# RetroBox UI API · 1.1.0

Os nomes públicos são em inglês. `Locale` aceita `"pt-BR"` e `"en-US"`. Textos dos controles pertencem ao seu script.

## Library

| Método / campo | Comportamento |
| --- | --- |
| `Library.Version` | Versão |
| `CreateWindow(options)` | Cria a janela no cliente |
| `RegisterTheme(name, colors)` | Registra paleta; campos omitidos herdam Retro98 |
| `GetThemeNames()` | Nomes de temas em ordem alfabética |
| `GetCapabilities()` | Booleans: GetHui, ReadFile, WriteFile, MakeFolder, IsFile, IsFolder, FileStorage |
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
| `Size` | `Vector2.new(790, 570)` | Tamanho; mínimo lógico de 300×300 |
| `Scale` | `1` | De 0.75 a 1.5, com ajuste automático à tela |
| `ToggleKey` | `RightShift` | Enum.KeyCode; Unknown desativa |
| `Parent` | Detecção automática | gethui → CoreGui → PlayerGui; Parent explícito tem prioridade |
| `Locale` | `"pt-BR"` | Idioma interno |
| `ShowProfile` | `true` | Avatar, DisplayName e @Name do LocalPlayer |
| `Settings` / `Launcher` / `Notifications` | `true` | Engrenagem, reabrir e notificações |
| `ReducedMotion` / `Scanlines` | `false` | Reduzir animações e linhas CRT estáticas |
| `DestroyOnClose` | `true` | X destrói; com false, oculta |
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
| `SetSearch(text)` | Filtra título, descrição, categoria e ID |
| `GetFlag(id)` / `SetFlag(id, value, silent?)` | Consultar/alterar controle |
| `ExportConfig(asTable?)` | Retorna JSON ou cópia de tabela |
| `ImportConfig(source, {Silent?, Strict?})` | JSON/tabela; retorna ok, err |
| `SaveConfig(name)` | Retorna ok, jsonOrError |
| `LoadConfig(name, options?)` | Retorna ok, err |
| `GetConfigNames()` | Perfis conhecidos em memória |
| `SetStorage(adapter)` | Tabela com Save e Load |
| `Reset(silent?)` | Padrões de controles persistentes e janela |
| `Notify(options)` | Notificação ou nil |
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

Section aceita `SetTitle(text)`, `SetVisible(bool)` e `Destroy()`.

## Opções comuns

`Id`, `Title`, `Description`, `Default`, `Callback`, `Visible` (true), `Disabled` (false), `Persist` e `FireOnInit` (false).

IDs são únicos por janela. Use IDs explícitos para preservar configurações entre versões. O prefixo `__retrobox/` é reservado. IDs automáticos seguem a ordem de criação.

Callbacks usam task.spawn e pcall. Erros geram avisos sem interromper o evento da GUI.

## Componentes de Section

| Constructor | Valor / callback | Opções e métodos próprios |
| --- | --- | --- |
| `AddToggle` | boolean | Default false |
| `AddSlider` | number | Min, Max, Step, Suffix; campo para digitar |
| `AddButton` | Callback recebe controle | Text; Press() impede chamadas sobrepostas |
| `AddInput` | string | Placeholder, Multiline, Live, MaxLength, Validate |
| `AddDropdown` | string/nil | Options, Searchable, SetOptions(array, preserve?), SetOpen(bool) |
| `AddDropdown({Multi=true})` | array de strings | Ordem canônica de Options, sem duplicatas |
| `AddKeybind` | (active, key) | Mode: Press/Toggle/Hold; CaptureOnly; Trigger(active?) |
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

Keybind usa teclado: clicar no campo captura, Escape cancela, Backspace limpa. OnChanged observa a atribuição; Callback observa Press/Toggle/Hold. Entrada processada e campos de texto focados bloqueiam ações.

## Control

- `GetValue()` copia tabelas.
- `SetValue(value, silent?)` valida e atualiza a GUI; callbacks só disparam se mudou.
- `OnChanged(callback)` retorna listener com Connected e Disconnect().
- `SetTitle`, `SetDescription`, `SetVisible` e `SetDisabled`.
- `Destroy()` desconecta e libera seu ID.

Um controle destruído não volta à janela; seu ID pode ser reutilizado.

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
})
```

Por padrão, readfile + writefile + makefolder habilitam arquivos; isfile/isfolder são opcionais. Sem as três funções necessárias, usa memória. `FileStorage=false` seleciona memória mesmo se houver funções. Um Storage próprio tem prioridade. AutoSave usa debounce e não carrega automaticamente. Nome de perfil: 1–64 bytes, sem barras ou controles.

Os arquivos ficam em `ConfigFolder/profile-<nome codificado>.json`. Espaços, pontos, percentuais e bytes não alfanuméricos são codificados; nomes de perfil não viram subpastas. ConfigFolder rejeita caminho absoluto, segmentos . e .., caracteres incompatíveis e nomes reservados. Só SaveConfig cria pastas/arquivos. Use pasta e IDs estáveis entre execuções.

```lua
local adapter, reason = Library:CreateFileStorage("RetroBox/MeuScript")
if adapter then window:SetStorage(adapter) end
```

`GetConfigNames()` lista perfis salvos nesta janela; não varre arquivos externos. O painel aceita o nome de outro perfil salvo para carregá-lo. Se a janela usa apenas memória, destruir a janela encerra esses perfis.

Ao executar novamente o mesmo ID no mesmo container, um registro de ciclo de vida em getgenv (ou _G) permite limpar eventos da janela anterior antes da substituição. O registro interno `__RetroBoxUIWindows` guarda referências locais; não persiste perfis.

Crie controles antes de carregar. Silent=true evita callbacks; sincronize sua lógica com GetFlag. Com false, callbacks são enviados após aplicar os valores. Tipo incompatível, schema incorreto e valores inválidos retornam erro antes da aplicação.

Use `window:OnDestroy(callback)` para desconectar eventos criados pelo seu script. A library limpa os eventos que criou.

## Referências nativas

- [Funções de arquivo / especificação UNC](https://github.com/unified-naming-convention/NamingStandard/blob/main/api/filesystem.md)
- [gethui / teste de referência UNC](https://github.com/unified-naming-convention/NamingStandard/blob/main/UNCCheckEnv.lua)

- [Players / avatar](https://create.roblox.com/docs/reference/engine/classes/Players)
- [GuiButton / Activated](https://create.roblox.com/docs/reference/engine/classes/GuiButton)
- [Color3](https://create.roblox.com/docs/reference/engine/datatypes/Color3)
- [RunService](https://create.roblox.com/docs/reference/engine/classes/RunService)
- [HttpService / JSON](https://create.roblox.com/docs/reference/engine/classes/HttpService)
