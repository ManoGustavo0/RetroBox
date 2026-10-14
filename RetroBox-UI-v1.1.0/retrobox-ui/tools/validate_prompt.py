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
    assert url == 'https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua', "Use the permanent API 2 bootstrap"
    example = prompt[prompt.index('Exemplo funcional de montagem da interface'):]
    chunk = re.search(r'```lua\n(.*?)```', example, re.S).group(1)
    assert "game:HttpGet(" in chunk and "loadstring(" in chunk, "HTTP/loadstring must remain the primary loader"
    assert not re.search(r'\breadfile\s*\(|\brequire\s*\(', chunk), "The primary example must not require a local file or ModuleScript"
    order = [chunk.index("game:HttpGet("), chunk.index("Library:CreateWindow("), chunk.index("window:CreateTab("), chunk.index("tab:CreateSection("), chunk.index("section:Add")]
    assert order == sorted(order), "Keep loader -> window -> tab -> section -> controls"
    assert 'Library.APIVersion ~= 2' in chunk, "Primary example must accept compatible API 2 releases"
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
    assert 'options.Major=2; options.APIVersion=2' in loader, "Bootstrap compatibility guard is stale"
    print("Remote distribution contract passed for RetroBox " + version)
    print(url)
