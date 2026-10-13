"""Check the permanent remote-loader contract before delivering an AI prompt.

Network verification is separate: compare the downloaded raw source/version to
the published Git tree, then execute the extracted example in the logic runner.
"""
import argparse
from pathlib import Path
import re

def validate(prompt, source, commit=None):
    version = re.search(r'Version = "([^"]+)"', source).group(1)
    raw = re.search(r'local (?:RAW|RETROBOX_URL) = "([^"]+)"', prompt)
    assert raw, "The primary example must start with a remote raw URL"
    url = raw.group(1)
    match = re.fullmatch(r'https://raw\.githubusercontent\.com/ManoGustavo0/RetroBox/([a-f0-9]{40})/RetroBox-UI-v1\.1\.0/retrobox-ui/RetroBox\.lua', url)
    assert match, "Use a real pinned release commit and the historical source path"
    if commit:
        assert match.group(1) == commit, "Prompt does not use the verified release commit"
    chunk = re.search(r'```lua\n(.*?)```', prompt, re.S).group(1)
    assert "game:HttpGet(" in chunk and "loadstring(" in chunk, "HTTP/loadstring must remain the primary loader"
    assert not re.search(r'\breadfile\s*\(|\brequire\s*\(', chunk), "The primary example must not require a local file or ModuleScript"
    order = [chunk.index("game:HttpGet("), chunk.index("Library:CreateWindow("), chunk.index("window:CreateTab("), chunk.index("tab:CreateSection("), chunk.index("section:Add")]
    assert order == sorted(order), "Keep loader -> window -> tab -> section -> controls"
    assert f'Library.Version ~= "{version}"' in chunk, "Primary example checks the wrong version"
    assert f'Fontes de referência da versão {version}' in prompt, "Prompt header checks the wrong version"
    # APIs in the runnable example must exist; executing it catches aliases too.
    declared = set(re.findall(r'function\s+[\w.]+:([A-Za-z_]\w*)\s*\(', source))
    for method in re.findall(r'\b(?:Library|window|tab|section):([A-Za-z_]\w*)\(', chunk):
        assert method in declared, "Primary example calls an unknown API: " + method
    return version, url

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--prompt", type=Path, required=True)
    parser.add_argument("--commit")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    version, url = validate(args.prompt.read_text(), (root / "RetroBox.lua").read_text(), args.commit)
    loader = (root / "Loader.lua").read_text()
    assert f'EXPECTED_VERSION = "{version}"' in loader, "Diagnostic loader version is stale"
    print("Remote distribution contract passed for RetroBox " + version)
    print(url)
