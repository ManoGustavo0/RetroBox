"""Exercise channel promotion, immutable history and rollback in isolated checkouts."""
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name, PROJECT / 'tools' / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class ReleasePipeline(unittest.TestCase):
    def test_library_channels_immutability_and_rollback_with_dirty_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project = root / 'RetroBox-UI-v1.1.0/retrobox-ui'
            project.mkdir(parents=True)
            shutil.copytree(PROJECT / 'src', project / 'src')
            original = (PROJECT / 'RetroBox.lua').read_text()
            (project / 'RetroBox.lua').write_text(original)
            build = module('build_distribution')
            build.ROOT, build.REPOSITORY, build.DIST = project, root, root / 'dist'
            build.build('stable')
            old_bytes = (build.DIST / 'releases/2.0.0/RetroBox.lua').read_bytes()
            (project / 'RetroBox.lua').write_text(original.replace('2.0.0', '2.0.1', 2))
            build.build('preview')
            self.assertEqual(json.loads((build.DIST / 'channels/stable/v2.json').read_text())['Version'], '2.0.0')
            self.assertEqual(json.loads((build.DIST / 'channels/preview/v2.json').read_text())['Version'], '2.0.1')
            build.build('stable')
            source = (project / 'RetroBox.lua').read_text() + '\n-- unpublished local edit\n'
            (project / 'RetroBox.lua').write_text(source)
            with self.assertRaises(ValueError):
                build.build('stable')
            build.build('stable', '2.0.0')
            self.assertEqual(json.loads((build.DIST / 'channels/stable/v2.json').read_text())['Version'], '2.0.0')
            self.assertEqual((build.DIST / 'releases/2.0.0/RetroBox.lua').read_bytes(), old_bytes)
            self.assertGreaterEqual(module('verify_distribution').verify(build.DIST), 4)

    def test_hub_code_and_catalog_promote_and_rollback_independently(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            build = module('build_hub_release')
            code = root / 'Hub.lua'; code.write_text('return {Version="1.0.0",Start=function() end}')
            data = root / 'catalog.json'; document = {'SchemaVersion':1,'Kind':'HubCatalog','HubId':'test','Version':'1.0.0','Games':[]}
            data.write_text(json.dumps(document))
            build.publish(root / 'code', code, '1.0.0', 'test', 'code', 'stable')
            build.publish(root / 'catalog', data, '1.0.0', 'test', 'catalog', 'stable')
            code.write_text('return {Version="1.1.0",Start=function() return true end}')
            build.publish(root / 'code', code, '1.1.0', 'test', 'code', 'stable')
            self.assertEqual(json.loads((root / 'catalog/dist/channels/stable/v1.json').read_text())['Version'], '1.0.0')
            document['Version'] = '1.2.0'; data.write_text(json.dumps(document))
            build.publish(root / 'catalog', data, '1.2.0', 'test', 'catalog', 'preview')
            self.assertEqual(json.loads((root / 'catalog/dist/channels/stable/v1.json').read_text())['Version'], '1.0.0')
            code.write_text('return {Version="1.1.0",Start=function() error("dirty") end}')
            with self.assertRaises(ValueError):
                build.publish(root / 'code', code, '1.1.0', 'test', 'code', 'stable')
            build.publish(root / 'code', code, '1.1.0', 'test', 'code', 'stable', '1.0.0')
            self.assertEqual(json.loads((root / 'code/dist/channels/stable/v1.json').read_text())['Version'], '1.0.0')


if __name__ == '__main__':
    unittest.main()
