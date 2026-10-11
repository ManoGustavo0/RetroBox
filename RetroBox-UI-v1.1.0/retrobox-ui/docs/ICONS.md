# Pixel art · RetroBox UI 1.4.0

A identidade usa uma caixa em pixels, bordas em relevo e pequenos detalhes estáticos. Os 46 desenhos padrão usam uma grade de 12×12. O catálogo Lua é a fonte dos ícones da GUI, dos SVGs e da imagem abaixo.

![Catálogo de ícones](pixel-icons.png)

## Escolher um ícone

```lua
local window = RetroBox:CreateWindow({ Title = "Meu script", Icon = "retrobox" })
local tab = window:CreateTab({ Title = "Visual", Icon = "eye" })
local section = tab:CreateSection({ Title = "Cores", Icon = "palette" })
local toggle = section:AddToggle({ Id = "visual", Title = "Mostrar recurso", Icon = "bolt" })
toggle:SetIcon("target")
window:Notify({ Title = "Pronto", Content = "Atualização concluída.", Icon = "star" })
window:Confirm({ Title = "Continuar?", Content = "Aplicar a mudança?", Icon = "warning" })
```

`window`, `tab`, `section` e controles aceitam `SetIcon`. Na criação, omitir o ícone usa o padrão da janela/aba/categoria; controles só recebem ícone quando o dev escolher um. `Icon=false` e `SetIcon(nil/false)` removem. `Icon="pixel:nome"` exige que o nome exista; um erro não substitui o desenho atual. Texto curto/emoji preserva scripts antigos, e `rbxassetid://` ou um ID numérico positivo usa uma imagem Roblox.

## Nomes incluídos

| Grupo | Nomes |
| --- | --- |
| Identidade e organização | `retrobox`, `home`, `folder`, `grid`, `code`, `terminal` |
| Controles e visual | `eye`, `target`, `mouse`, `keyboard`, `palette`, `sliders` |
| Perfil e interface | `user`, `search`, `settings`, `gamepad`, `mobile`, `notification`, `volume` |
| Arquivos e conexão | `save`, `load`, `copy`, `download`, `upload`, `link`, `globe` |
| Status | `info`, `success`, `warning`, `error`, `check` |
| Ações | `close`, `minimize`, `maximize`, `restore`, `reset`, `refresh`, `chevron-down`, `chevron-right` |
| Destaques | `star`, `heart`, `bolt`, `spark` |
| Proteção | `shield`, `lock`, `unlock` |

`RetroBox:GetIconNames()` retorna os nomes em ordem alfabética, incluindo os registrados pelo dev. `RetroBox:GetIcon(name)` retorna uma cópia das linhas do desenho, ou nil se não existir.

## Desenhar um ícone próprio

```lua
RetroBox:RegisterIcon("gem", {
    "..####..", ".#ahha#.", "#ahhhha#", "#aaaaaa#",
    ".#aaaa#.", "..#aa#..", "...##...", "........",
})
local tab = window:CreateTab({ Title = "Coleção", Icon = "gem" })
```

O nome precisa ter 1–48 caracteres: começa com letra minúscula e aceita letras minúsculas, números, `_` e `-`. Use 4–16 linhas, com 4–16 colunas de largura igual, e pelo menos um pixel visível. A biblioteca valida todo o desenho antes de registrá-lo. Registrar novamente um nome substitui o padrão e atualiza os ícones montados dessa instância da library.

| Caractere | Cor |
| --- | --- |
| `.` | Transparente |
| `#` | Cor do texto no contexto: normal, título, categoria ou aba selecionada |
| `a` | Accent |
| `h` | Highlight |
| `s` | Shadow |
| `m` | Muted |
| `g` | Success |
| `r` | Danger |

As cores vêm da paleta da janela e mudam com o tema. Ícones de controles desabilitados ficam atenuados. No estado selecionado, a cor contextual acompanha AccentText.

## Preferências e desempenho

`PixelIcons` e `PixelDecorations` são true por padrão. O jogador pode alterá-los em Configurações → Aparência. `window:SetPixelIcons(false)` oculta os ícones automáticos e restaura os símbolos de texto das ações; não oculta ícones escolhidos explicitamente pelo dev. `window:SetPixelDecorations(false)` oculta os enfeites estáticos. Essas opções são exportadas, restauradas e retornam ao estado inicial com Reset. Saves antigos, sem esses campos, continuam aceitos.

Os desenhos padrão não usam assets remotos: são Frames nativos, com pixels da mesma cor agrupados horizontalmente. Só ícones montados criam objetos. Não há loops de animação nem sinais por pixel. Trocar um desenho destrói seus objetos anteriores; destruir a interface limpa os handles e suas conexões de ciclo de vida.

A grade usa posições e tamanhos inteiros antes da UIScale. Uma escala fracionária ou tela pequena pode alterar o tamanho físico dos pixels: confira no executor/dispositivo alvo. Imagens externas usam `ResampleMode=Pixelated`; carregamento e permissão do asset continuam dependendo do Roblox.

Os [SVGs](../assets/pixel-icons) são exportações na paleta Retro98 para documentação/design. A GUI usa os desenhos Lua embutidos; não tente carregar SVG diretamente em ImageLabel. Veja [icons.lua](../examples/icons.lua) e [API.md](API.md).
