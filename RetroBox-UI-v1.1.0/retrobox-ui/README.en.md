# RetroBox UI

A standalone Luau GUI library for scripts running through Roblox client executors. Load the raw GitHub source, create components, and connect callbacks to your script.

[Português](README.md) · [API](docs/API.md) · [GitHub publishing](docs/GITHUB.md) · [Validation](docs/VALIDATION.md)

![RetroBox visual concept](docs/visual-concept.png)

*Illustrative concept, not an in-game screenshot. The library renders native Roblox GUI objects.*

## Load

Replace the GitHub username, repository and branch:

```lua
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/retrobox-ui/main/RetroBox.lua"))()
local window = RetroBox:CreateWindow({
    Id = "my-script",
    Title = "My script",
    Theme = "Retro98",
    Locale = "en-US",
    ConfigFolder = "RetroBox/MyScript",
})
local section = window:CreateTab("Main"):CreateSection("Controls")
section:AddToggle({
    Id = "enabled", Title = "Enable", Default = false,
    Callback = function(value) print("Enabled:", value) end,
})
```

The executor needs `loadstring` and `game:HttpGet`. [Loader.lua](Loader.lua) adds diagnostic messages. `RetroBox.lua` is self-contained and downloads no additional code.

## Features

- Retro beveled windows; drag, resize, minimize, maximize and RightShift visibility shortcut.
- Automatic LocalPlayer avatar, display name and username at the bottom left, beside the settings gear.
- Six themes, custom palettes, accent colors, UI scale and optional CRT scanlines.
- Tabs, sections, search, responsive columns and touch input.
- Toggle, slider, button, input, single/multi dropdown, keybind, color picker, progress, console, label, separator and image.
- HSV/RGB/HEX colors, opacity, and rainbow animation with configurable seconds per cycle.
- Notifications, protected callbacks, state getters/setters, listeners and event cleanup.
- JSON profiles, optional debounced AutoSave, automatic executor file storage and custom adapters.

## Executor integration

The default GUI mount order is `gethui()` → `CoreGui` → `PlayerGui`, with permission failures handled before fallback. An explicit `Parent` overrides detection. `window.ParentMode` reports the selected root.

File profiles are enabled automatically when `readfile`, `writefile` and `makefolder` are present. `isfile` and `isfolder` are optional. `ConfigFolder` is relative to the executor workspace; folders are created only when saving. Without the required file functions, profiles remain in session memory. Use `FileStorage=false` for memory only, or supply `Storage.Save/Load` to override the automatic adapter.

Keep stable window and control IDs and a stable config folder. Create all controls before calling `window:LoadConfig("default")`. AutoSave does not automatically load. Loading calls callbacks unless `{Silent=true}` is supplied. With silent loading, synchronize your script through `GetFlag`.

```lua
local ok, result = window:SaveConfig("default")
local restored, err = window:LoadConfig("default")
local json = window:ExportConfig()
window:ImportConfig(json)
print(window.StorageMode) -- file, memory or custom
```

## Examples and testing

[Quick start](examples/quickstart.lua), [full showcase](examples/showcase.lua), [custom theme](examples/custom-theme.lua), [storage](examples/storage-adapter.lua), and [native executor smoke test](tests/executor-smoke.lua). Replace `SEU_USUARIO` in their URLs before running.

41 local logic tests passed. These tests use a Lua 5.4 engine double and simulated HTTP/filesystem capabilities. A real Roblox executor was unavailable; rendering and specific executor compatibility, including Unbound, remain unverified. See [validation](docs/VALIDATION.md).

MIT · Mano Gustavo · 2026
