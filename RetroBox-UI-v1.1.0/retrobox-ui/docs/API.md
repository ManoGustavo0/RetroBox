# RetroBox UI API · 1.3.0

Os nomes públicos são em inglês. `Locale` aceita `"pt-BR"` e `"en-US"`. Textos dos controles pertencem ao seu script.

## Library

| Método / campo | Comportamento |
| --- | --- |
| `Library.Version` | Versão |
| `CreateWindow(options)` | Cria a janela no cliente |
| `RegisterTheme(name, colors)` | Registra paleta; campos omitidos herdam Retro98 |
| `GetThemeNames()` | Nomes de temas em ordem alfabética |
| `GetCapabilities()` | Booleans: GetHui, ReadFile, WriteFile, MakeFolder, IsFile, IsFolder, ListFiles, FileStorage |
| `CreateFileStorage(folder?)` | Adaptador de arquivos; retorna tabela ou nil, reason se faltam funções |
| `DestroyAll()` | Destrói janelas desta instância |

Todos os métodos acima usam `Library:Nome(...)`.

O arquivo principal retorna Library ao ser carregado por `loadstring(game:HttpGet(rawUrl))()`. `Loader.lua` acrescenta diagnósticos. Substitua a URL dos exemplos pela sua fonte raw publicada; veja [GITHUB.md](GITHUB.md).

## CreateWindow

| Opção | Padrão | Uso |
| --- | --- | --- |
| `Id` | GUID | Recriar o mesmo ID substitui a janela anterior da library |
| `Title` / `Subtitle` | Apresentação RetroBox | Identidade |
| `Icon` | Nenhum | String de imagem Roblox no título |
| `Theme` | `"Retro98"` | Nome registrado |
| `Accent` | Cor do tema | Color3 ou HEX |
| `Font` | `Enum.Font.Code` | Fonte dos componentes |
| `TooltipDelay` | `0.4` | Atraso padrão do hover, de 0 a 3 segundos |
| `TooltipMaxWidth` | `320` | Largura máxima padrão da dica, de 160 a 640 pixels |
| `Size` | `Vector2.new(790, 570)` | Tamanho; mínimo lógico de 300×300 |
| `Scale` | `1` | De 0.75 a 1.5, com ajuste automático à tela |
| `ToggleKey` | `RightShift` | Enum.KeyCode; Unknown desativa |
| `Parent` | Detecção automática | gethui → CoreGui → PlayerGui; Parent explícito tem prioridade |
| `Locale` | `"pt-BR"` | Idioma interno |
| `ShowProfile` | `true` | Avatar, DisplayName e @Name do LocalPlayer |
| `Settings` / `Launcher` / `Notifications` | `true` | Aba Configurações + engrenagem, reabrir e notificações |
| `ErrorNotifications` | `true` | Avisos de erros em callbacks; respeita Notifications |
| `ReducedMotion` / `Scanlines` | `false` | Reduzir animações e linhas CRT estáticas |
| `DestroyOnClose` | `false` | X oculta e permite reabrir; true destrói |
| `LauncherText` / `LauncherPosition` | `"UI"` / `Vector2.new(.025,.1)` | Texto de 1–16 bytes e posição relativa à tela (0–1) |
| `QuickActions` | `true` | Exibe atalhos flutuantes registrados pelos controles |
| `FloatSize` / `FloatOpacity` | `64` / `1` | Tamanho 44–96 px e opacidade 0.2–1 |
| `DisplayOrder` | `50` | Ordem da ScreenGui |
| `Storage` | Arquivo ou memória | Tabela Save/Load própria tem prioridade |
| `FileStorage` | `true` | Arquivos automáticos se o executor oferecer funções; false seleciona memória |
| `ConfigFolder` | `RetroBox/script-<Id codificado>` | Caminho relativo ao workspace do executor, até 180 bytes |
| `AutoSave` | Desativado | Nome de perfil; debounce de 0.8 s |
| `MaxConfigBytes` | `262144` | Limite; de 1024 a 1048576 bytes |

O perfil mostra a pessoa que abriu o script. A personalização é da interface; não muda a identidade da conta Roblox.

`window.Parent` é o container selecionado; `ParentMode` vale gethui/CoreGui/PlayerGui/custom. `window.StorageMode` vale file/memory/custom. `GetCapabilities()` verifica a presença das funções, sem garantir que permissões ou escrita funcionarão. Falhas de salvar/carregar retornam erro nos métodos correspondentes.

## Window

| Método | Uso |
| --- | --- |
| `CreateTab(titleOrOptions)` | Opções: Title, Icon, Columns (1 ou 2) |
| `SetTitle` / `SetSubtitle` / `SetIcon` | Identidade |
| `SetTheme(name, keepAccent?)` | Troca tema e, por padrão, limpa destaque próprio |
| `SetAccent(color)` | Color3/HEX; nil restaura cor do tema |
| `SetScale(number)` | 0.75 a 1.5 |
| `SetToggleKey(key)` | Enum.KeyCode ou nome válido |
| `SetReducedMotion` / `SetScanlines` | Boolean |
| `SetProfileVisible` / `SetNotifications` / `SetLauncher` | Boolean |
| `Show()` / `Hide()` / `Toggle()` | Visibilidade |
| `Minimize(bool?)` / `Center()` | Minimizar e centralizar |
| `ShowSettings(bool?)` | Sem argumento, alterna |
| `SetLauncherOptions({Text?, Position?, Enabled?})` | Personaliza o botão de reabrir; posição Vector2 de 0 a 1 |
| `SetFloatingOptions({Enabled?, Size?, Opacity?})` | Personaliza todos os atalhos flutuantes |
| `AddFloatingButton(options)` | Atalho ligado a Control ou Callback; retorna handle |
| `SetSearch(text)` | Filtra título, descrição, categoria e ID |
| `SearchControls(text)` | Lista resultados {Control, Tab, Section}; exclui controles internos/ocultos |
| `FocusControl(controlOrId)` | Abre a aba, rola e destaca; retorna ok, err sem executar a ação |
| `GetFlag(id)` / `SetFlag(id, value, silent?)` | Consultar/alterar controle |
| `ExportConfig(asTable?)` | Retorna JSON ou cópia de tabela |
| `ImportConfig(source, {Silent?, Strict?})` | JSON/tabela; retorna ok, err |
| `SaveConfig(name)` | Retorna ok, jsonOrError |
| `LoadConfig(name, options?)` | Retorna ok, err |
| `GetConfigNames()` | Perfis da sessão + Storage.List; retorna array, err opcional |
| `SetStorage(adapter)` | Tabela com Save e Load |
| `Reset(silent?)` | Padrões de controles persistentes e janela |
| `Notify(options)` | Notificação ou nil |
| `Dialog(options)` / `Confirm(options)` | Modal retrô; retorna handle ou nil se destruída |
| `OnDestroy(callback)` | Hook síncrono após limpeza; listener desconectável |
| `Destroy()` | Desconecta eventos e remove GUI |

Use `window:Metodo(...)`. `window.Flags` pode ser consultado; escrever diretamente nessa tabela não atualiza componentes. Use SetFlag.

Notify aceita Title, Content, Kind (success/error/normal), Duration (0.1–30 s). Há no máximo quatro notificações.

## Tab e Section

```lua
local tab = window:CreateTab({ Title = "Visual", Columns = 2 })
local left = tab:CreateSection({ Title = "Cores", Side = "Left" })
local right = tab:CreateSection({ Title = "Detalhes", Side = "Right" })
```

Telas estreitas empilham colunas e levam a navegação para o topo. `tab:Select()` seleciona; `tab:Destroy()` remove as categorias e controles.

Section aceita `SetTitle(text)`, `SetVisible(bool)`, `CreateRow(options?)` e `Destroy()`.

```lua
local row = left:CreateRow({ Gap = 10, StackAt = 440 })
row:AddToggle({ Id = "row_enabled", Title = "Ativar" })
row:AddButton({ Title = "Executar", Feedback = true, Callback = function() return true end })
```

Uma Row aceita os mesmos constructors de Section. Os controles usam colunas de larguras iguais e a altura do mais alto. Abaixo de StackAt, ou com mais de três controles, a linha se empilha. Gap aceita 0–32; StackAt, 200–1000. `row:SetVisible` e `row:Destroy` controlam a linha. IDs, valores, busca, callbacks e perfis continuam registrados na janela. Rows não podem ser aninhadas.

## Opções comuns

`Id`, `Title`, `Description`, `Tooltip` (ou `Tip`), `Default`, `Callback`, `Visible` (true), `Disabled` (false), `Persist` e `FireOnInit` (false). Toggle, Button e Keybind também aceitam `Floating = true` ou opções de atalho flutuante.

IDs são únicos por janela. Use IDs explícitos para preservar configurações entre versões. O prefixo `__retrobox/` é reservado. IDs automáticos seguem a ordem de criação.

Callbacks comuns usam task.spawn e pcall. Liberações de Hold durante destruição ou restauração podem ser síncronas para encerrar o estado antes da operação; continuam protegidas. Erros geram logs e notificações quando habilitadas. A lógica e os eventos próprios do script pertencem ao desenvolvedor.

## Componentes de Section

| Constructor | Valor / callback | Opções e métodos próprios |
| --- | --- | --- |
| `AddToggle` | boolean | Default false; Keybind opcional ao lado; Floating |
| `AddSlider` | number | Min, Max, Step, Suffix; campo para digitar |
| `AddButton` | Callback recebe controle | Text, Feedback, BusyText, SuccessText, ErrorText; Press() impede chamadas sobrepostas |
| `AddInput` | string | Placeholder, Multiline, Live, MaxLength, Validate |
| `AddDropdown` | string/nil | Options, Searchable, SetOptions(array, preserve?), SetOpen(bool) |
| `AddDropdown({Multi=true})` | array de strings | Ordem canônica de Options, sem duplicatas |
| `AddKeybind` | (active, binding) | Teclado/Mouse 1–3; Mode: Press/Toggle/Hold; AllowMouse, CaptureOnly; Trigger(active?) |
| `AddColorPicker` | (color, opacity, state) | HSV/HEX/RGB, opacidade e animação |
| `AddProgress` | number | Min, Max; porcentagem |
| `AddConsole` | string | Height, MaxLines; Append(message), Clear() |
| `AddLabel` | string | Height, descrição, SetText(text) |
| `AddSeparator` | string | Divisor com título |
| `AddImage` | string de imagem | Image, Height |

Cada constructor recebe uma tabela de opções. Label e Separator também aceitam texto diretamente.

Button, Label, Separator, Image e Console não persistem. Progress só persiste com Persist=true.

Input confirma ao perder foco; Live=true confirma cada edição válida. Validate(text) retorna true ou false, reason. Entradas inválidas conservam o valor anterior. MaxLength conta bytes.

Dropdown recebe opções string/number e normaliza para string. Abrir um fecha o anterior; clicar novamente no cabeçalho fecha.

Keybind aceita Enum.KeyCode, Enum.UserInputType.MouseButton1/2/3 ou seus nomes em string. Clique no campo e pressione a tecla/botão escolhido; Escape cancela, Backspace limpa e perder foco cancela a captura. AllowMouse=false restringe ao teclado. OnChanged observa a atribuição; Callback observa Press/Toggle/Hold, com o EnumItem escolhido no segundo argumento. Capturar um atalho não executa sua ação. Entrada processada, texto focado, Configurações e modais bloqueiam ações. Soltar, desabilitar, trocar o binding ou destruir libera Hold. O atalho da janela permanece restrito ao teclado e tem prioridade sobre bindings com a mesma tecla.

Toggle pode receber `Keybind = { Default = Enum.UserInputType.MouseButton2, Mode = "Toggle" }`, ou o binding diretamente. `toggle.Keybind` é o controle de captura, com ID padrão `<Id do toggle>/keybind`. Seu valor é salvo separadamente. Toggle/Press alternam o toggle; Hold ativa enquanto pressionado. A caixa de captura aparece ao lado do checkbox; clicar nela não altera o toggle.

Button mostra BusyText (padrão traduzido "Executando...") durante o callback. Feedback=true gera aviso de sucesso/erro ao terminar. `return false, reason` informa uma falha; uma exceção também vira erro. O botão recupera seu estado e não executa duas ações simultâneas. O callback continua pertencendo ao script; a library não desfaz efeitos externos.

## Control

- `GetValue()` copia tabelas.
- `SetValue(value, silent?)` valida e atualiza a GUI; callbacks só disparam se mudou.
- `OnChanged(callback)` retorna listener com Connected e Disconnect().
- `SetTitle`, `SetDescription`, `SetVisible` e `SetDisabled`.
- `SetTooltip(value)` / `SetTip(value)`, `GetTooltip()`, `ShowTooltip()` e `HideTooltip()`.
- `AddFloatingButton(options?)` em Toggle/Button/Keybind retorna um handle, também exposto em `control.FloatingButton`.
- `Destroy()` desconecta e libera seu ID.

Um controle destruído não volta à janela; seu ID pode ser reutilizado.

## Tooltip

Todos os componentes de Section aceitam a opção `Tooltip`. Use uma string ou uma tabela:

```lua
local control = section:AddButton({
    Title = "Executar",
    Description = "Descrição fixa abaixo do título.",
    Tooltip = {
        Title = "O que esta função faz",
        Text = "O desenvolvedor escreve a explicação aqui.\nTambém aceita quebras de linha.",
        Delay = 0.4,
        MaxWidth = 320,
    },
    Callback = function() print("Sua função") end,
})
```

| Campo | Padrão | Limite / uso |
| --- | --- | --- |
| `Text` | Obrigatório na tabela | String com até 4096 bytes; texto simples |
| `Title` | Título atual do controle | String opcional com até 256 bytes |
| `Delay` | `window.TooltipDelay` | 0–3 segundos; atraso do hover |
| `MaxWidth` | `window.TooltipMaxWidth` | 160–640 pixels; reduzido se a tela for menor |

`Tip` é um alias da opção; `Tooltip` tem prioridade se ambos forem fornecidos. `nil`, `false` ou string vazia removem a dica. `GetTooltip()` retorna uma cópia da tabela normalizada ou nil; valores herdados da janela continuam omitidos nessa cópia.

`SetTooltip(value)` atualiza o texto e as opções. `SetTip(value)` é um alias desse método. `ShowTooltip()` abre imediatamente junto ao controle visível; `HideTooltip()` fecha sua dica e cancela seu hover pendente. Esses métodos retornam o controle. Se a janela estiver oculta, minimizada ou o controle estiver numa aba oculta ou atrás do painel de configurações, a dica não abre.

No mouse, passar sobre o controle inicia o atraso; sair cancela ou fecha. No toque, segurar o título ou a descrição abre a dica; ela continua aberta ao soltar e fecha ao tocar nela ou em outro lugar. Ler a dica não chama Callback nem altera o valor do componente. Controles Disabled também podem mostrar a explicação.

O painel acompanha o tema e a fonte, quebra linhas e ajusta posição e dimensões aos limites da tela. Texto maior que a área disponível é truncado. A janela usa um único painel, criado quando necessário. Busca, troca de aba, arraste, perda de foco, ocultação e destruição encerram dicas pendentes ou abertas. As dicas não fazem parte de Flags ou dos perfis JSON.

## Diálogos

```lua
local dialog = window:Confirm({
    Title = "Restaurar?",
    Content = "Os valores atuais serão substituídos pelos padrões.",
    ConfirmText = "Restaurar", CancelText = "Cancelar", Kind = "danger",
    OnConfirm = function() window:Reset() end,
    OnCancel = function() end,
})
```

Confirm usa dois botões e seleciona Cancelar como ação padrão de Enter. Escape, X ou Close cancelam. OnConfirm só é chamado ao escolher o botão de confirmação; OnCancel ao cancelar. Abrir outro diálogo substitui o anterior. A janela encerra captura de binding/drag e libera Holds; o modal bloqueia os atalhos do script.

`Dialog({Title, Content, Buttons, DefaultButton?, DismissOnOutside?, OnClose?})` permite 1–3 botões `{Text, Callback?, Kind?}`. DefaultButton é um índice válido; padrão 1. OnClose recebe reason, index. Title aceita até 256 bytes; Content, 8192; texto de botão, 1–64. Texto é simples, quebra linhas e pode ser truncado em telas pequenas. Métodos do handle: `SetContent(text)`, `Choose(index)` e `Close(reason?)`. O handle expõe Result, Reason e Destroyed. Escolher duas vezes não repete a ação. Destruir a janela remove o modal e seus eventos.

## Atalhos flutuantes

```lua
local control = section:AddToggle({
    Id = "feature", Title = "Ativar recurso",
    Keybind = { Default = Enum.UserInputType.MouseButton2, Mode = "Toggle" },
    Floating = { Text = "RECURSO", Position = Vector2.new(.04,.65) },
    Callback = function(enabled) print(enabled) end,
})
control.FloatingButton:SetPosition(Vector2.new(.1,.5))
window:SetFloatingOptions({ Enabled = true, Size = 64, Opacity = .8 })
```

Floating aceita Id, Text, Position (Vector2 de 0 a 1), MobileOnly (true), Visible (true), VisibleWithMenu (false) e Mode. Por padrão, o botão aparece em dispositivos com toque quando o menu está oculto/minimizado. MobileOnly=false permite teste no PC; VisibleWithMenu=true o mantém com o menu aberto. Arraste pela barra `::`; pressione a área principal para agir. Arrastar não executa a função.

Toggle aceita Press/Toggle (ambos alternam) e Hold (ativa enquanto pressionado). Button usa Press; Keybind herda seu próprio Mode. Desabilitar ou destruir o controle também afeta seu atalho. Os botões refletem o estado atual do toggle. Soltar fora do botão, perder foco ou desligar atalhos libera Hold. Posicionamento é limitado à tela e lembrado no perfil, junto de tamanho/opacidade. IDs explícitos permitem restaurar posições em outra execução.

`window:AddFloatingButton({Id?, Text?, Control?, Callback?, ...})` cria um atalho ligado a um controle da janela ou a um Callback próprio `(active, handle)`. O handle tem `Activate(active?)`, `Release()`, `SetPosition(Vector2)` e `Destroy()`. Também está disponível como control.FloatingButton quando criado pelo controle. `window:SetLauncherOptions` personaliza o botão de reabrir; sua barra `::` também permite arrastar.

## Pesquisa

A pesquisa lista até 30 resultados, mostrando controle, aba e categoria. Clique, ou use setas e Enter, para selecionar. Isso abre a aba, rola até o componente e o destaca por 1.5 s, sem chamar seu Callback. Escape fecha os resultados. `SearchControls` retorna a lista completa; `FocusControl` também pode ser chamado por código. A filtragem existente de SetSearch permanece disponível. Controles internos, explicitamente ocultos e linhas ocultas são excluídos da lista.

## ColorPicker

```lua
local picker = section:AddColorPicker({
    Id = "color",
    Title = "Cor",
    Default = { Color = "#336699", Opacity = 1, Rainbow = false, Speed = 6 },
    Expanded = false,
    AllowRainbow = true,
    AllowOpacity = true,
    Callback = function(currentColor, opacity, manualState) end,
})
```

Default também aceita Color3 ou HEX diretamente. Color aceita Color3, #RRGGBB e #RGB. Componentes de Color3 devem ser finitos e entre 0 e 1.

| Campo | Significado |
| --- | --- |
| Color | Cor manual preservada durante RGB |
| Opacity | 0–1; inversa de Transparency |
| Rainbow | Boolean de animação |
| Speed | 0.1–60 segundos por ciclo; menor valor = mais rápido |

Métodos: `GetColor()` retorna cor atual; `SetColor`, `SetOpacity`, `SetRainbow` e `SetSpeed` aceitam silent como segundo argumento. `SetOpen(bool)` expande o painel.

RGB chama Callback aproximadamente 30 vezes/s, compartilhando uma conexão por janela. OnChanged observa mudanças de configuração, não cada frame. Desligar RGB restaura a cor manual. Disabled pausa a animação. Ocultar a janela conserva o RGB para o elemento do script.

## Paletas

RegisterTheme aceita Color3/HEX em Background, Surface, Inset, Text, Muted, Border, Highlight, Shadow, Accent, AccentText, Success e Danger.

Paletas acompanham a exportação. Importar uma paleta a registra só naquela janela, preservando outras janelas.

## Storage e configurações

```lua
window:SetStorage({
    Save = function(name, json)
        -- Grave no seu backend.
        return true -- ou false, reason
    end,
    Load = function(name)
        -- Retorne JSON/tabela ou nil, reason.
        return json
    end,
    -- Opcional; permite listar saves depois de reexecutar o script.
    List = function() return { "default", "Meu preset" } end,
})
```

Por padrão, readfile + writefile + makefolder habilitam arquivos; isfile/isfolder são opcionais. Sem as três funções necessárias, usa memória. `FileStorage=false` seleciona memória mesmo se houver funções. Um Storage próprio tem prioridade. AutoSave usa debounce e não carrega automaticamente. Nome de perfil: 1–64 bytes, sem barras ou controles.

Os arquivos ficam em `ConfigFolder/profile-<nome codificado>.json`. `profiles-index.json` registra até 256 nomes para a lista sobreviver a outra execução, mesmo sem listfiles. Indexar um perfil novo envolve uma escrita extra; sobrescrever um nome já indexado conserva o índice. O índice é validado antes de salvar e erros de leitura/escrita são informados. Espaços, pontos, percentuais e bytes não alfanuméricos são codificados; nomes de perfil não viram subpastas. ConfigFolder rejeita caminho absoluto, segmentos . e .., caracteres incompatíveis e nomes reservados. Só SaveConfig cria pastas/arquivos. Use pasta e IDs estáveis entre execuções.

```lua
local adapter, reason = Library:CreateFileStorage("RetroBox/MeuScript")
if adapter then window:SetStorage(adapter) end
```

`GetConfigNames()` combina perfis desta sessão e Storage.List, se disponível. O adaptador automático lê o índice e usa listfiles opcionalmente para descobrir saves antigos. Sem índice nem listfiles, um save antigo ainda pode ser carregado pelo nome digitado; salvar novamente o indexa. Adaptadores próprios precisam de List para enumerar saves de outras execuções. A aba Configurações permite selecionar/carregar um save ou digitar um nome, e confirma antes de sobrescrever pela interface. SaveConfig da API escreve diretamente. Sem funções de arquivo, os perfis usam memória; destruir a janela encerra esses saves.

Ao executar novamente o mesmo ID no mesmo container, um registro de ciclo de vida em getgenv (ou _G) permite limpar eventos da janela anterior antes da substituição. O registro interno `__RetroBoxUIWindows` guarda referências locais; não persiste perfis.

Crie todos os controles antes de carregar. Silent=true evita callbacks; sincronize sua lógica com GetFlag. Com false, callbacks são enviados após aplicar os valores, incluindo valores já iguais aos salvos. Holds são encerrados antes da aplicação; eventos anteriores ainda na fila não sobrescrevem o perfil carregado. Keybind restaura a atribuição, sem executar uma ação Press/Toggle. Cores, opacidade, RGB, temas, escala, atalho da janela e aparência/posições dos botões flutuantes acompanham o perfil. Tipo incompatível, schema incorreto e valores inválidos retornam erro antes da aplicação. Perfis Schema=1 das versões anteriores continuam aceitos.

Use `window:OnDestroy(callback)` para desconectar eventos criados pelo seu script. A library limpa os eventos que criou.

## Referências nativas

- [Funções de arquivo / especificação UNC](https://github.com/unified-naming-convention/NamingStandard/blob/main/api/filesystem.md)
- [gethui / teste de referência UNC](https://github.com/unified-naming-convention/NamingStandard/blob/main/UNCCheckEnv.lua)

- [Players / avatar](https://create.roblox.com/docs/reference/engine/classes/Players)
- [GuiButton / Activated](https://create.roblox.com/docs/reference/engine/classes/GuiButton)
- [GuiObject / MouseEnter, MouseLeave e TouchLongPress](https://create.roblox.com/docs/reference/engine/classes/GuiObject)
- [TextService / GetTextSize](https://create.roblox.com/docs/reference/engine/classes/TextService)
- [Color3](https://create.roblox.com/docs/reference/engine/datatypes/Color3)
- [RunService](https://create.roblox.com/docs/reference/engine/classes/RunService)
- [HttpService / JSON](https://create.roblox.com/docs/reference/engine/classes/HttpService)
