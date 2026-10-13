-- RetroBox 1.7.0+: the editor uses actual controls and normal profile storage.
local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"))()
local window=RetroBox:CreateWindow({Id="theme-studio-demo",Title="RetroBox / Theme Studio",ConfigFolder="RetroBox/ThemeStudioDemo",ThemeStudio=true})
-- Official palettes are read only in the editor. Give a variation a name and
-- create it before editing. Save the catalog in a normal named profile.
-- LoadThemeCatalog loads only the catalog, without replaying script flags.
-- Export/import JSON never executes code. ImportTheme rejects official names.
