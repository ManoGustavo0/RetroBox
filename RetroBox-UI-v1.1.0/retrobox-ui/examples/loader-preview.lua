local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))({Channel="preview"})
local window=RetroBox:CreateWindow({Id="loader-preview",Title="RetroBox / preview",Locale="pt-BR"})
local section=window:CreateTab("Exemplo"):CreateSection("Versão carregada")
section:AddLabel({Title=RetroBox.Version.." · ".."preview"})
