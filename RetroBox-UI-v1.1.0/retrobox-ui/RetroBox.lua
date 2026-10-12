-- RetroBox UI 1.5.0 | Mano Gustavo | MIT License
-- Standalone GUI library for Roblox client executors.
-- Load the raw GitHub source with loadstring(game:HttpGet(URL))().

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local Library = { Version = "1.5.0", Themes = {}, Windows = {} }
local Window = {}; Window.__index = Window
local Tab = {}; Tab.__index = Tab
local Section = {}; Section.__index = Section
local Row = {}; Row.__index = Row; setmetatable(Row,{__index=Section})
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
    if window._dispatch then return window:_dispatch(callback,{Phase="Callback"},...) end
    if type(callback) ~= "function" or window.Destroyed or window._suppressCallbacks then return end
    local args = table.pack(...)
    if window._closing or window._syncCallbacks then
        local ok,err=pcall(callback,table.unpack(args,1,args.n))
        if not ok then warn("[RetroBox] Cleanup callback: "..tostring(err)) end
        return
    end
    task.spawn(function()
        if window.Destroyed then return end
        local ok, err = pcall(callback, table.unpack(args, 1, args.n))
        if not ok then
            warn("[RetroBox] Callback: " .. tostring(err))
            if window.ErrorNotifications then window:Notify({Title=window:_text("error"),Content=tostring(err),Kind="error"}) end
        end
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
local mouseButtons={MouseButton1=true,MouseButton2=true,MouseButton3=true}
local function bindingValue(value,allowMouse)
    if typeof(value)=="EnumItem" and value.EnumType==Enum.UserInputType then
        assert(allowMouse~=false and mouseButtons[value.Name],"Only mouse buttons 1–3 can be bound")
        return value
    end
    if type(value)=="string" and mouseButtons[value] then
        assert(allowMouse~=false,"Mouse buttons are disabled for this binding")
        return Enum.UserInputType[value]
    end
    return keycode(value)
end
local function inputBinding(input)
    if input.UserInputType==Enum.UserInputType.Keyboard then return input.KeyCode end
    if mouseButtons[input.UserInputType.Name] then return input.UserInputType end
end
local function bindingLabel(value)
    if value.Name=="Unknown" then return "---" end
    if mouseButtons[value.Name] then return "Mouse "..value.Name:sub(-1) end
    return value.Name
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

-- BEGIN PIXEL ICONS
local iconPatterns = {
    ["retrobox"] = "............/.....#....../...#####..../.hh##a###hh./.#ahhaahha#./.#ahhhhaaa#./.#ahhahaaa#./.#aahahaaa#./.##aaahaaa#./...##aha###./....##h##.../......#.....",
    ["home"] = "............/.....#....../....###...../...#####..../..########../.##########./..#h######../..#h#..###../..###..###../..###..###../..###..###../............",
    ["folder"] = "............/............/.#####....../.##########./.#hhhhhhhh#./.#aaaaaaaa#./.#aaaaaaaa#./.#aaaaaaaa#./.#aaaaaaaa#./.##########./............/............",
    ["grid"] = "............/.###.###.###/.###.###.###/.###.###.###/............/.###.###.###/.###.###.###/.###.###.###/............/.###.###.###/.###.###.###/.###.###.###",
    ["code"] = "............/............/......a...../...#..a.#.../..#..a...#../.#...a....#./..#..a...#../...#.a..#.../....a......./....a......./............/............",
    ["terminal"] = "............/............/.##########./.#........#./.#.a......#./.#..a.....#./.#.a......#./.#....###.#./.#........#./.##########./............/............",
    ["eye"] = "............/............/...######.../..##....##../.##..aa..##./##...aa...##/.##..aa..##./..##....##../...######.../............/............/............",
    ["target"] = ".....##...../.....##...../....####..../...#.##.#.../..#......#../####.aa.####/####.aa.####/..#......#../...#.##.#.../....####..../.....##...../.....##.....",
    ["mouse"] = "............/...######.../...#.#aa#.../...#.#aa#.../...#.#aa#.../...######.../...#....#.../...#....#.../...#....#.../...#....#.../...######.../............",
    ["keyboard"] = "............/............/............/############/#.#.#.#.#..#/#..........#/#.#.#.#.#..#/#..........#/#..aaaaaa..#/############/............/............",
    ["palette"] = "............/...######.../..########../..#aa##hh##./.##aa##hh##./.##########./..#gg######./..#gg###..../..###r##..../....####..../.....#....../............",
    ["save"] = "............/.##hhhah##../.##hhhah###./.##hhhah###./.##hhhhh###./.##########./.##......##./.##.aaaa.##./.##......##./.##......##./.##########./............",
    ["load"] = "......#...../......#...../......#...../.########.../.##########./.#aaaa#aaa#./.#aaaaaaaa#./.#aaaaaaaa#./.#aaaaaaaa#./.#aaaaaaaa#./.##########./............",
    ["user"] = "............/....####..../...######.../...######.../....####..../............/...######.../..#aaaaaa#../..########../.##########./.##########./............",
    ["search"] = "............/...###....../..#...#...../.#.hh..#..../.#.hh..#..../.#.....#..../..#...#...../...###..#.../.......###../........###./.........###/..........#.",
    ["settings"] = "....####..../....####..../..########../..########../####....####/####.aa.####/####.aa.####/####....####/..########../..########../....####..../....####....",
    ["info"] = "....####..../..##....##../.#...aa...#./.#...aa...#./#..........#/#....##....#/#....##....#/#....##....#/.#..####..#./.#........#./..##....##../....####....",
    ["success"] = "....####..../..##....##../.#........#./.#.....g..#./#.....ggg..#/#...g.gg...#/#..gggg....#/#...ggg....#/.#...g....#./.#........#./..##....##../....####....",
    ["warning"] = ".....#....../.....##...../....###...../....#.##..../...##r.#..../...#.r.##.../..##.r..##../..#......#../.##..r...##./.#........#./############/............",
    ["error"] = "....####..../..##....##../.#........#./.#.r....r.#./#...r..r...#/#....rr....#/#....rr....#/#...r..r...#/.#.r....r.#./.#........#./..##....##../....####....",
    ["close"] = "............/.........#../...#....###./..###..###../...######.../....####..../....####..../...######.../..###..###../...#....###./.........#../............",
    ["minimize"] = "............/............/............/............/............/............/............/............/..########../..########../............/............",
    ["maximize"] = "............/.##########./.##########./.##########./.#........#./.#........#./.#........#./.#........#./.#........#./.#........#./.##########./............",
    ["restore"] = "............/....#######./....#.....#./....#.....#./.#######..#./.#######..#./.#.....#..#./.#.....####./.#.....#..../.#.....#..../.#######..../............",
    ["chevron-down"] = "............/............/............/............/...#...#..../..###.###.../...#####..../....###...../.....#....../............/............/............",
    ["chevron-right"] = "............/............/.....#....../....###...../.....###..../......###.../.....###..../....###...../.....#....../............/............/............",
    ["check"] = "............/............/.........#../........###./.......###../..#...###.../.###.###..../..#####...../...###....../....#......./............/............",
    ["reset"] = ".#........../.###......../.########.../.####....#../.##.......#./.#........#./..........#./..........#./.#........#./..#......#../...######.../............",
    ["refresh"] = ".......#..../.......##.../..#########./..#....#####/..#....###../.......#..../....#......./..###....#../#####....#../.#########../...##......./....#.......",
    ["copy"] = "............/.#######..../.#.....#..../.#.....#..../.#..#######./.#..#.....#./.#..#.....#./.#..#.....#./.####.....#./....#.....#./....#######./............",
    ["download"] = ".....##...../.....##...../.....##...../.....##...../..########../...######.../....####..../....###...../.#...#....#./.#........#./.##########./............",
    ["upload"] = ".....#....../....###...../....####..../...######.../..########../.....##...../.....##...../.....##...../.#...##...#./.#........#./.##########./............",
    ["link"] = "....###...../...#...#..../..#.....#.../.#.....a..../.#....aaa.../.#...aaa..../....aaa...#./...aaa....#./..aaa.....#./...a.....#../....#...#.../.....###....",
    ["star"] = ".....#....../.....#....../.....##...../....###...../#####aa#####/.####aa####./.####aa###../..#######.../..#######.../..###.###.../.##.....##../.#.......#..",
    ["heart"] = "............/.####..####./.#hh#.#####./############/############/############/.##########./..########../...######.../...#####..../....###...../.....#......",
    ["bolt"] = "......###.../.....####.../.....###..../....####..../...########./...#######../..#######.../.....###..../.....###..../....###...../....##....../....#.......",
    ["shield"] = ".....#....../...#####..../#####.#####./##.......##./##.....a.##./##.a..a..##./##..a.a..##./##...a...##./.###...###../.####.####../..#######.../.....#......",
    ["gamepad"] = "............/............/............/..########../.##h#######./##hhh###a###/###h#####a##/###h########/############/####....####/..#......#../............",
    ["mobile"] = "...######.../...######.../...#....#.../...#....#.../...#....#.../...#....#.../...#....#.../...#....#.../...#....#.../...######.../...##hh##.../...######...",
    ["volume"] = "............/......#...../.....##...../....###.#.../.######..#../.######..#../.######..#../.######..#../....###.#.../.....##...../......#...../............",
    ["notification"] = ".....##...../.....##...../...######.../...######.../..########../..########../..########../..########../.##########./............/.....aa...../............",
    ["lock"] = "...######.../...#....#.../...#....#.../...#....#.../...#....#.../.##########./.##########./.####hh####./.####hh####./.##########./.##########./............",
    ["unlock"] = "...######.../...#....#.../...#....#.../...#......../...#......../.##########./.##########./.####hh####./.####hh####./.##########./.##########./............",
    ["globe"] = "....####..../..###..###../.##########./.#.#....#.#./#..#....#..#/############/#..#....#..#/#..#....#..#/.#.#....#.#./.##########./..###..###../....####....",
    ["sliders"] = "..#...#...#./..#...#...#./..#...#..aaa/.aaa..#..aaa/.aaa..#..aaa/.aaa..#...#./..#...#...#./..#..aaa..#./..#..aaa..#./..#..aaa..#./..#...#...#./..#...#...#.",
    ["spark"] = ".....#....../.....#....../.....#....../....###...../....###...../############/....###...../....###...../....###...../.....#....../.....#....../.....#......",
}
-- END PIXEL ICONS

local iconRoles = { ["#"]="Text", a="Accent", h="Highlight", s="Shadow", m="Muted", g="Success", r="Danger" }
local function iconRows(pattern)
    local rows={}; for row in pattern:gmatch("[^/]+") do rows[#rows+1]=row end
    return rows
end
function Library:GetIconNames()
    local result={}; for name in pairs(iconPatterns) do result[#result+1]=name end
    table.sort(result); return result
end
function Library:GetIcon(name)
    local pattern=iconPatterns[name]
    return pattern and iconRows(pattern) or nil
end
function Library:RegisterIcon(name,rows)
    assert(type(name)=="string" and #name>=1 and #name<=48 and name:match("^[a-z][a-z0-9_-]*$"),"Icon name must be 1–48 lowercase letters, digits, underscores or hyphens")
    assert(type(rows)=="table" and #rows>=4 and #rows<=16,"Icon must have 4–16 rows")
    local width=type(rows[1])=="string" and #rows[1] or 0
    assert(width>=4 and width<=16,"Icon rows must have 4–16 columns")
    local visible=false
    for _,row in ipairs(rows) do
        assert(type(row)=="string" and #row==width and not row:find("[^%.#ahsmgr]"),"Icon rows must be equal width and use . # a h s m g r")
        if row:find("[^%.]") then visible=true end
    end
    assert(visible,"Icon needs at least one visible pixel")
    iconPatterns[name]=table.concat(rows,"/")
    for window in pairs(self.Windows) do
        for handle in pairs(window._icons or {}) do if handle.Name==name then handle:Set(handle.Spec) end end
    end
    return self
end
local function resolveIcon(value)
    if value==nil or value==false or value=="" then return "none" end
    if type(value)=="number" then
        assert(finite(value) and value>0 and value%1==0,"Icon asset ID must be a positive integer")
        return "asset","rbxassetid://"..string.format("%.0f",value)
    end
    assert(type(value)=="string" and #value<=1024,"Icon must be a name, asset ID, short text or false")
    if value:sub(1,6)=="pixel:" then
        local name=value:sub(7); assert(iconPatterns[name],"Unknown pixel icon: "..name)
        return "pixel",name
    end
    if iconPatterns[value] then return "pixel",value end
    if value:match("^rbxassetid://%d+$") or value:match("^https?://") or value:match("^rbxasset://") then return "asset",value end
    assert(#value<=64,"Legacy icon text must contain at most 64 bytes")
    return "text",value
end

local translations = {
    ["pt-BR"] = {
        search="Pesquisar funções...", settings="Configurações", theme="Tema", accent="Cor de destaque",
        scale="Escala da interface", motion="Reduzir animações", lines="Linhas CRT", launcher="Botão de reabrir",
        notices="Notificações", appearance="Aparência", accessibility="Interface e acessibilidade",
        pixelIcons="Ícones padrão em pixel art",pixelDecorations="Detalhes em pixel art",
        loading="Carregando...",unavailable="Indisponível",noData="Sem dados",
        animations="Animações",animationSpeed="Velocidade das animações",animationIntensity="Intensidade",smoothDragging="Arrasto suave",
        intensitySubtle="Discreta",intensityNormal="Normal",intensityOff="Desativada",
        shortcut="Atalho da janela", configs="Configurações", profile="Nome da configuração", save="Salvar",
        load="Carregar", export="Exportar JSON", import="Importar JSON", reset="Restaurar padrões",
        ready="Pronto", fixed="Cor fixa", rainbow="RGB animado", cycle="s/ciclo", opacity="Opacidade",
        choose="Selecionar...", empty="Sem resultados", capture="Pressione uma tecla ou um botão do mouse...", saved="Configuração salva",
        loaded="Configuração carregada", error="Não foi possível", close="Fechar", about="RetroBox UI",
        profiles="Saves disponíveis", refresh="Atualizar lista", overwrite="Sobrescrever save?", confirm="Confirmar", cancel="Cancelar",
        running="Executando...",queued="Na fila...",cancelling="Cancelando...", success="Concluído", quickActions="Atalhos flutuantes", floatSize="Tamanho dos atalhos", floatOpacity="Opacidade dos atalhos",
        launcherText="Texto do botão de reabrir", memoryProfiles="Saves disponíveis enquanto esta janela estiver aberta.", fileProfiles="Saves gravados podem ser carregados em outra execução.",
    },
    ["en-US"] = {
        search="Search features...", settings="Settings", theme="Theme", accent="Accent color",
        scale="Interface scale", motion="Reduce animations", lines="CRT scanlines", launcher="Reopen button",
        notices="Notifications", appearance="Appearance", accessibility="Interface and accessibility",
        pixelIcons="Default pixel art icons",pixelDecorations="Pixel art details",
        loading="Loading...",unavailable="Unavailable",noData="No data",
        animations="Animations",animationSpeed="Animation speed",animationIntensity="Intensity",smoothDragging="Smooth dragging",
        intensitySubtle="Subtle",intensityNormal="Normal",intensityOff="Off",
        shortcut="Window shortcut", configs="Configurations", profile="Configuration name", save="Save",
        load="Load", export="Export JSON", import="Import JSON", reset="Restore defaults",
        ready="Ready", fixed="Fixed color", rainbow="Animated RGB", cycle="s/cycle", opacity="Opacity",
        choose="Select...", empty="No results", capture="Press a key or mouse button...", saved="Configuration saved",
        loaded="Configuration loaded", error="Could not complete", close="Close", about="RetroBox UI",
        profiles="Available saves", refresh="Refresh list", overwrite="Overwrite save?", confirm="Confirm", cancel="Cancel",
        running="Running...",queued="Queued...",cancelling="Cancelling...", success="Completed", quickActions="Floating shortcuts", floatSize="Shortcut size", floatOpacity="Shortcut opacity",
        launcherText="Reopen button text", memoryProfiles="Saves available while this window remains open.", fileProfiles="Saved profiles can be loaded in another execution.",
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
    if window._animate then
        local function tone(role)
            if window.Destroyed or owner.Destroyed or owner.Disabled then return end
            if owner.Sections and window.ActiveTab==owner then role="Accent" end
            window:_animate(object,{BackgroundColor3=window.Palette[role]},.08,"button",owner)
        end
        connect(owner,object.MouseEnter,function() tone("Highlight") end)
        connect(owner,object.MouseLeave,function() tone("Surface") end)
        connect(owner,object.InputBegan,function(input) if pointer(input) then tone("Inset") end end)
        connect(owner,object.InputEnded,function(input) if pointer(input) then tone("Surface") end end)
    end
    if pressed then
        connect(owner, object.Activated, function(...)
            local blocked=false; local ancestor=object.Parent
            while ancestor do if ancestor==window.Main and window._shown==false then blocked=true; break end; ancestor=ancestor.Parent end
            local section=owner._section and (owner._section._parentSection or owner._section)
            if section and (section._collapsed or not section._visible) then blocked=true end
            if window._dialog and owner~=window._dialog then blocked=true end
            if not window.Destroyed and not owner.Destroyed and not owner.Disabled and not blocked then pressed(...) end
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
    ui(window, "UIPadding", { Name="TextPadding",Parent=object, PaddingLeft=UDim.new(0,8), PaddingRight=UDim.new(0,8) })
    return object
end
local function list(window, parent, gap, horizontal)
    return ui(window, "UIListLayout", { Parent=parent, Padding=UDim.new(0,gap or 8),
        FillDirection=horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
        SortOrder=Enum.SortOrder.LayoutOrder })
end

-- BEGIN MANAGED RUNTIME: resources, diagnostics and one lazy frame scheduler.
do
    local Scope={}; Scope.__index=Scope
    local cancelSignal={}; Library._cancelSignal=cancelSignal
    local function dispose(scope,record)
        if not record or record.Cleaned then return end
        record.Cleaned=true
        local ok,err=pcall(function()
            if type(record.Method)=="function" then record.Method(record.Resource)
            elseif record.Method then record.Resource[record.Method](record.Resource)
            else record.Resource() end
        end)
        if not ok then
            if scope._window then scope._window:_diagnose({Phase="Cleanup",Operation="Resource"},err)
            else warn("[RetroBox] Resource cleanup: "..tostring(err)) end
        end
    end
    function Scope:Add(resource,method,key)
        assert(resource~=nil,"Resource cannot be nil")
        if method==nil and type(resource)~="function" then
            if typeof(resource)=="Instance" then method="Destroy"
            else
                for _,candidate in ipairs({"Destroy","Disconnect","Cancel","Stop"}) do
                    local ok,value=pcall(function() return resource[candidate] end)
                    if ok and type(value)=="function" then method=candidate; break end
                end
            end
        end
        assert(type(resource)=="function" or type(method)=="function" or type(method)=="string","Resource needs a cleanup function or Destroy/Disconnect/Cancel/Stop method")
        if type(method)=="string" then assert(type(resource[method])=="function","Unknown resource cleanup method") end
        local record={Resource=resource,Method=method,Key=key}
        if self.Destroyed or self._cleaning then dispose(self,record); return resource end
        if getmetatable(resource)==Scope and resource._parent==self then
            self:Remove(resource._parentKey or resource,true); resource._parentKey=key or resource
            key=resource._parentKey; record.Key=key
        end
        if key~=nil and self._keys[key] then self:Remove(key) end
        self._next=self._next+1; record.Order=self._next
        self._records[record]=true; if key~=nil then self._keys[key]=record end
        return resource
    end
    function Scope:Remove(key,keep)
        local record=self._keys[key]
        if not record then return nil end
        self._keys[key]=nil; self._records[record]=nil
        if not keep then dispose(self,record) end
        return record.Resource
    end
    function Scope:Clean()
        if self._cleaning then return self end
        self._cleaning=true
        local records={}; for record in pairs(self._records) do records[#records+1]=record end
        table.sort(records,function(a,b) return a.Order>b.Order end)
        self._records={}; self._keys={}
        for _,record in ipairs(records) do dispose(self,record) end
        self._cleaning=false; return self
    end
    function Scope:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true; self:Clean()
        if self._parent then self._parent:Remove(self._parentKey or self,true); self._parent=nil end
    end
    function Scope:Child(options)
        options=options or {}; assert(type(options)=="table","Scope options must be a table")
        local policy={}
        for _,name in ipairs({"CancelOnHide","CancelOnDisable","CancelOnFalse"}) do
            assert(options[name]==nil or type(options[name])=="boolean","Scope policy must be a boolean: "..name)
            policy[name]=options[name]
        end
        local child=setmetatable({_window=self._window,_owner=self._owner,_parent=self,Options=policy,_records={},_keys={},_next=0},Scope)
        self:Add(child,"Destroy",child); return child
    end
    function Scope:GetCount() local n=0; for _ in pairs(self._records) do n=n+1 end; return n end
    function Library:CreateScope()
        return setmetatable({_records={},_keys={},_next=0,Options={}},Scope)
    end
    function Window:CreateScope(options)
        assert(not self.Destroyed,"Window has been destroyed")
        return self._resources:Child(options)
    end
    function Window:Manage(resource,method,key) return self._resources:Add(resource,method,key) end
    function Control:CreateScope(options)
        assert(not self.Destroyed,"Control has been destroyed")
        return self._resources:Child(options)
    end
    function Control:Manage(resource,method,key) return self._resources:Add(resource,method,key) end
    function Window:_cleanPolicy(policy,owner)
        local function visit(scope)
            local children={}; for record in pairs(scope._records) do
                if getmetatable(record.Resource)==Scope then children[#children+1]=record.Resource end
            end
            for _,child in ipairs(children) do
                if child.Options[policy] and (not owner or child._owner==owner) then child:Clean() else visit(child) end
            end
        end
        visit(self._resources)
    end
    function Window:SetDebug(enabled)
        assert(type(enabled)=="boolean","Debug must be a boolean"); self.Debug=enabled; return self
    end
    function Window:SetCallbackExecutor(executor)
        assert(executor==nil or type(executor)=="function","CallbackExecutor must be a function or nil")
        self.CallbackExecutor=executor; return self
    end
    function Window:GetDiagnostics() return copy(self._diagnostics) end
    function Window:OnError(callback)
        assert(type(callback)=="function","OnError expects a function")
        local listener={Connected=true,Callback=callback}; self._errorListeners[listener]=true
        local owner=self
        function listener:Disconnect() self.Connected=false; owner._errorListeners[self]=nil end
        self._resources:Add(listener,"Disconnect"); return listener
    end
    function Window:_diagnose(context,message,traceback)
        if message==cancelSignal then return end
        context=context or {}
        local record={Time=os.clock(),ControlId=context.ControlId,Operation=context.Operation,Phase=context.Phase or "Callback",
            Message=tostring(message):sub(1,2048),Traceback=self.Debug and traceback and tostring(traceback):sub(1,8192) or nil}
        if self.Debug and context.State~=nil then record.State=copy(context.State) end
        if self.Debug and not record.State then
            local control=context.ControlId and self.Controls[context.ControlId]
            local action=context.Operation and self._actions[context.Operation]
            local job=context.Operation and self.Tasks[context.Operation]
            if control then record.State={Value=control:GetValue(),Disabled=control.Disabled,Busy=control._busy==true}
            elseif action then record.State={Status=action._status.Status,Progress=action._status.Progress}
            elseif job then record.State={Running=job.Requested,Iteration=job.Iterations} end
        end
        self._diagnostics[#self._diagnostics+1]=record
        while #self._diagnostics>64 do table.remove(self._diagnostics,1) end
        local key=record.Phase..":"..tostring(record.ControlId or record.Operation or ""):sub(1,128)
        self._warningTimes=self._warningTimes or {}
        local last=self._warningTimes[key]; local report=not last or record.Time-last>=2
        if report then
            local count=0; for _ in pairs(self._warningTimes) do count=count+1 end
            if count>=64 then self._warningTimes={} end
            self._warningTimes[key]=record.Time
            warn("[RetroBox] "..record.Phase.." "..(record.ControlId or record.Operation or "")..": "..record.Message)
        end
        if not self._reportingError then
            self._reportingError=true
            for listener in pairs(self._errorListeners) do if listener.Connected then pcall(listener.Callback,copy(record)) end end
            self._reportingError=false
            if report and self.ErrorNotifications and not self.Destroyed and not self._closing and self.NotificationHost then
                self:Notify({Title=self:_text("error"),Content=record.Message,Kind="error"})
            end
        end
    end
    function Window:_protected(callback,context,...)
        if type(callback)~="function" then return true end
        local args=table.pack(...); local trace
        local result=table.pack(xpcall(function()
            if self.CallbackExecutor then return self.CallbackExecutor(callback,args,copy(context or {})) end
            return callback(table.unpack(args,1,args.n))
        end,function(err)
            if err~=cancelSignal and self.Debug and debug and debug.traceback then trace=debug.traceback(tostring(err),2) end
            return err
        end))
        if not result[1] and result[2]~=cancelSignal then self:_diagnose(context,result[2],trace) end
        return table.unpack(result,1,result.n)
    end
    function Window:_dispatch(callback,context,...)
        if type(callback)~="function" or self.Destroyed or self._suppressCallbacks then return end
        local args=table.pack(...)
        if self._closing or self._syncCallbacks then return self:_protected(callback,context,table.unpack(args,1,args.n)) end
        task.spawn(function()
            if not self.Destroyed then self:_protected(callback,context,table.unpack(args,1,args.n)) end
        end)
    end
    function Window:_hasRuntimeWork()
        if self._dragRender or next(self._visualQueue) then return true end
        for _,job in pairs(self.Tasks) do if job.Requested or job.InFlight then return true end end
        return false
    end
    function Window:_refreshRuntime()
        local active=not self.Destroyed and self:_hasRuntimeWork()
        if active and not self._runtimeConnection then
            self._runtimeConnection=RunService.RenderStepped:Connect(function(dt) self:_runtimeStep(dt) end)
        elseif not active and self._runtimeConnection then self._runtimeConnection:Disconnect(); self._runtimeConnection=nil end
    end
    function Window:_clampCenter(center)
        local view=self.Root.AbsoluteSize
        local size=self._logicalSize or self._requestedSize
        local scale=self._actualScale or self.UserScale
        local halfX=size.X*scale/2; local halfY=(self.Minimized and 42 or size.Y)*scale/2
        return Vector2.new(clamp(center.X,halfX+8,math.max(halfX+8,view.X-halfX-8)),clamp(center.Y,halfY+24,math.max(halfY+24,view.Y-halfY-8)))
    end
    function Window:_moveWindow(center)
        self:_cancelTrack(self.Main,"window",false)
        if self._shown~=false then self.Main.BackgroundTransparency=0 end
        center=self:_clampCenter(center); self._position=center
        if self.SmoothDragging and not self.ReducedMotion then
            self._dragRender={Target=center}; self:_refreshRuntime()
        else self._dragRender=nil; self.Main.Position=U2(center.X,center.Y); self:_refreshRuntime() end
    end
    function Window:_runtimeStep(dt)
        if self.Destroyed then self:_refreshRuntime(); return end
        dt=finite(dt) and clamp(dt,0,.1) or 1/60
        if self._dragRender then
            local target=self:_clampCenter(self._dragRender.Target)
            local current=Vector2.new(self.Main.Position.X.Offset,self.Main.Position.Y.Offset)
            local alpha=1-math.exp(-self.DragResponsiveness*dt)
            local nextPosition=current+(target-current)*alpha
            if math.abs(target.X-nextPosition.X)+math.abs(target.Y-nextPosition.Y)<.15 then nextPosition=target; self._dragRender=nil end
            self.Main.Position=U2(nextPosition.X,nextPosition.Y)
        end
        if self._stepTasks then self:_stepTasks() end
        local now=os.clock(); local ready={}
        for control,job in pairs(self._visualQueue) do if control.Destroyed then self._visualQueue[control]=nil elseif now>=job.Due then ready[#ready+1]={control,job} end end
        for _,item in ipairs(ready) do
            self._visualQueue[item[1]]=nil
            self:_protected(item[2].Render,{ControlId=item[1].Id,Phase="Render"})
        end
        self:_refreshRuntime()
    end
    function Window:_requestVisual(control,render,rate)
        local now=os.clock(); local interval=1/(rate or 20)
        if not control._lastDraw or now-control._lastDraw>=interval then control._lastDraw=now; self:_protected(render,{ControlId=control.Id,Phase="Render"})
        else self._visualQueue[control]={Due=control._lastDraw+interval,Render=function() control._lastDraw=os.clock(); render() end}; self:_refreshRuntime() end
    end
    function Window:SetDragOptions(options)
        assert(type(options)=="table","Drag options must be a table")
        local enabled=options.Smooth; if enabled==nil then enabled=self.SmoothDragging end
        local responsiveness=options.Responsiveness or self.DragResponsiveness
        assert(type(enabled)=="boolean" and finite(responsiveness) and responsiveness>=8 and responsiveness<=80,"Drag Smooth must be boolean and Responsiveness 8–80")
        self.SmoothDragging=enabled; self.DragResponsiveness=responsiveness
        if not enabled and self._dragRender then local t=self:_clampCenter(self._dragRender.Target); self.Main.Position=U2(t.X,t.Y); self._dragRender=nil; self:_refreshRuntime() end
        self:_scheduleSave(); return self
    end
    -- Observable values use one bounded dispatch queue. Batches coalesce events
    -- so derived UI observes a complete set of flags, never a partial update.
    local State={}; State.__index=State
    local queue,pending,dispatching,batchDepth,afterBatch={},{},false,0,{}
    local function cloneState(value,seen,depth)
        if typeof(value)~="table" then return value end
        seen=seen or {}; depth=depth or 0
        assert(depth<16 and not seen[value],"State data must be acyclic and at most 16 levels deep")
        seen[value]=true; local result={}; local count=0
        for key,item in pairs(value) do
            count=count+1; assert(count<=1024,"State table exceeds 1024 entries")
            assert(type(key)=="number" or type(key)=="string","State keys must be strings or numbers")
            result[key]=cloneState(item,seen,depth+1)
        end
        seen[value]=nil; return result
    end
    local function notifyState(state,listener,value)
        if not listener.Connected or state.Destroyed then return end
        if state._window then state._window:_protected(listener.Callback,{Phase="State",Operation=state.Name},cloneState(value))
        else
            local ok,err=pcall(listener.Callback,cloneState(value))
            if not ok then warn("[RetroBox] State observer: "..tostring(err)) end
        end
    end
    local function drainStates()
        if dispatching or batchDepth>0 then return end
        dispatching=true; local iterations=0
        while #queue>0 do
            iterations=iterations+1
            if iterations>128 then
                local offender=queue[1]; queue={}; pending={}
                if offender._window then offender._window:_diagnose({Phase="State",Operation=offender.Name},"Reactive update cycle exceeded 128 changes")
                else warn("[RetroBox] Reactive update cycle exceeded 128 changes") end
                break
            end
            local state=table.remove(queue,1); pending[state]=nil
            if not state.Destroyed then
                local value=state:Get(); local listeners={}
                for listener in pairs(state._listeners) do listeners[#listeners+1]=listener end
                for _,listener in ipairs(listeners) do notifyState(state,listener,value) end
            end
        end
        dispatching=false
    end
    function Library:Batch(callback)
        assert(type(callback)=="function","Batch expects a function")
        batchDepth=batchDepth+1; local result=table.pack(pcall(callback)); batchDepth=batchDepth-1
        if batchDepth==0 then local deferred=afterBatch; afterBatch={}; for _,fn in ipairs(deferred) do fn() end end
        drainStates(); if not result[1] then error(result[2],2) end
        return table.unpack(result,2,result.n)
    end
    function Library:_afterBatch(callback)
        if batchDepth>0 then afterBatch[#afterBatch+1]=callback else callback() end
    end
    function Library:CreateState(value,options)
        options=options or {}; assert(options.Validate==nil or type(options.Validate)=="function","State Validate must be a function")
        local state=setmetatable({_value=cloneState(value),_listeners={},Validate=options.Validate,Name=options.Name or "State",_window=options.Window},State)
        if state.Validate then local valid,reason=state.Validate(state:Get()); assert(valid,reason or "Invalid initial state") end
        return state
    end
    function Library:_isState(value) return getmetatable(value)==State end
    function State:Get() return cloneState(self._value) end
    function State:_assign(value)
        assert(not self.Destroyed,"State has been destroyed")
        local nextValue=cloneState(value)
        if self.Validate then local valid,reason=self.Validate(cloneState(nextValue)); assert(valid,reason or "Invalid state") end
        if same(self._value,nextValue) then return false end
        self._value=nextValue
        if not pending[self] then pending[self]=true; queue[#queue+1]=self end
        drainStates(); return true
    end
    function State:Set(value)
        assert(not self.ReadOnly,"Computed states are read-only")
        return self:_assign(value)
    end
    function State:Update(callback) assert(type(callback)=="function","Update expects a function"); return self:Set(callback(self:Get())) end
    function State:Subscribe(callback,immediate)
        assert(not self.Destroyed and type(callback)=="function","Subscribe needs a live state and function")
        local owner=self; local listener={Connected=true,Callback=callback}
        function listener:Disconnect() self.Connected=false; owner._listeners[self]=nil end
        self._listeners[listener]=true
        if immediate then notifyState(self,listener,self:Get()) end
        return listener
    end
    function State:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true
        local listeners={}; for listener in pairs(self._listeners) do listeners[#listeners+1]=listener end
        for _,listener in ipairs(listeners) do listener:Disconnect() end
        if self._scope then self._scope:Destroy(); self._scope=nil end
    end
    function Window:CreateState(value,options)
        assert(not self.Destroyed,"Window has been destroyed")
        options=copy(options or {}); options.Window=self
        local state=Library:CreateState(value,options)
        local scope=self:CreateScope(); state._scope=scope
        scope:Add(function() if not state.Destroyed then state:Destroy() end end)
        return state
    end
    function Window:Computed(sources,calculate)
        assert(type(sources)=="table" and #sources>=1 and #sources<=32 and type(calculate)=="function","Computed requires 1–32 states and a function")
        for _,source in ipairs(sources) do assert(Library:_isState(source) and not source.Destroyed,"Computed source must be a live state") end
        local function get() local values={}; for i,source in ipairs(sources) do values[i]=source:Get() end; return calculate(table.unpack(values,1,#sources)) end
        local state=self:CreateState(get()); state.ReadOnly=true
        local function update()
            if state.Destroyed or self.Destroyed then return end
            self:_protected(function() state:_assign(get()) end,{Phase="Computed",Operation=state.Name})
        end
        for _,source in ipairs(sources) do state._scope:Add(source:Subscribe(update),"Disconnect") end
        return state
    end
    function Window:GetFlagState(id)
        assert(type(id)=="string" and self.Controls[id] and not self.Controls[id].Destroyed,"Unknown flag: "..tostring(id))
        local state=self._flagStates[id]
        if not state then state=self:CreateState(self:GetFlag(id),{Name="Flag:"..id}); state.ReadOnly=true; self._flagStates[id]=state end
        return state
    end
    function Window:_flagChanged(control)
        local state=self._flagStates[control.Id]
        if state and not state.Destroyed then state:_assign(control:GetValue()) end
    end
    function Window:SetFlags(values,options)
        if self.Destroyed then return false,"Window has been destroyed" end
        options=type(options)=="boolean" and {Silent=options} or options or {}
        local ok,prepared=pcall(function()
            assert(type(values)=="table","SetFlags expects a table")
            local changes={}
            for id,value in pairs(values) do
                local control=self.Controls[id]
                assert(type(id)=="string" and control and not control.Destroyed,"Unknown flag: "..tostring(id))
                local normalized=control:_normalize(value)
                if not same(control.Value,normalized) then changes[#changes+1]={Control=control,Value=normalized} end
            end
            table.sort(changes,function(a,b) return a.Control.Id<b.Control.Id end)
            return changes
        end)
        if not ok then return false,tostring(prepared) end
        Library:Batch(function()
            for _,change in ipairs(prepared) do
                change.Control._callbackEpoch=(change.Control._callbackEpoch or 0)+1
                change.Control:SetValue(change.Value,true)
            end
        end)
        if not options.Silent then for _,change in ipairs(prepared) do if not change.Control.Destroyed then change.Control:_emit() end end end
        self:_scheduleSave(); return true
    end
    function Window:Condition(spec)
        local sources,indices={},{}; local nodes=0
        local function source(state)
            if not indices[state] then sources[#sources+1]=state; indices[state]=#sources end
            return indices[state]
        end
        local function compile(rule,seen,depth)
            nodes=nodes+1; assert(nodes<=64 and depth<=8,"Condition exceeds 64 nodes or 8 levels")
            if type(rule)=="boolean" then return function() return rule end end
            if Library:_isState(rule) then local index=source(rule); return function(values) return not not values[index] end end
            assert(type(rule)=="table" and not seen[rule],"Conditions must be acyclic tables, booleans or states")
            seen[rule]=true
            local evaluator
            if rule.All or rule.Any then
                assert(not(rule.All and rule.Any),"Condition cannot combine All and Any in the same node")
                local children=rule.All or rule.Any; assert(type(children)=="table" and #children>=1,"All/Any needs conditions")
                local tests={}; for i,child in ipairs(children) do tests[i]=compile(child,seen,depth+1) end
                evaluator=function(values)
                    for _,test in ipairs(tests) do local v=test(values); if rule.All and not v then return false elseif rule.Any and v then return true end end
                    return rule.All~=nil
                end
            elseif rule.Not~=nil then local test=compile(rule.Not,seen,depth+1); evaluator=function(values) return not test(values) end
            else
                local state=rule.State or (rule.Flag and self:GetFlagState(rule.Flag))
                assert(Library:_isState(state),"Condition needs Flag, State, All, Any or Not")
                assert(rule.Test==nil or type(rule.Test)=="function","Condition Test must be a function")
                local index=source(state)
                evaluator=function(values)
                    if rule.Test then return not not rule.Test(copy(values[index])) end
                    if rule.Equals~=nil then return same(values[index],rule.Equals) end
                    return not not values[index]
                end
            end
            seen[rule]=nil; return evaluator
        end
        local evaluate=compile(spec,{},0)
        if #sources==0 then local state=self:CreateState(evaluate({})); state.ReadOnly=true; return state end
        return self:Computed(sources,function(...) return evaluate({...}) end)
    end
    function Control:BindState(state,options)
        assert(not self.Destroyed and Library:_isState(state) and not state.Destroyed,"BindState requires a live state and control")
        options=options or {}; local property=options.Property or "Value"
        assert(property=="Value" or property=="Text" or property=="Subtitle" or property=="Visible" or property=="Enabled" or property=="Disabled","Unsupported binding property")
        assert(options.Transform==nil or type(options.Transform)=="function","Binding Transform must be a function")
        assert(not options.TwoWay or property=="Value" and not state.ReadOnly,"TwoWay needs a writable Value state")
        local scope=self._resources:Child(); self._resources:Add(scope,"Destroy","binding:"..property)
        local applying=false
        local function apply(value)
            if self.Destroyed then return end
            self._window:_protected(function()
                if options.Transform then value=options.Transform(value) end
                applying=true
                local ok,err=pcall(function()
                    if property=="Visible" then self:SetVisible(not not value)
                    elseif property=="Enabled" or property=="Disabled" then
                        local disabled=property=="Enabled" and not value or property=="Disabled" and not not value
                        self:SetDisabled(disabled)
                        if options.Reason then
                            if not self._dependencyTip then self._dependencyTip={Original=self:GetTooltip()} end
                            local original=self._dependencyTip.Original
                            self:SetTooltip(disabled and {Title=self.Title,Text=(original and original.Text.."\n\n" or "")..tostring(options.Reason)} or original)
                        end
                    elseif property=="Text" then assert(self.SetText,"This control does not support Text"); self:SetText(tostring(value))
                    elseif property=="Subtitle" then assert(self.SetSubtitle,"This control does not support Subtitle"); self:SetSubtitle(tostring(value))
                    else
                        self:SetValue(value,not options.FireCallback)
                        if options.TwoWay and not same(state:Get(),self:GetValue()) then state:Set(self:GetValue()) end
                    end
                end)
                applying=false; if not ok then error(err) end
            end,{ControlId=self.Id,Phase="Binding"})
        end
        scope:Add(state:Subscribe(apply),"Disconnect")
        if options.TwoWay then scope:Add(self._window:GetFlagState(self.Id):Subscribe(function(value) if not applying and not state.Destroyed then state:Set(value) end end),"Disconnect") end
        apply(state:Get()); return scope
    end
    function Control:DependsOn(options)
        assert(type(options)=="table","DependsOn expects a table")
        for _,property in ipairs({"Visible","Enabled"}) do if options[property]~=nil then
            local state=self._window:Condition(options[property])
            local binding=self:BindState(state,{Property=property,Reason=options.Reason})
            binding:Add(state,"Destroy")
        end end
        return self
    end

    -- Cooperative contexts never force-terminate user threads. Replacements in
    -- the same group wait for the cancelled worker to return before starting.
    local function token(window,scope)
        local context={Window=window,Resources=scope,Cancelled=false}
        function context:IsCancelled() return self.Cancelled or window.Destroyed end
        function context:ThrowIfCancelled() if self:IsCancelled() then error(cancelSignal,0) end end
        function context:Manage(resource,method,key) return self.Resources:Add(resource,method,key) end
        function context:Cancel(reason)
            if self.Cancelled then return end
            self.Cancelled=true; self.Reason=reason or "cancelled"; self.Resources:Destroy()
        end
        return context
    end
    function Window:CreateTask(options)
        assert(not self.Destroyed and type(options)=="table","CreateTask requires options and a live window")
        local id=options.Id; local interval=options.Interval or 1
        assert(type(id)=="string" and #id>=1 and #id<=128 and not self.Tasks[id],"Task Id must be unique and 1–128 bytes")
        assert(finite(interval) and interval>=.03 and interval<=86400,"Task Interval must be .03–86400 seconds")
        assert(type(options.Callback)=="function","Task Callback is required")
        assert(options.OnError==nil or options.OnError=="Stop" or options.OnError=="Continue","Task OnError is Stop or Continue")
        assert(options.Scope==nil or getmetatable(options.Scope)==Scope and not options.Scope.Destroyed,"Task Scope must be a live resource scope")
        local count=0; for _ in pairs(self.Tasks) do count=count+1 end; assert(count<128,"Window task limit is 128")
        local owner=self
        local job={Id=id,Interval=interval,Callback=options.Callback,Options=options,Requested=false,InFlight=false,Iterations=0,Generation=0}
        local policyScope=(options.Scope or self._resources):Child({CancelOnHide=options.CancelOnHide==true,CancelOnDisable=options.CancelOnDisable==true,CancelOnFalse=options.CancelOnFalse==true})
        policyScope:Add(function() job:Stop("scope cleaned") end,nil,"stop")
        function job:Start()
            if self.Destroyed or owner.Destroyed or policyScope.Destroyed then return false,"Task has been destroyed" end
            if self.Requested then return true end
            if not policyScope._keys.stop then policyScope:Add(function() self:Stop("scope cleaned") end,nil,"stop") end
            self.Requested=true; self.Generation=self.Generation+1
            self.Next=os.clock()+(options.Immediate==false and self.Interval or 0)
            owner:_refreshRuntime(); return true
        end
        function job:Stop(reason)
            self.Requested=false; self.Generation=self.Generation+1
            if self.Context then self.Context:Cancel(reason) end
            owner:_refreshRuntime(); return self
        end
        job.Cancel=job.Stop
        function job:IsRunning() return self.Requested or self.InFlight end
        function job:SetInterval(value)
            assert(finite(value) and value>=.03 and value<=86400,"Task Interval must be .03–86400")
            self.Interval=value; self.Next=os.clock()+value; return self
        end
        function job:Destroy()
            if self.Destroyed then return end
            self:Stop("destroyed"); self.Destroyed=true
            policyScope:Destroy(); owner.Tasks[id]=nil; owner._resources:Remove("task:"..id,true)
        end
        self.Tasks[id]=job; self:Manage(job,"Destroy","task:"..id)
        if options.Start then job:Start() end
        return job
    end
    function Control:CreateTask(options)
        assert(not self.Destroyed,"Control has been destroyed")
        assert(type(options)=="table","CreateTask requires options")
        local original=options; options={}; for k,v in pairs(original) do options[k]=v end
        options.Scope=self._resources; options.ControlId=self.Id
        local job=self._window:CreateTask(options); self:Manage(job,"Destroy","task:"..job.Id); return job
    end
    function Window:_stepTasks()
        local now=os.clock(); local ready={}
        for _,job in pairs(self.Tasks) do if job.Requested and not job.InFlight and now>=job.Next then ready[#ready+1]=job end end
        for _,job in ipairs(ready) do
            if not job.Destroyed and job.Requested and not job.InFlight then
                job.InFlight=true; local generation=job.Generation
                local scope=self:CreateScope(); local context=token(self,scope); job.Context=context
                task.spawn(function()
                    local ok,result,reason=true,nil,nil
                    if not context:IsCancelled() and not job.Destroyed then
                        ok,result,reason=self:_protected(job.Callback,{ControlId=job.Options.ControlId,Operation=job.Id,Phase="Task"},context)
                    end
                    scope:Destroy(); job.Context=nil; job.InFlight=false; job.Iterations=job.Iterations+1
                    if not ok and result~=cancelSignal then
                        job.LastError=tostring(result)
                        if job.Options.OnError~="Continue" then job.Requested=false end
                    end
                    if job.Options.Once then job.Requested=false end
                    if job.Generation==generation then job.Next=os.clock()+job.Interval end
                    if not self.Destroyed and not job.Destroyed then self:_refreshRuntime() end
                end)
            end
        end
    end
    function Window:StartTask(id) local job=self.Tasks[id]; assert(job,"Unknown task: "..tostring(id)); return job:Start() end
    function Window:StopTask(id,reason) local job=self.Tasks[id]; assert(job,"Unknown task: "..tostring(id)); job:Stop(reason); return self end
    local function actionUpdate(handle,changes)
        for key,value in pairs(changes) do handle._status[key]=value end
        if not handle.Status.Destroyed then handle.Status:_assign(handle._status) end
    end
    function Window:_finishAction(handle,status,result,err)
        if handle.Finished then return end
        handle.Finished=true; handle.Result=result; handle.Error=err
        handle.Context.Resources:Destroy()
        local safeResult
        if result~=nil then local ok,value=pcall(cloneState,result); if ok then safeResult=value end end
        handle._status.Result=safeResult; handle._status.Error=err and tostring(err):sub(1,2048) or nil
        actionUpdate(handle,{Status=status,Message=err and tostring(err):sub(1,2048) or handle._status.Message,Progress=status=="Completed" and 1 or handle._status.Progress})
        local group=self._groups[handle.Group]
        if group and group.Active==handle then group.Active=nil end
        self._actions[handle.Id]=nil
        self._actionHistory[#self._actionHistory+1]=handle
        while #self._actionHistory>32 do table.remove(self._actionHistory,1):Destroy() end
        if not self.Destroyed then
            self:_dispatch(handle.Options.OnComplete,{Operation=handle.Id,Phase="Complete"},handle)
            if group and not group.Active then self:_startNextAction(group) end
        end
    end
    function Window:_startNextAction(group)
        if self.Destroyed or group.Active then return end
        local handle
        while #group.Queue>0 do
            local candidate=table.remove(group.Queue,1)
            if not candidate.Finished and not candidate.Context:IsCancelled() then handle=candidate; break end
        end
        if not handle then self._groups[group.Id]=nil; return end
        group.Active=handle; actionUpdate(handle,{Status="Running"})
        task.spawn(function()
            local ok,result,reason=true,nil,nil
            if not handle.Context:IsCancelled() then
                ok,result,reason=self:_protected(handle.Options.Callback,{ControlId=handle.Options.ControlId,Operation=handle.Id,Phase="Action"},handle.Context)
            end
            if handle.Context:IsCancelled() or result==cancelSignal then self:_finishAction(handle,"Cancelled",nil,handle.Context.Reason)
            elseif not ok or result==false then self:_finishAction(handle,"Failed",nil,ok and (reason or "Action returned false") or result)
            else self:_finishAction(handle,"Completed",result) end
        end)
    end
    function Window:RunAction(options)
        if self.Destroyed then return nil,"Window has been destroyed" end
        assert(type(options)=="table" and type(options.Callback)=="function","RunAction needs a Callback")
        local groupId=options.Group or options.Id or "default"
        local policy=options.Policy or "Reject"
        assert(type(groupId)=="string" and #groupId>=1 and #groupId<=128,"Action Group must be 1–128 bytes")
        assert(policy=="Ignore" or policy=="Reject" or policy=="Queue" or policy=="Replace","Action Policy must be Ignore, Reject, Queue or Replace")
        local group=self._groups[groupId]
        if group and group.Active then
            if policy=="Ignore" or policy=="Reject" then return nil,policy=="Ignore" and "ignored" or "Group is busy: "..groupId end
            if policy=="Replace" then
                group.Active:Cancel("replaced")
                local queued={table.unpack(group.Queue)}; for _,entry in ipairs(queued) do entry:Cancel("replaced") end
            end
            if #group.Queue>=32 then return nil,"Action queue limit is 32 per group" end
        end
        self._nextAction=self._nextAction+1
        local id=options.Id or "action/"..self._nextAction
        assert(type(id)=="string" and #id>=1 and #id<=128,"Action Id must be 1–128 bytes")
        if self._actions[id] then return nil,"Action Id is already running: "..id end
        local count=0; for _ in pairs(self._groups) do count=count+1 end
        if not group and count>=32 then return nil,"Action group limit is 32" end
        group=group or {Id=groupId,Queue={}}; self._groups[groupId]=group
        local owner=self; local scope=self:CreateScope({CancelOnHide=options.CancelOnHide==true})
        local handle={Id=id,Group=groupId,Options=options,_status={Status="Queued",Step=0,Total=0,Progress=0,Message=""}}
        handle.Status=self:CreateState(handle._status,{Name="Action:"..id})
        handle.Status.ReadOnly=true
        handle.Context=token(self,scope); handle.Context.Action=handle
        function handle:GetStatus() return copy(self._status) end
        function handle:Subscribe(callback,immediate) return self.Status:Subscribe(callback,immediate) end
        function handle:Cancel(reason)
            if self.Finished then return self end
            self.Context:Cancel(reason)
            if self.Finished then return self end
            if self._status.Status=="Queued" then
                local index=table.find(group.Queue,self); if index then table.remove(group.Queue,index) end
                owner:_finishAction(self,"Cancelled",nil,self.Context.Reason)
            else actionUpdate(self,{Status="Cancelling",Message=self.Context.Reason}) end
            return self
        end
        function handle:Destroy()
            if self.Destroyed then return end
            self:Cancel("destroyed"); self.Destroyed=true; self.Status:Destroy()
            owner._resources:Remove("action:"..id,true)
        end
        function handle.Context:SetProgress(step,total,message)
            self:ThrowIfCancelled()
            assert(finite(step) and finite(total) and total>0 and step>=0 and step<=total,"Progress requires 0 <= step <= total and total > 0")
            actionUpdate(handle,{Step=step,Total=total,Progress=step/total,Message=tostring(message or handle._status.Message):sub(1,2048)})
            owner:_dispatch(options.OnProgress,{Operation=id,Phase="Progress"},handle:GetStatus(),handle)
        end
        function handle.Context:SetMessage(message)
            self:ThrowIfCancelled(); actionUpdate(handle,{Message=tostring(message):sub(1,2048)}); return self
        end
        scope:Add(function() if not handle.Finished then handle:Cancel("scope cleaned") end end)
        self._actions[id]=handle; self:Manage(handle,"Destroy","action:"..id)
        group.Queue[#group.Queue+1]=handle; self:_startNextAction(group)
        return handle
    end
    function Window:StopAll(reason)
        reason=reason or "stop all"
        for _,job in pairs(self.Tasks) do job:Stop(reason) end
        local actions={}; for _,handle in pairs(self._actions) do actions[#actions+1]=handle end
        for _,handle in ipairs(actions) do handle:Cancel(reason) end
        return self
    end

    function Window:GetRuntimeStats()
        local stats={Tasks=0,RunningTasks=0,Actions=0,Animations=0,QueuedVisuals=0,Resources=self._resources:GetCount(),FrameConnection=self._runtimeConnection~=nil}
        for _,t in pairs(self.Tasks) do stats.Tasks=stats.Tasks+1; if t.Requested or t.InFlight then stats.RunningTasks=stats.RunningTasks+1 end end
        for _ in pairs(self._actions or {}) do stats.Actions=stats.Actions+1 end
        for _ in pairs(self._visualQueue) do stats.QueuedVisuals=stats.QueuedVisuals+1 end
        for _,tracks in pairs(self._tweens or {}) do for _ in pairs(tracks) do stats.Animations=stats.Animations+1 end end
        return stats
    end
end
-- END MANAGED RUNTIME

-- BEGIN CENTRAL ANIMATOR: conflict cancellation, accessibility and ownership.
do
    local function settings(options,current)
        assert(options==nil or type(options)=="table","Animations must be a table")
        options=options or {}; current=current or {Enabled=true,Speed=1,Intensity="Normal"}
        local result={Enabled=options.Enabled,Speed=options.Speed or current.Speed,Intensity=options.Intensity or current.Intensity}
        if result.Enabled==nil then result.Enabled=current.Enabled end
        assert(type(result.Enabled)=="boolean","Animations Enabled must be a boolean")
        assert(finite(result.Speed) and result.Speed>=.25 and result.Speed<=4,"Animation Speed must be .25–4")
        assert(result.Intensity=="Normal" or result.Intensity=="Subtle" or result.Intensity=="Off","Animation Intensity is Normal, Subtle or Off")
        return result
    end
    Library._animationSettings=settings
    local function within(object,root)
        if not root then return true end
        local parent=object
        while parent do if parent==root then return true end; parent=parent.Parent end
        return false
    end
    function Window:_cancelTrack(object,channel,finish)
        local tracks=self._tweens[object]; local record=tracks and tracks[channel]
        if not record then return end
        tracks[channel]=nil; if not next(tracks) then self._tweens[object]=nil end
        if record.Connection then record.Connection:Disconnect(); record.Connection=nil end
        record.Tween:Cancel(); record.Tween:Destroy()
        if finish and object.Parent then
            for key,value in pairs(record.Goals) do object[key]=value end
            if record.Complete and not self.Destroyed then record.Complete() end
        end
    end
    function Window:_cancelAnimations(root,finish)
        local targets={}
        for object,tracks in pairs(self._tweens) do
            for channel,record in pairs(tracks) do
                if within(object,root) or record.Owner and record.Owner.Frame==root then targets[#targets+1]={object,channel} end
            end
        end
        for _,target in ipairs(targets) do self:_cancelTrack(target[1],target[2],finish) end
    end
    function Window:_animate(object,goals,duration,channel,owner,complete)
        if self.Destroyed or self._closing or not object.Parent then return end
        channel=channel or "style"; local tracks=self._tweens[object]
        local prior=tracks and tracks[channel]
        if prior and same(prior.Goals,goals) then return prior.Tween end
        local conflicts={}
        for name,record in pairs(tracks or {}) do
            local overlap=name==channel
            for key in pairs(goals) do if record.Goals[key]~=nil then overlap=true end end
            if overlap then conflicts[#conflicts+1]=name end
        end
        for _,name in ipairs(conflicts) do self:_cancelTrack(object,name,false) end
        local motion=self.Animations.Enabled and not self.ReducedMotion and self.Animations.Intensity~="Off"
        if not motion or duration==0 then
            for key,value in pairs(goals) do object[key]=value end
            if complete then complete() end
            return
        end
        local time=(duration or .12)/self.Animations.Speed
        if self.Animations.Intensity=="Subtle" then time=time*.75 end
        local tween=TweenService:Create(object,TweenInfo.new(time,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goals)
        local record={Tween=tween,Goals=goals,Owner=owner,Complete=complete}
        self._tweens[object]=self._tweens[object] or {}; self._tweens[object][channel]=record
        record.Connection=tween.Completed:Connect(function(state)
            if self._tweens[object] and self._tweens[object][channel]==record then
                self._tweens[object][channel]=nil; if not next(self._tweens[object]) then self._tweens[object]=nil end
                record.Connection:Disconnect(); record.Connection=nil; tween:Destroy()
                if state==Enum.PlaybackState.Completed and complete and not self.Destroyed then complete() end
            end
        end)
        tween:Play(); return tween
    end
    function Window:SetAnimations(options)
        local nextOptions=settings(options,self.Animations)
        self.Animations=nextOptions
        if not nextOptions.Enabled or nextOptions.Intensity=="Off" or self.ReducedMotion then self:_cancelAnimations(nil,true) end
        self:_syncSettings(); self:_scheduleSave(); return self
    end
    function Window:GetAnimations() return copy(self.Animations) end
    function Window:_animateWindow(visible)
        self._visibilityToken=self._visibilityToken+1; local token=self._visibilityToken
        self:_cancelTrack(self.Main,"window",false)
        self:_cancelTrack(self.ScaleObject,"window",false)
        self:_cancelTrack(self.Main,"size",true)
        if visible then
            self.Main.Visible=true; self.Main.Active=true; self:_layout()
            local target=self.Main.Position; local scale=self._actualScale
            local subtle=self.Animations.Intensity=="Subtle"
            self.Main.Position=UDim2.new(target.X.Scale,target.X.Offset,target.Y.Scale,target.Y.Offset+(subtle and 3 or 6))
            self.Main.BackgroundTransparency=.08; self.ScaleObject.Scale=scale*(subtle and .995 or .985)
            self:_animate(self.Main,{Position=target,BackgroundTransparency=0},.14,"window",self)
            self:_animate(self.ScaleObject,{Scale=scale},.14,"window",self)
        else
            local position=self.Main.Position
            self:_animate(self.Main,{Position=UDim2.new(position.X.Scale,position.X.Offset,position.Y.Scale,position.Y.Offset+4),BackgroundTransparency=.15},.1,"window",self,function()
                if self._visibilityToken==token and not self._shown then self.Main.Visible=false; self.Main.BackgroundTransparency=0 end
            end)
        end
    end
end
-- END CENTRAL ANIMATOR

-- Icons are static GUI rectangles, merged into horizontal runs. Only mounted
-- icons allocate instances; there are no per-pixel signals or render loops.
local function iconSlot(window,parent,value,defaultName,size,position,role,onLayout)
    resolveIcon(value)
    local handle={_window=window,_connections={},Nodes={},Foreground={},Spec=value,Default=defaultName,Role=role or "Text",Size=size,Opacity=0}
    handle.Frame=frame(window,parent,{Name="PixelIcon",Position=position,Size=U2(size,size),BackgroundTransparency=1,
        Active=false,ZIndex=parent.ZIndex+1})
    window._icons[handle]=true
    function handle:SetOpacity(opacity)
        self.Opacity=opacity
        for _,node in ipairs(self.Nodes) do
            if node:IsA("ImageLabel") then node.ImageTransparency=opacity
            elseif node:IsA("TextLabel") then node.TextTransparency=opacity
            else node.BackgroundTransparency=opacity end
        end
    end
    function handle:SetRole(nextRole)
        self.Role=nextRole
        for _,node in ipairs(self.Foreground) do
            window:_bind(node,{[node:IsA("TextLabel") and "TextColor3" or "BackgroundColor3"]=nextRole})
        end
    end
    function handle:Set(spec)
        local effective=spec
        if effective==nil and self.Default and window.PixelIcons then effective=self.Default end
        local kind,name=resolveIcon(effective)
        local pattern=kind=="pixel" and iconPatterns[name] or nil
        self.Spec=spec
        if kind~="none" and (self.Kind~=kind or self.Name~=name or self.Pattern~=pattern) then
            for _,node in ipairs(self.Nodes) do window._skin[node]=nil; node:Destroy() end
            self.Nodes={}; self.Foreground={}
            if kind=="pixel" then
                local rows=iconRows(pattern); local width=#rows[1]; local height=#rows
                local step=math.max(1,math.floor(self.Size/math.max(width,height)))
                local ox=math.floor((self.Size-width*step)/2); local oy=math.floor((self.Size-height*step)/2)
                for y,row in ipairs(rows) do
                    local x=1
                    while x<=width do
                        local char=row:sub(x,x); local last=x
                        while last<width and row:sub(last+1,last+1)==char do last=last+1 end
                        if char~="." then
                            local node=frame(window,self.Frame,{Name="PixelRun",Position=U2(ox+(x-1)*step,oy+(y-1)*step),
                                Size=U2((last-x+1)*step,step),ZIndex=self.Frame.ZIndex+1},char=="#" and self.Role or iconRoles[char])
                            self.Nodes[#self.Nodes+1]=node
                            if char=="#" then self.Foreground[#self.Foreground+1]=node end
                        end
                        x=last+1
                    end
                end
            elseif kind=="asset" then
                self.Nodes[1]=ui(window,"ImageLabel",{Parent=self.Frame,Name="AssetIcon",Size=UDim2.fromScale(1,1),Image=name,
                    BackgroundTransparency=1,BorderSizePixel=0,ScaleType=Enum.ScaleType.Fit,ResampleMode=Enum.ResamplerMode.Pixelated,
                    ZIndex=self.Frame.ZIndex+1})
            else
                self.Nodes[1]=label(window,self.Frame,name,{Name="TextIcon",Size=UDim2.fromScale(1,1),TextSize=math.min(18,size),
                    TextXAlignment=Enum.TextXAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=self.Frame.ZIndex+1},self.Role)
                self.Foreground[1]=self.Nodes[1]
            end
            self:SetOpacity(self.Opacity)
            self.Kind=kind; self.Name=name; self.Pattern=pattern
        end
        self.Frame.Visible=kind~="none"
        self.Frame:SetAttribute("RetroBoxIcon",kind~="none" and name or nil)
        if onLayout then onLayout(self.Frame.Visible) end
        return self
    end
    function handle:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true; cleanup(self); window._icons[self]=nil
        for _,node in ipairs(self.Nodes) do window._skin[node]=nil end
        self.Nodes={}; self.Foreground={}; self.Frame:Destroy()
    end
    connect(handle,handle.Frame.Destroying,function() handle:Destroy() end)
    handle:Set(value)
    return handle
end
local function pixelButton(window,owner,parent,caption,name,props,pressed)
    local object=button(window,owner,parent,caption,props,pressed)
    iconSlot(window,object,nil,name,16,UDim2.new(.5,-8,.5,-8),"Text",function(visible) object.Text=visible and "" or caption end)
    return object
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
    if self._shown==false then return false end
    local section=control._section and (control._section._parentSection or control._section)
    if section and section._collapsed then return false end
    if self.Destroyed or control.Destroyed or not control.Tooltip or not self.Main.Visible or self.Minimized or self._drag or self._binding or self._dialog then return false end
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
        if state==Enum.UserInputState.Begin and positions[1] and self.Tooltip then
            self._touchWasLongPress=true; self._window:_showTooltip(self,positions[1],"touch")
        end
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
    if not pointer(input) or owner.Disabled or owner.Destroyed or self.Destroyed or self._dialog or self._binding then return end
    local section=owner._section and (owner._section._parentSection or owner._section)
    if section and (section._collapsed or not section._visible) then return end
    if (owner==self or owner._section) and self._shown==false then return end
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
    if not self.AutoSave or self._importing or self._syncingSettings or self._refreshingProfiles or self.Destroyed then return end
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
    if options.Internal then
        self._nextInternalId=(self._nextInternalId or 0)+1
        control.Id=options.Id or ("__retrobox/internal/"..self._nextInternalId)
    else
        self._nextId = self._nextId + 1
        control.Id = options.Id or ("control/" .. self._nextId)
    end
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
        if listener.Connected then
            local epoch=self._callbackEpoch
            call(self._window,function(v) if not self.Destroyed and listener.Connected and self._callbackEpoch==epoch then listener.Callback(v) end end,copy(value))
        end
    end
    self._window:_scheduleSave()
end
function Control:_callbackNow()
    local callback=self._callback; local epoch=self._callbackEpoch
    local function emit(...)
        if not self.Destroyed and self._callbackEpoch==epoch and type(callback)=="function" then return callback(...) end
    end
    if self.Type == "ColorPicker" then
        self._window:_dispatch(emit,{ControlId=self.Id,Phase="Callback"},self:GetColor(),self.Value.Opacity,self:GetValue())
    else
        self._window:_dispatch(emit,{ControlId=self.Id,Phase="Callback"},self:GetValue())
    end
end
function Control:SetValue(value, silent)
    assert(not self.Destroyed, "This control has been destroyed")
    local normalized = self:_normalize(value)
    local changed = not same(self.Value, normalized)
    if changed and self.Type=="Keybind" and self.Mode=="Hold" and self.Active then self:Trigger(false) end
    self.Value = copy(normalized)
    self._window.Flags[self.Id] = self:GetValue()
    if changed and normalized==false then Library:_afterBatch(function() if not self.Destroyed then self._window:_cleanPolicy("CancelOnFalse",self) end end) end
    self._window:_flagChanged(self)
    if self._render then self:_render() end
    if self._window._syncFloating then self._window:_syncFloating(self) end
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
    if disabled==true and self._resources then self._window:_cleanPolicy("CancelOnDisable",self) end
    if disabled==true and self.FloatingButton then self.FloatingButton:Release() end
    if disabled == true and self.Type == "Keybind" and self.Mode == "Hold" and self.Active then self:Trigger(false) end
    if disabled == true and self._window._binding == self then self._window._binding = nil end
    self.Disabled = disabled == true
    self.TitleLabel.TextTransparency = self.Disabled and .5 or 0
    if self._titleIcon then self._titleIcon:SetOpacity(self.Disabled and .5 or 0) end
    if self._render then self:_render() end
    if self.Keybind then self.Keybind:SetDisabled(self.Disabled) end
    if self._window._syncFloating then self._window:_syncFloating(self) end
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
function Control:SetIcon(value)
    local kind=resolveIcon(value)
    assert(not self.Destroyed,"This control has been destroyed")
    if not self._titleIcon and kind=="none" then return self end
    if not self._titleIcon then
        self._titleIcon=iconSlot(self._window,self.Frame,value,nil,16,U2(0,2),"Text",function(visible)
            local inset=visible and 22 or 0; local delta=inset-(self._iconInset or 0)
            local position,size=self.TitleLabel.Position,self.TitleLabel.Size
            self.TitleLabel.Position=UDim2.new(position.X.Scale,position.X.Offset+delta,position.Y.Scale,position.Y.Offset)
            self.TitleLabel.Size=UDim2.new(size.X.Scale,size.X.Offset-delta,size.Y.Scale,size.Y.Offset)
            self._iconInset=inset
        end)
        self.Icon=self._titleIcon.Frame
    else self._titleIcon:Set(value) end
    self._titleIcon:SetOpacity(self.Disabled and .5 or 0)
    return self
end
function Control:SetDescription(text)
    self.Description = tostring(text or "")
    self.DescriptionLabel.Text = self.Description
    self.DescriptionLabel.Visible = #self.Description > 0
    return self
end
function Control:Destroy()
    if self.Destroyed or self._destroyingControl then return end
    self._destroyingControl=true
    if self._window._cancelAnimations then self._window:_cancelAnimations(self.Frame,false) end
    if self._resources then self._resources:Destroy() end
    local flagState=self._window._flagStates[self.Id]
    if flagState then flagState:Destroy(); self._window._flagStates[self.Id]=nil end
    self._window._visualQueue[self]=nil
    self._callbackEpoch=(self._callbackEpoch or 0)+1
    local oldSync=self._window._syncCallbacks; self._window._syncCallbacks=true
    if self.Keybind then self.Keybind:Destroy(); self.Keybind=nil end
    if self.FloatingButton then self.FloatingButton:Destroy(); self.FloatingButton=nil end
    if self.Type == "Keybind" and self.Mode == "Hold" and self.Active then self:Trigger(false) end
    for _,floating in pairs(self._window._floatingButtons) do if floating.Control==self then floating:Destroy() end end
    self._window._syncCallbacks=oldSync
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
    self._window._touchToggles[self]=nil
    for listener in pairs(self._listeners) do listener.Connected = false end
    self._listeners = {}
    self.Frame:Destroy()
    local index = table.find(self._section.Controls, self)
    if index then table.remove(self._section.Controls, index) end
    if self._section._parentSection then
        local parent=self._section._parentSection
        local outer=table.find(parent.Controls,self); if outer then table.remove(parent.Controls,outer) end
        self._section:_layout()
    end
    self._window:_updateRGB()
end

local function base(section, kind, options, height)
    options = options or {}
    assert(not section.Destroyed and not section._window.Destroyed, "Section has been destroyed")
    local window = section._window
    resolveIcon(options.Icon)
    assert(options.Floating==nil or type(options.Floating)=="boolean" or type(options.Floating)=="table","Floating must be a boolean or options table")
    assert(not options.Floating or kind=="Toggle" or kind=="Button" or kind=="Keybind","Floating supports Toggle, Button or Keybind")
    local tip=options.Tooltip
    if tip==nil then tip=options.Tip end
    local tooltip=tooltipValue(tip)
    local self = setmetatable({ Type=kind, Title=tostring(options.Title or kind), Description=tostring(options.Description or ""),
        Tooltip=tooltip,_window=window, _section=section, _connections={},_callbackEpoch=0, _visible=options.Visible ~= false, Disabled=options.Disabled == true }, Control)
    window:_register(self, options)
    self._resources=window:CreateScope(); self._resources._owner=self
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
    if section._parentSection then table.insert(section._parentSection.Controls,self) end
    connect(self, self.Frame.Destroying, function() if not self.Destroyed then self:Destroy() end end)
    if section._isRow then
        self._rowHeight=height or 76
        connect(self,self.Frame:GetPropertyChangedSignal("Size"),function()
            if not section._layingOut then self._rowHeight=self.Frame.Size.Y.Offset; section:_layout() end
        end)
        connect(self,self.Frame:GetPropertyChangedSignal("Visible"),function() section:_layout() end)
        section:_layout()
    end
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
    control:SetIcon(options.Icon)
    if options.State then control:BindState(options.State,{TwoWay=options.TwoWay~=false,FireCallback=options.FireOnState==true,Transform=options.Transform}) end
    if options.DependsOn then control:DependsOn(options.DependsOn) end
    if options.FireOnInit then local epoch=control._callbackEpoch; task.defer(function() if not control.Destroyed and control._callbackEpoch==epoch then control:_emit() end end) end
    if options.Floating then control:AddFloatingButton(type(options.Floating)=="table" and options.Floating or {}) end
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
        box.Text = self.Value and (self._window.PixelIcons and "" or "X") or ""
        box.TextColor3 = self._window.Palette[self.Value and "Accent" or "Text"]
        box.Active = not self.Disabled; box.TextTransparency = self.Disabled and .5 or 0
        if self._hasDefault then self._window:_animate(box,{BackgroundColor3=self._window.Palette[self.Value and "Inset" or "Surface"]},.1,"toggle",self) end
        if self.Value and self._window.PixelIcons and not self._checkIcon then
            self._checkIcon=iconSlot(self._window,box,"check",nil,16,U2(7,6),"Accent")
        end
        if self._checkIcon then
            self._checkIcon:Set(self.Value and self._window.PixelIcons and "check" or false)
            self._checkIcon:SetOpacity(self.Disabled and .5 or 0)
            if self.Value and self._hasDefault then
                self._checkIcon.Frame.Position=U2(7,5)
                self._window:_animate(self._checkIcon.Frame,{Position=U2(7,6)},.1,"toggle",self)
            end
        end
    end
    connect(self, self.Frame.InputBegan, function(input)
        if pointer(input) and not self.Disabled and self._window._shown~=false and not (self._section._parentSection or self._section)._collapsed and not self._window._binding and not self._window._dialog and not inside(box, point(input))
            and (not self.Keybind or not inside(self.Keybind.Frame,point(input))) then
            if input.UserInputType==Enum.UserInputType.Touch then
                self._touchWasLongPress=false; self._window._touchToggles[self]={Input=input,Position=point(input)}
            else self:SetValue(not self.Value) end
        end
    end)
    self.Frame.Active = true
    self.Button = box
    init(self, options, false)
    if options.Keybind~=nil then
        local bindOptions=typeof(options.Keybind)=="table" and copy(options.Keybind) or {Default=options.Keybind}
        bindOptions.Id=bindOptions.Id or self.Id.."/keybind"; bindOptions.Title=self.Title
        bindOptions.Mode=bindOptions.Mode or "Toggle"; bindOptions.Floating=nil
        local extra=bindOptions.Callback
        bindOptions.Callback=function(active,binding)
            if self.Destroyed then return end
            if bindOptions.Mode=="Press" then self:SetValue(not self.Value) else self:SetValue(active) end
            if type(extra)=="function" then call(self._window,extra,self.Value,binding) end
        end
        local ok,binding=pcall(Section.AddKeybind,self._section,bindOptions)
        if not ok then self:Destroy(); error(binding,2) end
        self.Keybind=binding; binding._inlineParent=self; binding._target=self
        binding.Frame.Parent=self.Frame; binding.Frame.Position=UDim2.new(1,-150,0,0); binding.Frame.Size=U2(112,30)
        binding.TitleLabel.Visible=false; binding.DescriptionLabel.Visible=false
        if binding._titleIcon then binding._titleIcon.Frame.Visible=false end
        binding.Button.Position=U2(0,0); binding.Button.Size=U2(112,28)
        self.TitleLabel.Size=UDim2.new(1,-162-(self._iconInset or 0),0,23); self.DescriptionLabel.Size=UDim2.new(1,-162,0,18)
        self:SetDisabled(self.Disabled)
        if self._section._isRow then self._section:_layout() end
    end
    return self
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
        fill.Size = UDim2.new(ratio,0,1,0)
        local target=UDim2.new(ratio,0,.5,0)
        if self._hasDefault and not (self._window._drag and self._window._drag.Owner==self) then self._window:_animate(thumb,{Position=target},.07,"slider",self)
        else self._window:_cancelTrack(thumb,"slider",false); thumb.Position=target end
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
    self.Feedback=options.Feedback==true
    self._normalText=options.Text or self.Title
    local y = #self.Description > 0 and 44 or 24
    local action
    action = button(self._window,self,self.Frame,options.Text or self.Title,{ Position=U2(0,y),Size=UDim2.new(1,0,0,30) },function() self:Press() end)
    function self:_normalize(value) return value end
    function self:_render()
        action.Active = not self.Disabled and not self._busy
        local phase=self._busy and self._action and self._action:GetStatus().Status
        action.Text=self._busy and (phase=="Queued" and self._window:_text("queued") or phase=="Cancelling" and self._window:_text("cancelling") or options.BusyText or self._window:_text("running")) or self._normalText
        action.TextTransparency = self.Disabled and .5 or 0
    end
    function self:Press()
        if self.Disabled or self.Destroyed or self._busy then return false end
        if options.Group or options.Cancelable or options.Policy then
            local handle,reason=self._window:RunAction({Group=options.Group or self.Id,Policy=options.Policy or "Reject",ControlId=self.Id,
                CancelOnHide=options.CancelOnHide,Callback=function(ctx)
                    if self.Destroyed then ctx:Cancel("control destroyed"); ctx:ThrowIfCancelled() end
                    if type(self._callback)=="function" then return self._callback(self,ctx) end
                end,OnComplete=function(completed)
                    self._busy=false
                    if not self.Destroyed and not self._window.Destroyed then
                        self:_render(); self._window:_syncFloating(self)
                        if self.Feedback then self._window:Notify({Title=self.Title,
                            Kind=completed:GetStatus().Status=="Completed" and "success" or completed:GetStatus().Status=="Cancelled" and "normal" or "error",
                            Content=completed.Error or completed:GetStatus().Message or self._window:_text("success")}) end
                        self._resources:Remove("button-action-observer")
                        self._resources:Remove("button-action",true)
                    end
                end})
            if not handle then
                if reason~="ignored" and self.Feedback then self._window:Notify({Title=self.Title,Kind="error",Content=reason}) end
                return false,reason
            end
            self._action=handle; self._busy=true; self:Manage(handle,"Cancel","button-action")
            self:Manage(handle:Subscribe(function() if not self.Destroyed then self:_render() end end),"Disconnect","button-action-observer")
            self:_render(); self._window:_syncFloating(self); return true
        end
        self._busy = true
        self:_render()
        self._window:_syncFloating(self)
        task.spawn(function()
            if self.Destroyed or self._window.Destroyed then self._busy=false; return end
            local ok,result,reason = true,nil,nil
            if type(self._callback) == "function" then ok,result,reason = self._window:_protected(self._callback,{ControlId=self.Id,Phase="Button"},self) end
            local success=ok and result~=false
            self._busy = false
            if not self.Destroyed and not self._window.Destroyed then
                self:_render(); self._window:_syncFloating(self)
                if self.Feedback then self._window:Notify({Title=self.Title,Kind=success and "success" or "error",
                    Content=success and (options.SuccessText or self._window:_text("success")) or tostring(ok and (reason or options.ErrorText or self._window:_text("error")) or result)}) end
            end
        end)
        return true
    end
    self.Button = action
    function self:Cancel(reason) if self._action then self._action:Cancel(reason); return true end; return false end
    function self:GetAction() return self._action end
    self:SetDisabled(self.Disabled)
    self:SetIcon(options.Icon)
    if options.DependsOn then self:DependsOn(options.DependsOn) end
    if options.Floating then self:AddFloatingButton(type(options.Floating)=="table" and options.Floating or {}) end
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
    local arrow=label(self._window,header,"v",{ Position=UDim2.new(1,-24,0,0),Size=U2(20,30),TextXAlignment=Enum.TextXAlignment.Center })
    iconSlot(self._window,arrow,nil,"chevron-down",12,UDim2.new(.5,-6,.5,-6),"Text",function(visible) arrow.Text=visible and "" or "v" end)
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
        local target=UDim2.new(1,0,0,open and 272 or 80)
        if self._hasDefault then self._window:_animate(self.Frame,{Size=target},.12,"expand",self) else self.Frame.Size=target end
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
    local initial = bindingValue(options.Default or Enum.KeyCode.Unknown,options.AllowMouse)
    local self = base(self,"Keybind",options,#tostring(options.Description or "") > 0 and 46 or 30)
    self.Mode, self.Active = options.Mode or "Press", false
    self.CaptureOnly = options.CaptureOnly == true
    self.AllowMouse=options.AllowMouse~=false
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
        self._window:_hideTooltip()
        self._window:Notify({ Title=self.Title,Content=self._window:_text("capture"),Duration=2 })
    end)
    function self:_normalize(value) return bindingValue(value,self.AllowMouse) end
    function self:_render()
        capture.Text = self._window._binding == self and "..." or bindingLabel(self.Value)
        capture.TextTransparency = self.Disabled and .5 or 0
    end
    function self:_callbackNow() end
    function self:Trigger(active)
        if self.Destroyed or self.CaptureOnly then return end
        if (self.Disabled or self._target and self._target.Disabled) and not (self.Mode=="Hold" and active==false) then return end
        if self.Mode == "Toggle" then
            if self._target then self.Active=not self._target:GetValue() else self.Active=not self.Active end
        elseif self.Mode == "Hold" then self.Active = active == true
        else self.Active = true end
        local callback=self._callback; local epoch=self._callbackEpoch
        local dispatch=function(active,value)
            if not self.Destroyed and self._callbackEpoch==epoch and type(callback)=="function" then callback(active,value) end
        end
        if self._target then
            local ok,err=pcall(dispatch,self.Active,self.Value)
            if not ok then warn("[RetroBox] Inline binding: "..tostring(err)) end
        else call(self._window,dispatch,self.Active,self.Value) end
        if self.Mode == "Press" then self.Active = false end
        self._window:_syncFloating(self)
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
    local caption=label(window,expand,"",{Name="ColorValue",Position=U2(8,0),Size=UDim2.new(1,-52,1,0),TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
    local swatch = frame(window,expand,{Name="ColorSwatch",Position=UDim2.new(1,-34,0,6),Size=U2(26,18),BorderSizePixel=1},"Accent")
    self.Preview=swatch; self.PreviewText=caption
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
        if self._hasDefault and not state.Rainbow then window:_animate(swatch,{BackgroundColor3=self._currentColor},.08,"color",self)
        else window:_cancelTrack(swatch,"color",false); swatch.BackgroundColor3=self._currentColor end
        swatch.BackgroundTransparency = 1-state.Opacity
        caption.Text = hex(state.Color) .. (state.Rainbow and "  RGB" or "")
        caption.TextTransparency = self.Disabled and .5 or 0
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
        local target=UDim2.new(1,0,0,self.Open and 334 or 80)
        if self._hasDefault then window:_animate(self.Frame,{Size=target},.12,"expand",self) else self.Frame.Size=target end
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

-- BEGIN DASHBOARD COMPONENTS: pooled data views, not gameplay features.
do
    local function format(value,kind,precision)
        if type(kind)=="function" then return tostring(kind(value)) end
        if value==nil then return "—" end
        if type(value)~="number" then return tostring(value) end
        precision=precision or 1
        local function decimal(n) return string.format("%."..precision.."f",n):gsub("(%..-)0+$","%1"):gsub("%.$","") end
        if kind=="Compact" then
            local size=math.abs(value)
            for _,unit in ipairs({{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}) do if size>=unit[1] then return decimal(value/unit[1])..unit[2] end end
            return decimal(value)
        elseif kind=="Percent" then return decimal(value).."%"
        elseif kind=="Time" then
            local seconds=math.floor(math.abs(value)); local minutes=math.floor(seconds/60); local hours=math.floor(minutes/60)
            return (value<0 and "-" or "")..(hours>0 and string.format("%02d:%02d:%02d",hours,minutes%60,seconds%60) or string.format("%02d:%02d",minutes,seconds%60))
        end
        return tostring(value)
    end
    function Library:FormatValue(value,kind,precision)
        assert(precision==nil or finite(precision) and precision%1==0 and precision>=0 and precision<=6,"Precision must be 0–6")
        assert(type(kind)=="function" or kind==nil or kind=="Raw" or kind=="Compact" or kind=="Percent" or kind=="Time","Unknown value format")
        return format(value,kind,precision)
    end
    local function points(value,limit)
        assert(type(value)=="table" and #value<=4096,"Chart data must be an array with at most 4096 input points")
        local result={}
        for key in pairs(value) do assert(type(key)=="number" and key%1==0 and key>=1 and key<=#value,"Chart data must be a dense array") end
        for i,item in ipairs(value) do
            local p=type(item)=="number" and {Value=item} or item
            assert(type(p)=="table" and finite(p.Value),"Point Value must be finite")
            assert(p.Label==nil or type(p.Label)=="string" and #p.Label<=128,"Point Label must contain at most 128 bytes")
            assert(p.Time==nil or finite(p.Time),"Point Time must be finite")
            if i>#value-limit then result[#result+1]={Value=p.Value,Label=p.Label,Time=p.Time} end
        end
        return result
    end
    local function lineNode(window,parent,pool,index,color)
        local node=pool[index]
        if not node then
            node=frame(window,parent,{Name="ChartElement",AnchorPoint=Vector2.new(.5,.5),Visible=false},"Accent")
            pool[index]=node
        end
        if color then window._skin[node]=nil; node.BackgroundColor3=color end
        node.Visible=true; return node
    end
    local function hideExtra(pool,wanted)
        for index=wanted+1,#pool do pool[index].Visible=false end
    end
    local function lineGeometry(window,node,x1,y1,x2,y2,thickness,animated,owner)
        local dx,dy=x2-x1,y2-y1
        local goals={Position=U2((x1+x2)/2,(y1+y2)/2),Size=U2(math.max(1,math.sqrt(dx*dx+dy*dy)),thickness),Rotation=math.deg(math.atan2(dy,dx))}
        if animated and window._animate then window:_animate(node,goals,.08,"chart",owner)
        else for key,value in pairs(goals) do node[key]=value end end
    end
    function Section:AddStatCard(options)
        options=options or {}
        local height=options.Height or (options.Sparkline and 174 or 140)+(options.Description and 20 or 0)
        assert(finite(height) and height>=116 and height<=600,"StatCard Height must be 116–600")
        assert(options.Precision==nil or finite(options.Precision) and options.Precision>=0 and options.Precision<=6 and options.Precision%1==0,"Precision must be 0–6")
        assert(options.Format==nil or type(options.Format)=="function" or options.Format=="Raw" or options.Format=="Compact" or options.Format=="Percent" or options.Format=="Time","Unknown card format")
        local trend,limit=options.Trend or 0,options.MaxPoints or 40
        assert(finite(trend) and finite(limit) and limit%1==0 and limit>=2 and limit<=256,"Trend must be finite and MaxPoints 2–256")
        local self=base(self,"StatCard",options,height); self.Persist=false
        self.Unit=tostring(options.Unit or ""); self.Subtitle=tostring(options.Subtitle or ""); self.Format=options.Format or "Raw"
        self.Precision=options.Precision or 1; self.Loading=options.Loading==true; self.Unavailable=options.Unavailable==true
        self.Trend=trend; self.TrendText=options.TrendText; self._history={}; self.MaxPoints=limit
        local top=#self.Description>0 and 44 or 24
        local body=frame(self._window,self.Frame,{Position=U2(0,top),Size=UDim2.new(1,0,1,-top),BorderSizePixel=1},"Inset")
        self._window:_bind(body,{BackgroundColor3="Inset",BorderColor3="Border"}); bevel(self._window,body,true)
        self.ValueLabel=label(self._window,body,"",{Position=U2(10,10),Size=UDim2.new(1,self.Unit~="" and -108 or -20,0,34),TextSize=26,TextTruncate=Enum.TextTruncate.AtEnd})
        self.UnitLabel=label(self._window,body,self.Unit,{Position=UDim2.new(1,-94,0,18),Size=U2(84,20),TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd,TextXAlignment=Enum.TextXAlignment.Right},"Muted")
        self.SubtitleLabel=label(self._window,body,self.Subtitle,{Position=U2(10,50),Size=UDim2.new(1,-20,0,18),TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd},"Muted")
        self.TrendLabel=label(self._window,body,"",{Position=U2(10,74),Size=UDim2.new(1,-20,0,18),TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd},"Muted")
        if options.Sparkline then
            self._spark=frame(self._window,body,{Position=U2(10,100),Size=UDim2.new(1,-20,1,-108),ClipsDescendants=true,BackgroundTransparency=1})
            self._sparkPool={}
        end
        function self:_normalize(value)
            assert(value==nil or finite(value) or type(value)=="string" and #value<=2048,"StatCard value must be finite, text or nil")
            return value
        end
        function self:_draw()
            local content=self.Loading and self._window:_text("loading") or self.Unavailable and (self.UnavailableText or self._window:_text("unavailable")) or format(self.Value,self.Format,self.Precision)
            self.ValueLabel.Text=content; self.SubtitleLabel.Text=self.Subtitle; self.UnitLabel.Text=self.Unit
            self.ValueLabel.Size=UDim2.new(1,self.Unit~="" and -108 or -20,0,34)
            self.TrendLabel.Text=self.TrendText or (self.Trend~=0 and (self.Trend>0 and "+" or "")..format(self.Trend,self.Format,self.Precision) or "")
            self.TrendLabel.TextColor3=self._window.Palette[self.Trend>0 and "Success" or self.Trend<0 and "Danger" or "Muted"]
            self.ValueLabel.TextColor3=self._window.Palette[(self.Loading or self.Unavailable) and "Muted" or "Text"]
            if options.Animated and self._window._animate and finite(self.Value) and finite(self._lastValue) and self.Value~=self._lastValue then
                self.ValueLabel.TextColor3=self._window.Palette[self.Value>self._lastValue and "Success" or "Danger"]
                self._window:_animate(self.ValueLabel,{TextColor3=self._window.Palette.Text},.25,"stat",self)
            end
            self._lastValue=self.Value
            if self._spark then
                local size=self._spark.AbsoluteSize; local min,max=math.huge,-math.huge
                for _,p in ipairs(self._history) do min=math.min(min,p.Value); max=math.max(max,p.Value) end
                if min==max then min=min-1; max=max+1 end
                local count=#self._history
                for i=2,count do
                    local a,b=self._history[i-1].Value,self._history[i].Value
                    lineGeometry(self._window,lineNode(self._window,self._spark,self._sparkPool,i-1),
                        (i-2)/math.max(1,count-1)*size.X,(1-(a-min)/(max-min))*size.Y,
                        (i-1)/math.max(1,count-1)*size.X,(1-(b-min)/(max-min))*size.Y,2,false,self)
                end
                hideExtra(self._sparkPool,math.max(0,count-1))
            end
        end
        function self:_render() self._window:_requestVisual(self,function() self:_draw() end,20) end
        function self:SetSubtitle(value) self.Subtitle=tostring(value or ""); self:_render(); return self end
        function self:SetUnit(value) self.Unit=tostring(value or ""); self:_render(); return self end
        function self:SetTrend(value,text) assert(finite(value),"Trend must be finite"); self.Trend=value; self.TrendText=text; self:_render(); return self end
        function self:SetLoading(value) self.Loading=value==true; self:_render(); return self end
        function self:SetUnavailable(value,text) self.Unavailable=value==true; self.UnavailableText=text; self:_render(); return self end
        function self:SetHistory(data) self._history=points(data,self.MaxPoints); self:_render(); return self end
        function self:GetHistory() return copy(self._history) end
        function self:AddPoint(value,labelText) local data=self:GetHistory(); data[#data+1]={Value=value,Label=labelText}; return self:SetHistory(data) end
        if self._spark then connect(self,self._spark:GetPropertyChangedSignal("AbsoluteSize"),function() self:_render() end) end
        local value=options.Value; if value==nil then value=0 end
        return init(self,options,value)
    end
    function Section:AddChart(options)
        options=options or {}; local kind=options.Type or "Line"; local limit=options.MaxPoints or 60
        assert(kind=="Line" or kind=="Bar" or kind=="Progress" or kind=="Sparkline","Chart Type is Line, Bar, Progress or Sparkline")
        assert(finite(limit) and limit%1==0 and limit>=2 and limit<=512,"MaxPoints must be 2–512")
        local minimum,maximum=options.Min,options.Max
        if kind=="Progress" then minimum=minimum or 0; maximum=maximum or 100 end
        assert(minimum==nil or finite(minimum),"Chart Min must be finite")
        assert(maximum==nil or finite(maximum),"Chart Max must be finite")
        assert(minimum==nil or maximum==nil or maximum>minimum,"Chart Max must exceed Min")
        local height=options.Height or (kind=="Progress" and 80 or kind=="Sparkline" and 82 or 220)
        assert(finite(height) and height>=64 and height<=800,"Chart Height must be 64–800")
        local rate=options.RefreshRate or 20; assert(finite(rate) and rate>=1 and rate<=60,"RefreshRate must be 1–60")
        assert(options.Precision==nil or finite(options.Precision) and options.Precision%1==0 and options.Precision>=0 and options.Precision<=6,"Precision must be 0–6")
        assert(options.Thickness==nil or finite(options.Thickness) and options.Thickness>=1 and options.Thickness<=12,"Thickness must be 1–12")
        assert(options.Format==nil or type(options.Format)=="function" or options.Format=="Raw" or options.Format=="Compact" or options.Format=="Percent" or options.Format=="Time","Unknown chart format")
        local color=options.Color and parseColor(options.Color) or nil
        local self=base(self,kind.."Chart",options,height); self.Persist=false
        self.ChartType=kind; self.MaxPoints=limit; self.Min=minimum; self.Max=maximum; self.RefreshRate=rate
        self._pool={}; self._grid={}; self.ShowGrid=options.ShowGrid~=false and kind~="Progress" and kind~="Sparkline"
        self.ShowLabels=options.ShowLabels~=false and kind~="Progress" and kind~="Sparkline"
        self.Color=color
        local top=#self.Description>0 and 46 or 26
        local legendHeight=options.ShowLegend and 20 or 0
        if options.ShowLegend then self.Legend=label(self._window,self.Frame,options.Legend or self.Title,{Position=U2(8,top),Size=UDim2.new(1,-16,0,18),TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd},"Accent") end
        local left=self.ShowLabels and 62 or 8; local bottom=self.ShowLabels and 28 or 8
        self.Plot=frame(self._window,self.Frame,{Name="Plot",Position=U2(left,top+legendHeight),Size=UDim2.new(1,-left-8,1,-top-legendHeight-bottom),ClipsDescendants=true,BorderSizePixel=1},"Inset")
        self._window:_bind(self.Plot,{BackgroundColor3="Inset",BorderColor3="Border"})
        for i=0,4 do self._grid[i+1]=frame(self._window,self.Plot,{Position=UDim2.fromScale(0,i/4),Size=UDim2.new(1,0,0,1),BackgroundTransparency=.65,Visible=self.ShowGrid},"Border") end
        self.EmptyLabel=label(self._window,self.Plot,self._window:_text("noData"),{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=12},"Muted")
        self.MinLabel=label(self._window,self.Frame,"",{Position=UDim2.new(0,0,1,-bottom-16),Size=U2(56,16),TextSize=10,TextXAlignment=Enum.TextXAlignment.Right,Visible=self.ShowLabels},"Muted")
        self.MaxLabel=label(self._window,self.Frame,"",{Position=U2(0,top+legendHeight),Size=U2(56,16),TextSize=10,TextXAlignment=Enum.TextXAlignment.Right,Visible=self.ShowLabels},"Muted")
        self.FirstLabel=label(self._window,self.Frame,"",{Position=UDim2.new(0,left,1,-22),Size=UDim2.new(.5,-left,0,18),TextSize=10,TextTruncate=Enum.TextTruncate.AtEnd,Visible=self.ShowLabels},"Muted")
        self.LastLabel=label(self._window,self.Frame,"",{Position=UDim2.new(.5,0,1,-22),Size=UDim2.new(.5,-8,0,18),TextSize=10,TextTruncate=Enum.TextTruncate.AtEnd,TextXAlignment=Enum.TextXAlignment.Right,Visible=self.ShowLabels},"Muted")
        if kind=="Progress" then self.ProgressLabel=label(self._window,self.Plot,"",{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=14,ZIndex=self.Plot.ZIndex+3},"Text") end
        function self:_normalize(value) if self.ChartType=="Progress" then assert(finite(value),"Progress value must be finite"); return clamp(value,self.Min,self.Max) end; return points(value,self.MaxPoints) end
        function self:_bounds()
            if self.ChartType=="Progress" then return self.Min,self.Max end
            local min,max=math.huge,-math.huge
            for _,point in ipairs(self.Value) do min=math.min(min,point.Value); max=math.max(max,point.Value) end
            if #self.Value==0 then min,max=0,1 end
            if options.StartAtZero or self.ChartType=="Bar" then min=math.min(0,min); max=math.max(0,max) end
            if min==max then local pad=math.max(1,math.abs(min)*.05); min=min-pad; max=max+pad end
            min=self.Min or min; max=self.Max or max
            if max<=min then max=min+1 end
            return min,max
        end
        function self:_draw()
            local min,max=self:_bounds(); self.Bounds={Min=min,Max=max}
            local size=self.Plot.AbsoluteSize; local width,height=math.max(1,size.X-2),math.max(1,size.Y-2)
            local function y(value) return 1+(1-clamp((value-min)/(max-min),0,1))*height end
            for _,node in ipairs(self._grid) do node.Visible=self.ShowGrid end
            self.MinLabel.Text=format(min,options.Format or "Compact",options.Precision)
            self.MaxLabel.Text=format(max,options.Format or "Compact",options.Precision)
            if self.ChartType=="Progress" then
                local ratio=(self.Value-min)/(max-min); local node=lineNode(self._window,self.Plot,self._pool,1,self.Color)
                node.AnchorPoint=Vector2.new(0,0); node.Position=U2(0,0); node.Rotation=0
                local goals={Size=UDim2.new(ratio,0,1,0)}
                if options.Animated and self._window._animate then self._window:_animate(node,goals,.12,"chart",self) else node.Size=goals.Size end
                self.ProgressLabel.Text=format(ratio*100,"Percent",options.Precision); self.EmptyLabel.Visible=false
                return
            end
            local n=#self.Value; self.EmptyLabel.Visible=n==0
            self.FirstLabel.Text=n>0 and (self.Value[1].Label or "1") or ""
            self.LastLabel.Text=n>0 and (self.Value[n].Label or tostring(n)) or ""
            local wanted=0
            if self.ChartType=="Bar" then
                local stride=width/math.max(1,n); local zero=y(0)
                for index,p in ipairs(self.Value) do
                    wanted=index; local node=lineNode(self._window,self.Plot,self._pool,index,self.Color)
                    local topY=y(p.Value); node.AnchorPoint=Vector2.new(0,0); node.Rotation=0
                    local goals={Position=U2(1+(index-1)*stride+2,math.min(zero,topY)),Size=U2(math.max(1,stride-4),math.max(1,math.abs(zero-topY)))}
                    if options.Animated and self._window._animate then self._window:_animate(node,goals,.08,"chart",self) else for key,value in pairs(goals) do node[key]=value end end
                end
            else
                if n==1 then
                    wanted=1; local node=lineNode(self._window,self.Plot,self._pool,1,self.Color); node.Position=U2(width/2,y(self.Value[1].Value)); node.Size=U2(3,3); node.Rotation=0
                end
                for index=2,n do
                    wanted=index-1
                    lineGeometry(self._window,lineNode(self._window,self.Plot,self._pool,index-1,self.Color),
                        1+(index-2)/(n-1)*width,y(self.Value[index-1].Value),1+(index-1)/(n-1)*width,y(self.Value[index].Value),options.Thickness or 2,options.Animated,self)
                end
            end
            hideExtra(self._pool,wanted)
        end
        function self:_render() self._window:_requestVisual(self,function() self:_draw() end,self.RefreshRate) end
        function self:SetData(data,silent) return self:SetValue(data,silent) end
        function self:AddPoint(value,labelText,time)
            assert(self.ChartType~="Progress","ProgressChart uses SetValue")
            local data=self:GetValue(); data[#data+1]={Value=value,Label=labelText,Time=time}; return self:SetValue(data)
        end
        function self:Clear() return self:SetValue(self.ChartType=="Progress" and self.Min or {}) end
        function self:SetRange(min,max)
            assert(min==nil or finite(min),"Min must be finite or nil"); assert(max==nil or finite(max),"Max must be finite or nil")
            assert(min==nil or max==nil or max>min,"Max must exceed Min")
            if self.ChartType=="Progress" then assert(min~=nil and max~=nil,"Progress requires both bounds") end
            self.Min=min; self.Max=max
            if self.ChartType=="Progress" then self:SetValue(self.Value,true) else self:_render() end
            return self
        end
        function self:SetMaxPoints(value)
            assert(finite(value) and value%1==0 and value>=2 and value<=512,"MaxPoints must be 2–512")
            self.MaxPoints=value
            while #self._pool>value do local node=table.remove(self._pool); self._window:_cancelAnimations(node,false); self._window._skin[node]=nil; node:Destroy() end
            if self.ChartType~="Progress" then self:SetValue(self.Value,true) end
            return self
        end
        connect(self,self.Plot:GetPropertyChangedSignal("AbsoluteSize"),function() self:_render() end)
        local initial=kind=="Progress" and (options.Value or minimum) or (options.Data or {})
        return init(self,options,initial)
    end
    for name,kind in pairs({AddLineChart="Line",AddBarChart="Bar",AddProgressChart="Progress",AddSparkline="Sparkline"}) do
        Section[name]=function(self,options)
            local opts={}; for key,value in pairs(options or {}) do opts[key]=value end; opts.Type=kind
            return self:AddChart(opts)
        end
    end
end
-- END DASHBOARD COMPONENTS

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
    if self._cancelAnimations then self:_cancelAnimations(nil,true) end
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
    self:_syncFloating()
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
    self.ReducedMotion=value == true
    if self.ReducedMotion and self._dragRender then self:_moveWindow(self._dragRender.Target) end
    if self.ReducedMotion and self._cancelAnimations then self:_cancelAnimations(nil,true) end
    self:_syncSettings(); self:_scheduleSave(); return self
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
    self.Launcher.Visible=self.LauncherEnabled and self._shown==false
    self:_syncSettings(); self:_scheduleSave(); return self
end
function Window:SetToggleKey(value)
    self.ToggleKey=keycode(value); self:_syncSettings(); self:_scheduleSave(); return self
end
function Window:SetTitle(value)
    self.Title=tostring(value); self.TitleLabel.Text=self.Title; return self
end
function Window:SetIcon(value)
    assert(not self.Destroyed,"Window has been destroyed")
    if value==nil then value=false end
    self._titleIcon:Set(value)
    return self
end
function Window:SetPixelIcons(value)
    assert(type(value)=="boolean","PixelIcons must be a boolean")
    self.PixelIcons=value
    for handle in pairs(self._icons) do if handle.Default and handle.Spec==nil then handle:Set(nil) end end
    for _,control in pairs(self.Controls) do if control.Type=="Toggle" and control._render and not control.Destroyed then control:_render() end end
    self:_syncSettings(); self:_scheduleSave(); return self
end
function Window:SetPixelDecorations(value)
    assert(type(value)=="boolean","PixelDecorations must be a boolean")
    self.PixelDecorations=value
    if self.PixelMotif then self.PixelMotif.Visible=value and not self.Minimized end
    if self.PixelSeal then self.PixelSeal.Visible=value and not self.Mobile and (not self._logicalSize or self._logicalSize.X>=620) end
    if self.SubtitleLabel then self.SubtitleLabel.Size=UDim2.new(1,value and -94 or -28,0,22) end
    self:_syncSettings(); self:_scheduleSave(); return self
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
    local changed=self._shown==false; self._shown=true; self.Launcher.Visible=false
    if changed then self:_animateWindow(true) else self.Main.Visible=true end
    self:_layoutFloating(); return self
end
function Window:Hide()
    if self.Destroyed then return self end
    self:_cleanPolicy("CancelOnHide")
    if self._dragRender then local p=self:_clampCenter(self._dragRender.Target); self.Main.Position=U2(p.X,p.Y); self._dragRender=nil; self:_refreshRuntime() end
    self:_hideTooltip()
    self:_hideSearchResults()
    if self._dialog then self._dialog:Close("hidden") end
    self:_releaseBindings()
    self:ShowSettings(false); self:_endDrag()
    if self._binding then local binding=self._binding; self._binding=nil; binding:_render() end
    self._shown=false; self.Main.Active=false; self.Launcher.Visible=self.LauncherEnabled
    self:_animateWindow(false)
    local focused=UserInputService:GetFocusedTextBox(); local parent=focused
    while parent do if parent==self.Gui then focused:ReleaseFocus(); break end; parent=parent.Parent end
    self:_layoutFloating()
    for binding in pairs(self._keybinds) do
        if binding.Mode=="Hold" and binding.Active then binding:Trigger(false) end
    end
    return self
end
function Window:Toggle() if self._shown~=false then return self:Hide() else return self:Show() end end
function Window:Minimize(value)
    if self.Destroyed then return self end
    self:_hideTooltip()
    self:_hideSearchResults()
    local oldSize=self.Main.Size; local oldPosition=self.Main.Position
    local targetMinimized=value == nil and not self.Minimized or value == true
    if targetMinimized==self.Minimized then return self end
    local oldHeight=oldSize.Y.Offset*self._actualScale
    local nextHeight=(targetMinimized and 42 or self._logicalSize.Y)*self._actualScale
    self._position=Vector2.new(oldPosition.X.Offset,oldPosition.Y.Offset+(nextHeight-oldHeight)/2)
    self.Minimized=targetMinimized
    if self.Minimized then self:ShowSettings(false) end
    self:_layout(); local targetSize,targetPosition=self.Main.Size,self.Main.Position; self.Main.Size=oldSize; self.Main.Position=oldPosition
    self:_animate(self.Main,{Size=targetSize,Position=targetPosition},.14,"size",self); return self
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
                        local rootControl=control._inlineParent or control
                        local text=(rootControl.Title.." "..rootControl.Description.." "..rootControl.Id.." "..section.Title):lower()
                        control.Frame.Visible=control._visible and rootControl._visible and (self._query=="" or text:find(self._query,1,true)~=nil)
                        if control.Frame.Visible then visible=true end
                    end
                end
                section.Frame.Visible=section._visible and (visible or #section.Controls==0 and self._query=="")
                end
            end
        end
    end
    self:_rebuildSearchResults()
    return self
end
function Window:SearchControls(query)
    query=tostring(query or ""):lower()
    local results={}
    for _,tab in ipairs(self.Tabs) do
        if not tab.Hidden and not tab.Destroyed then
            for _,section in ipairs(tab.Sections) do
                if not section.Destroyed and section._visible~=false then
                    for _,control in ipairs(section.Controls) do
                        if not control.Destroyed and not control._internal and not control._inlineParent and control._visible and control._section._visible~=false then
                            local text=(control.Title.." "..control.Description.." "..control.Id.." "..section.Title.." "..tab.Title):lower()
                            if text:find(query,1,true) then results[#results+1]={Control=control,Tab=tab,Section=section} end
                        end
                    end
                end
            end
        end
    end
    return results
end
function Window:_hideSearchResults()
    if self.SearchResults then self.SearchResults.Visible=false end
end
function Window:_selectSearchResult(index)
    local count=#(self._searchMatches or {})
    self._searchSelection=count>0 and clamp(index,1,count) or 0
    for number,cell in ipairs(self._searchCells or {}) do
        cell.BackgroundColor3=self.Palette[number==self._searchSelection and "Accent" or "Surface"]
        cell.TextColor3=self.Palette[number==self._searchSelection and "AccentText" or "Text"]
    end
    if self.SearchResults and count>0 then self.SearchResults.CanvasPosition=Vector2.new(0,math.max(0,(self._searchSelection-3)*42)) end
end
function Window:_rebuildSearchResults()
    if not self.Search or self.Destroyed then return end
    self._searchGeneration=(self._searchGeneration or 0)+1
    if self._searchOwner then cleanup(self._searchOwner) end
    self._searchOwner={_connections={}}
    self._searchMatches={}; self._searchCells={}
    if self.SearchResults then for _,child in ipairs(self.SearchResults:GetChildren()) do child:Destroy() end end
    if self._query=="" or self._settingsOpen or self._dialog or not self.Main.Visible or self.Minimized then self:_hideSearchResults(); return end
    local matches=self:SearchControls(self._query)
    for index,entry in ipairs(matches) do if index>30 then break end; self._searchMatches[#self._searchMatches+1]=entry end
    if not self.SearchResults then
        self.SearchResults=ui(self,"ScrollingFrame",{Parent=self.Main,Name="SearchResults",BorderSizePixel=1,ZIndex=70,
            CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,
            ScrollBarThickness=4,ClipsDescendants=true},{BackgroundColor3="Surface",BorderColor3="Border",ScrollBarImageColor3="Border"})
    end
    local origin=self.Search.Position
    self.SearchResults.Position=UDim2.new(origin.X.Scale,origin.X.Offset,origin.Y.Scale,origin.Y.Offset+34)
    self.SearchResults.Size=UDim2.new(self.Search.Size.X.Scale,self.Search.Size.X.Offset,0,
        math.min(math.max(42,#self._searchMatches*42),230,math.max(42,self._logicalSize.Y-origin.Y.Offset-78)))
    list(self,self.SearchResults,2,false)
    if #self._searchMatches==0 then label(self,self.SearchResults,self:_text("empty"),{Size=UDim2.new(1,-8,0,40),ZIndex=71}) end
    for index,entry in ipairs(self._searchMatches) do
        local text=entry.Control.Title.."  ["..entry.Tab.Title.." / "..entry.Section.Title.."]"
        self._searchCells[index]=button(self,self._searchOwner,self.SearchResults,text,{LayoutOrder=index,Size=UDim2.new(1,-6,0,40),
            TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=71},function() self:FocusControl(entry.Control) end)
    end
    self.SearchResults.Visible=true; self:_selectSearchResult(1)
end
function Window:FocusControl(control)
    if type(control)=="string" then control=self.Controls[control] end
    if not control or control._window~=self or control.Destroyed or not control._visible then return false,"Control is unavailable" end
    local section=control._section._parentSection or control._section
    local tab=control._section._tab
    if tab.Hidden or control._section._visible==false then return false,"Control is hidden" end
    if section._collapsed then section:SetCollapsed(false) end
    self:Show(); self:Minimize(false)
    self.Search.Text=""; self:SetSearch(""); tab:Select(); self:_hideSearchResults()
    if UserInputService:GetFocusedTextBox()==self.Search then self.Search:ReleaseFocus() end
    local canvas=tab.Frame.CanvasPosition or Vector2.new(0,0)
    local y=canvas.Y+(control.Frame.AbsolutePosition.Y-tab.Frame.AbsolutePosition.Y)/math.max(.1,self._actualScale)
    tab.Frame.CanvasPosition=Vector2.new(0,math.max(0,y-12))
    if control._focusBorder==nil then control._focusBorder=control.Frame.BorderSizePixel end
    control.Frame.BorderColor3=self.Palette.Accent; control.Frame.BorderSizePixel=1
    control._focusToken=(control._focusToken or 0)+1; local token=control._focusToken
    task.delay(1.5,function() if not control.Destroyed and control._focusToken==token then control.Frame.BorderSizePixel=control._focusBorder; control._focusBorder=nil end end)
    return true
end

function Tab:_renderSelection()
    if not self.Button then return end
    local active=self._window.ActiveTab==self
    self.Button.BackgroundColor3=self._window.Palette[active and "Accent" or "Surface"]
    self.Button.TextColor3=self._window.Palette[active and "AccentText" or "Text"]
    if self.Label then self.Label.TextColor3=self.Button.TextColor3 end
    if self._titleIcon then self._titleIcon:SetRole(active and "AccentText" or "Text") end
end
function Tab:SetIcon(value)
    assert(not self.Destroyed,"Tab has been destroyed")
    if value==nil then value=false end
    self._titleIcon:Set(value); self:_renderSelection(); return self
end
function Tab:SetTitle(value)
    assert(not self.Destroyed,"Tab has been destroyed")
    self.Title=tostring(value); self.Label.Text=self.Title
    if self._window.ActiveTab==self then self._window.Status.Text=self.Title.."  |  v"..Library.Version end
    self._window:SetSearch(self._window._query); return self
end
function Tab:Select()
    assert(not self.Destroyed,"Tab has been destroyed")
    if self.Hidden then return self end
    local window=self._window
    window:_hideTooltip()
    window:_hideSearchResults()
    if self._settingsConfig then window:_releaseBindings() end
    window._settingsOpen=self._settingsConfig==true
    if not self._settingsConfig then window._lastContentTab=self end
    window.ActiveTab=self
    if self.Frame.Visible==false then
        self.Container.Position=U2(0,4)
        window:_animate(self.Container,{Position=U2(0,0)},.1,"tab",self)
    end
    if window._openDropdown then window._openDropdown:SetOpen(false) end
    for _,tab in ipairs(window.Tabs) do if not tab.Hidden then tab.Frame.Visible=tab==self end; tab:_renderSelection() end
    window.Status.Text=self.Title.."  |  v"..Library.Version
    if self._settingsConfig then window:_syncSettings(); window:_refreshProfiles() end
    window:_layoutFloating()
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
    resolveIcon(options.Icon)
    local selfTab=setmetatable({ Title=tostring(options.Title or "Tab"),Columns=options.Columns or 1,Hidden=options.Hidden==true,
        _internal=options.Internal==true,_window=self,_connections={},Sections={},_sectionCount=0 },Tab)
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
    selfTab.Button=button(self,selfTab,self.Nav,"",{
        LayoutOrder=#self.Tabs+1,Size=U2(158,34),TextXAlignment=Enum.TextXAlignment.Left,TextSize=13,Visible=not selfTab.Hidden,
        TextTruncate=Enum.TextTruncate.AtEnd,
    },function() selfTab:Select() end)
    selfTab.Label=label(self,selfTab.Button,selfTab.Title,{Size=UDim2.new(1,-14,1,0),Position=U2(8,0),TextSize=13,TextTruncate=Enum.TextTruncate.AtEnd})
    selfTab._titleIcon=iconSlot(self,selfTab.Button,options.Icon,selfTab._internal and "settings" or "grid",24,U2(4,5),"Text",function(visible)
        selfTab.Label.Position=U2(visible and 34 or 8,0)
        selfTab.Label.Size=UDim2.new(1,visible and -40 or -14,1,0)
    end)
    selfTab.Icon=selfTab._titleIcon.Frame
    table.insert(self.Tabs,selfTab)
    connect(selfTab,selfTab.Frame:GetPropertyChangedSignal("AbsoluteSize"),function() selfTab:_layout() end)
    connect(selfTab,selfTab.Frame.Destroying,function() if not selfTab.Destroyed then selfTab:Destroy() end end)
    selfTab:_layout(); self:_layout()
    if not self.ActiveTab and not selfTab.Hidden and not selfTab._internal then selfTab:Select() end
    return selfTab
end
function Tab:CreateSection(options)
    if type(options)=="string" then options={ Title=options } end
    options=options or {}
    assert(not self.Destroyed,"Tab has been destroyed")
    resolveIcon(options.Icon)
    self._sectionCount=self._sectionCount+1
    local section=setmetatable({ Title=tostring(options.Title or "Section"),_window=self._window,_tab=self,_connections={},Controls={},_count=0,_visible=options.Visible~=false,Collapsible=options.Collapsible==true,_collapsed=false },Section)
    if options.Side=="Right" then self.Columns=2 end
    section.Frame=frame(self._window,options.Side=="Right" and self.Right or self.Left,{
        Name=section.Title,LayoutOrder=self._sectionCount,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BorderSizePixel=1,Visible=section._visible,
    },"Surface")
    self._window:_bind(section.Frame,{ BackgroundColor3="Surface",BorderColor3="Border" })
    local padding=ui(self._window,"UIPadding",{ Parent=section.Frame,PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,12) })
    list(self._window,section.Frame,8)
    section.HeaderRow=frame(self._window,section.Frame,{LayoutOrder=1,Size=UDim2.new(1,0,0,24),BackgroundTransparency=1})
    section.Header=label(self._window,section.HeaderRow,section.Title:upper(),{Size=UDim2.new(1,0,1,0),TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd},"Muted")
    section._titleIcon=iconSlot(self._window,section.HeaderRow,options.Icon,"folder",18,U2(0,3),"Muted",function(visible)
        section.Header.Position=U2(visible and 24 or 0,0)
        section.Header.Size=UDim2.new(1,(visible and -24 or 0)-(section.Collapsible and 22 or 0),1,0)
    end)
    section.Icon=section._titleIcon.Frame
    section.Content=frame(self._window,section.Frame,{ LayoutOrder=2,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1 })
    section.ContentLayout=list(self._window,section.Content,10)
    if section.Collapsible then
        section._collapseIcon=iconSlot(self._window,section.HeaderRow,"chevron-down",nil,12,UDim2.new(1,-14,.5,-6),"Muted")
        local target=ui(self._window,"TextButton",{Parent=section.HeaderRow,Size=UDim2.fromScale(1,1),Text="",BackgroundTransparency=1,AutoButtonColor=false,ZIndex=section.HeaderRow.ZIndex+4})
        connect(section,target.Activated,function() if not section.Destroyed and section._window._shown~=false and not section._window._dialog then section:SetCollapsed(not section._collapsed) end end)
        section.CollapseButton=target
    end
    table.insert(self.Sections,section)
    connect(section,section.Frame.Destroying,function() if not section.Destroyed then section:Destroy() end end)
    self:_layout()
    if section.Collapsible and options.Collapsed then section:SetCollapsed(true,true) end
    return section
end
function Section:CreateRow(options)
    options=options or {}
    assert(not self._isRow,"Rows cannot be nested")
    assert(not self.Destroyed and not self._window.Destroyed,"Section has been destroyed")
    local gap=options.Gap or 10; local stackAt=options.StackAt or 440
    assert(finite(gap) and gap>=0 and gap<=32,"Row Gap must be 0–32")
    assert(finite(stackAt) and stackAt>=200 and stackAt<=1000,"Row StackAt must be 200–1000")
    self._count=self._count+1
    local row=setmetatable({_isRow=true,_parentSection=self,_window=self._window,_tab=self._tab,
        Title=self.Title,Controls={},_connections={},_count=0,Gap=gap,StackAt=stackAt},Row)
    row.Frame=frame(self._window,self.Content,{LayoutOrder=self._count,Size=UDim2.new(1,0,0,1),BackgroundTransparency=1})
    row.Content=row.Frame
    row.Layout=list(self._window,row.Frame,gap,true)
    self.Rows=self.Rows or {}; self.Rows[#self.Rows+1]=row
    connect(row,row.Frame:GetPropertyChangedSignal("AbsoluteSize"),function() row:_layout() end)
    connect(row,row.Frame.Destroying,function() if not row.Destroyed then row:Destroy() end end)
    return row
end
function Row:_layout()
    if self.Destroyed or self._layingOut then return end
    self._layingOut=true
    local visible={}; local maximum=0; local total=0
    for _,control in ipairs(self.Controls) do
        if not control.Destroyed and not control._inlineParent and control.Frame.Visible then
            visible[#visible+1]=control; maximum=math.max(maximum,control._rowHeight or 30); total=total+(control._rowHeight or 30)
        end
    end
    local count=#visible
    self.Stacked=self.Frame.AbsoluteSize.X<self.StackAt or count>3
    self.Layout.FillDirection=self.Stacked and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
    self.Frame.Size=UDim2.new(1,0,0,count==0 and 0 or self.Stacked and total+self.Gap*(count-1) or maximum)
    for _,control in ipairs(visible) do
        control.Frame.Size=UDim2.new(self.Stacked and 1 or 1/count,self.Stacked and 0 or -self.Gap*(count-1)/count,0,self.Stacked and control._rowHeight or maximum)
    end
    self._layingOut=false
end
function Row:Destroy()
    if self.Destroyed then return end
    self.Destroyed=true
    local controls={table.unpack(self.Controls)}
    for _,control in ipairs(controls) do control:Destroy() end
    cleanup(self); self.Frame:Destroy()
    local index=table.find(self._parentSection.Rows or {},self); if index then table.remove(self._parentSection.Rows,index) end
end
function Row:SetVisible(value)
    self._visible=value~=false; self.Frame.Visible=self._visible; self._window:SetSearch(self._window._query); return self
end
function Section:SetTitle(value) self.Title=tostring(value); self.Header.Text=self.Title:upper(); return self end
function Section:SetCollapsed(value,instant)
    assert(not self.Destroyed and not self._isRow,"SetCollapsed needs a live Section")
    assert(type(value)=="boolean","Collapsed must be boolean")
    if not self.Collapsible then self.Collapsible=true end
    self._collapsed=value
    if self._collapseIcon then self._collapseIcon:Set(value and "chevron-right" or "chevron-down") end
    local old=self.Content.AbsoluteSize.Y
    self._window:_cancelTrack(self.Content,"collapse",false)
    self.Content.AutomaticSize=Enum.AutomaticSize.None; self.Content.ClipsDescendants=true; self.Content.Visible=true
    self.Content.Size=UDim2.new(1,0,0,old)
    local target=value and 0 or self.ContentLayout.AbsoluteContentSize.Y
    self._window:_animate(self.Content,{Size=UDim2.new(1,0,0,target)},instant and 0 or .14,"collapse",self,function()
        if self.Destroyed then return end
        self.Content.Visible=not self._collapsed
        self.Content.AutomaticSize=self._collapsed and Enum.AutomaticSize.None or Enum.AutomaticSize.Y
        if not self._collapsed then self.Content.Size=UDim2.new(1,0,0,0) end
    end)
    self._window:_hideTooltip(); return self
end
function Section:IsCollapsed() return self._collapsed==true end
function Section:SetIcon(value)
    assert(not self.Destroyed and not self._isRow,"SetIcon requires a live Section")
    if value==nil then value=false end
    self._titleIcon:Set(value); return self
end
function Section:SetVisible(value) self._visible=value~=false; self._window:SetSearch(self._window._query); return self end
function Section:Destroy()
    if self.Destroyed then return end
    self.Destroyed=true
    self._window:_cancelAnimations(self.Frame,false)
    for _,row in ipairs({table.unpack(self.Rows or {})}) do row:Destroy() end
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
            Notifications=self.NotificationsEnabled,Launcher=self.LauncherEnabled,ToggleKey=self.ToggleKey.Name,
            PixelIcons=self.PixelIcons,PixelDecorations=self.PixelDecorations,
            Animations=copy(self.Animations),Drag={Smooth=self.SmoothDragging,Responsiveness=self.DragResponsiveness} },
    }
    result.Appearance.Floating={Enabled=self.QuickActionsEnabled,Size=self.FloatSize,Opacity=self.FloatOpacity,Positions={}}
    for id,position in pairs(self._floatingPositions) do result.Appearance.Floating.Positions[id]={X=position.X,Y=position.Y} end
    result.Appearance.LauncherText=self.LauncherText
    result.Appearance.LauncherPosition={X=self.LauncherPosition.X,Y=self.LauncherPosition.Y}
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
            PixelIcons=look.PixelIcons,PixelDecorations=look.PixelDecorations,
            ToggleKey=self.ToggleKey }
        appearance.Animations=Library._animationSettings(look.Animations,self.Animations)
        if look.Drag~=nil then
            assert(type(look.Drag)=="table" and type(look.Drag.Smooth)=="boolean" and finite(look.Drag.Responsiveness) and look.Drag.Responsiveness>=8 and look.Drag.Responsiveness<=80,"Invalid Drag preference")
            appearance.Drag=copy(look.Drag)
        end
        if look.Theme~=nil then appearance.Theme=look.Theme end
        if look.Scale~=nil then appearance.Scale=look.Scale end
        if look.ToggleKey~=nil then appearance.ToggleKey=keycode(look.ToggleKey) end
        if config.Appearance==nil then appearance.Accent=self.Accent end
        assert(type(appearance.Theme)=="string" and #appearance.Theme>0,"Invalid theme name")
        assert(finite(appearance.Scale) and appearance.Scale>=.75 and appearance.Scale<=1.5,"Invalid interface scale")
        for _,key in ipairs({"ReducedMotion","Scanlines","Notifications","Launcher","PixelIcons","PixelDecorations"}) do
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
        if look.LauncherText~=nil then
            assert(type(look.LauncherText)=="string" and #look.LauncherText>=1 and #look.LauncherText<=16,"Invalid launcher text")
            appearance.LauncherText=look.LauncherText
        end
        local function position(value)
            assert(type(value)=="table" and finite(value.X) and finite(value.Y) and value.X>=0 and value.X<=1 and value.Y>=0 and value.Y<=1,"Invalid floating position")
            return Vector2.new(value.X,value.Y)
        end
        if look.LauncherPosition~=nil then appearance.LauncherPosition=position(look.LauncherPosition) end
        if look.Floating~=nil then
            local floating=look.Floating
            assert(type(floating)=="table" and type(floating.Enabled)=="boolean" and finite(floating.Size) and floating.Size>=44 and floating.Size<=96
                and finite(floating.Opacity) and floating.Opacity>=.2 and floating.Opacity<=1 and type(floating.Positions)=="table","Invalid floating appearance")
            appearance.Floating={Enabled=floating.Enabled,Size=floating.Size,Opacity=floating.Opacity,Positions={}}
            local count=0
            for id,p in pairs(floating.Positions) do
                count=count+1; assert(count<=256 and type(id)=="string" and #id>=1 and #id<=128,"Invalid floating Id")
                appearance.Floating.Positions[id]=position(p)
            end
        end
        return { Changes=changes,Appearance=appearance }
    end)
    if not ok then return false,tostring(prepared) end
    self._importing=true
    for _,control in pairs(self.Controls) do control._callbackEpoch=(control._callbackEpoch or 0)+1 end
    local previousSync,previousSuppress=self._syncCallbacks,self._suppressCallbacks
    self._syncCallbacks=true; self._suppressCallbacks=options.Silent==true
    self:_releaseBindings()
    self._syncCallbacks=previousSync; self._suppressCallbacks=previousSuppress
    if self.Destroyed then self._importing=false; return false,"Window was destroyed during a callback" end
    local look=prepared.Appearance
    Library:Batch(function()
    if look.Colors then self._themeOverrides[look.Theme]=look.Colors end
    self.Theme=look.Theme; self.Accent=look.Accent; self.UserScale=look.Scale; self.ToggleKey=look.ToggleKey
    if look.ReducedMotion~=nil then self.ReducedMotion=look.ReducedMotion end
    if look.Scanlines~=nil then self.Scanlines=look.Scanlines end
    if look.Notifications~=nil then self.NotificationsEnabled=look.Notifications end
    if look.Launcher~=nil then self.LauncherEnabled=look.Launcher end
    if look.PixelIcons~=nil then self.PixelIcons=look.PixelIcons end
    if look.PixelDecorations~=nil then self.PixelDecorations=look.PixelDecorations end
    self:SetAnimations(look.Animations)
    if look.Drag then self:SetDragOptions(look.Drag) end
    if look.LauncherText then self.LauncherText=look.LauncherText end
    if look.LauncherPosition then self.LauncherPosition=look.LauncherPosition end
    if look.Floating then
        self.QuickActionsEnabled=look.Floating.Enabled; self.FloatSize=look.Floating.Size; self.FloatOpacity=look.Floating.Opacity
        self._floatingPositions=look.Floating.Positions
    end
    for id,record in pairs(prepared.Changes) do self.Controls[id]:SetValue(record.Value,true) end
    self:_applyTheme(); self:_layout()
    self:SetScanlines(self.Scanlines); self:SetLauncher(self.LauncherEnabled)
    self:SetPixelIcons(self.PixelIcons); self:SetPixelDecorations(self.PixelDecorations)
    end)
    if not options.Silent then for id in pairs(prepared.Changes) do
        local control=self.Controls[id]; if control and not self.Destroyed then control:_emit() end
    end end
    self._importing=false; self:_scheduleSave()
    if self.Destroyed then return false,"Window was destroyed during a callback" end
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
        MakeFolder=type(makefolder)=="function",IsFile=type(isfile)=="function",IsFolder=type(isfolder)=="function",ListFiles=type(listfiles)=="function",
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
    local enumerate=type(listfiles)=="function" and listfiles or nil
    local function ensureFolders()
        local path=""
        for segment in folder:gmatch("[^/]+") do
            path=path=="" and segment or path.."/"..segment
            if not hasFolder or not hasFolder(path) then mkdir(path) end
        end
    end
    local function path(name) return folder.."/profile-"..filePart(profileName(name))..".json" end
    local indexPath=folder.."/profiles-index.json"
    local function readIndex()
        if hasFile and not hasFile(indexPath) then return {} end
        local ok,text=pcall(read,indexPath)
        if not ok then
            if hasFile then error(text) end
            return {} -- Without isfile, an absent index raises through readfile.
        end
        assert(type(text)=="string" and #text<=65536,"Profile index exceeds its limit")
        local data=HttpService:JSONDecode(text)
        assert(type(data)=="table" and data.Schema==1 and type(data.Names)=="table" and #data.Names<=256,"Invalid profile index")
        local result,seen={},{}
        for _,name in ipairs(data.Names) do
            profileName(name)
            if not seen[name] then result[#result+1]=name; seen[name]=true end
        end
        return result
    end
    local function discovered()
        local result=readIndex(); local seen={}
        for _,name in ipairs(result) do seen[name]=true end
        if enumerate then
            local ok,files=pcall(enumerate,folder)
            if ok and type(files)=="table" then
                for index,file in ipairs(files) do
                    if index>4096 then break end
                    if type(file)=="string" then
                        local encoded=file:gsub("\\","/"):match("/profile%-(.-)%.json$")
                        if encoded then
                            local name=encoded:gsub("%%(%x%x)",function(byte) return string.char(tonumber(byte,16)) end)
                            if pcall(profileName,name) and filePart(name)==encoded and not seen[name] and #result<256 then
                                result[#result+1]=name; seen[name]=true
                            end
                        end
                    end
                end
            end
        end
        local existing={}
        for _,name in ipairs(result) do if not hasFile or hasFile(path(name)) then existing[#existing+1]=name end end
        table.sort(existing); return existing
    end
    return {
        Kind="file",Folder=folder,
        Save=function(name,json)
            assert(type(json)=="string","Storage expects JSON text")
            profileName(name)
            local known=discovered(); local fresh=not table.find(known,name)
            assert(not fresh or #known<256,"Profile limit is 256")
            local target=path(name); ensureFolders()
            local result=write(target,json)
            assert(result~=false,"Executor refused to write the profile")
            if fresh then
                known[#known+1]=name; table.sort(known)
                local indexed=write(indexPath,HttpService:JSONEncode({Schema=1,Names=known}))
                assert(indexed~=false,"Profile saved, but the executor refused its index")
            end
            return true
        end,
        Load=function(name)
            local target=path(name)
            if hasFile and not hasFile(target) then return nil,"Profile was not found" end
            return read(target)
        end,
        List=discovered,
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
        self.LastConfigName=name
        return json
    end)
    if ok and self._refreshProfiles then self:_refreshProfiles() end
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
    local applied,err=self:ImportConfig(data,options)
    if applied then self.LastConfigName=name; self._profiles[name]=type(data)=="string" and data or HttpService:JSONEncode(data) end
    return applied,err
end
function Window:GetConfigNames()
    local result,seen={},{}
    if self.Storage and type(self.Storage.List)=="function" then
        local ok,listed=pcall(self.Storage.List)
        if not ok then return {},tostring(listed) end
        if type(listed)~="table" then return {},"Storage.List must return an array" end
        for _,name in ipairs(listed) do
            if not pcall(profileName,name) then return {},"Storage.List returned an invalid profile name" end
            if not seen[name] then seen[name]=true; result[#result+1]=name end
        end
    end
    for name in pairs(self._profiles) do if not seen[name] then result[#result+1]=name end end
    table.sort(result); return result
end
function Window:Reset(silent)
    self._importing=true
    for _,control in pairs(self.Controls) do control._callbackEpoch=(control._callbackEpoch or 0)+1 end
    local previousSync,previousSuppress=self._syncCallbacks,self._suppressCallbacks
    self._syncCallbacks=true; self._suppressCallbacks=silent==true; self:_releaseBindings()
    self._syncCallbacks=previousSync; self._suppressCallbacks=previousSuppress
    if self.Destroyed then self._importing=false; return self end
    Library:Batch(function()
    for _,control in pairs(self.Controls) do if control.Persist and control._hasDefault then control:SetValue(control._default,true) end end
    self.Theme=self._initial.Theme; self.Accent=self._initial.Accent; self.UserScale=self._initial.Scale
    self._themeOverrides[self._initial.Theme]=copy(self._initial.ThemeColors)
    self.ReducedMotion=self._initial.ReducedMotion; self.Scanlines=self._initial.Scanlines
    self.NotificationsEnabled=self._initial.Notifications; self.LauncherEnabled=self._initial.Launcher
    self.PixelIcons=self._initial.PixelIcons; self.PixelDecorations=self._initial.PixelDecorations
    self:SetAnimations(copy(self._initial.Animations))
    self:SetDragOptions({Smooth=self._initial.SmoothDragging,Responsiveness=self._initial.DragResponsiveness})
    self.ToggleKey=self._initial.ToggleKey
    self.FloatSize=self._initial.FloatSize; self.FloatOpacity=self._initial.FloatOpacity; self.QuickActionsEnabled=self._initial.QuickActions
    self.LauncherText=self._initial.LauncherText; self.LauncherPosition=self._initial.LauncherPosition; self._floatingPositions={}
    for _,floating in pairs(self._floatingButtons) do floating.Position=floating._defaultPosition end
    self:_applyTheme(); self:_layout(); self:SetScanlines(self.Scanlines); self:SetLauncher(self.LauncherEnabled)
    self:SetPixelIcons(self.PixelIcons); self:SetPixelDecorations(self.PixelDecorations)
    end)
    if not silent then for _,control in pairs(self.Controls) do if control.Persist then control:_emit() end end end
    self._importing=false; self:_scheduleSave(); return self
end

function Window:_layout()
    if self.Destroyed or not self.Main then return end
    self:_cancelTrack(self.Main,"size",false)
    self:_cancelTrack(self.Main,"window",false)
    if self.ScaleObject then self:_cancelTrack(self.ScaleObject,"window",false) end
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
    if self._searchIcon then
        local p=self.Search.Position
        self._searchIcon.Frame.Position=UDim2.new(p.X.Scale,p.X.Offset+7,p.Y.Scale,p.Y.Offset+7)
    end
    if self.PixelMotif then self.PixelMotif.Visible=self.PixelDecorations and not self.Minimized end
    if self.PixelSeal then self.PixelSeal.Visible=self.PixelDecorations and not self.Mobile and width>=620 end
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
    self:_layoutFloating()
    if self._dialog then self._dialog:_layout() end
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
    controls.PixelIcons:SetValue(self.PixelIcons,true)
    controls.PixelDecorations:SetValue(self.PixelDecorations,true)
    if controls.Animations then
        controls.Animations:SetValue(self.Animations.Enabled,true)
        controls.AnimationSpeed:SetValue(self.Animations.Speed,true)
        controls.AnimationIntensity:SetValue(self:_text("intensity"..self.Animations.Intensity),true)
        controls.SmoothDragging:SetValue(self.SmoothDragging,true)
    end
    controls.Notifications:SetValue(self.NotificationsEnabled,true)
    controls.Launcher:SetValue(self.LauncherEnabled,true)
    controls.Shortcut:SetValue(self.ToggleKey,true)
    controls.LauncherText:SetValue(self.LauncherText,true)
    controls.QuickActions:SetValue(self.QuickActionsEnabled,true)
    controls.FloatSize:SetValue(self.FloatSize,true)
    controls.FloatOpacity:SetValue(self.FloatOpacity,true)
    self._syncingSettings=false
end
function Window:_refreshProfiles()
    local controls=self._settingsControls
    if not controls or self._refreshingProfiles then return end
    self._refreshingProfiles=true
    local known,err=self:GetConfigNames()
    controls.Profiles:SetOptions(known,true)
    local selected=controls.Profiles:GetValue()
    if not selected then controls.Profiles:SetValue(known[1],true) end
    controls.Load:SetDisabled(err~=nil)
    controls.ProfileStatus:SetText(err or self:_text(self.StorageMode=="file" and "fileProfiles" or "memoryProfiles"))
    self._refreshingProfiles=false
    return known,err
end
function Window:_createSettings()
    if self._settingsTab then return end
    local tab=self:CreateTab({Title=self:_text("settings"),Internal=true})
    tab._settingsConfig=true; tab.Button.LayoutOrder=100000
    self._settingsTab=tab
    local function opts(id,title,extra)
        local result={Id="__retrobox/"..id,Title=title,Internal=true,Persist=false}
        for k,v in pairs(extra or {}) do result[k]=v end
        return result
    end
    local controls={}; self._settingsControls=controls
    local configs=tab:CreateSection(self:_text("configs"))
    controls.ProfileStatus=configs:AddLabel(opts("config-status","",{Default=self:_text("memoryProfiles"),Height=42}))
    local profile=configs:AddInput(opts("config-name",self:_text("profile"),{Default="default",MaxLength=64}))
    controls.ProfileName=profile
    controls.Profiles=configs:AddDropdown(opts("config-list",self:_text("profiles"),{Options={},Searchable=true,
        Callback=function(value) if value then profile:SetValue(value,true) end end}))
    local actions=configs:CreateRow()
    actions:AddButton(opts("config-save",self:_text("save"),{Callback=function()
        local name=profile.Input.Text
        local valid,reason=pcall(profileName,name)
        if not valid then self:Notify({Title=self:_text("error"),Content=reason,Kind="error"}); return end
        local known,err=self:GetConfigNames()
        if err then self:Notify({Title=self:_text("error"),Content=err,Kind="error"}); return end
        local function save()
            local ok,result=self:SaveConfig(name)
            if ok then controls.Profiles:SetValue(name,true); profile:SetValue(name,true) end
            self:Notify({Title=self:_text(ok and "saved" or "error"),Content=ok and name or result,Kind=ok and "success" or "error"})
        end
        if table.find(known,name) then self:Confirm({Title=self:_text("overwrite"),Content=name,OnConfirm=save}) else save() end
    end}))
    controls.Load=actions:AddButton(opts("config-load",self:_text("load"),{Callback=function()
        local name=controls.Profiles:GetValue() or profile.Input.Text
        if not name then self:Notify({Title=self:_text("error"),Content=self:_text("empty"),Kind="error"}); return end
        local ok,result=self:LoadConfig(name)
        self:Notify({Title=self:_text(ok and "loaded" or "error"),Content=ok and name or result,Kind=ok and "success" or "error"})
    end}))
    configs:AddButton(opts("config-refresh",self:_text("refresh"),{Callback=function()
        local _,err=self:_refreshProfiles()
        if err then self:Notify({Title=self:_text("error"),Content=err,Kind="error"}) end
    end}))
    local transfer=tab:CreateSection("JSON")
    local json=transfer:AddInput(opts("config-json","JSON",{Default="",Multiline=true,MaxLength=self.MaxConfigBytes}))
    local transfers=transfer:CreateRow()
    transfers:AddButton(opts("config-export",self:_text("export"),{Callback=function() json:SetValue(self:ExportConfig(),true); json.Input:CaptureFocus() end}))
    transfers:AddButton(opts("config-import",self:_text("import"),{Callback=function()
        local ok,result=self:ImportConfig(json.Input.Text)
        self:Notify({Title=self:_text(ok and "loaded" or "error"),Content=ok and self:_text("ready") or result,Kind=ok and "success" or "error"})
    end}))
    local look=tab:CreateSection(self:_text("appearance"))
    controls.Theme=look:AddDropdown(opts("theme",self:_text("theme"),{Options=self:GetThemeNames(),Default=self.Theme,Callback=function(value) self:SetTheme(value) end}))
    controls.PixelIcons=look:AddToggle(opts("pixel-icons",self:_text("pixelIcons"),{Default=self.PixelIcons,Callback=function(v) self:SetPixelIcons(v) end}))
    controls.PixelDecorations=look:AddToggle(opts("pixel-decorations",self:_text("pixelDecorations"),{Default=self.PixelDecorations,Callback=function(v) self:SetPixelDecorations(v) end}))
    controls.Animations=look:AddToggle(opts("animations",self:_text("animations"),{Default=self.Animations.Enabled,Callback=function(v) self:SetAnimations({Enabled=v}) end}))
    controls.AnimationSpeed=look:AddSlider(opts("animation-speed",self:_text("animationSpeed"),{Min=.25,Max=4,Step=.05,Default=self.Animations.Speed,Callback=function(v) self:SetAnimations({Speed=v}) end}))
    controls.AnimationIntensity=look:AddDropdown(opts("animation-intensity",self:_text("animationIntensity"),{Options={self:_text("intensitySubtle"),self:_text("intensityNormal"),self:_text("intensityOff")},Default=self:_text("intensity"..self.Animations.Intensity),Callback=function(v)
        for _,kind in ipairs({"Subtle","Normal","Off"}) do if v==self:_text("intensity"..kind) then self:SetAnimations({Intensity=kind}); break end end
    end}))
    controls.SmoothDragging=look:AddToggle(opts("smooth-drag",self:_text("smoothDragging"),{Default=self.SmoothDragging,Callback=function(v) self:SetDragOptions({Smooth=v}) end}))
    controls.Accent=look:AddColorPicker(opts("accent",self:_text("accent"),{Default=self.Palette.Accent,AllowRainbow=false,AllowOpacity=false,Callback=function(color) self:SetAccent(color) end}))
    local access=tab:CreateSection(self:_text("accessibility"))
    controls.Scale=access:AddSlider(opts("scale",self:_text("scale"),{Min=.75,Max=1.5,Step=.05,Default=self.UserScale,Suffix="x",Callback=function(value) self:SetScale(value) end}))
    controls.Motion=access:AddToggle(opts("motion",self:_text("motion"),{Default=self.ReducedMotion,Callback=function(v) self:SetReducedMotion(v) end}))
    controls.Scanlines=access:AddToggle(opts("scanlines",self:_text("lines"),{Default=self.Scanlines,Callback=function(v) self:SetScanlines(v) end}))
    controls.Notifications=access:AddToggle(opts("notices",self:_text("notices"),{Default=self.NotificationsEnabled,Callback=function(v) self:SetNotifications(v) end}))
    controls.Launcher=access:AddToggle(opts("launcher",self:_text("launcher"),{Default=self.LauncherEnabled,Callback=function(v) self:SetLauncher(v) end}))
    controls.LauncherText=access:AddInput(opts("launcher-text",self:_text("launcherText"),{Default=self.LauncherText,MaxLength=16,
        Validate=function(value) return #value>0 end,Callback=function(value) self:SetLauncherOptions({Text=value}) end}))
    controls.Shortcut=access:AddKeybind(opts("shortcut",self:_text("shortcut"),{Default=self.ToggleKey,CaptureOnly=true,AllowMouse=false}))
    controls.Shortcut:OnChanged(function(value) self:SetToggleKey(value) end)
    local floats=tab:CreateSection(self:_text("quickActions"))
    controls.QuickActions=floats:AddToggle(opts("quick-actions",self:_text("quickActions"),{Default=self.QuickActionsEnabled,Callback=function(value) self:SetFloatingOptions({Enabled=value}) end}))
    controls.FloatSize=floats:AddSlider(opts("float-size",self:_text("floatSize"),{Min=44,Max=96,Default=self.FloatSize,Callback=function(value) self:SetFloatingOptions({Size=value}) end}))
    controls.FloatOpacity=floats:AddSlider(opts("float-opacity",self:_text("floatOpacity"),{Min=.2,Max=1,Step=.05,Default=self.FloatOpacity,Callback=function(value) self:SetFloatingOptions({Opacity=value}) end}))
    access:AddButton(opts("config-reset",self:_text("reset"),{Callback=function()
        self:Confirm({Title=self:_text("reset"),Content=self:_text("confirm"),Kind="danger",OnConfirm=function() self:Reset() end})
    end}))
    self:_syncSettings(); self:_refreshProfiles()
end
function Window:ShowSettings(value)
    if not self.SettingsEnabled or self.Destroyed then return self end
    if not self._settingsTab then self:_createSettings() end
    if value==nil then value=not self._settingsOpen end
    self:_hideTooltip(); self:_hideSearchResults()
    if value then
        if self.ActiveTab and self.ActiveTab~=self._settingsTab then self._lastContentTab=self.ActiveTab end
        self:_syncSettings(); self:_refreshProfiles(); self._settingsTab:Select()
    elseif self.ActiveTab==self._settingsTab then
        local previous=self._lastContentTab
        if previous and not previous.Destroyed then previous:Select()
        else for _,tab in ipairs(self.Tabs) do if tab~=self._settingsTab and not tab.Hidden then tab:Select(); break end end end
    end
    return self
end

function Window:Notify(options)
    if type(options)=="string" then options={ Content=options } end
    options=options or {}
    if self.Destroyed or not self.NotificationsEnabled then return nil end
    resolveIcon(options.Icon)
    local duration=options.Duration or 4
    assert(finite(duration),"Notification Duration must be finite")
    duration=clamp(duration,.1,30)
    while #self._notifications>=4 do self._notifications[1]:Destroy(true) end
    self._noticeCount=self._noticeCount+1
    local width=math.min(340,math.max(220,self.Root.AbsoluteSize.X-32))
    local notification={ _window=self,_connections={},Destroyed=false }
    notification.Frame=frame(self,self.NotificationHost,{ LayoutOrder=-self._noticeCount,Size=U2(width,82),
        BorderSizePixel=1,ZIndex=80,ClipsDescendants=true },"Surface")
    self:_bind(notification.Frame,{ BackgroundColor3="Surface",BorderColor3="Border" }); bevel(self,notification.Frame,false)
    local role=options.Kind=="error" and "Danger" or options.Kind=="success" and "Success" or "Accent"
    frame(self,notification.Frame,{ Position=U2(0,0),Size=UDim2.new(0,4,1,0) },role)
    local title=label(self,notification.Frame,options.Title or self:_text("about"),{
        Position=U2(12,8),Size=UDim2.new(1,-48,0,22),TextSize=13,TextTruncate=Enum.TextTruncate.AtEnd,
    })
    local defaultIcon=options.Kind=="error" and "error" or options.Kind=="success" and "success" or options.Kind=="warning" and "warning" or options.Kind=="loading" and "refresh" or "info"
    notification._titleIcon=iconSlot(self,notification.Frame,options.Icon,defaultIcon,16,U2(12,11),"Text",function(visible)
        title.Position=U2(visible and 34 or 12,8); title.Size=UDim2.new(1,visible and -70 or -48,0,22)
    end)
    notification.Icon=notification._titleIcon.Frame
    label(self,notification.Frame,options.Content or "",{
        Position=U2(12,32),Size=UDim2.new(1,-24,0,42),TextSize=12,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,
    },"Muted")
    function notification:_remove()
        self._window:_cancelAnimations(self.Frame,false)
        cleanup(self); self.Frame:Destroy()
        local index=table.find(self._window._notifications,self)
        if index then table.remove(self._window._notifications,index) end
    end
    function notification:Destroy(immediate)
        if self.Destroyed then if immediate then self:_remove() end; return end
        self.Destroyed=true; cleanup(self); self._window:_cancelAnimations(self.Frame,false)
        if immediate or self._window.Destroyed or self._window._closing then self:_remove()
        else self._window:_animate(self.Frame,{Size=U2(width,0),BackgroundTransparency=1},.12,"notice",self,function() self:_remove() end) end
    end
    pixelButton(self,notification,notification.Frame,"X","close",{ Position=UDim2.new(1,-32,0,8),Size=U2(22,22),TextSize=12 },function() notification:Destroy() end)
    table.insert(self._notifications,notification)
    notification.Frame.BackgroundTransparency=.4; notification.Frame.Size=U2(width,4)
    self:_animate(notification.Frame,{BackgroundTransparency=0,Size=U2(width,82)},.14,"notice",notification)
    task.delay(duration,function() notification:Destroy() end)
    return notification
end

local function normalizedPosition(value)
    assert(typeof(value)=="Vector2" and finite(value.X) and finite(value.Y) and value.X>=0 and value.X<=1 and value.Y>=0 and value.Y<=1,
        "Position must be a Vector2 with coordinates between 0 and 1")
    return Vector2.new(value.X,value.Y)
end
function Window:_layoutFloating()
    if not self.Root then return end
    local view=self.Root.AbsoluteSize
    local function place(object,position,size)
        object.Size=U2(size.X,size.Y)
        object.Position=U2(clamp(position.X*view.X,8,math.max(8,view.X-size.X-8)),clamp(position.Y*view.Y,20,math.max(20,view.Y-size.Y-8)))
    end
    if self.Launcher then
        place(self.Launcher,self.LauncherPosition,Vector2.new(self.FloatSize,40))
        self.Launcher.Text=self.LauncherText; self.Launcher.BackgroundTransparency=1-self.FloatOpacity
    end
    for _,floating in pairs(self._floatingButtons) do
        if not floating.Destroyed then
            place(floating.Frame,self._floatingPositions[floating.Id] or floating.Position,Vector2.new(self.FloatSize,self.FloatSize+14))
            floating.Frame.Visible=self.QuickActionsEnabled and floating.Visible and (not floating.MobileOnly or UserInputService.TouchEnabled==true)
                and (self._shown==false or self.Minimized or floating.VisibleWithMenu)
            floating.Button.BackgroundTransparency=1-self.FloatOpacity; floating.Button.TextTransparency=1-self.FloatOpacity
            self:_syncFloating(floating.Control)
        end
    end
end
function Window:_syncFloating(control)
    if not self._floatingButtons then return end
    for _,floating in pairs(self._floatingButtons) do
        if not floating.Destroyed and (not control or floating.Control==control) then
            local target=floating.Control; local active=target and (target.Type=="Toggle" and target.Value==true or target.Type=="Keybind" and target.Active==true)
            floating.Button.Text=target and target._busy and "..." or floating.Text
            floating.Button.BackgroundColor3=self.Palette[active and "Accent" or "Surface"]
            floating.Button.TextColor3=self.Palette[active and "AccentText" or "Text"]
            floating.Button.Active=not (target and (target.Disabled or target.Destroyed or target._busy))
        end
    end
end
function Window:SetFloatingOptions(options)
    options=options or {}
    local size=options.Size; if size==nil then size=self.FloatSize end
    local opacity=options.Opacity; if opacity==nil then opacity=self.FloatOpacity end
    assert(finite(size) and size>=44 and size<=96,"Floating Size must be 44–96")
    assert(finite(opacity) and opacity>=.2 and opacity<=1,"Floating Opacity must be 0.2–1")
    assert(options.Enabled==nil or type(options.Enabled)=="boolean","Floating Enabled must be boolean")
    self.FloatSize=size; self.FloatOpacity=opacity
    if options.Enabled~=nil then self.QuickActionsEnabled=options.Enabled end
    if not self.QuickActionsEnabled then self:_releaseBindings() end
    self:_layoutFloating(); self:_scheduleSave(); return self
end
function Window:SetLauncherOptions(options)
    options=options or {}
    local text=options.Text~=nil and options.Text or self.LauncherText
    assert(type(text)=="string" and #text>=1 and #text<=16,"Launcher Text must contain 1–16 bytes")
    assert(options.Enabled==nil or type(options.Enabled)=="boolean","Launcher Enabled must be boolean")
    local position=options.Position and normalizedPosition(options.Position) or self.LauncherPosition
    self.LauncherText=text; self.LauncherPosition=position
    if options.Enabled~=nil then self:SetLauncher(options.Enabled) end
    self:_layoutFloating(); self:_scheduleSave(); return self
end
function Window:AddFloatingButton(options)
    options=options or {}
    assert(not self.Destroyed,"Window has been destroyed")
    local control=options.Control
    assert(control==nil or control._window==self and not control.Destroyed,"Floating Control must belong to this window")
    assert(control or type(options.Callback)=="function","Floating button needs a Control or Callback")
    if control then assert(control.Type=="Toggle" or control.Type=="Button" or control.Type=="Keybind","Floating supports Toggle, Button or Keybind") end
    local id=options.Id or control and control.Id or HttpService:GenerateGUID(false)
    assert(type(id)=="string" and #id>=1 and #id<=128 and not self._floatingButtons[id],"Invalid or duplicate floating Id")
    local mode=options.Mode or control and (control.Type=="Toggle" and "Toggle" or control.Type=="Keybind" and control.Mode) or "Press"
    assert(mode=="Press" or mode=="Toggle" or mode=="Hold","Invalid floating Mode")
    assert(not control or control.Type~="Button" or mode=="Press","Button floating actions use Press mode")
    assert(not control or control.Type~="Keybind" or mode==control.Mode,"Floating keybind Mode must match the keybind")
    local position=normalizedPosition(options.Position or Vector2.new(.03,.65))
    local floating={_window=self,_connections={},Id=id,Control=control,Text=tostring(options.Text or control and control.Title or "Action"),
        Mode=mode,Position=position,_defaultPosition=position,MobileOnly=options.MobileOnly~=false,Visible=options.Visible~=false,
        VisibleWithMenu=options.VisibleWithMenu==true,Destroyed=false}
    assert(#floating.Text<=64,"Floating Text exceeds 64 bytes")
    floating.Frame=frame(self,self.Root,{Name="Floating/"..id,Size=U2(64,78),BackgroundTransparency=1,ZIndex=50})
    local handle=button(self,floating,floating.Frame,"::",{Size=UDim2.new(1,0,0,14),TextSize=11,ZIndex=51})
    function floating:Activate(active)
        if self.Destroyed or active~=false and (self._window._dialog or self._window._binding) then return end
        local target=self.Control
        if target and (target.Destroyed or active~=false and target.Disabled) then return end
        if target then
            if target.Type=="Toggle" then
                if self.Mode=="Hold" then target:SetValue(active==true) else target:SetValue(not target:GetValue()) end
            elseif target.Type=="Button" then target:Press()
            else target:Trigger(active) end
        else call(self._window,options.Callback,active,self) end
        self._window:_syncFloating(target)
    end
    function floating:SetPosition(value)
        self.Position=normalizedPosition(value); self._window._floatingPositions[self.Id]=self.Position
        self._window:_layoutFloating(); self._window:_scheduleSave(); return self
    end
    function floating:Release()
        if self._holdInput then self._holdInput=nil; self:Activate(false) end
    end
    function floating:Destroy()
        if self.Destroyed then return end
        self:Release(); self.Destroyed=true; cleanup(self)
        if self._window._drag and self._window._drag.Owner==self then self._window:_endDrag() end
        self._window._floatingButtons[self.Id]=nil
        if self.Control and self.Control.FloatingButton==self then self.Control.FloatingButton=nil end
        self.Frame:Destroy()
    end
    floating.Button=button(self,floating,floating.Frame,floating.Text,{Position=U2(0,14),Size=UDim2.new(1,0,1,-14),TextSize=12,
        TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=51},function() if floating.Mode~="Hold" then floating:Activate(true) end end)
    connect(floating,handle.InputBegan,function(input)
        if not pointer(input) or self._dialog then return end
        local start=point(input); local origin=floating.Frame.AbsolutePosition
        self:_beginDrag(floating,input,function(current)
            local view=self.Root.AbsoluteSize; local p=origin+(current-start)
            floating.Position=Vector2.new(clamp(p.X/math.max(1,view.X),0,1),clamp(p.Y/math.max(1,view.Y),0,1))
            self._floatingPositions[id]=floating.Position; self:_layoutFloating()
        end,function() self:_scheduleSave() end)
    end)
    connect(floating,floating.Button.InputBegan,function(input)
        if floating.Mode=="Hold" and pointer(input) and not self._dialog and not self._binding then floating._holdInput=input; floating:Activate(true) end
    end)
    connect(floating,floating.Button.InputEnded,function(input) if floating._holdInput==input then floating:Release() end end)
    connect(floating,floating.Frame.Destroying,function() floating:Destroy() end)
    self._floatingButtons[id]=floating; self:_layoutFloating()
    return floating
end
function Control:AddFloatingButton(options)
    assert(not self.Destroyed,"Control has been destroyed")
    assert(options==nil or type(options)=="table","Floating options must be a table")
    local passed={}
    for key,value in pairs(options or {}) do if key~="Control" then passed[key]=value end end
    if passed.Position~=nil then normalizedPosition(passed.Position) end
    assert(passed.Text==nil or type(passed.Text)=="string" and #passed.Text<=64,"Invalid floating Text")
    assert(passed.Mode==nil or passed.Mode=="Press" or passed.Mode=="Toggle" or passed.Mode=="Hold","Invalid floating Mode")
    if self.FloatingButton then self.FloatingButton:Destroy() end
    passed.Control=self
    self.FloatingButton=self._window:AddFloatingButton(passed); return self.FloatingButton
end

function Window:Dialog(options)
    options=options or {}
    assert(type(options)=="table","Dialog expects options")
    resolveIcon(options.Icon)
    local title=tostring(options.Title or self:_text("about")); local content=tostring(options.Content or "")
    assert(#title<=256 and #content<=8192,"Dialog text exceeds its limit")
    local actions=options.Buttons or {{Text="OK"}}
    assert(type(actions)=="table" and #actions>=1 and #actions<=3,"Dialog needs 1–3 buttons")
    local buttons={}
    for _,action in ipairs(actions) do
        assert(type(action)=="table" and type(action.Text)=="string" and #action.Text>=1 and #action.Text<=64,"Invalid dialog button")
        assert(action.Callback==nil or type(action.Callback)=="function","Dialog Callback must be a function")
        buttons[#buttons+1]={Text=action.Text,Callback=action.Callback,Kind=action.Kind}
    end
    local default=options.DefaultButton or 1
    assert(finite(default) and default%1==0 and default>=1 and default<=#buttons,"Invalid dialog default button")
    assert(options.OnClose==nil or type(options.OnClose)=="function","OnClose must be a function")
    if self.Destroyed then return nil end
    if self._dialog then self._dialog:Close("replaced") end
    self:Show(); self:_hideTooltip(); self:_hideSearchResults(); self:_endDrag()
    if self._binding then local bind=self._binding; self._binding=nil; bind:_render() end
    if self._openDropdown then self._openDropdown:SetOpen(false) end
    self:_releaseBindings()
    local focused=UserInputService:GetFocusedTextBox(); if focused then focused:ReleaseFocus() end
    local dialog={_window=self,_connections={},Destroyed=false,Buttons={},DefaultButton=default}
    dialog.Frame=ui(self,"TextButton",{Parent=self.Root,Name="Dialog",Size=UDim2.fromScale(1,1),Text="",AutoButtonColor=false,
        BackgroundColor3=RGB(0,0,0),BackgroundTransparency=.45,Active=true,ZIndex=2000})
    dialog.Panel=frame(self,dialog.Frame,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BorderSizePixel=1,ZIndex=2001},"Background")
    bevel(self,dialog.Panel,false)
    local header=frame(self,dialog.Panel,{Position=U2(4,4),Size=UDim2.new(1,-8,0,30),ZIndex=2002},"Accent")
    local heading=label(self,header,title,{Position=U2(9,0),Size=UDim2.new(1,-42,1,0),TextSize=13,TextTruncate=Enum.TextTruncate.AtEnd},"AccentText")
    dialog._titleIcon=iconSlot(self,header,options.Icon,options.Kind=="danger" and "warning" or "info",16,U2(7,7),"AccentText",function(visible)
        heading.Position=U2(visible and 29 or 9,0); heading.Size=UDim2.new(1,visible and -62 or -42,1,0)
    end)
    dialog.Icon=dialog._titleIcon.Frame
    dialog.Content=label(self,dialog.Panel,content,{Position=U2(14,46),Size=UDim2.new(1,-28,1,-103),TextWrapped=true,
        TextTruncate=Enum.TextTruncate.AtEnd,TextYAlignment=Enum.TextYAlignment.Top,TextSize=13,ZIndex=2002})
    function dialog:_layout()
        if self.Destroyed then return end
        local view=self._window.Root.AbsoluteSize; local width=math.max(120,math.min(480,view.X-16))
        local ok,bounds=pcall(TextService.GetTextSize,TextService,self.Content.Text,13,self._window.Font,Vector2.new(width-28,100000))
        local height=ok and bounds.Y+116 or 220
        self.Panel.Size=U2(width,math.max(130,math.min(height,view.Y-16,420)))
    end
    function dialog:SetContent(text)
        assert(type(text)=="string" and #text<=8192,"Dialog content exceeds its limit")
        if not self.Destroyed then self.Content.Text=text; self:_layout() end
        return self
    end
    function dialog:Close(reason,index)
        if self.Destroyed then
            if reason=="replaced" or reason=="destroyed" or reason=="hidden" then
                self._window:_cancelAnimations(self.Frame,false)
                if self._window._dialog==self then self._window._dialog=nil end
                self.Frame:Destroy()
            end
            return
        end
        self.Destroyed=true; self.Result=index; self.Reason=reason or "closed"
        cleanup(self); self._window:_cancelAnimations(self.Frame,false)
        local function remove()
            if self._window._dialog==self then self._window._dialog=nil end
            self._window:_cancelAnimations(self.Frame,false); self.Frame:Destroy()
        end
        if reason=="destroyed" or reason=="hidden" or reason=="replaced" or self._window.Destroyed or self._window._closing then remove()
        else self._window:_animate(self.Frame,{BackgroundTransparency=1},.1,"dialog",self,remove) end
        call(self._window,options.OnClose,self.Reason,index)
    end
    function dialog:Choose(index)
        if self.Destroyed or not buttons[index] then return end
        local callback=buttons[index].Callback
        self:Close("button",index); call(self._window,callback,index)
    end
    pixelButton(self,dialog,header,"X","close",{Position=UDim2.new(1,-29,0,3),Size=U2(24,24),TextSize=11},function() dialog:Close("cancel") end)
    for index,action in ipairs(buttons) do
        local cell=button(self,dialog,dialog.Panel,action.Text,{Position=UDim2.new((index-1)/#buttons,14,1,-44),
            Size=UDim2.new(1/#buttons,-28,0,30),ZIndex=2002,TextSize=12},function() dialog:Choose(index) end)
        if action.Kind=="danger" then self:_bind(cell,{TextColor3="Danger"}) end
        dialog.Buttons[index]=cell
    end
    connect(dialog,dialog.Frame.Activated,function(input)
        if options.DismissOnOutside and input and not inside(dialog.Panel,point(input)) then dialog:Close("outside") end
    end)
    connect(dialog,self.Root:GetPropertyChangedSignal("AbsoluteSize"),function() dialog:_layout() end)
    connect(dialog,dialog.Frame.Destroying,function() dialog:Close("destroyed") end)
    self._dialog=dialog; dialog:_layout()
    dialog.Frame.BackgroundTransparency=1
    dialog.Panel.Position=UDim2.new(.5,0,.5,5)
    self:_animate(dialog.Panel,{Position=UDim2.fromScale(.5,.5)},.12,"dialog",dialog)
    self:_animate(dialog.Frame,{BackgroundTransparency=.45},.12,"dialog",dialog)
    return dialog
end
function Window:Confirm(options)
    options=options or {}
    return self:Dialog({Title=options.Title,Content=options.Content,Icon=options.Icon,Kind=options.Kind,DefaultButton=1,
        Buttons={{Text=options.CancelText or self:_text("cancel"),Callback=options.OnCancel},
            {Text=options.ConfirmText or self:_text("confirm"),Kind=options.Kind,Callback=options.OnConfirm}},
        OnClose=function(reason) if reason~="button" then call(self,options.OnCancel,reason) end end})
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

function Window:_releaseBindings()
    self._touchToggles={}
    for _,floating in pairs(self._floatingButtons) do floating:Release() end
    for binding in pairs(self._keybinds) do if binding.Mode=="Hold" and binding.Active then binding:Trigger(false) end end
end
function Window:_inputBegan(input,processed)
    if self.Destroyed then return end
    if self._dialog then
        if input.UserInputType==Enum.UserInputType.Keyboard then
            if input.KeyCode==Enum.KeyCode.Escape then self._dialog:Close("cancel")
            elseif input.KeyCode==Enum.KeyCode.Return then self._dialog:Choose(self._dialog.DefaultButton) end
        end
        return
    end
    if pointer(input) then
        if not self.TooltipFrame or not self.TooltipFrame.Visible or not inside(self.TooltipFrame,point(input)) then self:_hideTooltip() end
        if self.SearchResults and self.SearchResults.Visible and not inside(self.SearchResults,point(input)) and not inside(self.Search,point(input)) then self:_hideSearchResults() end
    elseif input.UserInputType==Enum.UserInputType.Keyboard then self:_hideTooltip() end
    if self._binding then
        local value=inputBinding(input); if not value then return end
        local binding=self._binding
        if value.EnumType==Enum.UserInputType and not binding.AllowMouse then return end
        self._binding=nil
        if value~=Enum.KeyCode.Escape then binding:SetValue(value==Enum.KeyCode.Backspace and Enum.KeyCode.Unknown or value) end
        binding:_render(); return
    end
    if UserInputService:GetFocusedTextBox()==self.Search and self.SearchResults and self.SearchResults.Visible then
        if input.KeyCode==Enum.KeyCode.Up then self:_selectSearchResult((self._searchSelection or 1)-1); return
        elseif input.KeyCode==Enum.KeyCode.Down then self:_selectSearchResult((self._searchSelection or 1)+1); return
        elseif input.KeyCode==Enum.KeyCode.Escape then self.Search:ReleaseFocus(); self:_hideSearchResults(); return
        elseif input.KeyCode==Enum.KeyCode.Return then
            local match=self._searchMatches[self._searchSelection or 1]
            if match then self:FocusControl(match.Control) end
            return
        end
    end
    if pointer(input) and self._openDropdown and not inside(self._openDropdown.Frame,point(input)) then self._openDropdown:SetOpen(false) end
    if processed or UserInputService:GetFocusedTextBox() then return end
    local value=inputBinding(input)
    if value==self.ToggleKey and value~=Enum.KeyCode.Unknown then self:Toggle(); return end
    if self._settingsOpen then return end
    if value and value~=Enum.KeyCode.Unknown then
        for binding in pairs(self._keybinds) do if binding.Value==value then binding:Trigger(true) end end
    end
end
function Window:_inputEnded(input)
    for control,touch in pairs(self._touchToggles) do
        if touch.Input==input then
            self._touchToggles[control]=nil
            local position=point(input); local delta=position-touch.Position
            if not control.Destroyed and not control.Disabled and not control._touchWasLongPress and not touch.Moved and not self._dialog and not self._binding
                and self._shown~=false and self.Main.Visible and control.Frame.Visible and control._section._visible~=false and not (control._section._parentSection or control._section)._collapsed and control._section._tab==self.ActiveTab
                and inside(control.Frame,position) and delta.X*delta.X+delta.Y*delta.Y<=100 then control:SetValue(not control.Value) end
        end
    end
    if self._drag and (input==self._drag.Input or input.UserInputType==Enum.UserInputType.MouseButton1 and self._drag.Input.UserInputType==Enum.UserInputType.MouseButton1) then self:_endDrag() end
    for _,floating in pairs(self._floatingButtons) do
        local held=floating._holdInput
        if held and (held==input or held.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==held.UserInputType) then floating:Release() end
    end
    local value=inputBinding(input)
    for binding in pairs(self._keybinds) do if binding.Mode=="Hold" and binding.Active and binding.Value==value then binding:Trigger(false) end end
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
    resolveIcon(options.Icon)
    assert(options.PixelIcons==nil or type(options.PixelIcons)=="boolean","PixelIcons must be a boolean")
    assert(options.PixelDecorations==nil or type(options.PixelDecorations)=="boolean","PixelDecorations must be a boolean")
    assert(options.SmoothDragging==nil or type(options.SmoothDragging)=="boolean","SmoothDragging must be a boolean")
    assert(options.DragResponsiveness==nil or finite(options.DragResponsiveness) and options.DragResponsiveness>=8 and options.DragResponsiveness<=80,"DragResponsiveness must be 8–80")
    assert(options.Debug==nil or type(options.Debug)=="boolean","Debug must be a boolean")
    assert(options.CallbackExecutor==nil or type(options.CallbackExecutor)=="function","CallbackExecutor must be a function")
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
        PixelIcons=options.PixelIcons~=false,PixelDecorations=options.PixelDecorations~=false,
        SmoothDragging=options.SmoothDragging~=false,DragResponsiveness=options.DragResponsiveness or 24,
        Debug=options.Debug==true,CallbackExecutor=options.CallbackExecutor,
        _diagnostics={},_errorListeners={},Tasks={},_actions={},_groups={},_visualQueue={},_flagStates={},_actionHistory={},_nextAction=0,
        _tweens={},Animations=Library._animationSettings(options.Animations),_shown=true,_visibilityToken=0,
        NotificationsEnabled=options.Notifications~=false,LauncherEnabled=options.Launcher~=false,
        ErrorNotifications=options.ErrorNotifications~=false,
        SettingsEnabled=options.Settings~=false,AutoSave=options.AutoSave,StorageMode="memory",
        FloatSize=options.FloatSize or 64,FloatOpacity=options.FloatOpacity or 1,QuickActionsEnabled=options.QuickActions~=false,
        LauncherText=options.LauncherText or "UI",LauncherPosition=normalizedPosition(options.LauncherPosition or Vector2.new(.025,.1)),
        _locale=translations[options.Locale or "pt-BR"] or translations["pt-BR"],
        _connections={},_skin=setmetatable({},{ __mode="k" }),_icons={},_themeOverrides={},_rainbows={},_keybinds={},_destroyListeners={},
        _profiles={},_notifications={},_noticeCount=0,_nextId=0,_saveToken=0,_query="",
        _floatingButtons={},_floatingPositions={},_touchToggles={},
        _requestedSize=size,Controls={},Flags={},Tabs={},Destroyed=false,
    },Window)
    assert(finite(window.DragResponsiveness) and window.DragResponsiveness>=8 and window.DragResponsiveness<=80,"DragResponsiveness must be 8–80")
    assert(window.CallbackExecutor==nil or type(window.CallbackExecutor)=="function","CallbackExecutor must be a function")
    window._resources=self:CreateScope(); window._resources._window=window
    if window.AutoSave~=nil then profileName(window.AutoSave) end
    assert(finite(window.FloatSize) and window.FloatSize>=44 and window.FloatSize<=96,"FloatSize must be 44–96")
    assert(finite(window.FloatOpacity) and window.FloatOpacity>=.2 and window.FloatOpacity<=1,"FloatOpacity must be 0.2–1")
    assert(type(window.LauncherText)=="string" and #window.LauncherText>=1 and #window.LauncherText<=16,"LauncherText must contain 1–16 bytes")
    assert(options.FileStorage==nil or type(options.FileStorage)=="boolean","FileStorage must be a boolean")
    if options.Storage then window:SetStorage(options.Storage)
    elseif options.FileStorage~=false then
        window.ConfigFolder=folderName(options.ConfigFolder or "RetroBox/script-"..filePart(id))
        local adapter=self:CreateFileStorage(window.ConfigFolder)
        if adapter then window:SetStorage(adapter) end
    end
    window._initial={ Theme=theme,ThemeColors=copy(self.Themes[theme]),Accent=window.Accent,Scale=userScale,ReducedMotion=window.ReducedMotion,
        Animations=copy(window.Animations),SmoothDragging=window.SmoothDragging,DragResponsiveness=window.DragResponsiveness,
        Scanlines=window.Scanlines,PixelIcons=window.PixelIcons,PixelDecorations=window.PixelDecorations,
        Notifications=window.NotificationsEnabled,Launcher=window.LauncherEnabled,ToggleKey=toggle,
        FloatSize=window.FloatSize,FloatOpacity=window.FloatOpacity,QuickActions=window.QuickActionsEnabled,LauncherText=window.LauncherText,LauncherPosition=window.LauncherPosition }
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
    window._titleIcon=iconSlot(window,header,options.Icon,"retrobox",24,U2(6,5),"AccentText",function(visible)
        window.TitleLabel.Position=U2(visible and 36 or 10,0)
        window.TitleLabel.Size=UDim2.new(1,visible and -148 or -120,1,0)
    end)
    window.Icon=window._titleIcon.Frame
    window.MinimizeButton=pixelButton(window,window,header,"_","minimize",{ Position=UDim2.new(1,-98,0,4),Size=U2(27,26) },function() window:Minimize() end)
    window.MaximizeButton=pixelButton(window,window,header,"[]","maximize",{ Position=UDim2.new(1,-66,0,4),Size=U2(27,26),TextSize=11 },function()
        window._maximized=not window._maximized; window:Minimize(false); window:_layout()
    end)
    window.CloseButton=pixelButton(window,window,header,"X","close",{ Position=UDim2.new(1,-34,0,4),Size=U2(27,26) },function()
        if options.DestroyOnClose==true then window:Destroy() else window:Hide() end
    end)
    window.SubtitleLabel=label(window,window.Main,window.Subtitle,{
        Position=U2(14,44),Size=UDim2.new(1,-28,0,22),TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd,
    },"Muted")
    window.PixelMotif=frame(window,window.Main,{Name="PixelMotif",Position=UDim2.new(1,-72,0,49),Size=U2(54,12),BackgroundTransparency=1})
    for index,name in ipairs({"spark","retrobox","spark"}) do
        iconSlot(window,window.PixelMotif,name,nil,12,U2((index-1)*18,0),"Muted")
    end
    window.Nav=ui(window,"ScrollingFrame",{
        Parent=window.Main,BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,
        CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,
    },{ ScrollBarImageColor3="Border" })
    window.NavLayout=list(window,window.Nav,8,false)
    window.Search=textbox(window,window.Main,"",{ PlaceholderText=window:_text("search"),TextSize=12 })
    local searchPadding=window.Search:FindFirstChild("TextPadding")
    window._searchIcon=iconSlot(window,window.Main,nil,"search",16,U2(0,0),"Muted",function(visible) searchPadding.PaddingLeft=UDim.new(0,visible and 30 or 8) end)
    window.PageHost=frame(window,window.Main,{ BackgroundTransparency=1 })
    window.Footer=frame(window,window.Main,{ Position=UDim2.new(0,10,1,-56),Size=UDim2.new(1,-20,0,48),BackgroundTransparency=1 })
    frame(window,window.Footer,{ Size=UDim2.new(1,0,0,1) },"Border")
    window.Profile=frame(window,window.Footer,{ Position=U2(2,1),Size=U2(182,46),BackgroundTransparency=1,Visible=options.ShowProfile~=false })
    window:_profile(player)
    window.SettingsButton=pixelButton(window,window,window.Footer,"⚙","settings",{
        Position=U2(190,10),Size=U2(32,32),Font=Enum.Font.SourceSans,TextSize=24,Visible=window.SettingsEnabled,
    },function() window:ShowSettings() end)
    window.PixelSeal=frame(window,window.Footer,{Name="PixelSeal",Position=U2(234,18),Size=U2(36,12),BackgroundTransparency=1})
    for y=0,1 do for x=0,5 do
        frame(window,window.PixelSeal,{Position=U2(x*6,y*6),Size=U2(4,4)},(x+y)%2==0 and "Accent" or "Muted")
    end end
    window.Status=label(window,window.Footer,window:_text("ready").."  |  v"..self.Version,{
        Position=UDim2.new(1,-244,0,10),Size=U2(214,30),TextXAlignment=Enum.TextXAlignment.Right,TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd,
    },"Muted")
    window.ResizeGrip=label(window,window.Footer,"//",{
        Position=UDim2.new(1,-24,1,-24),Size=U2(24,24),TextXAlignment=Enum.TextXAlignment.Right,Active=true,
    },"Muted")
    window.Launcher=button(window,window,window.Root,"UI",{ Position=U2(16,60),Size=U2(44,38),Visible=false,ZIndex=30 },function() window:Show() end)
    local launcherHandle=button(window,window,window.Launcher,"::",{Position=U2(0,-14),Size=UDim2.new(1,0,0,14),TextSize=11,ZIndex=31})
    connect(window,launcherHandle.InputBegan,function(input)
        if not pointer(input) or window._dialog then return end
        local start=point(input); local origin=window.Launcher.AbsolutePosition
        window:_beginDrag(window,input,function(current)
            local view=window.Root.AbsoluteSize; local position=origin+(current-start)
            window.LauncherPosition=Vector2.new(clamp(position.X/math.max(1,view.X),0,1),clamp(position.Y/math.max(1,view.Y),0,1))
            window:_layoutFloating()
        end,function() window:_scheduleSave() end)
    end)
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
        window._dragRender=nil
        window:_beginDrag(window,input,function(current)
            window:_moveWindow(center+(current-start))
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
    connect(window,window.Search.Focused,function() window:_rebuildSearchResults() end)
    connect(window,window.Search.FocusLost,function(enter)
        local generation=window._searchGeneration
        if enter and window.SearchResults and window.SearchResults.Visible then
            local match=window._searchMatches[window._searchSelection or 1]
            if match then window:FocusControl(match.Control) end
        else task.delay(.15,function() if not window.Destroyed and window._searchGeneration==generation and UserInputService:GetFocusedTextBox()~=window.Search then window:_hideSearchResults() end end) end
    end)
    connect(window,window.Root:GetPropertyChangedSignal("AbsoluteSize"),function() window:_layout() end)
    connect(window,UserInputService.InputBegan,function(input,processed) window:_inputBegan(input,processed) end)
    connect(window,UserInputService.InputChanged,function(input)
        if input.UserInputType==Enum.UserInputType.Touch then
            for _,touch in pairs(window._touchToggles) do if touch.Input==input then
                local delta=point(input)-touch.Position; if delta.X*delta.X+delta.Y*delta.Y>100 then touch.Moved=true end
            end end
        end
        window:_updateTooltip(input)
        local drag=window._drag; if not drag then return end
        if drag.Input.UserInputType==Enum.UserInputType.Touch and input~=drag.Input then return end
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then drag.Update(point(input)) end
    end)
    connect(window,UserInputService.InputEnded,function(input) window:_inputEnded(input) end)
    connect(window,UserInputService.WindowFocusReleased,function()
        window:_hideTooltip()
        window:_endDrag()
        if window._binding then local binding=window._binding; window._binding=nil; binding:_render() end
        window:_releaseBindings(); window:_hideSearchResults()
    end)
    connect(window,window.Gui.Destroying,function() if not window.Destroyed then window:Destroy() end end)
    window:SetPixelDecorations(window.PixelDecorations)
    window:_layout(); window:_applyTheme()
    if window.SettingsEnabled then window:_createSettings() end
    window:_animateWindow(true)
    sharedWindows[window.Gui]=window
    return window
end
function Window:Destroy()
    if self.Destroyed or self._closing then return end
    self._closing=true
    self:_cancelAnimations(nil,false)
    self:_releaseBindings()
    if self.StopAll then self:StopAll("destroyed") end
    if self._resources then self._resources:Destroy() end
    self._dragRender=nil; self._visualQueue={}
    if self._runtimeConnection then self._runtimeConnection:Disconnect(); self._runtimeConnection=nil end
    self.Destroyed=true; self._saveToken=self._saveToken+1
    self._closing=false
    self:_hideTooltip()
    if self._dialog then self._dialog:Close("destroyed") end
    if self._searchOwner then cleanup(self._searchOwner) end
    for _,floating in pairs(self._floatingButtons) do floating:Destroy() end
    sharedWindows[self.Gui]=nil
    self:_endDrag()
    if self._rgbConnection then self._rgbConnection:Disconnect(); self._rgbConnection=nil end
    cleanup(self)
    local tabs={}
    for _,tab in ipairs(self.Tabs) do table.insert(tabs,tab) end
    for _,tab in ipairs(tabs) do tab:Destroy() end
    while #self._notifications>0 do self._notifications[1]:Destroy(true) end
    local icons={}; for handle in pairs(self._icons) do icons[#icons+1]=handle end
    for _,handle in ipairs(icons) do handle:Destroy() end
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
