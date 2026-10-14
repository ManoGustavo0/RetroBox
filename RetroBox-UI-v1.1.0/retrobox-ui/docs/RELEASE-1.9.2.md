# RetroBox 1.9.2 · Descrições do hub visíveis

O texto de jogos e scripts era recebido corretamente, mas o `AddLabel` reservava somente 21 pixels para o seu campo principal. O hub colocava nome e descrição em linhas desse campo; as linhas restantes ficavam cortadas, mesmo com um controle de 82 ou 106 pixels de altura.

A correção mede o texto completo e ajusta o campo e a linha ao conteúdo. A descrição auxiliar fica abaixo do texto principal. Atualizações, largura disponível, ícones, dicas e escala do texto acionam o recálculo. `Height` permanece como altura mínima. Sem medição disponível, uma estimativa conservadora preserva as linhas.

Selecione o jogo para ler sua descrição em **Jogo selecionado**. Selecione o script para ler sua descrição abaixo do **Catálogo de scripts**. A configuração continua usando `Description` nos registros de jogos e scripts, sem mudança de estrutura. Os 76 ícones e os perfis existentes continuam disponíveis.

## Verificação

**224/224 testes de lógica e 19 exemplos aprovados.** A reprodução da versão anterior mostrava uma caixa de 21 pixels para um texto que precisava de 48. Após a correção, ela reserva 51 pixels. As regressões cobrem descrições de jogo/script, escala do texto, atualização de textos longos/curtos, largura, dicas, descrição auxiliar e falha de medição.

O cliente Roblox não está disponível neste ambiente; os testes verificam conteúdo, geometria calculada, comportamento e limpeza em uma simulação.

Raw da implementação: https://raw.githubusercontent.com/ManoGustavo0/RetroBox/4eb987097a9ee37ea9b84bf87ab797a93123590b/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua

A fonte publicada foi comparada byte a byte ao código testado.

O Loader e o exemplo do prompt inicializaram a fonte publicada sem funções de arquivo do executor e limparam seus recursos. O Mano Gustavo Hub atualizado passou nas 15 verificações de integração. A atualização altera seu carregador; `CONFIG.Games`, os IDs, os callbacks e os perfis permanecem compatíveis.
