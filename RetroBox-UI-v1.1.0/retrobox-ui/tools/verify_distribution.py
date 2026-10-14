"""Independently verify release bytes, channel aliases and manifest paths."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent.parent if ROOT.parent.name == 'RetroBox-UI-v1.1.0' else ROOT.parent


def verify(folder):
    count = 0
    for file in sorted(folder.rglob('*.json')):
        manifest = json.loads(file.read_text())
        if not isinstance(manifest, dict) or 'Artifact' not in manifest:
            continue
        artifact = manifest['Artifact']
        assert manifest['SchemaVersion'] == 1 and manifest['Kind'] in {'RetroBox','Hub','HubCatalog'}
        rel = artifact['Path']
        assert re.fullmatch(r'[A-Za-z0-9_./-]+', rel) and not rel.startswith('/') and '..' not in Path(rel).parts
        # Each manifest resolves against its publisher's root, before /dist/.
        publisher = file
        while publisher.name != 'dist':
            publisher = publisher.parent
            assert publisher != publisher.parent, f'No distribution root: {file}'
        publisher = publisher.parent
        payload = (publisher / rel).read_bytes()
        assert len(payload) == artifact['Bytes'], f'Wrong length: {file}'
        assert hashlib.sha256(payload).hexdigest() == artifact['SHA256'], f'Wrong digest: {file}'
        assert re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?', manifest['Version'])
        if manifest['Channel'] == 'stable':
            assert '-' not in manifest['Version'].split('+')[0], f'Prerelease on Stable: {file}'
        if manifest['Kind'] == 'RetroBox':
            declared = re.search(rb'local Library = \{ Version = "([^"]+)"', payload)[1].decode()
            assert declared == manifest['Version'] and manifest['APIVersion'] == 2
            if '/channels/' in file.as_posix():
                alias = publisher / 'dist' / manifest['Channel'] / ('v' + declared.split('.')[0]) / 'RetroBox.lua'
                assert alias.read_bytes() == payload, f'Channel alias differs: {alias}'
        elif manifest['Kind'] == 'HubCatalog':
            data = json.loads(payload)
            assert data['Version'] == manifest['Version'] and data['HubId'] == manifest['HubId'] and data['Kind'] == 'HubCatalog'
        else:
            assert re.search(rb'Version\s*=\s*["\']' + re.escape(manifest['Version']).encode() + rb'["\']', payload)
        count += 1
    return count


if __name__ == '__main__':
    count = verify(REPO / 'dist') + verify(ROOT / 'examples/hub-distribution')
    assert count >= 7, 'Library and demonstration channels have not been built'
    assert (REPO / 'dist/bootstrap/v2.lua').read_bytes() == (ROOT / 'Loader.lua').read_bytes()
    print(f'{count} distribution manifests verified with Python hashlib; aliases and versions match')
