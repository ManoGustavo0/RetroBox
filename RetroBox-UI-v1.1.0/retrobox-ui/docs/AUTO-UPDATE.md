# Distribuição e auto-update · RetroBox 2.0.0

O bootstrap permanente de API 2 é [dist/bootstrap/v2.lua](https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua). Ele resolve um manifesto do canal, valida major/API/limites semânticos e confere tamanho e SHA-256 antes de compilar a library. A mesma URL recebe versões **2.x compatíveis na próxima execução**. Não substitui a library da janela que já está aberta.

```lua
local URL="https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"
local RetroBox,report=loadstring(game:HttpGet(URL))({Channel="stable"})
-- Fluxo tradicional preservado:
local window=RetroBox:CreateWindow({Id="meu-script",Title="Meu Script",Locale="pt-BR"})
local section=window:CreateTab("Principal"):CreateSection("Controles")
section:AddLabel({Title=RetroBox.Version})
```

O caminho histórico `RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua` continua sendo a fonte standalone da versão atual. O nome da pasta não é sua versão. O bootstrap e os artefatos também são standalone: não exigem `require`, ModuleScript, instalação no Studio ou um `RetroBox.lua` local.

## Canais e contratos

| Canal | Configuração | Manifesto | Comportamento |
| --- | --- | --- | --- |
| Stable | `{Channel="stable"}` ou opções omitidas | `dist/channels/stable/v2.json` | Somente releases sem prerelease, major 2 e API 2. |
| Preview | `{Channel="preview"}` | `dist/channels/preview/v2.json` | Canal independente; aceita prereleases 2.x. |
| Pinned | `{Channel="pinned",Version="2.0.0"}` | `dist/releases/2.0.0/manifest.json` | Exige exatamente essa versão, mesmo se Stable mudar. |

Na primeira publicação, Stable e Preview apontam para a mesma 2.0.0, em manifestos separados. Uma promoção posterior de Preview não altera Stable. Uma futura API 3 terá outro bootstrap e canais próprios; `bootstrap/v2.lua` permanece reservado à API 2.

`dist/stable/v2/RetroBox.lua` e `dist/preview/v2/RetroBox.lua` são aliases da release do canal. Para validação de integridade, compatibilidade e diagnóstico, prefira o bootstrap. `dist/releases/<versão>/RetroBox.lua` e seu manifesto são históricos imutáveis; os builders recusam sobrescrevê-los com bytes diferentes.

Versões são comparadas como SemVer, incluindo prerelease e build metadata; `2.10.0 > 2.9.0`. `MaxVersion` é exclusivo. O bootstrap fixa `Major=2`, `APIVersion=2`, `MinVersion="2.0.0"` e `MaxVersion="3.0.0"`; o consumidor pode estreitar MinVersion/MaxVersion.

## Cache e diagnóstico

O cache é opcional: `{Cache=true}`. Usa `readfile`, `writefile`, `makefolder` quando disponíveis e armazenamento da sessão quando não estiverem. Pasta padrão `RetroBox/Updates`; `CacheFolder` aceita caminho relativo sem traversal. Não mistura origens, canais, tipos de artefato ou versões fixadas. Um adapter pode oferecer `Get(key)` e `Set(key,record)`.

Se a rede, o manifesto ou o artefato falhar, `Cache=true` pode recuperar a última fonte desse canal/origem, conferindo **novamente** manifesto, versão, tamanho, digest e contrato. `Fallback=false` proíbe isso. A recuperação emite aviso e retorna `State="Fallback"`, `Fallback=true`, `CurrentVersion` usada e `Error` da tentativa online. Falha de gravação fica em `CacheError`; não vira uma gravação bem-sucedida fictícia. Sem cache validado, retorna erro. Não há loop de atualização.

`RetroBox:CheckForUpdates(options?)` consulta somente metadados e retorna `(status,error?)`. `GetUpdateStatus()` copia o último estado. `GetVersion()` retorna a versão em execução. O relatório tem `State`, `Channel`, `Kind`, `Root`, `CurrentVersion`, `AvailableVersion`, `Build`, `Compatible`, `LastCheck`, `Error`, `Fallback` e `Cache` quando aplicáveis. Estados incluem Idle, Checking, UpToDate, Available, RollbackAvailable, Loaded, Fallback e Failed. A consulta não destrói janelas nem instala código em execução.

`ParseVersion(version)`, `CompareVersions(a,b)` e `SHA256(bytes)` também estão disponíveis. `CreateUpdater(options)` retorna um cliente com `Check()`, `Load("json"?)`, `GetStatus()` e `SetChannel(channel,version?)`. É uma API de distribuição para origens declaradas pelo desenvolvedor, não um instalador de terceiros. HTTP e carregamento dinâmico dependem do executor; hashing requer o `bit32` do Luau. A falta de uma capacidade é diagnosticada.

## Publicar uma release da library

Na raiz do checkout:

```bash
python3 RetroBox-UI-v1.1.0/retrobox-ui/tools/build_distribution.py --embed-only
python3 RetroBox-UI-v1.1.0/retrobox-ui/tests/run_headless.py
python3 RetroBox-UI-v1.1.0/retrobox-ui/tools/build_distribution.py --channel preview
python3 RetroBox-UI-v1.1.0/retrobox-ui/tools/verify_distribution.py
```

1. Altere a fonte e aumente `Library.Version`; atualize os módulos em `src` quando necessário. O embed recompõe o standalone e o bootstrap, sem dependências de arquivos no executor.
2. Execute a suíte e a verificação de distribuição. Publique a release e o manifesto imutáveis em um commit/PR.
3. Verifique os URLs públicos e teste a versão Preview. A promoção para Stable é `build_distribution.py --channel stable`; publique esse novo apontamento depois da validação.
4. Atualize documentação, prompt e exemplos. Um commit de branch não é uma promoção de `main`; o status público só muda após merge e conferência do RAW.

`dist/history.json` lista releases disponíveis. A verificação em Python usa `hashlib`, independente do hash implementado em Luau, e recusa tamanho/versionamento/path inconsistentes.

## Rollback

```bash
python3 RetroBox-UI-v1.1.0/retrobox-ui/tools/build_distribution.py --channel stable --rollback 2.0.0
python3 RetroBox-UI-v1.1.0/retrobox-ui/tools/verify_distribution.py
```

Publique o manifesto/alias resultantes. O builder confere a release antiga; não reescreve seu histórico. Stable passa a resolver a versão anterior na próxima execução; Pinned e Preview continuam independentes. O histórico inicial de API 2 contém apenas 2.0.0; um rollback para outra versão exigirá que ela já tenha sido publicada. Os RAWs históricos 1.x continuam acessíveis por seus commits; não são carregados pelo bootstrap de API 2.

## Limites de confiança

HTTPS e a origem configurada são a fronteira de confiança. O manifesto só contém paths relativos a essa origem; URLs externas, caminhos absolutos/traversal e origens inseridas no catálogo são rejeitados. SHA-256 detecta corrupção e inconsistência de bytes; não é assinatura e não protege uma conta do publicador ou o próprio host comprometidos. O bootstrap inicial também vem dessa origem autorizada.

Sem HTTP não há consulta online. Sem loadstring não há atualização dinâmica de library/código. O cache não elimina a necessidade de obter o bootstrap pelo mecanismo de distribuição do desenvolvedor; não promete iniciar offline quando o primeiro `HttpGet` do consumidor falhar. Catálogos são JSON e nunca são compilados. Veja [HUB-AUTO-UPDATE.md](HUB-AUTO-UPDATE.md) para a distribuição independente de hubs.
