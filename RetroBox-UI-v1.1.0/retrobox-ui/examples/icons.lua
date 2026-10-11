-- Requires RetroBox 1.4.0+ at this raw path. Adjust it if you move the source.
local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"))()
RetroBox:RegisterIcon("gem",{
    "..####..", ".#ahha#.", "#ahhhha#", "#aaaaaa#",
    ".#aaaa#.", "..#aa#..", "...##...", "........",
})
local window=RetroBox:CreateWindow({
    Id="pixel-showcase", Title="RetroBox / Pixel art", Icon="retrobox",
    Subtitle="Ícones com nomes simples, cores do tema e desenho próprio.",
    ConfigFolder="RetroBox/PixelShowcase", PixelIcons=true, PixelDecorations=true,
})
local tab=window:CreateTab({Title="Ícones",Icon="grid"})
local section=tab:CreateSection({Title="Usar nos títulos",Icon="folder"})
local preview=section:AddLabel({Title="Prévia do ícone",Icon="retrobox",Height=38})
section:AddDropdown({
    Id="preview-icon",Title="Selecionar ícone",Icon="palette",
    Options=RetroBox:GetIconNames(),Default="retrobox",Searchable=true,
    Tooltip="Altera o ícone do título da janela, desta aba, da categoria e da prévia.",
    Callback=function(name)
        window:SetIcon(name); tab:SetIcon(name); section:SetIcon(name); preview:SetIcon(name)
    end,
})
local actions=section:CreateRow()
actions:AddButton({Title="Notificar",Icon="notification",Callback=function()
    window:Notify({Title="Ícone personalizado",Content="O desenho acompanha o tema.",Icon="gem"})
end})
actions:AddButton({Title="Diálogo",Icon="info",Callback=function()
    window:Confirm({Title="Pixel art",Content="Ícones funcionam em diálogos também.",Icon="star"})
end})
local gallery=tab:CreateSection({Title="Catálogo completo",Icon="grid"})
local row
for index,name in ipairs(RetroBox:GetIconNames()) do
    if (index-1)%3==0 then row=gallery:CreateRow({StackAt=440}) end
    row:AddLabel({Title=name,Icon=name,Height=40,Tooltip='Use Icon = "'..name..'" no seu componente.'})
end
