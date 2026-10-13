local Mock=dofile("tests/mock_roblox.lua")
local Library=dofile("RetroBox.lua")
local passed=0
local function test(name,fn)
    local ok,err=pcall(fn)
    if not ok then error("FAIL ["..name.."] "..tostring(err)) end
    passed=passed+1; print("PASS "..name)
end
local w=Library:CreateWindow({Id="tests",Title="RetroBox tests",ReducedMotion=true})
local tab=w:CreateTab({Title="Controls",Columns=2})
local section=tab:CreateSection("Controls")
local callbacks=0
local toggle=section:AddToggle({Id="toggle",Default=false,Callback=function() callbacks=callbacks+1 end})
local slider=section:AddSlider({Id="slider",Min=0,Max=10,Step=.5,Default=3})
local dropdown=section:AddDropdown({Id="choice",Options={"A","B","C"},Default="B"})
local multi=section:AddDropdown({Id="multi",Multi=true,Options={"A","B","C"},Default={"C","A","A"}})
local text=section:AddInput({Id="text",Default="hello",MaxLength=32})
local picker=section:AddColorPicker({Id="color",Default={Color="#336699",Rainbow=false,Opacity=.5,Speed=6}})
local key=section:AddKeybind({Id="key",Default=Enum.KeyCode.F,Mode="Hold"})
local console=section:AddConsole({Title="Log",MaxLines=2})
local progress=section:AddProgress({Title="Progress",Default=30})
section:AddLabel("Label"); section:AddSeparator("Separator"); section:AddImage({Image="rbxassetid://0"})
Mock.pump()
test("profile comes from LocalPlayer",function()
    assert(w.DisplayNameLabel.Text=="Test Player" and w.UsernameLabel.Text=="@TestUser")
    assert(w.Avatar.Image=="rbxthumb://test-avatar")
end)
test("silent defaults and callbacks",function()
    assert(callbacks==0); toggle:SetValue(true); Mock.pump(); assert(callbacks==1)
    toggle:SetValue(false,true); Mock.pump(); assert(callbacks==1)
end)
test("change listeners disconnect",function()
    local count=0; local c=toggle:OnChanged(function() count=count+1 end)
    toggle:SetValue(true); Mock.pump(); assert(count==1); c:Disconnect()
    toggle:SetValue(false); Mock.pump(); assert(count==1 and not c.Connected)
end)
test("duplicate IDs are rejected",function()
    local count=#section.Controls
    assert(not pcall(function() section:AddToggle({Id="toggle"}) end))
    assert(#section.Controls==count)
end)
test("slider clamps, steps, and rejects NaN",function()
    slider:SetValue(7.3); assert(slider:GetValue()==7.5)
    slider:SetValue(99); assert(slider:GetValue()==10)
    assert(not pcall(function() slider:SetValue(0/0) end))
end)
test("multi dropdown canonical order and immutable getter",function()
    assert(table.concat(multi:GetValue(),",")=="A,C")
    local value=multi:GetValue(); value[1]="B"; assert(multi:GetValue()[1]=="A")
    assert(not pcall(function() dropdown:SetValue("missing") end))
end)
test("dropdown closes when clicked twice and owns one open menu",function()
    dropdown:SetOpen(true); assert(dropdown.Open)
    dropdown.Button.Activated:Fire(); assert(not dropdown.Open)
    dropdown:SetOpen(true); multi:SetOpen(true); assert(not dropdown.Open and multi.Open)
    multi:SetOpen(false)
end)
test("color state, HEX, opacity, and one shared RGB scheduler",function()
    assert(picker:GetColor()==Color3.fromRGB(51,102,153))
    picker:SetRainbow(true); assert(w._rgbConnection and w._rgbConnection.Connected)
    local second=section:AddColorPicker({Id="color2",Default={Color="#FFFFFF",Rainbow=true,Speed=4,Opacity=1}})
    local connection=w._rgbConnection
    local previous=picker:GetColor(); Mock.Services.RunService.Heartbeat:Fire(.1); Mock.pump()
    assert(picker:GetColor()~=previous and w._rgbConnection==connection)
    picker:SetRainbow(false); assert(picker:GetColor()==Color3.fromRGB(51,102,153))
    second:SetDisabled(true); assert(w._rgbConnection==nil)
    second:Destroy(); picker:SetOpacity(.2); assert(picker:GetValue().Opacity==.2)
end)
test("invalid color options are rejected without flags left behind",function()
    assert(not pcall(function() section:AddColorPicker({Id="invalid",Default={Color="#123456",Speed=-1}}) end))
    assert(w.Controls.invalid==nil)
    assert(not pcall(function() picker:SetValue({Speed=false}) end))
    assert(not pcall(function() picker:SetColor(Color3.new(-1,0,1)) end))
end)
test("config JSON round trip and enum/color serialization",function()
    toggle:SetValue(true,true); slider:SetValue(4.5,true)
    local json=w:ExportConfig(); assert(json:find("#336699",1,true))
    toggle:SetValue(false,true); slider:SetValue(9,true); dropdown:SetValue("C",true)
    assert(w:ImportConfig(json,{Silent=true}))
    assert(toggle:GetValue()==true and slider:GetValue()==4.5 and dropdown:GetValue()=="B")
    assert(key:GetValue()==Enum.KeyCode.F)
end)
test("invalid config leaves all controls and appearance unchanged",function()
    local config=w:ExportConfig(true); config.Flags.slider.Value="invalid"; config.Flags.toggle.Value=false
    config.Appearance.Theme="Terminal"
    local before=w.Theme; assert(not w:ImportConfig(config))
    assert(slider:GetValue()==4.5 and toggle:GetValue()==true and w.Theme==before)
    assert(not w:ImportConfig("this is not JSON"))
    config=w:ExportConfig(true); config.Appearance.Scale=false; assert(not w:ImportConfig(config))
    config=w:ExportConfig(true); config.Appearance.ToggleKey=false; assert(not w:ImportConfig(config))
end)
test("unknown IDs skip by default and fail in strict mode",function()
    local config=w:ExportConfig(true); config.Flags.missing={Type="Toggle",Value=true}
    assert(w:ImportConfig(config,{Silent=true})); assert(not w:ImportConfig(config,{Strict=true}))
end)
test("empty single dropdown restores correctly",function()
    dropdown:SetValue(nil,true); local json=w:ExportConfig()
    dropdown:SetValue("A",true); assert(w:ImportConfig(json,{Silent=true})); assert(dropdown:GetValue()==nil)
end)
test("config copies cannot mutate live values",function()
    local config=w:ExportConfig(true); config.Flags.multi.Value[1]="B"
    assert(multi:GetValue()[1]=="A")
end)
test("custom themes and accent are serialized",function()
    Library:RegisterTheme("Custom",{Accent="#102030"})
    w:SetTheme("Custom"); w:SetAccent("#F0D070")
    local config=w:ExportConfig(); w:SetTheme("Retro98")
    assert(w:ImportConfig(config,{Silent=true})); assert(w.Theme=="Custom" and w.Palette.Accent==Color3.fromRGB(240,208,112))
end)
test("hold key releases on focus loss and disable",function()
    key:Trigger(true); assert(key.Active)
    Mock.Services.UserInputService.WindowFocusReleased:Fire(); assert(not key.Active)
    key:Trigger(true); key:SetDisabled(true); assert(not key.Active); key:SetDisabled(false)
end)
test("capture Escape cancels and Backspace clears",function()
    key.Button.Activated:Fire(); assert(w._binding==key)
    w:_inputBegan({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Escape},false)
    assert(key:GetValue()==Enum.KeyCode.F and w._binding==nil)
    key.Button.Activated:Fire()
    w:_inputBegan({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.Backspace},false)
    assert(key:GetValue()==Enum.KeyCode.Unknown)
end)
test("focused text input blocks hotkeys",function()
    w:Show(); text.Input:CaptureFocus()
    w:_inputBegan({UserInputType=Enum.UserInputType.Keyboard,KeyCode=w.ToggleKey},false)
    assert(w.Main.Visible); text.Input:ReleaseFocus()
end)
test("memory and custom storage adapters report failures",function()
    assert(w:SaveConfig("test")); assert(w:LoadConfig("test",{Silent=true}))
    assert(not w:LoadConfig("missing")); assert(not w:SaveConfig("../bad"))
    local data={}
    w:SetStorage({Save=function(name,json) data[name]=json; return true end,Load=function(name) return data[name] end})
    assert(w:SaveConfig("adapter")); assert(w:LoadConfig("adapter",{Silent=true}))
    w:SetStorage({Save=function() return false,"write failed" end,Load=function() return nil end})
    local ok,err=w:SaveConfig("failed"); assert(not ok and err:find("write failed",1,true))
    w.Storage=nil
end)
test("responsive layout, minimize, hide, and launcher",function()
    w.Root.AbsoluteSize=Vector2.new(360,740); assert(w.Mobile and w._logicalSize.X<=430)
    w:Minimize(true); assert(not w.Footer.Visible)
    w:Minimize(false); assert(w.Footer.Visible)
    w:Hide(); assert(w.Launcher.Visible); w:Show(); assert(not w.Launcher.Visible)
    w.Root.AbsoluteSize=Vector2.new(1280,720); assert(not w.Mobile)
end)
test("gear settings and internal flags stay out of exported config",function()
    w.SettingsButton.Activated:Fire(); assert(w._settingsOpen)
    local config=w:ExportConfig(true)
    for id in pairs(config.Flags) do assert(not id:match("^__retrobox/")) end
    w:ShowSettings(false); assert(not w._settingsOpen)
end)
test("console ring buffer and progress",function()
    console:Append("one"):Append("two"):Append("three")
    assert(console:GetValue()=="two\nthree"); progress:SetValue(200); assert(progress:GetValue()==100)
end)
test("search and destruction remove controls from registries",function()
    w:SetSearch("text"); assert(text.Frame.Visible and not slider.Frame.Visible)
    w:SetSearch(""); local extra=tab:CreateSection("Disposable")
    local temp=extra:AddToggle({Id="temp"}); temp:Destroy(); assert(w.Controls.temp==nil and #extra.Controls==0)
    extra:AddToggle({Id="temp1"}); extra:AddToggle({Id="temp2"}); extra:Destroy()
    assert(w.Controls.temp1==nil and w.Controls.temp2==nil)
end)
test("notifications are bounded and expire",function()
    for i=1,7 do w:Notify({Content=tostring(i),Duration=1}) end
    assert(#w._notifications==4); Mock.pump(2); assert(#w._notifications==0)
end)
test("reset restores initial controls and appearance",function()
    local config=w:ExportConfig(true)
    config.Appearance.Theme="Retro98"; config.Appearance.ThemeColors.Accent="#AA7733"
    assert(w:ImportConfig(config,{Silent=true}))
    w:Reset(true); assert(toggle:GetValue()==false and slider:GetValue()==3 and w.Theme=="Retro98")
    assert(w.Palette.Accent==Library.Themes.Retro98.Accent)
end)
test("same explicit window Id cleans up the previous instance",function()
    local old=Library:CreateWindow({Id="replace"}); local replacement=Library:CreateWindow({Id="replace"})
    assert(old.Destroyed and not replacement.Destroyed); replacement:Destroy()
end)
test("destroy stops RGB, external ownership hooks, and every engine event",function()
    local cleaned=false
    w:OnDestroy(function() cleaned=true end)
    picker:SetRainbow(true); w:Destroy(); Mock.pump(60)
    assert(w.Destroyed and w._rgbConnection==nil and next(Library.Windows)==nil)
    assert(Mock.Connections==0,"Leaked connections: "..Mock.Connections)
    assert(cleaned)
end)
dofile("tests/tooltip.lua")(Mock,Library,test)
test("gethui is preferred and explicit Parent overrides detection",function()
    local hidden=Instance.new("Folder")
    local core=Instance.new("CoreGui"); Mock.Services.CoreGui=core
    gethui=function() return hidden end
    local window=Library:CreateWindow({Id="hidden-root"})
    assert(window.Parent==hidden and window.ParentMode=="gethui")
    local custom=Library:CreateWindow({Id="custom-root",Parent=core})
    assert(custom.Parent==core and custom.ParentMode=="custom")
    window:Destroy(); custom:Destroy(); gethui=nil; Mock.Services.CoreGui=nil; Mock.pump()
    assert(Mock.Connections==0)
end)
test("throwing, invalid and denied gethui fall back to CoreGui",function()
    local core=Instance.new("CoreGui"); Mock.Services.CoreGui=core
    local blocked=Instance.new("Folder"); blocked._rejectGuiParent=true
    for _,getter in ipairs({function() error("not available") end,function() return {} end,function() return blocked end}) do
        gethui=getter
        local window=Library:CreateWindow({Id="fallback-core"})
        assert(window.Parent==core and window.ParentMode=="CoreGui")
        window:Destroy()
    end
    assert(#blocked:GetChildren()==0)
    gethui=nil; Mock.Services.CoreGui=nil; Mock.pump(); assert(Mock.Connections==0)
end)
test("denied CoreGui falls back to PlayerGui",function()
    local core=Instance.new("CoreGui"); core._rejectGuiParent=true; Mock.Services.CoreGui=core
    local window=Library:CreateWindow({Id="fallback-player"})
    assert(window.Parent==Mock.Services.Players.LocalPlayer:WaitForChild("PlayerGui") and window.ParentMode=="PlayerGui")
    window:Destroy(); Mock.Services.CoreGui=nil; Mock.pump(); assert(Mock.Connections==0)
end)
test("explicit Parent failures leave no windows or events",function()
    local parent=Instance.new("Folder"); parent._rejectGuiParent=true
    assert(not pcall(function() Library:CreateWindow({Id="denied",Parent=parent}) end))
    parent._rejectGuiParent=false
    local unrelated=Instance.new("Frame"); unrelated.Name="RetroBox_collision"; unrelated.Parent=parent
    assert(not pcall(function() Library:CreateWindow({Id="collision",Parent=parent}) end))
    assert(unrelated.Parent==parent and not unrelated._destroyed)
    unrelated:Destroy(); assert(next(Library.Windows)==nil and Mock.Connections==0)
end)
test("reloading the source replaces the same Id across library instances",function()
    -- Cleanup must happen before an engine yield, even with deferred signals.
    Mock.DeferDestroying=true
    local environment={}; getgenv=function() return environment end
    local first=dofile("RetroBox.lua"); local second=dofile("RetroBox.lua")
    local previous=first:CreateWindow({Id="reexecute"})
    local cleaned=false; previous:OnDestroy(function() cleaned=true end)
    local window=second:CreateWindow({Id="reexecute"})
    assert(previous.Destroyed and cleaned and next(first.Windows)==nil)
    window:Destroy(); Mock.pump(); assert(Mock.Connections==0 and next(environment.__RetroBoxUIWindows)==nil)
    getgenv=nil; Mock.DeferDestroying=false
end)
local function filesystem()
    local fs={Files={},Folders={},Writes=0}
    readfile=function(path) return assert(fs.Files[path],"File not found") end
    writefile=function(path,json)
        assert(not fs.FailWrite,"write denied")
        assert(fs.Folders[path:match("^(.*)/")],"Missing parent folder")
        fs.Files[path]=json; fs.Writes=fs.Writes+1
    end
    makefolder=function(path) fs.Folders[path]=true end
    isfile=function(path) return fs.Files[path]~=nil end
    isfolder=function(path) return fs.Folders[path]==true end
    return fs
end
local function clearFiles() readfile=nil; writefile=nil; makefolder=nil; isfile=nil; isfolder=nil end
test("missing file capabilities fall back to session memory",function()
    local caps=Library:GetCapabilities(); assert(not caps.FileStorage)
    local adapter,err=Library:CreateFileStorage("RetroBox/test"); assert(adapter==nil and err)
    readfile=function() error("must not run") end
    local window=Library:CreateWindow({Id="memory-fallback"})
    assert(window.StorageMode=="memory" and window.Storage==nil)
    assert(window:SaveConfig("default") and window:LoadConfig("default"))
    window:Destroy(); clearFiles(); Mock.pump(); assert(Mock.Connections==0)
end)
test("automatic file storage is lazy and survives source reexecution",function()
    local fs=filesystem(); assert(Library:GetCapabilities().FileStorage)
    local window=Library:CreateWindow({Id="persistent",ConfigFolder="RetroBox/Project"})
    local control=window:CreateTab("Main"):CreateSection("Main"):AddToggle({Id="enabled",Default=false})
    assert(window.StorageMode=="file" and next(fs.Folders)==nil)
    control:SetValue(true,true); assert(window:SaveConfig("default"))
    assert(fs.Files["RetroBox/Project/profile-default.json"] and fs.Folders.RetroBox and fs.Folders["RetroBox/Project"])
    window:Destroy()
    local nextLibrary=dofile("RetroBox.lua")
    local restored=nextLibrary:CreateWindow({Id="persistent",ConfigFolder="RetroBox/Project"})
    local nextControl=restored:CreateTab("Main"):CreateSection("Main"):AddToggle({Id="enabled",Default=false})
    assert(restored:LoadConfig("default",{Silent=true}) and nextControl:GetValue())
    restored:Destroy(); clearFiles(); Mock.pump(); assert(Mock.Connections==0)
end)
test("file errors and corrupt JSON do not mutate live controls",function()
    local fs=filesystem()
    local window=Library:CreateWindow({Id="file-errors",ConfigFolder="RetroBox/Errors"})
    local control=window:CreateTab("Main"):CreateSection("Main"):AddSlider({Id="amount",Min=0,Max=10,Default=3})
    assert(not window:LoadConfig("missing"))
    fs.FailWrite=true; local ok,err=window:SaveConfig("denied")
    assert(not ok and err:find("write denied",1,true) and next(window._profiles)==nil)
    fs.FailWrite=false; assert(window:SaveConfig("valid"))
    fs.Files["RetroBox/Errors/profile-valid.json"]="corrupt JSON"
    assert(not window:LoadConfig("valid") and control:GetValue()==3)
    window:Destroy(); clearFiles(); Mock.pump(); assert(Mock.Connections==0)
end)
test("file folders reject traversal and profile encoding has no collisions",function()
    local fs=filesystem()
    for _,folder in ipairs({"../outside","/absolute","RetroBox/../outside","RetroBox//bad","C:/drive","RetroBox/CON","RetroBox/bad.",""}) do
        assert(not pcall(function() Library:CreateFileStorage(folder) end),folder)
    end
    local window=Library:CreateWindow({Id="paths",ConfigFolder="RetroBox/Paths"})
    assert(not window:SaveConfig("../escape") and not window:SaveConfig("bad\\name"))
    for _,name in ipairs({"a b","a%20b","..","CON","ação"}) do assert(window:SaveConfig(name)) end
    local count=0
    for path in pairs(fs.Files) do
        if path~="RetroBox/Paths/profiles-index.json" then
            assert(path:match("^RetroBox/Paths/profile%-[^/]+%.json$")); count=count+1
        end
    end
    assert(count==5 and fs.Files["RetroBox/Paths/profile-a%20b.json"] and fs.Files["RetroBox/Paths/profile-a%2520b.json"])
    assert(#window:GetConfigNames()==5)
    window:Destroy(); clearFiles(); Mock.pump(); assert(Mock.Connections==0)
end)
test("optional file predicates are not required",function()
    local fs=filesystem(); isfile=nil; isfolder=nil
    local window=Library:CreateWindow({Id="minimal-files"})
    assert(window.StorageMode=="file" and window:SaveConfig("default") and window:LoadConfig("default"))
    assert(window:SaveConfig("default") and fs.Writes==3)
    window:Destroy(); clearFiles(); Mock.pump(); assert(Mock.Connections==0)
end)
test("custom storage and explicit memory take precedence over files",function()
    local fs=filesystem(); local saved={}
    local window=Library:CreateWindow({Id="custom",Storage={Save=function(name,json) saved[name]=json end,Load=function(name) return saved[name] end}})
    assert(window.StorageMode=="custom" and window:SaveConfig("default") and window:LoadConfig("default"))
    local memory=Library:CreateWindow({Id="memory-only",FileStorage=false})
    assert(memory.StorageMode=="memory" and memory:SaveConfig("default"))
    assert(fs.Writes==0 and next(fs.Folders)==nil)
    window:Destroy(); memory:Destroy(); clearFiles(); Mock.pump(); assert(Mock.Connections==0)
end)
test("autosave debounces changes into the latest file state",function()
    local fs=filesystem()
    local window=Library:CreateWindow({Id="auto",ConfigFolder="RetroBox/Auto",AutoSave="latest"})
    local control=window:CreateTab("Main"):CreateSection("Main"):AddSlider({Id="amount",Min=0,Max=10,Default=0})
    control:SetValue(2); control:SetValue(7); Mock.pump(.79); assert(fs.Writes==0)
    Mock.pump(.02); assert(fs.Writes==2) -- profile + first-time name index
    local config=Mock.Services.HttpService:JSONDecode(fs.Files["RetroBox/Auto/profile-latest.json"])
    assert(config.Flags.amount.Value==7)
    control:SetValue(9); window:Destroy(); Mock.pump(1); assert(fs.Writes==2)
    clearFiles(); assert(Mock.Connections==0)
end)
dofile("tests/workflows.lua")(Mock,Library,test)
dofile("tests/icons.lua")(Mock,Library,test)
dofile("tests/runtime.lua")(Mock,Library,test)
dofile("tests/dashboard.lua")(Mock,Library,test)
dofile("tests/animation.lua")(Mock,Library,test)
dofile("tests/interaction.lua")(Mock,Library,test)
dofile("tests/integration.lua")(Mock,Library,test)
dofile("tests/migrations.lua")(Mock,Library,test)
dofile("tests/advanced.lua")(Mock,Library,test)
dofile("tests/tools.lua")(Mock,Library,test)
dofile("tests/navigation.lua")(Mock,Library,test)
dofile("tests/hub.lua")(Mock,Library,test)
dofile("tests/distribution.lua")(Mock,Library,test)
test("diagnostic loader reports HTTP, compile and library errors",function()
    loadstring=load
    for _,response in ipairs({function() error("HTTP failed") end,function() return "local" end,function() return "return {}" end,function() return "" end}) do
        game.HttpGet=response
        local ok,err=pcall(dofile,"Loader.lua"); assert(not ok and tostring(err):find("[RetroBox]",1,true))
    end
    game.HttpGet=function() local file=assert(io.open("RetroBox.lua","r")); local source=file:read("*a"); file:close(); return source end
    local library=dofile("Loader.lua"); assert(library.Version==Library.Version and type(library.CreateWindow)=="function")
    loadstring=nil; game.HttpGet=nil
end)
test("all shipped examples use the public API and clean up",function()
    local loaded={}
    local requests=0
    game.HttpGet=function(_,url)
        assert(url:match("^https://raw%.githubusercontent%.com/.+/RetroBox%.lua$"))
        requests=requests+1
        local file=assert(io.open("RetroBox.lua","r")); local source=file:read("*a"); file:close()
        return source
    end
    for _,file in ipairs({"quickstart","showcase","custom-theme","storage-adapter","tooltips","workflows","icons","dashboard","runtime-integration","contrast-showcase","advanced-components","theme-studio","runtime-inspector","dashboard-builder","command-palette","help-accessibility","themes-gallery","script-hub","remote-loader"}) do
        loadstring=function(source,name)
            local chunk,err=load(source,name)
            if not chunk then return nil,err end
            return function(...) local library=chunk(...); table.insert(loaded,library); return library end
        end
        dofile("examples/"..file..".lua")
        Mock.pump()
    end
    assert(requests==19 and #loaded==19)
    for _,library in ipairs(loaded) do
        for window in pairs(library.Windows) do
            if window.Id=="themes-gallery" then
                for _,name in ipairs({"Hacker","Dracula","Nord","Sakura","Ocean","Amber"}) do
                    window:SetFlag("gallery-theme",name); Mock.pump(); assert(window.Theme==name)
                end
                window:SetFlag("gallery-progress",0); Mock.pump()
                window:SetFlag("gallery-progress",100); Mock.pump()
            end
            if window.Id=="dashboard-demo" then
                assert(window:SetFlags({simulate=true,interval=.3})); Mock.pump()
                Mock.Services.RunService.RenderStepped:Fire(.1); Mock.pump()
                assert(window:GetFlag("total")>1250 and #window:GetFlag("history")==5)
                assert(window.Controls.process:Press()); Mock.pump()
                assert(window.Controls.process:GetAction().Result.Processed==20 and window:GetFlag("progress")==100)
                window:StopAll(); assert(not window.Tasks.simulation.Requested)
            end
            if window.Id=="runtime-integration-demo" then
                assert(window.Controls["legacy-profile"]:Press()); Mock.pump()
                assert(window:GetFlag("collector") and math.abs(window:GetFlag("sell-interval")-1.5)<1e-9 and window.Tasks.collect.Requested,
                    "Migrated flags/binding: "..tostring(window:GetFlag("collector")).." / "..tostring(window:GetFlag("sell-interval")).." / "..tostring(window.Tasks.collect.Requested))
                assert(window:SetFlags({collector=true,seller=true})); Mock.Services.RunService.RenderStepped:Fire(.1); Mock.pump()
                assert(window:GetFlag("money")>1000 and window.Tasks.sell.LastResult.Sold==3)
                window:StopAll(); assert(not window:GetFlag("collector") and not window:GetFlag("seller"))
            end
            window:ShowSettings(true); window:ShowSettings(false)
            assert(window:ImportConfig(window:ExportConfig(),{Silent=true}))
        end
        library:DestroyAll()
    end
    loadstring=nil; game.HttpGet=nil; Mock.pump(60)
    assert(Mock.Connections==0 and #Mock.Warnings==0)
end)
print(string.format("\n%d/%d headless logic tests passed. Rendering must be checked in a Roblox executor.",passed,passed))
