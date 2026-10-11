-- Requires RetroBox 1.3.0+ at this raw path; adjust it if you move the library.
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"))()
local window = RetroBox:CreateWindow({
    Id = "workflow-demo", Title = "RetroBox / Recursos 1.3",
    Subtitle = "Saves, atalhos, pesquisa e diálogos.",
    ConfigFolder = "RetroBox/WorkflowDemo", ToggleKey = Enum.KeyCode.RightShift,
})
local main = window:CreateTab("Principal")
local controls = main:CreateSection("Teclado, mouse e celular")
local state = { Enabled = false, Amount = 50 }
local toggle = controls:AddToggle({
    Id = "feature", Title = "Ativar recurso",
    Tooltip = "Use o checkbox, o atalho ou o botão flutuante. O callback recebe o estado atual.",
    Keybind = { Default = Enum.UserInputType.MouseButton2, Mode = "Toggle" },
    Floating = { Text = "RECURSO", Position = Vector2.new(.04,.65) },
    Callback = function(value) state.Enabled = value; print("Recurso:",value) end,
})
controls:AddSlider({ Id = "amount", Title = "Intensidade", Min = 0, Max = 100, Default = 50,
    Callback = function(value) state.Amount = value end })
local row = controls:CreateRow()
row:AddButton({ Title = "Abrir configurações", Callback = function() window:ShowSettings(true) end })
row:AddButton({ Title = "Mostrar diálogo", Callback = function()
    window:Confirm({ Title = "Continuar?", Content = "Essa ação é apenas uma demonstração.",
        OnConfirm = function() window:Notify({ Title = "Confirmado", Content = "Sua função entra no callback.", Kind = "success" }) end })
end })
controls:AddButton({ Title = "Ação com feedback", Feedback = true, BusyText = "Processando...",
    SuccessText = "A ação terminou.", Callback = function() task.wait(.25); return true end })
local visual = window:CreateTab("Visual"):CreateSection("Pesquise pelo nome de um controle")
visual:AddColorPicker({ Id = "accent-demo", Title = "Cor de demonstração", Default = "#336699",
    Callback = function(color) print("Cor escolhida:",color) end })
-- Settings lists named saves. Select one and press Load to replay its callbacks.
-- Without executor file functions, saves only live while this window stays open.
-- Create every control before calling LoadConfig/ImportConfig yourself.
-- Programmatic equivalents:
-- window:SaveConfig("Meu preset")
-- window:LoadConfig("Meu preset")
-- window:FocusControl(toggle)
-- toggle.Keybind:SetValue(Enum.KeyCode.G)
-- window:SetLauncherOptions({Text="ABRIR",Position=Vector2.new(.05,.1)})
