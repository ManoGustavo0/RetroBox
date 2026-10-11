-- RetroBox UI 1.2.0 | Mano Gustavo | MIT License
-- Standalone GUI library for Roblox client executors.
-- Load the raw GitHub source with loadstring(game:HttpGet(URL))().

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local Library = { Version = "1.2.0", Themes = {}, Windows = {} }
local Window = {}; Window.__index = Window
local Tab = {}; Tab.__index = Tab
local Section = {}; Section.__index = Section
local Control = {}; Control.__index = Control
local RGB = Color3.fromRGB
local U2 = UDim2.fromOffset
-- Share lifecycle handles across separate raw-source loads. Reexecution must
-- disconnect old input callbacks before engine Destroying events are resumed.
local sharedWindows=setmetatable({},{__mode="k"})
do
    local environment=_G
    if type(getgenv)=="function" then
        local ok,value=pcall(getgenv)
        if ok and type(value)=="table" then environment=value end
    end
    if type(environment)=="table" then
        local ok,registry=pcall(function()
            if type(environment.__RetroBoxUIWindows)~="table" then
                environment.__RetroBoxUIWindows=setmetatable({},{__mode="k"})
            end
            return environment.__RetroBoxUIWindows
        end)
        if ok then sharedWindows=registry end
    end
end

local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
local function clamp(n, low, high) return math.max(low, math.min(high, n)) end
local function copy(value)
    if typeof(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local function same(a, b)
    if typeof(a) ~= "table" or typeof(b) ~= "table" then return a == b end
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function cleanup(owner)
    for _, connection in ipairs(owner._connections or {}) do connection:Disconnect() end
    owner._connections = {}
end
local function connect(owner, signal, callback)
    local connection = signal:Connect(callback)
    table.insert(owner._connections, connection)
    return connection
end
local function call(window, callback, ...)
    if type(callback) ~= "function" or window.Destroyed then return end
    local args = table.pack(...)
    task.spawn(function()
        if window.Destroyed then return end
        local ok, err = pcall(callback, table.unpack(args, 1, args.n))
        if not ok then warn("[RetroBox] Callback: " .. tostring(err)) end
    end)
end
local function keycode(value)
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then return value end
    if type(value) == "string" then
        local ok, item = pcall(function() return Enum.KeyCode[value] end)
        if ok and item then return item end
    end
    error("Expected an Enum.KeyCode or a valid key name", 3)
end
local function hex(color)
    return string.format("#%02X%02X%02X", math.floor(color.R * 255 + .5),
        math.floor(color.G * 255 + .5), math.floor(color.B * 255 + .5))
end
local function parseColor(value)
    if typeof(value) == "Color3" then
        assert(finite(value.R) and finite(value.G) and finite(value.B) and value.R>=0 and value.R<=1 and value.G>=0 and value.G<=1 and value.B>=0 and value.B<=1,"Color components must be finite and between 0 and 1")
        return value
    end
    if type(value) == "string" then
        local text = value:gsub("^#", "")
        if text:match("^%x%x%x$") then
            text = text:sub(1, 1):rep(2) .. text:sub(2, 2):rep(2) .. text:sub(3, 3):rep(2)
        end
        if text:match("^%x%x%x%x%x%x$") then
            return RGB(tonumber(text:sub(1, 2), 16), tonumber(text:sub(3, 4), 16), tonumber(text:sub(5, 6), 16))
        end
    end
    error("Expected a Color3 or #RRGGBB/#RGB color", 3)
end
local function names(options)
    assert(type(options) == "table", "Options must be an array")
    local result, seen = {}, {}
    for _, item in ipairs(options) do
        assert(type(item) == "string" or type(item) == "number", "Dropdown options must be strings or numbers")
        local name = tostring(item)
        assert(not seen[name], "Duplicate dropdown option: " .. name)
        seen[name] = true; table.insert(result, name)
    end
    return result
end
local function point(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        return Vector2.new(input.Position.X, input.Position.Y)
    end
    return UserInputService:GetMouseLocation()
end
local function inside(object, position)
    local p, s = object.AbsolutePosition, object.AbsoluteSize
    return position.X >= p.X and position.Y >= p.Y and position.X <= p.X + s.X and position.Y <= p.Y + s.Y
end
local function pointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local roleNames = { "Background", "Surface", "Inset", "Text", "Muted", "Border", "Highlight", "Shadow", "Accent", "AccentText", "Success", "Danger" }
local function palette(values)
    local result = {}
    for index, name in ipairs(roleNames) do result[name] = RGB(table.unpack(values[index])) end
    return result
end
Library.Themes.Retro98 = palette({
    {210,207,195},{230,227,216},{249,247,236},{33,37,42},{88,91,94},{105,105,96},
    {255,253,241},{115,111,101},{28,59,101},{251,248,230},{43,115,69},{161,53,51},
})
Library.Themes.Terminal = palette({
    {17,26,20},{29,41,30},{12,20,15},{210,226,196},{164,186,155},{78,102,76},
    {73,91,64},{8,14,10},{151,188,116},{15,27,17},{159,207,123},{238,146,130},
})
Library.Themes.GameBoy = palette({
    {199,211,164},{218,228,188},{231,237,209},{43,57,35},{87,106,67},{113,130,86},
    {240,246,218},{111,128,77},{77,104,52},{243,246,217},{61,111,60},{128,58,41},
})
Library.Themes.Paper = palette({
    {232,221,200},{246,236,216},{255,249,234},{68,52,41},{107,91,73},{151,128,103},
    {255,252,237},{138,115,88},{113,76,55},{255,246,225},{66,119,70},{157,64,47},
})
Library.Themes.Midnight = palette({
    {25,31,43},{36,44,59},{18,25,36},{231,235,243},{170,183,200},{79,95,117},
    {91,108,132},{10,15,22},{125,166,206},{13,27,44},{140,201,160},{238,145,139},
})
Library.Themes.Monokai = palette({
    {39,40,34},{53,55,46},{28,30,25},{248,248,242},{195,198,178},{98,103,84},
    {108,113,91},{18,20,16},{166,226,46},{31,39,20},{166,226,46},{249,139,151},
})

local translations = {
    ["pt-BR"] = {
        search="Buscar nesta aba...", settings="PERSONALIZAR", theme="Tema", accent="Cor de destaque",
        scale="Escala da interface", motion="Reduzir animações", lines="Linhas CRT", launcher="Botão de reabrir",
        notices="Notificações", appearance="Aparência", accessibility="Interface e acessibilidade",
        shortcut="Atalho da janela", configs="Configurações", profile="Nome da configuração", save="Salvar",
        load="Carregar", export="Exportar JSON", import="Importar JSON", reset="Restaurar padrões",
        ready="Pronto", fixed="Cor fixa", rainbow="RGB animado", cycle="s/ciclo", opacity="Opacidade",
        choose="Selecionar...", empty="Sem resultados", capture="Pressione uma tecla...", saved="Configuração salva",
        loaded="Configuração carregada", error="Não foi possível", close="Fechar", about="RetroBox UI",
    },
    ["en-US"] = {
        search="Search this tab...", settings="CUSTOMIZE", theme="Theme", accent="Accent color",
        scale="Interface scale", motion="Reduce animations", lines="CRT scanlines", launcher="Reopen button",
        notices="Notifications", appearance="Appearance", accessibility="Interface and accessibility",
        shortcut="Window shortcut", configs="Configurations", profile="Configuration name", save="Save",
        load="Load", export="Export JSON", import="Import JSON", reset="Restore defaults",
        ready="Ready", fixed="Fixed color", rainbow="Animated RGB", cycle="s/cycle", opacity="Opacity",
        choose="Select...", empty="No results", capture="Press a key...", saved="Configuration saved",
        loaded="Configuration loaded", error="Could not complete", close="Close", about="RetroBox UI",
    },
}

function Library:RegisterTheme(name, colors)
    assert(type(name) == "string" and #name > 0, "Theme name must be nonempty")
    assert(type(colors) == "table", "Theme must be a table")
    local result = copy(self.Themes.Retro98)
    for role, color in pairs(colors) do
        assert(result[role] ~= nil, "Unknown theme role: " .. tostring(role))
        result[role] = parseColor(color)
    end
    self.Themes[name] = result
end
function Library:GetThemeNames()
    local result = {}
    for name in pairs(self.Themes) do table.insert(result, name) end
    table.sort(result)
    return result
end

function Window:_text(key) return self._locale[key] or key end
function Window:_bind(object, roles)
    self._skin[object] = roles
    for property, role in pairs(roles) do object[property] = self.Palette[role] end
end
local function ui(window, class, properties, roles)
    local object = Instance.new(class)
    local parent = properties.Parent
    for property, value in pairs(properties) do if property ~= "Parent" then object[property] = value end end
    if roles then window:_bind(object, roles) end
    object.Parent = parent
    return object
end
local function frame(window, parent, props, role)
    local properties = { Parent=parent, BorderSizePixel=0, Size=UDim2.new(1, 0, 0, 0) }
    for k, v in pairs(props or {}) do properties[k] = v end
    return ui(window, "Frame", properties, role and { BackgroundColor3=role } or nil)
end
local function label(window, parent, text, props, role)
    local properties = {
        Parent=parent, BackgroundTransparency=1, BorderSizePixel=0, Text=tostring(text or ""),
        Font=window.Font, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center,
        Size=UDim2.new(1, 0, 0, 24), RichText=false,
    }
    for k, v in pairs(props or {}) do properties[k] = v end
    return ui(window, "TextLabel", properties, { TextColor3=role or "Text" })
end
local function bevel(window, object, sunken)
    local bright, dark = sunken and "Shadow" or "Highlight", sunken and "Highlight" or "Shadow"
    frame(window, object, { Name="BevelTop", Size=UDim2.new(1,0,0,1), ZIndex=object.ZIndex+1 }, bright)
    frame(window, object, { Name="BevelLeft", Size=UDim2.new(0,1,1,0), ZIndex=object.ZIndex+1 }, bright)
    frame(window, object, { Name="BevelBottom", Position=UDim2.new(0,0,1,-1), Size=UDim2.new(1,0,0,1), ZIndex=object.ZIndex+1 }, dark)
    frame(window, object, { Name="BevelRight", Position=UDim2.new(1,-1,0,0), Size=UDim2.new(0,1,1,0), ZIndex=object.ZIndex+1 }, dark)
end
local function button(window, owner, parent, text, props, pressed)
    local properties = { Parent=parent, Text=tostring(text), Font=window.Font, TextSize=14,
        BorderSizePixel=0, AutoButtonColor=false, Size=U2(80,30), Active=true, Selectable=true, RichText=false }
    for k, v in pairs(props or {}) do properties[k] = v end
    local object = ui(window, "TextButton", properties, { BackgroundColor3="Surface", TextColor3="Text" })
    bevel(window, object, false)
    if pressed then
        connect(owner, object.Activated, function(...)
            if not window.Destroyed and not owner.Destroyed and not owner.Disabled then pressed(...) end
        end)
    end
    return object
end
local function textbox(window, parent, text, props)
    local properties = { Parent=parent, Text=tostring(text or ""), Font=window.Font, TextSize=14,
        BorderSizePixel=1, ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left,
        Size=UDim2.new(1,0,0,32), RichText=false }
    for k, v in pairs(props or {}) do properties[k] = v end
    local object = ui(window, "TextBox", properties, { BackgroundColor3="Inset", TextColor3="Text", BorderColor3="Border", PlaceholderColor3="Muted" })
    ui(window, "UIPadding", { Parent=object, PaddingLeft=UDim.new(0,8), PaddingRight=UDim.new(0,8) })
    return object
end
local function list(window, parent, gap, horizontal)
    return ui(window, "UIListLayout", { Parent=parent, Padding=UDim.new(0,gap or 8),
        FillDirection=horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
        SortOrder=Enum.SortOrder.LayoutOrder })
end

local function tooltipValue(value)
    if value==nil or value==false or value=="" then return nil end
    if type(value)=="string" then value={Text=value} end
    assert(type(value)=="table" and type(value.Text)=="string","Tooltip must be text or a table with Text")
    assert(#value.Text<=4096,"Tooltip text must contain at most 4096 bytes")
    assert(value.Title==nil or type(value.Title)=="string" and #value.Title<=256,"Tooltip Title must be text with at most 256 bytes")
    assert(value.Delay==nil or finite(value.Delay) and value.Delay>=0 and value.Delay<=3,"Tooltip Delay must be 0–3 seconds")
    assert(value.MaxWidth==nil or finite(value.MaxWidth) and value.MaxWidth>=160 and value.MaxWidth<=640,"Tooltip MaxWidth must be 160–640")
    if #value.Text==0 then return nil end
    return {Text=value.Text,Title=value.Title,Delay=value.Delay,MaxWidth=value.MaxWidth}
end
function Window:_hideTooltip()
    self._tooltipToken=(self._tooltipToken or 0)+1
    self._pendingTooltip=nil; self._tooltipOwner=nil; self._tooltipAnchor=nil; self._tooltipMode=nil
    if self.TooltipFrame then self.TooltipFrame.Visible=false end
end
function Window:_tooltipEligible(control,position)
    if self.Destroyed or control.Destroyed or not control.Tooltip or not self.Main.Visible or self.Minimized or self._drag or self._binding then return false end
    if self._settingsOpen and not control._internal then return false end
    if self._openDropdown and self._openDropdown~=control then return false end
    if position and not inside(control.Frame,position) then return false end
    local parent=control.Frame
    while parent and parent~=self.Gui do
        if parent:IsA("GuiObject") then
            if parent.Visible==false then return false end
            if position and (parent:IsA("ScrollingFrame") or parent.ClipsDescendants==true) and not inside(parent,position) then return false end
        end
        parent=parent.Parent
    end
    return parent==self.Gui
end
function Window:_createTooltip()
    if self.TooltipFrame then return end
    self.TooltipFrame=ui(self,"TextButton",{
        Parent=self.Root,Name="Tooltip",Size=U2(320,80),Visible=false,ZIndex=1000,Active=true,ClipsDescendants=true,
        BorderSizePixel=1,Text="",AutoButtonColor=false,Selectable=false,
    },{BackgroundColor3="Surface",BorderColor3="Border"})
    connect(self,self.TooltipFrame.Activated,function() self:_hideTooltip() end)
    bevel(self,self.TooltipFrame,false)
    self._tooltipTitle=label(self,self.TooltipFrame,"",{
        Position=U2(12,9),Size=UDim2.new(1,-24,0,20),ZIndex=1001,TextSize=13,TextTruncate=Enum.TextTruncate.AtEnd,
    },"Accent")
    self._tooltipBody=label(self,self.TooltipFrame,"",{
        Position=U2(12,34),Size=UDim2.new(1,-24,1,-44),ZIndex=1001,TextSize=13,
        TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd,TextYAlignment=Enum.TextYAlignment.Top,
    })
end
function Window:_positionTooltip(anchor)
    local size=self.TooltipFrame.AbsoluteSize; local view=self.Root.AbsoluteSize
    local cursor=anchor-self.Root.AbsolutePosition
    local x,y=cursor.X+16,cursor.Y+18
    if x+size.X>view.X-8 then x=cursor.X-size.X-14 end
    if y+size.Y>view.Y-8 then y=cursor.Y-size.Y-14 end
    self.TooltipFrame.Position=U2(clamp(x,8,math.max(8,view.X-size.X-8)),clamp(y,8,math.max(8,view.Y-size.Y-8)))
end
function Window:_showTooltip(control,anchor,mode)
    local checkPoint
    if mode~="manual" then checkPoint=anchor end
    if not self:_tooltipEligible(control,checkPoint) then self:_hideTooltip(); return false end
    local view=self.Root.AbsoluteSize
    if view.X<64 or view.Y<80 then self:_hideTooltip(); return false end
    self:_createTooltip()
    self._tooltipToken=(self._tooltipToken or 0)+1; self._pendingTooltip=nil
    self._tooltipOwner=control; self._tooltipAnchor=anchor; self._tooltipMode=mode
    local tip=control.Tooltip
    local width=math.min(tip.MaxWidth or self.TooltipMaxWidth,view.X-16)
    local textSize=clamp(math.floor(13*self.UserScale+.5),10,20)
    local ok,bounds=pcall(TextService.GetTextSize,TextService,tip.Text,textSize,self.Font,Vector2.new(width-24,100000))
    local bodyHeight=ok and typeof(bounds)=="Vector2" and finite(bounds.Y) and bounds.Y+4 or math.ceil(#tip.Text*textSize*.6/(width-24))*(textSize+2)
    local headerHeight=textSize+6
    local height=math.min(math.max(bodyHeight,textSize+4)+headerHeight+28,view.Y-16,420)
    self.TooltipFrame.Size=U2(width,height)
    self._tooltipTitle.Text="[?] "..(tip.Title or control.Title)
    self._tooltipTitle.TextSize=textSize; self._tooltipTitle.Size=UDim2.new(1,-24,0,headerHeight)
    self._tooltipBody.Text=tip.Text; self._tooltipBody.TextSize=textSize
    self._tooltipBody.Position=U2(12,12+headerHeight)
    self._tooltipBody.Size=UDim2.new(1,-24,0,math.max(0,height-headerHeight-24))
    self:_positionTooltip(anchor); self.TooltipFrame.Visible=true
    return true
end
function Window:_queueTooltip(control,anchor)
    if not self:_tooltipEligible(control,anchor) then return end
    self:_hideTooltip()
    self._pendingTooltip=control; self._tooltipAnchor=anchor; self._tooltipMode="hover"
    local token=self._tooltipToken
    task.delay(control.Tooltip.Delay or self.TooltipDelay,function()
        if not self.Destroyed and self._tooltipToken==token and self._pendingTooltip==control then
            self:_showTooltip(control,self._tooltipAnchor,"hover")
        end
    end)
end
function Window:_updateTooltip(input)
    local owner=self._tooltipOwner or self._pendingTooltip
    if not owner then return end
    if not self:_tooltipEligible(owner) then self:_hideTooltip(); return end
    if input.UserInputType==Enum.UserInputType.MouseMovement and self._tooltipMode=="hover" then
        local anchor=point(input)
        if not self:_tooltipEligible(owner,anchor) then self:_hideTooltip(); return end
        self._tooltipAnchor=anchor
        if self._tooltipOwner then self:_positionTooltip(anchor) end
    end
end
function Control:_connectTooltip()
    if self._tooltipConnected then return end
    self._tooltipConnected=true
    self.TitleLabel.Active=true; self.DescriptionLabel.Active=true
    connect(self,self.Frame.MouseEnter,function(x,y)
        if self.Tooltip then self._window:_queueTooltip(self,Vector2.new(x,y)) end
    end)
    connect(self,self.Frame.MouseLeave,function()
        local window=self._window
        if window._tooltipMode=="hover" and (window._tooltipOwner==self or window._pendingTooltip==self) then window:_hideTooltip() end
    end)
    local function touch(positions,state)
        if state==Enum.UserInputState.Begin and positions[1] and self.Tooltip then self._window:_showTooltip(self,positions[1],"touch") end
    end
    connect(self,self.TitleLabel.TouchLongPress,touch)
    connect(self,self.DescriptionLabel.TouchLongPress,touch)
end
function Control:SetTooltip(value)
    assert(not self.Destroyed,"This control has been destroyed")
    self.Tooltip=tooltipValue(value)
    if self.Tooltip then self:_connectTooltip() end
    local window=self._window
    if window._tooltipOwner==self then
        if self.Tooltip then window:_showTooltip(self,window._tooltipAnchor,window._tooltipMode) else window:_hideTooltip() end
    elseif window._pendingTooltip==self then
        if self.Tooltip then window:_queueTooltip(self,window._tooltipAnchor) else window:_hideTooltip() end
    end
    return self
end
Control.SetTip=Control.SetTooltip
function Control:GetTooltip() return copy(self.Tooltip) end
function Control:ShowTooltip()
    self._window:_showTooltip(self,self.Frame.AbsolutePosition+Vector2.new(12,12),"manual"); return self
end
function Control:HideTooltip()
    if self._window._tooltipOwner==self or self._window._pendingTooltip==self then self._window:_hideTooltip() end
    return self
end

function Window:_beginDrag(owner, input, update, finish)
    if not pointer(input) or owner.Disabled then return end
    self:_hideTooltip()
    self:_endDrag()
    self._drag = { Owner=owner, Input=input, Update=update, Finish=finish }
    update(point(input))
end
function Window:_endDrag()
    local drag = self._drag
    self._drag = nil
    if drag and drag.Finish then drag.Finish() end
end
function Window:_scheduleSave()
    if not self.AutoSave or self._importing or self.Destroyed then return end
    self._saveToken = self._saveToken + 1
    local token = self._saveToken
    task.delay(.8, function()
        if not self.Destroyed and self._saveToken == token then
            local ok, err = self:SaveConfig(self.AutoSave)
            if not ok then warn("[RetroBox] AutoSave: " .. tostring(err)) end
        end
    end)
end
function Window:_register(control, options)
    if options.Id ~= nil then
        assert(type(options.Id) == "string" and #options.Id > 0, "Id must be a nonempty string")
        assert(not options.Id:match("^__retrobox/") or options.Internal, "The __retrobox/ prefix is reserved")
    end
    self._nextId = self._nextId + 1
    control.Id = options.Id or ("control/" .. self._nextId)
    assert(not self.Controls[control.Id], "Duplicate control Id: " .. control.Id)
    self.Controls[control.Id] = control
    control.Persist = options.Persist ~= false and not options.Internal
    control._callback = options.Callback
    control._listeners = {}
    control._internal = options.Internal == true
end
function Control:_emit()
    if self.Destroyed or self._window.Destroyed then return end
    local value = self:GetValue()
    self._window.Flags[self.Id] = copy(value)
    self:_callbackNow()
    for listener in pairs(self._listeners) do
        if listener.Connected then call(self._window, listener.Callback, copy(value)) end
    end
    self._window:_scheduleSave()
end
function Control:_callbackNow()
    if self.Type == "ColorPicker" then
        call(self._window, self._callback, self:GetColor(), self.Value.Opacity, self:GetValue())
    else
        call(self._window, self._callback, self:GetValue())
    end
end
function Control:SetValue(value, silent)
    assert(not self.Destroyed, "This control has been destroyed")
    local normalized = self:_normalize(value)
    local changed = not same(self.Value, normalized)
    self.Value = copy(normalized)
    self._window.Flags[self.Id] = self:GetValue()
    if self._render then self:_render() end
    if changed and not silent then self:_emit() end
    return self
end
function Control:GetValue() return copy(self.Value) end
function Control:OnChanged(callback)
    assert(type(callback) == "function", "OnChanged expects a function")
    local owner = self
    local listener = { Connected=true, Callback=callback }
    function listener:Disconnect()
        self.Connected = false
        owner._listeners[self] = nil
    end
    self._listeners[listener] = true
    return listener
end
function Control:SetDisabled(disabled)
    if disabled == true and self.Type == "Keybind" and self.Mode == "Hold" and self.Active then self:Trigger(false) end
    if disabled == true and self._window._binding == self then self._window._binding = nil end
    self.Disabled = disabled == true
    self.TitleLabel.TextTransparency = self.Disabled and .5 or 0
    if self._render then self:_render() end
    if self.Type == "ColorPicker" then self._window:_updateRGB() end
    if self.Disabled and self._window._drag and self._window._drag.Owner == self then self._window:_endDrag() end
    return self
end
function Control:SetVisible(visible)
    self._visible = visible ~= false
    self._window:SetSearch(self._window._query)
    return self
end
function Control:SetTitle(text)
    self.Title = tostring(text); self.TitleLabel.Text = self.Title
    self._window:SetSearch(self._window._query)
    return self
end
function Control:SetDescription(text)
    self.Description = tostring(text or "")
    self.DescriptionLabel.Text = self.Description
    self.DescriptionLabel.Visible = #self.Description > 0
    return self
end
function Control:Destroy()
    if self.Destroyed then return end
    if self.Type == "Keybind" and self.Mode == "Hold" and self.Active then self:Trigger(false) end
    self.Destroyed = true
    self:HideTooltip()
    cleanup(self)
    if self._window._drag and self._window._drag.Owner == self then self._window:_endDrag() end
    if self._window._binding == self then self._window._binding = nil end
    if self._window._openDropdown == self then self._window._openDropdown = nil end
    self._window.Controls[self.Id] = nil
    self._window.Flags[self.Id] = nil
    self._window._rainbows[self] = nil
    self._window._keybinds[self] = nil
    for listener in pairs(self._listeners) do listener.Connected = false end
    self._listeners = {}
    self.Frame:Destroy()
    local index = table.find(self._section.Controls, self)
    if index then table.remove(self._section.Controls, index) end
    self._window:_updateRGB()
end

local function base(section, kind, options, height)
    options = options or {}
    assert(not section.Destroyed and not section._window.Destroyed, "Section has been destroyed")
    local window = section._window
    local tip=options.Tooltip
    if tip==nil then tip=options.Tip end
    local tooltip=tooltipValue(tip)
    local self = setmetatable({ Type=kind, Title=tostring(options.Title or kind), Description=tostring(options.Description or ""),
        Tooltip=tooltip,_window=window, _section=section, _connections={}, _visible=options.Visible ~= false, Disabled=options.Disabled == true }, Control)
    window:_register(self, options)
    section._count = section._count + 1
    self.Frame = frame(window, section.Content, {
        Name=self.Id, LayoutOrder=section._count, Size=UDim2.new(1,0,0,height or 76),
        BackgroundTransparency=1,
    })
    self.TitleLabel = label(window, self.Frame, self.Title, { Position=U2(0,0), Size=UDim2.new(1,0,0,21), TextTruncate=Enum.TextTruncate.AtEnd })
    self.DescriptionLabel = label(window, self.Frame, self.Description, {
        Position=U2(0,22), Size=UDim2.new(1,0,0,18), TextSize=12, TextTruncate=Enum.TextTruncate.AtEnd,
        Visible=#self.Description > 0,
    }, "Muted")
    if tooltip then self:_connectTooltip() end
    table.insert(section.Controls, self)
    connect(self, self.Frame.Destroying, function() if not self.Destroyed then self:Destroy() end end)
    return self
end
local function init(control, options, default)
    local value = default
    if options.Default ~= nil then value = options.Default end
    local ok, err = pcall(control.SetValue, control, value, true)
    if not ok then control:Destroy(); error(err, 3) end
    control._default = control:GetValue()
    control._hasDefault = true
    control:SetDisabled(control.Disabled)
    if options.FireOnInit then task.defer(function() if not control.Destroyed then control:_emit() end end) end
    return control
end

function Section:AddToggle(options)
    options = options or {}
    local self = base(self, "Toggle", options, #tostring(options.Description or "") > 0 and 47 or 30)
    self.TitleLabel.Size = UDim2.new(1,-46,0,23)
    self.DescriptionLabel.Size = UDim2.new(1,-46,0,18)
    local box
    box = button(self._window, self, self.Frame, "", { Position=UDim2.new(1,-32,0,0), Size=U2(30,28) }, function()
        self:SetValue(not self.Value)
    end)
    function self:_normalize(value) assert(type(value) == "boolean", "Toggle value must be boolean"); return value end
    function self:_render()
        box.Text = self.Value and "X" or ""
        box.TextColor3 = self._window.Palette[self.Value and "Accent" or "Text"]
        box.Active = not self.Disabled; box.TextTransparency = self.Disabled and .5 or 0
    end
    connect(self, self.Frame.InputBegan, function(input)
        if pointer(input) and not self.Disabled and not inside(box, point(input)) then self:SetValue(not self.Value) end
    end)
    self.Frame.Active = true
    self.Button = box
    return init(self, options, false)
end

function Section:AddSlider(options)
    options = options or {}
    local self = base(self, "Slider", options, 78)
    self.Min, self.Max, self.Step = options.Min or 0, options.Max or 100, options.Step or 1
    assert(finite(self.Min) and finite(self.Max) and self.Max > self.Min, "Slider requires finite Min < Max")
    assert(finite(self.Step) and self.Step > 0, "Slider Step must be positive")
    self.TitleLabel.Size = UDim2.new(1,-85,0,21)
    local valueBox = textbox(self._window, self.Frame, "", { Position=UDim2.new(1,-78,0,0), Size=U2(78,25), TextSize=12 })
    local track = frame(self._window, self.Frame, { Position=U2(0,49), Size=UDim2.new(1,0,0,10), Active=true }, "Inset")
    bevel(self._window, track, true)
    local fill = frame(self._window, track, { Size=UDim2.new(0,0,1,0) }, "Accent")
    local thumb = frame(self._window, track, { AnchorPoint=Vector2.new(.5,.5), Position=UDim2.new(0,0,.5,0), Size=U2(12,22), Active=true }, "Surface")
    bevel(self._window, thumb, false)
    function self:_normalize(value)
        assert(finite(value), "Slider value must be a finite number")
        if value >= self.Max then return self.Max end
        if value <= self.Min then return self.Min end
        return clamp(self.Min + math.floor((clamp(value,self.Min,self.Max)-self.Min)/self.Step+.5)*self.Step, self.Min, self.Max)
    end
    function self:_render()
        local ratio = (self.Value-self.Min)/(self.Max-self.Min)
        fill.Size = UDim2.new(ratio,0,1,0); thumb.Position = UDim2.new(ratio,0,.5,0)
        if not valueBox:IsFocused() then valueBox.Text = string.format("%.6g", self.Value) .. (options.Suffix or "") end
        valueBox.TextEditable = not self.Disabled
    end
    local function start(input)
        self._window:_beginDrag(self,input,function(p)
            local width = track.AbsoluteSize.X
            if width > 0 then self:SetValue(self.Min + clamp((p.X-track.AbsolutePosition.X)/width,0,1)*(self.Max-self.Min)) end
        end)
    end
    connect(self,track.InputBegan,start); connect(self,thumb.InputBegan,start)
    connect(self,valueBox.Focused,function() valueBox.Text = string.format("%.6g",self.Value) end)
    connect(self,valueBox.FocusLost,function()
        local n = tonumber(valueBox.Text)
        if finite(n) and not self.Disabled then self:SetValue(n) end
        self:_render()
    end)
    self.Input = valueBox
    return init(self,options,self.Min)
end

function Section:AddButton(options)
    options = options or {}
    local self = base(self, "Button", options, #tostring(options.Description or "") > 0 and 79 or 56)
    self.Persist = false
    local y = #self.Description > 0 and 44 or 24
    local action
    action = button(self._window,self,self.Frame,options.Text or self.Title,{ Position=U2(0,y),Size=UDim2.new(1,0,0,30) },function() self:Press() end)
    function self:_normalize(value) return value end
    function self:_render() action.Active = not self.Disabled; action.TextTransparency = self.Disabled and .5 or 0 end
    function self:Press()
        if self.Disabled or self.Destroyed or self._busy then return false end
        self._busy = true
        task.spawn(function()
            if self.Destroyed or self._window.Destroyed then self._busy=false; return end
            local ok,err = true,nil
            if type(self._callback) == "function" then ok,err = pcall(self._callback,self) end
            if not ok then warn("[RetroBox] Button " .. self.Id .. ": " .. tostring(err)) end
            self._busy = false
        end)
        return true
    end
    self.Button = action
    self:SetDisabled(self.Disabled)
    return self
end

function Section:AddInput(options)
    options = options or {}
    local self = base(self, "Input", options, options.Multiline and 155 or 80)
    self.MaxLength = options.MaxLength or 256
    assert(finite(self.MaxLength) and self.MaxLength >= 1, "MaxLength must be positive")
    local input = textbox(self._window,self.Frame,"",{
        Position=U2(0,44),Size=UDim2.new(1,0,0,options.Multiline and 104 or 32),
        PlaceholderText=options.Placeholder or "",MultiLine=options.Multiline == true,
        TextWrapped=options.Multiline == true,TextYAlignment=options.Multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
    })
    function self:_normalize(value)
        assert(type(value) == "string", "Input value must be a string")
        assert(#value <= self.MaxLength, "Input exceeds MaxLength")
        if options.Validate then
            local ok,reason = options.Validate(value)
            assert(ok,reason or "Invalid input")
        end
        return value
    end
    function self:_render()
        if input.Text ~= self.Value then input.Text = self.Value end
        input.TextEditable = not self.Disabled
    end
    local changing = false
    local function submit()
        if changing or self.Disabled then return end
        local ok,value = pcall(self._normalize,self,input.Text)
        changing = true
        if ok then self:SetValue(value) else input.Text = self.Value end
        changing = false
    end
    connect(self,input.FocusLost,submit)
    if options.Live then connect(self,input:GetPropertyChangedSignal("Text"),submit) end
    self.Input = input
    return init(self,options,"")
end

function Section:AddLabel(options)
    if type(options) == "string" then options = { Title=options } end
    options = options or {}
    local self = base(self,"Label",options,options.Height or 62)
    self.Persist = false
    self.TitleLabel.TextWrapped = true; self.TitleLabel.TextTruncate = Enum.TextTruncate.None
    self.DescriptionLabel.TextWrapped = true; self.DescriptionLabel.TextTruncate = Enum.TextTruncate.None
    self.DescriptionLabel.Size = UDim2.new(1,0,1,-22); self.DescriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
    function self:_normalize(value) return tostring(value) end
    function self:_render() self.TitleLabel.Text = self.Value end
    function self:SetText(value) self.Title=tostring(value); return self:SetValue(tostring(value),true) end
    return init(self,options,self.Title)
end
function Section:AddSeparator(options)
    options = type(options) == "string" and { Title=options } or options or {}
    local self = base(self,"Separator",options,26)
    self.Persist = false; self.DescriptionLabel.Visible = false
    self.TitleLabel.TextSize = 12
    frame(self._window,self.Frame,{ Position=U2(0,24),Size=UDim2.new(1,0,0,1) },"Border")
    function self:_normalize(value) return tostring(value) end
    function self:_render() self.TitleLabel.Text = self.Value end
    return init(self,options,options.Title or "")
end

function Section:AddDropdown(options)
    options = options or {}
    local choices = names(options.Options or {})
    local self = base(self,"Dropdown",options,80)
    self.Options, self.Multi, self.Open = choices, options.Multi == true, false
    local header
    header = button(self._window,self,self.Frame,"",{
        Position=U2(0,44),Size=UDim2.new(1,0,0,30),TextXAlignment=Enum.TextXAlignment.Left,
    },function() self:SetOpen(not self.Open) end)
    ui(self._window,"UIPadding",{ Parent=header,PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,24) })
    label(self._window,header,"v",{ Position=UDim2.new(1,-24,0,0),Size=U2(20,30),TextXAlignment=Enum.TextXAlignment.Center })
    local panel = frame(self._window,self.Frame,{ Position=U2(0,79),Size=UDim2.new(1,0,0,184),Visible=false },"Inset")
    bevel(self._window,panel,true)
    local search = textbox(self._window,panel,"",{ Position=U2(6,6),Size=UDim2.new(1,-12,0,28),PlaceholderText=self._window:_text("search"),Visible=options.Searchable ~= false })
    local results = ui(self._window,"ScrollingFrame",{
        Parent=panel,Position=U2(6,options.Searchable == false and 6 or 40),
        Size=UDim2.new(1,-12,1,options.Searchable == false and -12 or -46),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,
        CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollingDirection=Enum.ScrollingDirection.Y,
    },{ ScrollBarImageColor3="Border" })
    list(self._window,results,3)
    self._optionConnections = {}
    function self:_normalize(value)
        if self.Multi then
            assert(type(value) == "table", "Multi dropdown value must be an array")
            local selected = {}
            for _, item in ipairs(value) do
                local name = tostring(item)
                assert(table.find(self.Options,name), "Unknown dropdown option: " .. name)
                selected[name] = true
            end
            local normalized = {}
            for _, name in ipairs(self.Options) do if selected[name] then table.insert(normalized,name) end end
            return normalized
        end
        if value == nil then return nil end
        local name = tostring(value)
        assert(table.find(self.Options,name), "Unknown dropdown option: " .. name)
        return name
    end
    function self:_render()
        local text = self.Multi and (#self.Value > 0 and table.concat(self.Value,", ") or self._window:_text("choose"))
            or self.Value or self._window:_text("choose")
        header.Text = text
        header.TextTruncate = Enum.TextTruncate.AtEnd
        header.TextTransparency = self.Disabled and .5 or 0
        header.Active = not self.Disabled
        for name, item in pairs(self._rows or {}) do
            local selected = self.Multi and table.find(self.Value,name) ~= nil or not self.Multi and self.Value == name
            item.Text = (selected and "[X] " or "[ ] ") .. name
            item.TextColor3 = self._window.Palette[selected and "Accent" or "Text"]
        end
        if self.Disabled and self.Open then self:SetOpen(false) end
    end
    function self:_rebuild()
        for _, c in ipairs(self._optionConnections) do c:Disconnect() end
        self._optionConnections = {}
        for _, object in ipairs(results:GetChildren()) do if object:IsA("GuiObject") then object:Destroy() end end
        self._rows = {}
        local query = search.Text:lower()
        local count = 0
        for index, name in ipairs(self.Options) do
            if query == "" or name:lower():find(query,1,true) then
                count = count + 1
                local item = button(self._window,self,results,"",{ LayoutOrder=index,Size=UDim2.new(1,-6,0,28),TextXAlignment=Enum.TextXAlignment.Left })
                ui(self._window,"UIPadding",{ Parent=item,PaddingLeft=UDim.new(0,6) })
                self._rows[name] = item
                local connection = item.Activated:Connect(function()
                    if self.Disabled or self.Destroyed then return end
                    if self.Multi then
                        local value = self:GetValue()
                        local selected = table.find(value,name)
                        if selected then table.remove(value,selected) else table.insert(value,name) end
                        self:SetValue(value)
                    else
                        self:SetValue(name); self:SetOpen(false)
                    end
                end)
                table.insert(self._optionConnections,connection)
            end
        end
        if count == 0 then label(self._window,results,self._window:_text("empty"),{ Size=UDim2.new(1,0,0,28),TextSize=12 },"Muted") end
        if self.Value ~= nil or self.Multi then self:_render() end
    end
    function self:SetOpen(open)
        if self.Destroyed then return self end
        open = open == true and not self.Disabled
        if open and self._window._openDropdown and self._window._openDropdown ~= self then self._window._openDropdown:SetOpen(false) end
        self.Open = open
        panel.Visible = open
        self.Frame.Size = UDim2.new(1,0,0,open and 272 or 80)
        if open then self._window._openDropdown = self
        elseif self._window._openDropdown == self then self._window._openDropdown = nil end
        return self
    end
    function self:SetOptions(newOptions, preserve)
        local newNames = names(newOptions)
        self.Options = newNames
        local value = self.Multi and {} or nil
        if preserve ~= false then
            if self.Multi then
                for _, name in ipairs(self.Value) do if table.find(newNames,name) then table.insert(value,name) end end
            elseif table.find(newNames,self.Value) then value = self.Value end
        end
        self:SetValue(value,true); self:_rebuild()
        self._window:_scheduleSave()
        return self
    end
    local inheritedDestroy = self.Destroy
    function self:Destroy()
        for _, c in ipairs(self._optionConnections) do c:Disconnect() end
        self._optionConnections = {}
        inheritedDestroy(self)
    end
    connect(self,search:GetPropertyChangedSignal("Text"),function() self:_rebuild() end)
    self.Button = header; self.SearchInput = search
    self.Value = self.Multi and {} or nil
    self:_rebuild()
    return init(self,options,self.Multi and {} or choices[1])
end

function Section:AddKeybind(options)
    options = options or {}
    assert(options.Mode == nil or options.Mode == "Press" or options.Mode == "Toggle" or options.Mode == "Hold", "Keybind Mode must be Press, Toggle, or Hold")
    local initial = keycode(options.Default or Enum.KeyCode.Unknown)
    local self = base(self,"Keybind",options,#tostring(options.Description or "") > 0 and 46 or 30)
    self.Mode, self.Active = options.Mode or "Press", false
    self.CaptureOnly = options.CaptureOnly == true
    self.TitleLabel.Size = UDim2.new(1,-116,0,23)
    self.DescriptionLabel.Size = UDim2.new(1,-116,0,18)
    local capture
    capture = button(self._window,self,self.Frame,"",{
        Position=UDim2.new(1,-106,0,0),Size=U2(104,28),TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd,
    },function()
        if self._window._binding == self then self._window._binding = nil; self:_render(); return end
        local previous = self._window._binding
        self._window._binding = nil
        if previous and previous ~= self then previous:_render() end
        self._window._binding = self; capture.Text = "..."
        self._window:Notify({ Title=self.Title,Content=self._window:_text("capture"),Duration=2 })
    end)
    function self:_normalize(value) return keycode(value) end
    function self:_render()
        capture.Text = self._window._binding == self and "..." or (self.Value.Name == "Unknown" and "---" or self.Value.Name)
        capture.TextTransparency = self.Disabled and .5 or 0
    end
    function self:_callbackNow() end
    function self:Trigger(active)
        if self.Destroyed or self.Disabled or self.CaptureOnly then return end
        if self.Mode == "Toggle" then self.Active = not self.Active
        elseif self.Mode == "Hold" then self.Active = active == true
        else self.Active = true end
        call(self._window,self._callback,self.Active,self.Value)
        if self.Mode == "Press" then self.Active = false end
    end
    self._window._keybinds[self] = true
    self.Button = capture
    return init(self,options,initial)
end

local function normalizePicker(value, previous, options)
    if typeof(value) == "Color3" or type(value) == "string" then value = { Color=value } end
    assert(type(value) == "table","ColorPicker value must be a color or state table")
    previous = previous or { Color=RGB(255,255,255),Opacity=1,Rainbow=false,Speed=6 }
    local result = copy(previous)
    if value.Color ~= nil then result.Color = parseColor(value.Color) end
    if value.Opacity ~= nil then result.Opacity = value.Opacity end
    if value.Rainbow ~= nil then result.Rainbow = value.Rainbow end
    if value.Speed ~= nil then result.Speed = value.Speed end
    assert(finite(result.Opacity) and result.Opacity >= 0 and result.Opacity <= 1,"Opacity must be between 0 and 1")
    assert(type(result.Rainbow) == "boolean","Rainbow must be boolean")
    assert(finite(result.Speed) and result.Speed >= .1 and result.Speed <= 60,"Speed must be 0.1–60 seconds per cycle")
    if options.AllowRainbow == false then assert(not result.Rainbow,"Rainbow is disabled for this picker") end
    if options.AllowOpacity == false then result.Opacity = 1 end
    return result
end

function Section:AddColorPicker(options)
    options = options or {}
    local self = base(self,"ColorPicker",options,80)
    local window = self._window
    self.Open = options.Expanded == true
    self._hue = 0; self._currentColor = RGB(255,255,255)
    self._pickerOptions = options
    local expand
    expand = button(window,self,self.Frame,"",{
        Position=U2(0,44),Size=UDim2.new(1,0,0,30),TextXAlignment=Enum.TextXAlignment.Left,TextSize=12,
    },function() self:SetOpen(not self.Open) end)
    ui(window,"UIPadding",{ Parent=expand,PaddingLeft=UDim.new(0,42) })
    local swatch = frame(window,expand,{ Position=U2(7,6),Size=U2(26,18),BorderSizePixel=1 },"Accent")
    window:_bind(swatch,{ BorderColor3="Border" })
    local panel = frame(window,self.Frame,{ Position=U2(0,80),Size=UDim2.new(1,0,0,244),Visible=self.Open },"Inset")
    bevel(window,panel,true)
    local sv = frame(window,panel,{ Position=U2(8,8),Size=UDim2.new(1,-16,0,100),Active=true })
    local white = frame(window,sv,{ Size=UDim2.fromScale(1,1),BackgroundColor3=RGB(255,255,255) })
    ui(window,"UIGradient",{ Parent=white,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}) })
    local black = frame(window,sv,{ Size=UDim2.fromScale(1,1),BackgroundColor3=RGB(0,0,0) })
    ui(window,"UIGradient",{ Parent=black,Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}) })
    local marker = frame(window,sv,{ AnchorPoint=Vector2.new(.5,.5),Size=U2(8,8),BackgroundColor3=RGB(255,255,255),BorderSizePixel=1,BorderColor3=RGB(0,0,0) })
    local hueBar = frame(window,panel,{ Position=U2(8,114),Size=UDim2.new(1,-16,0,16),BackgroundColor3=RGB(255,255,255),Active=true })
    local keys = {}
    for i=0,6 do table.insert(keys,ColorSequenceKeypoint.new(i/6,Color3.fromHSV(i/6,1,1))) end
    ui(window,"UIGradient",{ Parent=hueBar,Color=ColorSequence.new(keys) })
    local hueMarker = frame(window,hueBar,{ Size=U2(3,20),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(0,0,.5,0),BackgroundColor3=RGB(255,255,255),BorderSizePixel=1,BorderColor3=RGB(0,0,0) })
    local fields = {}
    local channelRow = frame(window,panel,{ Position=U2(8,138),Size=UDim2.new(1,-16,0,28),BackgroundTransparency=1 })
    for i,name in ipairs({"R","G","B"}) do
        local group = frame(window,channelRow,{ Position=UDim2.new((i-1)/3,0,0,0),Size=UDim2.new(1/3,-5,1,0),BackgroundTransparency=1 })
        label(window,group,name,{ Size=U2(16,28),TextSize=12 },"Muted")
        fields[i] = textbox(window,group,"",{ Position=U2(18,0),Size=UDim2.new(1,-18,1,0),TextSize=12 })
    end
    local hexBox = textbox(window,panel,"",{ Position=U2(8,172),Size=UDim2.new(.58,-12,0,28),PlaceholderText="#RRGGBB",TextSize=12 })
    local opacityBox = textbox(window,panel,"100",{ Position=UDim2.new(.7,0,0,172),Size=UDim2.new(.3,-8,0,28),TextSize=12,Visible=options.AllowOpacity ~= false })
    label(window,panel,"%",{ Position=UDim2.new(.61,0,0,172),Size=UDim2.new(.08,0,0,28),TextXAlignment=Enum.TextXAlignment.Center,Visible=options.AllowOpacity ~= false },"Muted")
    local rainbow
    rainbow = button(window,self,panel,window:_text("rainbow"),{
        Position=U2(8,208),Size=UDim2.new(.58,-12,0,28),TextSize=12,Visible=options.AllowRainbow ~= false,
    },function() self:SetRainbow(not self.Value.Rainbow) end)
    local speedBox = textbox(window,panel,"6",{ Position=UDim2.new(.58,0,0,208),Size=UDim2.new(.18,-4,0,28),TextSize=12,Visible=options.AllowRainbow ~= false })
    label(window,panel,window:_text("cycle"),{ Position=UDim2.new(.76,0,0,208),Size=UDim2.new(.24,-8,0,28),TextSize=11,Visible=options.AllowRainbow ~= false },"Muted")
    function self:_normalize(value) return normalizePicker(value,self.Value,options) end
    function self:_render()
        local state = self.Value
        local h,s,v = state.Color:ToHSV()
        if s > 0 and v > 0 or self._manualHue == nil then self._manualHue = h end
        sv.BackgroundColor3 = Color3.fromHSV(self._manualHue,1,1)
        marker.Position = UDim2.fromScale(s,1-v)
        hueMarker.Position = UDim2.new(self._manualHue,0,.5,0)
        self._currentColor = state.Rainbow and Color3.fromHSV(self._hue,.85,1) or state.Color
        swatch.BackgroundColor3 = self._currentColor; swatch.BackgroundTransparency = 1-state.Opacity
        expand.Text = hex(state.Color) .. (state.Rainbow and "  RGB" or "")
        expand.TextTransparency = self.Disabled and .5 or 0
        for i,value in ipairs({state.Color.R,state.Color.G,state.Color.B}) do
            fields[i].Text = tostring(math.floor(value*255+.5)); fields[i].TextEditable = not self.Disabled and not state.Rainbow
        end
        hexBox.Text = hex(state.Color); hexBox.TextEditable = not self.Disabled and not state.Rainbow
        opacityBox.Text = tostring(math.floor(state.Opacity*100+.5)); opacityBox.TextEditable = not self.Disabled
        speedBox.Text = tostring(state.Speed); speedBox.TextEditable = not self.Disabled and state.Rainbow
        rainbow.Text = (state.Rainbow and "[X] " or "[ ] ") .. window:_text("rainbow")
        window._rainbows[self] = state.Rainbow and true or nil
        window:_updateRGB()
    end
    function self:GetColor() return self._currentColor end
    function self:SetColor(value,silent)
        local state=self:GetValue(); state.Color=parseColor(value); return self:SetValue(state,silent)
    end
    function self:SetRainbow(value,silent)
        local state=self:GetValue(); state.Rainbow=value; return self:SetValue(state,silent)
    end
    function self:SetOpacity(value,silent)
        local state=self:GetValue(); state.Opacity=value; return self:SetValue(state,silent)
    end
    function self:SetSpeed(value,silent)
        local state=self:GetValue(); state.Speed=value; return self:SetValue(state,silent)
    end
    function self:SetOpen(value)
        self.Open=value == true; panel.Visible=self.Open
        self.Frame.Size=UDim2.new(1,0,0,self.Open and 334 or 80)
        return self
    end
    function self:_animate(delta)
        self._hue=(self._hue+delta/self.Value.Speed)%1
        self._currentColor=Color3.fromHSV(self._hue,.85,1)
        swatch.BackgroundColor3=self._currentColor
        self:_callbackNow()
    end
    local function dragSV(input)
        if self.Value.Rainbow then return end
        window:_beginDrag(self,input,function(p)
            local size=sv.AbsoluteSize; if size.X <= 0 or size.Y <= 0 then return end
            local s=clamp((p.X-sv.AbsolutePosition.X)/size.X,0,1)
            local v=1-clamp((p.Y-sv.AbsolutePosition.Y)/size.Y,0,1)
            self:SetColor(Color3.fromHSV(self._manualHue or 0,s,v))
        end)
    end
    connect(self,sv.InputBegan,dragSV); connect(self,white.InputBegan,dragSV); connect(self,black.InputBegan,dragSV)
    connect(self,hueBar.InputBegan,function(input)
        if self.Value.Rainbow then return end
        window:_beginDrag(self,input,function(p)
            if hueBar.AbsoluteSize.X <= 0 then return end
            local h=clamp((p.X-hueBar.AbsolutePosition.X)/hueBar.AbsoluteSize.X,0,.99999)
            local _,s,v=self.Value.Color:ToHSV()
            self._manualHue=h; self:SetColor(Color3.fromHSV(h,s,v))
        end)
    end)
    for _,field in ipairs(fields) do
        connect(self,field.FocusLost,function()
            if self.Disabled or self.Value.Rainbow then self:_render(); return end
            local values={}
            for i,item in ipairs(fields) do
                local n=tonumber(item.Text); if not finite(n) then self:_render(); return end
                values[i]=clamp(math.floor(n+.5),0,255)
            end
            self:SetColor(RGB(table.unpack(values)))
        end)
    end
    connect(self,hexBox.FocusLost,function()
        if self.Disabled or self.Value.Rainbow then self:_render(); return end
        local ok,value=pcall(parseColor,hexBox.Text)
        if ok then self:SetColor(value) else self:_render() end
    end)
    connect(self,opacityBox.FocusLost,function()
        local n=tonumber(opacityBox.Text)
        if finite(n) and not self.Disabled then self:SetOpacity(clamp(n/100,0,1)) else self:_render() end
    end)
    connect(self,speedBox.FocusLost,function()
        local n=tonumber(speedBox.Text)
        if finite(n) and not self.Disabled then self:SetSpeed(clamp(n,.1,60)) else self:_render() end
    end)
    self.Button=expand; self.Swatch=swatch; self.HexInput=hexBox
    init(self,options,{ Color=options.Color or RGB(100,159,219),Opacity=options.Opacity or 1,Rainbow=options.Rainbow == true,Speed=options.Speed or 6 })
    self:SetOpen(self.Open)
    return self
end

function Section:AddProgress(options)
    options=options or {}
    local self=base(self,"Progress",options,69)
    self.Persist=options.Persist == true
    self.Min,self.Max=options.Min or 0,options.Max or 100
    assert(finite(self.Min) and finite(self.Max) and self.Max>self.Min,"Progress requires finite Min < Max")
    local track=frame(self._window,self.Frame,{ Position=U2(0,45),Size=UDim2.new(1,0,0,14) },"Inset")
    local fill=frame(self._window,track,{ Size=UDim2.new(0,0,1,0) },"Accent")
    local valueLabel=label(self._window,self.Frame,"",{ Position=UDim2.new(1,-74,0,0),Size=U2(74,22),TextXAlignment=Enum.TextXAlignment.Right,TextSize=12 },"Muted")
    self.TitleLabel.Size=UDim2.new(1,-80,0,22)
    function self:_normalize(value) assert(finite(value),"Progress must be finite"); return clamp(value,self.Min,self.Max) end
    function self:_render()
        local ratio=(self.Value-self.Min)/(self.Max-self.Min)
        fill.Size=UDim2.new(ratio,0,1,0); valueLabel.Text=string.format("%.0f%%",ratio*100)
    end
    return init(self,options,self.Min)
end

function Section:AddConsole(options)
    options=options or {}
    local self=base(self,"Console",options,(options.Height or 160)+44)
    self.Persist=false; self.MaxLines=options.MaxLines or 150; self._lines={}
    assert(finite(self.MaxLines) and self.MaxLines>=1,"Console MaxLines must be positive")
    local scroll=ui(self._window,"ScrollingFrame",{
        Parent=self.Frame,Position=U2(0,42),Size=UDim2.new(1,0,1,-42),BorderSizePixel=1,
        ScrollBarThickness=4,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,
    },{ BackgroundColor3="Inset",BorderColor3="Border",ScrollBarImageColor3="Border" })
    local output=label(self._window,scroll,"",{
        Position=U2(8,6),Size=UDim2.new(1,-20,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,TextSize=12,
    })
    function self:_normalize(value) return tostring(value) end
    function self:_render() output.Text=self.Value end
    function self:Append(message)
        table.insert(self._lines,tostring(message))
        while #self._lines>self.MaxLines do table.remove(self._lines,1) end
        self:SetValue(table.concat(self._lines,"\n"),true)
        task.defer(function()
            if not self.Destroyed then scroll.CanvasPosition=Vector2.new(0,math.max(0,scroll.AbsoluteCanvasSize.Y-scroll.AbsoluteSize.Y)) end
        end)
        return self
    end
    function self:Clear() self._lines={}; return self:SetValue("",true) end
    self.Output=output
    return init(self,options,"")
end

function Section:AddImage(options)
    options=options or {}
    local self=base(self,"Image",options,(options.Height or 140)+44)
    self.Persist=false
    local image=ui(self._window,"ImageLabel",{
        Parent=self.Frame,Position=U2(0,42),Size=UDim2.new(1,0,1,-42),BackgroundTransparency=1,
        Image=tostring(options.Image or ""),ScaleType=Enum.ScaleType.Fit,
    })
    function self:_normalize(value) assert(type(value)=="string","Image must be an asset string"); return value end
    function self:_render() image.Image=self.Value end
    self.Image=image
    return init(self,options,options.Image or "")
end

function Window:_updateRGB()
    if self.Destroyed then return end
    local active = false
    for picker in pairs(self._rainbows) do if not picker.Destroyed and not picker.Disabled then active=true; break end end
    if active and not self._rgbConnection then
        self._rgbElapsed=0
        self._rgbConnection=RunService.Heartbeat:Connect(function(delta)
            self._rgbElapsed=self._rgbElapsed+math.min(delta,.25)
            if self._rgbElapsed<1/30 then return end
            local elapsed=self._rgbElapsed; self._rgbElapsed=0
            for picker in pairs(self._rainbows) do
                if not picker.Destroyed and not picker.Disabled then picker:_animate(elapsed) end
            end
        end)
    elseif not active and self._rgbConnection then
        self._rgbConnection:Disconnect(); self._rgbConnection=nil
    end
end
function Window:GetFlag(id)
    assert(self.Controls[id],"Unknown control: " .. tostring(id))
    return self.Controls[id]:GetValue()
end
function Window:SetFlag(id,value,silent)
    assert(self.Controls[id],"Unknown control: " .. tostring(id))
    self.Controls[id]:SetValue(value,silent)
    return self
end
function Window:GetThemeNames()
    local result=Library:GetThemeNames()
    for name in pairs(self._themeOverrides) do if not table.find(result,name) then table.insert(result,name) end end
    table.sort(result); return result
end
function Window:_applyTheme()
    local colors=self._themeOverrides[self.Theme] or Library.Themes[self.Theme]
    self.Palette=copy(colors)
    if self.Accent then
        self.Palette.Accent=self.Accent
        local c=self.Accent
        self.Palette.AccentText=(c.R*.2126+c.G*.7152+c.B*.0722)>.55 and RGB(20,25,28) or RGB(255,251,239)
    end
    for object,roles in pairs(self._skin) do
        if object.Parent then for property,role in pairs(roles) do object[property]=self.Palette[role] end end
    end
    for _,control in pairs(self.Controls) do if not control.Destroyed and control._render and (control.Value~=nil or control.Type=="Button" or control.Type=="Dropdown") then control:_render() end end
    for _,tab in ipairs(self.Tabs) do tab:_renderSelection() end
    self:_syncSettings()
end
function Window:SetTheme(name,keepAccent)
    assert(self._themeOverrides[name] or Library.Themes[name],"Unknown theme: " .. tostring(name))
    self.Theme=name
    if not keepAccent then self.Accent=nil end
    self:_applyTheme(); self:_scheduleSave()
    return self
end
function Window:SetAccent(color)
    self.Accent=color ~= nil and parseColor(color) or nil
    self:_applyTheme(); self:_scheduleSave()
    return self
end
function Window:SetScale(value)
    assert(finite(value) and value>=.75 and value<=1.5,"Scale must be 0.75–1.5")
    self.UserScale=value; self:_layout(); self:_syncSettings(); self:_scheduleSave()
    return self
end
function Window:SetReducedMotion(value)
    self.ReducedMotion=value == true; self:_syncSettings(); self:_scheduleSave(); return self
end
function Window:SetScanlines(value)
    self.Scanlines=value == true
    if self._scanlineLayer then self._scanlineLayer.Visible=self.Scanlines end
    self:_syncSettings(); self:_scheduleSave(); return self
end
function Window:SetNotifications(value)
    self.NotificationsEnabled=value ~= false; self:_syncSettings(); self:_scheduleSave(); return self
end
function Window:SetLauncher(value)
    self.LauncherEnabled=value ~= false
    self.Launcher.Visible=self.LauncherEnabled and not self.Main.Visible
    self:_syncSettings(); self:_scheduleSave(); return self
end
function Window:SetToggleKey(value)
    self.ToggleKey=keycode(value); self:_syncSettings(); self:_scheduleSave(); return self
end
function Window:SetTitle(value)
    self.Title=tostring(value); self.TitleLabel.Text=self.Title; return self
end
function Window:SetIcon(asset)
    self.Icon.Image=tostring(asset or "")
    self.Icon.Visible=#self.Icon.Image>0
    self.TitleLabel.Position=U2(self.Icon.Visible and 36 or 10,0)
    self.TitleLabel.Size=UDim2.new(1,self.Icon.Visible and -148 or -120,1,0)
    return self
end
function Window:SetSubtitle(value)
    self.Subtitle=tostring(value); self.SubtitleLabel.Text=self.Subtitle; return self
end
function Window:SetProfileVisible(value)
    self.Profile.Visible=value ~= false; return self
end
function Window:OnDestroy(callback)
    assert(not self.Destroyed and type(callback)=="function","OnDestroy requires a live window and a function")
    local owner=self
    local listener={ Connected=true,Callback=callback }
    function listener:Disconnect() self.Connected=false; owner._destroyListeners[self]=nil end
    self._destroyListeners[listener]=true
    return listener
end
function Window:Show()
    if self.Destroyed then return self end
    self.Main.Visible=true; self.Launcher.Visible=false; return self
end
function Window:Hide()
    if self.Destroyed then return self end
    self:_hideTooltip()
    self:ShowSettings(false); self:_endDrag()
    if self._binding then local binding=self._binding; self._binding=nil; binding:_render() end
    self.Main.Visible=false; self.Launcher.Visible=self.LauncherEnabled
    for binding in pairs(self._keybinds) do
        if binding.Mode=="Hold" and binding.Active then binding:Trigger(false) end
    end
    return self
end
function Window:Toggle() if self.Main.Visible then return self:Hide() else return self:Show() end end
function Window:Minimize(value)
    self:_hideTooltip()
    self.Minimized=value == nil and not self.Minimized or value == true
    if self.Minimized then self:ShowSettings(false) end
    self:_layout(); return self
end
function Window:Center()
    self._position=nil; self:_layout(); return self
end
function Window:SetSearch(query)
    self:_hideTooltip()
    self._query=tostring(query or ""):lower()
    for _,tab in ipairs(self.Tabs) do
        if not tab.Hidden then
            for _,section in ipairs(tab.Sections) do
                if not section.Destroyed then
                local visible=false
                for _,control in ipairs(section.Controls) do
                    if not control.Destroyed then
                        local text=(control.Title.." "..control.Description.." "..control.Id.." "..section.Title):lower()
                        control.Frame.Visible=control._visible and (self._query=="" or text:find(self._query,1,true)~=nil)
                        if control.Frame.Visible then visible=true end
                    end
                end
                section.Frame.Visible=section._visible and (visible or #section.Controls==0 and self._query=="")
                end
            end
        end
    end
    return self
end

function Tab:_renderSelection()
    if not self.Button then return end
    local active=self._window.ActiveTab==self
    self.Button.BackgroundColor3=self._window.Palette[active and "Accent" or "Surface"]
    self.Button.TextColor3=self._window.Palette[active and "AccentText" or "Text"]
end
function Tab:Select()
    assert(not self.Destroyed,"Tab has been destroyed")
    if self.Hidden then return self end
    local window=self._window
    window:_hideTooltip()
    window.ActiveTab=self
    if window._openDropdown then window._openDropdown:SetOpen(false) end
    for _,tab in ipairs(window.Tabs) do if not tab.Hidden then tab.Frame.Visible=tab==self end; tab:_renderSelection() end
    window.Status.Text=self.Title.."  |  v"..Library.Version
    return self
end
function Tab:_layout()
    if self.Destroyed then return end
    local two=self.Columns==2 and self.Frame.AbsoluteSize.X>=510
    self.ColumnLayout.FillDirection=two and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
    self.Left.Size=UDim2.new(two and .5 or 1,two and -6 or 0,0,0)
    self.Right.Size=UDim2.new(two and .5 or 1,two and -6 or 0,0,0)
    self.Right.Visible=self.Columns==2
end
function Window:CreateTab(options)
    if type(options)=="string" then options={ Title=options } end
    options=options or {}
    assert(not self.Destroyed,"Window has been destroyed")
    assert(options.Columns==nil or options.Columns==1 or options.Columns==2,"Columns must be 1 or 2")
    local selfTab=setmetatable({ Title=tostring(options.Title or "Tab"),Columns=options.Columns or 1,Hidden=options.Hidden==true,
        _window=self,_connections={},Sections={},_sectionCount=0 },Tab)
    selfTab.Frame=ui(self,"ScrollingFrame",{
        Name=selfTab.Title,Parent=self.PageHost,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
        BorderSizePixel=0,ScrollBarThickness=5,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollingDirection=Enum.ScrollingDirection.Y,Visible=false,ClipsDescendants=true,
    },{ ScrollBarImageColor3="Border" })
    selfTab.Container=frame(self,selfTab.Frame,{ Position=U2(0,0),Size=UDim2.new(1,-10,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1 })
    selfTab.ColumnLayout=list(self,selfTab.Container,12,false)
    selfTab.Left=frame(self,selfTab.Container,{ LayoutOrder=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1 })
    selfTab.Right=frame(self,selfTab.Container,{ LayoutOrder=2,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Visible=selfTab.Columns==2 })
    list(self,selfTab.Left,14); list(self,selfTab.Right,14)
    selfTab.Button=button(self,selfTab,self.Nav,(options.Icon and tostring(options.Icon).."  " or "")..selfTab.Title,{
        LayoutOrder=#self.Tabs+1,Size=U2(158,34),TextXAlignment=Enum.TextXAlignment.Left,TextSize=13,Visible=not selfTab.Hidden,
        TextTruncate=Enum.TextTruncate.AtEnd,
    },function() selfTab:Select() end)
    ui(self,"UIPadding",{ Parent=selfTab.Button,PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,6) })
    table.insert(self.Tabs,selfTab)
    connect(selfTab,selfTab.Frame:GetPropertyChangedSignal("AbsoluteSize"),function() selfTab:_layout() end)
    connect(selfTab,selfTab.Frame.Destroying,function() if not selfTab.Destroyed then selfTab:Destroy() end end)
    selfTab:_layout(); self:_layout()
    if not self.ActiveTab and not selfTab.Hidden then selfTab:Select() end
    return selfTab
end
function Tab:CreateSection(options)
    if type(options)=="string" then options={ Title=options } end
    options=options or {}
    assert(not self.Destroyed,"Tab has been destroyed")
    self._sectionCount=self._sectionCount+1
    local section=setmetatable({ Title=tostring(options.Title or "Section"),_window=self._window,_tab=self,_connections={},Controls={},_count=0,_visible=options.Visible~=false },Section)
    if options.Side=="Right" then self.Columns=2 end
    section.Frame=frame(self._window,options.Side=="Right" and self.Right or self.Left,{
        Name=section.Title,LayoutOrder=self._sectionCount,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BorderSizePixel=1,Visible=section._visible,
    },"Surface")
    self._window:_bind(section.Frame,{ BackgroundColor3="Surface",BorderColor3="Border" })
    local padding=ui(self._window,"UIPadding",{ Parent=section.Frame,PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,12) })
    list(self._window,section.Frame,8)
    section.Header=label(self._window,section.Frame,section.Title:upper(),{ LayoutOrder=1,Size=UDim2.new(1,0,0,21),TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd },"Muted")
    section.Content=frame(self._window,section.Frame,{ LayoutOrder=2,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1 })
    list(self._window,section.Content,10)
    table.insert(self.Sections,section)
    connect(section,section.Frame.Destroying,function() if not section.Destroyed then section:Destroy() end end)
    self:_layout()
    return section
end
function Section:SetTitle(value) self.Title=tostring(value); self.Header.Text=self.Title:upper(); return self end
function Section:SetVisible(value) self._visible=value~=false; self._window:SetSearch(self._window._query); return self end
function Section:Destroy()
    if self.Destroyed then return end
    self.Destroyed=true
    local controls={}
    for _,control in ipairs(self.Controls) do table.insert(controls,control) end
    for _,control in ipairs(controls) do control:Destroy() end
    cleanup(self); self.Frame:Destroy()
    local index=table.find(self._tab.Sections,self)
    if index then table.remove(self._tab.Sections,index) end
end
function Tab:Destroy()
    if self.Destroyed then return end
    self.Destroyed=true
    local window=self._window
    local sections={}
    for _,section in ipairs(self.Sections) do table.insert(sections,section) end
    for _,section in ipairs(sections) do section:Destroy() end
    cleanup(self); self.Frame:Destroy(); self.Button:Destroy()
    local index=table.find(window.Tabs,self); if index then table.remove(window.Tabs,index) end
    if window.ActiveTab==self then
        window.ActiveTab=nil
        for _,tab in ipairs(window.Tabs) do if not tab.Hidden and not tab.Destroyed then tab:Select(); break end end
    end
end

local function encode(control)
    local value=control:GetValue()
    if control.Type=="ColorPicker" then value.Color=hex(value.Color)
    elseif control.Type=="Keybind" then value=value.Name end
    return { Type=control.Type,Value=value }
end
function Window:ExportConfig(asTable)
    local flags={}
    for id,control in pairs(self.Controls) do
        if control.Persist and not control.Destroyed then flags[id]=encode(control) end
    end
    local colors={}
    for role,color in pairs(self._themeOverrides[self.Theme] or Library.Themes[self.Theme]) do colors[role]=hex(color) end
    local result={
        Library="RetroBox UI",Schema=1,Version=Library.Version,Flags=flags,
        Appearance={ Theme=self.Theme,ThemeColors=colors,Accent=self.Accent and hex(self.Accent) or nil,
            Scale=self.UserScale,ReducedMotion=self.ReducedMotion,Scanlines=self.Scanlines,
            Notifications=self.NotificationsEnabled,Launcher=self.LauncherEnabled,ToggleKey=self.ToggleKey.Name },
    }
    if asTable then return result end
    return HttpService:JSONEncode(result)
end
function Window:ImportConfig(source,options)
    options=options or {}
    if self.Destroyed then return false,"Window has been destroyed" end
    if type(source)=="string" and #source>self.MaxConfigBytes then return false,"Configuration exceeds MaxConfigBytes" end
    local ok,prepared=pcall(function()
        local config=type(source)=="string" and HttpService:JSONDecode(source) or source
        assert(type(config)=="table" and config.Library=="RetroBox UI" and config.Schema==1,"Unsupported configuration format")
        assert(type(config.Flags)=="table","Missing Flags")
        local changes={}
        for id,record in pairs(config.Flags) do
            assert(type(id)=="string","Flag Id must be a string")
            local control=self.Controls[id]
            if control and control.Persist then
                assert(type(record)=="table" and record.Type==control.Type,"Control type mismatch: "..id)
                changes[id]={ Value=control:_normalize(record.Value) }
            elseif options.Strict then error("Unknown or nonpersistent control: "..id) end
        end
        local look=config.Appearance or {}
        assert(type(look)=="table","Appearance must be a table")
        local appearance={ Theme=self.Theme,Scale=self.UserScale,
            ReducedMotion=look.ReducedMotion,Scanlines=look.Scanlines,Notifications=look.Notifications,Launcher=look.Launcher,
            ToggleKey=self.ToggleKey }
        if look.Theme~=nil then appearance.Theme=look.Theme end
        if look.Scale~=nil then appearance.Scale=look.Scale end
        if look.ToggleKey~=nil then appearance.ToggleKey=keycode(look.ToggleKey) end
        if config.Appearance==nil then appearance.Accent=self.Accent end
        assert(type(appearance.Theme)=="string" and #appearance.Theme>0,"Invalid theme name")
        assert(finite(appearance.Scale) and appearance.Scale>=.75 and appearance.Scale<=1.5,"Invalid interface scale")
        for _,key in ipairs({"ReducedMotion","Scanlines","Notifications","Launcher"}) do
            assert(appearance[key]==nil or type(appearance[key])=="boolean","Invalid appearance field: "..key)
        end
        if look.Accent~=nil then appearance.Accent=parseColor(look.Accent) end
        if look.ThemeColors then
            assert(type(look.ThemeColors)=="table","ThemeColors must be a table")
            appearance.Colors=copy(Library.Themes.Retro98)
            for role,color in pairs(look.ThemeColors) do
                assert(appearance.Colors[role]~=nil,"Unknown palette role: "..tostring(role))
                appearance.Colors[role]=parseColor(color)
            end
        else
            assert(self._themeOverrides[appearance.Theme] or Library.Themes[appearance.Theme],"Unknown theme: "..appearance.Theme)
        end
        return { Changes=changes,Appearance=appearance }
    end)
    if not ok then return false,tostring(prepared) end
    self._importing=true
    local look=prepared.Appearance
    if look.Colors then self._themeOverrides[look.Theme]=look.Colors end
    self.Theme=look.Theme; self.Accent=look.Accent; self.UserScale=look.Scale; self.ToggleKey=look.ToggleKey
    if look.ReducedMotion~=nil then self.ReducedMotion=look.ReducedMotion end
    if look.Scanlines~=nil then self.Scanlines=look.Scanlines end
    if look.Notifications~=nil then self.NotificationsEnabled=look.Notifications end
    if look.Launcher~=nil then self.LauncherEnabled=look.Launcher end
    for id,record in pairs(prepared.Changes) do self.Controls[id]:SetValue(record.Value,true) end
    self:_applyTheme(); self:_layout()
    self:SetScanlines(self.Scanlines); self:SetLauncher(self.LauncherEnabled)
    if not options.Silent then for id in pairs(prepared.Changes) do self.Controls[id]:_emit() end end
    self._importing=false; self:_scheduleSave()
    return true
end
local function profileName(name)
    assert(type(name)=="string" and #name>=1 and #name<=64,"Profile name must contain 1–64 bytes")
    assert(not name:find("[%c/\\]"),"Profile name cannot contain slashes or control characters")
    return name
end
local function filePart(text)
    -- Reversible byte encoding prevents collisions, separators and reserved names.
    return (text:gsub("[^%w_-]",function(byte) return string.format("%%%02X",byte:byte()) end))
end
local function folderName(folder)
    assert(type(folder)=="string" and #folder>0 and #folder<=180,"ConfigFolder must contain 1–180 bytes")
    assert(not folder:find("[%c\\:*?\"<>|]") and not folder:match("^/") and not folder:match("/$") and not folder:find("//",1,true),"ConfigFolder must be a relative path with portable folder names")
    for segment in folder:gmatch("[^/]+") do
        assert(segment~="." and segment~=".." and not segment:match("[. ]$"),"ConfigFolder cannot contain dot segments or trailing dots/spaces")
        local stem=segment:match("^([^.]*)"):upper()
        assert(stem~="CON" and stem~="PRN" and stem~="AUX" and stem~="NUL" and not stem:match("^COM[1-9]$") and not stem:match("^LPT[1-9]$"),"ConfigFolder contains a reserved folder name")
    end
    return folder
end
function Library:GetCapabilities()
    return {
        GetHui=type(gethui)=="function",
        ReadFile=type(readfile)=="function",WriteFile=type(writefile)=="function",
        MakeFolder=type(makefolder)=="function",IsFile=type(isfile)=="function",IsFolder=type(isfolder)=="function",
        FileStorage=type(readfile)=="function" and type(writefile)=="function" and type(makefolder)=="function",
    }
end
function Library:CreateFileStorage(folder)
    folder=folderName(folder or "RetroBox")
    if not self:GetCapabilities().FileStorage then return nil,"Executor does not expose readfile, writefile and makefolder" end
    -- Capture this executor's functions; no folder or file is created until Save.
    local read,write,mkdir=readfile,writefile,makefolder
    local hasFile=type(isfile)=="function" and isfile or nil
    local hasFolder=type(isfolder)=="function" and isfolder or nil
    local function ensureFolders()
        local path=""
        for segment in folder:gmatch("[^/]+") do
            path=path=="" and segment or path.."/"..segment
            if not hasFolder or not hasFolder(path) then mkdir(path) end
        end
    end
    local function path(name) return folder.."/profile-"..filePart(profileName(name))..".json" end
    return {
        Kind="file",Folder=folder,
        Save=function(name,json)
            assert(type(json)=="string","Storage expects JSON text")
            local target=path(name); ensureFolders()
            local result=write(target,json)
            assert(result~=false,"Executor refused to write the profile")
            return true
        end,
        Load=function(name)
            local target=path(name)
            if hasFile and not hasFile(target) then return nil,"Profile was not found" end
            return read(target)
        end,
    }
end
function Window:SetStorage(adapter)
    assert(type(adapter)=="table" and type(adapter.Save)=="function" and type(adapter.Load)=="function","Storage requires Save and Load functions")
    self.Storage=adapter; self.StorageMode=adapter.Kind or "custom"; return self
end
function Window:SaveConfig(name)
    if self.Destroyed then return false,"Window has been destroyed" end
    local ok,result=pcall(function()
        profileName(name)
        local json=self:ExportConfig()
        assert(#json<=self.MaxConfigBytes,"Configuration exceeds MaxConfigBytes")
        if self.Storage then
            local success,reason=self.Storage.Save(name,json)
            assert(success~=false,reason or "Storage refused save")
        end
        self._profiles[name]=json
        return json
    end)
    return ok,result
end
function Window:LoadConfig(name,options)
    if self.Destroyed then return false,"Window has been destroyed" end
    local ok,data=pcall(function()
        profileName(name)
        local value=self._profiles[name]
        if self.Storage then
            local loaded,err=self.Storage.Load(name)
            assert(loaded~=nil,err or "Profile was not found")
            value=loaded
        end
        assert(type(value)=="string" or type(value)=="table","Profile was not found")
        return value
    end)
    if not ok then return false,tostring(data) end
    return self:ImportConfig(data,options)
end
function Window:GetConfigNames()
    local result={}
    for name in pairs(self._profiles) do table.insert(result,name) end
    table.sort(result); return result
end
function Window:Reset(silent)
    self._importing=true
    for _,control in pairs(self.Controls) do if control.Persist and control._hasDefault then control:SetValue(control._default,true) end end
    self.Theme=self._initial.Theme; self.Accent=self._initial.Accent; self.UserScale=self._initial.Scale
    self._themeOverrides[self._initial.Theme]=copy(self._initial.ThemeColors)
    self.ReducedMotion=self._initial.ReducedMotion; self.Scanlines=self._initial.Scanlines
    self.NotificationsEnabled=self._initial.Notifications; self.LauncherEnabled=self._initial.Launcher
    self.ToggleKey=self._initial.ToggleKey
    self:_applyTheme(); self:_layout(); self:SetScanlines(self.Scanlines); self:SetLauncher(self.LauncherEnabled)
    if not silent then for _,control in pairs(self.Controls) do if control.Persist then control:_emit() end end end
    self._importing=false; self:_scheduleSave(); return self
end

function Window:_layout()
    if self.Destroyed or not self.Main then return end
    self:_hideTooltip()
    local view=self.Root.AbsoluteSize
    if view.X<=0 or view.Y<=0 then view=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720) end
    self.Mobile=view.X<640*self.UserScale
    local availableW,availableH=math.max(240,view.X-24),math.max(220,view.Y-56)
    local width=self.Mobile and math.max(300,math.min(430,availableW/self.UserScale)) or self._requestedSize.X
    local height=math.max(300,math.min(self._requestedSize.Y,availableH/self.UserScale))
    local scale=math.min(self.UserScale,availableW/width,availableH/height)
    if self._maximized then width=availableW/self.UserScale; height=availableH/self.UserScale; scale=self.UserScale end
    self._actualScale=scale; self._logicalSize=Vector2.new(width,height)
    self.ScaleObject.Scale=scale
    local renderedHeight=self.Minimized and 42 or height
    self.Main.Size=U2(width,renderedHeight)
    self.SubtitleLabel.Visible=not self.Minimized
    self.Nav.Visible=not self.Minimized; self.Search.Visible=not self.Minimized
    self.PageHost.Visible=not self.Minimized; self.Footer.Visible=not self.Minimized
    if self.Mobile then
        self.Nav.Position=U2(10,70); self.Nav.Size=UDim2.new(1,-20,0,38)
        self.NavLayout.FillDirection=Enum.FillDirection.Horizontal
        self.Nav.AutomaticCanvasSize=Enum.AutomaticSize.X; self.Nav.ScrollingDirection=Enum.ScrollingDirection.X
        self.Search.Position=U2(10,116); self.Search.Size=UDim2.new(1,-20,0,30)
        self.PageHost.Position=U2(10,156); self.PageHost.Size=UDim2.new(1,-20,1,-220)
    else
        self.Nav.Position=U2(10,76); self.Nav.Size=UDim2.new(0,160,1,-141)
        self.NavLayout.FillDirection=Enum.FillDirection.Vertical
        self.Nav.AutomaticCanvasSize=Enum.AutomaticSize.Y; self.Nav.ScrollingDirection=Enum.ScrollingDirection.Y
        self.Search.Position=U2(184,73); self.Search.Size=UDim2.new(1,-198,0,30)
        self.PageHost.Position=U2(184,114); self.PageHost.Size=UDim2.new(1,-198,1,-178)
    end
    self.Status.Visible=not self.Mobile; self.ResizeGrip.Visible=not self.Mobile and not self._maximized
    for _,tab in ipairs(self.Tabs) do
        tab.Button.Size=self.Mobile and U2(136,34) or UDim2.new(1,-6,0,34)
        tab:_layout()
    end
    local size=Vector2.new(width*scale,renderedHeight*scale)
    local center=self._position or Vector2.new(view.X/2,view.Y/2)
    center=Vector2.new(clamp(center.X,size.X/2+8,math.max(size.X/2+8,view.X-size.X/2-8)),
        clamp(center.Y,size.Y/2+24,math.max(size.Y/2+24,view.Y-size.Y/2-8)))
    self.Main.Position=U2(center.X,center.Y)
    if self._position then self._position=center end
end

function Window:_syncSettings()
    if not self._settingsControls or self._syncingSettings then return end
    self._syncingSettings=true
    local controls=self._settingsControls
    controls.Theme:SetOptions(self:GetThemeNames(),true); controls.Theme:SetValue(self.Theme,true)
    controls.Accent:SetColor(self.Palette.Accent,true)
    controls.Scale:SetValue(self.UserScale,true)
    controls.Motion:SetValue(self.ReducedMotion,true)
    controls.Scanlines:SetValue(self.Scanlines,true)
    controls.Notifications:SetValue(self.NotificationsEnabled,true)
    controls.Launcher:SetValue(self.LauncherEnabled,true)
    controls.Shortcut:SetValue(self.ToggleKey,true)
    self._syncingSettings=false
end
function Window:_createSettings()
    if self._settingsOverlay then return end
    local overlay=ui(self,"TextButton",{
        Parent=self.Main,Name="SettingsOverlay",Size=UDim2.fromScale(1,1),BackgroundColor3=RGB(0,0,0),
        BackgroundTransparency=.35,Text="",BorderSizePixel=0,ZIndex=40,AutoButtonColor=false,Visible=false,
    })
    local panel=frame(self,overlay,{ AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        Size=UDim2.new(1,-32,1,-52),ZIndex=41,BorderSizePixel=1 },"Background")
    self:_bind(panel,{ BackgroundColor3="Background",BorderColor3="Border" }); bevel(self,panel,false)
    label(self,panel,self:_text("settings"),{ Position=U2(12,7),Size=UDim2.new(1,-52,0,28),TextSize=13 })
    button(self,self,panel,"X",{ Position=UDim2.new(1,-36,0,8),Size=U2(26,26),ZIndex=42 },function() self:ShowSettings(false) end)
    local tab=self:CreateTab({ Title=self:_text("settings"),Hidden=true,Columns=1 })
    tab.Frame.Parent=panel; tab.Frame.Position=U2(10,42); tab.Frame.Size=UDim2.new(1,-20,1,-52); tab.Frame.Visible=true
    local function opts(id,title,extra)
        local result={ Id="__retrobox/"..id,Title=title,Internal=true,Persist=false }
        for k,v in pairs(extra or {}) do result[k]=v end
        return result
    end
    local look=tab:CreateSection(self:_text("appearance"))
    local controls={}
    controls.Theme=look:AddDropdown(opts("theme",self:_text("theme"),{
        Options=self:GetThemeNames(),Default=self.Theme,
        Callback=function(value) self:SetTheme(value) end,
    }))
    controls.Accent=look:AddColorPicker(opts("accent",self:_text("accent"),{
        Default=self.Palette.Accent,AllowRainbow=false,AllowOpacity=false,
        Callback=function(color) self:SetAccent(color) end,
    }))
    local access=tab:CreateSection(self:_text("accessibility"))
    controls.Scale=access:AddSlider(opts("scale",self:_text("scale"),{
        Min=.75,Max=1.5,Step=.05,Default=self.UserScale,Suffix="x",Callback=function(value) self:SetScale(value) end,
    }))
    controls.Motion=access:AddToggle(opts("motion",self:_text("motion"),{ Default=self.ReducedMotion,Callback=function(v) self:SetReducedMotion(v) end }))
    controls.Scanlines=access:AddToggle(opts("scanlines",self:_text("lines"),{ Default=self.Scanlines,Callback=function(v) self:SetScanlines(v) end }))
    controls.Notifications=access:AddToggle(opts("notices",self:_text("notices"),{ Default=self.NotificationsEnabled,Callback=function(v) self:SetNotifications(v) end }))
    controls.Launcher=access:AddToggle(opts("launcher",self:_text("launcher"),{ Default=self.LauncherEnabled,Callback=function(v) self:SetLauncher(v) end }))
    controls.Shortcut=access:AddKeybind(opts("shortcut",self:_text("shortcut"),{ Default=self.ToggleKey,CaptureOnly=true }))
    controls.Shortcut:OnChanged(function(value) self:SetToggleKey(value) end)
    local configs=tab:CreateSection(self:_text("configs"))
    local profile=configs:AddInput(opts("config-name",self:_text("profile"),{ Default="default",MaxLength=64 }))
    local json=configs:AddInput(opts("config-json","JSON",{ Default="",Multiline=true,MaxLength=self.MaxConfigBytes }))
    configs:AddButton(opts("config-save",self:_text("save"),{ Callback=function()
        local ok,result=self:SaveConfig(profile:GetValue())
        self:Notify({ Title=self:_text(ok and "saved" or "error"),Content=ok and profile:GetValue() or result,Kind=ok and "success" or "error" })
    end }))
    configs:AddButton(opts("config-load",self:_text("load"),{ Callback=function()
        local ok,result=self:LoadConfig(profile:GetValue())
        self:Notify({ Title=self:_text(ok and "loaded" or "error"),Content=ok and profile:GetValue() or result,Kind=ok and "success" or "error" })
    end }))
    configs:AddButton(opts("config-export",self:_text("export"),{ Callback=function() json:SetValue(self:ExportConfig(),true); json.Input:CaptureFocus() end }))
    configs:AddButton(opts("config-import",self:_text("import"),{ Callback=function()
        local ok,result=self:ImportConfig(json.Input.Text)
        self:Notify({ Title=self:_text(ok and "loaded" or "error"),Content=ok and self:_text("ready") or result,Kind=ok and "success" or "error" })
    end }))
    configs:AddButton(opts("config-reset",self:_text("reset"),{ Callback=function() self:Reset() end }))
    self._settingsOverlay=overlay; self._settingsPanel=panel; self._settingsTab=tab; self._settingsControls=controls
    connect(self,overlay.Activated,function(input)
        if input and inside(panel,point(input)) then return end
        self:ShowSettings(false)
    end)
    self:_syncSettings()
end
function Window:ShowSettings(value)
    if self.Destroyed or not self.SettingsEnabled then return self end
    self:_hideTooltip()
    if value==nil then value=not self._settingsOpen end
    if value then
        self:Show(); if self.Minimized then self:Minimize(false) end
        self:_createSettings()
    end
    self._settingsOpen=value == true
    if self._settingsOverlay then self._settingsOverlay.Visible=self._settingsOpen end
    if not self._settingsOpen and self._binding and self._binding._internal then
        local binding=self._binding; self._binding=nil; binding:_render()
    end
    if not self._settingsOpen and self._openDropdown and self._openDropdown._internal then self._openDropdown:SetOpen(false) end
    return self
end

function Window:Notify(options)
    if type(options)=="string" then options={ Content=options } end
    options=options or {}
    if self.Destroyed or not self.NotificationsEnabled then return nil end
    local duration=options.Duration or 4
    assert(finite(duration),"Notification Duration must be finite")
    duration=clamp(duration,.1,30)
    while #self._notifications>=4 do self._notifications[1]:Destroy() end
    self._noticeCount=self._noticeCount+1
    local width=math.min(340,math.max(220,self.Root.AbsoluteSize.X-32))
    local notification={ _window=self,_connections={},Destroyed=false }
    notification.Frame=frame(self,self.NotificationHost,{ LayoutOrder=-self._noticeCount,Size=U2(width,82),
        BorderSizePixel=1,ZIndex=80 },"Surface")
    self:_bind(notification.Frame,{ BackgroundColor3="Surface",BorderColor3="Border" }); bevel(self,notification.Frame,false)
    local role=options.Kind=="error" and "Danger" or options.Kind=="success" and "Success" or "Accent"
    frame(self,notification.Frame,{ Position=U2(0,0),Size=UDim2.new(0,4,1,0) },role)
    label(self,notification.Frame,options.Title or self:_text("about"),{
        Position=U2(12,8),Size=UDim2.new(1,-48,0,22),TextSize=13,TextTruncate=Enum.TextTruncate.AtEnd,
    })
    label(self,notification.Frame,options.Content or "",{
        Position=U2(12,32),Size=UDim2.new(1,-24,0,42),TextSize=12,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,
    },"Muted")
    function notification:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true
        cleanup(self); self.Frame:Destroy()
        local index=table.find(self._window._notifications,self)
        if index then table.remove(self._window._notifications,index) end
    end
    button(self,notification,notification.Frame,"X",{ Position=UDim2.new(1,-32,0,8),Size=U2(22,22),TextSize=12 },function() notification:Destroy() end)
    table.insert(self._notifications,notification)
    if not self.ReducedMotion then
        notification.Frame.BackgroundTransparency=.4
        local tween=TweenService:Create(notification.Frame,TweenInfo.new(.15),{ BackgroundTransparency=0 })
        tween:Play()
    end
    task.delay(duration,function() notification:Destroy() end)
    return notification
end

function Window:_profile(player)
    local fallback=label(self,self.Profile,"?",{ Position=U2(0,5),Size=U2(34,34),TextXAlignment=Enum.TextXAlignment.Center,TextSize=20 })
    local avatar=ui(self,"ImageLabel",{
        Parent=self.Profile,Position=U2(0,5),Size=U2(34,34),Image="",BackgroundTransparency=1,BorderSizePixel=1,
    },{ BorderColor3="Border" })
    local display=label(self,self.Profile,"Player",{
        Position=U2(44,4),Size=U2(134,20),TextSize=13,TextTruncate=Enum.TextTruncate.AtEnd,
    })
    local username=label(self,self.Profile,"@player",{
        Position=U2(44,24),Size=U2(134,18),TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd,
    },"Muted")
    self.Avatar=avatar; self.DisplayNameLabel=display; self.UsernameLabel=username
    if not player then return end
    local function update()
        display.Text=player.DisplayName; username.Text="@"..player.Name
        local name=player.DisplayName
        local nextCharacter=utf8.offset(name,2)
        fallback.Text=name:sub(1,(nextCharacter or #name+1)-1):upper()
    end
    update()
    connect(self,player:GetPropertyChangedSignal("DisplayName"),update)
    Library._thumbnails=Library._thumbnails or {}
    task.spawn(function()
        local cached=Library._thumbnails[player.UserId]
        if cached then if not self.Destroyed then avatar.Image=cached; fallback.Visible=false end; return end
        for attempt=1,3 do
            if self.Destroyed then return end
            local ok,content,ready=pcall(Players.GetUserThumbnailAsync,Players,player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)
            if self.Destroyed then return end
            if ok and ready and type(content)=="string" and #content>0 then
                Library._thumbnails[player.UserId]=content
                avatar.Image=content; fallback.Visible=false; return
            end
            if attempt<3 then task.wait(.3*attempt) end
        end
    end)
end

function Window:_inputBegan(input,processed)
    if self.Destroyed then return end
    if pointer(input) then
        if not self.TooltipFrame or not self.TooltipFrame.Visible or not inside(self.TooltipFrame,point(input)) then self:_hideTooltip() end
    elseif input.UserInputType==Enum.UserInputType.Keyboard then self:_hideTooltip() end
    if self._binding then
        if input.UserInputType~=Enum.UserInputType.Keyboard then return end
        local binding=self._binding; self._binding=nil
        if input.KeyCode~=Enum.KeyCode.Escape then
            binding:SetValue(input.KeyCode==Enum.KeyCode.Backspace and Enum.KeyCode.Unknown or input.KeyCode)
        end
        binding:_render(); return
    end
    if pointer(input) and self._openDropdown and not inside(self._openDropdown.Frame,point(input)) then self._openDropdown:SetOpen(false) end
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.UserInputType==Enum.UserInputType.Keyboard then
        if input.KeyCode==self.ToggleKey and self.ToggleKey~=Enum.KeyCode.Unknown then self:Toggle(); return end
        for binding in pairs(self._keybinds) do
            if not binding.CaptureOnly and binding.Value==input.KeyCode and binding.Value~=Enum.KeyCode.Unknown then binding:Trigger(true) end
        end
    end
end
function Window:_inputEnded(input)
    if self._drag and (input==self._drag.Input or input.UserInputType==Enum.UserInputType.MouseButton1 and self._drag.Input.UserInputType==Enum.UserInputType.MouseButton1) then self:_endDrag() end
    for binding in pairs(self._keybinds) do if binding.Mode=="Hold" and binding.Active and binding.Value==input.KeyCode then binding:Trigger(false) end end
end

local function mountGui(gui,explicitParent,player)
    local tried={}
    local function mount(parent,mode)
        if typeof(parent)~="Instance" or tried[parent] then return end
        tried[parent]=true
        local found,existing=pcall(function() return parent:FindFirstChild(gui.Name) end)
        if not found then return end
        if existing then assert(existing:GetAttribute("RetroBoxOwned")==true,"An unrelated instance already uses this window Id") end
        local ok=pcall(function() gui.Parent=parent end)
        if ok then
            if existing then
                local previous=sharedWindows[existing]
                if previous and type(previous.Destroy)=="function" then previous:Destroy() else existing:Destroy() end
            end
            return parent,mode
        end
    end
    if explicitParent~=nil then
        local parent,mode=mount(explicitParent,"custom")
        assert(parent,"Cannot attach ScreenGui to the supplied Parent")
        return parent,mode
    end
    if type(gethui)=="function" then
        local ok,container=pcall(gethui)
        if ok then local parent,mode=mount(container,"gethui"); if parent then return parent,mode end end
    end
    local ok,core=pcall(function() return game:GetService("CoreGui") end)
    if ok then local parent,mode=mount(core,"CoreGui"); if parent then return parent,mode end end
    if player then
        local parent,mode=mount(player:WaitForChild("PlayerGui",10),"PlayerGui")
        if parent then return parent,mode end
    end
    error("Executor could not attach the GUI via gethui, CoreGui or PlayerGui",2)
end
function Library:CreateWindow(options)
    options=options or {}
    assert(RunService:IsClient(),"CreateWindow must run on the Roblox client")
    local player=Players.LocalPlayer
    if options.Parent~=nil then assert(typeof(options.Parent)=="Instance","Parent must be a Roblox Instance") end
    local theme=options.Theme or "Retro98"
    assert(self.Themes[theme],"Unknown theme: "..tostring(theme))
    local size=options.Size or Vector2.new(790,570)
    assert(typeof(size)=="Vector2" and finite(size.X) and finite(size.Y) and size.X>=300 and size.Y>=300,"Size must be a Vector2 of at least 300x300")
    local userScale=options.Scale or 1
    assert(finite(userScale) and userScale>=.75 and userScale<=1.5,"Scale must be 0.75–1.5")
    local toggle=keycode(options.ToggleKey or Enum.KeyCode.RightShift)
    local font=options.Font or Enum.Font.Code
    assert(typeof(font)=="EnumItem" and font.EnumType==Enum.Font,"Font must be an Enum.Font")
    local maxBytes=options.MaxConfigBytes or 262144
    assert(finite(maxBytes) and maxBytes>=1024 and maxBytes<=1048576,"MaxConfigBytes must be 1024–1048576")
    local tooltipDelay=options.TooltipDelay
    if tooltipDelay==nil then tooltipDelay=.4 end
    local tooltipWidth=options.TooltipMaxWidth
    if tooltipWidth==nil then tooltipWidth=320 end
    assert(finite(tooltipDelay) and tooltipDelay>=0 and tooltipDelay<=3,"TooltipDelay must be 0–3 seconds")
    assert(finite(tooltipWidth) and tooltipWidth>=160 and tooltipWidth<=640,"TooltipMaxWidth must be 160–640")
    local id=options.Id or HttpService:GenerateGUID(false)
    assert(type(id)=="string" and #id>0,"Window Id must be a nonempty string")
    local guiName="RetroBox_"..id
    local window=setmetatable({
        Id=id,Title=tostring(options.Title or "RetroBox UI"),Subtitle=tostring(options.Subtitle or "A little old-school. A lot configurable."),
        Theme=theme,Accent=options.Accent and parseColor(options.Accent) or nil,Palette=copy(self.Themes[theme]),
        Font=font,UserScale=userScale,ToggleKey=toggle,MaxConfigBytes=maxBytes,TooltipDelay=tooltipDelay,TooltipMaxWidth=tooltipWidth,
        ReducedMotion=options.ReducedMotion == true,Scanlines=options.Scanlines == true,
        NotificationsEnabled=options.Notifications~=false,LauncherEnabled=options.Launcher~=false,
        SettingsEnabled=options.Settings~=false,AutoSave=options.AutoSave,StorageMode="memory",
        _locale=translations[options.Locale or "pt-BR"] or translations["pt-BR"],
        _connections={},_skin=setmetatable({},{ __mode="k" }),_themeOverrides={},_rainbows={},_keybinds={},_destroyListeners={},
        _profiles={},_notifications={},_noticeCount=0,_nextId=0,_saveToken=0,_query="",
        _requestedSize=size,Controls={},Flags={},Tabs={},Destroyed=false,
    },Window)
    if window.AutoSave~=nil then profileName(window.AutoSave) end
    assert(options.FileStorage==nil or type(options.FileStorage)=="boolean","FileStorage must be a boolean")
    if options.Storage then window:SetStorage(options.Storage)
    elseif options.FileStorage~=false then
        window.ConfigFolder=folderName(options.ConfigFolder or "RetroBox/script-"..filePart(id))
        local adapter=self:CreateFileStorage(window.ConfigFolder)
        if adapter then window:SetStorage(adapter) end
    end
    window._initial={ Theme=theme,ThemeColors=copy(self.Themes[theme]),Accent=window.Accent,Scale=userScale,ReducedMotion=window.ReducedMotion,
        Scanlines=window.Scanlines,Notifications=window.NotificationsEnabled,Launcher=window.LauncherEnabled,ToggleKey=toggle }
    window.Gui=ui(window,"ScreenGui",{
        Name=guiName,ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=options.DisplayOrder or 50,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    })
    window.Gui:SetAttribute("RetroBoxOwned",true)
    local mounted,parent,mode=pcall(mountGui,window.Gui,options.Parent,player)
    if not mounted then window.Gui:Destroy(); error(parent,2) end
    window.Parent=parent; window.ParentMode=mode
    self.Windows[window]=true
    window.Root=frame(window,window.Gui,{ Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Name="Root" })
    window.Main=frame(window,window.Root,{
        Name="Window",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=U2(size.X,size.Y),
        BorderSizePixel=1,Active=true,
    },"Background")
    window:_bind(window.Main,{ BackgroundColor3="Background",BorderColor3="Border" }); bevel(window,window.Main,false)
    window.ScaleObject=ui(window,"UIScale",{ Parent=window.Main,Scale=userScale })
    local header=frame(window,window.Main,{ Position=U2(4,4),Size=UDim2.new(1,-8,0,34),Active=true },"Accent")
    window.TitleLabel=label(window,header,window.Title,{
        Position=U2(10,0),Size=UDim2.new(1,-120,1,0),TextSize=15,TextTruncate=Enum.TextTruncate.AtEnd,
    },"AccentText")
    window.Icon=ui(window,"ImageLabel",{ Parent=header,Position=U2(6,5),Size=U2(24,24),BackgroundTransparency=1,Image="",Visible=false })
    window:SetIcon(options.Icon)
    button(window,window,header,"_",{ Position=UDim2.new(1,-98,0,4),Size=U2(27,26) },function() window:Minimize() end)
    button(window,window,header,"[]",{ Position=UDim2.new(1,-66,0,4),Size=U2(27,26),TextSize=11 },function()
        window._maximized=not window._maximized; window:Minimize(false); window:_layout()
    end)
    button(window,window,header,"X",{ Position=UDim2.new(1,-34,0,4),Size=U2(27,26) },function()
        if options.DestroyOnClose==false then window:Hide() else window:Destroy() end
    end)
    window.SubtitleLabel=label(window,window.Main,window.Subtitle,{
        Position=U2(14,44),Size=UDim2.new(1,-28,0,22),TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd,
    },"Muted")
    window.Nav=ui(window,"ScrollingFrame",{
        Parent=window.Main,BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,
        CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,
    },{ ScrollBarImageColor3="Border" })
    window.NavLayout=list(window,window.Nav,8,false)
    window.Search=textbox(window,window.Main,"",{ PlaceholderText=window:_text("search"),TextSize=12 })
    window.PageHost=frame(window,window.Main,{ BackgroundTransparency=1 })
    window.Footer=frame(window,window.Main,{ Position=UDim2.new(0,10,1,-56),Size=UDim2.new(1,-20,0,48),BackgroundTransparency=1 })
    frame(window,window.Footer,{ Size=UDim2.new(1,0,0,1) },"Border")
    window.Profile=frame(window,window.Footer,{ Position=U2(2,1),Size=U2(182,46),BackgroundTransparency=1,Visible=options.ShowProfile~=false })
    window:_profile(player)
    window.SettingsButton=button(window,window,window.Footer,"⚙",{
        Position=U2(190,10),Size=U2(32,32),Font=Enum.Font.SourceSans,TextSize=24,Visible=window.SettingsEnabled,
    },function() window:ShowSettings() end)
    window.Status=label(window,window.Footer,window:_text("ready").."  |  v"..self.Version,{
        Position=UDim2.new(1,-244,0,10),Size=U2(214,30),TextXAlignment=Enum.TextXAlignment.Right,TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd,
    },"Muted")
    window.ResizeGrip=label(window,window.Footer,"//",{
        Position=UDim2.new(1,-24,1,-24),Size=U2(24,24),TextXAlignment=Enum.TextXAlignment.Right,Active=true,
    },"Muted")
    window.Launcher=button(window,window,window.Root,"UI",{ Position=U2(16,60),Size=U2(44,38),Visible=false,ZIndex=30 },function() window:Show() end)
    window.NotificationHost=frame(window,window.Root,{
        AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-16),Size=UDim2.new(0,math.min(340,math.max(220,window.Root.AbsoluteSize.X-32)),0,0),
        AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,ZIndex=80,
    })
    local noticeLayout=list(window,window.NotificationHost,8,false)
    noticeLayout.HorizontalAlignment=Enum.HorizontalAlignment.Right
    window._scanlineLayer=frame(window,window.Main,{ Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=20,Visible=window.Scanlines })
    for index=1,96 do
        frame(window,window._scanlineLayer,{ Position=UDim2.fromScale(0,index/96),Size=UDim2.new(1,0,0,1),BackgroundTransparency=.95,ZIndex=20 },"Text")
    end
    connect(window,header.InputBegan,function(input)
        if window._maximized then return end
        local p=point(input)
        if p.X>=header.AbsolutePosition.X+header.AbsoluteSize.X-104 then return end
        local start,center=p,Vector2.new(window.Main.AbsolutePosition.X+window.Main.AbsoluteSize.X/2,window.Main.AbsolutePosition.Y+window.Main.AbsoluteSize.Y/2)
        window:_beginDrag(window,input,function(current)
            window._position=center+(current-start); window:_layout()
        end)
    end)
    connect(window,window.ResizeGrip.InputBegan,function(input)
        local start=point(input); local size=window._logicalSize
        window:_beginDrag(window,input,function(current)
            local delta=(current-start)/window._actualScale
            window._requestedSize=Vector2.new(clamp(size.X+delta.X,520,1400),clamp(size.Y+delta.Y,360,1000)); window:_layout()
        end)
    end)
    connect(window,window.Search:GetPropertyChangedSignal("Text"),function() window:SetSearch(window.Search.Text) end)
    connect(window,window.Root:GetPropertyChangedSignal("AbsoluteSize"),function() window:_layout() end)
    connect(window,UserInputService.InputBegan,function(input,processed) window:_inputBegan(input,processed) end)
    connect(window,UserInputService.InputChanged,function(input)
        window:_updateTooltip(input)
        local drag=window._drag; if not drag then return end
        if drag.Input.UserInputType==Enum.UserInputType.Touch and input~=drag.Input then return end
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then drag.Update(point(input)) end
    end)
    connect(window,UserInputService.InputEnded,function(input) window:_inputEnded(input) end)
    connect(window,UserInputService.WindowFocusReleased,function()
        window:_hideTooltip()
        window:_endDrag()
        for binding in pairs(window._keybinds) do if binding.Mode=="Hold" and binding.Active then binding:Trigger(false) end end
    end)
    connect(window,window.Gui.Destroying,function() if not window.Destroyed then window:Destroy() end end)
    window:_layout(); window:_applyTheme()
    sharedWindows[window.Gui]=window
    return window
end
function Window:Destroy()
    if self.Destroyed then return end
    self.Destroyed=true; self._saveToken=self._saveToken+1
    self:_hideTooltip()
    sharedWindows[self.Gui]=nil
    self:_endDrag()
    if self._rgbConnection then self._rgbConnection:Disconnect(); self._rgbConnection=nil end
    cleanup(self)
    local tabs={}
    for _,tab in ipairs(self.Tabs) do table.insert(tabs,tab) end
    for _,tab in ipairs(tabs) do tab:Destroy() end
    while #self._notifications>0 do self._notifications[1]:Destroy() end
    self.Controls={}; self.Flags={}; self._keybinds={}; self._rainbows={}; self._skin={}
    self.Gui:Destroy()
    Library.Windows[self]=nil
    for listener in pairs(self._destroyListeners) do
        if listener.Connected then
            listener.Connected=false
            local ok,err=pcall(listener.Callback)
            if not ok then warn("[RetroBox] OnDestroy: "..tostring(err)) end
        end
    end
    self._destroyListeners={}
end
function Library:DestroyAll()
    local windows={}
    for window in pairs(self.Windows) do table.insert(windows,window) end
    for _,window in ipairs(windows) do window:Destroy() end
end

return Library
