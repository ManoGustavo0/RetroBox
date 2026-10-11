# Publicar RetroBox UI no GitHub

## Repositório atual

No repositório [ManoGustavo0/RetroBox](https://github.com/ManoGustavo0/RetroBox), a fonte está em `RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua`. O raw é:

```lua
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua"))()
```

Para atualizar, substitua os arquivos dentro de `RetroBox-UI-v1.1.0/retrobox-ui` pelo conteúdo da pasta `retrobox-ui` do novo ZIP, ou mescle a pull request da atualização. O nome antigo da pasta pode continuar: a versão da library é `Library.Version`, dentro do arquivo. Manter esse caminho preserva o raw usado pelos scripts.

Tooltip requer a fonte 1.2.0 ou posterior. Configurações/lista de saves, mouse, linhas, diálogos, pesquisa navegável e atalhos flutuantes requerem a fonte 1.3.0 ou posterior publicada nesse caminho. Loader e exemplos deste pacote já usam essa URL. Carregue `RetroBox.lua` para obter a API; `examples/showcase.lua` monta uma demonstração pronta.

## Publicar em outro repositório

1. Extraia o ZIP e abra a pasta `retrobox-ui`.
2. Crie um repositório público no GitHub, por exemplo `retrobox-ui`.
3. Em **Add file → Upload files**, envie o conteúdo dessa pasta para a raiz do repositório. `RetroBox.lua` deve aparecer na raiz, junto com `README.md`.
4. Confirme qual é a branch: os exemplos usam `main`.
5. Abra `RetroBox.lua`, clique em **Raw** e copie o endereço. Use a URL do conteúdo raw, que normalmente começa por `https://raw.githubusercontent.com/`.
6. Substitua a URL em seu script, em `Loader.lua` e nos exemplos que você quiser publicar.

```lua
local RetroBox = loadstring(game:HttpGet("https://raw.githubusercontent.com/SEU_USUARIO/retrobox-ui/main/RetroBox.lua"))()
local window = RetroBox:CreateWindow({ Id = "meu-script", Title = "Meu script" })
local category = window:CreateTab("Principal"):CreateSection("Controles")
category:AddButton({ Title = "Executar", Callback = function() print("Sua função aqui") end })
```

O ZIP completo também pode ser anexado a uma release. Carregue `RetroBox.lua` quando quiser a API da library; `examples/showcase.lua` monta uma demonstração pronta.

## Fixar uma versão

Uma URL com `main` acompanha as atualizações dessa branch. Para fixar a library, troque `main` pelo hash completo de um commit que você testou ou por uma tag criada no seu repositório, por exemplo `v1.3.0`. A tag só funciona depois de existir no GitHub.

```text
https://raw.githubusercontent.com/SEU_USUARIO/retrobox-ui/v1.3.0/RetroBox.lua
```

## Se o carregamento falhar

Confira usuário, nome do repositório, branch e caminho exato. Nomes de arquivos no GitHub diferenciam maiúsculas e minúsculas. Se a página raw indicar 404, corrija o endereço antes de executar.

Se publicar a pasta `retrobox-ui` como uma subpasta, o caminho passa a ser `main/retrobox-ui/RetroBox.lua`. Se houver outra pasta por fora, ela também entra na URL, como no repositório atual mostrado acima.

Use `Loader.lua` para receber mensagens distintas para falha de download, compilação e inicialização. Teste `examples/showcase.lua` no executor que você pretende suportar e depois execute `tests/executor-smoke.lua`.
