#!/usr/bin/env python3
"""Private, bounded appearance metadata. JSON stdin/stdout; no service actions.

read | update | import | library. update actions: bar, device, link, forget.
XDG_CONFIG_HOME/Omaconnect.plus/appearance.json; XDG_DATA_HOME/Omaconnect.plus/icons.
Corrupt/unsafe metadata is preserved and blocks writes. Assets are never collected.
"""
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import struct
import sys
import tempfile
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET
import zlib

MAX_STATE = 256 * 1024
MAX_IMAGE = 1024 * 1024
PRESETS = {'phone', 'desktop', 'laptop', 'link', 'share'}
ASSET = re.compile(r'^[a-f0-9]{64}\.(?:png|svg)$')
DEVICE = re.compile(r'^[A-Za-z0-9_-]{1,128}$')
SYNCTHING = re.compile(r'^[A-Z2-7]{7}(?:-[A-Z2-7]{7}){7}$')
BAD_TEXT = re.compile(r'[\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]')


class Rejected(ValueError):
    pass


def reject(condition, message):
    if condition:
        raise Rejected(message)


def default():
    return {'schema_version': 1, 'bar_icon': {'mode': 'preset', 'value': 'phone', 'render': 'symbolic'}, 'devices': {}}


def bounded_text(value, maximum, label):
    reject(not isinstance(value, str) or bool(BAD_TEXT.search(value)), label + ' is invalid.')
    value = value.strip()
    reject(len(value) > maximum, label + ' is invalid.')
    return value


def device_key(value):
    reject(not isinstance(value, str), 'Device ID is invalid.')
    raw = value.removeprefix('kdeconnect:')
    reject(not DEVICE.fullmatch(raw), 'Device ID is invalid.')
    return 'kdeconnect:' + raw


def icon(value, device=False):
    reject(not isinstance(value, dict), 'Icon is invalid.')
    reject(bool(set(value) - {'mode','value','render','font'}), 'Icon contains unsupported fields.')
    mode = value.get('mode')
    reject(mode not in ({'automatic', 'preset', 'theme', 'glyph', 'image', 'inherit'} if device else {'automatic', 'preset', 'theme', 'glyph', 'image'}), 'Icon mode is invalid.')
    render = value.get('render', 'symbolic')
    reject(render not in {'symbolic', 'color'}, 'Icon rendering is invalid.')
    result = {'mode': mode, 'render': render}
    if mode not in {'automatic', 'inherit'}:
        text = bounded_text(value.get('value'), 128, 'Icon value')
        reject(not text, 'Icon value is empty.')
        reject(mode == 'preset' and text not in PRESETS, 'Preset is unavailable.')
        reject(mode == 'theme' and not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,127}', text), 'Theme icon is invalid.')
        reject(mode == 'glyph' and len(text) > 8, 'Symbol must be at most 8 characters.')
        reject(mode == 'image' and not ASSET.fullmatch(text), 'Imported image is invalid.')
        result['value'] = text
        if mode == 'glyph' and value.get('font'):
            result['font'] = bounded_text(value['font'], 128, 'Font')
    return result


def validate(value):
    reject(not isinstance(value, dict) or type(value.get('schema_version')) is not int or value.get('schema_version') != 1, 'Appearance schema is unsupported.')
    reject(bool(set(value) - {'schema_version','bar_icon','devices'}), 'Appearance contains unsupported fields.')
    devices = value.get('devices')
    reject(not isinstance(devices, dict) or len(devices) > 256, 'Appearance device limit is 256.')
    result = {'schema_version': 1, 'bar_icon': icon(value.get('bar_icon')), 'devices': {}}
    for key, entry in devices.items():
        reject(device_key(key) != key or not isinstance(entry, dict), 'Device metadata is invalid.')
        reject(bool(set(entry) - {'alias','icon','addresses','syncthing_device_id'}), 'Device metadata contains unsupported fields.')
        record = {'alias': bounded_text(entry.get('alias', ''), 80, 'Alias'), 'icon': icon(entry.get('icon', {'mode': 'inherit'}), True)}
        identity = entry.get('syncthing_device_id')
        reject(identity is not None and (not isinstance(identity, str) or not SYNCTHING.fullmatch(identity)), 'Syncthing ID is invalid.')
        record['syncthing_device_id'] = identity
        # Keep the specified address field, without performing discovery or writes.
        if 'addresses' in entry:
            addresses = entry['addresses']
            reject(not isinstance(addresses, list) or len(addresses) > 64, 'Saved addresses are invalid.')
            for address in addresses:
                reject(not isinstance(address, dict) or not isinstance(address.get('address'), str) or len(address['address']) > 128 or BAD_TEXT.search(address['address']) or address.get('source') not in {'manual', 'inventory', 'route'} or type(address.get('auto_discover')) is not bool, 'Saved addresses are invalid.')
            record['addresses'] = addresses
        result['devices'][key] = record
    return result


def paths():
    home = Path.home()
    config = Path(os.environ.get('XDG_CONFIG_HOME', str(home/'.config')))
    data = Path(os.environ.get('XDG_DATA_HOME', str(home/'.local/share')))
    reject(not config.is_absolute() or not data.is_absolute(), 'Appearance directory must be absolute.')
    return config/'Omaconnect.plus', data/'Omaconnect.plus'/'icons'


def private_dir(path):
    # Parent XDG paths are user-selected; never chmod them. Own directories refuse
    # symlinks and permissions that expose local aliases or private addresses.
    if path.name == 'icons':
        private_dir(path.parent)
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = path.lstat()
    reject(not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077, 'Appearance directory is unsafe.')


def read_file(path, limit, owned=False):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        reject(not stat.S_ISREG(info.st_mode) or info.st_size > limit, 'File is not a supported regular file or exceeds its size limit.')
        reject(owned and (info.st_uid != os.getuid() or info.st_mode & 0o077), 'Appearance file permissions are unsafe.')
        data = stream.read(limit + 1)
        reject(len(data) > limit, 'File exceeds its size limit.')
        return data


def load(config):
    try:
        return validate(json.loads(read_file(config/'appearance.json', MAX_STATE, True)))
    except FileNotFoundError:
        return default()


def atomic_write(directory, name, data):
    private_dir(directory)
    fd, temporary = tempfile.mkstemp(prefix='.appearance-', suffix='.tmp', dir=directory)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, directory/name)
        directory_fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def inspect_png(data):
    reject(not data.startswith(b'\x89PNG\r\n\x1a\n'), 'Image is not PNG.')
    position, chunks, payload, width, height, row_size = 8, [], bytearray(), 0, 0, 0
    while position < len(data):
        reject(position + 12 > len(data), 'PNG is truncated.')
        size = struct.unpack('!I', data[position:position+4])[0]
        kind = data[position+4:position+8]
        end = position + 12 + size
        reject(end > len(data), 'PNG is truncated.')
        body = data[position+8:position+8+size]
        crc = struct.unpack('!I', data[position+8+size:end])[0]
        reject(zlib.crc32(kind + body) != crc, 'PNG checksum is invalid.')
        reject(kind in {b'acTL', b'fcTL', b'fdAT'}, 'Animated images are unsupported.')
        reject(not chunks and kind != b'IHDR', 'PNG header is missing.')
        if kind == b'IHDR':
            reject(bool(chunks) or size != 13, 'PNG header is invalid.')
            width, height, depth, color, compression, filtering, interlace = struct.unpack('!IIBBBBB', body)
            allowed = {0: {1,2,4,8,16}, 2: {8,16}, 3: {1,2,4,8}, 4: {8,16}, 6: {8,16}}
            reject(not 1 <= width <= 512 or not 1 <= height <= 512, 'Image dimensions must be at most 512 by 512.')
            reject(color not in allowed or depth not in allowed[color] or compression or filtering or interlace, 'PNG uses an unsupported format. Export a non-interlaced PNG.')
            row_size = (width * {0:1, 2:3, 3:1, 4:2, 6:4}[color] * depth + 7)//8
        elif kind == b'IDAT':
            reject(b'IDAT' in chunks and chunks[-1] != b'IDAT', 'PNG image data is invalid.')
            payload.extend(body)
        elif kind == b'IEND':
            reject(size != 0 or end != len(data) or b'IDAT' not in chunks, 'PNG end is invalid.')
        elif kind == b'PLTE':
            reject(size == 0 or size % 3 or size > 768 or b'PLTE' in chunks or b'IDAT' in chunks, 'PNG palette is invalid.')
        else:
            reject(not kind[0] & 32, 'PNG has an unsupported critical chunk.')
        chunks.append(kind)
        position = end
    reject(not chunks or chunks[-1] != b'IEND' or (color == 3 and b'PLTE' not in chunks), 'PNG is incomplete.')
    expected = (row_size + 1) * height
    decoder = zlib.decompressobj()
    raw = decoder.decompress(payload, expected + 1)
    reject(len(raw) != expected or not decoder.eof or decoder.unused_data or decoder.unconsumed_tail, 'PNG decoded data is invalid.')
    reject(any(raw[index] > 4 for index in range(0, len(raw), row_size + 1)), 'PNG row filter is invalid.')
    return 'png'


SVG_TAGS = {'svg','g','defs','symbol','use','path','rect','circle','ellipse','line','polyline','polygon','linearGradient','radialGradient','stop','clipPath','title','desc'}
SVG_ATTRS = {'id','width','height','viewBox','preserveAspectRatio','x','y','x1','y1','x2','y2','cx','cy','r','rx','ry','d','points','transform','fill','fill-opacity','fill-rule','stroke','stroke-width','stroke-linecap','stroke-linejoin','stroke-miterlimit','stroke-opacity','stroke-dasharray','stroke-dashoffset','opacity','offset','stop-color','stop-opacity','gradientUnits','gradientTransform','spreadMethod','fx','fy','clip-path','clip-rule','clipPathUnits','href','style','version','color'}
STYLE_ATTRS = {'fill','fill-opacity','fill-rule','stroke','stroke-width','stroke-linecap','stroke-linejoin','stroke-miterlimit','stroke-opacity','stroke-dasharray','stroke-dashoffset','opacity','stop-color','stop-opacity','color','clip-path','clip-rule'}


def inspect_svg(data):
    data.decode('utf-8-sig')
    reject(b'\0' in data, 'SVG must use UTF-8 encoding.')
    reject(re.search(br'<!|<\?', data.replace(b'<?xml ', b'<xml ', 1), re.I) is not None, 'SVG declarations and active content are unsupported.')
    root = ET.fromstring(data)
    namespace = '{http://www.w3.org/2000/svg}'
    reject(root.tag not in {'svg', namespace+'svg'}, 'Image is not SVG.')
    nodes = list(root.iter())
    reject(len(nodes) > 4096, 'SVG has too many elements.')
    for node in nodes:
        tag = node.tag.removeprefix(namespace)
        reject(tag not in SVG_TAGS, 'SVG contains unsupported or active content.')
        for raw_key, value in node.attrib.items():
            key = raw_key.removeprefix('{http://www.w3.org/1999/xlink}')
            reject(key not in SVG_ATTRS or len(value) > 65536, 'SVG attribute is unsupported.')
            reject(key == 'href' and not re.fullmatch(r'#[A-Za-z_][A-Za-z0-9_.:-]*', value), 'SVG external resources are unsupported.')
            urls = re.findall(r'url\s*\(([^)]*)\)', value, re.I)
            reject(any(not re.fullmatch(r'#[A-Za-z_][A-Za-z0-9_.:-]*', ref.strip()) for ref in urls), 'SVG external resources are unsupported.')
            reject(re.search(r'@|\\|(?:https?|file|data|javascript):|expression\s*\(', value, re.I) is not None, 'SVG external resources are unsupported.')
            if key == 'style':
                for declaration in value.split(';'):
                    if declaration.strip():
                        name, separator, unused = declaration.partition(':')
                        reject(not separator or name.strip() not in STYLE_ATTRS, 'SVG style is unsupported.')
    viewbox = root.get('viewBox', '').replace(',', ' ').split()
    fallback = viewbox[2:] if len(viewbox) == 4 else []
    dimensions = []
    for index, name in enumerate(('width','height')):
        value = root.get(name, fallback[index] if len(fallback) == 2 else '')
        reject(not re.fullmatch(r'(?:\d+(?:\.\d*)?|\.\d+)(?:px)?', value), 'SVG needs explicit pixel dimensions or a viewBox.')
        dimensions.append(float(value.removesuffix('px')))
    reject(any(not math.isfinite(size) or not 0 < size <= 512 for size in dimensions), 'Image dimensions must be at most 512 by 512.')
    # Fragment reuse cycles can exhaust native decoders. Disallow reuse chains;
    # basic symbols and gradients remain supported without recursive references.
    references = {node.get('id'): node for node in nodes if node.get('id')}
    for node in nodes:
        for raw_key, value in node.attrib.items():
            if raw_key.endswith('href'):
                target = references.get(value[1:])
                reject(target is None or any(child.tag.removeprefix(namespace) == 'use' or any(attr.endswith('href') for attr in child.attrib) for child in target.iter()), 'SVG reuse is missing or recursive.')
    return 'svg'


def inspect_image(data):
    reject(not data or len(data) > MAX_IMAGE, 'Image must be at most 1 MiB.')
    return inspect_png(data) if data.startswith(b'\x89PNG') else inspect_svg(data)


def asset_warnings(snapshot, assets):
    warnings = []
    invalid = []
    checked = set()
    icons = [snapshot['bar_icon']] + [entry['icon'] for entry in snapshot['devices'].values()]
    for entry in icons:
        if entry['mode'] == 'image' and entry['value'] not in checked:
            checked.add(entry['value'])
            try:
                data = read_file(assets/entry['value'], MAX_IMAGE, True)
                extension = inspect_image(data)
                reject(hashlib.sha256(data).hexdigest()+'.'+extension != entry['value'], 'Imported image changed.')
            except (OSError, ValueError, ET.ParseError, zlib.error):
                warnings.append('An imported image is missing or invalid. Phone is shown instead.')
                invalid.append(entry['value'])
    return list(dict.fromkeys(warnings)), invalid


# Required defaults stay discoverable even when other themes exhaust the bank.
PRESET_THEME_NAMES = {'smartphone-symbolic', 'computer-symbolic', 'laptop-symbolic', 'insert-link-symbolic', 'document-send-symbolic'}


def theme_library():
    # Inventory candidates only. QML verifies each name through the active Qt theme.
    data_home = Path(os.environ.get('XDG_DATA_HOME', str(Path.home()/'.local/share')))
    data_dirs = os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':')[:16]
    roots = [data_home/'icons', Path.home()/'.icons']
    roots += [Path(value)/'icons' for value in data_dirs if value.startswith('/') and len(value) <= 4096]
    roots.append(Path('/usr/share/pixmaps'))
    names = set(PRESET_THEME_NAMES)
    visited = 0
    for root in dict.fromkeys(roots):
        if not root.is_dir():
            continue
        for directory, children, files in os.walk(root, followlinks=False):
            visited += 1
            if visited >= 30000:
                return sorted(names), True
            children.sort()
            for filename in sorted(files):
                visited += 1
                if filename.lower().endswith(('.svg', '.png')):
                    name = Path(filename).stem
                    if re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,127}', name):
                        names.add(name)
                if visited >= 30000 or len(names) >= 1024:
                    return sorted(names), True
    return sorted(names), False


def main(command, request):
    config, assets = paths()
    result = {'ok': True, 'snapshot': default(), 'asset_dir': str(assets), 'warnings': []}
    if command == 'library':
        result['theme_icons'], result['library_truncated'] = theme_library()
        return result
    if command == 'import':
        source = request.get('path')
        reject(not isinstance(source, str) or len(source) > 4096, 'Choose a local SVG or PNG.')
        if source.startswith('file:'):
            parsed = urlsplit(source)
            reject(parsed.netloc not in {'', 'localhost'} or parsed.query or parsed.fragment, 'Choose a local file.')
            source = unquote(parsed.path)
        reject(not Path(source).is_absolute() or '\0' in source, 'Choose a local file.')
        data = read_file(source, MAX_IMAGE)
        extension = inspect_image(data)
        name = hashlib.sha256(data).hexdigest()+'.'+extension
        atomic_write(assets, name, data)
        result['icon'] = {'mode':'image', 'value':name, 'render':'color'}
    elif command == 'update':
        private_dir(config)
        descriptor = os.open(config/'.appearance.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, 'r+') as lock:
            reject(not stat.S_ISREG(os.fstat(lock.fileno()).st_mode) or os.fstat(lock.fileno()).st_uid != os.getuid() or os.fstat(lock.fileno()).st_mode & 0o077, 'Appearance lock is unsafe.')
            fcntl.flock(lock, fcntl.LOCK_EX)
            snapshot = load(config)
            action = request.get('action')
            if action == 'bar':
                snapshot['bar_icon'] = icon(request.get('icon'))
            else:
                key = device_key(request.get('device_id'))
                if action == 'forget':
                    snapshot['devices'].pop(key, None)
                else:
                    reject(action not in {'device','link'}, 'Appearance action is unsupported.')
                    record = snapshot['devices'].get(key, {'alias':'', 'icon':{'mode':'inherit'}, 'syncthing_device_id':None})
                    if action == 'device':
                        record['alias'] = bounded_text(request.get('alias',''), 80, 'Alias')
                        record['icon'] = icon(request.get('icon'), True)
                    else:
                        identity = request.get('syncthing_device_id')
                        reject(identity is not None and (not isinstance(identity, str) or not SYNCTHING.fullmatch(identity)), 'Choose a valid full Syncthing device ID.')
                        record['syncthing_device_id'] = identity
                    snapshot['devices'][key] = record
            snapshot = validate(snapshot)
            for entry in ([snapshot['bar_icon']] if action == 'bar' else [snapshot['devices'].get(key, {}).get('icon', {'mode':'inherit'})]):
                if entry['mode'] == 'image':
                    data = read_file(assets/entry['value'], MAX_IMAGE, True)
                    extension = inspect_image(data)
                    reject(hashlib.sha256(data).hexdigest()+'.'+extension != entry['value'], 'Imported image is invalid.')
            encoded = json.dumps(snapshot, ensure_ascii=False, separators=(',',':')).encode('utf-8')
            reject(len(encoded) > MAX_STATE, 'Appearance exceeds 256 KiB.')
            atomic_write(config, 'appearance.json', encoded)
    else:
        reject(command != 'read', 'Appearance command is unsupported.')
    # A read never creates configuration or assets.
    if config.exists():
        info = config.lstat()
        reject(not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077, 'Appearance directory is unsafe.')
    result['snapshot'] = load(config)
    result['warnings'], result['invalid_assets'] = asset_warnings(result['snapshot'], assets)
    return result


if __name__ == '__main__':
    try:
        reject(len(sys.argv) != 2, 'Appearance command is required.')
        source = sys.stdin.buffer.readline(MAX_STATE+1)
        reject(len(source) > MAX_STATE, 'Appearance request exceeds 256 KiB.')
        request = json.loads(source or b'{}')
        reject(not isinstance(request, dict), 'Appearance request is invalid.')
        output = main(sys.argv[1], request)
    except (OSError, ValueError, ET.ParseError, zlib.error, OverflowError, RecursionError) as error:
        # Never expose paths, metadata or parser excerpts in error messages.
        message = str(error) if isinstance(error, Rejected) else 'Appearance could not be read or saved. Existing metadata was preserved.'
        output = {'ok':False, 'snapshot':default(), 'warnings':[], 'error':message}
    print(json.dumps(output, ensure_ascii=False, separators=(',',':')))
