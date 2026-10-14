# RetroBox 1.9.1 · Mais 30 ícones em pixel art

O catálogo passa de 46 para **76 ícones embutidos**. Cada desenho novo usa a grade 12×12 e as cores semânticas da paleta da janela. A interface desenha os pixels localmente, sem assets externos para os ícones.

| Grupo | Novos nomes |
| --- | --- |
| Economia e recursos | `diamond`, `coins`, `money`, `wallet`, `bank`, `credit-card` |
| Ferramentas | `tools`, `wrench`, `hammer`, `screwdriver`, `pickaxe`, `axe`, `shovel`, `toolbox` |
| Equipamentos | `sword`, `bow`, `chest`, `backpack`, `potion`, `key` |
| Recompensas | `crown`, `trophy`, `gift` |
| Atividades | `rocket`, `fish`, `magnet` |
| Contexto | `clock`, `map`, `skull`, `leaf` |

Use `Icon="diamond"`, por exemplo. `Icon="pixel:diamond"` exige um nome válido. Os novos ícones também funcionam nos registros de scripts do hub, em avisos, diálogos, títulos, categorias e controles. Os 46 desenhos antigos e seus nomes foram preservados.

[Catálogo visual e uso](ICONS.md) · [Exemplo executável](../examples/icons.lua)

O carregamento continua pelo raw com `loadstring(game:HttpGet(URL))()`. O modo normal `CreateWindow → CreateTab → CreateSection` e os perfis continuam compatíveis. Nenhum arquivo local da library é necessário para os scripts de usuário.

## Verificação

O catálogo, os 12 temas, a troca de ícones, o estado desativado, o exemplo e a limpeza são verificados pela suíte existente. A lista completa de limites está em [VALIDATION.md](VALIDATION.md): testes de lógica e imagens de documentação não equivalem à execução visual em um cliente Roblox.

Resultados: **221/221 testes de lógica e 19 exemplos aprovados**. Os 30 ícones novos foram conferidos nos 12 temas, em estados ativos/desativados e em trocas com limpeza. Os catálogos foram inspecionados visualmente. Os padrões dos 46 ícones anteriores permanecem idênticos.

O [raw confirmado da 1.9.1](https://raw.githubusercontent.com/ManoGustavo0/RetroBox/6486c4be4db877e4eb2e94f714f4ae4da3fdf762/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua) foi baixado e comparado byte a byte ao código testado. Commit da implementação: `6486c4be4db877e4eb2e94f714f4ae4da3fdf762`. [PR #9](https://github.com/ManoGustavo0/RetroBox/pull/9).

O Loader e o exemplo principal do prompt compilaram e inicializaram essa fonte baixada sem funções de arquivo do executor. Os 76 ícones e a limpeza da janela foram conferidos nesse fluxo. O Mano Gustavo Hub foi atualizado para o mesmo raw e passou nas 15 verificações de integração existentes.
