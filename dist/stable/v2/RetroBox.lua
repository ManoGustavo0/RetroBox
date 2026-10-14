-- RetroBox UI 2.0.0 | Mano Gustavo | MIT License
-- Standalone GUI library for Roblox client executors.
-- Load the raw GitHub source with loadstring(game:HttpGet(URL))().

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local Library = { Version = "2.0.0", Themes = {}, Windows = {} }
local Window = {}; Window.__index = Window
local Tab = {}; Tab.__index = Tab
local Section = {}; Section.__index = Section
local Row = {}; Row.__index = Row; setmetatable(Row,{__index=Section})
local Control = {}; Control.__index = Control
local RGB = Color3.fromRGB
local U2 = UDim2.fromOffset
local FIELD_PADDING=12
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

-- Additional official palettes: every surface owns its matching ink roles.
Library.Themes.Hacker = palette({
    {8,13,10},{16,27,19},{5,10,7},{213,255,224},{141,187,153},{53,92,65},
    {78,128,89},{2,5,3},{57,237,117},{5,23,11},{104,240,162},{255,137,145},
})
Library.Themes.Dracula = palette({
    {33,30,46},{44,40,61},{25,22,36},{245,240,255},{191,180,213},{101,88,125},
    {120,104,144},{17,13,25},{189,147,249},{32,19,50},{142,230,176},{255,143,168},
})
Library.Themes.Nord = palette({
    {36,45,58},{48,61,77},{28,37,49},{236,239,244},{180,196,214},{88,111,135},
    {113,136,159},{18,25,35},{136,192,208},{16,40,49},{163,217,165},{240,154,163},
})
Library.Themes.Sakura = palette({
    {240,223,230},{250,237,242},{255,248,251},{73,44,60},{121,83,105},{171,133,152},
    {255,255,255},{182,141,159},{149,73,111},{255,246,250},{50,109,81},{166,55,81},
})
Library.Themes.Ocean = palette({
    {16,37,46},{25,53,64},{11,27,35},{229,248,252},{161,200,210},{64,106,121},
    {84,132,147},{6,18,25},{82,217,208},{8,44,44},{139,225,181},{255,155,152},
})
Library.Themes.Amber = palette({
    {32,23,12},{48,35,19},{21,15,7},{255,240,204},{207,183,140},{122,91,50},
    {153,116,68},{11,7,3},{244,188,89},{43,26,5},{187,214,139},{246,156,123},
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

    -- Economy, tools, equipment and activities (1.9.1).
    ["diamond"] = "............/...######.../..#hahhah#../.#aha##aha#./#hhhhhhhhhh#/.#aa#aa#aa#./..#a#aa#a#../...##aa##.../....#aa#..../.....##...../............/............",
    ["coins"] = "............/....######../...#hhhaaa#./...#aaaaaa#./...#aaaaaa#./....######../..######..#./.#hhhaaa#.#./.#aaaaaa#.#./.#aaaaaa#.#./..######.#../...######...",
    ["money"] = "............/.##########./.#ggg##ggg#./.#gg#hg#gg#./.#gg#ggggg#./.#ggg##ggg#./.#ggggg#gg#./.#gg#hg#gg#./.#ggg##ggg#./.##########./............/............",
    ["wallet"] = "............/..#######.../.#hhhhhh#.../.##########./.#aaaaaaaa#./.#aaaaaaaa#./.#aaaa#####./.#aaaa#hh##./.#aaaa#####./.#aaaaaaaa#./.##########./............",
    ["bank"] = ".....##...../....#aa#..../...#ahha#.../..#aaaaaa#../.##########./..#h#..#h#../..#h#..#h#../..#h#..#h#../..#h#..#h#../.##########./.#aaaaaaaa#./.##########.",
    ["credit-card"] = "............/.##########./.#hhhhhhhh#./.##########./.##########./.#aaaaaaaa#./.#a##aaaaa#./.#a##aaaaa#./.#aaaa###a#./.##########./............/............",
    ["tools"] = ".#..#......./.#hh#...###./..##...#ah#./..##..#ah#../...###ah#.../....#ah#..../...#ah##..../..#ah#.##.../.#ah#...##../.###.....##./..........#./............",
    ["wrench"] = ".......#..#./......#h..h#/......#hhhh#/.......####./......#hh#../.....#hh#.../....#hh#..../...#hh#...../..#hh#....../.#ah#......./.###......../............",
    ["hammer"] = "..########../.#hhhhhhhh#./.#hhhhhhhh#./..########../.....##...../.....##...../.....##...../.....##...../.....##...../....#aa#..../....#aa#..../.....##.....",
    ["screwdriver"] = ".......##.../......#h#.../.....#h#..../....#h#...../...#h#....../..#h#......./.#h#......../.###......../.#aa#......./..#aa#....../...##......./............",
    ["pickaxe"] = "..######..../.#hhhhhh#.../#hh####hh#../.##....#hh#./.....##.#h#./....#aa#.##./...#aa#...../..#aa#....../.#aa#......./.###......../............/............",
    ["axe"] = "......####../.....#hhhh#./....#hhhhhh#/....#hh###h#/....###aa##./.....#aa#.../....#aa#..../...#aa#...../..#aa#....../.#aa#......./.###......../............",
    ["shovel"] = "....####..../....#aa#..../....####..../.....##...../.....##...../.....##...../...######.../...#hhhh#.../...#hhhh#.../....#hh#..../.....##...../............",
    ["toolbox"] = "....####..../...#....#.../...######.../.##########./.#aaaaaaaa#./.##########./.#hhh##hhh#./.#hhh##hhh#./.#hhhhhhhh#./.##########./............/............",
    ["sword"] = ".........##./........#h#./.......#hh#./......#hh#../.....#hh#.../..#.#hh#..../..##hh#...../...###....../..#aa##...../.#aa#.##..../.###......../............",
    ["bow"] = "....#......./....###...../....#.a#..../....#..a#.../....#...a#../.##########./....#...a#../....#..a#.../....#.a#..../....###...../....#......./............",
    ["chest"] = "............/..########../.#ahhhhhaa#./.#aaaaaaaa#./.#aaaaaaaa#./.##########./.#aaa##aaa#./.#aaa##aaa#./.#aaaaaaaa#./.##########./............/............",
    ["backpack"] = "....####..../....#..#..../...######.../..#ahhhha#../.##aaaaaa##./.##aaaaaa##./..#aaaaaa#../..#a####a#../..#a#hh#a#../..#a####a#../..########../............",
    ["potion"] = "....####..../....#aa#..../....####..../....#..#..../...#h...#.../..#hh....#../.#hhh.....#./.#gggggggg#./.#gggggggg#./..#gggggg#../...######.../............",
    ["key"] = "............/..####....../.#ahha#...../.#a..a#...../.#a..a#####./.#aaaaaaa##./..#####aa#../......#aa#../......####../............/............/............",
    ["crown"] = "............/.#...##...#./.##..##..##./.#a##aa##a#./.#aaaaaaaa#./.#ahhaahha#./.#aaaaaaaa#./.##########./.#hhhhhhhh#./.##########./............/............",
    ["trophy"] = "............/...######.../.###ahha###./.#.#aaaa#.#./.#.#aaaa#.#./..###aa###../....#aa#..../.....##...../.....##...../...######.../..#aaaaaa#../..########..",
    ["gift"] = "..###..###../..#aa##aa#../...##aa##.../.##########./.#aaaa#aaa#./.##########./..#aaa#aa#../..#aaa#aa#../..#aaa#aa#../..#aaa#aa#../..########../............",
    ["rocket"] = ".....##...../....#aa#..../....#aa#..../...#hhhh#.../...#h##h#.../...#h##h#.../...#hhhh#.../..##hhhh##../.#a#hhhh#a#./.###rrrr###./....#rr#..../.....rr.....",
    ["fish"] = "............/.....##...../....#aa#..../...######..#/..#hhhaaa###/.#hhh#aaaaa#/.#hhhhaaaa##/..#aaaaaa###/...######..#/.....##...../............/............",
    ["magnet"] = "............/..###..###../..#h#..#h#../..#h#..#h#../..###..###../..#r#..#a#../..#r#..#a#../..#r#..#a#../..#rr##aa#../...#rraa#.../....####..../............",
    ["clock"] = "....####..../..##hhhh##../.#hhhhhhhh#./.#hhh#hhhh#./#hhhh#hhhhh#/#hhhh#hhhhh#/#hhhh###hhh#/#hhhhhhhhhh#/.#hhhhhhhh#./.#hhhhhhhh#./..##hhhh##../....####....",
    ["map"] = "............/.####..####./.#hh###haa#./.#hh#h#haa#./.#hh#h#rra#./.#aa#h#rra#./.#aa#a#haa#./.#aa#a#hhh#./.####aa####./.....##...../............/............",
    ["skull"] = "....####..../..##hhhh##../.#hhhhhhhh#./.#hhhhhhhh#./.#h##hh##h#./.#h##hh##h#./.#hhhhhhhh#./..#hh##hh#../...#hhhh#.../...#h##h#.../...######.../............",
    ["leaf"] = ".........##./......###g#./....##gggg#./...#ggg#g#../..#ggg#gg#../..#gg#ggg#../..#g#ggg#.../..##ggg#..../..#####...../..##......../.##........./............",
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
        delete="Excluir",deleteProfile="Excluir configuração?",deleteWarning="Esta ação não poderá ser desfeita.",deleted="Configuração excluída",
        descriptions="Mostrar descrições",tooltips="Dicas de ajuda",tooltipDelay="Atraso das dicas",textScale="Escala do texto",themeStudio="Theme Studio",commandPalette="Central de comandos",
        search="Pesquisar funções...", settings="Configurações", theme="Tema", accent="Cor de destaque",
        scale="Escala da interface", motion="Reduzir animações", lines="Linhas CRT", launcher="Botão de reabrir",
        notices="Notificações", appearance="Aparência", accessibility="Interface e acessibilidade",
        pixelIcons="Ícones padrão em pixel art",pixelDecorations="Detalhes em pixel art",
        loading="Carregando...",unavailable="Indisponível",noData="Sem dados",
        animations="Animações",animationSpeed="Velocidade das animações",animationIntensity="Intensidade",smoothDragging="Suavizar reposicionamento",
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
        delete="Delete",deleteProfile="Delete configuration?",deleteWarning="This action cannot be undone.",deleted="Configuration deleted",
        descriptions="Show descriptions",tooltips="Help tooltips",tooltipDelay="Tooltip delay",textScale="Text scale",themeStudio="Theme Studio",commandPalette="Command palette",
        search="Search features...", settings="Settings", theme="Theme", accent="Accent color",
        scale="Interface scale", motion="Reduce animations", lines="CRT scanlines", launcher="Reopen button",
        notices="Notifications", appearance="Appearance", accessibility="Interface and accessibility",
        pixelIcons="Default pixel art icons",pixelDecorations="Pixel art details",
        loading="Loading...",unavailable="Unavailable",noData="No data",
        animations="Animations",animationSpeed="Animation speed",animationIntensity="Intensity",smoothDragging="Smooth repositioning",
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

-- Context-aware ink and explicit style ownership. Native Instance proxies must
-- not disappear from this registry while their widgets are alive.
do
    local function luminance(color)
        local function linear(value) return value<=.04045 and value/12.92 or ((value+.055)/1.055)^2.4 end
        return .2126*linear(color.R)+.7152*linear(color.G)+.0722*linear(color.B)
    end
    function Library:ContrastRatio(a,b)
        a,b=parseColor(a),parseColor(b); local x,y=luminance(a),luminance(b)
        return (math.max(x,y)+.05)/(math.min(x,y)+.05)
    end
    function Library:ReadableColor(color,background,minimum)
        color,background=parseColor(color),parseColor(background); minimum=minimum or 4.5
        assert(finite(minimum) and minimum>=1 and minimum<=21,"Contrast target must be 1–21")
        if self:ContrastRatio(color,background)>=minimum then return color end
        local dark,light=RGB(0,0,0),RGB(255,255,255)
        local target=self:ContrastRatio(dark,background)>self:ContrastRatio(light,background) and dark or light
        local low,high=0,1
        for _=1,20 do
            local mid=(low+high)/2; local candidate=color:Lerp(target,mid)
            if self:ContrastRatio(candidate,background)>=minimum then high=mid else low=mid end
        end
        return color:Lerp(target,high)
    end
    function Window:_surfaceColor(object)
        local override=self._inkSurfaces and self._inkSurfaces[object]
        if override then return type(override)=="string" and self.Palette[override] or override end
        local current=object
        while current do
            if current:IsA("GuiObject") and (current.BackgroundTransparency or 0)<1 then return current.BackgroundColor3 or self.Palette.Background end
            current=current.Parent
        end
        return self.Palette.Background
    end
    function Window:_ink(role,object,minimum,background)
        local color=type(role)=="string" and assert(self.Palette[role],"Unknown color role: "..role) or role
        return Library:ReadableColor(color,background or self:_surfaceColor(object),minimum or 4.5)
    end
    function Window:_refreshInk(object)
        for property,role in pairs(self._skin[object] or {}) do
            if property=="TextColor3" or property=="PlaceholderColor3" then object[property]=self:_ink(role,object) end
        end
    end
    function Window:_forgetSkin(root)
        local objects={root}; for _,object in ipairs(root:GetDescendants()) do objects[#objects+1]=object end
        for _,object in ipairs(objects) do
            self._skin[object]=nil
            if self._inkSurfaces then self._inkSurfaces[object]=nil end
            if self._textSizes then self._textSizes[object]=nil end
            if self._focusTargets then self._focusTargets[object]=nil end
            if self._keyboardFocus==object then self._keyboardFocus=nil; if self._focusRing then self._focusRing.Visible=false end end
            if self._focusRing==object then self._focusRing=nil end
        end
    end
end

function Window:_text(key) return self._locale[key] or key end
function Window:_bind(object, roles)
    local registered=self._skin[object] or {}; self._skin[object]=registered
    for property,role in pairs(roles) do registered[property]=role; object[property]=self.Palette[role] end
    self:_refreshInk(object)
end
local function ui(window, class, properties, roles)
    local object = Instance.new(class)
    local parent = properties.Parent
    for property, value in pairs(properties) do if property ~= "Parent" then object[property] = value end end
    if roles then window:_bind(object, roles) end
    object.Parent = parent
    if roles then window:_refreshInk(object) end
    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        window._textSizes[object]=object.TextSize or 14; object.TextSize=(object.TextSize or 14)*(window.TextScale or 1)
    end
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
            if role=="Surface" then role=(window._skin[object] or {}).BackgroundColor3 or role end
            local background=window.Palette[role]
            local foreground=(window._skin[object] or {}).TextColor3 or "Text"
            if owner.Sections and window.ActiveTab==owner then foreground="AccentText" end
            window:_animate(object,{BackgroundColor3=background,TextColor3=window:_ink(foreground,object,4.5,background)},.08,"button",owner)
            for _,child in ipairs(object:GetDescendants()) do
                local bound=window._skin[child]
                if bound and bound.TextColor3 then child.TextColor3=window:_ink(bound.TextColor3,child,4.5,background) end
            end
        end
        connect(owner,object.MouseEnter,function() tone("Highlight") end)
        connect(owner,object.MouseLeave,function() tone("Surface") end)
        connect(owner,object.InputBegan,function(input) if pointer(input) then tone("Inset") end end)
        connect(owner,object.InputEnded,function(input) if pointer(input) then tone("Surface") end end)
    end
    if pressed then
        local function activate(...)
            local blocked=false; local ancestor=object.Parent
            while ancestor do if ancestor==window.Main and window._shown==false then blocked=true; break end; ancestor=ancestor.Parent end
            local section=owner._section and (owner._section._parentSection or owner._section)
            if section and (section._collapsed or not section._visible) then blocked=true end
            if window._dialog and owner~=window._dialog then blocked=true end
            if window._interactionAllowed and not window:_interactionAllowed(object) then blocked=true end
            if not window.Destroyed and not owner.Destroyed and not owner.Disabled and not blocked then pressed(...) end
        end
        connect(owner,object.Activated,activate)
        if window._registerFocus then window:_registerFocus(object,function() activate() end) end
    end
    return object
end
local function padButton(window,object,left,right)
    ui(window,"UIPadding",{Name="TextPadding",Parent=object,PaddingLeft=UDim.new(0,left),PaddingRight=UDim.new(0,right)})
    local top,bottom=object:FindFirstChild("BevelTop"),object:FindFirstChild("BevelBottom")
    local l,r=object:FindFirstChild("BevelLeft"),object:FindFirstChild("BevelRight")
    if top then top.Position=U2(-left,0); top.Size=UDim2.new(1,left+right,0,1) end
    if bottom then bottom.Position=UDim2.new(0,-left,1,-1); bottom.Size=UDim2.new(1,left+right,0,1) end
    if l then l.Position=U2(-left,0) end
    if r then r.Position=UDim2.new(1,right-1,0,0) end
end

local function textbox(window, parent, text, props)
    local properties = { Parent=parent, Text=tostring(text or ""), Font=window.Font, TextSize=14,
        BorderSizePixel=1, ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left,
        Size=UDim2.new(1,0,0,32), RichText=false }
    for k, v in pairs(props or {}) do properties[k] = v end
    local object = ui(window, "TextBox", properties, { BackgroundColor3="Inset", TextColor3="Text", BorderColor3="Border", PlaceholderColor3="Muted" })
    ui(window, "UIPadding", { Name="TextPadding",Parent=object, PaddingLeft=UDim.new(0,FIELD_PADDING), PaddingRight=UDim.new(0,FIELD_PADDING) })
    if window._registerFocus then window:_registerFocus(object,function() object:CaptureFocus() end) end
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
        function listener:Disconnect() self.Connected=false; owner._errorListeners[self]=nil; owner._resources:Remove(self,true) end
        self._resources:Add(listener,"Disconnect",listener); return listener
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
        self._diagnosticSeq=(self._diagnosticSeq or 0)+1; record.Id="diagnostic/"..self._diagnosticSeq
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
    function Window:_moveWindow(center,direct)
        self:_cancelTrack(self.Main,"window",false)
        if self._shown~=false then self.Main.BackgroundTransparency=0 end
        center=self:_clampCenter(center); self._position=center
        if self.SmoothDragging and not self.ReducedMotion and not direct then
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

    -- Completion waits resume only on settlement, cancellation or timeout.
    -- No polling coroutine or per-wait frame connection is required.
    local Context={}; Context.__index=Context
    local function token(window,scope)
        local context=setmetatable({Window=window,Resources=scope,Cancelled=false,_cancelListeners={}},Context)
        scope:Add(function()
            local listeners={}; for listener in pairs(context._cancelListeners) do listeners[#listeners+1]=listener end
            for _,listener in ipairs(listeners) do listener:Disconnect() end
        end)
        return context
    end
    function Context:IsCancelled()
        return self.Cancelled or self.Window.Destroyed or self.ParentContext and self.ParentContext:IsCancelled() or false
    end
    function Context:ThrowIfCancelled() if self:IsCancelled() then error(cancelSignal,0) end end
    function Context:Manage(resource,method,key) return self.Resources:Add(resource,method,key) end
    function Context:OnCancel(callback)
        assert(type(callback)=="function","OnCancel requires a function")
        local owner=self; local listener={Connected=true,Callback=callback}
        function listener:Disconnect() self.Connected=false; owner._cancelListeners[self]=nil end
        if self:IsCancelled() then listener.Connected=false; self.Window:_protected(callback,{Phase="Cancellation"},self.Reason)
        elseif self.Resources.Destroyed then listener.Connected=false
        else self._cancelListeners[listener]=true end
        return listener
    end
    function Context:Cancel(reason)
        if self.Cancelled then return end
        self.Cancelled=true; self.Reason=tostring(reason or "cancelled"):sub(1,2048)
        local listeners={}; for listener in pairs(self._cancelListeners) do listeners[#listeners+1]=listener end
        for _,listener in ipairs(listeners) do
            if listener.Connected then self.Window:_protected(listener.Callback,{Phase="Cancellation"},self.Reason) end
            listener:Disconnect()
        end
        self.Resources:Destroy()
    end
    function Context:AwaitAction(handle,options)
        local opts={}; for k,v in pairs(options or {}) do opts[k]=v end; opts.Context=self
        return self.Window:AwaitAction(handle,opts)
    end
    local function awaitedResult(handle)
        if handle._status.Status=="Completed" then return true,handle.Result,"Completed" end
        if handle._status.Status=="Failed" then return false,handle.Error or "Action failed","Failed" end
        return false,handle.Error or handle.Context.Reason or "Action cancelled","Cancelled"
    end
    function Window:AwaitAction(handle,options)
        options=options or {}
        assert(type(options)=="table","AwaitAction options must be a table")
        assert(type(handle)=="table" and handle._window==self and type(handle.GetStatus)=="function","AwaitAction requires an action from this window")
        local timeout,context=options.Timeout,options.Context
        assert(timeout==nil or finite(timeout) and timeout>=0 and timeout<=86400,"Await timeout must be 0–86400 seconds")
        assert(context==nil or getmetatable(context)==Context and context.Window==self,"Await context must belong to this window")
        assert(options.CancelAction==nil or type(options.CancelAction)=="boolean","CancelAction must be boolean")
        assert(options.Throw==nil or type(options.Throw)=="boolean","Throw must be boolean")
        local function deliver(ok,result,status)
            if not ok and options.Throw then
                if status=="Cancelled" and context and context:IsCancelled() then error(cancelSignal,0) end
                error(tostring(result),2)
            end
            return ok,result,status
        end
        -- Completed handles remain readable after history eviction or Destroy.
        if handle.Finished then return deliver(awaitedResult(handle)) end
        if context and context.Action==handle then return deliver(false,"An action cannot await itself","Rejected") end
        if context and context.Action and context.Action.Group==handle.Group and handle._status.Status=="Queued" then
            return deliver(false,"Awaiting a queued action in the current group would deadlock","Rejected")
        end
        local function cancelled(reason,status)
            if options.CancelAction then handle:Cancel(reason) end
            return deliver(false,reason,status or "Cancelled")
        end
        if self.Destroyed or handle.Destroyed then return cancelled("Window or handle has been destroyed") end
        if context and (context:IsCancelled() or context.Resources.Destroyed) then return cancelled(context.Reason or "Wait context is no longer active") end
        if timeout==0 then return cancelled("Action wait timed out","TimedOut") end
        local thread,main=coroutine.running()
        if not thread or main then return deliver(false,"AwaitAction requires a yielding worker; use task.spawn or a runtime callback","Rejected") end
        self._waitCount=self._waitCount or 0
        if self._waitCount>=256 then return deliver(false,"Action wait limit is 256 per window","Rejected") end
        local scope=self:CreateScope(); local settled,parked=false,false; local outcome
        local function resolve(ok,result,status)
            if settled then return end
            settled=true; outcome=table.pack(ok,result,status)
            if not ok and options.CancelAction and (status=="Cancelled" or status=="TimedOut") then handle:Cancel(result) end
            scope:Destroy()
            if parked and coroutine.status(thread)=="suspended" then task.defer(thread,table.unpack(outcome,1,outcome.n)) end
        end
        self._waitCount=self._waitCount+1
        scope:Add(function()
            self._waitCount=self._waitCount-1; handle._awaiters[scope]=nil
            if not settled then resolve(false,"Wait owner was destroyed","Cancelled") end
        end)
        handle._awaiters[scope]=function(destroyed)
            if handle.Finished then resolve(awaitedResult(handle))
            elseif destroyed then resolve(false,"Action handle was destroyed","Cancelled") end
        end
        if context then scope:Add(context:OnCancel(function(reason) resolve(false,reason or "Wait cancelled","Cancelled") end),"Disconnect") end
        if timeout then
            local timer=task.delay(timeout,function() resolve(false,"Action wait timed out","TimedOut") end)
            scope:Add(function()
                if timer and timer~=coroutine.running() and type(task.cancel)=="function" then pcall(task.cancel,timer) end
                timer=nil
            end)
        end
        -- A synchronous cancellation or completion during registration wins.
        if handle.Finished and not settled then resolve(awaitedResult(handle)) end
        if settled then return deliver(table.unpack(outcome,1,outcome.n)) end
        parked=true
        return deliver(coroutine.yield())
    end

    local function safeResult(value)
        local ok,result=pcall(cloneState,value); if ok then return result end
        return nil
    end
    local function taskUpdate(job,phase)
        if phase then job._phase=phase end
        if job.Status.Destroyed then return end
        job.Status:_assign({Id=job.Id,Status=job._phase,Requested=job.Requested,Active=job.Requested or job.InFlight,
            Running=job._callbackRunning==true,InFlight=job.InFlight,Interval=job.Interval,Iterations=job.Iterations,
            NextRun=job.Requested and not job.InFlight and job.Next or nil,StartedAt=job.StartedAt,FinishedAt=job.FinishedAt,
            LastResult=safeResult(job.LastResult),LastError=job.LastError,LastOutcome=job.LastOutcome,StopReason=job.StopReason,Group=job.Options.Group})
    end
    function Window:CreateTask(options)
        assert(not self.Destroyed and type(options)=="table","CreateTask requires options and a live window")
        local supplied=options; options={}; for k,v in pairs(supplied) do options[k]=v end
        local id=options.Id; local interval=options.Interval or 1
        assert(type(id)=="string" and #id>=1 and #id<=128 and not self.Tasks[id],"Task Id must be unique and 1–128 bytes")
        assert(finite(interval) and interval>=.03 and interval<=86400,"Task Interval must be .03–86400 seconds")
        assert(type(options.Callback)=="function","Task Callback is required")
        assert(options.OnError==nil or options.OnError=="Stop" or options.OnError=="Continue","Task OnError is Stop or Continue")
        assert(options.Scope==nil or getmetatable(options.Scope)==Scope and not options.Scope.Destroyed,"Task Scope must be a live resource scope")
        assert(options.Group==nil or type(options.Group)=="string" and #options.Group>=1 and #options.Group<=128,"Task Group must be 1–128 bytes")
        assert(options.Policy==nil or options.Policy=="Ignore" or options.Policy=="Reject" or options.Policy=="Queue" or options.Policy=="Replace","Task Policy is Ignore, Reject, Queue or Replace")
        assert(options.Policy==nil or options.Group~=nil,"Task Policy requires a Group")
        local count=0; for _ in pairs(self.Tasks) do count=count+1 end; assert(count<128,"Window task limit is 128")
        local owner=self
        local job={Id=id,Interval=interval,Callback=options.Callback,Options=options,Requested=false,InFlight=false,Iterations=0,Generation=0,_window=self,_phase="Inactive"}
        job.Status=self:CreateState({Id=id,Status="Inactive",Requested=false,Active=false,Running=false,InFlight=false,Interval=interval,Iterations=0})
        job.Status.ReadOnly=true
        local policyScope=(options.Scope or self._resources):Child({CancelOnHide=options.CancelOnHide==true,CancelOnDisable=options.CancelOnDisable==true,CancelOnFalse=options.CancelOnFalse==true})
        policyScope:Add(function() job:Stop("scope cleaned") end,nil,"stop")
        function job:GetStatus()
            local value=self.Status:Get()
            value.Remaining=value.NextRun and math.max(0,value.NextRun-os.clock()) or nil
            return value
        end
        function job:Subscribe(callback,immediate) return self.Status:Subscribe(callback,immediate) end
        function job:Start()
            if self.Destroyed or owner.Destroyed or policyScope.Destroyed then return false,"Task has been destroyed" end
            if self.Requested then return true end
            if not policyScope._keys.stop then policyScope:Add(function() self:Stop("scope cleaned") end,nil,"stop") end
            self.Requested=true; self.Generation=self.Generation+1; self.StopReason=nil; self.LastError=nil
            self.Next=os.clock()+(options.Immediate==false and self.Interval or 0)
            taskUpdate(self,self.InFlight and self._phase or "Waiting")
            owner:_refreshRuntime(); return true
        end
        function job:Stop(reason)
            if self.Destroyed then return self end
            if not self.Requested and (not self.InFlight or self.Context and self.Context:IsCancelled()) and self._phase~="Inactive" then return self end
            self.Requested=false; self.Generation=self.Generation+1; self.StopReason=tostring(reason or "stopped"):sub(1,2048)
            if self.Context then self.Context:Cancel(self.StopReason) end
            if self.Action and not self.Action.Finished then self.Action:Cancel(self.StopReason) end
            taskUpdate(self,self.InFlight and "Cancelling" or "Stopped")
            owner:_refreshRuntime(); return self
        end
        job.Cancel=job.Stop
        function job:IsRunning() return self.Requested or self.InFlight end
        function job:SetInterval(value)
            assert(finite(value) and value>=.03 and value<=86400,"Task Interval must be .03–86400")
            self.Interval=value; self.Next=os.clock()+value; taskUpdate(self); return self
        end
        function job:Destroy()
            if self.Destroyed then return end
            self:Stop("destroyed"); self.Destroyed=true; taskUpdate(self,"Destroyed")
            policyScope:Destroy(); self.Status:Destroy(); owner.Tasks[id]=nil; owner._resources:Remove("task:"..id,true)
        end
        self.Tasks[id]=job; self:Manage(job,"Destroy","task:"..id)
        if options.Start then job:Start() end
        return job
    end
    function Control:CreateTask(options)
        assert(not self.Destroyed and type(options)=="table","CreateTask requires options and a live control")
        local original=options; options={}; for k,v in pairs(original) do options[k]=v end
        options.Scope=self._resources; options.ControlId=self.Id
        local job=self._window:CreateTask(options); self:Manage(job,"Destroy","task:"..job.Id); return job
    end
    function Window:_stepTasks()
        local now=os.clock(); local ready={}
        for _,job in pairs(self.Tasks) do if job.Requested and not job.InFlight and now>=job.Next then ready[#ready+1]=job end end
        table.sort(ready,function(a,b) return a.Id<b.Id end)
        for _,job in ipairs(ready) do
            if not job.Destroyed and job.Requested and not job.InFlight then
                job.InFlight=true; local generation=job.Generation
                local scope=self:CreateScope(); local context=token(self,scope); context.Task=job; job.Context=context
                taskUpdate(job,job.Options.Group and "WaitingForGroup" or "Waiting")
                task.spawn(function()
                    local ok,result,reason=true,nil,nil; local outcome="Completed"
                    local function invoke(ctx)
                        ctx.Task=job; ctx:ThrowIfCancelled()
                        job._callbackRunning=true; job.StartedAt=os.clock(); taskUpdate(job,"Running")
                        ctx:ThrowIfCancelled()
                        return job.Callback(ctx)
                    end
                    if context:IsCancelled() or job.Destroyed then outcome="Cancelled"
                    elseif job.Options.Group then
                        local action,err=self:RunAction({Group=job.Options.Group,Policy=job.Options.Policy or "Queue",ControlId=job.Options.ControlId,
                            Callback=function(ctx) ctx.ParentContext=context; return invoke(ctx) end})
                        job.Action=action
                        if action then
                            if context:IsCancelled() and not action.Finished then action:Cancel(context.Reason) end
                            ok,result,outcome=self:AwaitAction(action)
                        elseif err=="ignored" then outcome="Skipped"
                        else ok=false; result=err; outcome="Rejected"; self:_diagnose({Operation=job.Id,Phase="TaskGroup"},err) end
                    else
                        ok,result,reason=self:_protected(invoke,{ControlId=job.Options.ControlId,Operation=job.Id,Phase="Task"},context)
                        if context:IsCancelled() or result==cancelSignal then outcome="Cancelled"
                        elseif not ok then outcome="Failed" end
                    end
                    if context:IsCancelled() then outcome="Cancelled" end
                    job._callbackRunning=false; job.Action=nil; scope:Destroy(); job.Context=nil; job.InFlight=false
                    job.Iterations=job.Iterations+1; job.FinishedAt=os.clock(); job.LastOutcome=outcome
                    local failed=outcome=="Failed" or outcome=="Rejected"
                    if failed then job.LastError=tostring(result):sub(1,2048)
                    elseif outcome=="Completed" then job.LastResult=result; job.LastError=nil end
                    if job.Generation==generation then
                        if failed and job.Options.OnError~="Continue" or job.Options.Once then job.Requested=false end
                        if job.Requested then job.Next=os.clock()+job.Interval end
                    end
                    if not job.Destroyed and not self.Destroyed then
                        taskUpdate(job,job.Requested and "Waiting" or failed and "Failed" or "Stopped")
                        self:_refreshRuntime()
                    end
                end)
            end
        end
    end
    function Window:StartTask(id) local job=self.Tasks[id]; assert(job,"Unknown task: "..tostring(id)); return job:Start() end
    function Window:StopTask(id,reason) local job=self.Tasks[id]; assert(job,"Unknown task: "..tostring(id)); job:Stop(reason); return self end
    function Control:BindTask(job,options)
        options=options or {}
        assert(self.Type=="Toggle" and not self.Destroyed,"BindTask requires a live Toggle")
        assert(type(job)=="table" and job._window==self._window and not job.Destroyed and self._window.Tasks[job.Id]==job,"BindTask requires a live task from this window")
        assert(type(options)=="table","BindTask options must be a table")
        local onStop=options.OnStop or "TurnOff"; local initial=options.Initial or "Control"
        assert(onStop=="TurnOff" or onStop=="KeepRequested","OnStop is TurnOff or KeepRequested")
        assert(initial=="Control" or initial=="Task","Initial is Control or Task")
        assert(options.FireCallback==nil or type(options.FireCallback)=="boolean","FireCallback must be boolean")
        assert(options.StopOnUnbind==nil or type(options.StopOnUnbind)=="boolean","StopOnUnbind must be boolean")
        local scope=self:CreateScope(); self._resources:Add(scope,"Destroy","task-binding")
        local owner=self; local syncing=false
        local function show(value)
            if owner.Destroyed or owner._destroyingControl or owner._window.Destroyed or owner._window._closing then return end
            if owner:GetValue()==value then return end
            syncing=true; owner:SetValue(value,not options.FireCallback); syncing=false
        end
        local function request(value)
            if syncing or owner.Destroyed or job.Destroyed then return end
            if value then
                local ok,err=job:Start()
                if not ok then show(false); owner._window:_diagnose({ControlId=owner.Id,Operation=job.Id,Phase="TaskBinding"},err) end
            elseif job.Requested then job:Stop("toggle off") end
        end
        scope:Add(function() if options.StopOnUnbind~=false and not job.Destroyed then job:Stop("task binding removed") end end)
        scope:Add(self._window:GetFlagState(self.Id):Subscribe(request),"Disconnect")
        scope:Add(job:Subscribe(function(status)
            if status.Requested then show(true)
            elseif onStop=="TurnOff" or status.Status=="Destroyed" then show(false) end
        end),"Disconnect")
        if initial=="Task" then show(job.Requested) else request(self:GetValue()) end
        return scope
    end
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
        local waits={}; for _,callback in pairs(handle._awaiters) do waits[#waits+1]=callback end
        for _,callback in ipairs(waits) do callback(false) end
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
        local handle={Id=id,Group=groupId,Options=options,_window=self,_awaiters={},_status={Status="Queued",Step=0,Total=0,Progress=0,Message=""}}
        handle.Status=self:CreateState(handle._status,{Name="Action:"..id})
        handle.Status.ReadOnly=true
        handle.Context=token(self,scope); handle.Context.Action=handle
        function handle:GetStatus() return copy(self._status) end
        function handle:Subscribe(callback,immediate) return self.Status:Subscribe(callback,immediate) end
        function handle:Await(options) return owner:AwaitAction(self,options) end
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
            local waits={}; for _,callback in pairs(self._awaiters) do waits[#waits+1]=callback end
            for _,callback in ipairs(waits) do callback(true) end
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
        local stats={Tasks=0,RunningTasks=0,Actions=0,WaitingActions=self._waitCount or 0,Animations=0,QueuedVisuals=0,Resources=self._resources:GetCount(),FrameConnection=self._runtimeConnection~=nil}
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
    if self._shown==false or self.TooltipsEnabled==false or UserInputService:GetFocusedTextBox() then return false end
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
    local textSize=clamp(math.floor(13*self.UserScale*(self.TextScale or 1)+.5),10,24)
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
    if self._pendingTooltip==control or self._tooltipOwner==control then self._tooltipAnchor=anchor; return end
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
        if window._tooltipMode=="hover" and (window._tooltipOwner==self or window._pendingTooltip==self) and not window:_tooltipEligible(self,UserInputService:GetMouseLocation()) then window:_hideTooltip() end
    end)
    local function touch(positions,state)
        if state==Enum.UserInputState.Begin and positions[1] and self.Tooltip then
            self._touchWasLongPress=true; self._window:_showTooltip(self,positions[1],"touch")
        end
    end
    connect(self,self.TitleLabel.TouchLongPress,touch)
    connect(self,self.DescriptionLabel.TouchLongPress,touch)
    for _,object in ipairs({self.TitleLabel,self.DescriptionLabel}) do
        connect(self,object.MouseEnter,function(x,y) if self.Tooltip then self._window:_queueTooltip(self,Vector2.new(x,y)) end end)
    end
end
function Control:SetTooltip(value)
    assert(not self.Destroyed,"This control has been destroyed")
    self.Tooltip=tooltipValue(value)
    if self.Tooltip then self:_connectTooltip(); self:_syncHelpBadge()
    elseif self.InfoButton then
        self._window:_forgetSkin(self.InfoButton); self.InfoButton:Destroy(); self.InfoButton=nil
        self.TitleLabel.Size=UDim2.new(self.TitleLabel.Size.X.Scale,self.TitleLabel.Size.X.Offset+22,self.TitleLabel.Size.Y.Scale,self.TitleLabel.Size.Y.Offset)
    end
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
    if drag and drag.Owner==self and self._dragRender then
        local p=self:_clampCenter(self._dragRender.Target); self.Main.Position=U2(p.X,p.Y); self._dragRender=nil; self:_refreshRuntime()
    end
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
    self.TitleLabel.TextTransparency = self.Disabled and .15 or 0
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
    self:_layoutDescription()
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
    self._window:_forgetSkin(self.Frame); self.Frame:Destroy()
    local index = table.find(self._section.Controls, self)
    if index then table.remove(self._section.Controls, index) end
    if self._section._parentSection then
        local parent=self._section._parentSection
        local outer=table.find(parent.Controls,self); if outer then table.remove(parent.Controls,outer) end
        self._section:_layout()
    end
    self._window:_updateRGB()
    if self._window._refreshRuntime then self._window:_refreshRuntime() end
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
    local self = setmetatable({ Type=kind, Title=tostring(options.Title or kind), Description=tostring(options.Description or ""),_explicitHeight=options.Height~=nil,
        Tooltip=tooltip,_descriptionEnabled=options.ShowDescription~=false,_window=window, _section=section, _connections={},_callbackEpoch=0, _visible=options.Visible ~= false, Disabled=options.Disabled == true }, Control)
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
    control:_captureDescriptionLayout()
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
        box.Active = not self.Disabled; box.TextTransparency = self.Disabled and .15 or 0
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
            and (not self.Keybind or not inside(self.Keybind.Frame,point(input)))
            and (not self.InfoButton or not inside(self.InfoButton,point(input))) and (not self._window._interactionAllowed or self._window:_interactionAllowed(self.Frame)) then
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
        action.TextTransparency = self.Disabled and .15 or 0
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
    self:_captureDescriptionLayout()
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
    self.TitleLabel.TextYAlignment = Enum.TextYAlignment.Top
    self.DescriptionLabel.TextWrapped = true; self.DescriptionLabel.TextTruncate = Enum.TextTruncate.None
    self.DescriptionLabel.Size = UDim2.new(1,0,1,-22); self.DescriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
    function self:_normalize(value) return tostring(value) end
    function self:_render() self.TitleLabel.Text = self.Value end
    function self:SetText(value) self.Title=tostring(value); return self:SetValue(tostring(value),true) end
    connect(self,self.TitleLabel:GetPropertyChangedSignal("Text"),function() self:_layoutDescription() end)
    connect(self,self.TitleLabel:GetPropertyChangedSignal("AbsoluteSize"),function() self:_layoutDescription() end)
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
    padButton(self._window,header,FIELD_PADDING,24)
    local arrow=label(self._window,header,"v",{ Position=UDim2.new(1,-24,0,0),Size=U2(20,30),TextXAlignment=Enum.TextXAlignment.Center })
    iconSlot(self._window,arrow,nil,"chevron-down",12,UDim2.new(.5,-6,.5,-6),"Text",function(visible) arrow.Text=visible and "" or "v" end)
    local panel = frame(self._window,self.Frame,{ Position=U2(0,79),Size=UDim2.new(1,0,0,184),Visible=false },"Inset")
    bevel(self._window,panel,true)
    local search = textbox(self._window,panel,"",{ Position=U2(6,6),Size=UDim2.new(1,-12,0,28),PlaceholderText=self._window:_text("search"),Visible=options.Searchable ~= false })
    local results = ui(self._window,"ScrollingFrame",{
        Parent=panel,Position=U2(6,options.Searchable == false and 6 or 40),
        Size=UDim2.new(1,-12,1,options.Searchable == false and -12 or -46),ClipsDescendants=true,
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
        header.TextTransparency = self.Disabled and .15 or 0
        header.Active = not self.Disabled
        for name, item in pairs(self._rows or {}) do
            local selected = self.Multi and table.find(self.Value,name) ~= nil or not self.Multi and self.Value == name
            item.Text = (selected and "[X] " or "[ ] ") .. name
            self._window:_bind(item,{TextColor3=selected and "Accent" or "Text"})
        end
        if self.Disabled and self.Open then self:SetOpen(false) end
    end
    function self:_rebuild()
        for _, c in ipairs(self._optionConnections) do c:Disconnect() end
        self._optionConnections = {}
        for _,owner in ipairs(self._rowOwners or {}) do owner.Destroyed=true; cleanup(owner) end
        self._rowOwners={}
        for _, object in ipairs(results:GetChildren()) do if object:IsA("GuiObject") then self._window:_forgetSkin(object); object:Destroy() end end
        self._rows = {}
        local query = search.Text:lower()
        local count = 0
        for index, name in ipairs(self.Options) do
            if query == "" or name:lower():find(query,1,true) then
                count = count + 1
                local rowOwner={_connections={},_section=self._section}; self._rowOwners[#self._rowOwners+1]=rowOwner
                local item = button(self._window,rowOwner,results,"",{ LayoutOrder=index,Size=UDim2.new(1,-6,0,28),TextXAlignment=Enum.TextXAlignment.Left })
                padButton(self._window,item,FIELD_PADDING,FIELD_PADDING)
                self._rows[name] = item
                local function activateOption()
                    if self._window._interactionAllowed and not self._window:_interactionAllowed(item) then return end
                    if self.Disabled or self.Destroyed then return end
                    if self.Multi then
                        local value = self:GetValue()
                        local selected = table.find(value,name)
                        if selected then table.remove(value,selected) else table.insert(value,name) end
                        self:SetValue(value)
                    else
                        self:SetValue(name); self:SetOpen(false)
                    end
                end
                local connection=item.Activated:Connect(activateOption)
                if self._window._registerFocus then self._window:_registerFocus(item,activateOption) end
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
        local target=UDim2.new(1,0,0,(open and 272 or 80)+(self._descriptionDelta or 0))
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
        for _,owner in ipairs(self._rowOwners or {}) do owner.Destroyed=true; cleanup(owner) end
        self._rowOwners={}; self._optionConnections = {}
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
        capture.TextTransparency = self.Disabled and .15 or 0
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
        caption.TextTransparency = self.Disabled and .15 or 0
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
        local target=UDim2.new(1,0,0,(self.Open and 334 or 80)+(self._descriptionDelta or 0))
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
        node.BackgroundColor3=window:_ink(color or "Accent",node,3,window:_surfaceColor(parent))
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
            self._window:_bind(self.TrendLabel,{TextColor3=self.Trend>0 and "Success" or self.Trend<0 and "Danger" or "Muted"})
            self._window:_bind(self.ValueLabel,{TextColor3=(self.Loading or self.Unavailable) and "Muted" or "Text"})
            if options.Animated and self._window._animate and finite(self.Value) and finite(self._lastValue) and self.Value~=self._lastValue then
                self.ValueLabel.TextColor3=self._window:_ink(self.Value>self._lastValue and "Success" or "Danger",self.ValueLabel)
                self._window:_animate(self.ValueLabel,{TextColor3=self._window:_ink("Text",self.ValueLabel)},.25,"stat",self)
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
        if kind=="Progress" then
            self._progressInkLeft=frame(self._window,self.Plot,{Size=UDim2.fromScale(0,1),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=self.Plot.ZIndex+3})
            self._progressInkRight=frame(self._window,self.Plot,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=self.Plot.ZIndex+3})
            self.ProgressFillLabel=label(self._window,self._progressInkLeft,"",{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=14,ZIndex=self.Plot.ZIndex+4},"AccentText")
            self.ProgressLabel=label(self._window,self._progressInkRight,"",{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=14,ZIndex=self.Plot.ZIndex+4},"Text")
        end
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
                local logicalWidth=self.Plot.AbsoluteSize.X/math.max(.01,self._window._actualScale or 1)
                self._progressInkLeft.Size=UDim2.new(ratio,0,1,0)
                self._progressInkRight.Position=UDim2.new(ratio,0,0,0); self._progressInkRight.Size=UDim2.new(1-ratio,0,1,0)
                self.ProgressFillLabel.Size=UDim2.new(0,logicalWidth,1,0)
                self.ProgressLabel.Size=UDim2.new(0,logicalWidth,1,0); self.ProgressLabel.Position=U2(-ratio*logicalWidth,0)
                self._window._inkSurfaces[self.ProgressFillLabel]=node.BackgroundColor3
                self._window:_refreshInk(self.ProgressFillLabel); self._window:_refreshInk(self.ProgressLabel)
                self.ProgressLabel.Text=format(ratio*100,"Percent",options.Precision); self.ProgressFillLabel.Text=self.ProgressLabel.Text; self.EmptyLabel.Visible=false
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
        if object.Parent then
            for property,role in pairs(roles) do if property~="TextColor3" and property~="PlaceholderColor3" then object[property]=self.Palette[role] end end
        else self:_forgetSkin(object) end
    end
    for object in pairs(self._skin) do if object.Parent then self:_refreshInk(object) end end
    for _,control in pairs(self.Controls) do if not control.Destroyed and control._render and (control.Value~=nil or control.Type=="Button" or control.Type=="Dropdown") then
        if control._draw then self._visualQueue[control]=nil; self:_protected(function() control:_draw() end,{ControlId=control.Id,Phase="Theme"}) else control:_render() end
    end end
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
    self:_endDrag()
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
    self:_layout(); local targetSize,targetPosition=self.Main.Size,self.Main.Position; self.Main.Size=oldSize; self.Main.Position=oldPosition
    self:_animate(self.Main,{Size=targetSize,Position=targetPosition},.14,"size",self); return self
end
function Window:Center()
    local old=self.Main.Position; local view=self.Root.AbsoluteSize
    self._position=nil; self:_layout(); local target=self.Main.Position
    if self.SmoothDragging and not self.ReducedMotion then
        self.Main.Position=U2(old.X.Scale*view.X+old.X.Offset,old.Y.Scale*view.Y+old.Y.Offset)
        self:_moveWindow(Vector2.new(target.X.Offset,target.Y.Offset)); self._position=nil
    end
    return self
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
    if self._query=="" or self._settingsOpen or self._dialog or self._shown==false or not self.Main.Visible or self.Minimized then self:_hideSearchResults(); return end
    local matches=self:SearchControls(self._query)
    for index,entry in ipairs(matches) do if index>30 then break end; self._searchMatches[#self._searchMatches+1]=entry end
    if not self.SearchResults then
        self.SearchResults=ui(self,"ScrollingFrame",{Parent=self.Body,Name="SearchResults",BorderSizePixel=1,ZIndex=70,
            CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,
            ScrollBarThickness=4,ClipsDescendants=true},{BackgroundColor3="Surface",BorderColor3="Border",ScrollBarImageColor3="Border"})
    end
    local origin=self.SearchContainer.Position
    self.SearchResults.Position=UDim2.new(origin.X.Scale,origin.X.Offset,origin.Y.Scale,origin.Y.Offset+34)
    self.SearchResults.Size=UDim2.new(self.SearchContainer.Size.X.Scale,self.SearchContainer.Size.X.Offset,0,
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
    if tab.Hidden or control._section._visible==false or section._visible==false then return false,"Control is hidden" end
    if section._collapsed then section:SetCollapsed(false) end
    self:Show(); self:Minimize(false)
    self.Search.Text=""; self:SetSearch(""); tab:Select(); self:_hideSearchResults()
    if UserInputService:GetFocusedTextBox()==self.Search then self.Search:ReleaseFocus() end
    if self._focusNavigation then self._focusNavigation:Destroy() end
    local navigation=self:CreateScope(); self._focusNavigation=navigation
    local function scrollAndFocus()
        if self.Destroyed or control.Destroyed or tab.Destroyed or self.ActiveTab~=tab or self._overlay or self._dialog or self._shown==false or self.Minimized then return end
        local scroller=control.Frame.Parent
        while scroller and scroller~=tab.Frame and not (scroller:IsA("ScrollingFrame") and scroller.ScrollingEnabled~=false) do scroller=scroller.Parent end
        scroller=scroller or tab.Frame
        local canvas=scroller.CanvasPosition or Vector2.new(0,0)
        local y=canvas.Y+(control.Frame.AbsolutePosition.Y-scroller.AbsolutePosition.Y)/math.max(.1,self._actualScale)
        scroller.CanvasPosition=Vector2.new(canvas.X,math.max(0,y-12))
        if not control.Disabled then
            local target=control.Input or control.Button or control.TitleLabel
            if control.Viewport and control._onKey then
                target=control.Viewport
                for _,row in ipairs(control._pool or {}) do if row.Button.Visible then target=row.Button; break end end
            end
            if target and target.Parent then
                if target:IsA("TextBox") then target:CaptureFocus() else self:_focusObject(target) end
                if control.Viewport and control._onKey then self._activeAdvanced=control end
            end
        end
    end
    scrollAndFocus()
    navigation:Add(RunService.RenderStepped:Connect(function()
        scrollAndFocus(); navigation:Destroy()
        if self._focusNavigation==navigation then self._focusNavigation=nil end
    end),"Disconnect")
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

-- Script configuration versions are independent of Library.Version/Schema.
do
    local rootFields={Library=true,Schema=true,Version=true,ConfigVersion=true,Flags=true,Appearance=true}
    local appearanceFields={Theme=true,ThemeColors=true,Accent=true,Scale=true,ReducedMotion=true,Scanlines=true,
        Notifications=true,Launcher=true,ToggleKey=true,PixelIcons=true,PixelDecorations=true,Animations=true,Drag=true,
        Floating=true,LauncherText=true,LauncherPosition=true,Advanced=true}
    local function version(value)
        assert(finite(value) and value%1==0 and value>=1 and value<=65535,"ConfigVersion must be an integer 1–65535")
        return value
    end
    Library._configVersion=version
    local function clone(value,seen,depth,budget)
        local kind=typeof(value)
        if kind=="Color3" then return hex(value) end
        if kind=="EnumItem" then return value.Name end
        if type(value)~="table" then
            assert(value==nil or type(value)=="boolean" or type(value)=="string" or finite(value),"Configuration data must be serializable; functions/instances are not accepted")
            return value
        end
        seen=seen or {}; depth=depth or 0; budget=budget or {Count=0}
        assert(depth<16 and not seen[value],"Configuration data must be acyclic and at most 16 levels deep")
        seen[value]=true; local result={}; local count=0
        for key,item in pairs(value) do
            count=count+1; budget.Count=budget.Count+1
            assert(count<=4096 and budget.Count<=32768,"Configuration data exceeds its entry limit")
            assert(type(key)=="string" or finite(key),"Configuration keys must be strings or finite numbers")
            result[key]=clone(item,seen,depth+1,budget)
        end
        seen[value]=nil; return result
    end
    Library._copyConfigData=clone
    function Window:SetConfigVersion(value) self.ConfigVersion=version(value); return self end
    function Window:RegisterMigration(fromVersion,callback)
        version(fromVersion); assert(fromVersion<65535 and type(callback)=="function","Migration needs a source version and function")
        self._migrations[fromVersion]=callback; return self
    end
    function Window:_prepareProfile(source,options)
        assert(type(options)=="table","ImportConfig options must be a table")
        assert(options.Migrate==nil or type(options.Migrate)=="boolean","Migrate must be boolean")
        local policy=options.Strict and "Reject" or options.UnknownFlags or self.UnknownFlags
        assert(policy=="Ignore" or policy=="Preserve" or policy=="Reject","UnknownFlags is Ignore, Preserve or Reject")
        local profile=clone(type(source)=="string" and HttpService:JSONDecode(source) or source)
        assert(type(profile)=="table" and profile.Library=="RetroBox UI" and profile.Schema==1,"Unsupported configuration format")
        assert(type(profile.Flags)=="table","Missing Flags")
        local current=version(profile.ConfigVersion or 1)
        assert(current<=self.ConfigVersion,"Profile uses a newer script ConfigVersion: "..current)
        assert(options.Migrate~=false or current==self.ConfigVersion,"Profile migration is disabled")
        assert(self.ConfigVersion-current<=32,"Profile requires more than 32 migration steps")
        while current<self.ConfigVersion do
            local callback=self._migrations[current]; assert(callback,"Missing migration from ConfigVersion "..current)
            local candidate=clone(profile)
            local thread=coroutine.create(function() return callback(candidate,current,current+1) end)
            local ok,result=coroutine.resume(thread)
            if coroutine.status(thread)~="dead" then
                if type(task.cancel)=="function" then pcall(task.cancel,thread) end
                local message="Profile migration must be synchronous and cannot yield"
                self:_diagnose({Phase="Migration",Operation="config/"..current},message); error(message)
            end
            if not ok then
                self:_diagnose({Phase="Migration",Operation="config/"..current},result)
                error("Migration "..current.." failed: "..tostring(result))
            end
            assert(result==nil or type(result)=="table","Migration must return a profile table or nil after editing the supplied copy")
            profile=clone(result or candidate); current=current+1; profile.ConfigVersion=current
            assert(profile.Library=="RetroBox UI" and profile.Schema==1 and type(profile.Flags)=="table","Migration changed the RetroBox envelope or removed Flags")
        end
        profile.ConfigVersion=self.ConfigVersion
        local json=HttpService:JSONEncode(profile)
        assert(#json<=self.MaxConfigBytes,"Migrated configuration exceeds MaxConfigBytes")
        local extras={Root={},Appearance={},Flags={}}
        for key,value in pairs(profile) do if not rootFields[key] then extras.Root[key]=clone(value) end end
        for key,value in pairs(profile.Appearance or {}) do if not appearanceFields[key] then extras.Appearance[key]=clone(value) end end
        if policy=="Preserve" then
            for id,record in pairs(profile.Flags) do
                if type(id)=="string" and not id:match("^__retrobox/") and not self.Controls[id] then
                    assert(type(record)=="table" and type(record.Type)=="string" and #record.Type<=64,"Invalid preserved flag: "..id)
                    extras.Flags[id]=clone(record)
                end
            end
        end
        return profile,extras,policy
    end
    function Window:_exportProfileExtras(profile)
        local extras=self._profileExtras or {Root={},Appearance={},Flags={}}
        for key,value in pairs(extras.Root) do if not rootFields[key] then profile[key]=clone(value) end end
        for key,value in pairs(extras.Appearance) do if not appearanceFields[key] then profile.Appearance[key]=clone(value) end end
        for id,record in pairs(extras.Flags) do if not self.Controls[id] then profile.Flags[id]=clone(record) end end
        profile.ConfigVersion=self.ConfigVersion
        return profile
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
    if self._exportAdvanced then result.Appearance.Advanced=self:_exportAdvanced() end
    self:_exportProfileExtras(result)
    if asTable then return result end
    return HttpService:JSONEncode(result)
end
function Window:ImportConfig(source,options)
    options=options or {}
    if self.Destroyed then return false,"Window has been destroyed" end
    if type(source)=="string" and #source>self.MaxConfigBytes then return false,"Configuration exceeds MaxConfigBytes" end
    local ok,prepared=pcall(function()
        local config,extras,policy=self:_prepareProfile(source,options)
        assert(type(config)=="table" and config.Library=="RetroBox UI" and config.Schema==1,"Unsupported configuration format")
        assert(type(config.Flags)=="table","Missing Flags")
        local changes={}
        for id,record in pairs(config.Flags) do
            assert(type(id)=="string","Flag Id must be a string")
            local control=self.Controls[id]
            if control and control.Persist then
                assert(type(record)=="table" and record.Type==control.Type,"Control type mismatch: "..id)
                changes[id]={ Value=control:_normalize(record.Value) }
            elseif policy=="Reject" then error("Unknown or nonpersistent control: "..id) end
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
        return {Changes=changes,Appearance=appearance,Extras=extras,Advanced=self:_prepareAdvanced(look.Advanced)}
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
    self._profileExtras=prepared.Extras
    self:_applyAdvanced(prepared.Advanced,true)
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
    self:_applyTheme(); self:_applyAdvancedUI(prepared.Advanced); self:_layout()
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
        ReadFile=type(readfile)=="function",WriteFile=type(writefile)=="function",DeleteFile=type(delfile)=="function",
        MakeFolder=type(makefolder)=="function",IsFile=type(isfile)=="function",IsFolder=type(isfolder)=="function",ListFiles=type(listfiles)=="function",
        FileStorage=type(readfile)=="function" and type(writefile)=="function" and type(makefolder)=="function",
    }
end
function Library:CreateFileStorage(folder)
    folder=folderName(folder or "RetroBox")
    if not self:GetCapabilities().FileStorage then return nil,"Executor does not expose readfile, writefile and makefolder" end
    -- Capture this executor's functions; no folder or file is created until Save.
    local read,write,mkdir=readfile,writefile,makefolder
    local remove=type(delfile)=="function" and delfile or nil
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
        Delete=remove and function(name)
            local target=path(name); local exists=hasFile and hasFile(target)
            if not hasFile then exists=pcall(read,target) end
            assert(exists,"Profile was not found")
            local known=discovered(); local remaining={}
            for _,item in ipairs(known) do if item~=name then remaining[#remaining+1]=item end end
            ensureFolders()
            local indexed=write(indexPath,HttpService:JSONEncode({Schema=1,Names=remaining}))
            assert(indexed~=false,"Executor refused to update the profile index")
            local ok,reason=pcall(remove,target)
            if not ok or reason==false then
                local restored,value=pcall(write,indexPath,HttpService:JSONEncode({Schema=1,Names=known}))
                error("Profile deletion failed: "..tostring(reason)..((not restored or value==false) and "; index restoration also failed" or ""))
            end
            return true
        end or nil,
    }
end
function Window:DeleteConfig(name)
    if self.Destroyed then return false,"Window has been destroyed" end
    local ok,result=pcall(function()
        profileName(name)
        local known,err=self:GetConfigNames(); assert(not err,err)
        assert(table.find(known,name),"Profile was not found")
        if self.Storage then
            assert(type(self.Storage.Delete)=="function","Storage does not support profile deletion")
            local deleted,reason=self.Storage.Delete(name); assert(deleted==true,reason or "Storage refused deletion")
        end
        self._profiles[name]=nil
        if self.LastConfigName==name then self.LastConfigName=nil end
        if self.AutoSave==name then self.AutoSave=nil end
        self._saveToken=self._saveToken+1
        return true
    end)
    if ok and self._refreshProfiles then self:_refreshProfiles() end
    return ok,ok and result or tostring(result)
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
function Window:_readConfigSource(name)
    profileName(name)
    local value=self._profiles[name]
    if self.Storage then
        local loaded,err=self.Storage.Load(name); assert(loaded~=nil,err or "Profile was not found"); value=loaded
    end
    assert(type(value)=="string" or type(value)=="table","Profile was not found")
    return value
end

function Window:LoadConfig(name,options)
    if self.Destroyed then return false,"Window has been destroyed" end
    local ok,data=pcall(self._readConfigSource,self,name)
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
    if self._initial.Advanced then self:_applyAdvanced(self:_prepareAdvanced(self._initial.Advanced),true) end
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
    self:_applyTheme(); self:_applyAdvancedUI(self._initial.Advanced); self:_layout(); self:SetScanlines(self.Scanlines); self:SetLauncher(self.LauncherEnabled)
    for _,dashboard in pairs(self._dashboards) do dashboard:ResetLayout() end
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
    if self.Body then self.Body.Visible=not self.Minimized end
    self.SubtitleLabel.Visible=not self.Minimized
    self.Nav.Visible=not self.Minimized; self.Search.Visible=not self.Minimized
    self.PageHost.Visible=not self.Minimized; self.Footer.Visible=not self.Minimized
    if self.Mobile then
        self.Nav.Position=U2(10,70); self.Nav.Size=UDim2.new(1,-20,0,38)
        self.NavLayout.FillDirection=Enum.FillDirection.Horizontal
        self.Nav.AutomaticCanvasSize=Enum.AutomaticSize.X; self.Nav.ScrollingDirection=Enum.ScrollingDirection.X
        self.SearchContainer.Position=U2(10,116); self.SearchContainer.Size=UDim2.new(1,-20,0,30)
        self.PageHost.Position=U2(10,156); self.PageHost.Size=UDim2.new(1,-20,1,-220)
    else
        self.Nav.Position=U2(10,76); self.Nav.Size=UDim2.new(0,160,1,-141)
        self.NavLayout.FillDirection=Enum.FillDirection.Vertical
        self.Nav.AutomaticCanvasSize=Enum.AutomaticSize.Y; self.Nav.ScrollingDirection=Enum.ScrollingDirection.Y
        self.SearchContainer.Position=U2(184,73); self.SearchContainer.Size=UDim2.new(1,-198,0,30)
        self.PageHost.Position=U2(184,114); self.PageHost.Size=UDim2.new(1,-198,1,-178)
    end
    self.Status.Visible=not self.Mobile; self.ResizeGrip.Visible=not self.Mobile and not self._maximized
    self.SearchContainer.Visible=not self.Minimized
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
    controls.Load:SetDisabled(err~=nil or not controls.Profiles:GetValue())
    if controls.Delete then controls.Delete:SetDisabled(err~=nil or not controls.Profiles:GetValue() or self.Storage and type(self.Storage.Delete)~="function") end
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
    controls.Delete=actions:AddButton(opts("config-delete",self:_text("delete"),{Icon="close",Callback=function()
        local name=controls.Profiles:GetValue()
        if not name then self:Notify({Title=self:_text("error"),Content=self:_text("empty"),Kind="error"}); return end
        self:Confirm({Title=self:_text("deleteProfile"),Content=name.."\n"..self:_text("deleteWarning"),OnConfirm=function()
            local ok,reason=self:DeleteConfig(name)
            if ok then profile:SetValue(controls.Profiles:GetValue() or "",true) end
            self:Notify({Title=self:_text(ok and "deleted" or "error"),Content=ok and name or reason,Kind=ok and "success" or "error"})
        end})
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
            self._window:_cancelAnimations(self.Frame,false); self._window:_forgetSkin(self.Frame); self.Frame:Destroy()
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
    local configVersion=Library._configVersion(options.ConfigVersion or 1)
    assert(options.UnknownFlags==nil or options.UnknownFlags=="Ignore" or options.UnknownFlags=="Preserve" or options.UnknownFlags=="Reject","UnknownFlags is Ignore, Preserve or Reject")
    assert(options.Migrations==nil or type(options.Migrations)=="table","Migrations must be a table")
    for from,callback in pairs(options.Migrations or {}) do
        Library._configVersion(from); assert(from<65535 and type(callback)=="function","Invalid migration registration")
    end
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
    if tooltipDelay==nil then tooltipDelay=.2 end
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
        ShowDescriptions=options.ShowDescriptions~=false,TooltipsEnabled=options.Tooltips~=false,TextScale=options.TextScale or 1,
        _customThemes={},_dashboards={},CommandKey=options.CommandKey and keycode(options.CommandKey) or Enum.KeyCode.F4,
        Font=font,UserScale=userScale,ToggleKey=toggle,MaxConfigBytes=maxBytes,TooltipDelay=tooltipDelay,TooltipMaxWidth=tooltipWidth,
        ReducedMotion=options.ReducedMotion == true,Scanlines=options.Scanlines == true,
        PixelIcons=options.PixelIcons~=false,PixelDecorations=options.PixelDecorations~=false,
        SmoothDragging=options.SmoothDragging==true,DragResponsiveness=options.DragResponsiveness or 24,
        Debug=options.Debug==true,CallbackExecutor=options.CallbackExecutor,
        _diagnostics={},_errorListeners={},Tasks={},_actions={},_groups={},_visualQueue={},_flagStates={},_actionHistory={},_nextAction=0,
        _tweens={},Animations=Library._animationSettings(options.Animations),_shown=true,_visibilityToken=0,
        NotificationsEnabled=options.Notifications~=false,LauncherEnabled=options.Launcher~=false,
        ErrorNotifications=options.ErrorNotifications~=false,
        SettingsEnabled=options.Settings~=false,AutoSave=options.AutoSave,StorageMode="memory",
        FloatSize=options.FloatSize or 64,FloatOpacity=options.FloatOpacity or 1,QuickActionsEnabled=options.QuickActions~=false,
        LauncherText=options.LauncherText or "UI",LauncherPosition=normalizedPosition(options.LauncherPosition or Vector2.new(.025,.1)),
        _locale=translations[options.Locale or "pt-BR"] or translations["pt-BR"],
        _connections={},_skin={},_inkSurfaces={},_textSizes={},_focusTargets={},_icons={},_themeOverrides={},_rainbows={},_keybinds={},_destroyListeners={},
        _profiles={},_notifications={},_noticeCount=0,_nextId=0,_saveToken=0,_query="",
        ConfigVersion=configVersion,UnknownFlags=options.UnknownFlags or "Ignore",_migrations={},_profileExtras={Root={},Appearance={},Flags={}},
        _floatingButtons={},_floatingPositions={},_touchToggles={},
        _requestedSize=size,Controls={},Flags={},Tabs={},Destroyed=false,
    },Window)
    assert(finite(window.DragResponsiveness) and window.DragResponsiveness>=8 and window.DragResponsiveness<=80,"DragResponsiveness must be 8–80")
    assert(window.CallbackExecutor==nil or type(window.CallbackExecutor)=="function","CallbackExecutor must be a function")
    assert(finite(window.TextScale) and window.TextScale>=.8 and window.TextScale<=1.4,"TextScale must be .8–1.4")
    window._resources=self:CreateScope(); window._resources._window=window
    for from,callback in pairs(options.Migrations or {}) do window:RegisterMigration(from,callback) end
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
        BorderSizePixel=1,Active=true,ClipsDescendants=true,
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
    window.Body=frame(window,window.Main,{Name="Body",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ClipsDescendants=true})
    window.SubtitleLabel=label(window,window.Body,window.Subtitle,{
        Position=U2(14,44),Size=UDim2.new(1,-28,0,22),TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd,
    },"Muted")
    window.PixelMotif=frame(window,window.Body,{Name="PixelMotif",Position=UDim2.new(1,-72,0,49),Size=U2(54,12),BackgroundTransparency=1})
    for index,name in ipairs({"spark","retrobox","spark"}) do
        iconSlot(window,window.PixelMotif,name,nil,12,U2((index-1)*18,0),"Muted")
    end
    window.Nav=ui(window,"ScrollingFrame",{
        Parent=window.Body,BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,
        CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,
    },{ ScrollBarImageColor3="Border" })
    window.NavLayout=list(window,window.Nav,8,false)
    window.SearchContainer=frame(window,window.Body,{Name="SearchContainer",Size=UDim2.new(1,0,0,30),BackgroundTransparency=1})
    window.Search=textbox(window,window.SearchContainer,"",{Size=UDim2.fromScale(1,1),PlaceholderText=window:_text("search"),TextSize=12})
    local searchPadding=window.Search:FindFirstChild("TextPadding")
    window._searchIcon=iconSlot(window,window.SearchContainer,nil,"search",16,U2(FIELD_PADDING,7),"Muted",function(visible) searchPadding.PaddingLeft=UDim.new(0,visible and FIELD_PADDING+22 or FIELD_PADDING) end)
    window.PageHost=frame(window,window.Body,{ BackgroundTransparency=1 })
    window.Footer=frame(window,window.Body,{ Position=UDim2.new(0,10,1,-56),Size=UDim2.new(1,-20,0,48),BackgroundTransparency=1 })
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
    window._launcherOwner={_connections={}}
    window.Launcher=button(window,window._launcherOwner,window.Root,"UI",{ Position=U2(16,60),Size=U2(44,38),Visible=false,ZIndex=30 },function()
        if not window._launcherSuppressClick then window:Show() end
    end)
    local launcherHandle=button(window,window,window.Launcher,"::",{Position=U2(0,-14),Size=UDim2.new(1,0,0,14),TextSize=11,ZIndex=31})
    local function dragLauncher(input)
        if not pointer(input) or window._dialog then return end
        local start=point(input); local pos=window.Launcher.Position; local view=window.Root.AbsoluteSize
        local origin=Vector2.new(pos.X.Scale*view.X+pos.X.Offset,pos.Y.Scale*view.Y+pos.Y.Offset)
        window._launcherSuppressClick=false
        window._launcherReleaseToken=nil
        window:_beginDrag(window._launcherOwner,input,function(current)
            local delta=current-start
            if delta.X*delta.X+delta.Y*delta.Y<=16 and not window._launcherSuppressClick then return end
            window._launcherSuppressClick=true
            local view=window.Root.AbsoluteSize; local position=origin+(current-start)
            window.LauncherPosition=Vector2.new(clamp(position.X/math.max(1,view.X),0,1),clamp(position.Y/math.max(1,view.Y),0,1))
            window:_layoutFloating()
        end,function()
            window:_scheduleSave()
            if window._launcherSuppressClick then
                local token={}; window._launcherReleaseToken=token
                task.delay(.25,function() if not window.Destroyed and window._launcherReleaseToken==token then window._launcherSuppressClick=false end end)
            end
        end)
    end
    connect(window,window.Launcher.InputBegan,dragLauncher)
    connect(window,launcherHandle.InputBegan,dragLauncher)
    window.NotificationHost=frame(window,window.Root,{
        AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-16),Size=UDim2.new(0,math.min(340,math.max(220,window.Root.AbsoluteSize.X-32)),0,0),
        AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,ZIndex=80,
    })
    local noticeLayout=list(window,window.NotificationHost,8,false)
    noticeLayout.HorizontalAlignment=Enum.HorizontalAlignment.Right
    window._scanlineLayer=frame(window,window.Body,{ Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=20,Visible=window.Scanlines })
    for index=1,96 do
        frame(window,window._scanlineLayer,{ Position=UDim2.fromScale(0,index/96),Size=UDim2.new(1,0,0,1),BackgroundTransparency=.95,ZIndex=20 },"Text")
    end
    connect(window,header.InputBegan,function(input)
        if window._maximized then return end
        local p=point(input)
        if p.X>=header.AbsolutePosition.X+header.AbsoluteSize.X-104 then return end
        local position,view=window.Main.Position,window.Root.AbsoluteSize
        local start,center=p,Vector2.new(position.X.Scale*view.X+position.X.Offset,position.Y.Scale*view.Y+position.Y.Offset)
        window:_cancelTrack(window.Main,"window",false)
        window._dragRender=nil
        window:_beginDrag(window,input,function(current)
            window:_moveWindow(center+(current-start),true)
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
    if self._launcherOwner then self._launcherOwner.Destroyed=true; cleanup(self._launcherOwner) end
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

-- Description layout and help preferences share the existing control lifecycle.
do
    local compact={Toggle=true,Keybind=true,Button=true,StatCard=true,LineChart=true,BarChart=true,ProgressChart=true,SparklineChart=true}
    function Control:_captureDescriptionLayout()
        if self._descriptionLayout or self._inlineParent then return end
        local reserve
        if self.Type=="Toggle" then reserve=#self.Description>0 and 17 or 0
        elseif self.Type=="Keybind" then reserve=#self.Description>0 and 16 or 0
        elseif compact[self.Type] then reserve=#self.Description>0 and 20 or 0
        elseif self.Type=="Console" or self.Type=="Image" then reserve=18
        else reserve=20 end
        local layout={Reserve=reserve,Height=self.Frame.Size.Y.Offset,Children={}}
        for _,child in ipairs(self.Frame:GetChildren()) do
            if child:IsA("GuiObject") and child~=self.TitleLabel and child~=self.DescriptionLabel and child~=self.Icon and child~=self.InfoButton then
                layout.Children[child]={Position=child.Position,Size=child.Size}
            end
        end
        self._descriptionLayout=layout
        self.DescriptionLabel.TextWrapped=true; self.DescriptionLabel.TextTruncate=Enum.TextTruncate.None; self.DescriptionLabel.TextYAlignment=Enum.TextYAlignment.Top
        connect(self,self.Frame:GetPropertyChangedSignal("AbsoluteSize"),function() self:_layoutDescription() end)
        self:_layoutDescription()
    end
    function Control:_layoutDescription()
        local layout=self._descriptionLayout
        if not layout or self.Destroyed or self._describing or self.Type=="Separator" or self._inlineParent then return end
        self._describing=true
        if self.Type=="Label" then self:_syncHelpBadge() end
        local allowed=self._descriptionEnabled~=false and self._window.ShowDescriptions~=false and #self.Description>0
        local width=self.Frame.AbsoluteSize.X/math.max(.01,self._window._actualScale or 1)
        width=math.max(60,width+self.DescriptionLabel.Size.X.Offset)
        local height=0
        if allowed then
            local ok,size=pcall(TextService.GetTextSize,TextService,self.Description,12*(self._window.TextScale or 1),self._window.Font,Vector2.new(width,100000))
            height=ok and size.Y or 18; height=math.max(18,finite(height) and height+3 or 18)
        end
        local reserve=allowed and height+4 or 0; local delta=reserve-layout.Reserve
        self.DescriptionLabel.Visible=allowed; self.DescriptionLabel.Size=UDim2.new(1,self.DescriptionLabel.Size.X.Offset,0,height)
        local total=layout.Height+delta
        if self.Type=="Label" then
            -- SetText may contain several lines (hub descriptions and status).
            -- Height is a minimum; the text rectangle must grow with its content.
            local titleWidth=self.Frame.AbsoluteSize.X/math.max(.01,self._window._actualScale or 1)*self.TitleLabel.Size.X.Scale+self.TitleLabel.Size.X.Offset
            local ok,size=pcall(TextService.GetTextSize,TextService,self.TitleLabel.Text,self.TitleLabel.TextSize,self.TitleLabel.Font,Vector2.new(math.max(1,titleWidth),100000))
            local titleHeight
            if ok and finite(size.Y) then titleHeight=math.max(21,size.Y+3)
            else
                local lines=0
                for line in (self.TitleLabel.Text.."\n"):gmatch("(.-)\n") do
                    lines=lines+math.max(1,math.ceil(#line*self.TitleLabel.TextSize*.7/math.max(1,titleWidth)))
                end
                titleHeight=math.max(21,lines*(self.TitleLabel.TextSize+4)+3)
            end
            self.TitleLabel.Size=UDim2.new(self.TitleLabel.Size.X.Scale,self.TitleLabel.Size.X.Offset,0,titleHeight)
            self.DescriptionLabel.Position=UDim2.new(self.DescriptionLabel.Position.X.Scale,self.DescriptionLabel.Position.X.Offset,0,titleHeight+5)
            local minimum=self._explicitHeight and layout.Height or allowed and 30 or math.min(layout.Height,42)
            total=math.max(minimum,titleHeight+(allowed and height+5 or 0))
        end
        if self.Type=="Dropdown" then total=(self.Open and 272 or 80)+delta end
        if self.Type=="ColorPicker" then total=(self.Open and 334 or 80)+delta end
        for object,data in pairs(layout.Children) do
            if object.Parent and data.Position.Y.Offset>=22 then
                object.Position=UDim2.new(data.Position.X.Scale,data.Position.X.Offset,data.Position.Y.Scale,data.Position.Y.Offset+delta)
                if data.Size.Y.Scale~=0 then object.Size=UDim2.new(data.Size.X.Scale,data.Size.X.Offset,data.Size.Y.Scale,data.Size.Y.Offset-data.Size.Y.Scale*delta) end
            end
        end
        self._descriptionDelta=delta
        self.Frame.Size=UDim2.new(self.Frame.Size.X.Scale,self.Frame.Size.X.Offset,0,math.max(28,total))
        self:_syncHelpBadge(); self._describing=false
    end
    function Control:SetDescriptionVisible(value)
        assert(type(value)=="boolean","Description visibility must be boolean")
        self._descriptionEnabled=value; self:_layoutDescription(); return self
    end
    function Control:_syncHelpBadge()
        if not self.Tooltip or self._inlineParent then return end
        if not self.InfoButton then
            self.TitleLabel.Size=UDim2.new(self.TitleLabel.Size.X.Scale,self.TitleLabel.Size.X.Offset-22,self.TitleLabel.Size.Y.Scale,self.TitleLabel.Size.Y.Offset)
            self.InfoButton=pixelButton(self._window,self,self.Frame,"?","info",{Size=U2(20,20),ZIndex=self.TitleLabel.ZIndex+2},function()
                self._touchWasLongPress=true
                if self._window._tooltipOwner==self then self:HideTooltip() else self:ShowTooltip() end
            end)
            connect(self,self.InfoButton.TouchLongPress,function(positions,state)
                if state==Enum.UserInputState.Begin and positions[1] then self._touchWasLongPress=true; self._window:_showTooltip(self,positions[1],"touch") end
            end)
        end
        self.InfoButton.Visible=self._window.TooltipsEnabled~=false
        local p,s=self.TitleLabel.Position,self.TitleLabel.Size
        self.InfoButton.Position=UDim2.new(p.X.Scale+s.X.Scale,p.X.Offset+s.X.Offset+2,0,1)
    end
    function Window:SetDescriptions(value)
        assert(type(value)=="boolean","ShowDescriptions must be boolean")
        self.ShowDescriptions=value
        for _,control in pairs(self.Controls) do control:_layoutDescription() end
        self:_syncSettings(); self:_scheduleSave(); return self
    end
    function Window:SetTooltips(options)
        assert(type(options)=="table","Tooltip preferences must be a table")
        local enabled=options.Enabled; local delay=options.Delay or self.TooltipDelay; local width=options.MaxWidth or self.TooltipMaxWidth
        assert(enabled==nil or type(enabled)=="boolean","Tooltip Enabled must be boolean")
        assert(finite(delay) and delay>=0 and delay<=3 and finite(width) and width>=160 and width<=640,"Invalid tooltip preferences")
        if enabled~=nil then self.TooltipsEnabled=enabled end
        self.TooltipDelay=delay; self.TooltipMaxWidth=width; self:_hideTooltip()
        for _,control in pairs(self.Controls) do control:_syncHelpBadge() end
        self:_syncSettings(); self:_scheduleSave(); return self
    end
    function Window:SetTextScale(value)
        assert(finite(value) and value>=.8 and value<=1.4,"TextScale must be .8–1.4")
        self.TextScale=value
        for object,size in pairs(self._textSizes) do if object.Parent then object.TextSize=size*value else self._textSizes[object]=nil end end
        for _,control in pairs(self.Controls) do control:_layoutDescription() end
        self:_syncSettings(); self:_scheduleSave(); return self
    end
    function Window:_t17(pt,en) return self._locale==translations["en-US"] and en or pt end
end

-- BEGIN RETRO170 OVERLAYS
-- One overlay owner for menus and the palette, plus predictable keyboard focus.
do
    local function within(object,root)
        while object do if object==root then return true end; object=object.Parent end
        return false
    end
    function Window:_interactionAllowed(object)
        return not self._overlay or within(object,self._overlay.Frame)
    end
    function Window:_closeOverlay(reason)
        if self._overlay then self._overlay:Close(reason or "closed") end
    end
    function Window:_newOverlay(kind)
        assert(not self.Destroyed,"Window has been destroyed")
        if self._dialog or self._binding then return nil,"Close the dialog or key capture first" end
        self:_closeOverlay("replaced"); self:_hideTooltip(); self:_hideSearchResults()
        if self._openDropdown then self._openDropdown:SetOpen(false) end
        local window=self; local owner={Kind=kind,_connections={},Scope=self:CreateScope(),Panels={}}
        owner.Frame=frame(self,self.Root,{Name=kind.."Overlay",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=200})
        owner.Backdrop=ui(self,"TextButton",{Parent=owner.Frame,Size=UDim2.fromScale(1,1),Text="",BackgroundTransparency=1,BorderSizePixel=0,Active=true,AutoButtonColor=false,ZIndex=200})
        connect(owner,owner.Backdrop.Activated,function() owner:Close("outside") end)
        function owner:Close(reason)
            if self.Destroyed then return end
            self.Destroyed=true; self.Reason=reason
            if window._overlay==self then window._overlay=nil end
            local focused=UserInputService:GetFocusedTextBox(); if focused and within(focused,self.Frame) then focused:ReleaseFocus() end
            self.Scope:Destroy()
        end
        owner.Scope:Add(function()
            cleanup(owner); for _,panel in ipairs(owner.Panels) do if panel.Owner then cleanup(panel.Owner) end end
            window:_forgetSkin(owner.Frame); owner.Frame:Destroy()
            if window._overlay==owner then window._overlay=nil end
        end)
        self._overlay=owner; return owner
    end
    function Window:_registerFocus(object,activate)
        self._focusSequence=(self._focusSequence or 0)+1
        self._focusTargets[object]={Object=object,Activate=activate,Order=self._focusSequence}
    end
    function Window:_focusObject(object)
        if not object or not object.Parent then return false end
        self._keyboardFocus=object
        if self._activeAdvanced and object.Parent~=self._activeAdvanced.Viewport then self._activeAdvanced=nil end
        if not self._focusRing or not self._focusRing.Parent then
            self._focusRing=frame(self,object,{Name="KeyboardFocus",BackgroundTransparency=1,BorderSizePixel=2,Size=UDim2.fromScale(1,1),ZIndex=190})
            self:_bind(self._focusRing,{BorderColor3="Accent"})
        else self._focusRing.Parent=object; self._focusRing.Visible=true end
        self._focusRing.BorderColor3=self:_ink("Accent",object,3)
        return true
    end
    function Window:FocusNext(reverse)
        local choices={}
        for object,entry in pairs(self._focusTargets) do
            local active=object.Parent and object.Active~=false and self:_interactionAllowed(object)
            local parent=object
            while active and parent and parent~=self.Gui do
                if parent:IsA("GuiObject") and parent.Visible==false then active=false end
                parent=parent.Parent
            end
            if active and parent==self.Gui then choices[#choices+1]=entry end
        end
        table.sort(choices,function(a,b) return a.Order<b.Order end)
        if #choices==0 then return false end
        local index=reverse and 1 or 0
        for i,entry in ipairs(choices) do if entry.Object==self._keyboardFocus then index=i; break end end
        index=(index-1+(reverse and -1 or 1))%#choices+1
        return self:_focusObject(choices[index].Object)
    end
    function Window:SetCommandKey(value) self.CommandKey=keycode(value); self:_syncSettings(); self:_scheduleSave(); return self end
    local function menuItems(items,depth,seen,budget)
        assert(type(items)=="table" and #items<=64 and depth<=4,"Menus allow 64 entries per level and four levels")
        assert(not seen[items],"Menu cannot contain a cycle"); seen[items]=true
        local result={}
        for _,item in ipairs(items) do
            budget.Count=budget.Count+1; assert(budget.Count<=256,"Menu entry limit is 256")
            assert(type(item)=="table","Menu entry must be a table")
            local value={}; for k,v in pairs(item) do value[k]=v end
            if not value.Separator then
                assert(type(value.Text)=="string" and #value.Text>=1 and #value.Text<=256,"Menu entry requires Text")
                assert(value.Callback==nil or type(value.Callback)=="function","Menu Callback must be a function")
                assert(value.Disabled==nil or type(value.Disabled)=="boolean","Menu Disabled must be boolean")
                resolveIcon(value.Icon)
                if value.Items then value.Items=menuItems(value.Items,depth+1,seen,budget) end
                assert(value.Confirm==nil or type(value.Confirm)=="string" and #value.Confirm<=4096,"Menu Confirm must be text")
            end
            result[#result+1]=value
        end
        seen[items]=nil; return result
    end
    function Window:ContextMenu(options,anchor)
        assert(type(options)=="table","ContextMenu needs options")
        local items=menuItems(options.Items or {},1,{}, {Count=0})
        local window=self; local view=self.Root.AbsoluteSize
        assert(options.Width==nil or finite(options.Width) and options.Width>=80 and options.Width<=420,"Menu Width must be 80–420")
        assert(anchor==nil or typeof(anchor)=="Vector2" or typeof(anchor)=="Instance" and anchor:IsA("GuiObject"),"Menu anchor must be a point or GUI object")
        local width=math.min(options.Width or 240,math.max(40,view.X-16))
        local position
        if typeof(anchor)=="Vector2" then position=anchor-self.Root.AbsolutePosition
        elseif typeof(anchor)=="Instance" then position=anchor.AbsolutePosition+Vector2.new(0,anchor.AbsoluteSize.Y)-self.Root.AbsolutePosition
        else position=UserInputService:GetMouseLocation()-self.Root.AbsolutePosition end
        local owner,err=self:_newOverlay("ContextMenu"); if not owner then return nil,err end
        local function trim(level)
            while #owner.Panels>=level do local panel=table.remove(owner.Panels); if panel.Owner then panel.Owner.Destroyed=true; cleanup(panel.Owner) end; window:_forgetSkin(panel.Frame); panel.Frame:Destroy() end
        end
        local openPanel
        local function choose(panel,index)
            local item=panel.Items[index]; if not item or item.Separator or item.Disabled then return false end
            if item.Items then
                local p=panel.Frame.Position; local y=panel.Rows[index].AbsolutePosition.Y-window.Root.AbsolutePosition.Y
                local x=p.X.Offset+width+4; if x+width>view.X-8 then x=p.X.Offset-width-4 end
                openPanel(item.Items,Vector2.new(x,y),panel.Level+1); return true
            end
            owner:Close("selected")
            local function run() call(window,item.Callback,item) end
            if item.Confirm then window:Confirm({Title=item.Text,Content=item.Confirm,OnConfirm=run}) else run() end
            return true
        end
        openPanel=function(entries,p,level)
            trim(level)
            local height=math.min(view.Y-16,#entries*32+12); height=math.max(44,height)
            local panel={Items=entries,Rows={},Level=level,Selection=1,Owner={_connections={}}}
            panel.Frame=frame(window,owner.Frame,{Name="ContextPanel",Position=U2(clamp(p.X,8,math.max(8,view.X-width-8)),clamp(p.Y,8,math.max(8,view.Y-height-8))),Size=U2(width,height),BorderSizePixel=1,ZIndex=210+level*3},"Surface")
            window:_bind(panel.Frame,{BorderColor3="Border"}); bevel(window,panel.Frame,false)
            local scroll=ui(window,"ScrollingFrame",{Parent=panel.Frame,Position=U2(6,6),Size=UDim2.new(1,-12,1,-12),CanvasSize=U2(0,#entries*32),ScrollBarThickness=4,BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,ZIndex=panel.Frame.ZIndex+1},{ScrollBarImageColor3="Border"})
            if #entries==0 then label(window,scroll,window:_text("empty"),{Size=UDim2.new(1,0,0,28),ZIndex=scroll.ZIndex+1},"Muted") end
            for index,item in ipairs(entries) do
                if item.Separator then frame(window,scroll,{Position=U2(4,(index-1)*32+15),Size=UDim2.new(1,-8,0,1),ZIndex=scroll.ZIndex+1},"Border")
                else
                    local node=button(window,panel.Owner,scroll,item.Text..(item.Items and "  >" or ""),{Position=U2(0,(index-1)*32),Size=UDim2.new(1,-6,0,30),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=scroll.ZIndex+1},function() choose(panel,index) end)
                    padButton(window,node,item.Icon and 32 or 10,10)
                    if item.Icon then iconSlot(window,node,item.Icon,nil,16,U2(-24,7),"Text") end
                    if item.Disabled then node.Active=false; window:_bind(node,{TextColor3="Muted"}) end
                    panel.Rows[index]=node
                end
            end
            owner.Panels[level]=panel
        end
        openPanel(items,position,1)
        function owner:Select(index) local panel=self.Panels[#self.Panels]; return choose(panel,index) end
        function owner:OnKey(key)
            local panel=self.Panels[#self.Panels]; if not panel then return true end
            if key=="Escape" then self:Close("escape")
            elseif key=="Left" and #self.Panels>1 then trim(#self.Panels)
            elseif key=="Enter" or key=="Return" or key=="Right" then choose(panel,panel.Selection)
            elseif key=="Up" or key=="Down" then
                for _=1,#panel.Items do
                    panel.Selection=(panel.Selection-1+(key=="Up" and -1 or 1))%#panel.Items+1
                    local item=panel.Items[panel.Selection]; if not item.Separator and not item.Disabled then window:_focusObject(panel.Rows[panel.Selection]); break end
                end
            else return false end
            return true
        end
        return owner
    end
    function Control:SetContextMenu(items)
        assert(type(items)=="table" or type(items)=="function","Context menu requires items or a provider")
        self._contextItems=items
        if self._contextConnected then return self end
        self._contextConnected=true
        local function show(position)
            if self.Disabled or self.Destroyed then return end
            local value=self._contextItems; if type(value)=="function" then value=value(self) end
            self._window:ContextMenu({Items=value},position)
        end
        connect(self,self.Frame.InputBegan,function(input) if input.UserInputType==Enum.UserInputType.MouseButton2 then show(point(input)) end end)
        connect(self,self.TitleLabel.TouchLongPress,function(positions,state) if state==Enum.UserInputState.Begin and positions[1] then self._touchWasLongPress=true; show(positions[1]) end end)
        return self
    end
    function Window:_advancedInput(input,processed)
        if input.UserInputType~=Enum.UserInputType.Keyboard or self._binding then return false end
        local key=input.KeyCode.Name
        if key=="LeftShift" or key=="RightShift" then self._shiftDown=true end
        if input.KeyCode==self.CommandKey and input.KeyCode~=Enum.KeyCode.Unknown and not processed and self.OpenCommandPalette then self:OpenCommandPalette(); return true end
        if self._overlay and self._overlay.OnKey then return self._overlay:OnKey(key) end
        if self._shown==false or self.Minimized or processed or self._dialog or UserInputService:GetFocusedTextBox() then return false end
        if self._activeAdvanced and self._activeAdvanced._onKey and self._activeAdvanced:_onKey(key) then return true end
        if key=="Tab" then self:FocusNext(self._shiftDown); return true end
        if key=="Escape" and self._openDropdown then self._openDropdown:SetOpen(false); return true end
        if key=="Enter" or key=="Return" or key=="Space" then
            local entry=self._keyboardFocus and self._focusTargets[self._keyboardFocus]
            if entry and entry.Object.Parent and entry.Object.Active~=false then entry.Activate(); return true end
        end
        return false
    end
    local inputBegan=Window._inputBegan
    function Window:_inputBegan(input,processed) if self:_advancedInput(input,processed) then return end; return inputBegan(self,input,processed) end
    local inputEnded=Window._inputEnded
    function Window:_inputEnded(input)
        if input.KeyCode and (input.KeyCode.Name=="LeftShift" or input.KeyCode.Name=="RightShift") then self._shiftDown=false end
        return inputEnded(self,input)
    end
    for _,name in ipairs({"Hide","Minimize"}) do
        local old=Window[name]; Window[name]=function(self,...) self:_closeOverlay(name); return old(self,...) end
    end
    local selectTab=Tab.Select
    function Tab:Select(...)
        self._window:_closeOverlay("tab"); self._window._activeAdvanced=nil; self._window._keyboardFocus=nil
        if self._window._focusRing then self._window._focusRing.Visible=false end
        return selectTab(self,...)
    end
    local dialog=Window.Dialog
    function Window:Dialog(...) self:_closeOverlay("dialog"); return dialog(self,...) end
    local destroy=Window.Destroy
    function Window:Destroy(...) self:_closeOverlay("destroyed"); return destroy(self,...) end
end

-- END RETRO170 OVERLAYS

-- BEGIN RETRO170 VIRTUAL
-- A fixed-height recycled viewport backs lists, tables and tree rows.
do
    local function dense(value,limit)
        assert(type(value)=="table" and #value<=limit,"Dataset exceeds its item limit")
        for key in pairs(value) do assert(type(key)=="number" and key%1==0 and key>=1 and key<=#value,"Dataset must be a dense array") end
        return Library._copyConfigData(value)
    end
    local function id(value)
        assert(type(value)=="string" or finite(value),"Item key must be text or a finite number")
        value=tostring(value); assert(#value>=1 and #value<=128,"Item key must be 1–128 bytes"); return value
    end
    local function columns(value)
        assert(type(value)=="table" and #value>=1 and #value<=16,"Table needs 1–16 columns")
        local result,seen={},{}
        for _,column in ipairs(value) do
            assert(type(column)=="table" and type(column.Key)=="string" and #column.Key>=1 and #column.Key<=64 and not seen[column.Key],"Column Key must be unique")
            local width=column.Width; local weight=column.Weight or 1; local minimum=column.MinWidth or 88
            assert(width==nil or finite(width) and width>=48 and width<=1200,"Column Width must be 48–1200 pixels")
            assert(finite(weight) and weight>0 and weight<=100 and finite(minimum) and minimum>=48 and minimum<=600,"Invalid column Weight/MinWidth")
            assert(column.Format==nil or type(column.Format)=="function","Column Format must be a function")
            assert(column.Sortable==nil or type(column.Sortable)=="boolean","Column Sortable must be boolean")
            seen[column.Key]=true; result[#result+1]={Key=column.Key,Title=tostring(column.Title or column.Key),Width=width,Weight=weight,MinWidth=minimum,Format=column.Format,Sortable=column.Sortable~=false}
        end
        return result
    end
    local function build(section,options,kind)
        options=options or {}; local height=options.Height or 280; local rowHeight=options.RowHeight or 32
        assert(finite(height) and height>=120 and height<=900,"View Height must be 120–900")
        assert(finite(rowHeight) and rowHeight>=28 and rowHeight<=80,"RowHeight must be 28–80")
        assert(options.Format==nil or type(options.Format)=="function","List Format must be a function")
        assert(options.GetKey==nil or type(options.GetKey)=="function","GetKey must be a function")
        local schema=kind=="DataTable" and columns(options.Columns) or nil
        assert(options.DataState==nil or Library:_isState(options.DataState),"DataState must be a RetroBox State")
        local initial=dense(options.DataState and options.DataState:Get() or options.Items or options.Rows or {},20000)
        local self=base(section,kind,options,height); self.Persist=options.Persist==true; self.Items={}; self.Keys={}; self._indices={}; self._pool={}; self._query=""; self.RowHeight=rowHeight
        self.Columns=schema; self._loading=false; self._top=26; self._sorting=nil
        local window=self._window; local searchHeight=options.Searchable==false and 0 or 34; local headerHeight=schema and 32 or 0
        self.SearchInput=textbox(window,self.Frame,"",{Position=U2(0,26),Size=UDim2.new(1,0,0,30),PlaceholderText=window:_text("search"),Visible=searchHeight>0})
        self.Header=frame(window,self.Frame,{Position=U2(0,26+searchHeight),Size=UDim2.new(1,0,0,headerHeight),BackgroundTransparency=1,Visible=schema~=nil,ClipsDescendants=true})
        self.HeaderContent=frame(window,self.Header,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1})
        self._headers={}
        self.Viewport=ui(window,"ScrollingFrame",{Parent=self.Frame,Position=U2(0,26+searchHeight+headerHeight),Size=UDim2.new(1,0,1,-34-searchHeight-headerHeight),CanvasSize=U2(0,0),CanvasPosition=Vector2.new(0,0),AutomaticCanvasSize=Enum.AutomaticSize.None,ScrollingDirection=schema and Enum.ScrollingDirection.XY or Enum.ScrollingDirection.Y,ScrollBarThickness=6,BackgroundTransparency=0,BorderSizePixel=1,ClipsDescendants=true,Active=true},{BackgroundColor3="Inset",BorderColor3="Border",ScrollBarImageColor3="Border"})
        self.EmptyLabel=label(window,self.Viewport,options.EmptyText or window:_text("noData"),{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextWrapped=true},"Muted")
        local function keyFor(item,index)
            local key=options.GetKey and options.GetKey(item,index) or type(item)=="table" and (item.Id or item.Key) or index
            return id(key)
        end
        local function display(item,index,column)
            local callback=column and column.Format or options.Format
            local value=item; if column then value=type(item)=="table" and item[column.Key] or nil end
            if callback then
                local ok,text=window:_protected(callback,{ControlId=self.Id,Phase="Format"},value,item,index)
                return ok and tostring(text or "") or window:_text("unavailable")
            end
            if column then return value==nil and "—" or tostring(value) end
            return type(item)=="table" and tostring(item.Text or item.Title or item.Name or self.Keys[index]) or tostring(item)
        end
        function self:_normalize(value)
            if value==nil then return nil end
            value=id(value); assert(self._keyIndex[value],"Unknown item key: "..value); return value
        end
        function self:_selectIndex(position,activate)
            local index=self._indices[position]; if not index or self.Disabled or self._loading then return false end
            self._cursor=position; self:SetValue(self.Keys[index]); window._activeAdvanced=self
            if activate and self._activateNode then self:_activateNode(index) end
            if self.Destroyed then return true end
            call(window,options.OnSelect,Library._copyConfigData(self.Items[index]),self.Keys[index],index)
            return true
        end
        function self:_row()
            local row={_connections={},Labels={}}; row._section=self._section
            row.Button=button(window,row,self.Viewport,"",{Size=UDim2.new(1,-8,0,rowHeight-2),TextXAlignment=Enum.TextXAlignment.Left},function()
                if not row._longConsumed then self:_selectIndex(row.Position,true) end
            end)
            local function context(position)
                if not row.Index or not self._contextItems then return end
                row._longConsumed=true; self:_selectIndex(row.Position,false)
                local items=self._contextItems
                if type(items)=="function" then items=items(Library._copyConfigData(self.Items[row.Index]),self.Keys[row.Index],self) end
                window:ContextMenu({Items=items},position)
            end
            connect(row,row.Button.InputBegan,function(input)
                if pointer(input) then row._longConsumed=false; window._activeAdvanced=self end
                if input.UserInputType==Enum.UserInputType.MouseButton2 then context(point(input)) end
            end)
            connect(row,row.Button.TouchLongPress,function(positions,state) if state==Enum.UserInputState.Begin and positions[1] then context(positions[1]) end end)
            for index=1,schema and #schema or 1 do row.Labels[index]=label(window,row.Button,"",{Position=U2(10,0),Size=UDim2.new(1,-20,1,0),TextTruncate=Enum.TextTruncate.AtEnd,TextSize=13}) end
            return row
        end
        function self:_columnLayout()
            local available=math.max(1,self.Viewport.AbsoluteSize.X/math.max(.01,window._actualScale or 1)-8)
            self._columnWidths={}
            if not schema then self._contentWidth=available; self._columnWidths[1]=available; return end
            local fixed,weight=0,0
            for _,column in ipairs(schema) do if column.Width then fixed=fixed+column.Width else weight=weight+column.Weight end end
            local x=0
            for index,column in ipairs(schema) do
                local width=column.Width or math.max(column.MinWidth,(available-fixed)*column.Weight/math.max(1,weight))
                self._columnWidths[index]=width
                if self._headers[index] then self._headers[index].Position=U2(x,0); self._headers[index].Size=U2(width-3,headerHeight-2) end
                x=x+width
            end
            self._contentWidth=x; self.HeaderContent.Position=U2(-self.Viewport.CanvasPosition.X,0); self.HeaderContent.Size=U2(x,headerHeight)
        end
        function self:_layoutColumns(row)
            local x=0
            for index,width in ipairs(self._columnWidths) do row.Labels[index].Position=U2(x+10,0); row.Labels[index].Size=UDim2.new(0,width-20,1,0); x=x+width end
        end
        function self:_render()
            if self.Destroyed or self._renderingView or self._updatingItems then return end
            self._renderingView=true
            local scale=math.max(.01,window._actualScale or 1)
            local visibleHeight=math.max(1,self.Viewport.AbsoluteSize.Y/scale)
            local first=math.floor(self.Viewport.CanvasPosition.Y/self.RowHeight)+1
            local count=math.min(64,math.ceil(visibleHeight/self.RowHeight)+2,#self._indices)
            self:_columnLayout()
            self.Viewport.CanvasSize=U2(schema and self._contentWidth+8 or 0,#self._indices*self.RowHeight)
            self.EmptyLabel.Visible=self._loading or #self._indices==0
            self.EmptyLabel.Text=self._loading and window:_text("loading") or options.EmptyText or window:_text("noData")
            for slot=1,count do
                local row=self._pool[slot]; if not row then row=self:_row(); self._pool[slot]=row end
                local position=first+slot-1; local index=self._indices[position]
                row.Position=position; row.Index=index; row.Disabled=self.Disabled or self._loading
                row.Button.Visible=index~=nil and not self._loading; row.Button.Active=not row.Disabled
                if index then
                    row.Button.Position=U2(0,(position-1)*self.RowHeight); row.Button.Size=UDim2.new(0,self._contentWidth,0,self.RowHeight-2)
                    self:_layoutColumns(row)
                    for column,labelObject in ipairs(row.Labels) do labelObject.Text=display(self.Items[index],index,schema and schema[column] or nil) end
                    local selected=self.Value==self.Keys[index]
                    window:_bind(row.Button,{BackgroundColor3=selected and "Accent" or "Inset"})
                    for _,labelObject in ipairs(row.Labels) do window:_bind(labelObject,{TextColor3=selected and "AccentText" or "Text"}) end
                    if self._renderNode then self:_renderNode(row,index) end
                end
            end
            for slot=count+1,#self._pool do self._pool[slot].Button.Visible=false; self._pool[slot].Index=nil end
            self._renderingView=false
        end
        function self:_reindex(reset)
            local indices={}
            for index,item in ipairs(self.Items) do
                local text={}
                for _,column in ipairs(schema or {false}) do text[#text+1]=display(item,index,column or nil) end
                local matches=self._query=="" or table.concat(text," "):lower():find(self._query,1,true)~=nil
                if matches and self._filter then local ok,value=window:_protected(self._filter,{ControlId=self.Id,Phase="Filter"},Library._copyConfigData(item),self.Keys[index]); matches=ok and value==true end
                if matches then indices[#indices+1]=index end
            end
            if self._sorting then
                local sort=self._sorting
                table.sort(indices,function(a,b)
                    local x,y=self.Items[a][sort.Key],self.Items[b][sort.Key]
                    if x==y then return a<b end
                    if type(x)=="number" and type(y)=="number" then return sort.Descending and x>y or not sort.Descending and x<y end
                    x,y=tostring(x or ""),tostring(y or ""); return sort.Descending and x>y or not sort.Descending and x<y
                end)
            end
            self._indices=indices; self._cursor=nil
            for position,index in ipairs(indices) do if self.Value==self.Keys[index] then self._cursor=position; break end end
            local maximum=math.max(0,#indices*self.RowHeight-self.Viewport.AbsoluteSize.Y/math.max(.01,window._actualScale or 1))
            if reset or self.Viewport.CanvasPosition.Y>maximum then self.Viewport.CanvasPosition=Vector2.new(self.Viewport.CanvasPosition.X,reset and 0 or maximum) end
            self:_render()
        end
        function self:SetItems(items)
            local values=dense(items,20000); local keys,lookup={},{}
            for index,item in ipairs(values) do
                if schema then assert(type(item)=="table","Table rows must be records") end
                local key=keyFor(item,index); assert(not lookup[key],"Duplicate item key: "..key)
                keys[index]=key; lookup[key]=index
            end
            local top=math.floor(self.Viewport.CanvasPosition.Y/self.RowHeight)+1
            local anchor=self._indices[top] and self.Keys[self._indices[top]]; local offset=self.Viewport.CanvasPosition.Y%self.RowHeight
            self._updatingItems=true
            self.Items,self.Keys,self._keyIndex=values,keys,lookup
            if self.Value and not lookup[self.Value] then self:SetValue(nil,true) end
            self._updatingItems=false; self:_reindex(false)
            if anchor then
                for position,index in ipairs(self._indices) do if self.Keys[index]==anchor then
                    local maximum=math.max(0,#self._indices*self.RowHeight-self.Viewport.AbsoluteSize.Y/math.max(.01,window._actualScale or 1))
                    local y=clamp((position-1)*self.RowHeight+offset,0,maximum)
                    if self.Viewport.CanvasPosition.Y~=y then self.Viewport.CanvasPosition=Vector2.new(self.Viewport.CanvasPosition.X,y) end
                    break
                end end
            end
            self:_render(); return self
        end
        self.SetRows=self.SetItems
        function self:SetContextMenu(items) assert(type(items)=="table" or type(items)=="function","Context menu needs items or provider"); self._contextItems=items; return self end
        function self:GetItems() return Library._copyConfigData(self.Items) end
        function self:GetSelected() local index=self.Value and self._keyIndex[self.Value]; return index and Library._copyConfigData(self.Items[index]) or nil,self.Value end
        function self:SetFilter(callback) assert(callback==nil or type(callback)=="function","Filter must be a function or nil"); self._filter=callback; self:_reindex(true); return self end
        function self:SetQuery(query) assert(type(query)=="string" and #query<=256,"Query must be up to 256 bytes"); self._query=query:lower(); self:_reindex(true); return self end
        function self:Sort(key,descending)
            assert(schema,"Sort is only supported by DataTable")
            local found=false; for _,column in ipairs(schema) do if column.Key==key and column.Sortable then found=true end end
            assert(found,"Column is not sortable: "..tostring(key)); assert(descending==nil or type(descending)=="boolean","Descending must be boolean")
            self._sorting={Key=key,Descending=descending==true}; self:_reindex(true); return self
        end
        function self:SetLoading(value) assert(type(value)=="boolean","Loading must be boolean"); self._loading=value; self:_render(); return self end
        function self:ScrollToKey(key)
            key=id(key); local found
            for position,index in ipairs(self._indices) do if self.Keys[index]==key then found=position; break end end
            if not found then return false end
            local height=self.Viewport.AbsoluteSize.Y/math.max(.01,window._actualScale or 1)
            self.Viewport.CanvasPosition=Vector2.new(self.Viewport.CanvasPosition.X,clamp((found-1)*self.RowHeight,0,math.max(0,#self._indices*self.RowHeight-height)))
            self:_render(); return true
        end
        function self:GetViewStats() return {Items=#self.Items,Filtered=#self._indices,AllocatedRows=#self._pool,RowHeight=self.RowHeight} end
        function self:_onKey(key)
            if not self.Frame.Visible or self.Destroyed or self.Disabled then return false end
            local parent=self.Frame.Parent; while parent and parent~=window.Gui do if parent:IsA("GuiObject") and parent.Visible==false then return false end; parent=parent.Parent end
            if key=="Up" or key=="Down" or key=="Home" or key=="End" or key=="PageUp" or key=="PageDown" then
                local index=self._cursor or 1
                if key=="Up" then index=index-1 elseif key=="Down" then index=index+1 elseif key=="Home" then index=1 elseif key=="End" then index=#self._indices else index=index+(key=="PageUp" and -5 or 5) end
                index=clamp(index,1,math.max(1,#self._indices)); self:_selectIndex(index,false)
                local source=self._indices[index]; if source then self:ScrollToKey(self.Keys[source]) end
                return true
            elseif key=="Enter" or key=="Return" then return self:_selectIndex(self._cursor or 1,true) end
            return false
        end
        if schema then
            for index,column in ipairs(schema) do
                local node=button(window,self,self.HeaderContent,column.Title,{Position=U2(0,0),Size=U2(100,headerHeight-2),TextTruncate=Enum.TextTruncate.AtEnd,TextSize=12},function()
                    if column.Sortable then self:Sort(column.Key,self._sorting and self._sorting.Key==column.Key and not self._sorting.Descending or false) end
                end)
                self._headers[index]=node; if not column.Sortable then node.Active=false end
            end
        end
        connect(self,self.Viewport:GetPropertyChangedSignal("CanvasPosition"),function() self:_render() end)
        connect(self,self.Viewport:GetPropertyChangedSignal("AbsoluteSize"),function() self:_render() end)
        connect(self,self.SearchInput:GetPropertyChangedSignal("Text"),function() self:SetQuery(self.SearchInput.Text:sub(1,256)) end)
        self:Manage(function() for _,row in ipairs(self._pool) do row.Destroyed=true; cleanup(row) end; if window._activeAdvanced==self then window._activeAdvanced=nil end end)
        self._callback=options.Callback; self._listeners={}; self._keyIndex={}
        local loaded,loadError=pcall(self.SetItems,self,initial)
        if not loaded then self:Destroy(); error(loadError,2) end
        local value=options.Default; init(self,options,value)
        -- Data updates have a separate source; selection stays a normal flag.
        if options.DataState then
            assert(Library:_isState(options.DataState),"DataState must be a RetroBox State")
            self:Manage(options.DataState:Subscribe(function(value) self:SetItems(value) end,true),"Disconnect")
        end
        return self
    end
    function Section:AddVirtualList(options) return build(self,options,"VirtualList") end
    function Section:AddDataTable(options) return build(self,options,"DataTable") end
    function Section:AddTreeView(options)
        options=options or {}; assert(options.NodesState==nil or Library:_isState(options.NodesState),"NodesState must be a RetroBox State"); local parameters={}; for k,v in pairs(options) do parameters[k]=v end
        parameters.Items={}; parameters.Rows=nil; parameters.Default=nil; parameters.State=nil; parameters.DataState=nil; parameters.Format=function(item) return string.rep("  ",item.Depth)..item.Text end
        parameters.GetKey=function(item) return item.Id end
        local self=build(self,parameters,"TreeView"); self.Nodes={}; self._expanded={}; self._nodesById={}; self._allNodes={}
        local function flatten(nodes,expanded,query)
            local result={}
            local function visit(node,depth)
                local match=query=="" or node.Text:lower():find(query,1,true)~=nil
                local children={}; if expanded[node.Id] or query~="" then for _,child in ipairs(node.Children) do
                    local before=#result; visit(child,depth+1)
                    if #result>before then for i=before+1,#result do children[#children+1]=result[i] end; for i=#result,before+1,-1 do result[i]=nil end end
                end end
                if match or #children>0 then result[#result+1]={Id=node.Id,Text=node.Text,Depth=depth,HasChildren=#node.Children>0,Expanded=expanded[node.Id]==true,Icon=node.Icon}; for _,child in ipairs(children) do result[#result+1]=child end end
            end
            for _,node in ipairs(nodes) do visit(node,0) end
            return result
        end
        function self:_rebuildTree()
            local selected=self.Value
            self:SetItems(flatten(self.Nodes,self._expanded,self._treeQuery or ""))
            if selected and self._keyIndex[selected] then self:SetValue(selected,true) end
        end
        function self:SetNodes(value)
            value=dense(value,5000); local map,all={},{}; local count=0
            local function normalize(nodes,parent,depth)
                assert(depth<=16,"Tree depth limit is 16")
                local result={}
                for _,node in ipairs(nodes) do
                    count=count+1; assert(count<=5000 and type(node)=="table","Tree node limit is 5000")
                    local key=id(node.Id); assert(not map[key],"Duplicate node Id: "..key); resolveIcon(node.Icon)
                    local text=tostring(node.Text or node.Title or key); assert(#text<=2048,"Node text is too long")
                    local item={Id=key,Text=text,Icon=node.Icon,Parent=parent}; map[key]=item; all[#all+1]=item
                    item.Children=normalize(node.Children or {},key,depth+1); result[#result+1]=item
                end
                return result
            end
            local nodes=normalize(value,nil,0); self.Nodes,self._nodesById,self._allNodes=nodes,map,all
            for key in pairs(self._expanded) do if not map[key] then self._expanded[key]=nil end end
            self:_rebuildTree(); return self
        end
        function self:SetExpanded(key,value)
            key=id(key); assert(self._nodesById[key],"Unknown tree node")
            assert(type(value)=="boolean","Expanded must be boolean"); self._expanded[key]=value; self:_rebuildTree(); return self
        end
        function self:IsExpanded(key) return self._expanded[id(key)]==true end
        function self:ExpandAll(value) value=value~=false; for _,node in ipairs(self._allNodes) do self._expanded[node.Id]=value end; self:_rebuildTree(); return self end
        function self:SetQuery(query) assert(type(query)=="string" and #query<=256,"Tree query must be up to 256 bytes"); self._treeQuery=query:lower(); self:_rebuildTree(); return self end
        function self:_activateNode(index) local item=self.Items[index]; if item and item.HasChildren then self:SetExpanded(item.Id,not self:IsExpanded(item.Id)) end end
        function self:_renderNode(row,index)
            local item=self.Items[index]
            if not row.NodeIcon then row.NodeIcon=iconSlot(self._window,row.Button,false,nil,16,U2(10,7),"Text") end
            row.NodeIcon.Frame.Position=U2(10+item.Depth*12,7)
            row.NodeIcon:Set(item.Icon or (item.HasChildren and (item.Expanded and "chevron-down" or "chevron-right") or false))
            row.NodeIcon:SetRole(self.Value==item.Id and "AccentText" or "Text")
            row.Labels[1].Position=U2(32+item.Depth*12,0); row.Labels[1].Size=UDim2.new(1,-42-item.Depth*12,1,0); row.Labels[1].Text=item.Text
        end
        local onKey=self._onKey
        function self:_onKey(key)
            local item=self.Value and self._nodesById[self.Value]
            if item and key=="Right" and #item.Children>0 then self:SetExpanded(item.Id,true); return true end
            if item and key=="Left" then if self:IsExpanded(item.Id) then self:SetExpanded(item.Id,false) elseif item.Parent and self._keyIndex[item.Parent] then self:SetValue(item.Parent); self:ScrollToKey(item.Parent) end; return true end
            return onKey(self,key)
        end
        local ready,reason=pcall(function()
            self:SetNodes(options.Nodes or {}); if options.Default then self:SetValue(options.Default,true) end
            if options.State then self:BindState(options.State,{TwoWay=options.TwoWay~=false}) end
        end)
        if not ready then self:Destroy(); error(reason,2) end
        if options.NodesState then self:Manage(options.NodesState:Subscribe(function(value) self:SetNodes(value) end,true),"Disconnect") end
        return self
    end
end

-- END RETRO170 VIRTUAL

-- BEGIN RETRO170 THEMES
-- Local editable theme catalogs persist in the normal profile envelope.
do
    local official={Retro98=true,Terminal=true,GameBoy=true,Paper=true,Midnight=true,Monokai=true,Hacker=true,Dracula=true,Nord=true,Sakura=true,Ocean=true,Amber=true}
    local function themeName(name)
        assert(type(name)=="string" and #name>=1 and #name<=48 and not name:find("[%c]") and not name:match("^__retrobox/"),"Theme name must be 1–48 bytes without control characters")
        return name
    end
    local function colors(value)
        assert(type(value)=="table","Theme colors must be a table")
        local result={}
        for _,role in ipairs(roleNames) do assert(value[role]~=nil,"Missing theme color: "..role); result[role]=parseColor(value[role]) end
        for role in pairs(value) do assert(result[role],"Unknown theme color: "..tostring(role)) end
        return result
    end
    local function encodeColors(value)
        local result={}; for _,role in ipairs(roleNames) do result[role]=hex(value[role]) end; return result
    end
    function Window:GetThemeRoles() return copy(roleNames) end
    function Window:GetThemeColors(name)
        local value=self._themeOverrides[name] or Library.Themes[name]; assert(value,"Unknown theme: "..tostring(name)); return copy(value)
    end
    function Window:CreateTheme(name,baseName)
        themeName(name); baseName=baseName or self.Theme
        assert(not official[name] and not self._customThemes[name] and not Library.Themes[name] and not self._themeOverrides[name],"Theme name already exists or is official")
        local count=0; for _ in pairs(self._customThemes) do count=count+1 end; assert(count<32,"Custom theme limit is 32")
        local value=self:GetThemeColors(baseName)
        self._customThemes[name]={Base=baseName,Colors=copy(value),Original=copy(value)}; self._themeOverrides[name]=copy(value)
        self:_syncSettings(); self:_scheduleSave(); return name
    end
    function Window:DuplicateTheme(source,name) return self:CreateTheme(name,source) end
    function Window:SetThemeColor(name,role,color)
        local theme=self._customThemes[name]; assert(theme and not official[name],"Only local custom themes can be edited")
        assert(theme.Colors[role],"Unknown theme role: "..tostring(role)); color=parseColor(color)
        theme.Colors[role]=color; self._themeOverrides[name][role]=color
        if self.Theme==name then if role=="Accent" then self.Accent=nil end; self:_applyTheme() end
        self:_scheduleSave(); if self._themeStudio then self._themeStudio:Refresh() end; return self
    end
    function Window:RestoreTheme(name)
        local theme=self._customThemes[name]; assert(theme,"Only local custom themes can be restored")
        theme.Colors=copy(theme.Original); self._themeOverrides[name]=copy(theme.Original)
        if self.Theme==name then self:_applyTheme() end
        self:_scheduleSave(); if self._themeStudio then self._themeStudio:Refresh() end; return self
    end
    function Window:DeleteTheme(name)
        local theme=self._customThemes[name]; assert(theme and not official[name],"Official or unknown themes cannot be deleted")
        if self.Theme==name then self:SetTheme((self._themeOverrides[theme.Base] or Library.Themes[theme.Base]) and theme.Base or "Retro98") end
        self._customThemes[name]=nil; self._themeOverrides[name]=nil
        self:_syncSettings(); self:_scheduleSave(); if self._themeStudio then self._themeStudio:Refresh() end; return self
    end
    function Window:ExportTheme(name)
        name=name or self.Theme; themeName(name)
        local record=self._customThemes[name]
        return HttpService:JSONEncode({Library="RetroBox Theme",Schema=1,Name=name,Base=record and record.Base or name,Colors=encodeColors(self:GetThemeColors(name))})
    end
    function Window:ImportTheme(source,options)
        options=options or {}
        local ok,result=pcall(function()
            assert(type(options)=="table","ImportTheme options must be a table")
            assert(type(source)~="string" or #source<=16384,"Theme payload exceeds 16 KiB")
            local data=Library._copyConfigData(type(source)=="string" and HttpService:JSONDecode(source) or source)
            assert(type(data)=="table" and data.Library=="RetroBox Theme" and data.Schema==1,"Unsupported theme format")
            assert(#HttpService:JSONEncode(data)<=16384,"Theme payload exceeds 16 KiB")
            local name=themeName(options.Name or data.Name); assert(not official[name] and not Library.Themes[name],"Imported themes cannot overwrite registered or official themes")
            assert(options.Replace==nil or type(options.Replace)=="boolean","Replace must be boolean")
            local existing=self._customThemes[name]; assert(not existing or options.Replace,"Custom theme already exists")
            local value=colors(data.Colors)
            local count=0; for _ in pairs(self._customThemes) do count=count+1 end; assert(existing or count<32,"Custom theme limit is 32")
            local base=type(data.Base)=="string" and data.Base or "Retro98"; themeName(base)
            self._customThemes[name]={Base=base,Colors=copy(value),Original=copy(value)}; self._themeOverrides[name]=copy(value)
            self:_syncSettings(); if self.Theme==name then self:_applyTheme() end
            self:_scheduleSave(); return name
        end)
        return ok,result
    end
    function Window:CheckThemeContrast(name)
        local value=self:GetThemeColors(name or self.Theme); local results={}
        for _,background in ipairs({"Background","Surface","Inset","Highlight"}) do
            for _,role in ipairs({"Text","Muted"}) do local ratio=Library:ContrastRatio(value[role],value[background]); results[#results+1]={Role=role,Surface=background,Ratio=ratio,Target=4.5,Pass=ratio>=4.5} end
        end
        for _,role in ipairs({"Success","Danger","Accent"}) do local ratio=Library:ContrastRatio(value[role],value.Inset); results[#results+1]={Role=role,Surface="Inset",Ratio=ratio,Target=role=="Accent" and 3 or 4.5,Pass=ratio>=(role=="Accent" and 3 or 4.5)} end
        local ratio=Library:ContrastRatio(value.AccentText,value.Accent); results[#results+1]={Role="AccentText",Surface="Accent",Ratio=ratio,Target=4.5,Pass=ratio>=4.5}
        return results
    end
    function Window:_exportAdvanced()
        local themes={}
        for name,record in pairs(self._customThemes) do themes[name]={Base=record.Base,Colors=encodeColors(record.Colors),Original=encodeColors(record.Original)} end
        local dashboards={}; for name,widget in pairs(self._dashboards) do if not widget.Destroyed then dashboards[name]=widget:GetLayout() end end
        return {ShowDescriptions=self.ShowDescriptions,TextScale=self.TextScale,Tooltips={Enabled=self.TooltipsEnabled,Delay=self.TooltipDelay,MaxWidth=self.TooltipMaxWidth},CommandKey=self.CommandKey.Name,Themes=themes,Dashboards=dashboards}
    end
    function Window:_prepareAdvanced(value)
        if value==nil then return nil end
        value=Library._copyConfigData(value); assert(type(value)=="table","Advanced appearance must be a table")
        local result={}
        if value.ShowDescriptions~=nil then assert(type(value.ShowDescriptions)=="boolean","Invalid description preference"); result.ShowDescriptions=value.ShowDescriptions end
        if value.TextScale~=nil then assert(finite(value.TextScale) and value.TextScale>=.8 and value.TextScale<=1.4,"Invalid TextScale"); result.TextScale=value.TextScale end
        if value.Tooltips~=nil then
            local t=value.Tooltips; assert(type(t)=="table" and type(t.Enabled)=="boolean" and finite(t.Delay) and t.Delay>=0 and t.Delay<=3 and finite(t.MaxWidth) and t.MaxWidth>=160 and t.MaxWidth<=640,"Invalid tooltip preference")
            result.Tooltips=t
        end
        if value.CommandKey~=nil then result.CommandKey=keycode(value.CommandKey) end
        if value.Themes~=nil then
            assert(type(value.Themes)=="table","Custom themes must be a map"); result.Themes={}; local count=0
            for name,record in pairs(value.Themes) do
                themeName(name); count=count+1; assert(count<=32 and not official[name] and not Library.Themes[name],"Invalid or protected custom theme")
                assert(type(record)=="table","Theme record must be a table"); themeName(record.Base)
                result.Themes[name]={Base=record.Base,Colors=colors(record.Colors),Original=colors(record.Original or record.Colors)}
            end
        end
        if value.Dashboards~=nil then
            assert(type(value.Dashboards)=="table","Dashboard layouts must be a map"); result.Dashboards={}; local count=0
            for name,layout in pairs(value.Dashboards) do
                count=count+1; assert(count<=128 and type(name)=="string" and #name<=128,"Invalid dashboard Id")
                assert(type(layout)=="table" and type(layout.Order)=="table" and type(layout.Widgets)=="table","Invalid dashboard layout")
                if self._dashboards[name] then result.Dashboards[name]=self._dashboards[name]:ValidateLayout(layout)
                else result.Dashboards[name]=Library._copyConfigData(layout) end
            end
        end
        return result
    end
    function Window:_applyAdvanced(value,deferUI)
        if not value then return end
        if value.Themes then
            for name in pairs(self._customThemes) do self._themeOverrides[name]=nil end
            self._customThemes=copy(value.Themes); for name,record in pairs(value.Themes) do self._themeOverrides[name]=copy(record.Colors) end
        end
        if value.ShowDescriptions~=nil then self.ShowDescriptions=value.ShowDescriptions end
        if value.TextScale then self.TextScale=value.TextScale end
        if value.Tooltips then self.TooltipsEnabled=value.Tooltips.Enabled; self.TooltipDelay=value.Tooltips.Delay; self.TooltipMaxWidth=value.Tooltips.MaxWidth end
        if value.CommandKey then self.CommandKey=value.CommandKey end
        for name,layout in pairs(value.Dashboards or {}) do if self._dashboards[name] then self._dashboards[name]:SetLayout(layout) end end
        if not deferUI then self:_applyAdvancedUI(value) end
    end
    function Window:_applyAdvancedUI(value)
        if not value then return end
        if value.ShowDescriptions~=nil then self:SetDescriptions(value.ShowDescriptions) end
        if value.TextScale then self:SetTextScale(value.TextScale) end
        if value.Tooltips then self:SetTooltips(value.Tooltips) end
    end
    function Window:LoadThemeCatalog(name)
        if self.Destroyed then return false,"Window has been destroyed" end
        local ok,result=pcall(function()
            local source=self:_readConfigSource(name)
            local profile=self:_prepareProfile(source,{})
            local appearance=profile.Appearance or {}; assert(type(appearance)=="table","Invalid theme profile appearance")
            local advanced=self:_prepareAdvanced(appearance.Advanced)
            assert(advanced and advanced.Themes,"Profile does not contain a theme catalog")
            local target=appearance.Theme
            assert(type(target)=="string" and (advanced.Themes[target] or Library.Themes[target] or self._themeOverrides[target]),"Profile theme is unknown")
            self:_applyAdvanced({Themes=advanced.Themes},true)
            self:SetTheme(target); if self._themeStudio then self._themeStudio:_markSaved(); self._themeStudio:Refresh() end
            return target
        end)
        return ok,result
    end
    function Window:OpenThemeStudio()
        if self._themeStudio and not self._themeStudio.Destroyed then self._themeStudio.Tab:Select(); self._themeStudio:Refresh(); return self._themeStudio end
        local window=self; local manager={_connections={},Scope=self:CreateScope(),Pickers={},PreviousTab=self.ActiveTab}
        local tab=self:CreateTab({Title=self:_text("themeStudio"),Icon="palette",Columns=2,Internal=true}); manager.Tab=tab; self._themeStudio=manager; tab._toolManager=manager
        local function opts(key,title,extra)
            local result={Id="__retrobox/theme-studio/"..key,Title=title,Internal=true,Persist=false}
            for k,v in pairs(extra or {}) do result[k]=v end; return result
        end
        local choose=tab:CreateSection({Title=self:_t17("Temas","Themes"),Icon="palette"})
        manager.CloseButton=choose:AddButton(opts("close",self:_t17("Fechar editor","Close editor"),{Icon="close",Callback=function() manager:Close() end}))
        manager.Select=choose:AddDropdown(opts("select",self:_text("theme"),{Options=self:GetThemeNames(),Default=self.Theme,Callback=function(name) if name then window:SetTheme(name); manager:Refresh() end end}))
        manager.Name=choose:AddInput(opts("name",self:_t17("Nome da variação","Variation name"),{Default=self:_t17("Meu tema","My theme"),MaxLength=48}))
        local function notify(ok,value) window:Notify({Title=window:_text(ok and "success" or "error"),Content=tostring(value or ""),Kind=ok and "success" or "error"}) end
        choose:AddButton(opts("create",self:_t17("Criar / duplicar variação","Create / duplicate variation"),{Callback=function()
            local ok,name=pcall(window.DuplicateTheme,window,manager.Select:GetValue() or window.Theme,manager.Name:GetValue())
            if ok then window:SetTheme(name); manager:Refresh() end; notify(ok,name)
        end}))
        local actions=choose:CreateRow()
        actions:AddButton(opts("restore",self:_t17("Restaurar cores","Restore colors"),{Callback=function()
            local ok,err=pcall(window.RestoreTheme,window,manager.Select:GetValue()); notify(ok,ok and window:_text("ready") or err)
        end}))
        actions:AddButton(opts("delete",self:_text("delete"),{Callback=function()
            local name=manager.Select:GetValue(); if not window._customThemes[name] then notify(false,window:_t17("Temas oficiais são preservados.","Official themes are protected.")); return end
            window:Confirm({Title=window:_text("delete"),Content=name,OnConfirm=function() window:DeleteTheme(name); manager:Refresh() end})
        end}))
        manager.Contrast=choose:AddLabel(opts("contrast",self:_t17("Contraste da paleta","Palette contrast"),{Height=72}))
        local presets=tab:CreateSection({Title=self:_t17("Perfis e JSON","Profiles and JSON"),Icon="save"})
        manager.Profile=presets:AddInput(opts("profile",self:_text("profile"),{Default="themes",MaxLength=64}))
        local profiles=presets:CreateRow()
        profiles:AddButton(opts("save",self:_t17("Salvar no perfil","Save in profile"),{Callback=function()
            local name=manager.Profile:GetValue(); local known,listError=window:GetConfigNames()
            if listError then notify(false,listError); return end
            local function save() local ok,result=window:SaveConfig(name); notify(ok,ok and name or result) end
            if table.find(known,name) then window:Confirm({Title=window:_text("overwrite"),Content=name,OnConfirm=save}) else save() end
        end}))
        profiles:AddButton(opts("load",self:_t17("Carregar temas do perfil","Load themes from profile"),{Callback=function() local ok,result=window:LoadThemeCatalog(manager.Profile:GetValue()); if ok then manager:Refresh() end; notify(ok,ok and window.Theme or result) end}))
        manager.JSON=presets:AddInput(opts("json","JSON",{Multiline=true,MaxLength=16384}))
        local transfer=presets:CreateRow()
        transfer:AddButton(opts("export",self:_text("export"),{Callback=function() manager.JSON:SetValue(window:ExportTheme(manager.Select:GetValue()),true); manager.JSON.Input:CaptureFocus() end}))
        transfer:AddButton(opts("import",self:_text("import"),{Callback=function() local ok,result=window:ImportTheme(manager.JSON:GetValue(),{Name=manager.Name:GetValue()}); if ok then window:SetTheme(result); manager:Refresh() end; notify(ok,result) end}))
        local editor=tab:CreateSection({Title=self:_t17("Paleta editável","Editable palette"),Icon="sliders",Side="Right"})
        for _,role in ipairs(roleNames) do manager.Pickers[role]=editor:AddColorPicker(opts("color-"..role,role,{Default=window.Palette[role],AllowRainbow=false,AllowOpacity=false,Callback=function(color)
            if manager._refreshing then return end
            local name=manager.Select:GetValue(); if window._customThemes[name] then window:SetThemeColor(name,role,color) end
        end})) end
        local preview=tab:CreateSection({Title=self:_t17("Prévia com componentes reais","Preview with real components"),Icon="eye",Side="Right"})
        preview:AddButton(opts("preview-button",self:_t17("Botão de exemplo","Example button"),{Tooltip=window:_t17("Esta dica usa o mesmo estilo das demais.","This tooltip uses the real shared renderer."),Callback=function() window:Notify({Content=window:_text("ready")}) end}))
        preview:AddToggle(opts("preview-toggle","Toggle",{Default=true,Description=window:_t17("Texto secundário e estado ativo.","Secondary text and active state.")}))
        preview:AddSlider(opts("preview-slider","Slider",{Default=45}))
        preview:AddDropdown(opts("preview-dropdown","Dropdown",{Options={"Normal","Subtle","Off"}}))
        preview:AddInput(opts("preview-input","Input",{Default="RetroBox"}))
        preview:AddStatCard(opts("preview-card",self:_t17("Valor principal","Primary value"),{Value=1284,Subtitle=window:_t17("Texto sobre a superfície interna","Text over the inner surface"),Trend=12}))
        preview:AddLineChart(opts("preview-chart",self:_t17("Gráfico real","Real chart"),{Data={3,8,4,10},ShowLegend=true,Legend="Series"}))
        function manager:Refresh()
            if self.Destroyed or self._refreshing then return end
            self._refreshing=true; self.Select:SetOptions(window:GetThemeNames(),true); self.Select:SetValue(window.Theme,true)
            for role,picker in pairs(self.Pickers) do picker:SetValue(window.Palette[role],true); picker:SetDisabled(not window._customThemes[window.Theme]) end
            local bad=0; for _,entry in ipairs(window:CheckThemeContrast()) do if not entry.Pass then bad=bad+1 end end
            self.Contrast:SetText(bad==0 and window:_t17("Paleta com bom contraste.","Palette contrast passed.") or window:_t17("Combinações que merecem revisão: ","Combinations to review: ")..bad..window:_t17(". O texto se ajusta à superfície real.",". Ink adapts to the actual surface."))
            self._refreshing=false
        end
        function manager:_markSaved()
            self._savedCatalog=copy(window._customThemes); self._savedTheme=window.Theme
        end
        function manager:IsDirty() return not self.Destroyed and not same(self._savedCatalog,window._customThemes) end
        function manager:Close(choice,profileName)
            if self.Destroyed then return true end
            if choice=="Cancel" then return false,"cancelled" end
            if choice=="Discard" then
                local theme=window.Theme
                window:_applyAdvanced({Themes=copy(self._savedCatalog)},true)
                if not window._themeOverrides[theme] and not Library.Themes[theme] then theme=self._savedTheme end
                window:SetTheme(theme); self:Destroy(); return true
            end
            if choice=="Save" then
                local name=profileName or self.Profile:GetValue()
                local ok,reason=window:SaveConfig(name)
                if not ok then notify(false,reason); return false,reason end
                self:Destroy(); return true
            end
            assert(choice==nil,"Close choice must be Save, Discard or Cancel")
            if not self:IsDirty() then self:Destroy(); return true end
            window:Dialog({Title=window:_t17("Alterações do tema","Theme changes"),Content=window:_t17("Salvar as alterações em um perfil antes de fechar?","Save changes to a profile before closing?"),Buttons={
                {Text=window:_t17("Salvar","Save"),Callback=function() self:Close("Save") end},
                {Text=window:_t17("Descartar","Discard"),Callback=function() self:Close("Discard") end},
                {Text=window:_t17("Cancelar","Cancel"),Callback=function() self:Close("Cancel") end},
            }})
            return false,"confirmation pending"
        end
        function manager:Destroy()
            if self.Destroyed then return end; self.Destroyed=true; self.Scope:Destroy(); if window._themeStudio==self then window._themeStudio=nil end
            window._resources:Remove("theme-studio",true)
            if not self.Tab.Destroyed then self.Tab:Destroy() end
            if not window.Destroyed and self.PreviousTab and not self.PreviousTab.Destroyed and not self.PreviousTab.Hidden then self.PreviousTab:Select() end
        end
        manager.Scope:Add(function() cleanup(manager) end); self:Manage(manager,"Destroy","theme-studio")
        manager:_markSaved(); manager:Refresh(); tab:Select(); return manager
    end
    function Window:CloseThemeStudio(choice,profileName)
        if not self._themeStudio then return true end
        return self._themeStudio:Close(choice,profileName)
    end
    local saveConfig=Window.SaveConfig
    function Window:SaveConfig(...)
        local ok,result=saveConfig(self,...)
        if ok and self._themeStudio and not self._themeStudio.Destroyed then self._themeStudio:_markSaved() end
        return ok,result
    end
end

-- END RETRO170 THEMES

-- BEGIN RETRO170 DASHBOARDS
-- Widgets keep their real controls/bindings; layout changes only move/size them.
do
    local methods={"AddStatCard","AddChart","AddLineChart","AddBarChart","AddProgressChart","AddSparkline","AddProgress","AddLabel"}
    function Section:CreateDashboard(options)
        local section=self
        options=options or {}; local count=options.Columns or 2; local gap=options.Gap or 12; local stack=options.StackAt or 480
        assert(finite(count) and count%1==0 and count>=1 and count<=4,"Dashboard Columns must be 1–4")
        assert(finite(gap) and gap>=0 and gap<=32 and finite(stack) and stack>=200 and stack<=1200,"Invalid dashboard Gap/StackAt")
        local self=base(self,"Dashboard",options,30); self.Persist=false; self._count=0; self.Controls={}; self._parentSection=section; self._tab=section._tab
        self.Columns=count; self.Gap=gap; self.StackAt=stack; self.Content=frame(self._window,self.Frame,{Position=U2(0,26),Size=UDim2.new(1,0,1,-26),BackgroundTransparency=1})
        self._widgets={}; self._order={}; self._defaults={Order={},Widgets={}}; self._editable=options.Editable==true
        local window=self._window; window._dashboards[self.Id]=self
        function self:_layoutWidgets()
            if self.Destroyed or self._layingDashboard then return end
            self._layingDashboard=true
            local width=self.Content.AbsoluteSize.X/math.max(.01,window._actualScale or 1)
            local columns=width<self.StackAt and 1 or self.Columns; local column,rowY,rowHeight=0,0,0
            for _,key in ipairs(self._order) do
                local entry=self._widgets[key]; local widget=entry.Control
                if not widget.Destroyed and widget.Frame.Visible then
                    local span=math.min(columns,entry.Span)
                    if column+span>columns then rowY=rowY+rowHeight+self.Gap; column=0; rowHeight=0 end
                    local height=entry.Height+(widget._descriptionDelta or 0)
                    widget.Frame.Position=UDim2.new(column/columns,self.Gap*column/columns,0,rowY)
                    widget.Frame.Size=UDim2.new(span/columns,-self.Gap*(columns-span)/columns,0,height)
                    rowHeight=math.max(rowHeight,height); column=column+span
                    if column==columns then rowY=rowY+rowHeight+self.Gap; column=0; rowHeight=0 end
                end
            end
            local height=math.max(0,rowY+rowHeight-(column==0 and self.Gap or 0))
            self.Frame.Size=UDim2.new(1,0,0,height+30); self.Stacked=columns==1; self._layingDashboard=false
        end
        self._layout=self._layoutWidgets
        function self:GetLayout()
            local result={Order=copy(self._order),Widgets={}}
            for key,entry in pairs(self._widgets) do result.Widgets[key]={Span=entry.Span,Height=entry.Height} end
            return result
        end
        function self:ValidateLayout(value)
            value=Library._copyConfigData(value)
            assert(type(value)=="table" and type(value.Order)=="table" and #value.Order<=256 and type(value.Widgets)=="table","Invalid dashboard layout")
            local result={Order={},Widgets={}}; local seen={}
            for _,key in ipairs(value.Order) do
                assert(type(key)=="string" and #key>=1 and #key<=128 and not seen[key],"Invalid or duplicate dashboard widget Id")
                seen[key]=true; if self._widgets[key] then result.Order[#result.Order+1]=key end
            end
            for _,key in ipairs(self._order) do if not seen[key] then result.Order[#result.Order+1]=key end end
            for key,layout in pairs(value.Widgets) do
                assert(type(key)=="string" and type(layout)=="table" and finite(layout.Span) and layout.Span%1==0 and layout.Span>=1 and layout.Span<=4 and finite(layout.Height) and layout.Height>=28 and layout.Height<=900,"Invalid widget layout")
                local widget=self._widgets[key]
                if widget then assert(layout.Height>=widget.Minimum,"Widget height is too small"); result.Widgets[key]={Span=math.min(self.Columns,layout.Span),Height=layout.Height} end
            end
            for key,entry in pairs(self._widgets) do if not result.Widgets[key] then result.Widgets[key]={Span=entry.Span,Height=entry.Height} end end
            return result
        end
        function self:SetLayout(value)
            local prepared=self:ValidateLayout(value)
            self._order=prepared.Order
            for key,layout in pairs(prepared.Widgets) do
                local entry=self._widgets[key]; entry.Span=layout.Span; entry.Height=layout.Height
                if entry.Control._descriptionLayout then entry.Control._descriptionLayout.Height=layout.Height end
            end
            self:_layoutWidgets(); window:_scheduleSave(); return self
        end
        function self:SetOrder(value)
            assert(type(value)=="table" and #value==#self._order,"Order must include every widget")
            for _,key in ipairs(value) do assert(self._widgets[key],"Unknown widget in Order") end
            local layout=self:GetLayout(); layout.Order=value; return self:SetLayout(layout)
        end
        function self:SetWidgetLayout(key,layout)
            assert(self._widgets[key] and type(layout)=="table","Unknown dashboard widget")
            local value=self:GetLayout(); local old=value.Widgets[key]
            value.Widgets[key]={Span=layout.Span or old.Span,Height=layout.Height or old.Height}; return self:SetLayout(value)
        end
        function self:ResetLayout() return self:SetLayout(self._defaults) end
        local function add(method,parameters)
            parameters=parameters or {}; local span=parameters.Span or 1
            assert(finite(span) and span%1==0 and span>=1 and span<=count,"Widget Span must fit the grid")
            assert(#self._order<256,"Dashboard widget limit is 256")
            local aliases={AddLineChart="Line",AddBarChart="Bar",AddProgressChart="Progress",AddSparkline="Sparkline"}
            local widget
            if aliases[method] then
                local values={}; for k,v in pairs(parameters) do values[k]=v end; values.Type=aliases[method]
                widget=Section.AddChart(self,values)
            else widget=Section[method](self,parameters) end
            local key=widget.Id
            local minimum=widget.Type=="StatCard" and 116 or widget.Type:match("Chart$") and 64 or 28
            self._widgets[key]={Control=widget,Span=span,Height=widget.Frame.Size.Y.Offset-(widget._descriptionDelta or 0),Minimum=minimum}
            self._order[#self._order+1]=key; self._defaults.Order[#self._defaults.Order+1]=key
            self._defaults.Widgets[key]={Span=span,Height=self._widgets[key].Height}
            local destroy=widget.Destroy
            function widget:Destroy(...)
                if self.Destroyed then return end
                destroy(self,...); local entry=self
                if not self._dashboardOwner.Destroyed then
                    local dashboard=self._dashboardOwner; dashboard._widgets[self.Id]=nil
                    local index=table.find(dashboard._order,self.Id); if index then table.remove(dashboard._order,index) end
                    dashboard._defaults.Widgets[self.Id]=nil; local initial=table.find(dashboard._defaults.Order,self.Id); if initial then table.remove(dashboard._defaults.Order,initial) end
                    dashboard:_layoutWidgets()
                end
            end
            widget._dashboardOwner=self
            connect(widget,widget.Frame:GetPropertyChangedSignal("Visible"),function() self:_layoutWidgets() end)
            if self._editable then
                widget.TitleLabel.Size=UDim2.new(widget.TitleLabel.Size.X.Scale,widget.TitleLabel.Size.X.Offset-26,widget.TitleLabel.Size.Y.Scale,widget.TitleLabel.Size.Y.Offset)
                local function menu()
                    local position=table.find(self._order,key); local entries={}
                    entries[#entries+1]={Text=window:_t17("Mover antes","Move earlier"),Disabled=position==1,Callback=function()
                        local order=copy(self._order); order[position],order[position-1]=order[position-1],order[position]; self:SetOrder(order)
                    end}
                    entries[#entries+1]={Text=window:_t17("Mover depois","Move later"),Disabled=position==#self._order,Callback=function()
                        local order=copy(self._order); order[position],order[position+1]=order[position+1],order[position]; self:SetOrder(order)
                    end}
                    entries[#entries+1]={Separator=true}
                    for width=1,count do entries[#entries+1]={Text=window:_t17("Largura ","Width ")..width,Callback=function() self:SetWidgetLayout(key,{Span=width}) end} end
                    for _,height in ipairs({140,220,300}) do if height>=minimum then entries[#entries+1]={Text=window:_t17("Altura ","Height ")..height,Callback=function() self:SetWidgetLayout(key,{Height=height}) end} end end
                    entries[#entries+1]={Text=window:_t17("Restaurar layout","Restore layout"),Callback=function() self:ResetLayout() end}
                    return entries
                end
                local handle=pixelButton(window,widget,widget.Frame,"::","sliders",{Position=UDim2.new(1,-24,0,0),Size=U2(24,22)},function() window:ContextMenu({Items=menu()},widget.Frame.AbsolutePosition) end)
                widget:SetContextMenu(menu); widget.LayoutButton=handle
            end
            self:_layoutWidgets(); return widget
        end
        for _,method in ipairs(methods) do self[method]=function(_,parameters) return add(method,parameters) end end
        self:Manage(function()
            if window._dashboards[self.Id]==self then window._dashboards[self.Id]=nil end
            local children={}; for _,entry in pairs(self._widgets) do children[#children+1]=entry.Control end
            for _,child in ipairs(children) do child:Destroy() end
        end)
        connect(self,self.Content:GetPropertyChangedSignal("AbsoluteSize"),function() self:_layoutWidgets() end)
        self._listeners={}; self._callback=options.Callback
        function self:_normalize(value) return value end
        function self:_render() self:_layoutWidgets() end
        self:_captureDescriptionLayout(); return self
    end
    local search=Window.SetSearch
    function Window:SetSearch(...)
        search(self,...)
        for _,dashboard in pairs(self._dashboards or {}) do
            local visible=false
            for _,entry in pairs(dashboard._widgets) do if not entry.Control.Destroyed and entry.Control.Frame.Visible then visible=true; break end end
            dashboard.Frame.Visible=dashboard._visible and (self._query=="" or visible); dashboard:_layoutWidgets()
        end
    end
end

-- END RETRO170 DASHBOARDS

-- BEGIN RETRO170 INSPECTOR
-- Developer-only inspector: status subscriptions for lifecycle, a slow clock
-- for deadlines/resource counts, bounded tables, explicit cancellation permission.
do
    local function summary(value)
        if value==nil then return "—" end
        if type(value)~="table" then return tostring(value):sub(1,256) end
        local ok,text=pcall(HttpService.JSONEncode,HttpService,value); return ok and text:sub(1,256) or "[nonserializable result]"
    end
    function Window:GetRuntimeSnapshot()
        local result={Stats=self:GetRuntimeStats(),Tasks={},Actions={},Groups={},Resources={},Diagnostics=self:GetDiagnostics()}
        for _,job in pairs(self.Tasks) do
            local status=job:GetStatus()
            result.Tasks[#result.Tasks+1]={Id=job.Id,Status=status.Status,Requested=status.Requested,Running=status.Running,Remaining=status.Remaining,Interval=status.Interval,Result=summary(job.LastResult),Error=status.LastError or "",Reason=status.StopReason or "",ControlId=job.Options.ControlId or ""}
        end
        local seen={}
        local function action(handle)
            if seen[handle] then return end; seen[handle]=true
            local status=handle:GetStatus()
            result.Actions[#result.Actions+1]={Id=handle.Id,Group=handle.Group,Status=status.Status,Progress=status.Progress,Message=status.Message,Result=summary(handle.Result),Error=handle.Error and tostring(handle.Error) or "",ControlId=handle.Options.ControlId or ""}
        end
        for _,handle in pairs(self._actions) do action(handle) end
        for _,handle in ipairs(self._actionHistory) do action(handle) end
        for key,group in pairs(self._groups) do result.Groups[#result.Groups+1]={Id=key,Active=group.Active and group.Active.Id or "",Queued=#group.Queue} end
        local count=0
        for record in pairs(self._resources._records) do
            count=count+1; if count>256 then break end
            result.Resources[#result.Resources+1]={Id=tostring(record.Id or count),Kind=typeof(record.Resource),Method=tostring(record.Method or "cleanup"),Key=type(record.Key)=="string" and record.Key or ""}
        end
        for _,rows in ipairs({result.Tasks,result.Actions,result.Groups,result.Resources}) do table.sort(rows,function(a,b) return a.Id<b.Id end) end
        return result
    end
    function Window:OpenRuntimeInspector(options)
        options=options or {}
        assert(type(options)=="table" and (options.AllowCancel==nil or type(options.AllowCancel)=="boolean"),"Inspector AllowCancel must be boolean")
        local interval=options.Interval or 1; assert(finite(interval) and interval>=.25 and interval<=10,"Inspector Interval must be .25–10 seconds")
        if self._inspector and not self._inspector.Destroyed then self._inspector.Tab:Select(); self._inspector:Refresh(); self._inspector.Clock:Start(); return self._inspector end
        local window=self; local manager={Scope=self:CreateScope(),AllowCancel=options.AllowCancel==true,_connections={},_jobs={},_actions={}}
        local tab=self:CreateTab({Title="Runtime Inspector",Icon="terminal",Internal=true,Columns=2}); manager.Tab=tab; tab._toolManager=manager; self._inspector=manager
        local function opts(key,title,extra)
            local value={Id="__retrobox/inspector/"..key,Title=title,Internal=true,Persist=false}; for k,v in pairs(extra or {}) do value[k]=v end; return value
        end
        local overview=tab:CreateSection({Title="Overview",Icon="grid"})
        local row=overview:CreateRow()
        manager.TaskCount=row:AddStatCard(opts("task-count","Tasks",{Value=0}))
        manager.ActionCount=row:AddStatCard(opts("action-count","Actions",{Value=0}))
        manager.ResourceCount=overview:AddStatCard(opts("resources-count","Resources",{Value=0,Subtitle=window:_t17("Recursos da raiz; detalhes limitados a 256 entradas.","Root resources; detail list limited to 256 entries.")}))
        local tasks=tab:CreateSection({Title="Tasks",Icon="refresh"})
        manager.Tasks=tasks:AddDataTable(opts("tasks","Tasks",{Columns={{Key="Id",Width=160},{Key="Status",Width=140},{Key="Requested",Width=100},{Key="Remaining",Width=110,Format=function(value) return value and string.format("%.1f s",value) or "—" end},{Key="Error",Width=240}},Rows={},Height=250}))
        local controls=tasks:CreateRow()
        controls:AddButton(opts("task-details",window:_t17("Detalhes da tarefa","Task details"),{Callback=function()
            local selected=manager.Tasks:GetSelected(); if selected then manager.Details:SetValue(HttpService:JSONEncode(selected),true); manager.Details.Input:CaptureFocus() end
        end}))
        manager.Cancel=controls:AddButton(opts("cancel-task",window:_t17("Parar selecionada","Stop selected"),{Disabled=not manager.AllowCancel,Callback=function()
            if not manager.AllowCancel then return end
            local selected=manager.Tasks:GetSelected(); if not selected then return end
            window:Confirm({Title=window:_t17("Parar tarefa?","Stop task?"),Content=selected.Id,OnConfirm=function() local job=window.Tasks[selected.Id]; if job then job:Stop("runtime inspector") end; manager:Refresh() end})
        end}))
        local actions=tab:CreateSection({Title="Actions / Groups",Icon="bolt",Side="Right"})
        manager.Actions=actions:AddDataTable(opts("actions","Actions",{Columns={{Key="Id",Width=150},{Key="Group",Width=130},{Key="Status",Width=130},{Key="Progress",Width=100},{Key="Error",Width=240}},Rows={},Height=240}))
        actions:AddButton(opts("cancel-action",window:_t17("Cancelar ação selecionada","Cancel selected action"),{Disabled=not manager.AllowCancel,Callback=function()
            if not manager.AllowCancel then return end; local selected=manager.Actions:GetSelected(); if not selected then return end
            window:Confirm({Title=window:_t17("Cancelar ação?","Cancel action?"),Content=selected.Id,OnConfirm=function() local action=window._actions[selected.Id]; if action then action:Cancel("runtime inspector") end; manager:Refresh() end})
        end}))
        manager.Groups=actions:AddDataTable(opts("groups","Groups",{Columns={{Key="Id",Width=130},{Key="Active",Width=170},{Key="Queued",Width=80}},Rows={},Height=180}))
        local resources=tab:CreateSection({Title="Resources",Icon="folder",Side="Right"})
        manager.Resources=resources:AddDataTable(opts("resources","Resources",{Columns={{Key="Id",Width=80},{Key="Kind",Width=100},{Key="Method",Width=100},{Key="Key",Width=180}},Rows={},Height=200}))
        local diagnostics=tab:CreateSection({Title="Diagnostics",Icon="warning"})
        manager.Diagnostics=diagnostics:AddDataTable(opts("diagnostics","Diagnostics",{Columns={{Key="Phase",Width=120},{Key="ControlId",Width=140},{Key="Message",Width=300}},Rows={},Height=240,GetKey=function(record,index) return record.Id or "diagnostic/"..index end}))
        manager.Details=diagnostics:AddInput(opts("details",window:_t17("Detalhes / JSON para copiar","Details / JSON to copy"),{Multiline=true,MaxLength=32768}))
        diagnostics:AddButton(opts("copy",window:_t17("Mostrar / copiar diagnóstico","Show / copy diagnostic"),{Callback=function()
            local selected=manager.Diagnostics:GetSelected(); local text=HttpService:JSONEncode(selected or manager.Snapshot.Stats)
            manager.Details:SetValue(text,true); manager.Details.Input:CaptureFocus()
            if type(setclipboard)=="function" then local ok,err=pcall(setclipboard,text); if not ok then window:Notify({Content=tostring(err),Kind="error"}) end end
        end}))
        diagnostics:AddButton(opts("focus",window:_t17("Localizar componente","Find component"),{Callback=function()
            local selected=manager.Diagnostics:GetSelected(); if selected and selected.ControlId then window:FocusControl(selected.ControlId) end
        end}))
        function manager:Refresh()
            if self.Destroyed or self._refreshing then return end
            self._refreshing=true; local snapshot=window:GetRuntimeSnapshot(); self.Snapshot=snapshot
            self.TaskCount:SetValue(snapshot.Stats.RunningTasks,true); self.ActionCount:SetValue(snapshot.Stats.Actions,true); self.ResourceCount:SetValue(snapshot.Stats.Resources,true)
            self.Tasks:SetRows(snapshot.Tasks); self.Actions:SetRows(snapshot.Actions); self.Groups:SetRows(snapshot.Groups); self.Resources:SetRows(snapshot.Resources); self.Diagnostics:SetRows(snapshot.Diagnostics)
            self._refreshing=false
        end
        function manager:RequestRefresh()
            if self.Destroyed or self._queued then return end; self._queued=true
            task.defer(function() self._queued=false; if not self.Destroyed and not window.Destroyed then self:Refresh() end end)
        end
        function manager:ObserveJob(job)
            if job.Id=="__retrobox/inspector-clock" or self._jobs[job.Id]==job then return end
            self._jobs[job.Id]=job
            self.Scope:Add(job:Subscribe(function(status)
                self:RequestRefresh()
                if status.Status=="Destroyed" then self._jobs[job.Id]=nil; self.Scope:Remove("job:"..job.Id) end
            end),"Disconnect","job:"..job.Id)
        end
        function manager:ObserveAction(action)
            if action.Finished or self._actions[action.Id]==action then self:RequestRefresh(); return end
            self._actions[action.Id]=action
            self.Scope:Add(action:Subscribe(function()
                self:RequestRefresh()
                if action.Finished then self._actions[action.Id]=nil; self.Scope:Remove("action:"..action.Id) end
            end),"Disconnect","action:"..action.Id)
        end
        function manager:Destroy()
            if self.Destroyed then return end; self.Destroyed=true
            self.Scope:Destroy(); if window._inspector==self then window._inspector=nil end
            window._resources:Remove("runtime-inspector",true)
            if not self.Tab.Destroyed then self.Tab:Destroy() end
        end
        for _,job in pairs(self.Tasks) do manager:ObserveJob(job) end
        for _,action in pairs(self._actions) do manager:ObserveAction(action) end
        manager.Scope:Add(self:OnError(function() manager:RequestRefresh() end),"Disconnect")
        manager.Clock=self:CreateTask({Id="__retrobox/inspector-clock",Interval=interval,Immediate=false,Start=true,Callback=function(ctx)
            ctx:ThrowIfCancelled(); if manager.Tab.Frame.Visible and window._shown~=false and not window.Minimized then manager:Refresh() end
        end})
        manager.Scope:Add(manager.Clock,"Destroy"); manager.Scope:Add(function() cleanup(manager) end)
        self:Manage(manager,"Destroy","runtime-inspector"); manager:Refresh(); tab:Select(); return manager
    end
    local createTask=Window.CreateTask
    function Window:CreateTask(options)
        local job=createTask(self,options); if self._inspector then self._inspector:ObserveJob(job); self._inspector:RequestRefresh() end; return job
    end
    local runAction=Window.RunAction
    function Window:RunAction(options)
        local action,err=runAction(self,options); if self._inspector then if action then self._inspector:ObserveAction(action) end; self._inspector:RequestRefresh() end; return action,err
    end
end

-- END RETRO170 INSPECTOR

-- BEGIN RETRO170 COMMANDS
-- Navigation reuses SearchControls/FocusControl; only explicitly registered
-- commands execute code. Selecting a result never silently runs another action.
do
    function Window:RegisterCommand(options)
        assert(type(options)=="table" and type(options.Id)=="string" and #options.Id>=1 and #options.Id<=128,"Command requires Id (1–128 bytes)")
        assert(type(options.Title)=="string" and #options.Title>=1 and #options.Title<=256 and type(options.Callback)=="function","Command requires Title and Callback")
        assert(options.Enabled==nil or type(options.Enabled)=="boolean" or type(options.Enabled)=="function","Command Enabled must be boolean or predicate")
        assert(options.Confirm==nil or type(options.Confirm)=="string" and #options.Confirm<=4096,"Command Confirm must be text")
        assert(options.Group==nil or type(options.Group)=="string" and #options.Group>=1 and #options.Group<=128,"Invalid command Group")
        assert(options.Policy==nil or options.Policy=="Queue" or options.Policy=="Ignore" or options.Policy=="Reject" or options.Policy=="Replace","Invalid command Policy")
        resolveIcon(options.Icon)
        self._commands=self._commands or {}; assert(not self._commands[options.Id],"Command Id already registered")
        local count=0; for _ in pairs(self._commands) do count=count+1 end; assert(count<128,"Command limit is 128")
        local window=self; local command={Id=options.Id,Title=options.Title,Description=tostring(options.Description or ""),Options=options}
        function command:Destroy()
            if self.Destroyed then return end; self.Destroyed=true
            if window._commands[self.Id]==self then window._commands[self.Id]=nil end
            window._resources:Remove("command:"..self.Id,true)
        end
        self._commands[command.Id]=command; self:Manage(command,"Destroy","command:"..command.Id); return command
    end
    function Window:ExecuteCommand(id)
        local command=self._commands and self._commands[id]; if not command or command.Destroyed then return nil,"Unknown command" end
        local enabled=command.Options.Enabled
        if type(enabled)=="function" then local ok,value=self:_protected(enabled,{Operation=id,Phase="CommandAvailability"},self); enabled=ok and value==true end
        if enabled==false then return nil,"Command is disabled" end
        local function run()
            return self:RunAction({Group=command.Options.Group or command.Id,Policy=command.Options.Policy or "Reject",
                Callback=function(ctx) return command.Options.Callback(ctx,self,command) end,
                OnComplete=function(handle)
                    if self.Destroyed then return end
                    local status=handle:GetStatus().Status
                    if status=="Completed" or status=="Failed" then self:Notify({Title=command.Title,Content=status=="Completed" and self:_text("success") or tostring(handle.Error),Kind=status=="Completed" and "success" or "error"}) end
                end})
        end
        if command.Options.Confirm then self:Confirm({Title=command.Title,Content=command.Options.Confirm,OnConfirm=run}); return nil,"confirmation pending" end
        return run()
    end
    function Window:GetCommandResults(query)
        assert(type(query)=="string" and #query<=256,"Command query must be up to 256 bytes")
        query=query:lower(); local results={}
        for _,match in ipairs(self:SearchControls(query)) do results[#results+1]={Kind="Control",TargetId=match.Control.Id,Title=match.Control.Title,Description=match.Tab.Title.." / "..match.Section.Title} end
        for index,tab in ipairs(self.Tabs) do if not tab.Hidden and not tab.Destroyed and (query=="" or tab.Title:lower():find(query,1,true)) then results[#results+1]={Kind="Tab",TargetId=tostring(index),Title=tab.Title,Description=self:_t17("Abrir aba","Open tab")} end end
        for _,command in pairs(self._commands or {}) do
            if query=="" or (command.Title.." "..command.Description):lower():find(query,1,true) then results[#results+1]={Kind="Command",TargetId=command.Id,Title=command.Title,Description=command.Description} end
        end
        table.sort(results,function(a,b) if a.Kind==b.Kind then return a.Title<b.Title end; return a.Kind<b.Kind end)
        while #results>100 do table.remove(results) end
        for index,record in ipairs(results) do record.Id="result/"..index; record.Text=record.Title.."  · "..record.Description end
        return results
    end
    function Window:OpenCommandPalette(options)
        options=options or {}; assert(type(options)=="table","Palette options must be a table")
        if self._shown==false then self:Show() end; if self.Minimized then self:Minimize(false) end
        local owner,err=self:_newOverlay("CommandPalette"); if not owner then return nil,err end
        local window=self; local view=self.Root.AbsoluteSize
        local width=math.min(600,math.max(80,view.X-24)); local height=math.min(430,math.max(120,view.Y-32))
        owner.Panel=frame(self,owner.Frame,{Position=U2(math.max(8,(view.X-width)/2),clamp(view.Y*.18,8,math.max(8,view.Y-height-8))),Size=U2(width,height),BorderSizePixel=1,ZIndex=220,ClipsDescendants=true},"Surface")
        self:_bind(owner.Panel,{BorderColor3="Border"}); bevel(self,owner.Panel,false)
        owner.Header=label(self,owner.Panel,self:_text("commandPalette"),{Position=U2(12,8),Size=UDim2.new(1,-24,0,24),ZIndex=221})
        owner.Search=textbox(self,owner.Panel,"",{Position=U2(12,40),Size=UDim2.new(1,-24,0,32),PlaceholderText=self:_text("search"),ZIndex=221})
        -- This host uses the same Section/base/viewport renderer as ordinary lists.
        local host={_window=self,_tab=nil,_count=0,_visible=true,_collapsed=false,Controls={},Content=owner.Panel}
        owner.Rows=Section.AddVirtualList(host,{Id="__retrobox/palette-results",Internal=true,Persist=false,Title="",Searchable=false,Items={},Height=math.max(120,height-78),RowHeight=34})
        owner.Rows.Frame.ZIndex=221; owner.Search.ZIndex=225; owner.Rows.Frame.Position=U2(12,54); owner.Rows.Frame.Size=UDim2.new(1,-24,0,height-64); owner.Rows.TitleLabel.Visible=false
        owner.Rows.Viewport.ZIndex=221; owner.Rows.EmptyLabel.ZIndex=222
        owner.Scope:Add(owner.Rows,"Destroy")
        function owner:Choose(index)
            if self.Destroyed then return false,"Palette is closed" end
            local row=self.Results[index]; if not row then return false,"Result is unavailable" end
            local target=self._tabs and self._tabs[row.TargetId]
            self:Close("selected")
            local ok,reason
            if row.Kind=="Control" then ok,reason=window:FocusControl(row.TargetId)
            elseif row.Kind=="Tab" then
                ok=target and not target.Destroyed and not target.Hidden
                if ok then window:Show(); window:Minimize(false); target:Select() else reason="Tab is unavailable" end
            else
                local handle; handle,reason=window:ExecuteCommand(row.TargetId)
                ok=handle~=nil or reason=="confirmation pending" or reason=="ignored"
            end
            if not ok then window:Notify({Title=window:_text("error"),Content=tostring(reason or "Result is unavailable"),Kind="error"}) end
            return not not ok,reason
        end
        function owner:Refresh()
            self.Results=window:GetCommandResults(self.Search.Text:sub(1,256)); self.Selection=1; self._tabs={}
            for _,result in ipairs(self.Results) do if result.Kind=="Tab" then self._tabs[result.TargetId]=window.Tabs[tonumber(result.TargetId)] end end
            self.Rows:SetItems(self.Results)
            for _,row in ipairs(self.Rows._pool) do row.Button.ZIndex=222; for _,object in ipairs(row.Button:GetDescendants()) do if object:IsA("GuiObject") then object.ZIndex=223 end end end
            if self.Results[1] then self.Rows:SetValue(self.Results[1].Id,true) end
        end
        owner.Rows._renderNode=function(_,row)
            row.Button.ZIndex=222
            for _,object in ipairs(row.Button:GetDescendants()) do if object:IsA("GuiObject") then object.ZIndex=223 end end
        end
        owner.Rows._activateNode=function(_,index) owner.Selection=index; owner:Choose(index) end
        function owner:OnKey(key)
            if key=="Escape" then self:Close("escape"); return true end
            if key=="Enter" or key=="Return" then self:Choose(self.Selection); return true end
            if key=="Up" or key=="Down" then
                self.Selection=clamp(self.Selection+(key=="Up" and -1 or 1),1,math.max(1,#self.Results))
                local item=self.Results[self.Selection]; if item then self.Rows:SetValue(item.Id,true); self.Rows:ScrollToKey(item.Id) end
                return true
            end
            return false
        end
        connect(owner,owner.Search:GetPropertyChangedSignal("Text"),function() owner:Refresh() end)
        owner:Refresh(); owner.Search:CaptureFocus(); return owner
    end
end

-- END RETRO170 COMMANDS

-- BEGIN RETRO170 PREFERENCES
-- Preferences extend Settings/profile services; tools remain opt-in.
do
    local settings=Window._createSettings
    function Window:_createSettings()
        settings(self)
        if self._preferences17 then return end; self._preferences17=true
        local access=self._settingsControls.Scale._section; local window=self
        local function opts(key,title,extra)
            local value={Id="__retrobox/"..key,Title=title,Internal=true,Persist=false}; for k,v in pairs(extra or {}) do value[k]=v end; return value
        end
        local controls=self._settingsControls
        controls.Descriptions=access:AddToggle(opts("show-descriptions",self:_text("descriptions"),{Default=self.ShowDescriptions,Callback=function(value) window:SetDescriptions(value) end}))
        controls.Tooltips=access:AddToggle(opts("tooltips",self:_text("tooltips"),{Default=self.TooltipsEnabled,Callback=function(value) window:SetTooltips({Enabled=value}) end}))
        controls.TooltipDelay=access:AddSlider(opts("tooltip-delay",self:_text("tooltipDelay"),{Default=self.TooltipDelay,Min=0,Max=3,Step=.05,Suffix=" s",Callback=function(value) window:SetTooltips({Delay=value}) end}))
        controls.TextScale=access:AddSlider(opts("text-scale",self:_text("textScale"),{Default=self.TextScale,Min=.8,Max=1.4,Step=.05,Suffix="x",Callback=function(value) window:SetTextScale(value) end}))
        controls.CommandKey=access:AddKeybind(opts("command-key",self:_text("commandPalette"),{Default=self.CommandKey,CaptureOnly=true,AllowMouse=false}))
        controls.CommandKey:Manage(controls.CommandKey:OnChanged(function(value) window:SetCommandKey(value) end),"Disconnect")
        local tools=self._settingsTab:CreateSection({Title=self:_t17("Personalização e ferramentas","Customization and tools"),Icon="sliders"})
        tools:AddButton(opts("open-theme-studio",self:_text("themeStudio"),{Icon="palette",Callback=function() window:OpenThemeStudio() end}))
        tools:AddButton(opts("open-palette",self:_text("commandPalette"),{Icon="search",Callback=function() window:OpenCommandPalette() end}))
        if self.Debug then tools:AddButton(opts("open-inspector","Runtime Inspector",{Icon="terminal",Callback=function() window:OpenRuntimeInspector() end})) end
        self:_syncSettings()
    end
    local sync=Window._syncSettings
    function Window:_syncSettings()
        sync(self)
        local controls=self._settingsControls
        if self._syncingAdvanced or not controls or not controls.Descriptions then return end
        self._syncingAdvanced=true
        controls.Descriptions:SetValue(self.ShowDescriptions,true); controls.Tooltips:SetValue(self.TooltipsEnabled,true)
        controls.TooltipDelay:SetValue(self.TooltipDelay,true); controls.TextScale:SetValue(self.TextScale,true); controls.CommandKey:SetValue(self.CommandKey,true)
        self._syncingAdvanced=false
        if self._themeStudio and not self._themeStudio._refreshing then self._themeStudio:Refresh() end
    end
    local factory=Library.CreateWindow
    function Library:CreateWindow(options)
        options=options or {}
        assert(options.RuntimeInspector==nil or type(options.RuntimeInspector)=="boolean" or type(options.RuntimeInspector)=="table","RuntimeInspector must be boolean or options")
        local window=factory(self,options); window._initial.Advanced=window:_exportAdvanced()
        if options.ThemeStudio==true then window:OpenThemeStudio() end
        if options.RuntimeInspector then window:OpenRuntimeInspector(type(options.RuntimeInspector)=="table" and options.RuntimeInspector or {}) end
        return window
    end
    for _,prototype in ipairs({Tab,Section,Row}) do
        local destroy=prototype.Destroy
        prototype.Destroy=function(self,...)
            if self._toolManager and not self._toolManager.Destroyed then self._toolManager:Destroy() end
            if self.Frame then self._window:_forgetSkin(self.Frame) end
            if self.Button then self._window:_forgetSkin(self.Button) end
            return destroy(self,...)
        end
    end
    local layout=Window._layout
    function Window:_layout(...) self:_closeOverlay("layout"); return layout(self,...) end
end

-- END RETRO170 PREFERENCES

-- BEGIN RETRO200 UPDATE CORE
local UpdateCore=(function()
-- RetroBox update protocol v1. Embedded into the standalone library and loader.
-- HTTPS origin is the publisher trust boundary. SHA-256 detects damaged bytes;
-- it is not a signature and does not protect a compromised publishing account.
local Core={ProtocolVersion=1,OfficialRoot="https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main"}
local Client={}; Client.__index=Client
local function clone(value)
    if type(value)~="table" then return value end
    local out={}; for k,v in pairs(value) do out[k]=clone(v) end; return out
end
local function integer(n) return type(n)=="number" and n==n and n>=0 and n%1==0 and n<=9007199254740991 end
local function bounded(value,maximum,name)
    assert(type(value)=="string" and #value>0 and #value<=maximum,name.." must be bounded text"); return value
end
function Core.ParseVersion(value)
    bounded(value,128,"Version")
    local base,build=value:match("^(.-)%+(.+)$"); base=base or value
    if build then
        assert(not build:find("[^%w%.%-]") and not build:find("%.%.") and build:sub(1,1)~="." and build:sub(-1)~=".","Invalid semantic version build")
    end
    local numeric,pre=base:match("^(%d+%.%d+%.%d+)%-(.+)$"); numeric=numeric or base
    local a,b,c=numeric:match("^(%d+)%.(%d+)%.(%d+)$"); assert(a,"Expected MAJOR.MINOR.PATCH")
    local parts={a,b,c}; for _,part in ipairs(parts) do assert((#part==1 or part:sub(1,1)~="0") and integer(tonumber(part)),"Invalid semantic version number") end
    local prerelease={}
    if pre then
        assert(not pre:find("[^%w%.%-]") and not pre:find("%.%.") and pre:sub(1,1)~="." and pre:sub(-1)~=".","Invalid prerelease")
        for part in pre:gmatch("[^%.]+") do
            assert(not part:match("^%d+$") or #part==1 or part:sub(1,1)~="0","Prerelease numbers cannot have leading zeroes")
            prerelease[#prerelease+1]=part
        end
    end
    return {Major=tonumber(a),Minor=tonumber(b),Patch=tonumber(c),Prerelease=prerelease,Build=build,Text=value}
end
function Core.CompareVersions(a,b)
    a=Core.ParseVersion(a); b=Core.ParseVersion(b)
    for _,k in ipairs({"Major","Minor","Patch"}) do if a[k]~=b[k] then return a[k]<b[k] and -1 or 1 end end
    if #a.Prerelease==0 and #b.Prerelease==0 then return 0 end
    if #a.Prerelease==0 then return 1 elseif #b.Prerelease==0 then return -1 end
    for i=1,math.max(#a.Prerelease,#b.Prerelease) do
        local x,y=a.Prerelease[i],b.Prerelease[i]
        if x==nil then return -1 elseif y==nil then return 1 elseif x~=y then
            local xn,yn=x:match("^%d+$"),y:match("^%d+$")
            if xn and yn then
                if #x~=#y then return #x<#y and -1 or 1 end
                return x<y and -1 or 1
            elseif xn then return -1 elseif yn then return 1 end
            return x<y and -1 or 1
        end
    end
    return 0
end
function Core.SHA256(source)
    assert(type(source)=="string","SHA256 needs bytes")
    assert(type(bit32)=="table" and type(bit32.bxor)=="function","SHA-256 needs the Luau bit32 library")
    local band,bxor,bnot,rshift,ror=bit32.band,bit32.bxor,bit32.bnot,bit32.rshift,bit32.rrotate
    local constants={
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
    }
    local h={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
    local function word(n) return string.char(rshift(n,24),band(rshift(n,16),255),band(rshift(n,8),255),band(n,255)) end
    local bits=#source*8
    local padded=source.."\128"..string.rep("\0",(55-#source)%64)..word(math.floor(bits/4294967296))..word(bits%4294967296)
    for offset=1,#padded,64 do
        local w={}
        for i=0,15 do local a,b,c,d=padded:byte(offset+i*4,offset+i*4+3); w[i+1]=a*16777216+b*65536+c*256+d end
        for i=17,64 do
            local x,y=w[i-15],w[i-2]
            local s0=bxor(ror(x,7),ror(x,18),rshift(x,3)); local s1=bxor(ror(y,17),ror(y,19),rshift(y,10))
            w[i]=(w[i-16]+s0+w[i-7]+s1)%4294967296
        end
        local a,b,c,d,e,f,g,j=table.unpack(h)
        for i=1,64 do
            local s1=bxor(ror(e,6),ror(e,11),ror(e,25)); local ch=bxor(band(e,f),band(bnot(e),g))
            local t1=(j+s1+ch+constants[i]+w[i])%4294967296
            local s0=bxor(ror(a,2),ror(a,13),ror(a,22)); local maj=bxor(band(a,b),band(a,c),band(b,c))
            local t2=(s0+maj)%4294967296
            j,g,f,e,d,c,b,a=g,f,e,(d+t1)%4294967296,c,b,a,(t1+t2)%4294967296
        end
        local v={a,b,c,d,e,f,g,j}; for i=1,8 do h[i]=(h[i]+v[i])%4294967296 end
    end
    local out={}; for i=1,8 do out[i]=string.format("%08x",h[i]) end; return table.concat(out)
end
local function path(value)
    bounded(value,512,"Artifact path")
    assert(not value:find("[^%w_%.%/%-]") and value:sub(1,1)~="/" and value:sub(-1)~="/" and not value:find("//",1,true),"Only origin-relative paths are allowed")
    for segment in value:gmatch("[^/]+") do assert(segment~="." and segment~="..","Path traversal is forbidden") end
    return value
end
local function channel(value)
    assert(value=="stable" or value=="preview" or value=="pinned","Channel must be stable, preview or pinned"); return value
end
local function json(service,bytes,limit)
    assert(type(bytes)=="string" and #bytes>0 and #bytes<=limit,"Response is empty or exceeds its size limit")
    local value=service:JSONDecode(bytes); assert(type(value)=="table","Expected a JSON record"); return value
end
local function validate(client,m)
    local o=client.Options
    assert(type(m)=="table" and m.SchemaVersion==1 and m.Kind==o.Kind,"Unsupported distribution manifest")
    local version=Core.ParseVersion(m.Version)
    assert(version.Major==o.Major,"Incompatible release major")
    assert(o.Channel~="stable" or #version.Prerelease==0,"Stable cannot resolve a prerelease")
    assert(o.Channel=="pinned" or m.Channel==o.Channel,"Manifest belongs to a different channel")
    assert(o.Channel~="pinned" or m.Version==o.Version,"Pinned manifest does not match the requested version")
    assert(integer(m.APIVersion) and (not o.APIVersion or m.APIVersion==o.APIVersion),"Incompatible API version")
    if o.MinVersion then assert(Core.CompareVersions(m.Version,o.MinVersion)>=0,"Release is below MinVersion") end
    if o.MaxVersion then assert(Core.CompareVersions(m.Version,o.MaxVersion)<0,"Release is at or above exclusive MaxVersion") end
    if o.HubId then assert(m.HubId==o.HubId,"Manifest belongs to a different hub") end
    bounded(m.Build,128,"Build")
    local a=m.Artifact; assert(type(a)=="table","Artifact metadata is missing"); path(a.Path)
    assert(type(a.SHA256)=="string" and #a.SHA256==64 and a.SHA256:match("^[0-9a-f]+$"),"Invalid SHA-256 digest")
    assert(integer(a.Bytes) and a.Bytes>0 and a.Bytes<=o.MaxArtifactBytes,"Invalid artifact length")
    assert(o.Kind=="RetroBox" or type(m.Library)=="table","Hub manifest needs RetroBox compatibility metadata")
    if m.Library then
        assert(type(m.Library)=="table" and type(o.LibraryVersion)=="string","Library compatibility cannot be determined")
        assert(type(m.Library.MinVersion)=="string" and integer(m.Library.APIVersion),"Hub manifest needs a minimum RetroBox version and API")
        if m.Library.MinVersion then assert(Core.CompareVersions(o.LibraryVersion,m.Library.MinVersion)>=0,"Hub needs a newer RetroBox") end
        if m.Library.MaxVersion then assert(Core.CompareVersions(o.LibraryVersion,m.Library.MaxVersion)<0,"Hub does not support this RetroBox") end
        if m.Library.APIVersion then assert(m.Library.APIVersion==o.LibraryAPIVersion,"Hub needs a different RetroBox API") end
    end
    return clone(m)
end
function Core.New(options)
    options=options or {}; assert(type(options)=="table","Updater options must be a table")
    local o={}; for k,v in pairs(options) do o[k]=v end
    o.Channel=channel(o.Channel or "stable"); o.Kind=o.Kind or "RetroBox"; o.Major=o.Major or 2
    o.APIVersion=o.APIVersion or (o.Kind=="RetroBox" and 2 or 1)
    assert(o.Kind=="RetroBox" or o.Kind=="Hub" or o.Kind=="HubCatalog","Unsupported update kind")
    assert(integer(o.Major) and o.Major>0,"Major must be a positive integer")
    if o.Kind~="RetroBox" then assert(o.Root,"Hub updates need an explicit publisher Root") end
    o.Root=bounded(o.Root or Core.OfficialRoot,1024,"Root"):gsub("/+$","")
    assert(o.Root:match("^https://[%w%.%-]+/[A-Za-z0-9_%.%/%-]+$") and not o.Root:find("/%.%./") and not o.Root:find("/%.%./?$"),"Root must be an explicit HTTPS origin and path without traversal")
    if o.Version then Core.ParseVersion(o.Version) end
    assert(o.Channel~="pinned" or o.Version,"Pinned needs Version")
    if o.CurrentVersion then Core.ParseVersion(o.CurrentVersion) end
    if o.MinVersion then Core.ParseVersion(o.MinVersion) end; if o.MaxVersion then Core.ParseVersion(o.MaxVersion) end
    assert(o.APIVersion==nil or integer(o.APIVersion),"APIVersion must be an integer")
    if o.ManifestPath then path(o.ManifestPath) end
    o.MaxArtifactBytes=o.MaxArtifactBytes or (o.Kind=="HubCatalog" and 524288 or 2097152)
    assert(integer(o.MaxArtifactBytes) and o.MaxArtifactBytes>=1 and o.MaxArtifactBytes<=8388608,"MaxArtifactBytes must be 1–8388608")
    o.Service=o.Service or game:GetService("HttpService")
    o.Fetch=o.Fetch or function(url)
        local ok,fn=pcall(function() return game.HttpGet end); assert(ok and type(fn)=="function","Environment does not provide HttpGet")
        return fn(game,url,true)
    end
    assert(type(o.Fetch)=="function","Fetch must be a developer function")
    assert(o.Cache==nil or o.Cache==false or o.Cache==true or type(o.Cache)=="table","Cache must be boolean or an adapter")
    if type(o.Cache)=="table" then assert(type(o.Cache.Get)=="function" and type(o.Cache.Set)=="function","Cache needs Get and Set") end
    local self=setmetatable({Options=o,Report={State="Idle",Channel=o.Channel,CurrentVersion=o.CurrentVersion,Kind=o.Kind,Root=o.Root}},Client)
    return self
end
function Client:GetStatus() return clone(self.Report) end
function Client:SetChannel(value,version)
    assert(not self._busy,"Cannot change channel during an update operation")
    value=channel(value); if version then Core.ParseVersion(version) end
    assert(value~="pinned" or version or self.Options.Version,"Pinned needs Version")
    self.Options.Channel=value; if version then self.Options.Version=version end
    self._manifest=nil; self.Report={State="Idle",Channel=value,CurrentVersion=self.Options.CurrentVersion,Kind=self.Options.Kind,Root=self.Options.Root}
    return self
end
function Client:_manifestPath()
    if self.Options.ManifestPath then return self.Options.ManifestPath end
    if self.Options.Channel=="pinned" then return "dist/releases/"..self.Options.Version.."/manifest.json" end
    return "dist/channels/"..self.Options.Channel.."/v"..self.Options.Major..".json"
end
function Client:Check()
    if self._busy then return nil,"Update operation is already running" end
    self._busy=true; self.Report.State="Checking"; self.Report.LastCheck=os.time(); self.Report.Error=nil
    self.Report.Compatible=nil; self.Report.AvailableVersion=nil; self.Report.Build=nil
    local ok,result=pcall(function() return validate(self,json(self.Options.Service,self.Options.Fetch(self.Options.Root.."/"..self:_manifestPath()),65536)) end)
    self._busy=false
    if not ok then self.Report.State="Failed"; self.Report.Error=tostring(result); return nil,self.Report.Error end
    self._manifest=result; self.Report.AvailableVersion=result.Version; self.Report.Build=result.Build; self.Report.Compatible=true
    local current=self.Options.CurrentVersion
    local comparison=current and Core.CompareVersions(result.Version,current) or 1
    self.Report.State=comparison==0 and "UpToDate" or comparison<0 and "RollbackAvailable" or "Available"
    return clone(result)
end
function Client:_cacheKey()
    local o=self.Options
    return Core.SHA256(o.Root.."|"..self:_manifestPath().."|"..o.Kind.."|"..tostring(o.HubId or ""))
end
function Client:_cache(get,value)
    local o=self.Options; if not o.Cache then return nil end
    local key=self:_cacheKey()
    if type(o.Cache)=="table" then if get then return o.Cache:Get(key) else return o.Cache:Set(key,value) end end
    local env=_G; if type(getgenv)=="function" then local ok,v=pcall(getgenv); if ok and type(v)=="table" then env=v end end
    env.__RetroBoxUpdateCache=env.__RetroBoxUpdateCache or {}; local memory=env.__RetroBoxUpdateCache
    self.Report.Cache="session"
    local fileMode=type(readfile)=="function" and type(writefile)=="function" and type(makefolder)=="function"
    if fileMode then
        local folder=path(o.CacheFolder or "RetroBox/Updates"); local filename=folder.."/"..key..".json"
        self.Report.Cache="file"
        if get then
            if memory[key] then return clone(memory[key]) end
            local ok,bytes=pcall(readfile,filename)
            if ok then return json(o.Service,bytes,o.MaxArtifactBytes*3+65536) end
        else
            local accumulated=""; for segment in folder:gmatch("[^/]+") do accumulated=accumulated=="" and segment or accumulated.."/"..segment; pcall(makefolder,accumulated) end
            writefile(filename,o.Service:JSONEncode(value)); memory[key]=clone(value)
        end
    elseif get then return clone(memory[key]) else memory[key]=clone(value) end
end
function Client:_verified(m,bytes,mode)
    m=validate(self,m)
    assert(type(bytes)=="string" and #bytes==m.Artifact.Bytes and #bytes<=self.Options.MaxArtifactBytes,"Artifact length differs from the manifest")
    assert(Core.SHA256(bytes)==m.Artifact.SHA256,"Artifact SHA-256 does not match")
    if mode=="json" then
        assert(m.Kind=="HubCatalog","Only catalogs can be loaded as JSON")
        local value=json(self.Options.Service,bytes,self.Options.MaxArtifactBytes)
        assert(value.SchemaVersion==1 and value.Kind=="HubCatalog" and value.Version==m.Version and value.HubId==m.HubId,"Catalog does not match its manifest")
        if self.Options.ValidateData then assert(self.Options.ValidateData(value,m)==true,"Catalog validation failed") end
        return value,m
    end
    assert(type(loadstring)=="function","Environment does not provide loadstring")
    local chunk,reason=loadstring(bytes,"@RetroBox-"..m.Kind.."-"..m.Version); assert(chunk,"Artifact compilation failed: "..tostring(reason))
    local value=chunk()
    assert(type(value)=="table" and value.Version==m.Version,"Artifact reports a different version")
    if m.Kind=="RetroBox" then assert(type(value.CreateWindow)=="function" and type(value.CreateScriptHub)=="function" and value.APIVersion==m.APIVersion,"Artifact does not implement the declared RetroBox API")
    elseif m.Kind=="Hub" then assert(type(value.Start)=="function","Hub module must return Version and Start")
    else error("A catalog must be loaded as data") end
    return value,m
end
function Client:Load(mode)
    assert(mode==nil or mode=="json","Load mode must be json or omitted")
    local m,checkError=self:Check(); if self._busy then return nil,checkError end
    self._busy=true
    local ok,value,verified,bytes=pcall(function()
        assert(m,checkError); local source=self.Options.Fetch(self.Options.Root.."/"..m.Artifact.Path)
        local item,manifest=self:_verified(m,source,mode); return item,manifest,source
    end)
    if ok then
        self.Report.State="Loaded"; self.Report.CurrentVersion=verified.Version; self.Report.AvailableVersion=verified.Version; self.Report.Fallback=false; self.Report.Error=nil
        self.Options.CurrentVersion=verified.Version
        local saved,reason=pcall(self._cache,self,false,{Manifest=verified,Source=bytes,Root=self.Options.Root})
        if not saved then self.Report.CacheError=tostring(reason) end
        self._busy=false; return value,self:GetStatus()
    end
    local liveError=tostring(value)
    if self.Options.Cache and self.Options.Fallback~=false then
        local recovered,item,manifest=pcall(function()
            local cached=self:_cache(true); assert(type(cached)=="table" and cached.Root==self.Options.Root,"No validated cache for this origin")
            return self:_verified(cached.Manifest,cached.Source,mode)
        end)
        if recovered then
            self.Report.State="Fallback"; self.Report.CurrentVersion=manifest.Version; self.Report.Fallback=true; self.Report.Error=liveError
            self.Options.CurrentVersion=manifest.Version; self._busy=false
            warn("[RetroBox] Using validated cached "..self.Options.Kind.." "..manifest.Version..": "..liveError)
            return item,self:GetStatus()
        end
        self.Report.CacheError=tostring(item)
    end
    self.Report.State="Failed"; self.Report.Error=liveError; self._busy=false; return nil,liveError
end
Core.Client=Client
return Core

end)()
-- Public update APIs. All network work is explicit or opted into by the hub.
do
    Library.APIVersion=2
    Library.Build="retrobox-"..Library.Version
    Library.MinimumVersion="2.0.0"
    Library.MaximumVersion="3.0.0" -- exclusive
    function Library:GetVersion() return self.Version end
    function Library:ParseVersion(value) return UpdateCore.ParseVersion(value) end
    function Library:CompareVersions(a,b) return UpdateCore.CompareVersions(a,b) end
    function Library:SHA256(bytes) return UpdateCore.SHA256(bytes) end
    function Library:CreateUpdater(options) return UpdateCore.New(options) end
    function Library:CheckForUpdates(options)
        if options or not self._distributionUpdater then
            local settings={}; for k,v in pairs(options or {}) do settings[k]=v end
            settings.Kind="RetroBox"; settings.Major=2; settings.APIVersion=2; settings.CurrentVersion=self.Version
            settings.MinVersion=settings.MinVersion or "2.0.0"; settings.MaxVersion=settings.MaxVersion or "3.0.0"
            self._distributionUpdater=UpdateCore.New(settings)
        end
        local _,reason=self._distributionUpdater:Check()
        return self._distributionUpdater:GetStatus(),reason
    end
    function Library:GetUpdateStatus()
        return self._distributionUpdater and self._distributionUpdater:GetStatus() or {State="Idle",CurrentVersion=self.Version,Channel="stable",Kind="RetroBox"}
    end
    function Library:LoadHub(options)
        assert(type(options)=="table" and options.Root,"LoadHub needs an explicit publisher Root")
        local settings={}; for k,v in pairs(options) do if k~="Settings" then settings[k]=v end end
        settings.Kind="Hub"; settings.Major=options.Major or 1; settings.LibraryVersion=self.Version; settings.LibraryAPIVersion=self.APIVersion
        local updater=UpdateCore.New(settings)
        local module,report=updater:Load()
        if not module then return nil,report end
        local ok,hub=pcall(module.Start,self,options.Settings or {})
        if not ok then return nil,"Hub initialization failed: "..tostring(hub) end
        if type(hub)~="table" or not hub.Window or type(hub.RunScript)~="function" then return nil,"Hub Start did not return a Script Hub" end
        hub.Version=module.Version; hub.CodeDistribution=report; hub._codeUpdater=updater
        return hub,report
    end
end

-- END RETRO200 UPDATE CORE

-- BEGIN RETRO190 SCRIPT HUB
-- This optional mode uses native tabs, recycled lists, flags, scopes and actions.
do
    local Hub={}; Hub.__index=Hub
    local function key(value,label)
        assert(type(value)=="string" and #value>=1 and #value<=64 and value:match("^[%w_%.%-]+$"),(label or "Id").." must be 1–64 letters, numbers, dots, underscores or hyphens")
        return value
    end
    local function text(value,maximum,label,required)
        assert(value==nil or type(value)=="string",label.." must be text")
        value=value or ""; assert(#value<=maximum and (not required or #value>0),label.." has an invalid length"); return value
    end
    local function identifier(value,label)
        if value==nil or value==false then return nil end
        assert(finite(value) and value%1==0 and value>0 and value<=9007199254740991,label.." must be a positive safe integer")
        return value
    end
    local function array(value,limit,label)
        assert(type(value)=="table",label.." must be an array")
        local n=0; for i in pairs(value) do assert(type(i)=="number" and i%1==0 and i>=1 and i<=limit,label.." has an invalid index"); n=n+1 end
        assert(n==#value and n<=limit,label.." must be a dense bounded array"); return value
    end
    local function imageURI(value)
        if value==nil or value==false then return nil end
        if type(value)=="number" then return "rbxassetid://"..string.format("%.0f",identifier(value,"Image")) end
        assert(type(value)=="string" and #value<=512,"Image must be a Roblox content identifier")
        assert(value:match("^rbxassetid://%d+$") or value:match("^rbxthumb://type=%a+&id=%d+&w=%d+&h=%d+$") or value:match("^rbxasset://[%w_/%-%.]+$"),"Image must use rbxassetid, rbxthumb or rbxasset; external web URLs are unsupported")
        return value
    end
    local function normalizeScript(value)
        assert(type(value)=="table","Script must be a record")
        local result={Id=key(value.Id,"Script Id"),Title=text(value.Title,128,"Script Title",true),Description=text(value.Description,2048,"Script Description"),Author=text(value.Author,128,"Author"),Version=text(value.Version and tostring(value.Version),64,"Version"),Status=text(value.Status,128,"Status")}
        assert(value.Callback==nil or type(value.Callback)=="function","Script Callback must be a function")
        assert(value.Enabled==nil or type(value.Enabled)=="boolean" or type(value.Enabled)=="function","Script Enabled must be a boolean or predicate")
        assert(value.Confirm==nil or type(value.Confirm)=="string" and #value.Confirm<=4096,"Script Confirm must be text")
        assert(value.CurrentGameOnly==nil or type(value.CurrentGameOnly)=="boolean","CurrentGameOnly must be boolean")
        result.Callback=value.Callback; result.Enabled=value.Enabled; result.Confirm=value.Confirm; result.CurrentGameOnly=value.CurrentGameOnly==true
        result.Icon=value.Icon or "code"; resolveIcon(result.Icon)
        result.Requires={}
        for _,cap in ipairs(array(value.Requires or {},16,"Requires")) do
            assert(cap=="HttpGet" or cap=="loadstring" or cap=="readfile" or cap=="writefile" or cap=="setclipboard","Unknown required capability: "..tostring(cap))
            result.Requires[#result.Requires+1]=cap
        end
        return result
    end
    local function normalizeGame(value,order)
        assert(type(value)=="table","Game must be a record")
        local result={Id=key(value.Id,"Game Id"),Name=text(value.Name,128,"Game Name",true),Description=text(value.Description,2048,"Game Description"),PlaceId=identifier(value.PlaceId,"PlaceId"),UniverseId=identifier(value.UniverseId,"UniverseId"),Image=imageURI(value.Image),Scripts={}}
        assert(value.Order==nil or finite(value.Order) and value.Order%1==0 and math.abs(value.Order)<=1000000,"Game Order must be an integer between -1000000 and 1000000")
        result.Order=value.Order or order; local ids={}
        for _,entry in ipairs(array(value.Scripts or {},128,"Scripts")) do local script=normalizeScript(entry); assert(not ids[script.Id],"Duplicate script Id: "..script.Id); ids[script.Id]=true; result.Scripts[#result.Scripts+1]=script end
        return result
    end
    local function normalizeGames(values)
        local result,ids,total={},{},0
        for index,value in ipairs(array(values or {},512,"Games")) do
            local gameRecord=normalizeGame(value,index); assert(not ids[gameRecord.Id],"Duplicate game Id: "..gameRecord.Id)
            ids[gameRecord.Id]=true; total=total+#gameRecord.Scripts; assert(total<=4096,"Script catalog limit is 4096 entries"); result[#result+1]=gameRecord
        end
        return result
    end
    local upper={ ["Á"]="á",["À"]="à",["Â"]="â",["Ã"]="ã",["Ä"]="ä",["É"]="é",["È"]="è",["Ê"]="ê",["Ë"]="ë",["Í"]="í",["Ì"]="ì",["Î"]="î",["Ï"]="ï",["Ó"]="ó",["Ò"]="ò",["Ô"]="ô",["Õ"]="õ",["Ö"]="ö",["Ú"]="ú",["Ù"]="ù",["Û"]="û",["Ü"]="ü",["Ç"]="ç" }
    local function lower(value) value=value:lower(); for a,b in pairs(upper) do value=value:gsub(a,b) end; return value end
    local function metadata(record)
        if not record then return nil end
        local result={}; for name,value in pairs(record) do if name~="Scripts" and name~="Callback" and name~="Enabled" then result[name]=copy(value) end end
        return result
    end
    local function optionalService(name)
        local ok,value=pcall(game.GetService,game,name); return ok and value or nil
    end
    function Hub:_game(id) return self._games[id] end
    function Hub:_script(gameId,scriptId)
        local rec=self:_game(gameId); if rec then for _,entry in ipairs(rec.Scripts) do if entry.Id==scriptId then return entry,rec end end end
    end
    function Hub:GetGame(id)
        local rec=self:_game(id); if not rec then return nil end
        local value=metadata(rec); value.Scripts={}; for _,entry in ipairs(rec.Scripts) do value.Scripts[#value.Scripts+1]=metadata(entry) end; return value
    end
    function Hub:GetGames() local out={}; for _,id in ipairs(self._order) do out[#out+1]=self:GetGame(id) end; return out end
    function Hub:GetScript(gameId,scriptId) return metadata(self:_script(gameId,scriptId)) end
    function Hub:GetSelectedGame() return self:GetGame(self.SelectedGameId) end
    function Hub:IsCurrentGame(id)
        local rec=self:_game(id)
        return not not (rec and ((rec.PlaceId and rec.PlaceId==game.PlaceId) or (rec.UniverseId and rec.UniverseId==game.GameId)))
    end
    function Hub:DetectCurrentGame()
        for _,id in ipairs(self._order) do local rec=self._games[id]; if rec.PlaceId and rec.PlaceId==game.PlaceId then return id end end
        for _,id in ipairs(self._order) do local rec=self._games[id]; if rec.UniverseId and rec.UniverseId==game.GameId then return id end end
    end
    function Hub:IsFavorite(id) return table.find(self.Favorites:GetValue(),id)~=nil end
    function Hub:SetFavorite(id,value)
        assert(self:_game(id),"Unknown game"); assert(type(value)=="boolean","Favorite must be boolean")
        local values=self.Favorites:GetValue(); local index=table.find(values,id)
        if value and not index then values[#values+1]=id elseif not value and index then table.remove(values,index) end
        self.Favorites:SetValue(values); return self
    end
    function Hub:SetGameQuery(value)
        assert(type(value)=="string" and #value<=256,"Game query must be up to 256 bytes")
        self.GameSearch:SetValue(value); return self
    end
    function Hub:SetScriptQuery(value)
        assert(type(value)=="string" and #value<=256,"Script query must be up to 256 bytes")
        self.ScriptSearch:SetValue(value); return self
    end
    function Hub:SetSort(value)
        assert(value=="Order" or value=="Alphabetical" or value=="Favorites","Sort must be Order, Alphabetical or Favorites")
        self.Sort:SetValue(value); return self
    end
    function Hub:_thumbnailURI(rec,large)
        if rec.Image then return rec.Image end
        if large and rec.PlaceId then return "rbxthumb://type=GameThumbnail&id="..string.format("%.0f",rec.PlaceId).."&w=256&h=144" end
        if rec.UniverseId then return "rbxthumb://type=GameIcon&id="..string.format("%.0f",rec.UniverseId).."&w=150&h=150" end
        if rec.PlaceId then return "rbxthumb://type=GameThumbnail&id="..string.format("%.0f",rec.PlaceId).."&w=256&h=144" end
        return nil
    end
    function Hub:GetThumbnailStatus(id)
        local rec=self:_game(id); if not rec then return nil,"Unknown game" end
        local uri=self:_thumbnailURI(rec); local cached=uri and self._thumbs[uri]
        return {Status=cached and cached.Status or "Unavailable",URI=uri,Error=cached and cached.Error}
    end
    function Hub:_paintThumbnail(image,fallback,uri)
        local cached=uri and self._thumbs[uri]; local loaded=cached and cached.Status=="Loaded"
        image.Image=loaded and uri or ""; image.Visible=not not loaded
        if fallback then fallback.Frame.Visible=not loaded end
    end
    function Hub:_refreshImages()
        if self.Destroyed then return end
        self.GameList:_render()
        local rec=self:_game(self.SelectedGameId); local uri=rec and self:_thumbnailURI(rec,true)
        local cached=uri and self._thumbs[uri]; local loaded=cached and cached.Status=="Loaded"
        self.GameImage:SetValue(loaded and uri or "",true)
        self.GameImage.Image.Visible=not not loaded
        if self.ImageFallback then self.ImageFallback.Frame.Visible=not loaded end
        local status=cached and cached.Status or "Unavailable"
        self.ImageStatus:SetText((not rec or loaded) and "" or self.Window:_t17(status=="Loading" and "Carregando imagem…" or "Imagem indisponível",status=="Loading" and "Loading image…" or "Image unavailable"))
        self.ImageStatus:SetVisible(rec~=nil and not loaded)
    end
    function Hub:_pumpThumbnails()
        while not self.Destroyed and self._thumbActive<4 and #self._thumbQueue>0 do
            local request=table.remove(self._thumbQueue,1); self._thumbActive=self._thumbActive+1
            local resourceKey="thumbnail:"..request.URI
            local thread=task.defer(function()
                local success,reason=false,nil
                local provider=optionalService("ContentProvider")
                if provider and type(provider.PreloadAsync)=="function" then
                    local fetched
                    local ok,result=pcall(function() provider:PreloadAsync({request.URI},function(_,status) fetched=status and status.Name=="Success" end) end)
                    success=ok and fetched==true; reason=not ok and tostring(result) or not success and "Image fetch did not succeed" or nil
                else reason="ContentProvider unavailable" end
                self.Scope:Remove(resourceKey,true)
                if self.Destroyed then return end
                self._thumbActive=self._thumbActive-1
                if self._thumbs[request.URI]==request then request.Status=success and "Loaded" or "Unavailable"; request.Error=reason end
                self:_refreshImages(); self:_pumpThumbnails()
            end)
            self.Scope:Add(thread,function(value) if coroutine.status(value)~="dead" then pcall(task.cancel,value) end end,resourceKey)
        end
    end
    function Hub:_requestThumbnail(rec,large)
        local uri=self:_thumbnailURI(rec,large); if not uri or self._thumbs[uri] then return uri end
        if #self._thumbOrder>=128 then
            local evict
            for index,key in ipairs(self._thumbOrder) do if self._thumbs[key].Status~="Loading" then evict=index; break end end
            if not evict then return uri end
            local old=table.remove(self._thumbOrder,evict); self._thumbs[old]=nil
        end
        local cached={URI=uri,Status="Loading"}; self._thumbs[uri]=cached; self._thumbOrder[#self._thumbOrder+1]=uri
        self._thumbQueue[#self._thumbQueue+1]=cached; self:_pumpThumbnails(); return uri
    end
    function Hub:RetryThumbnail(id)
        local rec=assert(self:_game(id),"Unknown game")
        for _,large in ipairs({false,true}) do
            local uri=self:_thumbnailURI(rec,large); local cached=uri and self._thumbs[uri]
            if uri and (not cached or cached.Status~="Loading") then
                self._thumbs[uri]=nil; local index=table.find(self._thumbOrder,uri); if index then table.remove(self._thumbOrder,index) end
                self:_requestThumbnail(rec,large)
            end
        end
        self:_refreshImages(); return self
    end
    function Hub:IsScriptAvailable(gameId,scriptId)
        local spec,rec=self:_script(gameId,scriptId); if not spec then return false,"Script is unavailable" end
        if not spec.Callback then return false,self.Window:_t17("Nenhuma ação foi cadastrada.","No action was registered.") end
        if spec.CurrentGameOnly and not self:IsCurrentGame(gameId) then return false,self.Window:_t17("Disponível somente neste jogo.","Only available in this game.") end
        local enabled=spec.Enabled
        if type(enabled)=="function" then
            local ok,value=self.Window:_protected(enabled,{Operation=self.Id,Phase="HubAvailability"},self,metadata(rec),metadata(spec)); enabled=ok and value==true
        end
        if enabled==false then return false,self.Window:_t17("Indisponível","Unavailable") end
        local caps={loadstring=loadstring,readfile=readfile,writefile=writefile,setclipboard=setclipboard}
        for _,cap in ipairs(spec.Requires) do
            local fn=caps[cap]
            if cap=="HttpGet" then local ok,value=pcall(function() return game.HttpGet end); fn=ok and value or nil end
            if type(fn)~="function" then return false,self.Window:_t17("Capacidade ausente: ","Missing capability: ")..cap end
        end
        return true
    end
    function Hub:GetScriptStatus(gameId,scriptId)
        local spec=self:_script(gameId,scriptId); if not spec then return nil,"Unknown script" end
        local pending=self._pendingScripts[gameId.."/"..scriptId]
        if pending then return pending:GetStatus() end
        local status=self._scriptStatus[gameId.."/"..scriptId]
        if status then return copy(status) end
        local available,reason=self:IsScriptAvailable(gameId,scriptId)
        return {Status=available and "Available" or "Unavailable",Error=reason}
    end
    function Hub:_scriptRows()
        local out={}; local rec=self:_game(self.SelectedGameId)
        for _,spec in ipairs(rec and rec.Scripts or {}) do
            local status=self:GetScriptStatus(rec.Id,spec.Id); local author=spec.Author~="" and " · "..spec.Author or ""
            local pt={Available="Disponível",Unavailable="Indisponível",Queued="Na fila",Running="Executando",Cancelling="Cancelando",Completed="Concluído",Failed="Falha",Cancelled="Cancelado"}
            local label=self.Window:_t17(pt[status.Status] or status.Status,status.Status)
            out[#out+1]={Id=spec.Id,Title=spec.Title,Text=spec.Title..author..(spec.Version~="" and " · "..spec.Version or "").."\n"..label..(spec.Status~="" and " · "..spec.Status or ""),Description=spec.Description}
        end
        return out
    end
    function Hub:_refreshScriptDetails()
        if self.Destroyed or not self.ScriptList then return end
        local spec,rec=self:_script(self.SelectedGameId,self.ScriptList:GetValue())
        local available,reason=false,self.Window:_t17("Selecione um script.","Select a script.")
        if spec then available,reason=self:IsScriptAvailable(rec.Id,spec.Id) end
        local handle=spec and self._pendingScripts[rec.Id.."/"..spec.Id]
        local status=spec and self:GetScriptStatus(rec.Id,spec.Id) or {Status="Unavailable"}
        self.PlayButton._normalText=handle and self.Window:_t17("Executando…","Running…") or self.Window:_t17("Executar script","Run Script")
        self.PlayButton:SetDisabled(not available or handle~=nil and handle~=false)
        if self.CancelButton then self.CancelButton:SetVisible(not not handle); self.CancelButton:SetDisabled(not handle or status.Status=="Cancelling") end
        local parts={}
        if spec then
            parts[#parts+1]=spec.Title
            if spec.Description~="" then parts[#parts+1]=spec.Description end
            local credit=spec.Author..(spec.Version~="" and (spec.Author~="" and " · " or "")..spec.Version or "")
            if credit~="" then parts[#parts+1]=credit end
            if spec.Status~="" then parts[#parts+1]=spec.Status end
            if #spec.Requires>0 then parts[#parts+1]=self.Window:_t17("Requer: ","Requires: ")..table.concat(spec.Requires,", ") end
            if not available then parts[#parts+1]=tostring(reason) end
        end
        self.ScriptDetails:SetText(#parts>0 and table.concat(parts,"\n") or self.Window:_t17("Nenhum script disponível","No scripts available"))
        if self.ExecutionStatus then
            local pt={Available="Disponível",Unavailable="Indisponível",Queued="Na fila",Running="Executando",Cancelling="Cancelando",Completed="Concluído",Failed="Falha",Cancelled="Cancelado"}
            local message=self.Window:_t17(pt[status.Status] or status.Status,status.Status)
            if status.Progress and handle then message=message.." · "..math.floor(status.Progress*100+.5).."%" end
            if status.Message and status.Message~="" then message=message.."\n"..status.Message end
            if status.Error and status.Status=="Failed" then message=message.."\n"..tostring(status.Error) end
            self.ExecutionStatus:SetText(message)
        end
        self:_layoutHub()
    end
    function Hub:RefreshScripts()
        if self.Destroyed then return self end
        self._refreshingScripts=true
        self.ScriptList:SetItems(self:_scriptRows()); self:_filterScripts()
        local preferred=self._selectedScripts and self._selectedScripts[self.SelectedGameId]
        if preferred and self.ScriptList._keyIndex[preferred] then self.ScriptList:SetValue(preferred,true) end
        if not self.ScriptList:GetValue() and #self.ScriptList.Items>0 then self.ScriptList:SetValue(self.ScriptList.Items[1].Id,true) end
        if self.SelectedGameId then self._selectedScripts[self.SelectedGameId]=self.ScriptList:GetValue() end
        self._refreshingScripts=false; self:_refreshScriptDetails(); return self
    end
    function Hub:_filterScripts()
        local query=lower(self.ScriptSearch:GetValue()); local position=self.ScriptList.Viewport.CanvasPosition
        local preserve=self._lastScriptQuery==query; self._lastScriptQuery=query
        self.ScriptList:SetFilter(function(row) return query=="" or lower(row.Text.." "..row.Description):find(query,1,true)~=nil end)
        if preserve then self.ScriptList.Viewport.CanvasPosition=position end
        self:_layoutHub()
    end
    function Hub:_refreshGames()
        if self.Destroyed or self._refreshingGames then return end
        self._refreshingGames=true
        local rows,ids={},{}
        for _,id in ipairs(self._order) do
            local rec=self._games[id]; ids[#ids+1]=id
            rows[#rows+1]={Id=id,Name=rec.Name,Order=rec.Order,Favorite=self:IsFavorite(id),Text=(self:IsFavorite(id) and "★ " or "")..rec.Name.."\n"..#rec.Scripts..self.Window:_t17(" scripts"," scripts")..(self:IsCurrentGame(id) and self.Window:_t17(" · Jogo atual"," · Current game") or "")}
        end
        local sort=self.Sort:GetValue()
        table.sort(rows,function(a,b)
            if sort=="Favorites" and a.Favorite~=b.Favorite then return a.Favorite end
            if sort=="Order" and a.Order~=b.Order then return a.Order<b.Order end
            local x,y=lower(a.Name),lower(b.Name); return x==y and a.Id<b.Id or x~=y and x<y
        end)
        self.Favorites:SetOptions(ids,true)
        self.GameList:SetItems(rows)
        local query=lower(self.GameSearch:GetValue())
        self.GameList:SetFilter(function(row) return query=="" or lower(row.Name.." "..(self._games[row.Id].Description or "")):find(query,1,true)~=nil end)
        self:_layoutHub()
        self._refreshingGames=false
    end
    function Hub:SelectGame(id)
        if self.Destroyed or not self._games[id] then return false,"Game is unavailable" end
        if self._selecting then return true end
        self._selecting=true
        if self.SelectedGameId and self.SelectedGameId~=id then self._selectedScripts[self.SelectedGameId]=self.ScriptList:GetValue(); self.ScriptList:SetValue(nil,true) end
        self.SelectedGameId=id
        self.GameList:SetValue(id,true)
        local rec=self._games[id]
        self.GameDetails:SetText(rec.Name..(self:IsCurrentGame(id) and self.Window:_t17(" · Jogo atual"," · Current game") or "").."\n"..rec.Description)
        self.FavoriteButton.Button.Text=self:IsFavorite(id) and self.Window:_t17("Remover favorito","Remove favorite") or self.Window:_t17("Favoritar","Favorite")
        self.TeleportButton:SetDisabled(not rec.PlaceId or rec.PlaceId==game.PlaceId or self._teleportPending~=nil)
        self:_requestThumbnail(rec); self:_requestThumbnail(rec,true); self:_refreshImages(); self:RefreshScripts(); self._selecting=false
        return true
    end
    function Hub:_afterCatalog()
        self:_refreshGames()
        local selected=self.GameList:GetValue()
        if selected and self._games[selected] then self:SelectGame(selected)
        else
            local target=self.AutoDetectGame and self:DetectCurrentGame() or nil
            target=target or self.GameList.Items[1] and self.GameList.Items[1].Id
            if target then self:SelectGame(target) else
                self.SelectedGameId=nil; self.ScriptList:SetItems({}); self.ImageStatus:SetText(""); self.GameDetails:SetText(self.Window:_t17("Nenhum jogo cadastrado.","No games registered.")); self.GameImage:SetValue("",true)
                self.PlayButton:SetDisabled(true); self.TeleportButton:SetDisabled(true); self.FavoriteButton:SetDisabled(true); self:_refreshScriptDetails()
            end
        end
        if self.SelectedGameId then self.FavoriteButton:SetDisabled(false) end
    end
    function Hub:_checkCount(replacement)
        local total=0; for id,rec in pairs(self._games) do total=total+#((replacement and replacement.Id==id and replacement or rec).Scripts) end
        if replacement and not self._games[replacement.Id] then total=total+#replacement.Scripts end
        assert(total<=4096,"Script catalog limit is 4096 entries")
    end
    function Hub:AddGame(value)
        assert(not self.Destroyed,"Hub has been destroyed"); assert(#self._order<512,"Game catalog limit is 512")
        local rec=normalizeGame(value,#self._order+1); assert(not self._games[rec.Id],"Duplicate game Id"); self:_checkCount(rec)
        self._games[rec.Id]=rec; self._order[#self._order+1]=rec.Id; self:_afterCatalog(); return rec.Id
    end
    function Hub:_cancelScripts(gameId,scriptId)
        for name,handle in pairs(self._pendingScripts) do
            if scriptId and name==gameId.."/"..scriptId or not scriptId and name:sub(1,#gameId+1)==gameId.."/" then handle:Cancel("catalog changed") end
        end
    end
    function Hub:UpdateGame(id,patch)
        local old=assert(self:_game(id),"Unknown game"); assert(type(patch)=="table","Game patch must be a table")
        local value={}; for name,item in pairs(old) do value[name]=item end; for name,item in pairs(patch) do value[name]=item end
        assert(value.Id==id,"Game Id cannot be renamed"); local rec=normalizeGame(value,old.Order); self:_checkCount(rec)
        self:_cancelScripts(id); self._games[id]=rec; self:_afterCatalog(); return self
    end
    function Hub:RemoveGame(id)
        if not self:_game(id) then return false end
        self:_cancelScripts(id); if self._teleportPending and self._teleportPending.GameId==id then self:_endTeleport("Cancelled","Game removed") end; self._games[id]=nil; table.remove(self._order,table.find(self._order,id)); self:_afterCatalog(); return true
    end
    function Hub:AddScript(gameId,value)
        local old=assert(self:_game(gameId),"Unknown game"); local spec=normalizeScript(value)
        assert(not self:_script(gameId,spec.Id),"Duplicate script Id"); local scripts={table.unpack(old.Scripts)}; scripts[#scripts+1]=spec
        return self:UpdateGame(gameId,{Scripts=scripts})
    end
    function Hub:UpdateScript(gameId,id,patch)
        local old,rec=self:_script(gameId,id); assert(old,"Unknown script"); assert(type(patch)=="table","Script patch must be a table")
        local value={}; for name,item in pairs(old) do value[name]=item end; for name,item in pairs(patch) do value[name]=item end
        assert(value.Id==id,"Script Id cannot be renamed"); value=normalizeScript(value)
        local scripts={}; for _,spec in ipairs(rec.Scripts) do scripts[#scripts+1]=spec.Id==id and value or spec end
        self:UpdateGame(gameId,{Scripts=scripts}); self._scriptStatus[gameId.."/"..id]=nil; self:RefreshScripts(); return self
    end
    function Hub:RemoveScript(gameId,id)
        local old,rec=self:_script(gameId,id); if not old then return false end
        local scripts={}; for _,spec in ipairs(rec.Scripts) do if spec.Id~=id then scripts[#scripts+1]=spec end end
        self:UpdateGame(gameId,{Scripts=scripts}); self._scriptStatus[gameId.."/"..id]=nil; return true
    end
    function Hub:RunScript(gameId,scriptId,options)
        options=options or {}; if self.Destroyed then return nil,"Hub has been destroyed" end
        local available,reason=self:IsScriptAvailable(gameId,scriptId); if not available then return nil,reason end
        local spec,rec=self:_script(gameId,scriptId); local name=gameId.."/"..scriptId
        if self._pendingScripts[name] then return nil,"Script is already running" end
        if spec.Confirm and not options.Confirmed then
            self.Window:Confirm({Title=spec.Title,Content=spec.Confirm,OnConfirm=function() self:RunScript(gameId,scriptId,{Confirmed=true}) end}); return nil,"confirmation pending"
        end
        local hub=self
        local function complete(handle)
            if handle._hubCompleted then return end; handle._hubCompleted=true
            if hub._pendingScripts[name]==handle then hub._pendingScripts[name]=nil end
            hub.Scope:Remove("script-listener:"..name)
            if hub.Destroyed or hub:_script(gameId,scriptId)~=spec then return end
            hub._scriptStatus[name]=handle:GetStatus(); hub:RefreshScripts()
            local status=handle:GetStatus().Status
            hub.Window:Notify({Title=spec.Title,Content=status=="Completed" and hub.Window:_text("success") or tostring(handle.Error or status),Kind=status=="Completed" and "success" or status=="Failed" and "error" or "normal"})
        end
        local handle,err=self.Window:RunAction({Group="hub/"..self.Id.."/"..name,Policy="Reject",Callback=function(ctx)
            local ready,why=hub:IsScriptAvailable(gameId,scriptId); if not ready or hub:_script(gameId,scriptId)~=spec then return false,why or "Script was replaced" end
            return spec.Callback(ctx,hub,metadata(rec),metadata(spec))
        end,OnComplete=complete})
        if not handle then return nil,err end
        if handle.Finished then complete(handle)
        else
            self._pendingScripts[name]=handle
            self.Scope:Add(handle:Subscribe(function(status) if not hub.Destroyed and hub:_script(gameId,scriptId)==spec then hub._scriptStatus[name]=status; hub:RefreshScripts() end end,true),"Disconnect","script-listener:"..name)
        end
        return handle
    end
    function Hub:_endTeleport(status,message)
        local request=self._teleportPending; if not request then return end
        self._teleportPending=nil; self.Scope:Remove("teleport-timeout")
        self.TeleportStatus:SetText(message or status)
        if self.SelectedGameId then self:SelectGame(self.SelectedGameId) end
        if status=="Failed" then self.Window:Notify({Title=self.Window:_t17("Falha no teleporte","Teleport failed"),Content=tostring(message),Kind="error"}) end
    end
    function Hub:TeleportToGame(id,options)
        options=options or {}; if self.Destroyed then return nil,"Hub has been destroyed" end
        local rec=self:_game(id); if not rec or not rec.PlaceId then return nil,"Game has no PlaceId" end
        if rec.PlaceId==game.PlaceId then return nil,"Already in this place" end
        if self._teleportPending then return nil,"A teleport request is pending" end
        local service=optionalService("TeleportService")
        if not self.Teleporter and (not service or type(service.Teleport)~="function") then return nil,"Client teleport is unavailable; configure a Teleporter adapter" end
        if self.ConfirmTeleport and not options.Confirmed then
            self.Window:Confirm({Title=self.Window:_t17("Entrar no jogo?","Join game?"),Content=rec.Name,OnConfirm=function()
                local handle,err=self:TeleportToGame(id,{Confirmed=true}); if not handle then self.Window:Notify({Content=tostring(err),Kind="error"}) end
            end}); return nil,"confirmation pending"
        end
        local request={GameId=id,PlaceId=rec.PlaceId}; self._teleportPending=request; self.TeleportButton:SetDisabled(true)
        self.TeleportStatus:SetText(self.Window:_t17("Solicitando teleporte…","Requesting teleport…"))
        local hub=self
        local handle,err=self.Window:RunAction({Group="hub/"..self.Id.."/teleport",Policy="Reject",Callback=function(ctx)
            if hub:_game(id)~=rec then return false,"Game was removed or replaced" end
            local ok,result,reason
            if hub.Teleporter then ok,result,reason=pcall(hub.Teleporter,rec.PlaceId,Players.LocalPlayer,metadata(rec),ctx)
            else ok,result=pcall(service.Teleport,service,rec.PlaceId,Players.LocalPlayer) end
            if not ok or result==false then return false,ok and (reason or "Teleport was rejected") or tostring(result) end
            if hub._teleportPending==request then
                hub.TeleportStatus:SetText(hub.Window:_t17("Teleporte solicitado; aguardando o Roblox.","Teleport requested; waiting for Roblox."))
                local thread=task.delay(30,function()
                    hub.Scope:Remove("teleport-timeout",true)
                    if not hub.Destroyed and hub._teleportPending==request then hub:_endTeleport("Unconfirmed",hub.Window:_t17("Não foi possível confirmar o teleporte.","Teleport could not be confirmed.")) end
                end)
                hub.Scope:Add(thread,function(t) if coroutine.status(t)~="dead" then pcall(task.cancel,t) end end,"teleport-timeout")
            end
            return {Requested=true,PlaceId=rec.PlaceId}
        end,OnComplete=function(action)
            if not hub.Destroyed and hub._teleportPending==request and action:GetStatus().Status~="Completed" then hub:_endTeleport("Failed",tostring(action.Error or action:GetStatus().Status)) end
        end})
        if not handle then self:_endTeleport("Failed",err); return nil,err end
        self.Scope:Add(handle,"Cancel","teleport-action"); return handle
    end
    function Hub:Show() self.Window:Show(); self.Window:Minimize(false); self.Tab:Select(); return self end
    function Hub:Hide() self.Window:Hide(); return self end
    function Hub:Destroy()
        if self.Destroyed then return end; self.Destroyed=true
        for _,handle in pairs(self._pendingScripts) do handle:Cancel("hub destroyed") end
        self.Scope:Destroy(); self._thumbQueue={}; cleanup(self)
        if self.Window._scriptHubs then self.Window._scriptHubs[self.Id]=nil end
        self.Window._resources:Remove("script-hub:"..self.Id,true)
        if not self.Tab.Destroyed then self.Tab:Destroy() end
        if self.OwnsWindow and not self.Window.Destroyed then self.Window:Destroy() end
    end
-- BEGIN RETRO200 HUB UPDATES
-- Embedded inside the Script Hub scope, after its existing catalog methods.
local gameFields={Id=true,Name=true,PlaceId=true,UniverseId=true,Description=true,Image=true,Order=true,Scripts=true}
local scriptFields={Id=true,Title=true,Description=true,Icon=true,Author=true,Version=true,Status=true,Enabled=true,CurrentGameOnly=true,Requires=true,Confirm=true,Action=true}
local function declarative(record,fields,label)
    assert(type(record)=="table",label.." must be a record")
    for field,value in pairs(record) do
        assert(fields[field],"Unknown "..label.." field: "..tostring(field))
        assert(type(value)~="function" and type(value)~="thread" and typeof(value)~="Instance","Catalogs cannot contain executable values")
    end
end
function Hub:_prepareCatalog(document)
    assert(not self.Destroyed,"Hub has been destroyed")
    assert(document.SchemaVersion==1 and document.Kind=="HubCatalog" and document.HubId==self.Id,"Catalog belongs to a different hub or protocol")
    local fields={SchemaVersion=true,Kind=true,HubId=true,Version=true,Games=true}
    for name in pairs(document) do assert(fields[name],"Unknown catalog field: "..tostring(name)) end
    UpdateCore.ParseVersion(document.Version)
    local entries={}
    for index,value in ipairs(array(document.Games,512,"Games")) do
        declarative(value,gameFields,"game")
        local rec={}; for k,v in pairs(value) do if k~="Scripts" then rec[k]=copy(v) end end; rec.Scripts={}
        for _,item in ipairs(array(value.Scripts or {},128,"Scripts")) do
            declarative(item,scriptFields,"script")
            assert(item.Enabled==nil or type(item.Enabled)=="boolean","Catalog Enabled must be boolean")
            assert(item.Icon==nil or type(item.Icon)=="string","Catalog Icon must be text")
            local spec={}; for k,v in pairs(item) do if k~="Action" then spec[k]=copy(v) end end
            local old=self:_script(value.Id,item.Id)
            if item.Action then
                key(item.Action,"Action")
                spec.Callback=self._catalogActions[item.Action]
            elseif old then
                spec.Callback=old.Callback
                if item.Enabled==nil then spec.Enabled=old.Enabled end
                if item.Confirm==nil then spec.Confirm=old.Confirm end
                if item.Requires==nil then spec.Requires=old.Requires end
            end
            rec.Scripts[#rec.Scripts+1]=spec
        end
        entries[index]=rec
    end
    return normalizeGames(entries)
end
function Hub:GetVersion() return self.Version end
function Hub:GetUpdateStatus()
    return {Version=self.Version,CatalogVersion=self.CatalogVersion,LibraryVersion=Library.Version,
        Catalog=self._catalogUpdater and self._catalogUpdater:GetStatus() or {State="Disabled"},
        Code=self._codeUpdater and self._codeUpdater:GetStatus() or {State="Disabled"}}
end
function Hub:CheckForUpdates()
    if self.Destroyed then return nil,"Hub has been destroyed" end
    local errors={}
    for _,updater in ipairs({self._catalogUpdater or false,self._codeUpdater or false}) do
        if updater then local _,reason=updater:Check(); if reason then errors[#errors+1]=reason end end
    end
    return self:GetUpdateStatus(),#errors>0 and table.concat(errors,"\n") or nil
end
function Hub:SetUpdateChannel(value,version)
    assert(not self.Destroyed,"Hub has been destroyed")
    assert(value=="stable" or value=="preview" or value=="pinned","Unknown update channel")
    if version then UpdateCore.ParseVersion(version) end
    for _,updater in ipairs({self._catalogUpdater or false,self._codeUpdater or false}) do assert(not updater or not updater._busy,"Cannot change channel during an update operation") end
    if value=="pinned" then
        for _,updater in ipairs({self._catalogUpdater or false,self._codeUpdater or false}) do assert(not updater or version or updater.Options.Version,"Pinned needs Version") end
    end
    for _,updater in ipairs({self._catalogUpdater or false,self._codeUpdater or false}) do if updater then updater:SetChannel(value,version) end end
    return self
end
function Hub:ReloadCatalog(context)
    if self.Destroyed then return false,"Hub has been destroyed" end
    if not self._catalogUpdater then return false,"Catalog updates are not configured" end
    if self._reloadingCatalog then return false,"Catalog update is already running" end
    self._reloadingCatalog=true
    local ok,reason=pcall(function()
        if context then context:ThrowIfCancelled() end
        self._preparedCatalog=nil
        local document,report=self._catalogUpdater:Load("json")
        assert(document,report)
        assert(not self.Destroyed,"Hub was destroyed during the update")
        if context then context:ThrowIfCancelled() end
        local initial=self._preparedCatalog or self:_prepareCatalog(document)
        local games,order={},{}
        for _,rec in ipairs(initial) do games[rec.Id]=rec; order[#order+1]=rec.Id end
        -- Validation is complete. Mutate the catalog once and keep native controls.
        for id in pairs(self._games) do self:_cancelScripts(id) end
        self._games,self._order=games,order; self._scriptStatus={}; self.CatalogVersion=document.Version
        self:_afterCatalog()
        return report
    end)
    self._preparedCatalog=nil; self._reloadingCatalog=false
    if not ok then self._catalogUpdater.Report.State="Failed"; self._catalogUpdater.Report.Error=tostring(reason); return false,tostring(reason) end
    return true,reason
end
function Hub:_setupUpdates(options)
    self.Version=options.Version or "1.0.0"; self.CatalogVersion=options.CatalogVersion or self.Version
    self._catalogActions={}
    for name,callback in pairs(options.Actions or {}) do key(name,"Action"); assert(type(callback)=="function","Actions must contain developer callbacks"); self._catalogActions[name]=callback end
    local function configured(value,kind,current)
        assert(type(value)=="table","Update settings must be a table")
        local settings={}; for k,v in pairs(value) do settings[k]=v end
        settings.Kind=kind; settings.Major=value.Major or 1; settings.APIVersion=1; settings.HubId=self.Id
        settings.CurrentVersion=current; settings.LibraryVersion=Library.Version; settings.LibraryAPIVersion=Library.APIVersion
        return settings
    end
    if options.CatalogUpdate then
        local settings=configured(options.CatalogUpdate,"HubCatalog",self.CatalogVersion)
        settings.ValidateData=function(document) self._preparedCatalog=self:_prepareCatalog(document); return true end
        self._catalogUpdater=UpdateCore.New(settings)
    end
    if options.CodeUpdate then self._codeUpdater=UpdateCore.New(configured(options.CodeUpdate,"Hub",self.Version)) end
end
function Hub:SelectScript(id)
    if not self:_script(self.SelectedGameId,id) then return false,"Script is unavailable" end
    self.ScriptList:SetValue(id); self._selectedScripts[self.SelectedGameId]=id; self:_refreshScriptDetails(); return true
end
function Hub:GetSelectedScript() return self:GetScript(self.SelectedGameId,self.ScriptList:GetValue()) end
function Hub:_layoutHub()
    if self.Destroyed or self._layoutHubBusy or not self.ScriptList then return end
    self._layoutHubBusy=true
    local scale=math.max(.01,self.Window._actualScale or 1)
    local width=math.max(1,self.GameImage.Frame.AbsoluteSize.X/scale)
    self.GameImage.Frame.Size=UDim2.new(1,0,0,math.max(80,math.floor(width*9/16)))
    self.GameImage.Image.Position=U2(0,0); self.GameImage.Image.Size=UDim2.fromScale(1,1)
    local textScale=self.Window.TextScale or 1
    local function resize(view,maximum)
        view.RowHeight=math.ceil(48*textScale)
        local rows=math.max(1,#view._indices)
        local height=math.min(rows,maximum)*view.RowHeight+8
        view.Frame.Size=UDim2.new(1,0,0,height); view.Viewport.Position=U2(0,0); view.Viewport.Size=UDim2.fromScale(1,1)
        view:_render()
    end
    resize(self.ScriptList,self.ScriptListMaxRows)
    resize(self.GameList,self.LayoutMode=="columns" and self.GameListMaxRows or math.min(self.GameListMaxRows,4))
    self._layoutHubBusy=false
end
local function compact(control,target,kind)
    function control:_layoutDescription()
        if self.Destroyed then return end
        self.TitleLabel.Visible=false; self.DescriptionLabel.Visible=false
        if self._titleIcon then
            if kind=="button" then
                self._titleIcon.Frame.Parent=target; self._titleIcon.Frame.Position=UDim2.new(0,10,.5,-8); self._titleIcon.Frame.Visible=true
            else self._titleIcon.Frame.Visible=false end
        end
        local height=math.ceil((kind=="button" and 36 or 34)*(self._window.TextScale or 1))
        if UserInputService.TouchEnabled then height=math.max(44,height) end
        self.Frame.Size=UDim2.new(self.Frame.Size.X.Scale,self.Frame.Size.X.Offset,0,height)
        self._rowHeight=height; target.Position=U2(0,0); target.Size=UDim2.fromScale(1,1)
        if self._section._isRow then self._section:_layout() end
    end
    control:_layoutDescription()
end
function Hub:_installResponsiveLayout(options)
    local tab,window=self.Tab,self.Window; local hub=self
    self.ScriptListMaxRows=options.ScriptListMaxRows or 4; self.GameListMaxRows=options.GameListMaxRows or 7
    assert(finite(self.ScriptListMaxRows) and self.ScriptListMaxRows%1==0 and self.ScriptListMaxRows>=1 and self.ScriptListMaxRows<=12,"ScriptListMaxRows must be 1–12")
    assert(finite(self.GameListMaxRows) and self.GameListMaxRows%1==0 and self.GameListMaxRows>=2 and self.GameListMaxRows<=16,"GameListMaxRows must be 2–16")
    local ratio=options.NavigationRatio or .45; local stackAt=options.StackAt or 620
    assert(finite(ratio) and ratio>=.3 and ratio<=.55,"NavigationRatio must be .3–.55")
    assert(finite(stackAt) and stackAt>=480 and stackAt<=1000,"Hub StackAt must be 480–1000")
    local function scroll(order)
        return ui(window,"ScrollingFrame",{Parent=tab.Container,LayoutOrder=order,Size=UDim2.new(.5,-6,1,0),CanvasSize=U2(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=4,BackgroundTransparency=1,BorderSizePixel=0,Active=true,ClipsDescendants=true},{ScrollBarImageColor3="Border"})
    end
    self.NavigationScroll=scroll(1); self.DetailsScroll=scroll(2)
    function tab:_layout()
        if self.Destroyed or self._hubLayingOut then return end; self._hubLayingOut=true
        local width=self.Frame.AbsoluteSize.X/math.max(.01,window._actualScale or 1)
        local columns=width>=stackAt*(window.TextScale or 1)
        hub.LayoutMode=columns and "columns" or "stacked"
        self.ColumnLayout.FillDirection=columns and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
        self.Container.AutomaticSize=columns and Enum.AutomaticSize.None or Enum.AutomaticSize.Y
        self.Container.Size=UDim2.new(1,-10,columns and 1 or 0,0)
        self.Frame.ScrollingEnabled=not columns; self.Frame.ScrollBarThickness=columns and 0 or 5
        self.Frame.AutomaticCanvasSize=columns and Enum.AutomaticSize.None or Enum.AutomaticSize.Y
        if columns then
            self.Frame.CanvasPosition=Vector2.new(0,0); self.Frame.CanvasSize=U2(0,0)
            self.Left.Parent=hub.NavigationScroll; self.Right.Parent=hub.DetailsScroll
            hub.NavigationScroll.Size=UDim2.new(ratio,-6,1,0); hub.DetailsScroll.Size=UDim2.new(1-ratio,-6,1,0)
        else self.Left.Parent=self.Container; self.Right.Parent=self.Container end
        hub.NavigationScroll.Visible=columns; hub.DetailsScroll.Visible=columns
        self.Left.Size=UDim2.new(1,columns and -6 or 0,0,0); self.Right.Size=UDim2.new(1,columns and -6 or 0,0,0); self.Right.Visible=true
        self._hubLayingOut=false; hub:_layoutHub()
    end
    connect(self,self.GameImage.Frame:GetPropertyChangedSignal("AbsoluteSize"),function() hub:_layoutHub() end)
    connect(self,self.GameDetails.TitleLabel:GetPropertyChangedSignal("TextSize"),function() tab:_layout() end)
    for _,control in ipairs({self.GameList,self.ScriptList,self.GameImage}) do
        control.TitleLabel.Visible=false; control.DescriptionLabel.Visible=false
        function control:_layoutDescription() if not self.Destroyed then self.TitleLabel.Visible=false; self.DescriptionLabel.Visible=false; hub:_layoutHub() end end
    end
    for _,control in ipairs({self.FavoriteButton,self.TeleportButton,self.PlayButton,self.CancelButton}) do compact(control,control.Button,"button") end
    window:_bind(self.PlayButton.Button,{BackgroundColor3="Accent",TextColor3="AccentText"})
    if self.PlayButton._titleIcon then self.PlayButton._titleIcon:SetRole("AccentText") end
    for _,control in ipairs({self.GameSearch,self.ScriptSearch}) do
        compact(control,control.Input,"input")
        local clear=button(window,control,control.Frame,"×",{Position=UDim2.new(1,-30,0,0),Size=U2(30,30)},function() control:SetValue("") end)
        control.ClearButton=clear
        local layout=control._layoutDescription
        function control:_layoutDescription() layout(self); self.Input.Size=UDim2.new(1,-34,1,0); clear.Size=UDim2.new(0,30,1,0) end
        control:_layoutDescription()
        function control:_syncClear() clear.Visible=self:GetValue()~="" end
        self.Scope:Add(window:GetFlagState(control.Id):Subscribe(function() control:_syncClear() end,true),"Disconnect")
    end
    compact(self.Sort,self.Sort.Button,"input")
    local sortLayout,sortRender=self.Sort._layoutDescription,self.Sort._render
    local sortPanel
    for _,child in ipairs(self.Sort.Frame:GetChildren()) do if child.ClassName=="Frame" and child.Size.Y.Offset==184 then sortPanel=child; break end end
    function self.Sort:_layoutDescription()
        sortLayout(self)
        local height=math.ceil(34*(window.TextScale or 1))
        self.Button.Size=UDim2.new(1,0,0,height)
        if sortPanel then sortPanel.Position=U2(0,height+4) end
        if self.Open then self.Frame.Size=UDim2.new(1,0,0,height+192) end
    end
    function self.Sort:_render()
        sortRender(self)
        local labels={Order=window:_t17("Cadastro","Registration order"),Alphabetical=window:_t17("Nome","Name"),Favorites=window:_t17("Favoritos","Favorites")}
        self.Button.Text=labels[self.Value] or self.Button.Text
        for name,item in pairs(self._rows or {}) do item.Text=(self.Value==name and "[X] " or "[ ] ")..(labels[name] or name) end
    end
    self.Sort:_layoutDescription(); self.Sort:_render()
    local sortOpen=self.Sort.SetOpen
    function self.Sort:SetOpen(value)
        local previous=self.Frame.Size; sortOpen(self,value)
        window:_cancelTrack(self.Frame,"expand",false); self:_layoutDescription()
        local target=self.Frame.Size; self.Frame.Size=previous
        window:_animate(self.Frame,{Size=target},.12,"expand",self)
        return self
    end
    self.GameImage.Title=""; self.GameImage.TitleLabel.Text=""
    window:_bind(self.GameImage.Frame,{BackgroundColor3="Inset",BorderColor3="Border"}); self.GameImage.Frame.BackgroundTransparency=0; self.GameImage.Frame.BorderSizePixel=1
    self.ImageFallback=iconSlot(window,self.GameImage.Frame,"gamepad",nil,48,UDim2.new(.5,-24,.5,-24),"Muted")
    tab:_layout()
end

-- END RETRO200 HUB UPDATES
    function Window:CreateScriptHub(options)
        assert(type(options)=="table","Script Hub options must be a table")
        local id=key(options.Id or "script-hub","Hub Id"); self._scriptHubs=self._scriptHubs or {}; assert(not self._scriptHubs[id],"Hub Id already registered")
        assert(options.AutoDetectGame==nil or type(options.AutoDetectGame)=="boolean","AutoDetectGame must be boolean")
        assert(options.ConfirmTeleport==nil or type(options.ConfirmTeleport)=="boolean","ConfirmTeleport must be boolean")
        assert(options.Teleporter==nil or type(options.Teleporter)=="function","Teleporter must be a developer callback")
        local initial=normalizeGames(options.Games)
        local hub=setmetatable({Id=id,Window=self,Scope=self:CreateScope(),_selectedScripts={},_connections={},_games={},_order={},_scriptStatus={},_pendingScripts={},_thumbs={},_thumbOrder={},_thumbQueue={},_thumbActive=0,AutoDetectGame=options.AutoDetectGame~=false,ConfirmTeleport=options.ConfirmTeleport~=false,Teleporter=options.Teleporter},Hub)
        for _,rec in ipairs(initial) do hub._games[rec.Id]=rec; hub._order[#hub._order+1]=rec.Id end
        self._scriptHubs[id]=hub
        local function opts(name,title,extra)
            local result={Id="hub/"..id.."/"..name,Title=title}; for a,b in pairs(extra or {}) do result[a]=b end; return result
        end
        local window=self
        local ok,reason=pcall(function()
            hub:_setupUpdates(options)
            hub.Tab=self:CreateTab({Title=options.Title or "Script Hub",Icon="gamepad",Columns=2}); hub.Tab._toolManager=hub
            local nav=hub.Tab:CreateSection({Title=self:_t17("Jogos","Games"),Icon="gamepad"})
            hub.GameSearch=nav:AddInput(opts("game-search",self:_t17("Pesquisar jogos","Search games"),{Live=true,MaxLength=256,Persist=false,Placeholder=self:_t17("Pesquisar jogos…","Search games…")}))
            hub.Sort=nav:AddDropdown(opts("sort",self:_t17("Ordenação","Sort"),{Options={"Order","Alphabetical","Favorites"},Default="Order"}))
            hub.Favorites=nav:AddDropdown(opts("favorites","Favorites",{Options={},Multi=true,Default={}})); hub.Favorites:SetVisible(false)
            hub.GameList=nav:AddVirtualList(opts("games",self:_t17("Catálogo de jogos","Game catalog"),{Items={},Searchable=false,Height=360,RowHeight=64,Persist=true,EmptyText=self:_t17("Nenhum jogo encontrado.","No matching games.")}))
            local normalize=hub.GameList._normalize
            function hub.GameList:_normalize(value) if value~=nil and not self._keyIndex[tostring(value)] then return nil end; return normalize(self,value) end
            hub.GameList._renderNode=function(_,row,index)
                if not row.Thumb then
                    row.Thumb=ui(window,"ImageLabel",{Parent=row.Button,Position=U2(12,6),Size=U2(36,36),BackgroundTransparency=1,Image="",ScaleType=Enum.ScaleType.Fit})
                    row.Fallback=iconSlot(window,row.Button,"gamepad",nil,24,U2(18,12),"Muted")
                    row.SelectedMark=label(window,row.Button,"›",{Position=U2(1,0),Size=UDim2.new(0,10,1,0),TextSize=18},"AccentText")
                end
                row.Labels[1].Position=U2(56,4); row.Labels[1].Size=UDim2.new(1,-64,1,-8); row.Labels[1].TextWrapped=true
                row.SelectedMark.Visible=hub.GameList:GetValue()==hub.GameList.Items[index].Id
                local item=hub.GameList.Items[index]; local rec=hub:_game(item.Id)
                hub:_paintThumbnail(row.Thumb,row.Fallback,rec and hub:_requestThumbnail(rec))
            end
            local details=hub.Tab:CreateSection({Title=self:_t17("Jogo selecionado","Selected game"),Icon="info",Side="Right"})
            hub.GameImage=details:AddImage(opts("image","",{Image="",Height=104}))
            hub.ImageStatus=details:AddLabel(opts("image-status","",{Height=22,Persist=false}))
            hub.GameDetails=details:AddLabel(opts("game-details",self:_t17("Informações","Information"),{Height=26,Persist=false}))
            local actions=details:CreateRow({StackAt=200,Gap=8})
            hub.FavoriteButton=actions:AddButton(opts("favorite",self:_t17("Favoritar","Favorite"),{Icon="star",Callback=function() if hub.SelectedGameId then hub:SetFavorite(hub.SelectedGameId,not hub:IsFavorite(hub.SelectedGameId)) end end}))
            hub.TeleportButton=actions:AddButton(opts("teleport",self:_t17("Entrar no jogo","Join game"),{Icon="chevron-right",Callback=function()
                local handle,err=hub:TeleportToGame(hub.SelectedGameId); if not handle and err~="confirmation pending" then window:Notify({Content=tostring(err),Kind="error"}) end
            end}))
            hub.TeleportStatus=details:AddLabel(opts("teleport-status","",{Height=22,Persist=false})); hub.TeleportStatus:SetVisible(false)
            local teleportText=hub.TeleportStatus.SetText
            function hub.TeleportStatus:SetText(value) teleportText(self,value); self:SetVisible(tostring(value)~=""); return self end
            local scripts=hub.Tab:CreateSection({Title=self:_t17("Scripts disponíveis","Available scripts"),Icon="code",Side="Right"})
            hub.ScriptSearch=scripts:AddInput(opts("script-search",self:_t17("Pesquisar scripts","Search scripts"),{Live=true,MaxLength=256,Persist=false,Placeholder=self:_t17("Pesquisar scripts…","Search scripts…")}))
            hub.ScriptList=scripts:AddVirtualList(opts("scripts",self:_t17("Catálogo de scripts","Script catalog"),{Items={},Searchable=false,Height=250,RowHeight=64,EmptyText=self:_t17("Nenhum script disponível","No scripts available"),Persist=false}))
            hub.ScriptList._renderNode=function(_,row,index)
                row.Labels[1].Position=U2(38,4); row.Labels[1].Size=UDim2.new(1,-46,1,-8); row.Labels[1].TextWrapped=true
                local item=hub.ScriptList.Items[index]
                if not row.ScriptIcon then
                    row.ScriptIcon=iconSlot(window,row.Button,false,nil,20,UDim2.new(0,12,.5,-10),"Text")
                    row.SelectedMark=label(window,row.Button,"›",{Position=U2(1,0),Size=UDim2.new(0,10,1,0),TextSize=18},"AccentText")
                end
                local spec=hub:_script(hub.SelectedGameId,item.Id); row.ScriptIcon:Set(spec and spec.Icon or "code")
                local selected=hub.ScriptList:GetValue()==item.Id; row.SelectedMark.Visible=selected
                row.ScriptIcon:SetRole(selected and "AccentText" or "Text")
            end
            hub.ScriptDetails=scripts:AddLabel(opts("script-details","",{Height=26,Persist=false}))
            hub.ExecutionStatus=scripts:AddLabel(opts("execution-status","",{Height=22,Persist=false}))
            hub.PlayButton=scripts:AddButton(opts("play",self:_t17("Executar script","Run Script"),{Icon="bolt",Callback=function()
                local handle,err=hub:RunScript(hub.SelectedGameId,hub.ScriptList:GetValue()); if not handle and err~="confirmation pending" then window:Notify({Content=tostring(err),Kind="error"}) end
            end}))
            hub.CancelButton=scripts:AddButton(opts("cancel",self:_t17("Cancelar execução","Cancel run"),{Icon="close",Callback=function()
                local name=tostring(hub.SelectedGameId).."/"..tostring(hub.ScriptList:GetValue()); local handle=hub._pendingScripts[name]
                if handle then handle:Cancel("user cancelled") end
            end})); hub.CancelButton:SetVisible(false)
            hub:_installResponsiveLayout(options)
            hub.Scope:Add(self:GetFlagState(hub.GameList.Id):Subscribe(function(value)
                if value then hub:SelectGame(value)
                elseif not hub._selectionQueued then
                    hub._selectionQueued=true
                    local thread=task.defer(function()
                        hub.Scope:Remove("selection-refresh",true); hub._selectionQueued=false
                        if not hub.Destroyed and not hub.GameList:GetValue() then hub:_afterCatalog() end
                    end)
                    hub.Scope:Add(thread,function(t) if coroutine.status(t)~="dead" then pcall(task.cancel,t) end end,"selection-refresh")
                end
            end),"Disconnect")
            hub.Scope:Add(self:GetFlagState(hub.Favorites.Id):Subscribe(function() if not hub._refreshingGames then hub:_refreshGames(); local selected=hub.GameList:GetValue(); if selected then hub:SelectGame(selected) end end end),"Disconnect")
            hub.Scope:Add(self:GetFlagState(hub.Sort.Id):Subscribe(function() hub:_refreshGames() end),"Disconnect")
            hub.Scope:Add(self:GetFlagState(hub.GameSearch.Id):Subscribe(function() hub:_refreshGames() end),"Disconnect")
            hub.Scope:Add(self:GetFlagState(hub.ScriptSearch.Id):Subscribe(function() hub:_filterScripts() end),"Disconnect")
            hub.Scope:Add(self:GetFlagState(hub.ScriptList.Id):Subscribe(function(value)
                if not hub._selecting and not hub._refreshingScripts then
                    if hub.SelectedGameId then hub._selectedScripts[hub.SelectedGameId]=value end
                    hub:_refreshScriptDetails()
                end
            end),"Disconnect")
            local teleport=optionalService("TeleportService")
            if teleport and teleport.TeleportInitFailed then hub.Scope:Add(teleport.TeleportInitFailed:Connect(function(player,_,message,placeId)
                if not hub.Destroyed and player==Players.LocalPlayer and hub._teleportPending and hub._teleportPending.PlaceId==placeId then hub:_endTeleport("Failed",message) end
            end),"Disconnect") end
            hub:_refreshGames()
            local selected=hub.AutoDetectGame and hub:DetectCurrentGame() or nil
            if selected then hub:SelectGame(selected) else hub:_afterCatalog() end
            hub.Tab:Select()
        end)
        if not ok then
            if hub.Tab then hub:Destroy() else hub.Scope:Destroy(); self._scriptHubs[id]=nil end
            error(reason,2)
        end
        self:Manage(hub,"Destroy","script-hub:"..id)
        if options.CatalogUpdate and options.CatalogUpdate.AutoLoad~=false then
            local action=self:RunAction({Group="hub/"..id.."/catalog",Policy="Reject",Callback=function(ctx)
                ctx:ThrowIfCancelled(); local updated,err=hub:ReloadCatalog(ctx)
                if not updated and not hub.Destroyed then window:Notify({Title=window:_t17("Atualização do catálogo","Catalog update"),Content=tostring(err),Kind="warning"}) end
                return updated,err
            end})
            if action then hub.Scope:Add(action,"Cancel","catalog-startup") end
        end
        return hub
    end
    function Library:CreateScriptHub(options)
        assert(type(options)=="table","Script Hub options must be a table"); normalizeGames(options.Games)
        local settings={}; for name,value in pairs(options) do settings[name]=value end
        settings.Id=options.WindowId or options.Id or "RetroBox-ScriptHub"; settings.Title=options.Title or "Script Hub"
        local window=self:CreateWindow(settings)
        local hubOptions={}; for name,value in pairs(options) do hubOptions[name]=value end
        hubOptions.Id=options.HubId or options.Id or "script-hub"
        local ok,hub=pcall(window.CreateScriptHub,window,hubOptions)
        if not ok then window:Destroy(); error(hub,2) end
        hub.OwnsWindow=true; return hub
    end
end
-- END RETRO190 SCRIPT HUB

return Library
