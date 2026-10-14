local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))({Channel="stable"})
local window=RetroBox:CreateWindow({Id="loader-stable",Title="RetroBox / stable",Locale="pt-BR"})
local section=window:CreateTab("Exemplo"):CreateSection("Versão carregada")
section:AddLabel({Title=RetroBox.Version.." · ".."stable"})
