# RetroBox 1.8.0 · Temas

A 1.8.0 acrescenta **Hacker, Dracula, Nord, Sakura, Ocean e Amber**, totalizando doze temas oficiais. Cada paleta inclui fundos, superfícies internas, texto principal/secundário, bordas, relevos, destaque, seleção, sucesso e erro.

Os temas funcionam nas Configurações, em `CreateWindow({Theme = "Hacker"})`, em `SetTheme`, nos perfis e no Theme Studio. As paletas oficiais são preservadas no editor; uma cópia pode ser personalizada. A API anterior, os IDs existentes, o esquema dos perfis e o caminho histórico do raw continuam compatíveis.

O pacote inclui a galeria [themes-gallery.lua](../examples/themes-gallery.lua), o [guia de temas](THEMES.md) e prévias calculadas a partir das cores reais dos componentes no simulador. A galeria abre em Hacker e compara as seis novas paletas sem reconstruir cards, gráficos, console ou tabela. Todos os dados são simulados.

## Validação

- Sintaxe de todos os arquivos Lua no subconjunto compatível com Lua 5.4.
- 190 testes de lógica, incluindo a suíte anterior, integridade dos tokens, proteção dos temas oficiais, seleção via UI, restauração de saves e cópias editáveis das seis paletas.
- Contraste em widgets existentes para todas as paletas: texto principal/secundário, legendas, escalas e preenchimento; resolução sobre a superfície efetiva.
- Dezessete exemplos carregados por HTTP simulado e limpos ao final; slider e troca de tema da galeria exercitados.
- Conferência dos links locais da documentação, propriedades exportadas e integridade do ZIP.

Renderização e entrada em Roblox/Unbound real não foram executadas. As imagens são composições ilustrativas, e os testes não simulam métricas de fonte, clipping ou fluidez nativa. Veja [VALIDATION.md](VALIDATION.md).

## Publicação

A atualização é publicada na branch `codex/themes-v1.8.0`, em uma PR própria para `main`. O raw de `main` recebe a 1.8 após o merge; o prompt entregue usa o commit fixado da 1.8 para funcionar antes dele.

O diretório histórico `RetroBox-UI-v1.1.0/retrobox-ui/` é preservado. A publicação não altera os endereços de `main` já usados pelos scripts.
