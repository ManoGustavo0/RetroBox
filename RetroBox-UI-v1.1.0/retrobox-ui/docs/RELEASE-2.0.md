# RetroBox UI 2.0.0 · relatório da atualização

A 2.0 elimina a troca recorrente do URL da library e oferece distribuição independente de catálogos e módulos de Hub. O Script Hub foi alterado no componente nativo; a interface tradicional, 12 temas, 76 ícones, runtime, perfis, Theme Studio e Command Palette permanecem.

## Arquitetura entregue

`dist/bootstrap/v2.lua` → manifesto Stable/Preview/Pinned → release imutável → tamanho/SHA-256 → compatibilidade semântica/API → Library. Stable e Preview têm manifestos/aliases separados; Pinned exige versão exata. O próximo código compatível é carregado na próxima execução. Cache é opcional; fallback conferido informa a versão e o erro online.

Hubs têm um módulo `{Version,Start}` carregado por LoadHub e um catálogo JSON separado. O catálogo usa apenas ações locais registradas, valida todos os registros antes de aplicar, reutiliza a janela e mantém preferências ainda válidas. CodeUpdate consulta; não faz hot swap. Versões da library, módulo, catálogo e ConfigVersion não são misturadas.

## Layout nativo

Imagem com largura útil inteira e enquadramento 16:9/Fit, sem título Miniatura; placeholder pixel art e status vazios ocultos. Jogos/scripts têm linhas compactas e marcador de seleção. Desktop usa panes independentes; telas menores empilham. Pesquisas possuem limpeza; seleção por jogo é lembrada. A lista cresce com o conteúdo até o limite e então rola internamente.

Um único botão Executar script / Run Script, com feedback de resultado/progresso e cancelamento cooperativo. Entrar no jogo é outra ação. Seleção/detecção/perfis/catalog update não executam scripts nem teleportam. A pesquisa global navega ao scroller correto do hub. IDs públicos e a referência PlayButton foram mantidos.

## Validação realizada

| Verificação | Resultado |
| --- | --- |
| Comparação da base com main 1.9.2 | 147 arquivos idênticos ao Git tree antes da modificação. |
| Suíte de lógica Lua 5.4 com double da engine | 256/256 aprovados; inclui APIs tradicionais, todos os temas, runtime, perfis, imagens, navegação e o Hub. |
| Exemplos distribuídos | 24 executados pelo bootstrap com manifestos/artefatos; sem conexões retidas após cleanup. |
| Publicação/rollback Python | 2/2 aprovados em checkouts temporários, incluindo origem histórica e rollback com fonte local alterada. |
| Integridade | Vetores SHA-256 independentes, incluindo 1 milhão de bytes e limites de padding; artefatos confrontados com hashlib em Python. |
| Canais | Stable/Preview/Pinned, upgrade compatível, prerelease, versão/API incompatíveis e rollback. |
| Falhas | Manifesto inválido, bytes/hash errados, rede/404, compilação/init/versão incorreta, cache corrompido, falta de capacidades e write errors. |
| Catálogos | Atualização/rollback sem execução, bindings locais, favoritos/tema/perfis/views conservados, IDs/campos inválidos rejeitados e teardown durante HTTP yield. |
| Layout | 0/1/3/20 scripts, listas limitadas, descrição longa, 16:9, desktop/telas pequenas/TextScale, rótulos pt-BR/en-US, execução/cancelamento e busca global. |

Os testes são de semântica e propriedades da GUI com engine double. **Renderização, toque, ContentProvider e teleporte dentro de um cliente Roblox real ainda precisam ser conferidos no executor de destino.** A suite não simula uma imagem real de Roblox nem confirma compatibilidade com todos os executores. Nos hubs pessoais entregues, URLs de scripts externos são substituídas por respostas locais inofensivas durante o teste; os scripts reais não são executados pela validação.

## Critérios de aceitação

| Critério | Evidência |
| --- | --- |
| Mesmo loader recebe outra versão compatível | Teste 2.0.0 → 2.1.0 usando o mesmo cliente e bootstrap. |
| Pinned mantém versão | Rejeita release divergente; manifesto de release imutável. |
| Preview independente | Testes de canal e pipeline conservam o apontamento Stable. |
| Rollback funcional | Builders promovem histórico anterior e conferem seus bytes. |
| Catálogo remoto sem substituir consumidor | ReloadCatalog/AutoLoad; demonstração publicada. |
| Correções de código do Hub | Módulo Version/Start e bootstrap LoadHub funcional, próximo load. |
| Configurações preservadas | IDs/Schema/ConfigFolder mantidos; round trips antigos e favoritos/tema. |
| Imagem maior | Frame com largura inteira e 16:9; validado nas propriedades. |
| Sem título Miniatura | Title vazio e label invisível. |
| Altura das listas adequada | 0/1/3/20 entradas com altura pelo conteúdo e limite. |
| Sem dois Play | Sem ação interna nas linhas; somente PlayButton principal. |
| Executar script como rótulo | Testes pt-BR/en-US. |
| Teleporte independente | Suite de confirmação/falhas e execução separada. |
| Resoluções | Propriedades de colunas/empilhamento/TextScale; conferência visual real pendente. |
| APIs anteriores | Suíte de regressão e 24 exemplos. |
| Documentação real | Guias, migração, exemplos, builders e validator do prompt. |

## Publicação e arquivos

O caminho histórico foi preservado. A nova pasta dist fica na raiz do repositório. O manifesto de API 2 inicialmente aponta para 2.0.0 em Stable e Preview; somente 2.0.0 existe no histórico inicial. Um rollback para outra versão precisará de uma release histórica já publicada. Commits/PR e conferência pública são registrados na entrega final; um commit de branch isolado não equivale a promover main.

Alterações principais: RetroBox.lua, Loader.lua; src/UpdateCore.lua, UpdateAPI.lua e HubUpdates.lua; tools/build_distribution.py, build_hub_release.py, verify_distribution.py e validate_prompt.py; tests/update.lua, hub-update.lua, distribution.lua, mock_roblox.lua, headless.lua, hub.lua e test_release_pipeline.py; novos exemplos de loaders/código/catalog e adaptação dos exemplos anteriores; README/API/DISTRIBUTION/SCRIPT-HUB/GITHUB/VALIDATION/CHANGELOG, AUTO-UPDATE, HUB-AUTO-UPDATE e MIGRATION-2.0.

O prompt de uso foi atualizado integralmente, com estrutura e exemplos tradicionais preservados. Os loaders dos modelos Mano Gustavo passam a usar API 2 sem mudar seus IDs/perfis ou os jogos/scripts configurados.

## Endereços e operação

- [Bootstrap permanente](https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua)
- [Stable v2](https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/channels/stable/v2.json)
- [Preview v2](https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/channels/preview/v2.json)
- [Manifesto Pinned 2.0.0](https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/releases/2.0.0/manifest.json)
- [Fonte 2.0.0](https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/releases/2.0.0/RetroBox.lua)

Como publicar e fazer rollback da library: [AUTO-UPDATE.md](AUTO-UPDATE.md). Como publicar código/dados/rollback do Hub: [HUB-AUTO-UPDATE.md](HUB-AUTO-UPDATE.md). Como migrar o loader antigo uma única vez: [MIGRATION-2.0.md](MIGRATION-2.0.md).
