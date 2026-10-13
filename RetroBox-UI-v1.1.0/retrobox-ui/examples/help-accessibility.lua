-- RetroBox 1.7.0+: compact descriptions, reliable help, keyboard and text scale.
local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"))()
local window=RetroBox:CreateWindow({Id="help-accessibility-demo",Title="RetroBox / Ajuda",TooltipDelay=.2})
local s=window:CreateTab("Ajuda"):CreateSection("Explicações e controles")
s:AddToggle({Id="enabled",Title="Opção com descrição",Description="Esta explicação curta aparece abaixo do título e pode ser ocultada sem desativar a dica.",Tooltip="Passe sobre o título/descrição, use o botão de informação ou segure no celular.",Callback=function(value) print("Opção:",value) end})
s:AddInput({Id="compact",Title="Campo compacto",Default="Sem Description"})
s:AddDropdown({Id="choice",Title="Opção",Options={"A","B","C"},Description="A altura se adapta ao texto e à largura disponível.",Tooltip="Esta dica explica as opções sem selecionar nenhuma."})
s:AddButton({Title="Mensagem",Description="Tab percorre o foco; Enter ou Espaço ativa o botão.",Tooltip="O foco aparece em uma borda visível.",Callback=function() window:Notify({Content="Botão ativado."}) end})
-- Settings has Show descriptions, tooltips/delay, text scale and the palette key.
-- These preferences are saved and reset through the normal profiles.
