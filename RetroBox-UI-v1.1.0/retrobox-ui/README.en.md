# RetroBox UI

A standalone Luau GUI library for scripts running through Roblox client executors. Load the raw GitHub source, create components, and connect callbacks to your script.

[Português](README.md) · [API](docs/API.md) · [Runtime integration](docs/INTEGRATION.md) · [Advanced components and tools](docs/ADVANCED.md) · [GitHub publishing](docs/GITHUB.md) · [Validation](docs/VALIDATION.md)

![RetroBox visual concept](docs/visual-concept.png)

*Illustrative concept, not an in-game screenshot. The library renders native Roblox GUI objects.*

## Version 2.0.0

Permanent API 2 bootstrap, independent Stable/Preview/Pinned channels, semantic versions, SHA-256 integrity, optional cache and rollback. Hub catalogs and code modules update independently. The native hub now has a large image, compact adaptive lists, separate script selection, independent desktop panes and one **Run Script** action. Existing controls and profiles remain compatible.

[Distribution](docs/AUTO-UPDATE.md) · [Hub updates](docs/HUB-AUTO-UPDATE.md) · [Migration](docs/MIGRATION-2.0.md) · [Release report](docs/RELEASE-2.0.md)

## Version 1.9.2

Game and script descriptions in the hub now have room for their full text. Multiline labels grow with their content, width and text scale while preserving existing fields and profiles. See [RELEASE-1.9.2.md](docs/RELEASE-1.9.2.md).

## Version 1.9.1

Thirty new pixel icons bring the built-in catalog to **76**: diamonds, money, coins, tools, equipment and rewards. Each 12×12 drawing follows the window's theme and works in existing components and script hub entries. See [ICONS.md](docs/ICONS.md), [the runnable gallery](examples/icons.lua) and [RELEASE-1.9.1.md](docs/RELEASE-1.9.1.md).

## Version 1.9

Optional [Script Hub Mode](docs/SCRIPT-HUB.md) reuses the same window, recycled lists, flags, profiles, scopes and action runtime. Game/script catalogs, thumbnails, search, favorites, explicit Play/teleport and game selection are available. Detection and profile loading never execute scripts or teleport.

The command palette now activates real rows, preserves tab targets and navigates with focus. Theme Studio has a close button, previous-tab restoration and save/discard/cancel choices. The [remote distribution contract](docs/DISTRIBUTION.md) preserves HTTP/loadstring as the primary loader. See [RELEASE-1.9.md](docs/RELEASE-1.9.md).

## Version 1.8 themes

Six new official palettes: **Hacker, Dracula, Nord, Sakura, Ocean and Amber**, bringing the total to twelve. Select one in Settings or call `window:SetTheme("Hacker")`. Existing widgets update in place; profiles and editable Theme Studio copies support the new palettes.

See the [theme guide](docs/THEMES.md), [runnable gallery](examples/themes-gallery.lua) and [1.8 release report](docs/RELEASE-1.8.md).

## Pixel art identity

76 built-in 12×12 icons draw directly with native GUI rectangles and follow the theme. Use `Icon = "home"`, `"folder"`, `"palette"`, `"settings"` or another name on windows, tabs, categories and controls. Notifications and dialogs also accept Icon. Call `SetIcon(name)` to change it and `SetIcon(nil)` to remove it. Asset IDs and legacy emoji/text remain supported.

`GetIconNames()` lists the catalog, `GetIcon(name)` returns a copy of its pixel rows and `RegisterIcon(name, rows)` registers a custom pattern. The pattern supports 4–16 rows and columns; see the [icon guide](docs/ICONS.md) for names, theme characters and validation.

Default icons appear in the title, tabs/categories, search, settings, window actions, checkboxes/dropdowns and status dialogs. Appearance settings expose `PixelIcons` and `PixelDecorations`, both true by default. These preferences are saved and reset; disabling defaults preserves icons explicitly chosen by the developer. Existing saves without the new fields remain compatible.

![RetroBox pixel icon catalog](docs/pixel-icons.png)

[icons.lua](examples/icons.lua) demonstrates the catalog, selection, custom pixel art and notification/dialog integration. The [SVG exports](assets/pixel-icons) are for design/documentation; runtime icons are embedded in RetroBox.lua.

## Load

Use this repository's published source path. Adjust the URL if you host the library elsewhere:

```lua
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))()
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
- Twelve themes, custom palettes, accent colors, UI scale and optional CRT scanlines.
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

## Managed runtime

Version 1.5 adds live stat cards and Line/Bar/Progress/Sparkline charts, bounded histories, pooled geometry, resource scopes, idempotent periodic tasks, cancellable actions and execution groups. Shared states, bindings, All/Any/Not dependencies and batch flag updates coordinate the interface. A central animator respects ReducedMotion; animation/drag preferences round-trip through existing profiles. Collapsible sections, protected background callbacks and bounded Debug diagnostics complete the update.

Hiding/minimizing preserves work by default. Destroy cleans managed resources; long-running callbacks must cooperate with cancellation. See [the runtime guide](docs/RUNTIME.md) and [dashboard.lua](examples/dashboard.lua) for simulated data and a complete integration.

Version 1.6 adds event-driven `AwaitAction` / `handle:Await` / `ctx:AwaitAction`, optional timeout and independent wait/action cancellation. Periodic tasks accept Group/Policy and reuse the action exclusion manager, with one pending iteration and an interval measured after completion. `Task.Status`, `GetStatus` and `Subscribe` expose requested/effective phases, deadlines, results and errors; `toggle:BindTask(job)` synchronizes activation and external stops.

CreateWindow accepts a script-specific ConfigVersion and sequential Migrations, applied to a copy before validating or changing any controls. UnknownFlags supports Ignore/Preserve/Reject. See [INTEGRATION.md](docs/INTEGRATION.md) and [runtime-integration.lua](examples/runtime-integration.lua) for contracts and simulated collection/selling.

Window dragging directly follows mouse/touch deltas. The UI launcher is draggable by its body or :: handle, with click suppression after movement. Hide/show and minimize/restore preserve tabs, Settings and scroll; the body immediately hides all content, including the search icon, while minimized. Editable fields share 12 px horizontal padding.

## Version 1.7

Styles now retain native Instance references until explicit cleanup; backgrounds update before ink is resolved against each actual surface. Cards, plot captions, consoles, help and wide tables follow theme changes. Progress percentages use aligned clipped copies over the filled/unfilled regions. Official themes remain distinct.

AddVirtualList, AddDataTable and AddTreeView share recycled rows with bounded allocation. Context menus support keyboard, submenus and long touch. CreateDashboard moves/resizes existing widgets, with optional layout editing and profile persistence. Theme Studio offers real previews, protected official palettes and a local JSON/profile catalog. LoadThemeCatalog changes themes without replaying script flags.

The optional Runtime Inspector subscribes to existing status, uses a low-frequency clock and requires explicit permission plus confirmation for cancellation. Command Palette (F4 by default) reuses search/navigation and runs only explicitly registered commands. Descriptions reflow, tooltips have an info button and .2 s default delay, and Settings adds help/text-scale/key preferences and confirmed profile deletion.

See [ADVANCED.md](docs/ADVANCED.md) for the exact API and limits. The seven new examples require 1.7.0 at the source URL or a pinned PR commit.

## Tooltips

Pass `Tooltip = "Your explanation"` or `{Title = "Help", Text = "Your explanation", Delay = 0.4, MaxWidth = 320}` to a control. `Tip` is an alias. Hover opens the tip after 0.2 seconds by default. On touch devices, long-press the title or description, then tap the tip or elsewhere to dismiss it. Reading a tip does not run the control's callback.

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

Keep stable window and control IDs and a stable config folder. Create controls, tasks, bindings and migrations before calling `window:LoadConfig("default")`. AutoSave does not automatically load. Loading calls callbacks unless `{Silent=true}` is supplied. Silent loading preserves observers and bindings: a toggle with BindTask can start its task after the whole batch applies. Profiles contain configuration rather than running workers or task status.

The built-in Settings tab lists named saves and restores values, key/mouse assignments, colors, appearance and floating positions. A profile index preserves the list between executions without requiring listfiles. Optional listfiles discovers older saves; custom adapters can supply `List()`. Memory-only saves last while the window remains open. Loading a profile replays callbacks after applying values; keybind assignment does not execute its action.

```lua
local ok, result = window:SaveConfig("default")
local restored, err = window:LoadConfig("default")
local json = window:ExportConfig()
window:ImportConfig(json)
print(window.StorageMode) -- file, memory or custom
```

## Examples and testing

[Quick start](examples/quickstart.lua), [full showcase](examples/showcase.lua), [custom theme](examples/custom-theme.lua), [storage](examples/storage-adapter.lua), [tooltips](examples/tooltips.lua), [workflows](examples/workflows.lua), [pixel icons](examples/icons.lua), [live dashboard](examples/dashboard.lua), [runtime integration](examples/runtime-integration.lua), and [contrast showcase](examples/contrast-showcase.lua), [advanced datasets](examples/advanced-components.lua), [Theme Studio](examples/theme-studio.lua), [Runtime Inspector](examples/runtime-inspector.lua), [Dashboard Builder](examples/dashboard-builder.lua), [Command Palette](examples/command-palette.lua), [help/accessibility](examples/help-accessibility.lua), and [native executor smoke test](tests/executor-smoke.lua). Their URLs use the existing source path. Dashboard/integration require version 1.6.0 there; use the PR commit before merge or adjust URLs if you move the source.

221 local logic tests passed, including 19 examples, yielding workers, scheduler races, migrations and simulated drag geometry. These tests use a Lua 5.4 engine double and simulated HTTP/filesystem capabilities. A real Roblox executor was unavailable; rendering and specific executor compatibility, including Unbound, remain unverified. See [validation](docs/VALIDATION.md).

MIT · Mano Gustavo · 2026
