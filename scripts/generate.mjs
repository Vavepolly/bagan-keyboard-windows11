import fs from 'node:fs';
import { readLayout, codepoints } from './layout.mjs';
const layout = readLayout();
fs.writeFileSync('bagan-layout.json', JSON.stringify({ name: 'Bagan Style Myanmar Windows', version: '0.3.0', target: 'Keyman for Windows 11', language: 'my', encoding: 'Unicode', provenance: 'Local Luna reference; unofficial, not verified Bagan', typingOrder: 'logical; no automatic reordering', layout }, null, 2) + '\n');
let table = '# Key map\n\nPhysical US key positions. Shift selects the second column. Logical Unicode order; unofficial layout.\n\n| Key | Normal (code point) | Shift (code point) |\n| --- | --- | --- |\n';
const escape = s => s.replaceAll('&', '&amp;').replaceAll('|', '&#124;').replaceAll('<', '&lt;');
for (const key of Object.keys(layout.normal).sort()) {
  table += `| ${key.slice(2)} | ${escape(layout.normal[key])} (${codepoints(layout.normal[key])}) | ${escape(layout.shift[key])} (${codepoints(layout.shift[key])}) |\n`;
}
fs.writeFileSync('KEYMAP.md', table);
