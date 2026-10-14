"""Publish hub modules or declarative catalogs using the RetroBox update protocol."""
from pathlib import Path
import argparse
import hashlib
import json
import re


def version(value):
    assert re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?', value), 'Use a semantic version'
    return value


def publish(root, source, release_version, hub_id, kind, channel, rollback=None):
    if rollback:
        version(rollback)
        root = Path(root).resolve()
        manifest = json.loads((root / 'dist/releases' / rollback / 'manifest.json').read_text())
        assert manifest['HubId'] == hub_id and manifest['Version'] == rollback
        assert manifest['Kind'] == ('HubCatalog' if kind == 'catalog' else 'Hub')
        rel = Path(manifest['Artifact']['Path']); assert not rel.is_absolute() and '..' not in rel.parts
        payload = (root / rel).read_bytes()
        assert len(payload) == manifest['Artifact']['Bytes'] and hashlib.sha256(payload).hexdigest() == manifest['Artifact']['SHA256']
        assert channel != 'stable' or '-' not in rollback.split('+')[0], 'Stable cannot promote prereleases'
        target = root / 'dist/channels' / channel / ('v' + rollback.split('.')[0] + '.json')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(dict(manifest, Channel=channel), ensure_ascii=False, indent=2) + '\n')
        print(f'Rolled back {manifest["Kind"]} {channel} to {rollback}; historical artifacts preserved')
        return
    version(release_version)
    assert re.fullmatch(r'[A-Za-z0-9_.-]{1,64}', hub_id), 'Invalid HubId'
    root, source = Path(root).resolve(), Path(source).resolve()
    payload = source.read_bytes()
    suffix = 'catalog.json' if kind == 'catalog' else 'Hub.lua'
    protocol_kind = 'HubCatalog' if kind == 'catalog' else 'Hub'
    if kind == 'catalog':
        document = json.loads(payload)
        assert document['SchemaVersion'] == 1 and document['Kind'] == protocol_kind
        assert document['HubId'] == hub_id and document['Version'] == release_version
        assert isinstance(document['Games'], list) and len(document['Games']) <= 512
        ids, total = set(), 0
        for game in document['Games']:
            assert set(game) <= {'Id','Name','Description','PlaceId','UniverseId','Image','Order','Scripts'}
            assert re.fullmatch(r'[A-Za-z0-9_.-]{1,64}', game['Id']) and game['Id'] not in ids
            ids.add(game['Id']); scripts = game.get('Scripts', [])
            assert isinstance(scripts, list) and len(scripts) <= 128
            script_ids = set()
            for script in scripts:
                assert set(script) <= {'Id','Title','Description','Icon','Author','Version','Status','Enabled','CurrentGameOnly','Requires','Confirm','Action'}
                assert re.fullmatch(r'[A-Za-z0-9_.-]{1,64}', script['Id']) and script['Id'] not in script_ids
                script_ids.add(script['Id'])
            total += len(scripts)
        assert total <= 4096
    else:
        assert re.search(r'Version\s*=\s*["\']' + re.escape(release_version) + r'["\']', payload.decode())
        assert re.search(r'Start\s*=\s*function', payload.decode()), 'Hub module must return Version and Start'
    release = root / 'dist/releases' / release_version
    release.mkdir(parents=True, exist_ok=True)
    artifact = release / suffix
    if artifact.exists() and artifact.read_bytes() != payload:
        raise ValueError('Historical hub artifacts are immutable; bump Version')
    artifact.write_bytes(payload)
    manifest = {
        'SchemaVersion': 1, 'Kind': protocol_kind, 'HubId': hub_id, 'Version': release_version,
        'APIVersion': 1, 'Channel': 'pinned', 'Build': hub_id + '-' + release_version,
        'Library': {'MinVersion': '2.0.0', 'MaxVersion': '3.0.0', 'APIVersion': 2},
        'Artifact': {'Path': f'dist/releases/{release_version}/{suffix}', 'Bytes': len(payload), 'SHA256': hashlib.sha256(payload).hexdigest()},
    }
    manifest_path = release / 'manifest.json'
    encoded = json.dumps(manifest, ensure_ascii=False, indent=2) + '\n'
    if manifest_path.exists() and manifest_path.read_text() != encoded:
        raise ValueError('Historical manifests are immutable; bump Version')
    manifest_path.write_text(encoded)
    if rollback:
        version(rollback)
        manifest = json.loads((root / 'dist/releases' / rollback / 'manifest.json').read_text())
        payload = (root / manifest['Artifact']['Path']).read_bytes()
        assert hashlib.sha256(payload).hexdigest() == manifest['Artifact']['SHA256'] and len(payload) == manifest['Artifact']['Bytes']
    target = manifest['Version']
    assert channel != 'stable' or '-' not in target.split('+')[0], 'Stable cannot promote prereleases'
    selected = dict(manifest, Channel=channel)
    selected_path = root / 'dist/channels' / channel / ('v' + target.split('.')[0] + '.json')
    selected_path.parent.mkdir(parents=True, exist_ok=True)
    selected_path.write_text(json.dumps(selected, ensure_ascii=False, indent=2) + '\n')
    print(f'Published local {protocol_kind} {release_version}; {channel} resolves {target}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', required=True)
    parser.add_argument('--source', required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--hub-id', required=True)
    parser.add_argument('--kind', choices=['catalog','code'], required=True)
    parser.add_argument('--channel', choices=['stable','preview'], default='stable')
    parser.add_argument('--rollback')
    args = parser.parse_args()
    publish(args.root, args.source, args.version, args.hub_id, args.kind, args.channel, args.rollback)
