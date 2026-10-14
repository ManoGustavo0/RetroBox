-- Run in your executor. Update this raw URL if you move the published library.
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))()

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
    Tooltip = "Ativa ou desativa o recurso. O callback recebe true ou false.",
    Default = false,
    Keybind = { Default = Enum.KeyCode.F, Mode = "Toggle" },
    Floating = { Text = "RECURSO", Position = Vector2.new(.04, .65) },
    Callback = function(enabled)
        print("Recurso:", enabled)
    end,
})

category:AddSlider({
    Id = "intensity",
    Title = "Intensidade",
    Tooltip = { Title = "Intensidade", Text = "Ajusta o valor enviado ao seu script, de 0 a 100.", Delay = .3 },
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
-- Settings is a built-in tab. The gear selects it.
-- X hides the menu; RightShift or the draggable UI button opens it again.
-- Floating shortcuts appear on touch devices while the menu is hidden/minimized.
