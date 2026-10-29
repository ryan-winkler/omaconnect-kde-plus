"""Cross-language catalog parity and bounded inventory; no user icon walk."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('appearance_catalog', ROOT/'scripts/appearance.py')
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)


class CatalogTests(unittest.TestCase):
    def test_ui_and_persistence_agree_on_presets(self):
        code = "const fs=require('fs'),vm=require('vm');const c=vm.createContext({});vm.runInContext(fs.readFileSync('Appearance.js','utf8').replace(/^\\.pragma library\\s*/,''),c);process.stdout.write(JSON.stringify(c.presets));"
        run = subprocess.run(['node','-e',code],cwd=ROOT,capture_output=True,text=True,check=True,timeout=5)
        rows = json.loads(run.stdout)
        self.assertEqual({row['value'] for row in rows}, A.PRESETS)
        self.assertEqual(len(rows),len({row['value'] for row in rows}))
        self.assertTrue({row['theme'] for row in rows}.issubset(A.PRESET_THEME_NAMES))
        self.assertEqual(len({row['glyph'] for row in rows}),len(rows))

    def test_full_bank_keeps_defaults_and_reports_truncation(self):
        files = [f'app-{index:04}.svg' for index in range(2000)]
        with patch.object(A.os,'walk',return_value=iter([('/icons',[],files)])),patch.object(A.Path,'is_dir',return_value=True):
            names,truncated = A.theme_library()
        self.assertTrue(truncated)
        self.assertEqual(len(names),1024)
        self.assertTrue(A.PRESET_THEME_NAMES.issubset(names))

    def test_xdg_user_icons_and_normal_names_are_supported(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary); icons=root/'icons'; icons.mkdir()
            (icons/'my-contributor-icon.svg').write_text('<svg/>')
            with patch.dict(os.environ,{'XDG_DATA_HOME':str(root),'XDG_DATA_DIRS':str(root/'absent')}),patch.object(A.Path,'home',return_value=root),patch.object(A.os,'walk',return_value=iter([(str(icons),[],['my-contributor-icon.svg','unsafe name.png'])])):
                names,truncated = A.theme_library()
            self.assertIn('my-contributor-icon',names)
            self.assertNotIn('unsafe name',names)
            self.assertFalse(truncated)


if __name__=='__main__': unittest.main()
