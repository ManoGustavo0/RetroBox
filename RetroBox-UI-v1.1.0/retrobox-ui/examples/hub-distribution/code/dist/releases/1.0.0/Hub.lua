-- Fictitious demonstration hub. Publish changes as a new code release.
return {
    Version="1.0.0",
    Start=function(RetroBox,settings)
        local function notice(_,hub)
            hub.Window:Notify({Title="Demonstração",Content="Este callback foi cadastrado pelo desenvolvedor."})
            return {Shown=true}
        end
        return RetroBox:CreateScriptHub({
            Id="hub-update-demo",Title="RetroBox / Hub atualizável",Version="1.0.0",Theme="Hacker",Locale="pt-BR",
            ConfigFolder="RetroBox/HubUpdateDemo",Actions={notice=notice},
            CatalogUpdate=settings.CatalogRoot and {Root=settings.CatalogRoot,Major=1,Cache=true} or nil,
            Games={{Id="demo",Name="Jogo fictício / demonstração",Description="Não representa um jogo real; demonstra distribuição de dados e callbacks locais.",
                Scripts={{Id="notice",Title="Mostrar aviso",Description="Uma ação local sem downloads de scripts.",Callback=notice}}}},
        })
    end,
}
