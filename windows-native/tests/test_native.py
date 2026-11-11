"""Source validation only. No compiler, Windows runtime or installation simulated."""
from pathlib import Path
import hashlib
import importlib.util
import json
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('native_generate', ROOT / 'scripts/generate.py')
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)


def klc_rows():
    """Independent reader of the generated table, not its generator inventory."""
    text = (ROOT / 'source/bgmyuni.klc').read_text(encoding='utf-16')
    body = text.split('\nLAYOUT\n', 1)[1].split('\nKEYNAME\n', 1)[0]
    rows = {}
    for line in body.splitlines():
        line = line.split('//', 1)[0].strip()
        if not line:
            continue
        fields = line.split()
        if len(fields) != 6:
            raise AssertionError(f'Expected scan, VK, caps and three states: {line}')
        scan, vk, caps, normal, shift, ctrl = fields
        if vk in rows:
            raise AssertionError(f'Duplicate virtual key: {vk}')
        rows[vk] = (scan, int(caps), normal, shift, ctrl)
    return rows


class NativeSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = (ROOT / 'source/bgmyuni.klc').read_text(encoding='utf-16')
        cls.rows = klc_rows()
        cls.manifest = json.loads((ROOT / 'source/mapping.json').read_text(encoding='utf-8'))

    def test_01_original_project_unchanged(self):
        hashes = json.loads((ROOT / 'tests/original-files.sha256.json').read_text())
        for name, expected in hashes.items():
            with self.subTest(file=name):
                self.assertEqual(hashlib.sha256((ROOT.parent / name).read_bytes()).hexdigest(), expected)

    def test_02_current_source_audit_and_coverage(self):
        source = GEN.parse_source(GEN.SOURCE.read_text())
        self.assertEqual([len(source[layer]) for layer in ('normal', 'shift')], [47, 47])
        self.assertEqual(source['normal']['K_BKSLASH'], '\\')
        self.assertEqual(source['normal']['K_QUOTE'], "'")
        for item in self.manifest['rows']:
            row = self.rows[item['virtualKey']]
            self.assertEqual(chr(int(row[2], 16)), source['normal'][item['keymanKey']])
            self.assertEqual(chr(int(row[3], 16)), source['shift'][item['keymanKey']])
        # Compare to the existing independently generated Keyman map as well.
        self.assertEqual(source, json.loads((ROOT.parent / 'bagan-layout.json').read_text())['layout'])

    def test_03_metadata_encoding_and_no_dead_keys(self):
        raw = (ROOT / 'source/bgmyuni.klc').read_bytes()
        self.assertTrue(raw.startswith(b'\xff\xfe'))
        self.assertNotIn(b'\n\x00', raw.replace(b'\r\x00\n\x00', b''))
        self.assertRegex(self.text, r'^KBD\s+bgmyuni\s+"[^"]+"')
        self.assertIn('LOCALENAME\t"en-US"', self.text)
        self.assertIn('LOCALEID\t"00000409"', self.text)
        self.assertEqual(self.text.split('SHIFTSTATE\n')[1].split('LAYOUT')[0].splitlines()[0].split()[0], '0')
        self.assertNotRegex(self.text, r'(?m)^(DEADKEY|LIGATURE|ATTRIBUTES)\b')
        self.assertNotIn('@', self.text)
        self.assertTrue(self.text.rstrip().endswith('ENDKBD'))

    def test_04_unique_scans_and_complete_letter_positions(self):
        scans = [row[0] for row in self.rows.values()]
        self.assertEqual(len(scans), len(set(scans)))
        # Independent PC/AT Set 1 letter-position fixture.
        expected = {'Q':'10','W':'11','E':'12','R':'13','T':'14','Y':'15','U':'16','I':'17','O':'18','P':'19',
                    'A':'1e','S':'1f','D':'20','F':'21','G':'22','H':'23','J':'24','K':'25','L':'26',
                    'Z':'2c','X':'2d','C':'2e','V':'2f','B':'30','N':'31','M':'32'}
        for key, scan in expected.items():
            self.assertEqual(self.rows[key][0], scan)
        self.assertEqual(len(self.rows), 53)  # 47 source keys + 6 Windows policy rows

    def test_05_oem_positions(self):
        expected = {'OEM_MINUS':'0c','OEM_PLUS':'0d','OEM_4':'1a','OEM_6':'1b',
                    'OEM_1':'27','OEM_7':'28','OEM_3':'29','OEM_5':'2b',
                    'OEM_COMMA':'33','OEM_PERIOD':'34','OEM_2':'35'}
        for vk, scan in expected.items():
            self.assertEqual(self.rows[vk][0], scan)
        for number, scan in zip('1234567890', range(2, 12)):
            self.assertEqual(self.rows[number][0], f'{scan:02x}')

    def test_06_valid_bmp_scalars_and_caps_policy(self):
        for item in self.manifest['rows']:
            row = self.rows[item['virtualKey']]
            self.assertEqual(row[1], 0)
            for value in row[2:4]:
                self.assertRegex(value, r'^[0-9a-f]{4}$')
                cp = int(value, 16)
                self.assertFalse(0xD800 <= cp <= 0xDFFF)
                self.assertNotIn(cp, [0xFFFD, 0xFFFE, 0xFFFF])
                self.assertTrue(0x20 <= cp < 0x7F or 0x1000 <= cp <= 0x109F)

    def test_07_control_and_editing_behavior(self):
        for letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ':
            self.assertEqual(int(self.rows[letter][4], 16), ord(letter) - 64)
        expected = {'BACK':('0008','0008','007f'), 'TAB':('0009','0009','-1'),
                    'RETURN':('000d','000d','000a'), 'SPACE':('0020','0020','0020'),
                    'DECIMAL':('002e','002e','-1'), 'OEM_102':('-1','-1','-1')}
        for vk, outputs in expected.items():
            self.assertEqual(self.rows[vk][2:], outputs)

    def test_08_punctuation_and_ascii_digits_preserved(self):
        for digit in '0123456789':
            self.assertEqual(chr(int(self.rows[digit][2], 16)), digit)
        self.assertEqual(self.rows['OEM_5'][2:4], ('005c','007c'))
        self.assertEqual(self.rows['OEM_7'][2:4], ('0027','100e'))
        self.assertEqual(self.rows['7'][3], '101b')  # retained Shift+7 ရ
        self.assertEqual(self.rows['OEM_COMMA'][2], '104a')
        self.assertEqual(self.rows['OEM_PERIOD'][2], '104b')

    def test_09_myanmar_mark_inventory(self):
        required = {0x102B,0x102C,0x102D,0x102E,0x102F,0x1030,0x1031,0x1032,
                    0x1036,0x1037,0x1038,0x1039,0x103A,0x103B,0x103C,0x103D,0x103E}
        actual = {int(value, 16) for row in self.rows.values() for value in row[2:4] if value != '-1'}
        self.assertTrue(required <= actual)

    def test_10_logical_order_sequences_from_klc(self):
        cases = [
            ('U A', [0x1000,0x1031]),
            ('U S S-G S-S A M', [0x1000,0x103B,0x103D,0x103E,0x1031,0x102C]),
            ('U D K', [0x1000,0x102D,0x102F]),
            ('U S-F U', [0x1000,0x1039,0x1000]),
            ('I F S-F U', [0x1004,0x103A,0x1039,0x1000]),
            ('O I F S-F B A M', [0x101E,0x1004,0x103A,0x1039,0x1018,0x1031,0x102C]),
            ('U H F', [0x1000,0x1037,0x103A]),
            ('C G', [0x1001,0x102B]),
            ('U S-H OEM_1', [0x1000,0x1036,0x1038]),
        ]
        for keys, expected in cases:
            with self.subTest(keys=keys):
                actual = [int(self.rows[token.removeprefix('S-')][3 if token.startswith('S-') else 2], 16)
                          for token in keys.split()]
                self.assertEqual(actual, expected)

    def test_11_reject_unsupported_rules(self):
        text = GEN.SOURCE.read_text()
        for extra in ("+ [CTRL K_A] > 'a'", "'က' + [K_A] > 'ခ'", "+ [K_A] > 'ab'", "+ [K_A] > U+D800", "store(custom) 'x'"):
            with self.subTest(extra=extra), self.assertRaises(ValueError):
                GEN.parse_source(text + '\n' + extra)

    def test_12_source_and_generated_hashes(self):
        self.assertEqual(self.manifest['sourceSha256'], hashlib.sha256(GEN.SOURCE.read_bytes()).hexdigest())
        hashes = json.loads((ROOT / 'source/generated-sha256.json').read_text())
        for name, expected in hashes.items():
            self.assertEqual(hashlib.sha256((ROOT / name).read_bytes()).hexdigest(), expected)

    def test_13_regeneration_is_deterministic(self):
        names = ['source/bgmyuni.klc', 'source/mapping.json', 'source/generated-sha256.json', 'KEYMAP.md']
        previous = {name: (ROOT / name).read_bytes() for name in names}
        subprocess.run([sys.executable, str(ROOT / 'scripts/generate.py')], check=True, capture_output=True)
        for name in names:
            self.assertEqual((ROOT / name).read_bytes(), previous[name])


if __name__ == '__main__':
    unittest.main(verbosity=2)
