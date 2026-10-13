# RetroBox 1.7.0 · Relatório da atualização

A atualização amplia a 1.6 sem trocar o raw histórico ou exigir módulos externos. Todas as funcionalidades abaixo foram implementadas e exercitadas em testes locais. Renderização e entrada em um cliente Roblox real não foram executadas neste ambiente.

| Item solicitado | Entrega e evidência |
| --- | --- |
| 1. Resumo | Superfícies/contraste, componentes virtuais, ferramentas, ajuda/teclado e perfis integrados |
| 2. Bugs | Padding/moldura de dropdown, style registry forte, Terminal via UI/save/load, exclusão de perfis e limpeza de eventos/atualização |
| 3. Visual | Texto relativo à superfície; fundos e tintas atualizados juntos; percentual sobre preenchimento/vazio; margens e foco |
| 4. Componentes | VirtualList, DataTable e TreeView com pool de linhas; ContextMenu com submenus/teclado/toque |
| 5. Theme Studio | Preview real, variações locais, editor/restauração, duplicação/exclusão, JSON, catálogo no perfil e proteção dos oficiais |
| 6. Runtime Inspector | Opt-in, status/grupos/fila/recursos/diagnósticos, filtros/detalhes/cópia e cancelamento explicitamente habilitado/confirmado |
| 7. Dashboard Builder | Reutiliza widgets; grid responsiva, ordem/span/altura, edição opcional, reset e layout salvo |
| 8. Command Palette | F4 configurável, busca/navegação existente e comandos registrados em RunAction; seleção explícita |
| 9. Description / Tooltip 2.0 | Medição/refluxo e compactação, preferência global/per-control, regiões compartilhadas, badge e atraso .2 s |
| 10. Acessibilidade | Foco e Tab/Shift+Tab/Enter/Espaço, teclas de lista/árvore, fonte .8–1.4, ajuda por toque e ReducedMotion existente |
| 11. API | Guia ADVANCED.md com padrões, limites, métodos, eventos e exemplos; API.md/RUNTIME.md atualizados |
| 12. Compatibilidade | Os 151 testes da 1.6 permanecem; Schema=1, ConfigVersion independente e perfis antigos sem Advanced continuam aceitos |
| 13. Testes | Sintaxe Lua, regressões anteriores, componentes/ferramentas, fixture das capturas e 16 exemplos por HTTP simulado |
| 14. Resultados | 187/187 testes de lógica; temas exercitados sem reconstrução e repetição de tool lifetimes volta às contagens iniciais |
| 15. Limitações | Sem executor real; validar fonte/recortes/scroll/foco/input/fluidez. Datasets têm limites documentados; fixed row height; recursos do inspector resumem a raiz |
| 16. Arquivos | RetroBox.lua, tests/advanced.lua, tests/tools.lua, fixture, sete exemplos, smoke, docs e ferramentas de preview |
| 17. Commits | Implementação/testes e documentação/visuais são publicados em commits descritivos da branch da atualização |
| 18. Publicação | PR da atualização; main recebe a versão após merge. O prompt entregue usa commit fixado para funcionar antes |

O catálogo de 46 ícones em pixel art foi reaproveitado. Hover continua presente; o ajuste corrige a geometria da moldura. A paleta original fica disponível no editor: a renderização ajusta a tinta para a superfície específica.

Dados de sessão, funções, Instances e execução de tarefas não são salvos como configurações. Catálogos e layouts usam Appearance.Advanced do mesmo perfil. LoadThemeCatalog lê a aparência sem reaplicar flags do script. DeleteConfig não remove a cópia em memória quando o backend falha; sem Delete/delfile, informa indisponibilidade.

Não existem recursos listados apenas como planejamento. Os limites e a validação nativa pendente são descritos em [VALIDATION.md](VALIDATION.md). O guia de API é [ADVANCED.md](ADVANCED.md).
