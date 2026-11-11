import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import JSZip from 'jszip';
import { KmxFileReader } from '@keymanapp/common-types';
import { readLayout } from '../scripts/layout.mjs';

const layout = readLayout();
const bytes = fs.readFileSync('dist/bagan_full.kmx');
const keyboard = new KmxFileReader().read(bytes);
const keys = keyboard.groups[0].keys;
const vk = { HYPHEN:189, EQUAL:187, LBRKT:219, RBRKT:221, COLON:186,
  QUOTE:222, BKSLASH:220, COMMA:188, PERIOD:190, SLASH:191, BKQUOTE:192 };
const keycode = key => key.length === 1 ? key.charCodeAt(0) : vk[key];
function output(token) {
  const shift = token.startsWith('S-');
  const key = token.replace(/^S-/, '');
  const matches = keys.filter(k => k.Key === keycode(key) && k.ShiftFlags === (0x4000 | (shift ? 0x10 : 0)));
  assert.equal(matches.length, 1, token);
  return matches[0].dpOutput;
}

test('94 unique printable rules, full letters and valid single-scalar outputs', () => {
  for (const layer of Object.values(layout)) {
    assert.equal(Object.keys(layer).length, 47);
    for (const letter of 'ABCDEFGHIJKLMNOPQRSTUVWXYZ') assert.ok(layer[`K_${letter}`]);
    for (const value of Object.values(layer)) {
      assert.equal([...value].length, 1);
      const cp = value.codePointAt(0);
      assert.ok(cp < 0xD800 || cp > 0xDFFF);
      assert.ok(cp >= 0x20 && cp !== 0xFFFD);
    }
  }
  assert.deepEqual(JSON.parse(fs.readFileSync('bagan-layout.json')).layout, layout);
});

test('every original mapping retained except double-backslash repair', () => {
  const previous = fs.readFileSync('bagan-full.pre-0.3.0.kmn', 'utf8');
  let count = 0;
  for (const m of previous.matchAll(/^\+ \[(SHIFT )?(K_\w+)\] > '([^']*)'$/gm)) {
    assert.equal(layout[m[1] ? 'shift' : 'normal'][m[2]], m[2] === 'K_BKSLASH' && !m[1] ? '\\' : m[3]);
    count++;
  }
  assert.equal(count, 93);
  assert.equal(layout.normal.K_QUOTE, "'");
});

test('compiled binary has exactly the source outputs and no hidden contextual rules', () => {
  assert.equal(keyboard.keyboardVersion, '0.3.0');
  assert.equal(keyboard.groups.length, 1);
  assert.equal(keys.length, 94);
  assert.ok(!keyboard.groups[0].dpMatch);
  assert.ok(!keyboard.groups[0].dpNoMatch);
  for (const k of keys) assert.equal(k.dpContext, '');
  for (const [layer, entries] of Object.entries(layout)) {
    for (const [key, value] of Object.entries(entries)) {
      assert.equal(output((layer === 'shift' ? 'S-' : '') + key.slice(2)), value);
    }
  }
  assert.equal(output('BKSLASH'), '\\');
  assert.equal(output('QUOTE'), "'");
});

// This walks decoded, context-free compiled rules; it is not a Keyman engine emulator.
const sequences = [
  ['prebase vowel in logical order', 'U A', [0x1000,0x1031]],
  ['medials before E and AA', 'U S S-G S-S A M', [0x1000,0x103B,0x103D,0x103E,0x1031,0x102C]],
  ['I before U', 'U D K', [0x1000,0x102D,0x102F]],
  ['stack', 'U S-F U', [0x1000,0x1039,0x1000]],
  ['kinzi', 'I F S-F U', [0x1004,0x103A,0x1039,0x1000]],
  ['ship (Unicode FAQ example)', 'O I F S-F B A M', [0x101E,0x1004,0x103A,0x1039,0x1018,0x1031,0x102C]],
  ['dot below then asat', 'U H F', [0x1000,0x1037,0x103A]],
  ['tall AA', 'C G', [0x1001,0x102B]],
  ['anusvara and visarga', 'U S-H COLON', [0x1000,0x1036,0x1038]],
];
for (const [name, input, expected] of sequences) {
  test(`compiled sequence: ${name}`, () => {
    assert.deepEqual([...input.split(' ').map(output).join('')].map(c => c.codePointAt(0)), expected);
  });
}

test('package manifest, language, version, help and embedded KMX', async () => {
  const zip = await JSZip.loadAsync(fs.readFileSync('dist/bagan_full.kmp'));
  const manifest = JSON.parse(await zip.file('kmp.json').async('string'));
  assert.equal(manifest.keyboards.length, 1);
  assert.equal(manifest.keyboards[0].id, 'bagan_full');
  assert.equal(manifest.keyboards[0].version, '0.3.0');
  assert.equal(manifest.keyboards[0].languages[0].id, 'my');
  assert.equal(manifest.options.readmeFile, 'README.htm');
  assert.ok(zip.file('README.htm'));
  assert.ok(zip.file('KEYMAP.md'));
  assert.deepEqual(await zip.file('bagan_full.kmx').async('nodebuffer'), bytes);
  assert.ok(!Object.keys(zip.files).some(n => /\.(exe|dll|keylayout|kmn)$/i.test(n)));
  for (const entry of manifest.files) assert.ok(zip.file(entry.name), entry.name);
});

test('reference and original backup hashes unchanged', () => {
  const hashes = JSON.parse(fs.readFileSync('tests/preserved-sha256.json'));
  for (const [name, expected] of Object.entries(hashes)) {
    assert.equal(crypto.createHash('sha256').update(fs.readFileSync(name)).digest('hex'), expected, name);
  }
});
