return function(Mock,Library,test)
    local function fixture(options)
        options=options or {}; options.Id="advanced-test"; options.FileStorage=false; options.ReducedMotion=true
        local w=Library:CreateWindow(options); local s=w:CreateTab("Advanced"):CreateSection("Advanced")
        return w,s
    end
    local function finish(w)
        w:Destroy(); Mock.pump(100); Mock.MousePosition=nil; Mock.Warnings={}; assert(Mock.Connections==0,"Advanced control leaked connections")
    end
    test("new official palettes have complete roles and remain protected in Theme Studio",function()
        local w=fixture()
        for _,name in ipairs({"Hacker","Dracula","Nord","Sakura","Ocean","Amber"}) do
            for _,role in ipairs(w:GetThemeRoles()) do assert(Library.Themes[name][role],name.." missing "..role) end
            w:SetTheme(name)
            assert(not pcall(function() w:DeleteTheme(name) end),"Official palette was deletable")
            assert(Library:ContrastRatio(w.Palette.Text,w.Palette.Inset)>=4.5)
            assert(Library:ContrastRatio(w.Palette.Muted,w.Palette.Inset)>=4.5)
            assert(Library:ContrastRatio(w.Palette.AccentText,w.Palette.Accent)>=4.5)
        end
        finish(w)
    end)
    test("new palettes round trip Settings saves and restore existing widgets",function()
        local w,s=fixture(); local card=s:AddStatCard({Value=128,Subtitle="Saved theme"})
        local surface=card.ValueLabel.Parent
        for _,name in ipairs({"Hacker","Dracula","Nord","Sakura","Ocean","Amber"}) do
            w._settingsControls.Theme._rows[name].Activated:Fire(); Mock.pump()
            assert(w.Theme==name and w._settingsControls.Theme:GetValue()==name)
            assert(w:SaveConfig("palette-"..name)); w:SetTheme("Retro98")
            assert(w:LoadConfig("palette-"..name)); Mock.pump()
            assert(w.Theme==name and card.ValueLabel.Parent==surface and surface.BackgroundColor3==Library.Themes[name].Inset)
        end
        finish(w)
    end)
    test("each new palette supports editable copies without changing its official colors",function()
        local w=fixture()
        for _,name in ipairs({"Hacker","Dracula","Nord","Sakura","Ocean","Amber"}) do
            local original=Library.Themes[name].Accent
            local custom=name.." copy"
            w:DuplicateTheme(name,custom); w:SetTheme(custom)
            w:SetThemeColor(custom,"Accent","#7294F0")
            assert(Library.Themes[name].Accent==original and w.Palette.Accent==Color3.fromRGB(114,148,240))
            w:RestoreTheme(custom); assert(w.Palette.Accent==original)
            w:DeleteTheme(custom); assert(w.Theme==name and not w._customThemes[custom])
            assert(not w:ImportTheme(w:ExportTheme(name),{Name=name,Replace=true}))
        end
        finish(w)
    end)
    test("surface registry retains native proxies and repeated bindings merge roles",function()
        local w,s=fixture(); local card=s:AddStatCard({Value=12})
        assert(not getmetatable(w._skin) or not getmetatable(w._skin).__mode)
        local surface=card.ValueLabel.Parent; local original=w._skin[surface].BackgroundColor3
        w:_bind(surface,{BorderColor3="Accent"}); assert(w._skin[surface].BackgroundColor3==original)
        collectgarbage("collect"); w:SetTheme("Monokai")
        assert(surface.BackgroundColor3==w.Palette.Inset); finish(w)
    end)
    test("all official themes repaint existing cards plots captions and console ink",function()
        local w,s=fixture(); local card=s:AddStatCard({Title="Peixes",Value=128,Subtitle="Event FishCaught",Trend=2,Unit="un",Sparkline=true})
        local line=s:AddLineChart({Data={1,3,2},ShowLegend=true}); local bar=s:AddBarChart({Data={1,2}}); local spark=s:AddSparkline({Data={3,2,4}})
        local progress=s:AddProgressChart({Value=50}); local console=s:AddConsole({Default="Readable output"})
        local surface=card.ValueLabel.Parent; local plot=line.Plot
        for _,name in ipairs(Library:GetThemeNames()) do
            w:SetTheme(name); Mock.pump(); Mock.Services.RunService.RenderStepped:Fire(.1)
            assert(card.ValueLabel.Parent==surface and line.Plot==plot and surface.BackgroundColor3==w.Palette.Inset and plot.BackgroundColor3==w.Palette.Inset)
            for _,object in ipairs({card.ValueLabel,card.SubtitleLabel,card.UnitLabel,card.TrendLabel,line.Legend,line.MinLabel,line.MaxLabel,line.EmptyLabel,bar.MinLabel,spark.EmptyLabel,progress.ProgressLabel,progress.ProgressFillLabel}) do
                assert(Library:ContrastRatio(object.TextColor3,w:_surfaceColor(object))>=4.49999,name.." low ink contrast")
            end
            for _,node in ipairs(line._pool) do assert(Library:ContrastRatio(node.BackgroundColor3,line.Plot.BackgroundColor3)>=2.99999) end
        end
        finish(w)
    end)
    test("supplied Monokai screenshot regression repaints old light surfaces with existing widgets",function()
        local file=assert(io.open("tests/fixtures/contrast-regression.json","r")); local data=file:read("*a"); file:close()
        local fixture=game:GetService("HttpService"):JSONDecode(data)
        local window,section=Library:CreateWindow({Id="screenshot-case",FileStorage=false,Settings=false,ReducedMotion=true}),nil
        section=window:CreateTab("Case"):CreateSection("Case")
        local card=section:AddStatCard({Value=128,Subtitle="Captured case"}); local body=card.ValueLabel.Parent
        window:SetTheme("Monokai")
        body.BackgroundColor3=Color3.fromRGB(table.unpack(fixture.OldBackground)); card.ValueLabel.TextColor3=Color3.fromRGB(table.unpack(fixture.OldPrimary))
        assert(Library:ContrastRatio(card.ValueLabel.TextColor3,body.BackgroundColor3)<1.2)
        window:_applyTheme(); assert(card.ValueLabel.Parent==body and body.BackgroundColor3==window.Palette.Inset and Library:ContrastRatio(card.ValueLabel.TextColor3,body.BackgroundColor3)>=4.5)
        finish(window)
    end)
    test("mixed custom surfaces choose local ink without forcing one global text color",function()
        Library:RegisterTheme("mixed-test",{Surface="#F8F8F8",Inset="#101010",Text="#EFEFEF",Muted="#DADADA"})
        local w,s=fixture({Theme="mixed-test"}); local card=s:AddStatCard({Value=4,Subtitle="Subtitle"}); local t=s:AddToggle({Title="Outside"})
        assert(Library:ContrastRatio(card.ValueLabel.TextColor3,card.ValueLabel.Parent.BackgroundColor3)>=4.5)
        assert(Library:ContrastRatio(t.TitleLabel.TextColor3,s.Frame.BackgroundColor3)>=4.49999)
        assert(card.ValueLabel.TextColor3~=t.TitleLabel.TextColor3); finish(w); Library.Themes["mixed-test"]=nil
    end)
    test("Terminal selects by UI and survives save switch and load",function()
        local w=fixture(); local theme=w._settingsControls.Theme
        theme._rows.Terminal.Activated:Fire(); Mock.pump(); assert(w.Theme=="Terminal")
        assert(w:SaveConfig("terminal")); w:SetTheme("Paper"); assert(w:LoadConfig("terminal")); Mock.pump(); assert(w.Theme=="Terminal")
        for _,name in ipairs(Library:GetThemeNames()) do theme._rows[name].Activated:Fire(); Mock.pump(); assert(w.Theme==name) end
        finish(w)
    end)
    test("dropdown padding compensates decorative border and old row listeners release",function()
        local w,s=fixture(); local d=s:AddDropdown({Options={"Normal","Desativada"}})
        local item=d._rows.Normal; assert(item.Size.X.Offset==-6 and item:FindFirstChild("BevelTop").Position.X.Offset==-12 and item:FindFirstChild("BevelTop").Size.X.Offset==24)
        local count=Mock.Connections
        for _=1,20 do d:SetOptions({"Normal","Desativada"},true) end
        assert(Mock.Connections==count); item=d._rows.Normal; item.MouseEnter:Fire(); assert(item.BackgroundColor3==w.Palette.Highlight)
        finish(w)
    end)
    test("deleting named memory profiles preserves other saves and stops deleted autosave",function()
        local w,s=fixture(); s:AddToggle({Id="flag"}); assert(w:SaveConfig("one")); assert(w:SaveConfig("two")); local other=w._profiles.two
        w.AutoSave="one"; assert(w:DeleteConfig("one")); assert(w.AutoSave==nil and w._profiles.two==other and #w:GetConfigNames()==1)
        assert(not w:DeleteConfig("one")); assert(w:DeleteConfig("two")); assert(#w:GetConfigNames()==0 and not w.LastConfigName); finish(w)
    end)
    test("profile deletion UI confirms before mutation and cancellation preserves data",function()
        local w=fixture(); assert(w:SaveConfig("delete-me")); w._settingsControls.Profiles:SetValue("delete-me",true)
        assert(w._settingsControls.Delete:Press()); Mock.pump(); assert(w._dialog and w._profiles["delete-me"])
        w._dialog:Close("cancel"); Mock.pump(); assert(w._profiles["delete-me"])
        assert(w._settingsControls.Delete:Press()); Mock.pump(); w._dialog:Choose(2); Mock.pump(); assert(not w._profiles["delete-me"])
        finish(w)
    end)
    test("unsupported and failing storage deletion never pretend to delete memory cache",function()
        local w=fixture(); assert(w:SaveConfig("keep")); w:SetStorage({Save=function() return true end,Load=function() return w._profiles.keep end})
        assert(not w:DeleteConfig("keep") and w._profiles.keep)
        w.Storage.Delete=function() return false,"disk error" end
        local ok,err=w:DeleteConfig("keep"); assert(not ok and err:find("disk error",1,true) and w._profiles.keep); finish(w)
    end)
    test("file profile deletion updates its index and preserves unrelated profile bytes",function()
        local files,folders={},{}
        readfile=function(path) return assert(files[path],"missing") end
        writefile=function(path,value) files[path]=value; return true end
        makefolder=function(path) folders[path]=true end; isfile=function(path) return files[path]~=nil end; isfolder=function(path) return folders[path] end
        delfile=function(path) assert(files[path],"missing"); files[path]=nil; return true end
        local adapter=assert(Library:CreateFileStorage("RetroBox/delete-test"))
        local w=fixture(); w:SetStorage(adapter); assert(w:SaveConfig("one")); assert(w:SaveConfig("two")); local other=files["RetroBox/delete-test/profile-two.json"]
        assert(w:DeleteConfig("one")); assert(not files["RetroBox/delete-test/profile-one.json"] and files["RetroBox/delete-test/profile-two.json"]==other and #adapter.List()==1)
        finish(w); readfile=nil; writefile=nil; makefolder=nil; isfile=nil; isfolder=nil; delfile=nil
    end)
    test("failed file deletion restores the index and reports without losing the profile",function()
        local files,fail={},false
        readfile=function(path) return assert(files[path],"missing") end
        writefile=function(path,value) files[path]=value; return true end
        makefolder=function() end; isfile=function(path) return files[path]~=nil end; isfolder=function() return true end
        delfile=function() return false end
        local adapter=assert(Library:CreateFileStorage("RetroBox/delete-fail")); assert(adapter.Save("keep","{}"))
        local before=files["RetroBox/delete-fail/profiles-index.json"]; local w=fixture(); w:SetStorage(adapter)
        local ok,err=w:DeleteConfig("keep"); assert(not ok and err:find("deletion failed",1,true) and files["RetroBox/delete-fail/profile-keep.json"] and files["RetroBox/delete-fail/profiles-index.json"]==before)
        finish(w); readfile=nil; writefile=nil; makefolder=nil; isfile=nil; isfolder=nil; delfile=nil
    end)
    test("description preference reflows fields immediately and preserves help",function()
        local w,s=fixture(); local compact=s:AddInput({Id="empty"}); local detailed=s:AddInput({Description="Explains this setting.",Tooltip="Extra detail."}); local toggle=s:AddToggle({Description="Explanation"})
        local full=detailed.Frame.Size.Y.Offset; assert(detailed.Input.Position.Y.Offset>compact.Input.Position.Y.Offset)
        w:SetDescriptions(false); assert(not detailed.DescriptionLabel.Visible and detailed.Frame.Size.Y.Offset<full and detailed.Tooltip)
        w:SetDescriptions(true); assert(detailed.DescriptionLabel.Visible and detailed.Frame.Size.Y.Offset==full)
        toggle:SetDescription(""); assert(not toggle.DescriptionLabel.Visible and toggle.Frame.Size.Y.Offset==30)
        detailed:SetDescriptionVisible(false); assert(not detailed.DescriptionLabel.Visible); finish(w)
    end)
    test("multiline labels fit text and hints after width edits and measurement failure",function()
        local w,s=fixture(); local c=s:AddLabel({Height=30,Title="Título em várias linhas\nLinha dois\nLinha três",Description="Descrição complementar.",Icon="info",Tooltip="Ajuda"})
        local function fit()
            local width=c.TitleLabel.AbsoluteSize.X/math.max(.01,w._actualScale or 1)
            local size=Mock.Services.TextService:GetTextSize(c.TitleLabel.Text,c.TitleLabel.TextSize,c.TitleLabel.Font,Vector2.new(math.max(1,width),100000))
            assert(c.TitleLabel.Size.Y.Offset>=size.Y)
            assert(not c.DescriptionLabel.Visible or c.DescriptionLabel.Position.Y.Offset>=c.TitleLabel.Size.Y.Offset)
            assert(c.Frame.Size.Y.Offset>=c.DescriptionLabel.Position.Y.Offset+c.DescriptionLabel.Size.Y.Offset or not c.DescriptionLabel.Visible)
        end
        fit(); c.Frame.AbsoluteSize=Vector2.new(150,200); fit()
        c:SetText(("Texto que precisa quebrar linhas. "):rep(8)); fit()
        c:SetDescriptionVisible(false); fit(); c:SetText("Curto"); fit(); assert(c.Frame.Size.Y.Offset==30)
        local measure=Mock.Services.TextService.GetTextSize
        Mock.Services.TextService.GetTextSize=function() error("Measurement temporarily unavailable") end
        c:SetText("Primeira linha\nSegunda linha\nTerceira linha")
        assert(c.TitleLabel.Size.Y.Offset>=3*c.TitleLabel.TextSize)
        Mock.Services.TextService.GetTextSize=measure; fit(); finish(w)
    end)
    test("default help is faster while region changes do not reset its pending timer",function()
        local w,s=fixture(); local c=s:AddToggle({Tooltip="Help"}); c.Frame.AbsolutePosition=Vector2.new(100,150); c.Frame.AbsoluteSize=Vector2.new(240,30); w.ActiveTab.Frame.AbsoluteSize=w.Root.AbsoluteSize
        assert(w.TooltipDelay==.2 and c.InfoButton)
        c.TitleLabel.MouseEnter:Fire(120,160); Mock.pump(.1); c.DescriptionLabel.MouseEnter:Fire(121,160); Mock.pump(.11)
        assert(w.TooltipFrame.Visible and w._tooltipOwner==c)
        w:SetTooltips({Enabled=false}); assert(not w.TooltipFrame.Visible and not c.InfoButton.Visible)
        w:SetTooltips({Enabled=true,Delay=.3}); assert(c.InfoButton.Visible and w.TooltipDelay==.3); finish(w)
    end)
    test("virtual lists recycle a bounded pool and preserve selection through refresh",function()
        local w,s=fixture(); local items={}; for i=1,2000 do items[i]={Id="row-"..i,Text="Item "..i} end
        local list=s:AddVirtualList({Items=items}); local stats=list:GetViewStats(); assert(stats.Items==2000 and stats.AllocatedRows<20)
        local first=list._pool[1].Button; list:SetValue("row-1500",true); assert(list:ScrollToKey("row-1500"))
        assert(list._pool[1].Button==first and list:GetValue()=="row-1500" and list._pool[1].Index>1000)
        local count=Mock.Connections
        for _=1,20 do list:SetQuery("Item 19"); list:SetQuery(""); list:ScrollToKey("row-1500") end
        assert(Mock.Connections==count and list:GetViewStats().AllocatedRows<20)
        list:SetItems({{Id="row-1500",Text="Updated"}}); assert(list:GetSelected().Text=="Updated" and list:GetValue()=="row-1500")
        finish(w)
    end)
    test("tables sort search filter select and update missing values without text addresses",function()
        local w,s=fixture(); local t=s:AddDataTable({Columns={{Key="Name"},{Key="Value"}},Rows={{Id="a",Name="Alpha",Value=3},{Id="b",Name="Beta",Value=1},{Id="c",Name="Gamma"}}})
        t:Sort("Value"); assert(t._indices[1]==3); t:SetQuery("Beta"); assert(#t._indices==1 and t._indices[1]==2)
        t:SetQuery(""):SetFilter(function(row) return row.Name~="Beta" end); assert(#t._indices==2)
        t:Sort("Name"); t._pool[1].Button.Activated:Fire(); Mock.pump(); assert(t:GetValue()=="a")
        t:SetFilter(nil); t:SetQuery("Gamma"); assert(t._pool[1].Labels[2].Text=="—")
        t:SetLoading(true); assert(t.EmptyLabel.Visible and not t._pool[1].Button.Visible); t:SetLoading(false); assert(t._pool[1].Button.Visible)
        finish(w)
    end)
    test("wide tables retain real column widths and synchronize horizontal headers",function()
        local w,s=fixture(); local t=s:AddDataTable({Columns={{Key="A",Width=180},{Key="B",Width=180},{Key="C",Width=180}},Rows={{Id="row",A="a",B="b",C="c"}}})
        assert(t._contentWidth==540 and t._pool[1].Labels[1].Size.X.Offset==160)
        t.Viewport.CanvasPosition=Vector2.new(150,0); assert(t.HeaderContent.Position.X.Offset==-150)
        t:ScrollToKey("row"); assert(t.Viewport.CanvasPosition.X==150); finish(w)
    end)
    test("virtual refresh preserves the visible anchor when stable keys move",function()
        local w,s=fixture(); local data={}; for i=1,30 do data[i]={Id=tostring(i),Text="Row "..i} end
        local list=s:AddVirtualList({Items=data}); list:ScrollToKey("20")
        local anchor=list.Keys[list._pool[1].Index]; table.insert(data,1,{Id="new",Text="New row"}); list:SetItems(data)
        assert(list.Keys[list._pool[1].Index]==anchor); finish(w)
    end)
    test("recycled context menu captures the current item and long touch suppresses selection activation",function()
        local w,s=fixture(); local picked
        local list=s:AddVirtualList({Items={{Id="a",Text="A"},{Id="b",Text="B"}}})
        list:SetContextMenu(function(item,key) return {{Text=key,Callback=function() picked=key end}} end)
        local row=list._pool[1]; row.Button.TouchLongPress:Fire({Vector2.new(100,100)},Enum.UserInputState.Begin)
        row.Button.Activated:Fire(); assert(w._overlay); w._overlay:Select(1); Mock.pump(); assert(picked=="a")
        list:SetItems({{Id="z",Text="Z"}}); row.Button.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton2,Position=Vector2.new(0,0)})
        w._overlay:Select(1); Mock.pump(); assert(picked=="z"); finish(w)
    end)
    test("invalid virtual datasets are atomic and failed construction cleans its registry",function()
        local w,s=fixture(); local t=s:AddVirtualList({Items={{Id="a",Text="A"}}}); local old=t:GetItems()
        assert(not pcall(function() t:SetItems({{Id="x"},{Id="x"}}) end)); assert(t:GetItems()[1].Id==old[1].Id)
        local count=0; for _ in pairs(w.Controls) do count=count+1 end
        assert(not pcall(function() s:AddDataTable({Id="invalid-table",Columns={{Key="A"}},Rows={{Id="a"},{Id="a"}}}) end)); assert(not w.Controls["invalid-table"])
        local after=0; for _ in pairs(w.Controls) do after=after+1 end; assert(after==count); finish(w)
    end)
    test("virtual data bindings update silently and disconnect with the control",function()
        local w,s=fixture(); local state=w:CreateState({{Id="a",Text="One"}}); local t=s:AddVirtualList({DataState=state})
        state:Set({{Id="b",Text="Two"}}); assert(t.Items[1].Id=="b")
        t:Destroy(); assert(next(state._listeners)==nil); finish(w)
    end)
    test("tree expansion hierarchy search and keyboard use the recycled viewport",function()
        local w,s=fixture(); local tree=s:AddTreeView({Default="root",Nodes={{Id="root",Text="Root",Icon="folder",Children={{Id="leaf",Text="Leaf"}}}}})
        assert(tree:GetValue()=="root" and #tree.Items==1)
        tree:_onKey("Right"); assert(tree:IsExpanded("root") and #tree.Items==2 and tree._pool[1].NodeIcon)
        tree:SetQuery("Leaf"); assert(#tree.Items==2); tree:SetQuery(""); tree:SetValue("leaf",true); tree:_onKey("Left"); assert(tree:GetValue()=="root")
        tree:ExpandAll(false); assert(#tree.Items==1); tree:SetNodes({}); assert(#tree.Items==0 and tree:GetValue()==nil); finish(w)
    end)
    test("context menus retain disabled actions and close or confirm selected callbacks",function()
        local w=fixture(); local calls=0; local menu=w:ContextMenu({Items={{Text="Blocked",Disabled=true,Callback=function() calls=calls+100 end},{Separator=true},{Text="Run",Callback=function() calls=calls+1 end}}},Vector2.new(1200,700))
        assert(not menu:Select(1)); assert(menu.Panels[1].Frame.Position.X.Offset+menu.Panels[1].Frame.Size.X.Offset<=w.Root.AbsoluteSize.X)
        assert(menu:Select(3)); Mock.pump(); assert(calls==1 and menu.Destroyed and not w._overlay)
        menu=w:ContextMenu({Items={{Text="Delete",Confirm="Confirm?",Callback=function() calls=calls+1 end}}}); menu:Select(1); Mock.pump(); assert(w._dialog and calls==1); w._dialog:Close("cancel"); Mock.pump(); assert(calls==1)
        finish(w)
    end)
    test("submenu navigation replaces panels without retained row listeners",function()
        local w=fixture(); local menu=w:ContextMenu({Items={{Text="More",Items={{Text="Action"}}}}}); local baseline=Mock.Connections
        for _=1,10 do assert(menu:Select(1)); menu:OnKey("Left") end
        assert(Mock.Connections==baseline and #menu.Panels==1); menu:OnKey("Escape"); assert(menu.Destroyed); finish(w)
    end)
end
