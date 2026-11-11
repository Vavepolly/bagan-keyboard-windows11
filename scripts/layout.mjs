import fs from 'node:fs';
export function readLayout() {
  const source = fs.readFileSync('bagan-full.kmn', 'utf8');
  const layout = { normal: {}, shift: {} };
  for (const line of source.split(/\r?\n/)) {
    if (!line.startsWith('+')) continue;
    const m = line.match(/^\+ \[(SHIFT )?(K_\w+)\] > (?:'([^']*)'|U\+([0-9A-F]+))$/);
    if (!m) throw Error(`Unsupported rule: ${line}`);
    const layer = layout[m[1] ? 'shift' : 'normal'];
    if (Object.hasOwn(layer, m[2])) throw Error(`Duplicate ${m[2]}`);
    layer[m[2]] = m[4] ? String.fromCodePoint(parseInt(m[4], 16)) : m[3];
  }
  return layout;
}
export const codepoints = s => [...s].map(c => `U+${c.codePointAt(0).toString(16).toUpperCase().padStart(4, '0')}`).join(' ');
