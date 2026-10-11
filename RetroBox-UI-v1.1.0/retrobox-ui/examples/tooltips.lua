-- Replace this file's URL if you publish the library somewhere else.
-- Requires the updated RetroBox.lua (version 1.2.0+) at the published path.
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"))()

local window = RetroBox:CreateWindow({
    Id = "tooltip-showcase", Title = "RetroBox / Tooltips",
    Subtitle = "Passe o mouse; no celular, segure o título ou a descrição.",
    TooltipDelay = .4, TooltipMaxWidth = 320,
})
local section = window:CreateTab("Ajuda"):CreateSection("Explicações configuráveis")
local control = section:AddToggle({
    Id = "enabled", Title = "Ativar recurso",
    Description = "Esta descrição continua visível.",
    Tooltip = "Esta dica aparece ao passar o mouse. O dev escreve aqui o que a função faz.",
    Callback = function(enabled) print("Seu script recebeu:", enabled) end,
})
section:AddSlider({
    Id = "amount", Title = "Intensidade", Min = 0, Max = 100, Default = 50,
    Tooltip = { Title = "Como ajustar", Text = "Arraste a barra ou digite um valor.\nO callback recebe o número escolhido.", Delay = .25, MaxWidth = 300 },
})
section:AddButton({
    Title = "Mudar o texto da dica",
    Tooltip = "As dicas também podem ser atualizadas depois de criar os controles.",
    Callback = function() control:SetTooltip("Texto atualizado pelo seu código.") end,
})
section:AddButton({
    Title = "Abrir a dica por código",
    Tip = "Tip também é aceito como nome da opção Tooltip.",
    Callback = function() control:ShowTooltip() end,
})
-- control:SetTooltip(nil) removes it. GetTooltip() returns a copy of its options.
