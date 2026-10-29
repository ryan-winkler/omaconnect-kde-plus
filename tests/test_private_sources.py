"""Private source preparation uses owned files only; no native provider runs."""
import errno
import importlib.util
import os
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'scripts/private_sources.py'


def reviewed(path):
    value = path.stat()
    return {'path': str(path), 'size': value.st_size, 'device': str(value.st_dev),
            'inode': str(value.st_ino), 'mtimeNs': str(value.st_mtime_ns),
            'ctimeNs': str(value.st_ctime_ns)}


class PrivateSources(unittest.TestCase):
    def setUp(self):
        self.assertTrue(HELPER.is_file(), 'private source handoff helper is missing')
        spec = importlib.util.spec_from_file_location('private_sources', HELPER)
        self.m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.m)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.cache = self.base / 'cache'
        self.env = patch.dict(os.environ, {'XDG_CACHE_HOME': str(self.cache)})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.shared = self.base / 'shared'
        self.shared.mkdir(mode=0o777)
        self.shared.chmod(0o777)
        self.source = self.shared / 'reviewed name.bin'
        self.source.write_bytes(b'intended reviewed bytes')
        self.expected = reviewed(self.source)

    def snapshots(self):
        return list((self.cache / 'Omaconnect.plus/share-snapshots').glob('source-*'))

    def test_shared_source_replacement_cannot_redirect_later_backend_open(self):
        victim = self.base / 'private'
        victim.write_bytes(b'private sentinel never selected')
        with self.m.prepared_source(self.expected, lambda: False) as prepared:
            self.assertTrue(prepared.snapshot_used)
            self.assertEqual(Path(prepared.path).name, self.source.name)
            self.source.unlink()
            self.source.symlink_to(victim)
            self.assertEqual(Path(prepared.path).read_bytes(), b'intended reviewed bytes')
            self.assertEqual(Path(prepared.path).stat().st_mode & 0o777, 0o600)
            self.assertEqual(Path(prepared.path).parent.stat().st_mode & 0o777, 0o700)
        self.assertTrue(Path(prepared.path).is_file(), 'KDE can reopen after CLI/context exit')

    def test_private_file_uses_its_canonical_protected_fast_path(self):
        private = self.base / 'private'
        private.mkdir(mode=0o700)
        source = private / 'file'
        source.write_bytes(b'private regular file')
        alias = self.base / 'alias'
        alias.symlink_to(private, target_is_directory=True)
        with self.m.prepared_source(reviewed(alias / 'file'), lambda: False) as prepared:
            self.assertFalse(prepared.snapshot_used)
            self.assertEqual(prepared.path, str(source))
        self.assertFalse(self.cache.exists(), 'fast path needs no cache or payload copy')

    def test_group_writable_file_requires_a_snapshot(self):
        self.shared.chmod(0o700)
        self.source.chmod(0o660)
        with self.m.prepared_source(reviewed(self.source), lambda: False) as prepared:
            self.assertTrue(prepared.snapshot_used)

    def test_restrictive_umask_still_creates_readable_private_owned_snapshot(self):
        previous = os.umask(0o777)
        try:
            with self.m.prepared_source(self.expected, lambda: False) as prepared:
                self.assertEqual(Path(prepared.path).stat().st_mode & 0o777, 0o600)
                self.assertEqual(Path(prepared.path).parent.stat().st_mode & 0o777, 0o700)
                self.assertEqual(Path(prepared.path).read_bytes(), b'intended reviewed bytes')
        finally:
            os.umask(previous)

    def test_sticky_parent_protects_only_a_trusted_owned_next_entry(self):
        self.shared.chmod(0o1777)
        with self.m.prepared_source(reviewed(self.source), lambda: False) as prepared:
            self.assertFalse(prepared.snapshot_used)
        with patch.object(self.m.os, 'getuid', return_value=os.getuid() + 1):
            self.assertFalse(self.m._protected_path(self.source, self.source.stat()))

    def test_reflink_unavailable_falls_back_to_actual_bounded_copy(self):
        with patch.object(self.m.fcntl, 'ioctl', side_effect=OSError(errno.EXDEV, 'fixture')):
            with self.m.prepared_source(self.expected, lambda: False) as prepared:
                self.assertTrue(prepared.snapshot_used)
                self.assertEqual(Path(prepared.path).read_bytes(), self.source.read_bytes())

    def test_final_symlink_and_changed_review_identity_are_rejected(self):
        self.source.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, '^source-changed$'):
            with self.m.prepared_source(self.expected, lambda: False):
                self.fail('changed source was yielded')
        target = self.base / 'target'
        target.write_bytes(b'target')
        self.source.unlink()
        self.source.symlink_to(target)
        with self.assertRaisesRegex(ValueError, '^source-path-rejected$'):
            with self.m.prepared_source(reviewed(self.source), lambda: False):
                self.fail('final symlink was yielded')

    def test_cancel_before_preparation_creates_no_snapshot(self):
        with self.assertRaisesRegex(ValueError, '^cancelled-before-submit$'):
            with self.m.prepared_source(self.expected, lambda: True):
                self.fail('cancelled source was yielded')
        self.assertFalse(self.cache.exists())

    def test_copy_cancellation_and_write_failure_remove_only_new_snapshot(self):
        with patch.object(self.m.fcntl, 'ioctl', side_effect=OSError(errno.EOPNOTSUPP, 'fixture')):
            with patch.object(self.m.os, 'write', side_effect=OSError(errno.ENOSPC, 'fixture')):
                with self.assertRaisesRegex(ValueError, '^source-preparation-failed$'):
                    with self.m.prepared_source(self.expected, lambda: False):
                        self.fail('failed copy was yielded')
        self.assertEqual(self.snapshots(), [])
        calls = 0
        def cancelled():
            nonlocal calls
            calls += 1
            return calls >= 5
        with patch.object(self.m.fcntl, 'ioctl', side_effect=OSError(errno.EOPNOTSUPP, 'fixture')):
            with self.assertRaisesRegex(ValueError, '^cancelled-before-submit$'):
                with self.m.prepared_source(self.expected, cancelled):
                    self.fail('cancelled copy was yielded')
        self.assertEqual(self.snapshots(), [])

    def test_low_disk_and_expired_deadline_fail_without_payload_retention(self):
        empty = type('Space', (), {'f_bavail': 0, 'f_frsize': 4096})()
        with patch.object(self.m.os, 'statvfs', return_value=empty):
            with self.assertRaisesRegex(ValueError, '^source-preparation-failed$'):
                with self.m.prepared_source(self.expected, lambda: False):
                    self.fail('low-space snapshot was yielded')
        self.assertEqual(self.snapshots(), [])
        with patch.object(self.m.time, 'monotonic', side_effect=[0, 121, 121, 121]):
            with self.assertRaisesRegex(ValueError, '^source-preparation-failed$'):
                with self.m.prepared_source(self.expected, lambda: False):
                    self.fail('late preparation was yielded')
        self.assertEqual(self.snapshots(), [])

    def test_source_changed_during_copy_is_rejected_and_cleaned(self):
        original = self.m._clone_or_copy
        def changed(*args, **kwargs):
            original(*args, **kwargs)
            self.source.write_bytes(b'changed during snapshot')
        with patch.object(self.m, '_clone_or_copy', side_effect=changed):
            with self.assertRaisesRegex(ValueError, '^source-changed$'):
                with self.m.prepared_source(self.expected, lambda: False):
                    self.fail('changed source snapshot was yielded')
        self.assertEqual(self.snapshots(), [])

    def test_incomplete_snapshot_cannot_be_yielded(self):
        with patch.object(self.m, '_clone_or_copy', return_value=None):
            with self.assertRaisesRegex(ValueError, '^source-preparation-failed$'):
                with self.m.prepared_source(self.expected, lambda: False):
                    self.fail('incomplete snapshot was yielded')
        self.assertEqual(self.snapshots(), [])

    def test_cache_symlinks_unsafe_ancestors_and_nonprivate_existing_dirs_refuse(self):
        self.cache.symlink_to(self.base, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, '^source-preparation-failed$'):
            with self.m.prepared_source(self.expected, lambda: False):
                self.fail('symlink cache accepted')
        self.cache.unlink()
        self.cache.mkdir(mode=0o777)
        self.cache.chmod(0o777)
        with self.assertRaisesRegex(ValueError, '^source-preparation-failed$'):
            with self.m.prepared_source(self.expected, lambda: False):
                self.fail('unprotected cache ancestry accepted')
        self.cache.chmod(0o700)
        namespace = self.cache / 'Omaconnect.plus'
        namespace.mkdir(mode=0o755)
        namespace.chmod(0o755)
        with self.assertRaisesRegex(ValueError, '^source-preparation-failed$'):
            with self.m.prepared_source(self.expected, lambda: False):
                self.fail('nonprivate namespace accepted')
        self.assertEqual(namespace.stat().st_mode & 0o777, 0o755, 'never chmod existing unrelated state')

    def test_expiration_removes_only_exact_owned_safe_old_snapshots(self):
        with self.m.prepared_source(self.expected, lambda: False) as prepared:
            first = Path(prepared.path)
        parent = first.parent.parent
        old = time.time() - self.m.RETENTION_SECONDS - 10
        os.utime(first.parent, (old, old))
        unrelated = parent / 'unrelated'
        unrelated.mkdir(mode=0o700)
        (unrelated / 'keep').write_bytes(b'keep')
        linked = parent / ('source-' + 'b' * 32)
        linked.symlink_to(unrelated, target_is_directory=True)
        unsafe = parent / ('source-' + 'c' * 32)
        unsafe.mkdir(mode=0o700)
        (unsafe / 'link').symlink_to(unrelated / 'keep')
        os.utime(unsafe, (old, old))
        recent = parent / ('source-' + 'd' * 32)
        recent.mkdir(mode=0o700)
        private = self.base / 'ordinary-private-file'
        private.write_bytes(b'private fast path also expires existing snapshots')
        with self.m.prepared_source(reviewed(private), lambda: False) as next_source:
            self.assertFalse(next_source.snapshot_used)
        self.assertFalse(first.parent.exists())
        self.assertEqual((unrelated / 'keep').read_bytes(), b'keep')
        self.assertTrue(linked.is_symlink())
        self.assertTrue((unsafe / 'link').is_symlink())
        self.assertTrue(recent.is_dir())


if __name__ == '__main__':
    unittest.main()
