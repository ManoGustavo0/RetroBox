local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))({Channel="pinned",Version="2.0.0"})
local window=RetroBox:CreateWindow({Id="loader-pinned",Title="RetroBox / pinned",Locale="pt-BR"})
local section=window:CreateTab("Exemplo"):CreateSection("Versão carregada")
section:AddLabel({Title=RetroBox.Version.." · ".."pinned"})
