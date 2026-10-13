-- RetroBox 1.7.0+: real widgets for native theme/contrast verification.
local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"))()
local window=RetroBox:CreateWindow({Id="contrast-showcase",Title="RetroBox / Contraste",Subtitle="Casos das capturas · valores simulados",Debug=true})
local tab=window:CreateTab({Title="Contraste",Icon="eye",Columns=2})
local stats=tab:CreateSection({Title="Esta execução",Icon="star"})
local cards={}
local row=stats:CreateRow()
cards[1]=row:AddStatCard({Id="fish",Title="Peixes capturados",Value=128,Subtitle="Evento de captura simulado",Icon="success"})
cards[2]=row:AddStatCard({Id="casts",Title="Lançamentos",Value=142,Subtitle="Carga liberada pela vara",Icon="spark"})
row=stats:CreateRow()
cards[3]=row:AddStatCard({Id="accuracy",Title="Precisão do minigame",Value=91,Format="Percent",Subtitle="Último minigame: 9 acertos · 1 erro",Icon="target"})
cards[4]=row:AddStatCard({Id="last",Title="Último peixe",Value="Dourado",Subtitle="Informação simulada",Icon="star"})
local palette=tab:CreateSection({Title="Alternar temas",Icon="palette"})
local choice=palette:AddDropdown({Id="theme-choice",Title="Tema",Options=RetroBox:GetThemeNames(),Default=window.Theme,Callback=function(value) window:SetTheme(value) end})
palette:AddButton({Title="Próximo tema",Callback=function()
    local names=RetroBox:GetThemeNames(); local index=table.find(names,window.Theme) or 1; choice:SetValue(names[index%#names+1])
end})
palette:AddButton({Title="Verificar texto dos cards",Feedback=true,Callback=function()
    for _,card in ipairs(cards) do
        for _,object in ipairs({card.ValueLabel,card.SubtitleLabel}) do
            local ratio=RetroBox:ContrastRatio(object.TextColor3,card.ValueLabel.Parent.BackgroundColor3)
            if ratio<4.49 then return false,"Contraste insuficiente: "..card.Title end
        end
    end
    return true
end})
palette:AddButton({Title="Abrir Theme Studio",Callback=function() window:OpenThemeStudio() end})
local charts=tab:CreateSection({Title="Gráficos e legendas",Icon="grid",Side="Right"})
charts:AddLineChart({Title="Histórico",Data={{Value=8,Label="A"},{Value=16,Label="B"},{Value=11,Label="C"},{Value=22,Label="D"}},ShowLegend=true,Legend="Capturas simuladas"})
charts:AddBarChart({Title="Categorias",Data={{Value=8,Label="Comum"},{Value=4,Label="Raro"},{Value=2,Label="Especial"}},ShowLegend=true,Legend="Exemplo de distribuição"})
charts:AddProgressChart({Title="Progresso",Value=50})
charts:AddSparkline({Title="Sparkline",Data={5,7,4,9,6}})
charts:AddConsole({Title="Console",Default="Texto sobre uma superfície interna."})
charts:AddInput({Title="Campo editável",Default="Texto legível",Description="A descrição pode ser ocultada nas configurações.",Tooltip="Confira hover, título, descrição e o botão de informação."})
-- Switch every official theme without recreating any widget. Native text metrics,
-- borders, clipping and input still need inspection in the target executor.
