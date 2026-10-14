-- RetroBox 1.6.0+: simulated inventory, shared groups and script migrations.
local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))()
local window=RetroBox:CreateWindow({
    Id="runtime-integration-demo",Title="RetroBox / Runtime integrado",Icon="terminal",
    Subtitle="Demonstração com dados simulados",ConfigFolder="RetroBox/RuntimeIntegration",
    ConfigVersion=2,UnknownFlags="Preserve",Debug=true,SmoothDragging=false,
    Migrations={
        [1]=function(profile)
            if profile.Flags.collect_enabled then profile.Flags.collector=profile.Flags.collect_enabled; profile.Flags.collect_enabled=nil end
            if profile.Flags.sell_frequency then
                profile.Flags["sell-interval"]={Type="Slider",Value=tonumber(profile.Flags.sell_frequency.Value) or 2}
                profile.Flags.sell_frequency=nil
            end
        end,
    },
})
local section=window:CreateTab({Title="Operações",Icon="grid"}):CreateSection({Title="Inventário simulado",Collapsible=true})
local stock=window:CreateState(0); local money=window:CreateState(1000)
local row=section:CreateRow()
row:AddStatCard({Id="stock",Title="Itens",Icon="folder",State=stock,TwoWay=false})
row:AddStatCard({Id="money",Title="Saldo",Icon="star",State=money,TwoWay=false,Format="Compact"})
local chart=section:AddLineChart({Title="Saldo da sessão",MaxPoints=40})
window:Manage(money:Subscribe(function(value) chart:AddPoint(value) end,true),"Disconnect")
local collector=window:CreateTask({Id="collect",Interval=1,Group="inventory-work",Callback=function(ctx)
    task.wait(.25); ctx:ThrowIfCancelled(); stock:Update(function(value) return value+3 end)
    return {Added=3}
end})
local seller=window:CreateTask({Id="sell",Interval=2,Group="inventory-work",Callback=function(ctx)
    task.wait(.15); ctx:ThrowIfCancelled()
    local amount=stock:Get()
    RetroBox:Batch(function() stock:Set(0); money:Update(function(value) return value+amount*5 end) end)
    return {Sold=amount}
end})
local collectToggle=section:AddToggle({Id="collector",Title="Coleta periódica",Default=false,Keybind=Enum.KeyCode.G,Floating={Text="COLETAR"}})
collectToggle:BindTask(collector)
local sellToggle=section:AddToggle({Id="seller",Title="Venda periódica",Default=false,Floating={Text="VENDER"}})
sellToggle:BindTask(seller)
section:AddSlider({Id="sell-interval",Title="Intervalo da venda",Min=.1,Max=5,Step=.1,Default=2,Suffix=" s"})
window:Manage(window:GetFlagState("sell-interval"):Subscribe(function(value) seller:SetInterval(value) end,true),"Disconnect")
local collectText=section:AddLabel({Title="Coleta",Text="Parada"})
local sellText=section:AddLabel({Title="Venda",Text="Parada"})
local names={Inactive="Parada",Waiting="Aguardando próxima execução",WaitingForGroup="Aguardando a outra operação",Running="Executando",Cancelling="Cancelando",Stopped="Parada",Failed="Erro",Destroyed="Encerrada"}
local function statusText(job)
    local status=job:GetStatus(); local text=names[status.Status] or status.Status
    if status.Remaining then text=text.." · "..string.format("%.1f s",status.Remaining) end
    if status.LastError then text=text.." · "..status.LastError end
    return text
end
-- Present countdowns at a low frequency; task Status itself does not emit per frame.
window:CreateTask({Id="status-ui",Interval=.5,Start=true,Callback=function(ctx)
    ctx:ThrowIfCancelled(); collectText:SetText(statusText(collector)); sellText:SetText(statusText(seller))
end})
section:AddButton({Title="Operação única com espera",Feedback=true,Callback=function()
    local action,reason=window:RunAction({Group="inventory-work",Policy="Queue",Callback=function(ctx)
        task.wait(.2); ctx:ThrowIfCancelled(); stock:Update(function(value) return value+1 end); return 1
    end})
    if not action then return false,reason end
    local ok,result=action:Await({Timeout=3,CancelAction=true})
    if not ok then return false,result end
    return true
end})
section:AddButton({Id="stop-all",Title="Parar tudo",Icon="close",Callback=function() window:StopAll("Parado pelo usuário") end})
section:AddButton({Id="legacy-profile",Title="Carregar perfil antigo de exemplo",Icon="load",Callback=function()
    local ok,err=window:ImportConfig({Library="RetroBox UI",Schema=1,Version="1.5.0",Flags={
        collect_enabled={Type="Toggle",Value=true},seller={Type="Toggle",Value=false},sell_frequency={Type="Input",Value="1.5"},
    }},{Silent=true})
    window:Notify({Title=ok and "Perfil convertido" or "Erro",Content=ok and "IDs e intervalo migrados; coleta iniciada pelo binding." or err,Kind=ok and "success" or "error"})
end})
-- Shared Queue groups exclude concurrent stock edits; every task keeps at most
-- one outstanding iteration. StopAll also updates the bound toggles.
-- Named profiles use the normal Settings tab. Loading a profile updates bindings
-- after all flags are applied, including when Silent=true skips old callbacks.
