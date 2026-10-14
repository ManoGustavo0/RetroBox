-- Run with RetroBox API 2 through its permanent bootstrap.
-- Only registered callbacks execute. The extra empty game is a catalog demonstration.
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))()
local placeId = game.PlaceId > 0 and game.PlaceId or nil
local universeId = game.GameId > 0 and game.GameId or nil
local hub = RetroBox:CreateScriptHub({
    Id = "hub-demo", Title = "RetroBox / Script Hub", Theme = "Retro98", Locale = "pt-BR",
    ConfigFolder = "RetroBox/HubDemo", AutoDetectGame = true, ConfirmTeleport = true,
    Games = {
        {Id = "current", Name = "Jogo desta sessão", PlaceId = placeId, UniverseId = universeId,
            Description = "Catálogo desta sessão, com ações locais de demonstração.", Order = 1,
            Scripts = {
                {Id = "hello", Title = "Mostrar aviso", Author = "Mano Gustavo", Version = "1.0", Icon = "info",
                    Description = "Demonstra o botão Executar script e o feedback da ação concluída.",
                    Callback = function(_, activeHub) activeHub.Window:Notify({Title = "Olá!", Content = "Ação de demonstração executada."}); return {Shown = true} end},
                {Id = "managed", Title = "Operação cancelável", Author = "Mano Gustavo", Version = "1.0", Confirm = "Executar a demonstração?",
                    Description = "Três etapas simuladas, usando o runtime da library.",
                    Callback = function(ctx)
                        for step = 1, 3 do ctx:ThrowIfCancelled(); ctx:SetProgress(step, 3, "Etapa " .. step); task.wait(.1) end
                        ctx:ThrowIfCancelled(); return {Steps = 3}
                    end},
            }},
        {Id = "empty-demo", Name = "Catálogo vazio / demonstração", Order = 2,
            Description = "Exemplo sem scripts, imagem ou destino de teleporte. Cadastre identificadores reais ao adaptar o código.", Scripts = {}},
    },
})
-- Extend the same window with ordinary tabs and controls.
local section = hub.Window:CreateTab({Title = "Ferramentas", Icon = "settings"}):CreateSection("Demonstração")
section:AddButton({Title = "Abrir Command Palette", Callback = function() hub.Window:OpenCommandPalette() end})
section:AddButton({Title = "Abrir Theme Studio", Callback = function() hub.Window:OpenThemeStudio() end})
section:AddButton({Title = "Fechar Theme Studio", Callback = function() hub.Window:CloseThemeStudio() end})
hub:Show()
