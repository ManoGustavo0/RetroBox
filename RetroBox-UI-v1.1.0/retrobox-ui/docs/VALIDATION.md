# Validação · RetroBox UI 1.5.0

## Executado

- Compilação sintática de todos os arquivos Lua pelo subconjunto compatível com Lua 5.4.
- **120 testes de lógica** com sinais, instâncias e serviços simulados.
- Carregamento dos oito exemplos por HTTP simulado + compilação do conteúdo real de `RetroBox.lua`; o dashboard também inicia sua simulação e conclui uma ação com progresso.
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

Os testes não renderizam texto, bordas, rolagem ou imagens, nem executam eventos reais de mouse/toque. A medição do TextService, HTTP e funções de arquivo do executor são simulados. Workers podem dar yield e tweens podem concluir depois; o double não interpola propriedades visualmente entre frames. O arraste é calculado pela library e testado em frames simulados. Eles verificam lógica/limpeza, mas não comprovam desempenho, fluidez ou compatibilidade com um executor específico.

O double de Destroying também testa entrega adiada após remover a ancestralidade, conforme o comportamento descrito em [Deferred engine events](https://create.roblox.com/docs/scripting/events/deferred). Isso verifica ownership de animações, sem reproduzir todos os eventos da engine.

**Nenhum executor Roblox estava disponível neste ambiente.** A conferência em jogo e no executor alvo, incluindo Unbound, permanece pendente. Não há promessa de suporte a todos os executores.

## Conferir no executor

1. Publique a fonte 1.5.0 no caminho usado pelo raw; ajuste a URL se tiver movido o arquivo ou use um commit fixado para testar uma PR.
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

`docs/visual-concept.png` e `docs/dashboard-concept.png` são ilustrações geradas a partir da paleta; não são capturas de tela da GUI em execução.
