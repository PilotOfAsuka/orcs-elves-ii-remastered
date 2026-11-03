#!/usr/bin/env python3
"""Reproduce the supplied JAR inventory, bytecode and indexed resource extraction."""
from __future__ import annotations

import argparse
import collections
import hashlib
import io
import json
from pathlib import Path
import struct
import zipfile

from classfile import parse_class, dump

ROOT = Path(__file__).resolve().parents[1]


def decode_index(raw: bytes) -> list[dict]:
    """n.a(String)[I: LE u16 count; signed bank/u16 offset, FF boundary markers."""
    count = struct.unpack_from('<H', raw)[0]
    cursor = 2
    records = []
    while len(records) < count:
        bank, offset = struct.unpack_from('<bH', raw, cursor)
        cursor += 3
        if offset:
            if not records:
                raise ValueError('Boundary without preceding resource')
            records[-1]['size'] = offset - records[-1]['offset']
        if bank != -1:
            if bank < 0:
                raise ValueError('Unexpected negative bank')
            records.append(dict(id=len(records), bank=bank, offset=offset))
    bank, end = struct.unpack_from('<bH', raw, cursor)
    cursor += 3
    if bank != -1 or raw[cursor:] not in (b'', b'\xff\x00\x00'):
        raise ValueError('Invalid index terminator or trailing bytes')
    records[-1]['size'] = end - records[-1]['offset']
    if any(r['size'] < 0 for r in records):
        raise ValueError('Invalid resource bounds')
    return records


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('jar', nargs='?', type=Path,
                        default=ROOT/'research/original/orcs__elves_ii300.jar')
    args = parser.parse_args()
    raw = args.jar.read_bytes()
    classes = {}
    opcodes = collections.Counter()
    inventory = []
    groups = {}
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        if archive.testzip() is not None:
            raise ValueError('JAR CRC verification failed')
        extracted = ROOT/'research/extracted'
        for info in archive.infolist():
            if info.is_dir():
                continue
            data = archive.read(info)
            target = extracted/info.filename
            if not target.resolve().is_relative_to(extracted.resolve()):
                raise ValueError('Unsafe archive path')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            inventory.append(dict(path=info.filename, size=len(data),
                                  sha256=hashlib.sha256(data).hexdigest()))
            if info.filename.endswith('.class'):
                cls, counts = parse_class(data)
                classes[cls['name']] = cls
                opcodes.update(counts)
            elif not info.filename.startswith('META-INF/'):
                asset = ROOT/'game/assets/original'/info.filename
                asset.parent.mkdir(parents=True, exist_ok=True)
                asset.write_bytes(data)
        for name in archive.namelist():
            if not name.endswith('.idx'):
                continue
            group = name[:-4]
            records = decode_index(archive.read(name))
            coverage = collections.defaultdict(list)
            for record in records:
                bank = f"{group}{record['bank']}.bin"
                source = archive.read(bank)
                start, size = record['offset'], record['size']
                payload = source[start:start+size]
                if len(payload) != size:
                    raise ValueError(f'Truncated {bank}, resource {record["id"]}')
                record['sha256'] = hashlib.sha256(payload).hexdigest()
                record['file'] = bank
                suffix = '.png' if payload.startswith(b'\x89PNG\r\n\x1a\n') else '.mid' if payload.startswith(b'MThd') else '.bin'
                out = ROOT/'research/resources'/group/f"{record['id']:03d}{suffix}"
                out.parent.mkdir(parents=True, exist_ok=True)
                out.write_bytes(payload)
                coverage[bank].append((start, payload))
            for bank, spans in coverage.items():
                cursor = 0
                rebuilt = bytearray()
                for offset, payload in sorted(spans, key=lambda span:span[0]):
                    if offset != cursor:
                        raise ValueError(f'Gap or overlap in {bank}')
                    rebuilt.extend(payload)
                    cursor += len(payload)
                if bytes(rebuilt) != archive.read(bank):
                    raise ValueError(f'Round-trip mismatch: {bank}')
            groups[group] = records
            if group=='sounds' and archive.read(name).endswith(b'\xff\x00\x00'):
                dump(ROOT/'research/reports/index_suffixes.json', {'sounds.idx':{'trailing_hex':'ff0000','status':'preserved in original index; not consumed by n.a(String)[I'}})
    external = {ref['owner']+'.'+ref['name']+ref['desc']:ref
                for cls in classes.values() for ref in cls['references']
                if ref['owner'] not in classes}
    summary = dict(source=args.jar.name, sha256=hashlib.sha256(raw).hexdigest(),
                   entries=inventory, classes=len(classes), methods=sum(len(c['methods']) for c in classes.values()),
                   opcodes=len(opcodes), external_apis=len(external),
                   resource_counts={k:len(v) for k,v in groups.items()})
    dump(ROOT/'game/data/classes.json', classes)
    dump(ROOT/'research/reports/archive_inventory.json', summary)
    dump(ROOT/'research/reports/opcodes.json', dict(sorted(opcodes.items())))
    dump(ROOT/'research/reports/external_api.json', list(external.values()))
    dump(ROOT/'research/reports/resource_index.json', groups)
    print(json.dumps({k:v for k,v in summary.items() if k!='entries'}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
