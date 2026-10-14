local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))()
local hub=RetroBox:CreateScriptHub({Id="hub-update-demo",Title="Catálogo atualizável",Version="1.0.0",Locale="pt-BR",Theme="Hacker",
    Actions={notice=function(_,activeHub) activeHub.Window:Notify({Content="Ação local de demonstração."}) end},Games={},
    CatalogUpdate={Root="https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/examples/hub-distribution/catalog",Major=1}})
local tools=hub.Window:CreateTab("Atualizações"):CreateSection("Catálogo e versões")
tools:AddButton({Id="check",Title="Consultar atualização",Callback=function()
    local status,err=hub:CheckForUpdates(); hub.Window:Notify({Content=err or status.Catalog.State})
end})
tools:AddButton({Id="reload",Title="Atualizar catálogo",Group="catalog-demo",Policy="Reject",Callback=function(_,ctx) return hub:ReloadCatalog(ctx) end})
hub:Show()
