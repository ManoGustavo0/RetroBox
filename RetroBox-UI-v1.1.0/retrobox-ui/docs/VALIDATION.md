# Validação · RetroBox UI 1.7.0

## Executado

- Compilação sintática de todos os arquivos Lua pelo subconjunto compatível com Lua 5.4.
- **187 testes de lógica** com sinais, instâncias e serviços simulados; os 151 testes da 1.6 continuam na suíte.
- Carregamento dos 16 exemplos por HTTP simulado + compilação do conteúdo real de `RetroBox.lua`; dashboard inicia simulação/conclui ação, e runtime-integration carrega um perfil antigo, sincroniza toggles e executa coleta/venda no grupo compartilhado.
- Loader com respostas inválidas, falha de download e erro de compilação.
- GUI por gethui/CoreGui/PlayerGui: preferência, fallback quando falta permissão, Parent explícito, falhas e limpeza ao executar de novo.
- Arquivos: detecção parcial, fallback para memória, pastas criadas sob demanda, restauração em outra instância da library, JSON inválido, falha de escrita, nomes sem colisões, caminhos inválidos, funções opcionais e debounce do AutoSave.
- Componentes, callbacks, listeners, enums, cores, RGB compartilhado, importação atômica, temas, teclas, foco, configurações, buffers, notificações e limpeza das conexões.
- Oito testes de tooltip: atraso/cancelamento do hover, painel único, Tip e atualização, toque longo, fechamento, limites da tela/tema, limpeza, validação atômica, clipping, arraste e foco. Ler dicas não altera valores nem chama callbacks.
- 23 testes de novos fluxos: aba Configurações, X/RightShift/reabrir, saves nomeados por UI, confirmação, índice entre execuções, arquivos antigos, corrupção, Storage.List, captura de mouse, combinações, Hold, filas anteriores ao load, linhas responsivas, feedback, modais, pesquisa, atalhos flutuantes, aparência/posições e toque longo.
- Dez testes de pixel art: catálogo/cópias, identidade padrão, espaço de títulos com atalhos, temas/contraste, desenhos próprios, validação atômica, texto/assets anteriores, preferências persistentes/Reset/saves antigos, notificações/diálogos e limpeza em trocas repetidas. O runner também carrega o novo exemplo icons.lua.
- 17 testes de runtime: correção HEX/amostra, scopes/chaves/limpeza, políticas opt-in e restart, cópia/ciclos de State, lotes/perfis coerentes, bindings bidirecionais silenciosos/normalização, All/Any/Not, callbacks antigos descartados, tarefas com yield sem sobreposição, Stop All, ações Replace/Queue/Reject/Ignore e histórico limitado, botões canceláveis e diagnóstico/adapter/Debug.
- Nove testes de dashboard: formatos, cards/status/histórico, retenção/pool, barras negativas/zero, Progress/Sparkline, desenho coalescido, parâmetros inválidos sem registro parcial, linhas responsivas/resize e falhas de formatador isoladas.
- 12 testes de animação: conflitos por propriedade, Hide/Show rápidos e cliques bloqueados, ReducedMotion, preferências/perfis/Reset, collapse/search, destruição durante saída de toasts, barreira modal, drag sem relayout, minimize reversível, limpeza de componentes animados, mouse/toque/offset/foco/janelas independentes e transições de componentes durante Hide/Show.
- Cinco regressões de interação: mouse/toque com origem/inset não zero e escalas .75/1/1.5, sem salto/inércia; launcher pelo corpo, limiar/clique, dedos independentes, save/reset/resize; aba/Configurações/scroll preservados; Body/lupa/auxiliares durante recolhimento; padding central.
- 16 testes de integração: Await/resultados/falhas/Throw, timeout separado/CancelAction, contexto cancelável, conclusão anterior/destruição/deadlock, múltiplas esperas/timers, grupos/fila/políticas, próximo prazo após conclusão, status sem emissões por frame, toggles/paradas/erros/restarts/KeepRequested, listeners e scheduler com task.spawn imediato.
- Dez testes de migração: renomear/converter em sequência, cópia/original/arquivo preservados em falha, passos ausentes/versão futura/corrupção/Migrate=false, flags desconhecidas/transitórias, valores/aparência atômicos, dados sem código/ciclos, rejeição de yield, saves antigos, BindTask após lote e limites de versões/payload.
- 23 testes de componentes/contraste: registro forte de estilos, binding combinado, seis temas em cards/plots/legendas, superfícies mistas, Terminal via UI/save/load, molduras/padding, eventos de linhas descartadas, exclusão em memória/arquivos/falhas, descrição/refluxo/ajuda, virtualização/âncora/scroll horizontal, filtros/ordenação, construção inválida sem registro parcial, dados reativos, árvore e menus/submenus/toque.
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

1. Publique a fonte 1.7.0 no caminho usado pelo raw; ajuste a URL se tiver movido o arquivo ou use um commit fixado para testar uma PR.
2. Execute o showcase e confira perfil, temas, textos, rolagem, arraste, redimensionamento, minimizar/maximizar e RightShift.
3. Confira HSV, R/G/B, HEX, opacidade, RGB e velocidade. O círculo do showcase é um exemplo de ligação por callback.
4. Na aba Configurações, crie saves com nomes próprios, selecione/carregue e confira callbacks/valores. Confirme e cancele sobrescritas. Execute de novo com os mesmos IDs/ConfigFolder e confira a lista de saves e os arquivos restaurados.
5. Execute `examples/tooltips.lua`. Confira o atraso do hover, sair do controle, trocar abas, buscar, tema e dicas perto dos limites da tela. Em toque, segure o título/descrição, solte e toque para fechar; confirme que o callback não foi executado por ler a dica.
6. Execute `examples/workflows.lua`: capture teclas e Mouse 1/2/3, teste Toggle/Press/Hold, soltar fora da interface e troca do binding. Verifique linhas combinadas, setas/Enter na busca, destaque sem callback, confirmações e botão ocupado/feedback. No toque, confira arraste dos atalhos pela barra ::, ação sem arraste, tamanho/opacidade e posições restauradas. X deve ocultar e o launcher/RightShift reabrir.
7. Verifique toque e tela pequena nos dispositivos que quiser suportar; execute `tests/executor-smoke.lua`. O teste cria componentes, troca temas, importa configurações, alterna RGB, usa diálogos/busca/atalhos e abre/atualiza/fecha uma dica pela API da engine real.
8. Confira a mensagem `[RetroBox] Real-engine smoke passed`, depois inspecione a aparência e entrada. Essa mensagem sozinha não valida a experiência visual.
9. Teste `window:Destroy()` e confirme que atalhos, RGB, modais e callbacks anteriores foram encerrados.
10. Execute `examples/icons.lua`: confira catálogo, seleção, desenhos personalizados, títulos, abas/categorias e avisos. Troque os seis temas, escala e tamanho da tela; verifique contraste, recortes e atalhos junto aos títulos. Desative os ícones padrão/detalhes em Aparência, salve/carregue e confirme que ícones explícitos permanecem.
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

1. Execute examples/contrast-showcase.lua. Alterne os seis temas sem recriar widgets; observe os quatro cards das capturas, plots/legendas/escalas, porcentagem em 0/25/50/75/100%, console e tooltips. O relatório numérico complementa a inspeção visual.
2. Execute examples/advanced-components.lua: role 2.000 itens, procure/filtre, atualize dados com IDs estáveis, ordene tabelas e role horizontalmente; teste seleção, botão direito, toque longo e teclas de lista/árvore.
3. Execute examples/theme-studio.lua: crie variação, edite, restaure, salve/carregue catálogo, duplique, exporte/importe e exclua com confirmação; oficiais devem continuar preservados. LoadThemeCatalog não deve acionar flags do script.
4. Execute examples/runtime-inspector.lua: inicie tarefa, enfileire ação no grupo, gere erro intencional, observe estados e selecione detalhes. Cancelamento aparece só quando habilitado e deve confirmar. Destrua/reabra o painel e confira limpeza.
5. Execute examples/dashboard-builder.lua: mude ordem/span/altura, redimensione a janela, salve layout e restaure; updates de valores não devem recriar controles.
6. Execute examples/command-palette.lua: F4, pesquisa, seleção por clique/teclado, navegar sem executar função, comando registrado e confirmação. Teste Escape, clique fora, troca de aba e ocultação durante overlays.
7. Execute examples/help-accessibility.lua: descrição longa em tela pequena, preferência global, tooltip com descrição oculta, badge/toque, .2 s padrão, Tab/Shift+Tab/Enter/Espaço e texto em .8/1/1.4.
8. Crie dois perfis e exclua um pela UI. Cancele/confirme, confira lista e arquivo/índice; sem delfile/Delete, a indisponibilidade deve ser explícita. Excluir AutoSave não deve recriar o arquivo.

A suíte Lua 5.4 não reproduz a coleta de proxies nativos de Instance; o teste confirma ownership forte e registro persistente, com comportamento explicado pela documentação Roblox. O simulador também não comprova clip/hover/rolagem/seleção no renderizador real. **Todos os novos componentes/ferramentas foram implementados e testados localmente; a validação no cliente Roblox permanece pendente.**
