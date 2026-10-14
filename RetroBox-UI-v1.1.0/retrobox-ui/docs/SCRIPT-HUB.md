# Script Hub Mode · RetroBox 1.9.0

O hub é opcional. A sequência normal `HTTP → CreateWindow → CreateTab → CreateSection → controles` continua disponível. O modo usa a mesma janela, as listas virtuais, as flags, os perfis, os temas, os scopes e as ações da RetroBox.

`Library:CreateScriptHub(options)` cria um hub com uma janela própria. `window:CreateScriptHub(options)` adiciona um hub a uma janela existente. Ambos retornam um manager com `Window`, `Tab`, `Id`, `GameList`, `ScriptList` e os métodos abaixo. Não execute funções vindas de perfis; o catálogo é definido pelo desenvolvedor em código.

## Cadastro

| Campo | Contrato |
| --- | --- |
| `Id` | ID estável de 1–64 letras, números, ponto, hífen ou sublinhado. |
| `Title` | Título do hub; a factory também aceita as opções normais da janela, como Theme, Locale e ConfigFolder. |
| `WindowId` / `HubId` | A factory permite separar o ID da janela do ID do manager. |
| `AutoDetectGame` | `true` por padrão; seleciona uma correspondência do catálogo, sem executar ações. |
| `ConfirmTeleport` | `true` por padrão. |
| `Teleporter` | Adapter opcional `function(placeId, player, gameMetadata, ctx)`. Deve retornar false, motivo se rejeitar a solicitação. |
| `Games` | Array denso, até 512 jogos e 4096 scripts no total. |

Jogo: `{Id, Name, PlaceId?, UniverseId?, Description?, Image?, Order?, Scripts={...}}`. Name é obrigatório (até 128 bytes), Description até 2048. PlaceId e UniverseId são inteiros positivos exatos até 2^53−1, com significados distintos. Order é inteiro entre −1000000 e 1000000, padrão ordem de cadastro. Image aceita ID numérico ou conteúdo Roblox `rbxassetid://`, `rbxthumb://`, `rbxasset://`; URLs web não são colocadas no ImageLabel. `false` pode limpar PlaceId, UniverseId ou Image em UpdateGame.

Script: `{Id, Title, Description?, Icon?, Author?, Version?, Status?, Enabled?, CurrentGameOnly?, Requires?, Confirm?, Callback?}`. Até 128 por jogo, IDs únicos dentro dele. Title/Author até 128 bytes, Description até 2048, Version 64, Status 128, Confirm 4096. Sem Callback, a entrada permanece indisponível. Icon usa o catálogo pixel art existente. Enabled é bool ou `function(hub, gameMetadata, scriptMetadata)`; CurrentGameOnly restringe a disponibilidade ao contexto correspondente.

`Requires` pode conter `HttpGet`, `loadstring`, `readfile`, `writefile` ou `setclipboard`. Essas capacidades pertencem à ação cadastrada: o hub e a library não exigem `readfile` para carregar. Nenhuma URL de código é interpretada pelo catálogo; Play chama somente o Callback registrado em código pelo desenvolvedor.

```lua
-- Carregue a RetroBox primeiro pelo raw confirmado da versão, como no prompt.
local hub = Library:CreateScriptHub({
    Id = "meu-hub", Title = "Meu Hub", Theme = "Retro98", Locale = "pt-BR",
    AutoDetectGame = true, ConfigFolder = "RetroBox/MeuHub",
    Games = {{
        Id = "current", Name = "Jogo desta sessão",
        PlaceId = game.PlaceId, UniverseId = game.GameId,
        Scripts = {{Id = "notice", Title = "Mostrar aviso", Icon = "info",
            Callback = function(ctx, activeHub)
                ctx:ThrowIfCancelled()
                activeHub.Window:Notify({Content = "Ação de demonstração."})
                return {Shown = true}
            end}},
    }},
})
```

## Métodos

| Método | Resultado / comportamento |
| --- | --- |
| `AddGame(record)` | Retorna o ID; valida antes da mutação. |
| `UpdateGame(id, patch)` | Retorna hub; ID não é renomeado. Cancela ações da versão anterior do cadastro. |
| `RemoveGame(id)` | Bool; remove entrada e ajusta seleção/favoritos. |
| `GetGame(id)`, `GetGames()` | Cópias de metadados; callbacks/predicates não são expostos nem serializados. |
| `SelectGame(id)`, `GetSelectedGame()` | Bool, motivo / metadados. Reutiliza a janela e as listas. |
| `DetectCurrentGame()`, `IsCurrentGame(id)` | ID ou nil / bool. PlaceId exato tem prioridade; depois UniverseId = game.GameId. |
| `SetGameQuery(text)`, `SetScriptQuery(text)` | Pesquisa imediata sem executar ações; até 256 bytes, case insensitive em ASCII e capitais latinas pt-BR. |
| `SetSort("Order"/"Alphabetical"/"Favorites")` | Mantém a seleção. IDs das opções são estáveis entre idiomas. |
| `IsFavorite(id)`, `SetFavorite(id, bool)` | Estado persistido pelo perfil normal. |
| `AddScript(gameId, record)` | Retorna hub; exige ID único. |
| `UpdateScript(gameId, scriptId, patch)` | Retorna hub; pode atualizar disponibilidade, metadados e callback. |
| `RemoveScript(gameId, scriptId)` | Bool. |
| `GetScript(gameId, scriptId)` | Metadados sem função executável. |
| `IsScriptAvailable(gameId, scriptId)` | Bool, motivo. Revalida também no início da ação. |
| `GetScriptStatus(gameId, scriptId)` | Snapshot Available/Unavailable/Queued/Running/Cancelling/Completed/Failed/Cancelled. |
| `RefreshScripts()` | Atualiza os dados após uma dependência externa mudar. |
| `RunScript(gameId, scriptId, {Confirmed?})` | Handle/erro; ou nil, `confirmation pending`. Runtime compartilhado, grupo exclusivo por entrada, sem execuções duplicadas. |
| `GetThumbnailStatus(gameId)` | Status Loading/Loaded/Unavailable, URI e erro quando houver. |
| `RetryThumbnail(gameId)` | Reenvia uma falha; não duplica trabalho já Loading. |
| `TeleportToGame(gameId, {Confirmed?})` | Handle/erro; confirmação por padrão, sem auto Play. |
| `Show()`, `Hide()`, `Destroy()` | Retorna hub / destruição. Factory própria destrói também a janela; hub anexado remove seu tab e recursos. |

Callbacks de scripts recebem `(ctx, hub, gameMetadata, scriptMetadata)`. Cooperem com cancelamento: `ctx:ThrowIfCancelled()`, `ctx:IsCancelled()`, `ctx:AwaitAction()` e `ctx:Manage()`. Um callback que ignora cancelamento não pode ser interrompido à força pelo runtime. A conclusão só é mostrada depois do resultado real da ação. Retornar `false, "motivo"` produz Failed; levantar erro também. Remover/atualizar o cadastro solicita cancelamento da execução anterior.

## Perfis e imagens

As descrições do jogo selecionado aparecem em **Jogo selecionado**. A descrição do script selecionado aparece abaixo do **Catálogo de scripts**, junto dos créditos e da versão. Na 1.9.2, esses campos medem o texto completo: crescem para acomodar quebras de linha e textos longos e recalculam ao atualizar o cadastro, redimensionar a janela ou alterar a escala do texto. São conteúdo do catálogo; desligar as descrições auxiliares dos controles não remove esses dados.

Favoritos, ordenação e jogo selecionado usam flags estáveis `hub/<HubId>/favorites`, `hub/<HubId>/sort`, `hub/<HubId>/games`. Construa o catálogo antes de LoadConfig. Restauração silenciosa atualiza a interface pelas flags observáveis. Favoritos ausentes do catálogo são descartados; uma seleção inexistente é normalizada para nil e uma entrada disponível é escolhida. Dados dos jogos, callbacks, busca, imagens e execuções não entram no perfil. Schema/ConfigVersion permanecem compatíveis com perfis anteriores.

As linhas são recicladas, com pool máximo 64. Miniaturas usam `rbxthumb://type=GameIcon&id=<UniverseId>&w=150&h=150`; sem UniverseId, `GameThumbnail` usa PlaceId e 256×144. ContentProvider:PreloadAsync roda fora da criação da interface, no máximo quatro pedidos simultâneos; cache/pendências são limitados a 128 URIs. Sem serviço, sem imagem ou em erro, permanece o fallback em pixel art. Ocultar/reabrir preserva a seleção. Destruir cancela os scopes, observadores, trabalhos de imagem e ações gerenciadas.

## Teleporte

O destino sempre usa PlaceId, nunca UniverseId. A seleção automática e o load de perfil não teleportam. Há confirmação por padrão e proteção contra solicitações duplicadas. Falhas síncronas e TeleportInitFailed são informadas; após 30 segundos sem confirmação, a espera local termina como Unconfirmed. Solicitar um teleporte não confirma a chegada e não produz um aviso de sucesso antecipado.

O fluxo nativo compatível no cliente usa `TeleportService:Teleport(placeId, LocalPlayer)`, uma API legada. Roblox recomenda TeleportAsync no servidor, via RemoteEvent definido pela própria experiência. Em um hub universal de cliente não há um RemoteEvent de servidor que se possa presumir; configure Teleporter para essa integração quando disponível. A library não chama TeleportAsync no cliente nem tenta contornar bloqueios do ambiente. Método legado, assets e entrada real exigem teste no executor de destino.

Fontes oficiais: [URIs de assets](https://create.roblox.com/docs/projects/assets), [TeleportService](https://create.roblox.com/docs/reference/engine/classes/TeleportService), [migração de teleportes](https://create.roblox.com/docs/projects/teleport#migrate-to-secure-teleports).

Veja [script-hub.lua](../examples/script-hub.lua), [distribuição remota](DISTRIBUTION.md) e [validação](VALIDATION.md).
