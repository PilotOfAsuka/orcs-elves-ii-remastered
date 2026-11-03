"""Check indexed resources against the original archive, including exact byte coverage."""
import hashlib
import sys
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from analyze_jar import decode_index


class OriginalResources(unittest.TestCase):
    def test_source_identity(self):
        raw = (ROOT/'research/original/orcs__elves_ii300.jar').read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),
                         '759213ee5ce194f1ac92ff5937ffe562200e2c01dcfd76890c5148cf57787a33')

    def test_all_resource_banks_round_trip(self):
        with zipfile.ZipFile(ROOT/'research/original/orcs__elves_ii300.jar') as archive:
            for name in archive.namelist():
                if not name.endswith('.idx'):
                    continue
                with self.subTest(index=name):
                    banks = {}
                    for record in decode_index(archive.read(name)):
                        bank = f"{name[:-4]}{record['bank']}.bin"
                        source = archive.read(bank)
                        rebuilt = banks.setdefault(bank, bytearray())
                        self.assertEqual(len(rebuilt), record['offset'])
                        start, size = record['offset'], record['size']
                        rebuilt.extend(source[start:start+size])
                    for bank, rebuilt in banks.items():
                        self.assertEqual(bytes(rebuilt), archive.read(bank))

    def test_rejects_truncated_index(self):
        with self.assertRaises(Exception):
            decode_index(b'\x02\x00\x00\x00\x00')


if __name__ == '__main__':
    unittest.main()
