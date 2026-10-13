-- RetroBox 1.7.0+: recycled datasets, tables, trees and contextual actions.
local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"))()
local window=RetroBox:CreateWindow({Id="advanced-components-demo",Title="RetroBox / Dados",Subtitle="Listas, tabelas e hierarquias"})
local tab=window:CreateTab({Title="Dados",Icon="folder",Columns=2})
local section=tab:CreateSection({Title="Lista virtual",Icon="grid"})
local items={}; for i=1,2000 do items[i]={Id="item-"..i,Text="Item "..i} end
local list=section:AddVirtualList({Id="list",Title="2.000 itens",Items=items,Height=260,OnSelect=function(item,key) print("Selecionado:",key,item.Text) end})
list:SetContextMenu(function(item,key) return {{Text="Mostrar ID",Icon="info",Callback=function() window:Notify({Content=key..": "..item.Text}) end},{Text="Ir ao último item",Callback=function() list:ScrollToKey("item-2000") end}} end)
section:AddButton({Title="Pular ao último item",Callback=function() list:ScrollToKey("item-2000") end})
local rows={}; for i=1,120 do rows[i]={Id="record-"..i,Name="Registro "..i,Count=i*3,Group=i%2==0 and "A" or "B"} end
local tableView=section:AddDataTable({Id="table",Title="Tabela ordenável",Rows=rows,Columns={{Key="Name",Title="Nome",Width=180},{Key="Count",Title="Quantidade",Width=120},{Key="Group",Title="Grupo",Width=90}},Height=280})
section:AddButton({Title="Filtrar grupo A",Callback=function() tableView:SetFilter(function(row) return row.Group=="A" end) end})
section:AddButton({Title="Limpar filtro",Callback=function() tableView:SetFilter(nil) end})
local hierarchy=tab:CreateSection({Title="Árvore",Icon="folder",Side="Right"})
local tree=hierarchy:AddTreeView({Id="tree",Title="Hierarquia expansível",Nodes={{Id="settings",Text="Configurações",Icon="settings",Children={{Id="appearance",Text="Aparência",Icon="palette"},{Id="profiles",Text="Perfis",Icon="save"}}},{Id="runtime",Text="Runtime",Icon="terminal",Children={{Id="tasks",Text="Tarefas",Icon="refresh"},{Id="actions",Text="Ações",Icon="bolt"}}}},Height=300})
hierarchy:AddButton({Title="Expandir tudo",Callback=function() tree:ExpandAll(true) end})
hierarchy:AddButton({Title="Recolher tudo",Callback=function() tree:ExpandAll(false) end})
-- Click column headers; use horizontal scroll for wide tables. Click a list row
-- before Up/Down/Home/End/PageUp/PageDown/Enter. Tree also accepts Left/Right.
