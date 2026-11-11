"""Run source checks in a Git checkout without pretending ignored backups exist."""
from pathlib import Path
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('native_tests', ROOT / 'tests/test_native.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CheckoutTests(module.NativeSourceTests):
    def test_01_original_project_unchanged(self):
        expected = json.loads((ROOT / 'tests/original-files.sha256.json').read_text())
        tracked = set(subprocess.check_output(['git', 'ls-files'], cwd=ROOT.parent, text=True).splitlines())
        checked = 0
        for name, digest in expected.items():
            if name == '.DS_Store':
                continue  # Finder metadata is mutable and never a shipping source.
            if name in tracked or (ROOT.parent / name).exists():
                self.assertEqual(hashlib.sha256((ROOT.parent / name).read_bytes()).hexdigest(), digest, name)
                checked += 1
        self.assertGreater(checked, 10)

    def test_13_regeneration_is_deterministic(self):
        # The original generator uses host-native newlines for JSON/Markdown.
        # Generate in a temporary copy, normalize those text files for comparison;
        # require exact KLC binary bytes. Never rewrite the shipping source in CI.
        import shutil
        import tempfile
        with tempfile.TemporaryDirectory() as temp:
            project = Path(temp)
            native = project / 'windows-native'
            (native / 'scripts').mkdir(parents=True)
            (native / 'source').mkdir()
            shutil.copyfile(ROOT / 'scripts/generate.py', native / 'scripts/generate.py')
            shutil.copyfile(ROOT.parent / 'bagan-full.kmn', project / 'bagan-full.kmn')
            subprocess.run([sys.executable, '-B', str(native / 'scripts/generate.py')], check=True)
            self.assertEqual((native / 'source/bgmyuni.klc').read_bytes(), (ROOT / 'source/bgmyuni.klc').read_bytes())
            for name in ('source/mapping.json', 'KEYMAP.md'):
                self.assertEqual((native / name).read_text(encoding='utf-8'), (ROOT / name).read_text(encoding='utf-8'))


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(CheckoutTests))
    raise SystemExit(not result.wasSuccessful())
