-- RetroBox 1.8.0+: six new palettes on real widgets, with simulated data.
-- Before the release is merged, replace main with the commit from its PR.
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))()
assert(RetroBox.Themes.Hacker, "Publish RetroBox 1.8.0+ or use the release commit in the raw URL")

local themes = {"Hacker", "Dracula", "Nord", "Sakura", "Ocean", "Amber"}
local window = RetroBox:CreateWindow({
    Id = "themes-gallery", Title = "RetroBox / Galeria 1.8",
    Subtitle = "Seis paletas novas · dados simulados",
    Theme = "Hacker", Locale = "pt-BR", ConfigFolder = "RetroBox/ThemesGallery",
})
local tab = window:CreateTab({Title = "Galeria", Icon = "palette", Columns = 2})
local selection = tab:CreateSection({Title = "Escolha a paleta", Icon = "palette"})
local theme = selection:AddDropdown({
    Id = "gallery-theme", Title = "Tema novo", Options = themes, Default = "Hacker",
    Tooltip = "Atualiza os componentes existentes. Os 12 temas estão nas Configurações.",
    Callback = function(name) window:SetTheme(name) end,
})
selection:AddButton({Title = "Próximo tema", Icon = "chevron-right", Callback = function()
    local index = table.find(themes, theme:GetValue()) or 1
    theme:SetValue(themes[index % #themes + 1])
end})
selection:AddButton({Title = "Criar sua variação", Icon = "palette", Callback = function()
    window:OpenThemeStudio()
end})
selection:AddButton({Title = "Testar aviso", Icon = "success", Callback = function()
    window:Notify({Title = "Paleta aplicada", Content = window.Theme .. " · valores de demonstração", Kind = "success"})
end})

local stats = tab:CreateSection({Title = "Valores e superfícies", Icon = "star"})
local row = stats:CreateRow()
row:AddStatCard({Title = "Eventos", Value = 128, Subtitle = "Nesta demonstração", Icon = "success"})
row:AddStatCard({Title = "Precisão", Value = 91, Format = "Percent", Subtitle = "Resultado simulado", Icon = "target"})
stats:AddConsole({Title = "Saída", Default = "[RetroBox 1.8] Paletas prontas.\nOs dados desta galeria são simulados."})

local charts = tab:CreateSection({Title = "Gráficos", Icon = "grid", Side = "Right"})
charts:AddLineChart({Title = "Atividade", Data = {8, 16, 11, 22, 18, 26}, ShowLegend = true, Legend = "Eventos simulados"})
charts:AddBarChart({Title = "Distribuição", Data = {{Value = 12, Label = "A"}, {Value = 7, Label = "B"}, {Value = 4, Label = "C"}}, ShowLegend = true, Legend = "Amostra"})
local progress = charts:AddProgressChart({Title = "Preenchimento", Value = 75})
charts:AddSlider({Id = "gallery-progress", Title = "Progresso", Min = 0, Max = 100, Default = 75, Suffix = "%", Callback = function(value)
    progress:SetValue(value)
end})
charts:AddSparkline({Title = "Tendência", Data = {5, 7, 4, 9, 6}})
charts:AddDataTable({Title = "Texto nas linhas", Height = 150,
    Columns = {{Key = "Name", Title = "Paleta"}, {Key = "Style", Title = "Estilo"}},
    Rows = {{Id = "hacker", Name = "Hacker", Style = "Terminal verde"}, {Id = "sakura", Name = "Sakura", Style = "Rosa claro"}, {Id = "amber", Name = "Amber", Style = "Monitor âmbar"}},
})
