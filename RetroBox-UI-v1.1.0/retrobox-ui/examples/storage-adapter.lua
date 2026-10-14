-- Run in your executor. Update this raw URL if you move the published library.
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))()
local window = RetroBox:CreateWindow({
    Id = "storage-example",
    Title = "Configurações / Storage",
    ConfigFolder = "RetroBox/MeuScript",
    AutoSave = "last-session",
})
local section = window:CreateTab("Principal"):CreateSection("Configuração")
section:AddToggle({ Id = "enabled", Title = "Ativar", Default = false })
section:AddSlider({ Id = "volume", Title = "Volume", Min = 0, Max = 100, Default = 50 })

-- Load after all persistent controls have been created.
local ok, err = window:LoadConfig("last-session", { Silent = true })
if not ok then print("Sem perfil anterior:", err) end

print("Armazenamento:", window.StorageMode)
-- Files are automatic when readfile/writefile/makefolder exist.
-- To use session memory only, set FileStorage=false in CreateWindow.
-- To integrate your own backend, use window:SetStorage({Save=..., Load=...}).
