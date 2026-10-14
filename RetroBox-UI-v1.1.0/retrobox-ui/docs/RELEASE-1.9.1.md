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
