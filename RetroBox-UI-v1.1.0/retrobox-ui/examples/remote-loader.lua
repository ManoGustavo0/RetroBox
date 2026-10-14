-- Remote distribution contract: HTTP -> library -> window -> tab -> section -> controls.
-- For pre-merge testing replace main with the verified 1.9.1 release commit.
local RETROBOX_URL = "https://raw.githubusercontent.com/ManoGustavo0/RetroBox/6486c4be4db877e4eb2e94f714f4ae4da3fdf762/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"
local ok, Library = pcall(function()
    assert(type(loadstring) == "function", "loadstring is unavailable")
    local hasHTTP, getter = pcall(function() return game.HttpGet end)
    assert(hasHTTP and type(getter) == "function", "game:HttpGet is unavailable")
    local source = game:HttpGet(RETROBOX_URL)
    assert(type(source) == "string" and #source > 0, "The raw source is empty")
    local chunk, err = loadstring(source, "RetroBox")
    assert(chunk, err)
    return chunk()
end)
if not ok then warn("[RetroBox] " .. tostring(Library)); return end
if type(Library) ~= "table" or Library.Version ~= "1.9.1" then warn("[RetroBox] Use the confirmed 1.9.1 raw URL"); return end
local window = Library:CreateWindow({Id = "remote-loader-demo", Title = "RetroBox / Remoto", Theme = "Retro98", Locale = "pt-BR"})
local tab = window:CreateTab({Title = "Principal", Icon = "home"})
local section = tab:CreateSection({Title = "Funções", Icon = "code"})
section:AddButton({Id = "remote-example", Title = "Testar aviso", Callback = function()
    window:Notify({Title = "Carregamento remoto", Content = "A library foi carregada por HTTP."})
end})
