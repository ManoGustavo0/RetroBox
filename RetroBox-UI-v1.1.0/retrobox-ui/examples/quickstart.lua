-- Replace SEU_USUARIO and the repository/branch in the raw URL. Run in your executor.
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/SEU_USUARIO/retrobox-ui/main/RetroBox.lua"))()

local window = RetroBox:CreateWindow({
    Id = "my-script",
    Title = "Meu script",
    Subtitle = "Feito com RetroBox UI",
    Theme = "Retro98",
    Locale = "pt-BR",
    ToggleKey = Enum.KeyCode.RightShift,
})

local tab = window:CreateTab({ Title = "Principal", Icon = "+" })
local category = tab:CreateSection("Controles")

category:AddToggle({
    Id = "feature_enabled",
    Title = "Ativar recurso",
    Default = false,
    Callback = function(enabled)
        print("Recurso:", enabled)
    end,
})

category:AddSlider({
    Id = "intensity",
    Title = "Intensidade",
    Min = 0,
    Max = 100,
    Default = 50,
    Callback = function(value)
        print("Intensidade:", value)
    end,
})

category:AddButton({
    Title = "Testar notificação",
    Callback = function()
        window:Notify({ Title = "Pronto", Content = "A interface está funcionando.", Kind = "success" })
    end,
})

-- Avatar and player names are filled in automatically.
-- The gear opens built-in themes, accessibility options and configurations.
