-- RetroBox 1.7.0+: responsive layout with real existing cards/charts.
local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))()
local window=RetroBox:CreateWindow({Id="dashboard-builder-demo",Title="RetroBox / Dashboard",ConfigFolder="RetroBox/DashboardBuilder"})
local s=window:CreateTab("Dashboard"):CreateSection("Dados simulados")
local d=s:CreateDashboard({Id="layout",Title="Widgets",Columns=2,Editable=true})
local value=window:CreateState(100)
d:AddStatCard({Id="total",Title="Total",Value=100,State=value,TwoWay=false,Format="Compact"})
d:AddStatCard({Id="sample",Title="Última amostra",Value=12})
local chart=d:AddLineChart({Id="history",Title="Histórico",Data={4,8,5,10},Span=2,Height=220})
d:AddBarChart({Id="bars",Title="Barras",Data={5,2,9}})
d:AddProgressChart({Id="progress",Title="Progresso",Value=60})
local job=window:CreateTask({Id="sample",Interval=1,Callback=function(ctx)
    ctx:ThrowIfCancelled(); value:Update(function(previous) return previous+3 end); chart:AddPoint(value:Get()%17)
end})
s:AddToggle({Id="sampling",Title="Atualizar simulação",Default=false}):BindTask(job)
s:AddButton({Title="Restaurar layout",Callback=function() d:ResetLayout() end})
-- The widget's small layout button/right click exposes order, span and height.
-- Normal Settings profiles save layout only; values/history remain transient.
