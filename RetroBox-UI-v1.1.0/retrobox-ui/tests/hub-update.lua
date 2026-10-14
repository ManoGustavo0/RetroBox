return function(Mock,Library,test)
    local service=Mock.Services.HttpService
    local function catalog(version)
        return {SchemaVersion=1,Kind="HubCatalog",HubId="catalog-test",Version=version or "1.1.0",Games={{Id="current",Name="Jogo atualizado",PlaceId=game.PlaceId,Description="Descrição atualizada",Scripts={{Id="main",Title="Ação atualizada",Description="Descrição do script",Action="notice"}}},{Id="other",Name="Outro jogo",Scripts={}}}}
    end
    local function fixture()
        local state={Document=catalog(),Calls=0,Fetches=0}
        state.Fetch=function(url)
            state.Fetches=state.Fetches+1
            if state.Error then error(state.Error) end
            local bytes=service:JSONEncode(state.Document)
            if url:sub(-5)==".json" and not url:find("/catalog.json",1,true) then
                return service:JSONEncode({SchemaVersion=1,Kind="HubCatalog",HubId="catalog-test",Version=state.Document.Version,APIVersion=1,Channel="stable",Build="catalog-"..state.Document.Version,
                    Library={MinVersion="2.0.0",MaxVersion="3.0.0",APIVersion=2},Artifact={Path="dist/releases/"..state.Document.Version.."/catalog.json",SHA256=Library:SHA256(bytes),Bytes=#bytes}})
            end
            return bytes
        end
        local h=Library:CreateScriptHub({Id="catalog-test",Version="1.0.0",FileStorage=false,ReducedMotion=true,
            Actions={notice=function() state.Calls=state.Calls+1; return {Message="local callback"} end},
            CatalogUpdate={Root="https://updates.test/catalog",Fetch=state.Fetch,AutoLoad=false},
            Games={{Id="current",Name="Original",PlaceId=game.PlaceId,Scripts={{Id="main",Title="Original",Callback=function() state.Calls=state.Calls+1 end}}},{Id="other",Name="Other",Scripts={}}}})
        return h,state
    end
    local function finish(h) h.Window:Destroy(); Mock.pump(100); assert(Mock.Connections==0) end
    test("catalog reload updates native views atomically and preserves preferences and versions",function()
        local h,s=fixture(); Mock.pump(); h:SetFavorite("other",true); h:SetSort("Favorites"); h:SelectGame("other"); h.Window:SetTheme("Hacker")
        h.Window:SaveConfig("before-update"); local oldViewport=h.GameList.Viewport; local flag=h.GameList.Id
        local ok,report=h:ReloadCatalog(); assert(ok and report.State=="Loaded")
        assert(h:GetGame("current").Name=="Jogo atualizado" and h.GameList.Viewport==oldViewport and h.GameList.Id==flag)
        assert(h:IsFavorite("other") and h.SelectedGameId=="other" and h.Window.Theme=="Hacker" and h.Sort:GetValue()=="Favorites")
        assert(h:GetVersion()=="1.0.0" and h.CatalogVersion=="1.1.0" and h:GetUpdateStatus().LibraryVersion=="2.0.0")
        assert(s.Calls==0 and h.Window:LoadConfig("before-update",{Silent=true})); finish(h)
    end)
    test("a catalog binds only registered actions and never executes on selection or reload",function()
        local h,s=fixture(); assert(h:ReloadCatalog()); h:SelectGame("current"); assert(h:SelectScript("main")); Mock.pump(); assert(s.Calls==0)
        local action=h:RunScript("current","main"); Mock.pump(); assert(action:GetStatus().Status=="Completed" and s.Calls==1)
        s.Document.Games[1].Scripts[1].Action="unregistered"; s.Document.Version="1.2.0"; assert(h:ReloadCatalog()); assert(not h:IsScriptAvailable("current","main")); assert(not h:RunScript("current","main") and s.Calls==1); finish(h)
    end)
    test("catalog metadata cannot inject code URLs callbacks or unknown fields",function()
        local h,s=fixture(); local original=h:GetGame("current").Name
        for _,field in ipairs({"Callback","URL","Loadstring","Source"}) do
            s.Document=catalog(); s.Document.Games[1].Scripts[1][field]='error("injected")'
            assert(not h:ReloadCatalog()); assert(h:GetGame("current").Name==original and s.Calls==0)
        end
        s.Document=catalog(); s.Document.Games[1].Scripts[1].Enabled="function() end"; assert(not h:ReloadCatalog()); finish(h)
    end)
    test("malformed catalogs and duplicate or accented IDs leave all existing views intact",function()
        local h,s=fixture(); local original=h:GetGames(); local viewport=h.ScriptList.Viewport
        for _,change in ipairs({function(d) d.Games[1].Id="Cães" end,function(d) d.Games[2].Id=d.Games[1].Id end,function(d) d.Games[1].PlaceId=-1 end,function(d) d.Games[1].Scripts[2]=d.Games[1].Scripts[1] end,function(d) d.Games[1].Image="https://foreign.test/image" end}) do
            s.Document=catalog(); change(s.Document); assert(not h:ReloadCatalog()); assert(h:GetGame("current").Name==original[1].Name and h.ScriptList.Viewport==viewport)
        end
        finish(h)
    end)
    test("catalog network failures and rollback preserve valid favorites and local callbacks",function()
        local h,s=fixture(); h:SetFavorite("current",true); assert(h:ReloadCatalog()); s.Error="Offline"; assert(not h:ReloadCatalog()); assert(h.CatalogVersion=="1.1.0")
        s.Error=nil; s.Document=catalog("1.0.0"); s.Document.Games[1].Name="Rollback"; local status=h:CheckForUpdates(); assert(status.Catalog.State=="RollbackAvailable")
        assert(h:ReloadCatalog() and h:GetGame("current").Name=="Rollback" and h:IsFavorite("current") and h.Version=="1.0.0"); finish(h)
    end)
    test("update checks are manual by default and channels do not mutate running code",function()
        local h,s=fixture(); Mock.pump(); assert(s.Fetches==0)
        local status=h:CheckForUpdates(); assert(s.Fetches==1 and status.Catalog.AvailableVersion=="1.1.0" and h:GetGame("current").Name=="Original")
        h:SetUpdateChannel("preview"); assert(h:GetUpdateStatus().Catalog.Channel=="preview" and h:GetVersion()=="1.0.0")
        assert(not pcall(h.SetUpdateChannel,h,"pinned")); h:SetUpdateChannel("pinned","1.1.0"); assert(h:GetUpdateStatus().Catalog.Channel=="pinned"); finish(h)
    end)
    test("automatic catalog loading is a single scoped startup action without execution",function()
        local template,s=fixture(); local fetch=s.Fetch; finish(template); s.Fetches=0
        local h=Library:CreateScriptHub({Id="catalog-test",Version="1.0.0",FileStorage=false,ReducedMotion=true,Games={},Actions={notice=function() s.Calls=s.Calls+1 end},CatalogUpdate={Root="https://updates.test/catalog",Fetch=fetch}})
        Mock.pump(); assert(s.Fetches==2 and h.CatalogVersion=="1.1.0" and #h:GetGames()==2 and s.Calls==0); Mock.pump(60); assert(s.Fetches==2); finish(h)
    end)
    test("removing the hub during a network yield prevents catalog application",function()
        Mock.YieldingTasks=true; local h,s=fixture(); local original=s.Fetch
        h._catalogUpdater.Options.Fetch=function(url) task.wait(.2); return original(url) end
        local action=h.Window:RunAction({Group="update-test",Callback=function(ctx) return h:ReloadCatalog(ctx) end}); Mock.pump(); h:Destroy(); Mock.pump(1)
        assert(h.Destroyed and h.CatalogVersion=="1.0.0" and action:GetStatus().Status~="Completed"); Mock.YieldingTasks=false; Mock.pump(100); assert(Mock.Connections==0)
    end)
    test("hero image is full width in 16 to 9 without a thumbnail title or empty status panel",function()
        local h=Library:CreateScriptHub({Id="hero-test",FileStorage=false,ReducedMotion=true,Games={{Id="a",Name="A",PlaceId=game.PlaceId,Scripts={}}}}); Mock.pump()
        assert(h.GameImage.Title=="" and h.GameImage.TitleLabel.Text=="" and not h.GameImage.TitleLabel.Visible)
        local width=h.GameImage.Frame.AbsoluteSize.X/math.max(.01,h.Window._actualScale or 1)
        assert(h.GameImage.Image.Size.X.Scale==1 and h.GameImage.Image.Size.Y.Scale==1 and h.GameImage.Image.ScaleType==Enum.ScaleType.Fit)
        assert(h.GameImage.Frame.Size.Y.Offset==math.max(80,math.floor(width*9/16)) and not h.ImageStatus.Frame.Visible)
        assert(not h.TeleportStatus.Frame.Visible); finish(h)
    end)
    test("script lists fit zero one three and many entries and keep one run button",function()
        local h,s=fixture(); local view=h.ScriptList.Viewport
        for _,count in ipairs({0,1,3,20}) do
            local scripts={}; for i=1,count do scripts[i]={Id="s"..i,Title="Script "..i,Callback=function() s.Calls=s.Calls+1 end} end
            h:UpdateGame("current",{Scripts=scripts}); h:SelectGame("current")
            assert(h.ScriptList.Viewport==view and h.ScriptList.Frame.Size.Y.Offset==math.max(1,math.min(count,4))*h.ScriptList.RowHeight+8)
            for _,row in ipairs(h.ScriptList._pool) do assert(not row.Play) end
            assert(h.PlayButton.Title=="Executar script" and s.Calls==0)
            if count==1 then assert(h:GetSelectedScript().Id=="s1") end
        end
        finish(h)
    end)
    test("script choices survive game navigation and query clearing without executing",function()
        local h,s=fixture(); h:AddScript("current",{Id="second",Title="Second",Callback=function() s.Calls=s.Calls+1 end}); h:SelectScript("second")
        h:SelectGame("other"); h:SelectGame("current"); assert(h:GetSelectedScript().Id=="second")
        h:SetScriptQuery("absent"); Mock.pump(); assert(h.ScriptList:GetViewStats().Filtered==0 and h.ScriptSearch.ClearButton.Visible)
        h.ScriptSearch.ClearButton.Activated:Fire(); Mock.pump(); assert(h.ScriptSearch:GetValue()=="" and h.ScriptList:GetViewStats().Filtered==2 and s.Calls==0); finish(h)
    end)
    test("desktop uses independent panes and small touch text-scaled windows stack",function()
        local h=Library:CreateScriptHub({Id="responsive-hub",Width=1100,Height=760,FileStorage=false,ReducedMotion=true,Games={{Id="a",Name="A",Scripts={}}}})
        h.Tab.Frame.Size=UDim2.fromOffset(900,600); h.Tab:_layout(); assert(h.LayoutMode=="columns" and h.Tab.Left.Parent==h.NavigationScroll and h.Tab.Right.Parent==h.DetailsScroll and not h.Tab.Frame.ScrollingEnabled)
        for _,textScale in ipairs({.8,1,1.4}) do
            h.Window:SetTextScale(textScale); h.Tab.Frame.Size=UDim2.fromOffset(360,520); h.Tab:_layout()
            assert(h.LayoutMode=="stacked" and h.Tab.Left.Parent==h.Tab.Container and h.Tab.Frame.ScrollingEnabled)
            assert(h.ScriptList.RowHeight>=38 and h.PlayButton.Frame.Size.Y.Offset>=28 and not h.GameImage.TitleLabel.Visible)
        end
        finish(h)
    end)
    test("run feedback reports actual progress completion failure and cancellation",function()
        Mock.YieldingTasks=true; local h,s=fixture()
        h:UpdateScript("current","main",{Callback=function(ctx) ctx:SetProgress(1,2,"Etapa"); task.wait(.3); ctx:ThrowIfCancelled(); return true end})
        h.PlayButton:Press(); Mock.pump(); assert(h.PlayButton.Disabled and h.CancelButton.Frame.Visible and h.ExecutionStatus:GetValue():find("50%%"))
        h.CancelButton:Press(); Mock.pump(); Mock.pump(.5); assert(h:GetScriptStatus("current","main").Status=="Cancelled" and not h.CancelButton.Frame.Visible)
        h:UpdateScript("current","main",{Callback=function() return false,"Falhou" end}); h.PlayButton:Press(); Mock.pump(); assert(h.ExecutionStatus:GetValue():find("Falha",1,true) and not h.PlayButton.Disabled)
        h:UpdateScript("current","main",{Callback=function() return true end}); h.PlayButton:Press(); Mock.pump(); assert(h.ExecutionStatus:GetValue():find("Concluído",1,true) and not h.PlayButton.Disabled)
        Mock.YieldingTasks=false; finish(h)
    end)
    test("English labels distinguish running a script from joining a game",function()
        local h=Library:CreateScriptHub({Id="english-hub",Locale="en-US",FileStorage=false,ReducedMotion=true,Games={{Id="a",Name="A",PlaceId=222,Scripts={{Id="s",Title="Demo",Callback=function() end}}}}})
        assert(h.PlayButton.Title=="Run Script" and h.TeleportButton.Title=="Join game" and h.Sort.Button.Text=="Registration order")
        h.Sort:SetOpen(true); assert(h.Sort.Frame.Size.Y.Offset<240); h.Sort:SetOpen(false); assert(h.Sort.Frame.Size.Y.Offset==34); finish(h)
    end)
    test("global search focuses the correct independent hub pane without executing",function()
        Mock.Geometry=true
        local h,s=fixture(); h.Tab.Frame.Size=UDim2.fromOffset(900,600); h.Tab:_layout()
        h.GameDetails.Frame.Position=UDim2.fromOffset(0,500)
        assert(h.Window:FocusControl(h.GameDetails)); Mock.pump(); Mock.Services.RunService.RenderStepped:Fire(.02)
        assert(h.DetailsScroll.CanvasPosition.Y>0 and h.Tab.Frame.CanvasPosition.Y==0 and s.Calls==0,"Focus panes: "..h.LayoutMode.." / "..h.DetailsScroll.CanvasPosition.Y.." / "..h.Tab.Frame.CanvasPosition.Y.." / "..s.Calls)
        finish(h); Mock.Geometry=false
    end)
end
