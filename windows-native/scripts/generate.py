"""Generate an MSKLC source using only Python's standard library.

Run from any directory: python3 windows-native/scripts/generate.py
Only writes inside windows-native. Does not compile, install or register anything.
"""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / 'bagan-full.kmn'

# PC/AT Set 1 scan codes and Windows VK names for physical US ANSI positions.
# OEM_1 is the semicolon key, OEM_7 the quote key, OEM_5 the backslash key.
ROWS = [
    ('02','1','1'), ('03','2','2'), ('04','3','3'), ('05','4','4'),
    ('06','5','5'), ('07','6','6'), ('08','7','7'), ('09','8','8'),
    ('0a','9','9'), ('0b','0','0'), ('0c','HYPHEN','OEM_MINUS'),
    ('0d','EQUAL','OEM_PLUS'),
    ('10','Q','Q'), ('11','W','W'), ('12','E','E'), ('13','R','R'),
    ('14','T','T'), ('15','Y','Y'), ('16','U','U'), ('17','I','I'),
    ('18','O','O'), ('19','P','P'), ('1a','LBRKT','OEM_4'), ('1b','RBRKT','OEM_6'),
    ('1e','A','A'), ('1f','S','S'), ('20','D','D'), ('21','F','F'),
    ('22','G','G'), ('23','H','H'), ('24','J','J'), ('25','K','K'),
    ('26','L','L'), ('27','COLON','OEM_1'), ('28','QUOTE','OEM_7'),
    ('29','BKQUOTE','OEM_3'), ('2b','BKSLASH','OEM_5'),
    ('2c','Z','Z'), ('2d','X','X'), ('2e','C','C'), ('2f','V','V'),
    ('30','B','B'), ('31','N','N'), ('32','M','M'),
    ('33','COMMA','OEM_COMMA'), ('34','PERIOD','OEM_PERIOD'), ('35','SLASH','OEM_2'),
]


def parse_source(text):
    """Fail closed if future source introduces contexts, stores or multi-output rules."""
    mapping = {'normal': {}, 'shift': {}}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith('c ') or line == 'c':
            continue
        if re.fullmatch(r"store\(&(NAME|VERSION|KEYBOARDVERSION|TARGETS)\) '[^']*'", line):
            continue
        if line in ('begin Unicode > use(Main)', 'group(Main) using keys'):
            continue
        match = re.fullmatch(r"\+ \[(SHIFT )?(K_\w+)\] > (?:'([^']*)'|U\+([0-9A-Fa-f]{4,6}))", line)
        if not match:
            raise ValueError(f'Unsupported source statement: {line}')
        shift, key, literal, scalar = match.groups()
        output = chr(int(scalar, 16)) if scalar else literal
        if len(output) != 1 or not 0x20 <= ord(output) <= 0xFFFD or 0xD800 <= ord(output) <= 0xDFFF:
            raise ValueError(f'Output must be one printable BMP scalar: {line}')
        layer = mapping['shift' if shift else 'normal']
        if key in layer:
            raise ValueError(f'Duplicate rule: {line}')
        layer[key] = output
    expected = {'K_' + key for _, key, _ in ROWS}
    for layer in mapping.values():
        if set(layer) != expected:
            raise ValueError('Expected exactly 47 physical printable keys per layer')
    return mapping


def hexchar(value):
    return f'{ord(value):04x}'


def generate():
    source_bytes = SOURCE.read_bytes()
    mapping = parse_source(source_bytes.decode('utf-8'))
    lines = [
        'KBD\tbgmyuni\t"Bagan Style Myanmar Native (unofficial)"', '',
        '// Generated from bagan-full.kmn; do not edit this generated file.',
        '// English-US host locale for legacy MSKLC compatibility; output is Myanmar Unicode.',
        '// Caps Lock does not select the Shift layer. No dead keys or AltGr layer.',
        'COMPANY\t"Local reference-derived project"',
        'LOCALENAME\t"en-US"', 'LOCALEID\t"00000409"', 'VERSION\t1.0', '',
        'SHIFTSTATE', '0\t// Normal', '1\t// Shift', '2\t// Ctrl', '',
        'LAYOUT', '//SC\tVK_\tCap\t0\t1\t2', '',
    ]
    inventory = []
    for scan, key, vk in sorted(ROWS, key=lambda row: int(row[0], 16)):
        normal, shift = mapping['normal']['K_' + key], mapping['shift']['K_' + key]
        # Explicit control characters preserve standard US Ctrl+A..Z conventions.
        # Other shortcuts are handled by Windows/apps by VK, not text output.
        control = f'{ord(key) - 64:04x}' if len(key) == 1 and 'A' <= key <= 'Z' else '-1'
        if key in ('LBRKT', 'BKSLASH', 'RBRKT'):
            control = {'LBRKT':'001b', 'BKSLASH':'001c', 'RBRKT':'001d'}[key]
        lines.append(f'{scan}\t{vk}\t0\t{hexchar(normal)}\t{hexchar(shift)}\t{control}')
        inventory.append({'scanCode': scan, 'keymanKey': 'K_' + key, 'virtualKey': vk,
                          'caps': 0, 'normal': normal, 'shift': shift, 'ctrl': control})
    lines += [
        '', '// Windows editing keys; not additional Myanmar mappings.',
        '0e\tBACK\t0\t0008\t0008\t007f',
        '0f\tTAB\t0\t0009\t0009\t-1',
        '1c\tRETURN\t0\t000d\t000d\t000a',
        '39\tSPACE\t0\t0020\t0020\t0020',
        '53\tDECIMAL\t0\t002e\t002e\t-1',
        '56\tOEM_102\t0\t-1\t-1\t-1\t// ISO extra key intentionally unmapped',
        '', 'KEYNAME', '01\tEsc', '0e\tBackspace', '0f\tTab', '1c\tEnter',
        '1d\tCtrl', '2a\tShift', '36\t"Right Shift"', '37\t"Num *"',
        '38\tAlt', '39\tSpace', '3a\t"Caps Lock"', '3b\tF1', '3c\tF2',
        '3d\tF3', '3e\tF4', '3f\tF5', '40\tF6', '41\tF7', '42\tF8',
        '43\tF9', '44\tF10', '45\tPause', '46\t"Scroll Lock"',
        '47\t"Num 7"', '48\t"Num 8"', '49\t"Num 9"', '4a\t"Num -"',
        '4b\t"Num 4"', '4c\t"Num 5"', '4d\t"Num 6"', '4e\t"Num +"',
        '4f\t"Num 1"', '50\t"Num 2"', '51\t"Num 3"', '52\t"Num 0"',
        '53\t"Num Del"', '54\t"Sys Req"', '57\tF11', '58\tF12', '',
        'KEYNAME_EXT', '1c\t"Num Enter"', '1d\t"Right Ctrl"', '35\t"Num /"',
        '37\t"Prnt Scrn"', '38\t"Right Alt"', '45\t"Num Lock"', '46\tBreak',
        '47\tHome', '48\tUp', '49\t"Page Up"', '4b\tLeft', '4d\tRight',
        '4f\tEnd', '50\tDown', '51\t"Page Down"', '52\tInsert', '53\tDelete',
        '54\t"<00>"', '56\tHelp', '5b\t"Left Windows"', '5c\t"Right Windows"',
        '5d\tApplication', '', 'DESCRIPTIONS',
        '0409\tBagan Style Myanmar Native (unofficial)', '',
        'LANGUAGENAMES', '0409\tEnglish (United States)', '', 'ENDKBD', '',
    ]
    klc = '\r\n'.join(lines)
    (ROOT / 'source' / 'bgmyuni.klc').write_bytes(b'\xff\xfe' + klc.encode('utf-16-le'))
    manifest = {
        'layoutId': 'bgmyuni', 'displayName': 'Bagan Style Myanmar Native (unofficial)',
        'sourceFile': '../bagan-full.kmn', 'sourceSha256': hashlib.sha256(source_bytes).hexdigest(),
        'sourceKeyboardVersion': '0.3.0', 'hostLocale': 'en-US', 'localeId': '00000409',
        'outputLanguage': 'my', 'counts': {'normal': 47, 'shift': 47},
        'capsLockPolicy': 'ignored; Shift alone selects shifted output',
        'rows': inventory,
    }
    (ROOT / 'source' / 'mapping.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    table = ['# Native physical key map', '',
             'US ANSI positions. Caps Lock is ignored. All values are Unicode.', '',
             '| Scan | Key | Normal | Shift |', '| --- | --- | --- | --- |']
    def cell(s):
        return s.replace('&', '&amp;').replace('|', '&#124;').replace('<', '&lt;') + f' (U+{ord(s):04X})'
    for row in inventory:
        table.append(f"| {row['scanCode']} | {row['keymanKey'][2:]} | {cell(row['normal'])} | {cell(row['shift'])} |")
    (ROOT / 'KEYMAP.md').write_text('\n'.join(table) + '\n', encoding='utf-8')
    checksums = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                 for name in ('source/bgmyuni.klc', 'source/mapping.json', 'KEYMAP.md')}
    (ROOT / 'source' / 'generated-sha256.json').write_text(json.dumps(checksums, indent=2) + '\n', encoding='utf-8')
    print('Generated source/bgmyuni.klc (UTF-16LE BOM), mapping.json and KEYMAP.md; 94 mappings.')


if __name__ == '__main__':
    generate()
