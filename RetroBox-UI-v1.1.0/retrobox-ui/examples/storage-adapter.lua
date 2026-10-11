-- Replace SEU_USUARIO and the repository/branch in the raw URL. Run in your executor.
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/SEU_USUARIO/retrobox-ui/main/RetroBox.lua"))()
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
