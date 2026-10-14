"""Build deterministic standalone update artifacts; never edit historical releases."""
from pathlib import Path
import argparse
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = ROOT.parent.parent if ROOT.parent.name == 'RetroBox-UI-v1.1.0' else ROOT.parent
DIST = REPOSITORY / 'dist'
START = '-- BEGIN RETRO200 UPDATE CORE'
END = '-- END RETRO200 UPDATE CORE'


def embed():
    core = (ROOT / 'src/UpdateCore.lua').read_text()
    api = (ROOT / 'src/UpdateAPI.lua').read_text()
    embedded = START + '\nlocal UpdateCore=(function()\n' + core + '\nend)()\n' + api + '\n' + END
    source_path = ROOT / 'RetroBox.lua'
    source = source_path.read_text()
    if START in source:
        source = source[:source.index(START)] + embedded + source[source.index(END) + len(END):]
    else:
        marker = '-- BEGIN RETRO190 SCRIPT HUB'
        assert marker in source
        source = source.replace(marker, embedded + '\n\n' + marker, 1)
    hub_start, hub_end = '-- BEGIN RETRO200 HUB UPDATES', '-- END RETRO200 HUB UPDATES'
    hub_code = hub_start + '\n' + (ROOT / 'src/HubUpdates.lua').read_text() + '\n' + hub_end
    if hub_start in source:
        source = source[:source.index(hub_start)] + hub_code + source[source.index(hub_end) + len(hub_end):]
    else:
        marker = '    function Window:CreateScriptHub(options)'
        assert marker in source
        source = source.replace(marker, hub_code + '\n' + marker, 1)
    source_path.write_text(source)
    bootstrap = ('-- RetroBox permanent bootstrap v2. No local file or ModuleScript required.\n'
                 '-- Configure with loadstring(game:HttpGet(LOADER_URL))({Channel="stable"}).\n'
                 'local Core=(function()\n' + core + '\nend)()\n'
                 'local supplied=...\nassert(supplied==nil or type(supplied)=="table","[RetroBox] Loader options must be a table")\n'
                 'local options={}; for k,v in pairs(supplied or {}) do options[k]=v end\n'
                 'options.Kind="RetroBox"; options.Major=2; options.APIVersion=2\n'
                 'options.MinVersion=options.MinVersion or "2.0.0"\n'
                 'options.MaxVersion=options.MaxVersion or "3.0.0"\n'
                 'local updater=Core.New(options)\n'
                 'local library,report=updater:Load()\n'
                 'assert(library,"[RetroBox] Could not load the configured release: "..tostring(report))\n'
                 'library.Distribution=report; library._distributionUpdater=updater\n'
                 'return library,report\n')
    (ROOT / 'Loader.lua').write_text(bootstrap)
    DIST.mkdir(exist_ok=True)
    (DIST / 'Loader.lua').write_text(bootstrap)
    (DIST / 'bootstrap').mkdir(exist_ok=True)
    (DIST / 'bootstrap/v2.lua').write_text(bootstrap)
    return source


def write_json(path, value, immutable=False):
    payload = json.dumps(value, ensure_ascii=False, indent=2) + '\n'
    path.parent.mkdir(parents=True, exist_ok=True)
    if immutable and path.exists() and path.read_text() != payload:
        raise ValueError(f'Refusing to overwrite historical metadata: {path}')
    path.write_text(payload)


def build(channel='stable', rollback=None):
    if rollback:
        assert re.fullmatch(r'2\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?', rollback), 'Rollback must name an existing API 2 release'
        manifest = json.loads((DIST / 'releases' / rollback / 'manifest.json').read_text())
        assert manifest['Kind'] == 'RetroBox' and manifest['Version'] == rollback and manifest['APIVersion'] == 2
        rel = Path(manifest['Artifact']['Path'])
        assert not rel.is_absolute() and '..' not in rel.parts
        payload = (REPOSITORY / rel).read_bytes()
        assert len(payload) == manifest['Artifact']['Bytes'] and hashlib.sha256(payload).hexdigest() == manifest['Artifact']['SHA256']
        assert channel != 'stable' or '-' not in rollback.split('+')[0], 'Stable cannot promote prereleases'
        write_json(DIST / 'channels' / channel / 'v2.json', dict(manifest, Channel=channel))
        alias = DIST / channel / 'v2/RetroBox.lua'; alias.parent.mkdir(parents=True, exist_ok=True); alias.write_bytes(payload)
        print(f'Rolled back {channel}/v2 to {rollback}; historical artifacts preserved')
        return
    source = embed()
    version = re.search(r'local Library = \{ Version = "([^"]+)"', source)[1]
    assert version.split('.')[0] == '2', 'This builder publishes API 2 releases'
    release = DIST / 'releases' / version
    release.mkdir(parents=True, exist_ok=True)
    artifact = release / 'RetroBox.lua'
    payload = source.encode()
    if artifact.exists() and artifact.read_bytes() != payload:
        raise ValueError(f'Refusing to change immutable {version}; bump Version first')
    artifact.write_bytes(payload)
    manifest = {
        'SchemaVersion': 1, 'Kind': 'RetroBox', 'Version': version,
        'APIVersion': 2, 'Build': 'retrobox-' + version, 'Channel': 'pinned',
        'Artifact': {'Path': f'dist/releases/{version}/RetroBox.lua',
                     'SHA256': hashlib.sha256(payload).hexdigest(), 'Bytes': len(payload)},
    }
    write_json(release / 'manifest.json', manifest, immutable=True)
    target = version
    if rollback:
        manifest = json.loads((DIST / 'releases' / rollback / 'manifest.json').read_text())
        target = rollback
        payload = (DIST / manifest['Artifact']['Path'].removeprefix('dist/')).read_bytes()
        assert len(payload) == manifest['Artifact']['Bytes']
        assert hashlib.sha256(payload).hexdigest() == manifest['Artifact']['SHA256']
    major = target.split('.')[0]
    if channel == 'stable' and '-' in target.split('+')[0]:
        raise ValueError('Stable cannot promote a prerelease')
    selected = dict(manifest, Channel=channel)
    write_json(DIST / 'channels' / channel / ('v' + major + '.json'), selected)
    alias = DIST / channel / ('v' + major) / 'RetroBox.lua'
    alias.parent.mkdir(parents=True, exist_ok=True)
    alias.write_bytes(payload)
    history_path = DIST / 'history.json'
    history = json.loads(history_path.read_text()) if history_path.exists() else {'SchemaVersion': 1, 'Releases': []}
    if version not in [r['Version'] for r in history['Releases']]:
        history['Releases'].append({'Version': version, 'Manifest': f'dist/releases/{version}/manifest.json'})
    write_json(history_path, history)
    print(f'Built {version}; {channel}/v{major} resolves {target}; {len(payload)} verified bytes')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--channel', choices=['stable', 'preview'], default='stable')
    parser.add_argument('--rollback', help='Existing immutable release to promote instead of current source')
    parser.add_argument('--embed-only', action='store_true')
    args = parser.parse_args()
    if args.embed_only:
        embed()
    else:
        build(args.channel, args.rollback)
