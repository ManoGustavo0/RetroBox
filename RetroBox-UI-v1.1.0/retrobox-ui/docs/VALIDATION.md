# Validação · RetroBox UI 1.9.2

## Executado

- Três regressões da 1.9.2 verificam descrições multiline de jogos/scripts, ajustes de escala, atualização de textos longos/curtos, posição da descrição auxiliar, largura e fallback de medição.

- Compilação sintática de todos os arquivos Lua pelo subconjunto compatível com Lua 5.4.
- **224 testes de lógica** com sinais, instâncias e serviços simulados; os 151 testes da 1.6 continuam na suíte.
- Carregamento dos 19 exemplos por HTTP simulado + compilação do conteúdo real de `RetroBox.lua`; dashboard inicia simulação/conclui ação, e runtime-integration carrega um perfil antigo, sincroniza toggles e executa coleta/venda no grupo compartilhado.
- Loader com respostas inválidas, falha de download e erro de compilação.
- GUI por gethui/CoreGui/PlayerGui: preferência, fallback quando falta permissão, Parent explícito, falhas e limpeza ao executar de novo.
- Arquivos: detecção parcial, fallback para memória, pastas criadas sob demanda, restauração em outra instância da library, JSON inválido, falha de escrita, nomes sem colisões, caminhos inválidos, funções opcionais e debounce do AutoSave.
- Componentes, callbacks, listeners, enums, cores, RGB compartilhado, importação atômica, temas, teclas, foco, configurações, buffers, notificações e limpeza das conexões.
- Oito testes de tooltip: atraso/cancelamento do hover, painel único, Tip e atualização, toque longo, fechamento, limites da tela/tema, limpeza, validação atômica, clipping, arraste e foco. Ler dicas não altera valores nem chama callbacks.
- 23 testes de novos fluxos: aba Configurações, X/RightShift/reabrir, saves nomeados por UI, confirmação, índice entre execuções, arquivos antigos, corrupção, Storage.List, captura de mouse, combinações, Hold, filas anteriores ao load, linhas responsivas, feedback, modais, pesquisa, atalhos flutuantes, aparência/posições e toque longo.
- Dez testes de pixel art: catálogo/cópias, identidade padrão, espaço de títulos com atalhos, temas/contraste, desenhos próprios, validação atômica, texto/assets anteriores, preferências persistentes/Reset/saves antigos, notificações/diálogos e limpeza em trocas repetidas. O runner também carrega o novo exemplo icons.lua.
- A 1.9.1 confere os 76 desenhos de 12×12 e os 30 novos nomes. Monta cada ícone novo com o nome estrito `pixel:`, troca os 12 temas e verifica aparência desativada/restaurada e limpeza em substituições. As exportações SVG e os dois catálogos visuais usam os mesmos padrões Lua.
- 17 testes de runtime: correção HEX/amostra, scopes/chaves/limpeza, políticas opt-in e restart, cópia/ciclos de State, lotes/perfis coerentes, bindings bidirecionais silenciosos/normalização, All/Any/Not, callbacks antigos descartados, tarefas com yield sem sobreposição, Stop All, ações Replace/Queue/Reject/Ignore e histórico limitado, botões canceláveis e diagnóstico/adapter/Debug.
- Nove testes de dashboard: formatos, cards/status/histórico, retenção/pool, barras negativas/zero, Progress/Sparkline, desenho coalescido, parâmetros inválidos sem registro parcial, linhas responsivas/resize e falhas de formatador isoladas.
- 12 testes de animação: conflitos por propriedade, Hide/Show rápidos e cliques bloqueados, ReducedMotion, preferências/perfis/Reset, collapse/search, destruição durante saída de toasts, barreira modal, drag sem relayout, minimize reversível, limpeza de componentes animados, mouse/toque/offset/foco/janelas independentes e transições de componentes durante Hide/Show.
- Cinco regressões de interação: mouse/toque com origem/inset não zero e escalas .75/1/1.5, sem salto/inércia; launcher pelo corpo, limiar/clique, dedos independentes, save/reset/resize; aba/Configurações/scroll preservados; Body/lupa/auxiliares durante recolhimento; padding central.
- 16 testes de integração: Await/resultados/falhas/Throw, timeout separado/CancelAction, contexto cancelável, conclusão anterior/destruição/deadlock, múltiplas esperas/timers, grupos/fila/políticas, próximo prazo após conclusão, status sem emissões por frame, toggles/paradas/erros/restarts/KeepRequested, listeners e scheduler com task.spawn imediato.
- Dez testes de migração: renomear/converter em sequência, cópia/original/arquivo preservados em falha, passos ausentes/versão futura/corrupção/Migrate=false, flags desconhecidas/transitórias, valores/aparência atômicos, dados sem código/ciclos, rejeição de yield, saves antigos, BindTask após lote e limites de versões/payload.
- 26 testes de componentes/contraste: registro forte de estilos, binding combinado, doze temas em cards/plots/legendas, superfícies mistas, Terminal via UI/save/load, molduras/padding, eventos de linhas descartadas, exclusão em memória/arquivos/falhas, descrição/refluxo/ajuda, virtualização/âncora/scroll horizontal, filtros/ordenação, construção inválida sem registro parcial, dados reativos, árvore e menus/submenus/toque.
- 13 testes de ferramentas: temas locais/JSON/proteção/restauração, catálogos sem aplicar flags, aparência inválida atômica, preferências/Reset/saves antigos, preview real do editor, dashboards sem reconstrução e layouts inválidos, status/grupos/cancelamento confirmado do inspector, comandos/palette/foco, e abertura/destruição repetida com recursos/eventos retornando à contagem inicial.
- Verificação dos links locais da documentação, fontes dentro do ZIP e integridade CRC.

```bash
python3 tests/run_headless.py
# ou, com Lua 5.4 instalado:
lua tests/headless.lua
```

O runner Python requer liblua5.4 e usa a biblioteca padrão do Python. O build da imagem e do ZIP usa Pillow:

```bash
python3 tools/build_package.py
```

## Limites

Os testes não renderizam texto, bordas, rolagem ou imagens, nem executam eventos reais de mouse/toque. A medição do TextService, HTTP e funções de arquivo do executor são simulados. Workers podem dar yield e tweens podem concluir depois; o double não interpola propriedades visualmente entre frames. A geometria opcional exercita AbsolutePosition/AbsoluteSize/UIScale/origem, sem reproduzir toda a engine. As esperas usam coroutines estacionadas/retomadas, com timers e task.spawn imediato ou enfileirado simulados. Isso verifica lógica/limpeza, mas não comprova desempenho, fluidez ou compatibilidade com um executor específico.

O double de Destroying também testa entrega adiada após remover a ancestralidade, conforme o comportamento descrito em [Deferred engine events](https://create.roblox.com/docs/scripting/events/deferred). Isso verifica ownership de animações, sem reproduzir todos os eventos da engine.

**Nenhum executor Roblox estava disponível neste ambiente.** A conferência em jogo e no executor alvo, incluindo Unbound, permanece pendente. Não há promessa de suporte a todos os executores.

## Conferir no executor

1. Use o raw verificado da 1.9.2 indicado no prompt ou em DISTRIBUTION.md; ele funciona mesmo antes do merge da PR.
2. Execute o showcase e confira perfil, temas, textos, rolagem, arraste, redimensionamento, minimizar/maximizar e RightShift.
3. Confira HSV, R/G/B, HEX, opacidade, RGB e velocidade. O círculo do showcase é um exemplo de ligação por callback.
4. Na aba Configurações, crie saves com nomes próprios, selecione/carregue e confira callbacks/valores. Confirme e cancele sobrescritas. Execute de novo com os mesmos IDs/ConfigFolder e confira a lista de saves e os arquivos restaurados.
5. Execute `examples/tooltips.lua`. Confira o atraso do hover, sair do controle, trocar abas, buscar, tema e dicas perto dos limites da tela. Em toque, segure o título/descrição, solte e toque para fechar; confirme que o callback não foi executado por ler a dica.
6. Execute `examples/workflows.lua`: capture teclas e Mouse 1/2/3, teste Toggle/Press/Hold, soltar fora da interface e troca do binding. Verifique linhas combinadas, setas/Enter na busca, destaque sem callback, confirmações e botão ocupado/feedback. No toque, confira arraste dos atalhos pela barra ::, ação sem arraste, tamanho/opacidade e posições restauradas. X deve ocultar e o launcher/RightShift reabrir.
7. Verifique toque e tela pequena nos dispositivos que quiser suportar; execute `tests/executor-smoke.lua`. O teste cria componentes, troca temas, importa configurações, alterna RGB, usa diálogos/busca/atalhos e abre/atualiza/fecha uma dica pela API da engine real.
8. Confira a mensagem `[RetroBox] Real-engine smoke passed`, depois inspecione a aparência e entrada. Essa mensagem sozinha não valida a experiência visual.
9. Teste `window:Destroy()` e confirme que atalhos, RGB, modais e callbacks anteriores foram encerrados.
10. Execute `examples/icons.lua`: confira catálogo, seleção, desenhos personalizados, títulos, abas/categorias e avisos. Troque os doze temas, escala e tamanho da tela; verifique contraste, recortes e atalhos junto aos títulos. Desative os ícones padrão/detalhes em Aparência, salve/carregue e confirme que ícones explícitos permanecem.
11. Execute `examples/dashboard.lua` e inicie as amostras. Confira valores, unidades, tendências, Line/Bar/Progress/Sparkline, labels, histórico máximo e comportamento em PC/celular. Mude tamanho/escala e temas enquanto atualiza. O exemplo começa pausado e usa dados simulados.
12. Inicie, cancele e reinicie Processar demonstração, inclusive ao ocultar/minimizar. Stop All deve cancelar as ações e tarefas gerenciadas. Um callback longo que ignora tokens não pode ser encerrado à força; confira cooperatividade no seu script.
13. Salve e carregue animações/arraste. Teste ReducedMotion, velocidade/intensidade, arraste próximo a bordas, foco perdido, mouse e um segundo dedo. Abra/feche repetidamente dropdowns, ColorPicker, categorias e modais; o fechamento do modal não deve acionar controles atrás dele.
14. Crie um erro intencional num callback com Debug=true, veja GetDiagnostics/OnError e depois destrua/reexecute com o mesmo Id. Confira o fim de tasks, observadores, conexões próprias gerenciadas, gráficos e animações.
15. Execute `examples/runtime-integration.lua`: ligue coleta/venda, confira exclusão no grupo, fases/contagem regressiva e desligue enquanto aguarda. Stop All deve desligar toggles por BindTask. Teste erro intencional e restart, Queue/Ignore/Reject/Replace, Await com timeout e cancelamento só da espera ou também da ação.
16. Carregue o perfil antigo do exemplo; confira renomeação da flag e conversão do intervalo antes do início da tarefa. Salve na versão atual e carregue novamente. Teste arquivo corrompido/passos ausentes e confirme que o original e os controles permanecem intactos.
17. Oculte/reabra em Configurações e numa aba rolada; recolha/restaure e confira a lupa oculta durante toda a transição. Arraste o launcher pelo corpo e por ::, clique sem mover, troque resolução e salve/reset sua posição.
18. Arraste a barra com mouse/toque em escalas .75/1/1.5, vários pontos iniciais e resoluções. Pressionar sem mover não deve deslocar; soltar não deve continuar movimento. Confira dropdowns/inputs/campos numéricos e texto com margem consistente.

`docs/visual-concept.png` e `docs/dashboard-concept.png` são ilustrações geradas a partir da paleta; não são capturas de tela da GUI em execução.

## Conferência adicional da 1.7

1. Execute examples/contrast-showcase.lua. Alterne os doze temas sem recriar widgets; observe os quatro cards das capturas, plots/legendas/escalas, porcentagem em 0/25/50/75/100%, console e tooltips. O relatório numérico complementa a inspeção visual.
2. Execute examples/advanced-components.lua: role 2.000 itens, procure/filtre, atualize dados com IDs estáveis, ordene tabelas e role horizontalmente; teste seleção, botão direito, toque longo e teclas de lista/árvore.
3. Execute examples/theme-studio.lua: crie variação, edite, restaure, salve/carregue catálogo, duplique, exporte/importe e exclua com confirmação; oficiais devem continuar preservados. LoadThemeCatalog não deve acionar flags do script.
4. Execute examples/runtime-inspector.lua: inicie tarefa, enfileire ação no grupo, gere erro intencional, observe estados e selecione detalhes. Cancelamento aparece só quando habilitado e deve confirmar. Destrua/reabra o painel e confira limpeza.
5. Execute examples/dashboard-builder.lua: mude ordem/span/altura, redimensione a janela, salve layout e restaure; updates de valores não devem recriar controles.
6. Execute examples/command-palette.lua: F4, pesquisa, seleção por clique/teclado, navegar sem executar função, comando registrado e confirmação. Teste Escape, clique fora, troca de aba e ocultação durante overlays.
7. Execute examples/help-accessibility.lua: descrição longa em tela pequena, preferência global, tooltip com descrição oculta, badge/toque, .2 s padrão, Tab/Shift+Tab/Enter/Espaço e texto em .8/1/1.4.
8. Crie dois perfis e exclua um pela UI. Cancele/confirme, confira lista e arquivo/índice; sem delfile/Delete, a indisponibilidade deve ser explícita. Excluir AutoSave não deve recriar o arquivo.

A suíte Lua 5.4 não reproduz a coleta de proxies nativos de Instance; o teste confirma ownership forte e registro persistente, com comportamento explicado pela documentação Roblox. O simulador também não comprova clip/hover/rolagem/seleção no renderizador real. **Todos os novos componentes/ferramentas foram implementados e testados localmente; a validação no cliente Roblox permanece pendente.**


## Conferência adicional da 1.8

1. Execute `examples/themes-gallery.lua` com o raw da 1.8. Teste Hacker, Dracula, Nord, Sakura, Ocean e Amber. Alterne com o dropdown e com Próximo tema, observando os mesmos cards, gráficos, console e tabela.
2. Selecione cada tema em Configurações, salve um perfil, troque a paleta e carregue o perfil. Confira também os perfis da 1.7.
3. No Theme Studio, duplique cada paleta nova, edite a cópia e restaure. Confira que a paleta oficial permanece preservada.
4. Teste o slider de progresso em 0/25/50/75/100 e confira percentuais sobre preenchimento e vazio, legendas, escalas e avisos.
5. As prévias de `contrast-themes.png` e `themes-new.png` são composições das cores dos widgets no simulador; não substituem esta conferência nativa.


## Regressões da 1.9

- Dez testes de navegação: eventos Activated reais, caminho touch, Enter com foco no campo da palette, alvo de aba após remoção, controles removidos/ocultos/desabilitados, comandos confirmados e falhas, fechar/reabrir, salvar/descartar/cancelar, recursos e scroll/foco com escala.
- Dezenove testes do hub: opcionalidade, catálogo vazio, PlaceId/UniverseId, nenhuma ação na detecção, configuração/CRUD inválidos atômicos, pesquisa/case/sort, perfis silenciosos, URI/cache/falha/retry, limites de pool/cache/concurrency, Play registrado, exclusão mútua, capacidades/confirm/cancelamento, erro real, teleportes solicitados/negados/assíncronos/timeout/adapter, teclado e recriação com o mesmo ID, repintura dos temas.
- Dois testes de distribuição: loader HTTP completo sem funções de arquivo do executor e rejeição de capacidades ausentes/versão antiga. Os testes anteriores de rede/compilação/inicialização continuam.
- O exemplo do prompt é compilado/executado separadamente com a fonte efetivamente publicada; o validator estático confere commit, versão, caminho, APIs, ordem e ausência de arquivo local obrigatório.

A fonte do raw e o Git tree são verificados na publicação. Sinais, serviços, imagens e teleportes dos testes são simulados; isso não confirma um cliente Roblox real. A suíte não renderiza GUI nem realiza teleportes reais.

## Conferência nativa da 1.9

1. Execute remote-loader.lua pelo raw confirmado, sem RetroBox.lua no workspace do executor. Teste HTTP/loadstring ausentes e erros de rede separadamente.
2. Na palette, selecione por mouse/toque/Enter, inclusive campos fora do viewport e seções recolhidas. Confira foco, destaque e scroll nas escalas .75/1/1.5. Navegação não deve disparar callbacks.
3. Abra o Theme Studio, duplique/edite, feche salvando/descartando/cancelando e reabra. Confira retorno à aba e ausência de tabs/objetos duplicados.
4. Execute script-hub.lua. Confira imagens com e sem UniverseId, fallback em assets negados, busca, teclado, favoritos, perfis, ocultar/reabrir e todos os temas.
5. Para testar teleporte, cadastre destinos reais e permitidos; confirme manualmente. Confira TeleportInitFailed e o adapter da experiência. O método cliente legado pode ser rejeitado, e TeleportAsync exige servidor. Não use os registros vazios de demonstração como destinos reais.


## Atualização 2.0.0

A suíte atual possui 256 testes de lógica (incluindo 24 exemplos) e 2 testes de pipeline em Python. Execute `python3 tests/run_headless.py`, `python3 tests/test_release_pipeline.py` e os builders/verifier conforme [AUTO-UPDATE.md](AUTO-UPDATE.md). O relatório [RELEASE-2.0.md](RELEASE-2.0.md) separa evidência de lógica/propriedades da conferência visual real.

No executor, conferir: bootstrap/canais publicados; thumbnail em janela grande/pequena/toque/TextScale; listas com 0/1/3/20 registros; um botão de execução; confirmação de teleporte; falha/timeout; consulta/catalog update sem execução ou perda de perfis; ausência de conexões duplicadas após reexecutar. Não usar o resultado do double como screenshot/renderização nativa.
