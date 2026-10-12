# Changelog

## 1.6.0 · 2026-10-12

- AwaitAction, handle:Await e ctx:AwaitAction por evento, com resultado original, falha, timeout, cancelamento separado da espera/ação e proteção contra corrida/deadlock. OnCancel e timers/observadores com limpeza; máximo 256 esperas por janela.
- CreateTask aceita Group/Policy e usa os mesmos grupos de RunAction. Uma iteração por tarefa, intervalo após conclusão, fila cancelável e políticas Queue/Ignore/Reject/Replace sem outro mutex.
- Task.Status somente leitura, GetStatus/Subscribe, solicitação/execução efetiva, fases, prazo monotônico, resultado/erro e motivo de parada. Remaining é calculado sem notificações por frame.
- Toggle:BindTask opcional e bidirecional, sincronização de falhas/paradas/restarts, política de intenção após parada e limpeza ao desfazer a ligação.
- ConfigVersion independente por script, RegisterMigration/SetConfigVersion e migrações sequenciais antes da validação/aplicação em lote. Originais preservados em falha; UnknownFlags Ignore/Preserve/Reject e dados desconhecidos limitados.
- Launcher UI arrastável pelo corpo ou pela barra :: com mouse/toque, limiar de clique, posição persistente, clamp após resize e Reset.
- Hide/Show e minimizar/restaurar preservam aba, Configurações e rolagem. Body estrutural oculta lupa e conteúdo imediatamente ao recolher, inclusive durante animação.
- Arraste manual calcula o delta na posição local da âncora, sem misturar AbsolutePosition/inset. Não salta, não faz relayout por movimento nem deixa inércia. SmoothDragging continua aceito para reposicionamento gerenciado, padrão false.
- Padding horizontal central de 12 px em campos editáveis/dropdowns, respeitando ícones/setas e alinhamentos próprios.
- Guia de integração, exemplo com inventário/saldo simulados, dashboard e smoke atualizados. 151 testes locais e nove exemplos passaram; conferência visual/entrada no executor real permanece pendente.

## 1.5.0 · 2026-10-12

- ColorPicker separa HEX à esquerda e amostra à direita, preservando título externo, flags, campos e RGB.
- Arraste suavizado por delta de frame sem relayout por movimento; offset de mouse/toque preservado, limites e preferência de resposta. Minimizar/restaurar preserva a posição do cabeçalho.
- Scopes de recursos com limpeza única, reversa e protegida, ownership de janela/controle e políticas opt-in de Hide/Disable/False. Ocultar/minimizar mantém trabalho ativo por padrão.
- Tarefas periódicas idempotentes, sem sobreposição mesmo com yield, reinício cooperativo, tratamento de erros e Stop All.
- Ações canceláveis, progresso/status/resultado, grupos Ignore/Reject/Queue/Replace e integração com botões. Replace espera o worker anterior devolver o controle.
- Estados observáveis e derivados, bindings bidirecionais e condições All/Any/Not com explicação de indisponibilidade. SetFlags valida o lote antes de aplicar e os observadores recebem todas as flags juntas; load/reset usam o mesmo agrupamento.
- StatCard com valor/unidade/subtítulo/tendência/status/formatos e sparkline; gráficos Line/Bar/Progress/Sparkline nativos, história limitada, escala automática/manual, labels/grid/legenda e pooling/throttle de desenho.
- Animador central cancela conflitos e limpa tweens; abertura/ocultação, componentes, seções recolhíveis, avisos e modais. ReducedMotion respeitado; preferências de animação/arraste salvas em Schema=1, com perfis antigos compatíveis.
- Diagnósticos limitados a 64 erros, Debug com traceback/estado, avisos repetidos limitados, OnError e adaptador opcional de callbacks sem dependência de executor específico.
- Guia de runtime, dashboard simulado, smoke ampliado, conceito visual atualizado e documentação. 120 testes de lógica e oito exemplos passaram; validação visual e de executor real permanece pendente.

## 1.4.0 · 2026-10-11

- Identidade visual em pixel art: símbolo de caixa, detalhes estáticos e 46 ícones embutidos que acompanham as paletas.
- Icon por nome em janela, abas, categorias, controles, notificações e diálogos; SetIcon em janela/aba/categoria/controle e SetTitle em abas.
- Ícones padrão na busca, engrenagem, ações da janela, checkbox/dropdown, notificações e diálogos. Textos/emojis e IDs de imagens continuam aceitos; SetIcon(nil/false) remove.
- GetIconNames, GetIcon e RegisterIcon para consultar o catálogo e registrar desenhos próprios; validação antes da alteração e atualização dos desenhos montados.
- PixelIcons e PixelDecorations em Aparência, com API, persistência em saves e Reset. Saves anteriores sem esses campos continuam aceitos; ícones explícitos do dev permanecem visíveis.
- Renderização por Frames agrupados horizontalmente, sem assets remotos para o catálogo, loops de animação ou eventos por pixel. Limpeza ao trocar desenhos e destruir a GUI.
- Catálogo PNG, 46 SVGs para design, novo símbolo, conceito atualizado, guia de ícones e exemplo navegável. Dez testes novos; 82 testes locais e sete exemplos passaram. Conferência em executor real permanece pendente.

## 1.3.0 · 2026-10-11

- Aba Configurações automática e engrenagem que a seleciona, com saves de nomes livres, lista persistente e confirmação de sobrescrita.
- Índice de nomes para listar saves em outra execução sem exigir listfiles; enumeração opcional de arquivos antigos e Storage.List para adaptadores próprios.
- Keybind com teclado e Mouse 1/2/3; seletor ao lado do toggle e valores preservados nos perfis.
- Linhas de controles combinados, que se empilham em telas estreitas.
- Atalhos flutuantes ligados a Toggle/Button/Keybind, com arraste separado da ação, Hold e aparência/posições salvas.
- Busca com resultados navegáveis, seleção por setas/Enter e destaque do controle, sem executar sua função.
- Diálogos/confirmacões retrô, estado de execução e feedback opcional de sucesso/erro em botões.
- X passa a ocultar por padrão; DestroyOnClose=true mantém destruição. RightShift continua como padrão; botão de reabrir configurável e arrastável.
- Holds e eventos antigos são encerrados antes de carregar/restaurar. Toque longo para ler ajuda não ativa o toggle.
- 72 testes locais e seis exemplos passaram. Renderização e entradas na engine real seguem pendentes.

## 1.2.0 · 2026-10-11

- Tooltip opcional em todos os controles, com texto simples ou título, atraso e largura próprios; `Tip` é um alias.
- Dicas com visual do tema, quebra de linhas, posição limitada à tela e um painel compartilhado por janela.
- Abertura por hover no mouse ou toque longo no título/descrição; ler a dica não chama callbacks.
- SetTooltip/SetTip, GetTooltip, ShowTooltip e HideTooltip para controle por código.
- Cancelamento ao mudar abas, buscar, abrir configurações, arrastar, ocultar ou destruir; limpeza de eventos e tarefas pendentes.
- Exemplo de tooltips, API documentada e oito testes novos; 49 testes locais e cinco exemplos passaram.
- Loader, documentação e exemplos apontam para o raw existente de ManoGustavo0/RetroBox.
- Conferência visual e dos eventos na engine real permanece pendente.

## 1.1.0 · 2026-10-11

- Fluxo principal por GitHub raw + loadstring para executores.
- Exemplos independentes de instalação no Studio.
- Montagem automática da GUI por gethui, CoreGui e PlayerGui, com fallback de permissão.
- Arquivos JSON automáticos, ConfigFolder, FileStorage e diagnóstico de capacidades.
- Loader com mensagens de erro e guia de publicação no GitHub.
- 41 testes locais, incluindo HTTP, arquivos, recriação da janela e quatro exemplos.
- Teste da engine adaptado ao executor; modelo Studio e projeto Rojo removidos do pacote atual.

## 1.0.0 · 2026-10-11

- Primeira implementação independente em Luau.
- Identidade retrô, seis paletas e temas personalizados.
- Perfil automático do LocalPlayer e painel de personalização.
- Controles, abas, categorias, colunas e busca.
- HSV/RGB/HEX, opacidade e atualização compartilhada.
- Atalhos, configurações, integração Storage e ciclo de vida.
- Exemplos, documentação, modelo de demonstração e testes.
