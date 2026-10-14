-- Requires RetroBox 1.6.0+. All data and operations below are simulated.
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))()
assert(type(RetroBox.CreateState)=="function", "Publish RetroBox 1.6.0+ before running this example")
local window = RetroBox:CreateWindow({
    Id="dashboard-demo", Title="RetroBox / Live dashboard", Icon="terminal",
    Subtitle="Dados simulados · tarefas gerenciadas · ações canceláveis",
    ConfigFolder="RetroBox/DashboardDemo", Debug=true,
    Animations={Enabled=true,Speed=1,Intensity="Normal"}, SmoothDragging=false,
})
local tab=window:CreateTab({Title="Dashboard",Icon="grid"})
local metrics=tab:CreateSection({Title="Métricas",Icon="star",Collapsible=true})
local controls=tab:CreateSection({Title="Simulação",Icon="sliders",Collapsible=true})
local total=window:CreateState(1250,{Name="Total"})
local busy=window:CreateState(false,{Name="Action busy"})
local series=window:CreateState({10,14,11,18},{Name="Series"})
local row=metrics:CreateRow()
local count=row:AddStatCard({Id="total",Title="Total",Icon="star",State=total,TwoWay=false,Format="Compact",Unit="itens",Subtitle="Apenas demonstração",Animated=true})
local duration=row:AddStatCard({Id="duration",Title="Tempo ativo",Icon="refresh",Value=0,Format="Time",Subtitle="A simulação começa pausada"})
local trend=metrics:AddStatCard({Id="sample",Title="Amostra atual",Icon="bolt",Value=18,Unit="un/s",Sparkline=true,MaxPoints=40})
local line=metrics:AddLineChart({Id="history",Title="Histórico",State=series,TwoWay=false,MaxPoints=60,Height=200,ShowLegend=true,Legend="Amostras simuladas"})
local bars=metrics:AddBarChart({Id="categories",Title="Categorias",Data={{Value=10,Label="A"},{Value=20,Label="B"},{Value=15,Label="C"}},Height=180})
local progress=metrics:AddProgressChart({Id="progress",Title="Progresso da ação",Value=0,Animated=true})
metrics:AddSparkline({Title="Histórico compacto",State=series,TwoWay=false,MaxPoints=60})
local status=controls:AddLabel({Title="Estado",Text="Pronto para iniciar"})
local sampling=controls:AddSlider({Id="interval",Title="Intervalo das amostras",Min=.1,Max=2,Step=.1,Default=.5,Suffix=" s"})
local samples,elapsed=0,0
local job=window:CreateTask({Id="simulation",Interval=sampling:GetValue(),Callback=function(ctx)
    ctx:ThrowIfCancelled(); samples=samples+1; elapsed=elapsed+sampling:GetValue()
    local value=18+math.floor(8*math.sin(samples*.45))
    RetroBox:Batch(function()
        total:Update(function(previous) return previous+value end)
        series:Update(function(data) data[#data+1]={Value=value,Label=tostring(samples)}; while #data>60 do table.remove(data,1) end; return data end)
    end)
    duration:SetValue(elapsed,true); trend:SetValue(value,true):SetTrend(value-18):AddPoint(value)
    bars:SetData({{Value=value,Label="A"},{Value=value+5,Label="B"},{Value=math.max(0,value-4),Label="C"}},true)
end})
sampling:Manage(window:GetFlagState("interval"):Subscribe(function(value) job:SetInterval(value) end),"Disconnect")
local simulate=controls:AddToggle({
    Id="simulate",Title="Atualizar dados simulados",Default=false,
    Tooltip="Inicia uma tarefa periódica sem sobreposição. Ocultar ou minimizar o menu mantém a tarefa ativa.",
    Keybind={Default=Enum.KeyCode.G,Mode="Toggle"},Floating={Text="DADOS"},
})
simulate:BindTask(job)
local action=controls:AddButton({
    Id="process",Title="Processar demonstração",Icon="chevron-right",Group="demo-processing",Cancelable=true,Feedback=true,
    DependsOn={Enabled={Not={State=busy}},Reason="Aguarde ou cancele a operação atual."},
    Callback=function(_,ctx)
        progress:BindState(ctx.Action.Status,{Transform=function(value) return value.Progress*100 end})
        status:BindState(ctx.Action.Status,{Property="Text",Transform=function(value) return value.Status.." · "..value.Message end})
        busy:Set(true); ctx:Manage(function() if not busy.Destroyed then busy:Set(false) end end)
        for step=1,20 do
            ctx:ThrowIfCancelled(); ctx:SetProgress(step,20,"Etapa "..step.." de 20")
            task.wait(.08)
        end
        return {Processed=20}
    end,
})
local actions=controls:CreateRow()
actions:AddButton({Title="Cancelar ação",Icon="close",Callback=function() action:Cancel("Cancelado pelo usuário") end})
actions:AddButton({Title="Parar tudo",Icon="close",Callback=function()
    window:StopAll("Parado pelo usuário"); simulate:SetValue(false,true)
    window:Notify({Title="Pausado",Content="Tarefas e ações receberam cancelamento.",Kind="warning"})
end})
controls:AddButton({Title="Aplicar opções em lote",Callback=function()
    local ok,err=window:SetFlags({interval=.3,simulate=true})
    if not ok then window:Notify({Content=err,Kind="error"}) end
end})
controls:AddColorPicker({Id="color",Title="Cor personalizada",Default="#397A50",Callback=function(color) window:SetAccent(color) end})
controls:AddButton({Title="Confirmar ação",Callback=function()
    window:Confirm({Title="Continuar?",Content="Este exemplo usa apenas dados simulados.",OnConfirm=function() action:Press() end})
end})
controls:AddButton({Title="Ver diagnóstico",Callback=function()
    window:Dialog({Title="Runtime",Content="Recursos gerenciados: "..window:GetRuntimeStats().Resources.."\nErros registrados: "..#window:GetDiagnostics()})
end})
-- Scope also accepts your connections, Instances and cleanup functions.
window:Manage(function() print("[RetroBox] Dashboard resources cleaned") end)
-- Create every control first. Loading named saves invokes normal callbacks
-- after every flag has been applied; Silent=true skips control callbacks.
-- UI observers and BindTask still update on silent loads. Transient cards/history/tasks
-- and execution status are never stored in a profile.
-- See docs/RUNTIME.md for Queue/Replace, BindState and lifecycle policies.
