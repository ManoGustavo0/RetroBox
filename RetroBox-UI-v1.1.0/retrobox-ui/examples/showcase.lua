-- Run in your executor. Update this raw URL if you move the published library.
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"))()

local window = RetroBox:CreateWindow({
    Id = "retrobox-showcase",
    Title = "RetroBox UI / Showcase",
    Subtitle = "Pequenas peças. Interfaces completas.",
    Theme = "Retro98",
    Locale = "pt-BR",
    Size = Vector2.new(790, 570),
    DestroyOnClose = false,
})
local home = window:CreateTab({ Title = "Início", Icon = ">" })
local visual = window:CreateTab({ Title = "Visual", Icon = "*", Columns = 2 })
local components = window:CreateTab({ Title = "Componentes", Icon = "+" })
local logs = window:CreateTab({ Title = "Eventos", Icon = "#" })
local log = logs:CreateSection("Saída"):AddConsole({ Title = "Console", Height = 250, MaxLines = 120 })

local intro = home:CreateSection("Seu script, com outra cara")
intro:AddLabel({
    Title = "Interface retrô, API direta.",
    Description = "Use a engrenagem junto ao seu avatar para trocar tema, escala e configurações.",
    Height = 78,
})
intro:AddButton({ Title = "Abrir personalização", Callback = function() window:ShowSettings(true) end })
intro:AddButton({
    Title = "Salvar configuração",
    Callback = function()
        local ok, err = window:SaveConfig("showcase")
        window:Notify({ Title = ok and "Salvo" or "Erro", Content = ok and "Perfil: showcase" or err, Kind = ok and "success" or "error" })
    end,
})
intro:AddButton({
    Title = "Carregar configuração",
    Callback = function()
        local ok, err = window:LoadConfig("showcase")
        window:Notify({ Title = ok and "Carregado" or "Erro", Content = ok and "Perfil: showcase" or err, Kind = ok and "success" or "error" })
    end,
})
intro:AddButton({ Title = "Notificação", Callback = function() window:Notify("Esses botões executam callbacks do seu código.") end })

local circle = Instance.new("Frame")
circle.Name = "DemoFOV"
circle.Size = UDim2.fromOffset(220, 220)
circle.AnchorPoint = Vector2.new(.5, .5)
circle.Position = UDim2.fromScale(.5, .5)
circle.BackgroundTransparency = 1
circle.BorderSizePixel = 0
circle.ZIndex = 0
circle.Parent = window.Root
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = circle
local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(50, 110, 170)
outline.Thickness = 2
outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
outline.Parent = circle

local fov = visual:CreateSection("Exemplo / Campo de visão")
fov:AddLabel({ Title = "O círculo é uma demonstração visual.", Description = "Aperte RightShift para ocultar a janela e enxergar o círculo.", Height = 65 })
fov:AddToggle({
    Id = "fov_visible", Title = "Mostrar círculo", Default = true, FireOnInit = true,
    Tooltip = "Exibe o círculo de demonstração. A visibilidade é alterada pelo callback deste controle.",
    Callback = function(value) circle.Visible = value end,
})
fov:AddSlider({
    Id = "fov_size", Title = "Diâmetro do círculo", Min = 40, Max = 520, Step = 2, Default = 220, Suffix = " px",
    Tooltip = "Muda o diâmetro do círculo em pixels. Você também pode digitar um valor no campo numérico.",
    Callback = function(value) circle.Size = UDim2.fromOffset(value, value) end,
})
local colors = visual:CreateSection({ Title = "Paleta / RGB", Side = "Right" })
colors:AddColorPicker({
    Id = "fov_color", Title = "Cor do FOV", Description = "Cor fixa, HSV, HEX ou RGB animado.",
    Tooltip = { Title = "Cor e RGB", Text = "Define a cor e a opacidade do contorno. Ative RGB para alternar as cores continuamente; a velocidade é medida em segundos por ciclo." },
    Default = { Color = Color3.fromRGB(50, 110, 170), Opacity = 1, Rainbow = false, Speed = 6 },
    FireOnInit = true, Expanded = true,
    Callback = function(color, opacity)
        if window.Destroyed then return end
        outline.Color = color
        outline.Transparency = 1 - opacity
    end,
})

local inputs = components:CreateSection("Seleção e texto")
inputs:AddDropdown({
    Id = "preset", Title = "Seleção simples", Options = { "Equilibrado", "Leve", "Personalizado" },
    Tooltip = "Selecione uma opção. O callback recebe o texto escolhido.",
    Default = "Equilibrado", Callback = function(value) log:Append("Preset: " .. tostring(value)) end,
})
inputs:AddDropdown({
    Id = "layers", Title = "Seleção múltipla", Multi = true, Options = { "Texto", "Ícones", "Contornos", "Sons" },
    Default = { "Texto", "Contornos" }, Callback = function(value) log:Append("Camadas: " .. table.concat(value, ", ")) end,
})
inputs:AddInput({
    Id = "notes", Title = "Anotações", Multiline = true, Default = "", Placeholder = "Digite algo...",
    Callback = function(value) log:Append("Texto: " .. value) end,
})
local hotkeys = components:CreateSection("Teclado")
hotkeys:AddKeybind({
    Id = "action_key", Title = "Executar uma ação", Default = Enum.KeyCode.F, Mode = "Press",
    Tooltip = "Clique no campo para escolher uma tecla. Escape cancela e Backspace remove o atalho.",
    Callback = function(_, key) window:Notify({ Title = "Atalho", Content = "Tecla: " .. key.Name }) end,
})
hotkeys:AddKeybind({
    Id = "hold_key", Title = "Segurar para ativar", Default = Enum.KeyCode.G, Mode = "Hold",
    Callback = function(active) log:Append("Segurar G: " .. tostring(active)) end,
})
local status = components:CreateSection("Progresso e estado")
local progress = status:AddProgress({ Title = "Progresso de exemplo", Default = 25 })
status:AddButton({
    Title = "Avançar 25%",
    Callback = function()
        local value = progress:GetValue() + 25
        progress:SetValue(value > 100 and 0 or value)
        log:Append("Progresso: " .. progress:GetValue() .. "%")
    end,
})
status:AddSeparator("Controles podem mudar depois de criados")
status:AddButton({ Title = "Restaurar valores iniciais", Callback = function() window:Reset() end })

log:Append("RetroBox UI " .. RetroBox.Version .. " carregada.")
window:OnDestroy(function()
    -- Disconnect external events here if your own script adds any.
    circle:Destroy()
end)
