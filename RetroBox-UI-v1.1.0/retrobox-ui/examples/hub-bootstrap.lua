-- Published demonstration origins in this repository; all game data is fictitious.
local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))()
local base="https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/examples/hub-distribution/"
local hub,report=RetroBox:LoadHub({Root=base.."code",HubId="hub-update-demo",Major=1,APIVersion=1,Cache=true,
    Settings={CatalogRoot=base.."catalog"}})
assert(hub,report)
hub:Show()
