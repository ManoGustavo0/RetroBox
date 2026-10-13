local Mock=dofile("tests/mock_roblox.lua"); local Library=dofile("RetroBox.lua")
local w=Library:CreateWindow({Id="contrast-export",FileStorage=false,ReducedMotion=true}); local s=w:CreateTab("Contrast"):CreateSection("Contrast")
local card=s:AddStatCard({Value=128,Subtitle="Secondary ink",Trend=3}); local chart=s:AddLineChart({Data={1,3,2},ShowLegend=true}); local progress=s:AddProgressChart({Value=50})
local function color(value) return {math.floor(value.R*255+.5),math.floor(value.G*255+.5),math.floor(value.B*255+.5)} end
local scenes={}
for _,name in ipairs(Library:GetThemeNames()) do
    w:SetTheme(name)
    local scene={Name=name,Palette={},CardBackground=color(card.ValueLabel.Parent.BackgroundColor3),CardText=color(card.ValueLabel.TextColor3),CardMuted=color(card.SubtitleLabel.TextColor3),PlotBackground=color(chart.Plot.BackgroundColor3),PlotText=color(chart.MinLabel.TextColor3),Legend=color(chart.Legend.TextColor3),Series=color(chart._pool[1].BackgroundColor3),FillText=color(progress.ProgressFillLabel.TextColor3),Contrast={}}
    for _,role in ipairs(w:GetThemeRoles()) do scene.Palette[role]=color(w.Palette[role]) end
    scene.Contrast.Card=Library:ContrastRatio(card.ValueLabel.TextColor3,card.ValueLabel.Parent.BackgroundColor3)
    scene.Contrast.Subtitle=Library:ContrastRatio(card.SubtitleLabel.TextColor3,card.ValueLabel.Parent.BackgroundColor3)
    scene.Contrast.Series=Library:ContrastRatio(chart._pool[1].BackgroundColor3,chart.Plot.BackgroundColor3)
    scenes[#scenes+1]=scene
end
local file=assert(io.open("docs/contrast-colors.json","w")); file:write(game:GetService("HttpService"):JSONEncode(scenes)); file:close(); w:Destroy(); Mock.pump(100)
assert(Mock.Connections==0)
