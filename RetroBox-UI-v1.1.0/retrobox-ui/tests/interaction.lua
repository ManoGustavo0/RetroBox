return function(Mock,Library,test)
    local function fixture(options)
        Mock.Geometry=true; Mock.GuiOrigin=Vector2.new(17,-36)
        options=options or {}; options.Id="interaction"; options.FileStorage=false; options.ReducedMotion=true
        local w=Library:CreateWindow(options); w:CreateTab("Main"):CreateSection("Main"):AddToggle({Id="feature"})
        return w
    end
    local function finish(w)
        w:Destroy(); Mock.pump(100); Mock.Geometry=false; Mock.GuiOrigin=nil; Mock.MousePosition=nil
        Mock.Viewport=Vector2.new(1280,720); Mock.AnimatedTweens=false; assert(Mock.Connections==0)
    end
    local function move(input,p)
        if input.UserInputType==Enum.UserInputType.Touch then input.Position=p; Mock.Services.UserInputService.InputChanged:Fire(input)
        else Mock.MousePosition=p; Mock.Services.UserInputService.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement}) end
    end
    local function press(w,object,kind)
        local p=object.AbsolutePosition+Vector2.new(24,8); Mock.MousePosition=p
        local input={UserInputType=kind or Enum.UserInputType.MouseButton1,Position=p}
        object.InputBegan:Fire(input); return input,p
    end
    test("title drag uses the live parent anchor without inset or scale jumps",function()
        for _,scale in ipairs({.75,1,1.5}) do
            local w=fixture({Scale=scale,SmoothDragging=true}); local header=w.TitleLabel.Parent
            for _,kind in ipairs({Enum.UserInputType.MouseButton1,Enum.UserInputType.Touch}) do
                local initial=w.Main.Position; local input,p=press(w,header,kind)
                assert(w.Main.Position.X.Offset==initial.X.Offset and w.Main.Position.Y.Offset==initial.Y.Offset)
                move(input,p+Vector2.new(30,20)); local target=w:_clampCenter(Vector2.new(initial.X.Offset+30,initial.Y.Offset+20))
                assert(w.Main.Position.X.Offset==target.X and w.Main.Position.Y.Offset==target.Y and not w._dragRender)
                Mock.Services.UserInputService.InputEnded:Fire(input); local released=w.Main.Position
                Mock.Services.RunService.RenderStepped:Fire(.1)
                assert(w.Main.Position.X.Offset==released.X.Offset and w.Main.Position.Y.Offset==released.Y.Offset)
            end
            finish(w)
        end
    end)
    test("launcher supports body drag, touch, click suppression and accessible persistence",function()
        local w=fixture(); w:Hide(); local original=w.Launcher.Position
        for _,kind in ipairs({Enum.UserInputType.MouseButton1,Enum.UserInputType.Touch}) do
            local input,p=press(w,w.Launcher,kind)
            move(input,p+Vector2.new(150,80)); Mock.Services.UserInputService.InputEnded:Fire(input)
            w.Launcher.Activated:Fire(); assert(not w._shown and w.Launcher.Position.X.Offset>original.X.Offset)
            Mock.pump(.3)
        end
        local saved=w:ExportConfig(); w:SetLauncherOptions({Position=Vector2.new(.8,.8)}); assert(w:ImportConfig(saved,{Silent=true}))
        local input,p=press(w,w.Launcher); move(input,p+Vector2.new(1,1)); Mock.Services.UserInputService.InputEnded:Fire(input)
        w.Launcher.Activated:Fire(); assert(w._shown)
        w:Hide(); local drag,start=press(w,w.Launcher); move(drag,start+Vector2.new(10000,10000)); Mock.Services.UserInputService.InputEnded:Fire(drag)
        assert(w.Launcher.Position.X.Offset+w.Launcher.AbsoluteSize.X<=w.Root.AbsoluteSize.X-8)
        Mock.Viewport=Vector2.new(380,500); w:_layoutFloating()
        assert(w.Launcher.Position.X.Offset+w.Launcher.AbsoluteSize.X<=380-8)
        w:Reset(true); assert(w.LauncherPosition.X==.025); finish(w)
    end)
    test("hide and minimize preserve Settings, scroll and control state",function()
        local w=fixture(); w:ShowSettings(true); local tab=w.ActiveTab
        tab.Frame.CanvasPosition=Vector2.new(0,123); w:SetFlag("feature",true,true)
        for _=1,3 do w:Hide(); w:Show(); w:Minimize(true); w:Minimize(false) end
        assert(w.ActiveTab==tab and w._settingsOpen and tab.Frame.CanvasPosition.Y==123 and w:GetFlag("feature"))
        finish(w)
    end)
    test("collapsing structurally hides search icons and every content descendant",function()
        local w=fixture(); Mock.AnimatedTweens=true; w:SetReducedMotion(false)
        w:SetSearch("feature"); w:_rebuildSearchResults(); assert(w.SearchResults.Visible)
        w:Minimize(true); assert(not w.Body.Visible and not w.SearchContainer.Visible and not w.SearchResults.Visible)
        local parent=w._searchIcon.Frame.Parent; assert(parent==w.SearchContainer and parent.Parent==w.Body)
        assert(w.Main.ClipsDescendants and w.Body.ClipsDescendants and w.TitleLabel.Parent.Parent==w.Main)
        Mock.pump(1); w:Minimize(false); Mock.pump(1); assert(w.Body.Visible and w.SearchContainer.Visible)
        assert(w:FocusControl("feature")); finish(w)
    end)
    test("editable fields and dropdown choices use consistent inset spacing",function()
        local w=fixture(); local s=w.ActiveTab.Sections[1]; local d=s:AddDropdown({Options={"Normal","Muito longo"}}); local i=s:AddInput({Default="Text"}); local n=s:AddSlider()
        assert(d.Button:FindFirstChild("TextPadding").PaddingLeft.Offset==12)
        assert(i.Input:FindFirstChild("TextPadding").PaddingLeft.Offset==12 and n.Input:FindFirstChild("TextPadding").PaddingRight.Offset==12)
        assert(d._rows.Normal:FindFirstChild("TextPadding").PaddingLeft.Offset==12)
        finish(w)
    end)
end
