"""Prepare a stable pathname for the native KDE file handoff.

prepared_source(reviewed_metadata, cancelled) yields PreparedSource(path,
snapshot_used). Protected canonical files need no copy. Other sources are copied
from their validated open descriptor into private cache storage. Once yielded,
snapshots survive context exit: KDE can reopen after CLI acceptance. They become
eligible after 24 hours. Cleanup is attempted on later preparation when the cache is safe and available.

No daemon or provider runs here. Same-UID code and root remain trusted. Deadlines
and cancellation are checked between bounded chunks, not inside blocked kernel
filesystem calls. All public errors are fixed codes without paths or contents.
"""
from collections import namedtuple
from contextlib import contextmanager
import errno
import fcntl
import os
from pathlib import Path
import re
import stat
import time
import uuid

PreparedSource = namedtuple('PreparedSource', 'path snapshot_used')
PREPARATION_SECONDS = 120
RETENTION_SECONDS = 24 * 60 * 60
RESERVE_BYTES = 64 * 1024 * 1024
CHUNK_BYTES = 1024 * 1024
MAX_BYTES = 2 ** 40
FICLONE = 0x40049409
SNAPSHOT_NAME = re.compile(r'source-[a-f0-9]{32}\Z')


def _check(cancelled, deadline):
    if cancelled():
        raise ValueError('cancelled-before-submit')
    if time.monotonic() >= deadline:
        raise ValueError('source-preparation-failed')


def _matches(expected, value):
    return (stat.S_ISREG(value.st_mode) and 0 <= value.st_size <= MAX_BYTES
            and expected.get('size') == value.st_size
            and all(expected.get(key) == str(actual) for key, actual in
                    (('device', value.st_dev), ('inode', value.st_ino),
                     ('mtimeNs', value.st_mtime_ns), ('ctimeNs', value.st_ctime_ns))))


def _protected_path(path, opened):
    """Check every canonical entry; sticky parents protect only owned children."""
    try:
        parts = [path] + list(path.parents)
        values = [entry.lstat() for entry in parts]
        if (values[0].st_dev, values[0].st_ino) != (opened.st_dev, opened.st_ino):
            return False
        for index, value in enumerate(values):
            if value.st_uid not in (0, os.getuid()) or stat.S_ISLNK(value.st_mode):
                return False
            if index == 0:
                if not stat.S_ISREG(value.st_mode) or value.st_mode & 0o022:
                    return False
            elif not stat.S_ISDIR(value.st_mode):
                return False
            elif value.st_mode & 0o022:
                if not value.st_mode & stat.S_ISVTX or values[index - 1].st_uid not in (0, os.getuid()):
                    return False
        return True
    except OSError:
        return False


def _cache_directory(create=True):
    raw = os.environ.get('XDG_CACHE_HOME') or str(Path.home() / '.cache')
    base = Path(raw)
    if not base.is_absolute() or '..' in base.parts or '\0' in raw:
        raise ValueError('source-preparation-failed')
    target = base / 'Omaconnect.plus' / 'share-snapshots'
    # Do not resolve: symlinks in cache ancestry are refused, not followed.
    chain = list(reversed(target.parents)) + [target]
    previous = None
    for entry in chain:
        try:
            value = entry.lstat()
        except FileNotFoundError:
            if not create:
                return None
            if previous is None or previous.st_uid not in (0, os.getuid()):
                raise ValueError('source-preparation-failed') from None
            entry.mkdir(mode=0o700)
            os.chmod(entry, 0o700, follow_symlinks=False)
            value = entry.lstat()
        if (not stat.S_ISDIR(value.st_mode) or value.st_uid not in (0, os.getuid())
                or value.st_mode & 0o022 and not value.st_mode & stat.S_ISVTX):
            raise ValueError('source-preparation-failed')
        if previous is not None and previous.st_mode & 0o022 and value.st_uid not in (0, os.getuid()):
            raise ValueError('source-preparation-failed')
        if entry in (target, target.parent) and (value.st_uid != os.getuid() or stat.S_IMODE(value.st_mode) != 0o700):
            raise ValueError('source-preparation-failed')
        previous = value
    return target


def _remove_snapshot(directory):
    """Delete only our exact flat shape; never recurse or follow a symlink."""
    try:
        info = directory.lstat()
        if (not SNAPSHOT_NAME.fullmatch(directory.name) or not stat.S_ISDIR(info.st_mode)
                or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700):
            return
        with os.scandir(directory) as entries:
            files = list(entries)
        if len(files) > 1:
            return
        for entry in files:
            value = entry.stat(follow_symlinks=False)
            if (not stat.S_ISREG(value.st_mode) or value.st_uid != os.getuid()
                    or stat.S_IMODE(value.st_mode) != 0o600 or value.st_nlink != 1):
                return
        for entry in files:
            os.unlink(entry.path)
        directory.rmdir()
    except OSError:
        # Unsafe or busy old state is preserved. Never broaden the delete set.
        return


def _expire(directory, cancelled, deadline):
    cutoff = time.time() - RETENTION_SECONDS
    with os.scandir(directory) as entries:
        for entry in entries:
            _check(cancelled, deadline)
            if SNAPSHOT_NAME.fullmatch(entry.name):
                value = entry.stat(follow_symlinks=False)
                if value.st_mtime <= cutoff:
                    _remove_snapshot(Path(entry.path))


def _space(directory, needed=0):
    available = os.statvfs(directory)
    if available.f_bavail * available.f_frsize < RESERVE_BYTES + needed:
        raise ValueError('source-preparation-failed')


def _clone_or_copy(source_fd, target_fd, size, directory, cancelled, deadline):
    _check(cancelled, deadline)
    _space(directory)
    try:
        fcntl.ioctl(target_fd, FICLONE, source_fd)
    except OSError as error:
        if error.errno not in (errno.EXDEV, errno.EINVAL, errno.ENOTTY, errno.EOPNOTSUPP, errno.ENOSYS):
            raise
        _space(directory, size)
        remaining = size
        while remaining:
            _check(cancelled, deadline)
            _space(directory, min(CHUNK_BYTES, remaining))
            block = os.read(source_fd, min(CHUNK_BYTES, remaining))
            if not block:
                raise ValueError('source-changed')
            view = memoryview(block)
            while view:
                _check(cancelled, deadline)
                written = os.write(target_fd, view)
                if written <= 0:
                    raise ValueError('source-preparation-failed')
                view = view[written:]
            remaining -= len(block)
    _check(cancelled, deadline)
    _space(directory)


@contextmanager
def prepared_source(expected, cancelled=lambda: False):
    """Yield an identity-checked trusted path or a private retained snapshot.

    ValueError codes: source-path-rejected, source-changed,
    source-preparation-failed, cancelled-before-submit. This context owns the
    source descriptor only; it does not start, stop or infer native transfers.
    """
    source_fd = target_fd = None
    created = None
    yielded = False
    try:
        deadline = time.monotonic() + PREPARATION_SECONDS
        _check(cancelled, deadline)
        path = expected.get('path') if isinstance(expected, dict) else None
        if (not isinstance(path, str) or not path.startswith('/') or '\0' in path
                or len(os.fsencode(path)) > 4096):
            raise ValueError('source-path-rejected')
        try:
            source_fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC)
        except OSError:
            raise ValueError('source-path-rejected') from None
        source_stat = os.fstat(source_fd)
        if not _matches(expected, source_stat):
            raise ValueError('source-changed')
        canonical = Path(os.readlink('/proc/self/fd/' + str(source_fd)))
        _check(cancelled, deadline)
        if canonical.is_absolute() and _protected_path(canonical, source_stat):
            # A protected source needs no cache. Optional old-copy housekeeping
            # must not turn an unrelated unsafe/unavailable cache into send failure.
            try:
                directory = _cache_directory(create=False)
            except (OSError, ValueError):
                directory = None
            if directory is not None:
                try:
                    _expire(directory, cancelled, deadline)
                except OSError:
                    pass
                # _expire's cancellation/deadline ValueErrors still propagate.
            _check(cancelled, deadline)
            if not _matches(expected, os.fstat(source_fd)):
                raise ValueError('source-changed')
            yielded = True
            yield PreparedSource(str(canonical), False)
            return
        directory = _cache_directory()
        _expire(directory, cancelled, deadline)
        _space(directory)
        _check(cancelled, deadline)
        created = directory / ('source-' + uuid.uuid4().hex)
        created.mkdir(mode=0o700)
        os.chmod(created, 0o700, follow_symlinks=False)
        target = created / Path(path).name
        target_fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
        os.fchmod(target_fd, 0o600)
        _clone_or_copy(source_fd, target_fd, source_stat.st_size, directory, cancelled, deadline)
        if not _matches(expected, os.fstat(source_fd)):
            raise ValueError('source-changed')
        if os.fstat(target_fd).st_size != source_stat.st_size:
            raise ValueError('source-preparation-failed')
        os.fsync(target_fd)
        os.close(target_fd)
        target_fd = None
        _check(cancelled, deadline)
        yielded = True
        yield PreparedSource(str(target), True)
    except OSError:
        if yielded:
            raise
        raise ValueError('source-preparation-failed') from None
    finally:
        if target_fd is not None:
            os.close(target_fd)
        if source_fd is not None:
            os.close(source_fd)
        if created is not None and not yielded:
            _remove_snapshot(created)
