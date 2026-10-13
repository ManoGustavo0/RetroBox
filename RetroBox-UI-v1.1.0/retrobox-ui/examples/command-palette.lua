-- RetroBox 1.7.0+: navigation + explicitly registered managed commands.
local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"))()
local window=RetroBox:CreateWindow({Id="command-palette-demo",Title="RetroBox / Comandos",CommandKey=Enum.KeyCode.F4})
local s=window:CreateTab("Exemplo"):CreateSection("Componentes")
s:AddToggle({Id="option",Title="Opção de exemplo",Tooltip="A busca navega até aqui sem ativar a opção."})
s:AddInput({Id="name",Title="Nome",Default="Exemplo"})
window:RegisterCommand({Id="message",Title="Mostrar mensagem",Description="Aviso de demonstração",Icon="notification",Callback=function(ctx)
    ctx:ThrowIfCancelled(); window:Notify({Content="Comando selecionado explicitamente."}); return true
end})
window:RegisterCommand({Id="reset",Title="Restaurar preferências",Icon="reset",Confirm="Restaurar os padrões deste exemplo?",Callback=function(ctx) ctx:ThrowIfCancelled(); window:Reset(); return true end})
s:AddButton({Title="Abrir central",Callback=function() window:OpenCommandPalette() end})
-- F4 opens by default. Settings captures another keyboard key; Unknown disables
-- the shortcut. Typing a query alone does not run any registered command.
