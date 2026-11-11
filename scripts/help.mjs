import fs from 'node:fs';
import { marked } from 'marked';
fs.writeFileSync('README.htm', '<!doctype html><html lang="en"><meta charset="utf-8"><title>Bagan Style Myanmar — installation and typing</title><style>body{font:16px system-ui,sans-serif;max-width:900px;margin:2em auto;padding:1em;line-height:1.6}table{border-collapse:collapse}td,th{border:1px solid #aaa;padding:.4em}</style><body>' + marked.parse(fs.readFileSync('README.md', 'utf8')) + '</body></html>');
