-- Run in your executor. Update this raw URL if you move the published library.
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"))()

-- Partial palettes inherit any omitted colors from Retro98.
RetroBox:RegisterTheme("Azulejo", {
    Background = "#D1D8D7",
    Surface = "#E6ECE9",
    Inset = "#F5F7F0",
    Text = "#1D353A",
    Muted = "#566D72",
    Accent = "#2E6374",
    AccentText = "#FCF4DC",
    Border = "#778E8D",
})

local window = RetroBox:CreateWindow({
    Id = "custom-theme",
    Title = "Meu projeto / Azulejo",
    Theme = "Azulejo",
    Font = Enum.Font.Code,
    Locale = "pt-BR",
})
local category = window:CreateTab("Principal"):CreateSection("Tema personalizado")
category:AddLabel({
    Title = "Essa paleta é do seu projeto.",
    Description = "O tema também aparece no menu da engrenagem e acompanha o arquivo de configuração.",
    Height = 78,
})
category:AddColorPicker({
    Title = "Destaque da janela", Default = "#2E6374", AllowRainbow = false, AllowOpacity = false,
    Callback = function(color) window:SetAccent(color) end,
})
