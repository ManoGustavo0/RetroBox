# Publicar RetroBox UI no GitHub

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

Uma URL com `main` acompanha as atualizações dessa branch. Para fixar a library, troque `main` pelo hash completo de um commit que você testou ou por uma tag criada no seu repositório, por exemplo `v1.1.0`. A tag só funciona depois de existir no GitHub.

```text
https://raw.githubusercontent.com/SEU_USUARIO/retrobox-ui/v1.1.0/RetroBox.lua
```

## Se o carregamento falhar

Confira usuário, nome do repositório, branch e caminho exato. Nomes de arquivos no GitHub diferenciam maiúsculas e minúsculas. Se a página raw indicar 404, corrija o endereço antes de executar.

Se você publicar a pasta `retrobox-ui` como uma subpasta do repositório, o caminho passa a ser `main/retrobox-ui/RetroBox.lua`. A documentação assume que o conteúdo dela está na raiz.

Use `Loader.lua` para receber mensagens distintas para falha de download, compilação e inicialização. Teste `examples/showcase.lua` no executor que você pretende suportar e depois execute `tests/executor-smoke.lua`.
