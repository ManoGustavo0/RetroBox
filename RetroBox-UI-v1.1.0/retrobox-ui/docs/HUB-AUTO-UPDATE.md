# Atualizações de hubs · RetroBox 2.0.0

Há três versões distintas: `RetroBox.Version`, `hub:GetVersion()` (módulo de código) e `hub.CatalogVersion` (dados). `ConfigVersion` continua sendo exclusivamente a versão das configurações do script. Trocar uma release da library não muda automaticamente o código de um hub local fixado.

## Catálogo declarativo

O desenvolvedor opta por `CatalogUpdate={Root,Major=1,Channel="stable",AutoLoad=true,Cache?}`. Root é uma origem HTTPS explícita sob seu controle. O próprio exemplo publicado deste repositório é fictício e pode ser executado para testar o fluxo:

```lua
local hub=RetroBox:CreateScriptHub({
    Id="hub-update-demo",Title="Meu Hub",Version="1.0.0",Games={},
    Actions={notice=function(_,activeHub) activeHub.Window:Notify({Content="Aviso local."}) end},
    CatalogUpdate={Root="https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/examples/hub-distribution/catalog",Major=1},
})
```

O updater resolve `dist/channels/<canal>/v<major>.json` nessa Root e obtém um catálogo imutável com digest. O JSON tem `SchemaVersion=1`, `Kind="HubCatalog"`, `HubId`, `Version` e `Games`. Os jogos aceitam os campos normais; scripts aceitam metadados e `Action="nome"`, sem Callback/URL/Source/código. `Enabled` é somente boolean e `Icon` é texto no JSON. Os limites e IDs da API normal continuam válidos. Campos desconhecidos nas entradas são rejeitados.

Action liga a entrada a `Actions[nome]`, uma função **já cadastrada em código**. Action desconhecida deixa a entrada indisponível; não baixa nem executa um script. Se Action for omitida para um ID já existente, mantém o callback e, quando omitidos no JSON, os requisitos/confirm/predicate locais anteriores. Jogos ou scripts novos sem ação registrada ficam indisponíveis.

`AutoLoad=true` é o padrão ao optar por CatalogUpdate: uma ação no scope faz uma verificação/carregamento na inicialização, sem executar scripts ou teleporte. `AutoLoad=false` deixa o carregamento manual. `hub:ReloadCatalog()` retorna `(ok,reportOrError)`, confere **todo** o catálogo antes da mutação e reutiliza janela, listas, flags e IDs. Um contexto de RunAction pode ser passado para cooperar com cancelamento. Falhas preservam o catálogo e a janela ativos.

Favoritos e seleção que ainda existirem são preservados, assim como tema, perfis e posições da janela/launcher. IDs removidos não continuam selecionáveis e favoritos de entradas removidas são retirados da flag; manter os IDs é responsabilidade do publicador. Seleção de script por jogo é conservada durante a sessão. Atualizar o catálogo cancela cooperativamente ações do cadastro anterior para evitar efeitos de referências obsoletas.

## Código versionado do hub

O módulo autorizado retorna `{Version="1.0.0",Start=function(RetroBox,settings) return RetroBox:CreateScriptHub(...) end}`. Não é um catálogo JSON. O desenvolvedor publica esse módulo e seus manifestos em uma origem própria; o usuário conserva apenas um bootstrap pequeno:

```lua
local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))()
local base="https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/examples/hub-distribution/"
local hub,report=RetroBox:LoadHub({Root=base.."code",HubId="hub-update-demo",Major=1,APIVersion=1,
    Settings={CatalogRoot=base.."catalog"}})
assert(hub,report)
hub:Show()
```

Esse endereço é da demonstração publicada, com jogos fictícios. Copie o módulo e publique sua própria Root antes de adaptar para seu catálogo real. `LoadHub` confere versão, hash, protocolo e compatibilidade com a RetroBox e chama Start uma única vez. Não troca o código de um hub aberto. Uma falha em Start é retornada; não tenta Start novamente nem troca uma janela criada parcialmente por fallback automático.

`CodeUpdate={Root,...}` permite anexar consultas de código a um hub local; consulta não aplica código. Hubs criados por LoadHub já recebem o updater de código. `CheckForUpdates()` retorna `(status,error?)` com `Catalog` e `Code` separados. `GetUpdateStatus()` inclui Version, CatalogVersion e LibraryVersion. `SetUpdateChannel(channel,version?)` troca os clientes configurados; Pinned precisa de versão. Não muda a origem nem interpreta configurações/perfis como instruções de atualização.

| Operação | Aplicação |
| --- | --- |
| Catálogo válido | Pode ser aplicado na janela atual por ReloadCatalog. |
| Library nova | Próxima inicialização pelo bootstrap de API 2. |
| Código novo do hub | Próxima execução de LoadHub pelo bootstrap do hub. |
| Preferências do jogador | Perfis existentes, sem código e sem origens executáveis. |

## Publicar e reverter

Use `tools/build_hub_release.py` com `--root`, `--source`, `--version`, `--hub-id`, `--kind catalog/code` e `--channel stable/preview`. O módulo tem seu Version; o JSON também tem Version. Aumente somente a versão do componente que alterou.

```bash
python3 RetroBox-UI-v1.1.0/retrobox-ui/tools/build_hub_release.py --root caminho/do/catalogo --source catalog.json --version 1.1.0 --hub-id meu-hub --kind catalog --channel preview
python3 RetroBox-UI-v1.1.0/retrobox-ui/tools/build_hub_release.py --root caminho/do/codigo --source Hub-source.lua --version 1.2.0 --hub-id meu-hub --kind code --channel preview
```

Os arquivos-fonte/caminhos do comando são arquivos do checkout do **publicador**, não requisitos no executor. O builder gera releases imutáveis, digest/tamanho e manifesto de canal com compatibilidade de library. Publique em seu repositório, verifique os RAWs e promova o canal com `--channel stable`. Para rollback acrescente `--rollback <versão existente>`; publique o novo apontamento e conserve o histórico anterior. Origins de código e catálogo podem ter pastas separadas e versões independentes.

Arquivos e origens reais da demonstração estão em [hub-distribution](../examples/hub-distribution/Hub-source.lua), [hub-bootstrap.lua](../examples/hub-bootstrap.lua) e [hub-catalog.lua](../examples/hub-catalog.lua). Nenhum recurso altera arquivos de terceiros nem contorna restrições do ambiente.
