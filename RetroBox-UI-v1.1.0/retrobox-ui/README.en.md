# RetroBox UI

A standalone Luau GUI library for scripts running through Roblox client executors. Load the raw GitHub source, create components, and connect callbacks to your script.

[Português](README.md) · [API](docs/API.md) · [GitHub publishing](docs/GITHUB.md) · [Validation](docs/VALIDATION.md)

![RetroBox visual concept](docs/visual-concept.png)

*Illustrative concept, not an in-game screenshot. The library renders native Roblox GUI objects.*

## Load

Use this repository's published source path. Adjust the URL if you host the library elsewhere:

```lua
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"))()
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
    Tooltip = "Explain what this feature does in your script.",
    Callback = function(value) print("Enabled:", value) end,
})
```

The executor needs `loadstring` and `game:HttpGet`. [Loader.lua](Loader.lua) adds diagnostic messages. `RetroBox.lua` is self-contained and downloads no additional code.

## Features

- Retro beveled windows; drag, resize, minimize, maximize and RightShift visibility shortcut.
- Automatic LocalPlayer avatar, display name and username at the bottom left, beside the settings gear.
- Six themes, custom palettes, accent colors, UI scale and optional CRT scanlines.
- Tabs, sections, search, responsive columns and touch input.
- Built-in Settings tab with named saves, a persistent profile list and overwrite confirmation.
- Search results navigate to the matching tab/control without running its action.
- Toggle, slider, button, input, single/multi dropdown, keybind, color picker, progress, console, label, separator and image.
- Optional tooltips on every control: mouse hover or a long press on its title/description on touch devices.
- HSV/RGB/HEX colors, opacity, and rainbow animation with configurable seconds per cycle.
- Notifications, protected callbacks, state getters/setters, listeners and event cleanup.
- Retro dialogs, confirmations, button busy state and optional success/error feedback.
- Keyboard/Mouse 1–3 capture, inline toggle keybinds, responsive control rows and draggable touch shortcuts.
- JSON profiles, optional debounced AutoSave, automatic executor file storage and custom adapters.

## Tooltips

Pass `Tooltip = "Your explanation"` or `{Title = "Help", Text = "Your explanation", Delay = 0.4, MaxWidth = 320}` to a control. `Tip` is an alias. Hover opens the tip after 0.4 seconds by default. On touch devices, long-press the title or description, then tap the tip or elsewhere to dismiss it. Reading a tip does not run the control's callback.

Use `control:SetTooltip(...)` to change it, `GetTooltip()` to read a copy, `ShowTooltip()` / `HideTooltip()` to open or close it, and `SetTooltip(nil)` to remove it. Tips follow the theme and fit within the viewport. See the [tooltip example](examples/tooltips.lua) and [API options](docs/API.md#tooltip).

## Inline keybinds and touch shortcuts

```lua
local control = section:AddToggle({
    Id = "feature", Title = "Enable feature",
    Keybind = { Default = Enum.UserInputType.MouseButton2, Mode = "Toggle" },
    Floating = { Text = "FEATURE", Position = Vector2.new(.04,.65) },
    Callback = function(enabled) print(enabled) end,
})
```

Click the binding field and press a keyboard key or mouse button. Escape cancels; Backspace clears. Hold enables while pressed; Toggle switches state. `control.Keybind` exposes the binding control. Touch shortcuts appear while the menu is hidden/minimized; drag their `::` bar to reposition them.

X hides the window by default. RightShift or the draggable `UI` launcher reopens it. Settings lets players change the window shortcut, launcher text, shortcut size/opacity and visibility. `DestroyOnClose=true` opts into destructive closing.

Use `section:CreateRow()` for controls on one responsive row, `window:Confirm(...)` / `Dialog(...)` for modals, and `Feedback=true` on buttons for success/error notices. See [workflows.lua](examples/workflows.lua) and the [API](docs/API.md).

## Executor integration

The default GUI mount order is `gethui()` → `CoreGui` → `PlayerGui`, with permission failures handled before fallback. An explicit `Parent` overrides detection. `window.ParentMode` reports the selected root.

File profiles are enabled automatically when `readfile`, `writefile` and `makefolder` are present. `isfile` and `isfolder` are optional. `ConfigFolder` is relative to the executor workspace; folders are created only when saving. Without the required file functions, profiles remain in session memory. Use `FileStorage=false` for memory only, or supply `Storage.Save/Load` to override the automatic adapter.

Keep stable window and control IDs and a stable config folder. Create all controls before calling `window:LoadConfig("default")`. AutoSave does not automatically load. Loading calls callbacks unless `{Silent=true}` is supplied. With silent loading, synchronize your script through `GetFlag`.

The built-in Settings tab lists named saves and restores values, key/mouse assignments, colors, appearance and floating positions. A profile index preserves the list between executions without requiring listfiles. Optional listfiles discovers older saves; custom adapters can supply `List()`. Memory-only saves last while the window remains open. Loading a profile replays callbacks after applying values; keybind assignment does not execute its action.

```lua
local ok, result = window:SaveConfig("default")
local restored, err = window:LoadConfig("default")
local json = window:ExportConfig()
window:ImportConfig(json)
print(window.StorageMode) -- file, memory or custom
```

## Examples and testing

[Quick start](examples/quickstart.lua), [full showcase](examples/showcase.lua), [custom theme](examples/custom-theme.lua), [storage](examples/storage-adapter.lua), [tooltips](examples/tooltips.lua), [workflows](examples/workflows.lua), and [native executor smoke test](tests/executor-smoke.lua). Their URLs use this repository's existing source path. Publish version 1.3.0 or later there before running the updated examples; update the URLs if you move the source.

72 local logic tests passed. These tests use a Lua 5.4 engine double and simulated HTTP/filesystem capabilities. A real Roblox executor was unavailable; rendering and specific executor compatibility, including Unbound, remain unverified. See [validation](docs/VALIDATION.md).

MIT · Mano Gustavo · 2026
