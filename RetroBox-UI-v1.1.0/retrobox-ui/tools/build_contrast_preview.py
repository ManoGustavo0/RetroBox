from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,math,html
repo=Path(__file__).resolve().parents[1]; scenes=json.loads((repo/'docs/contrast-colors.json').read_text())
image=Image.new('RGB',(1440,1220),'#eee9df');d=ImageDraw.Draw(image)
f=lambda n:ImageFont.truetype('DejaVuSansMono.ttf',n)
d.text((36,26),'RETROBOX / SURFACE & INK',font=f(26),fill='#21364b')
d.text((36,66),'v1.7.0 · propriedades reais do código · composição ilustrativa, sem renderizador Roblox',font=f(13),fill='#53585d')
for i,s in enumerate(scenes):
    x=36+(i%2)*700;y=108+(i//2)*356;p=s['Palette'];bg=tuple(p['Background']);surface=tuple(p['Surface']);ink=tuple(s['CardText']);muted=tuple(s['CardMuted']);inset=tuple(s['CardBackground'])
    d.rectangle((x,y,x+668,y+328),fill=bg,outline=tuple(p['Border']),width=2)
    d.rectangle((x+5,y+5,x+663,y+34),fill=tuple(p['Accent']))
    d.text((x+15,y+10),s['Name'].upper(),font=f(15),fill=tuple(p['AccentText']))
    d.rectangle((x+12,y+48,x+326,y+172),fill=inset,outline=tuple(p['Border']))
    d.text((x+25,y+60),'Peixes capturados',font=f(13),fill=ink)
    d.text((x+25,y+85),'128',font=f(31),fill=ink)
    d.text((x+25,y+135),'Evento simulado · 142 lançamentos',font=f(11),fill=muted)
    d.rectangle((x+340,y+48,x+656,y+172),fill=inset,outline=tuple(p['Border']))
    d.text((x+353,y+60),'Precisão / último peixe',font=f(13),fill=ink)
    d.text((x+353,y+88),'91%  /  Dourado',font=f(21),fill=ink)
    d.text((x+353,y+135),'Texto secundário sobre Inset',font=f(11),fill=muted)
    d.rectangle((x+12,y+192,x+468,y+295),fill=tuple(s['PlotBackground']),outline=tuple(p['Border']))
    points=[(x+28+j*50,y+272-round((math.sin(j*.75)+1)*25)) for j in range(9)]
    d.line(points,fill=tuple(s['Series']),width=3)
    d.text((x+25,y+201),'Histórico / legenda / escala',font=f(11),fill=tuple(s['Legend']))
    d.rectangle((x+485,y+192,x+656,y+245),fill=inset,outline=tuple(p['Border']))
    d.rectangle((x+486,y+193,x+570,y+244),fill=tuple(s['Series']))
    d.text((x+593,y+208),'50%',font=f(15),fill=ink)
    d.text((x+485,y+267),'texto %.2f:1'%s['Contrast']['Card'],font=f(11),fill=tuple(p['Text']))
    d.text((x+485,y+285),'subt. %.2f:1'%s['Contrast']['Subtitle'],font=f(11),fill=tuple(p['Text']))
d.text((36,1190),'Os testes medem cores; clipping, métricas e mouse/toque ainda exigem conferência no cliente.',font=f(13),fill='#53585d')
image.save(repo/'docs/contrast-themes.png',optimize=True)
# The supplied dark screenshot preserved Retro98 Inset while Monokai ink changed.
fixture={'source':'Capturas fornecidas pelo usuário: tema claro e Monokai com superfície clara retida','OldBackground':[249,247,236],'OldPrimary':[248,248,242],'OldSecondary':[195,198,178],'Expected':'surface and foreground update together; normal text contrast >= 4.5'}
(repo/'tests/fixtures').mkdir(exist_ok=True);(repo/'tests/fixtures/contrast-regression.json').write_text(json.dumps(fixture,ensure_ascii=False,indent=2)+'\n')
print('Generated six-theme contrast proof and screenshot regression fixture')
