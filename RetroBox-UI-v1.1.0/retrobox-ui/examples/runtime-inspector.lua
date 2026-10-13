-- RetroBox 1.7.0+: simulated operations; optional developer inspector.
local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"))()
local window=RetroBox:CreateWindow({Id="runtime-inspector-demo",Title="RetroBox / Inspector",Debug=true})
local s=window:CreateTab("Simulação"):CreateSection("Operações")
local total=window:CreateState(0); s:AddStatCard({Title="Total",State=total,TwoWay=false})
local job=window:CreateTask({Id="sample-worker",Interval=1,Group="demo-work",Callback=function(ctx)
    task.wait(.15); ctx:ThrowIfCancelled(); total:Update(function(value) return value+1 end); return total:Get()
end})
s:AddToggle({Id="worker",Title="Tarefa periódica",Default=false}):BindTask(job)
s:AddButton({Title="Ação com progresso",Group="demo-work",Policy="Queue",Cancelable=true,Callback=function(_,ctx)
    for i=1,5 do task.wait(.15); ctx:ThrowIfCancelled(); ctx:SetProgress(i,5,"Etapa "..i) end
    return {Processed=5}
end})
s:AddButton({Title="Diagnóstico de exemplo",Callback=function() error("Falha intencional de demonstração") end})
s:AddButton({Title="Abrir inspector",Callback=function() window:OpenRuntimeInspector({AllowCancel=true}) end})
window:OpenRuntimeInspector({AllowCancel=true})
-- Cancel is explicitly enabled here and still requires confirmation. Most
-- scripts should keep the inspector absent or read only.
