# Contrato permanente de distribuição

A distribuição principal da RetroBox usa um arquivo Luau independente no raw do GitHub. O caminho histórico é `RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua`; o nome da pasta não representa a versão atual do conteúdo.

**Raw confirmado → HttpGet → loadstring → Library → CreateWindow → CreateTab → CreateSection → controles.**

O script final exige HTTP e loadstring disponibilizados pelo ambiente. Não exige readfile para obter a library, um ModuleScript no Workspace nem arquivos de desenvolvimento. Arquivos locais são uma alternativa de desenvolvimento; perfis usam readfile/writefile apenas quando disponíveis, com fallback de sessão conforme a API existente.

O raw de main recebe uma versão depois do merge. Antes disso, use o commit realmente publicado e verificado da release. Não apresente marcadores, links inexistentes ou uma versão anterior como se fossem a nova. [Loader.lua](../Loader.lua) verifica capacidades, HTTP, conteúdo vazio, compilação, inicialização, APIs e versão esperada. [remote-loader.lua](../examples/remote-loader.lua) mostra o fluxo tradicional.

O `Prompt-RetroBox-IA.md` entregue em cada atualização preserva sua API e organização e usa o raw fixado daquela versão. Antes de entregá-lo:

1. Publique a fonte e confirme o raw, sua versão e seu conteúdo contra o Git tree.
2. Execute `python3 tools/validate_prompt.py --prompt /caminho/Prompt-RetroBox-IA.md --commit SHA_CONFIRMADO`.
3. Execute o exemplo principal no runner com a fonte baixada, sem capacidades de arquivo do executor.
4. Confira dependências e métodos reais; se a publicação falhar, informe a URL pendente e não converta um loader local em novo requisito geral.

O validator detecta versão/header antigos, marcador ou caminho incorreto, loader local/ModuleScript, ordem de montagem alterada e métodos desconhecidos no exemplo. A suíte também testa HTTP ausente, erros de download/compilação/inicialização e versões erradas. A execução por HTTP no Roblox real continua sendo uma conferência separada, descrita em [VALIDATION.md](VALIDATION.md).


Raw verificado da 1.9.1: [6486c4b](https://raw.githubusercontent.com/ManoGustavo0/RetroBox/6486c4be4db877e4eb2e94f714f4ae4da3fdf762/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua). A fonte distribuída declara 1.9.1 e foi executada no runner sem readfile/writefile do executor. A conferência dentro do cliente Roblox segue separada.
