# Migração 1.9.2 → 2.0.0

Troque uma vez o loader preso ao commit da 1.9.2 pelo bootstrap de API 2. Não é possível modificar retroativamente um RAW fixado em commit; ele continuará entregando a versão original. Depois da migração, a mesma URL resolve releases 2.x compatíveis na próxima execução.

```lua
local RetroBox=loadstring(game:HttpGet("https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua"))({Channel="stable"})
assert(RetroBox.APIVersion==2)
```

O fluxo `CreateWindow → CreateTab → CreateSection → controles` e a factory opcional CreateScriptHub permanecem. Os métodos de CRUD, pesquisa, favoritos, imagens, RunScript, DetectCurrentGame e TeleportToGame continuam. Callbacks mantêm `Callback(ctx,hub,gameMetadata,scriptMetadata)`. As 12 paletas, 76 ícones, Theme Studio, Command Palette, runtime e storage permanecem.

Mantenha WindowId/HubId, IDs de controles, ConfigFolder e ConfigVersion. A atualização não converte nem apaga perfis. Favorites/sort/games conservam os IDs `hub/<Id>/favorites`, `/sort` e `/games`. ConfigVersion só deve aumentar quando seu próprio esquema de configuração mudar. Guards `Version == "1.9.2"` devem migrar para `APIVersion==2` ou um intervalo semântico; consumidores estritos usam Pinned.

O Script Hub possui imagem maior sem título Miniatura, listas compactas, um botão Executar script e rolagem independente no desktop. `hub.PlayButton` conserva esse nome de referência por compatibilidade, com o novo rótulo. O botão interno de cada linha foi removido; a linha seleciona. Entrar no jogo continua separado e confirmado por padrão. Seleção/detecção/reload nunca executam callbacks nem teleportam.

IDs internos continuam ASCII: `CaesScript1`, com `Title="Cães Hub"` para o nome visível. Textos e descrições aceitam acentos. PlaceId é o destino; UniverseId é o ID da experiência, não um campo duplicado a ser sobrescrito por nil.

Para receber correções do **código do seu hub**, publique um módulo Version/Start e use LoadHub em um bootstrap permanente. Para atualizar somente metadados, opte por CatalogUpdate e Actions. Atualizar a library não publica automaticamente arquivos do seu hub. Veja [AUTO-UPDATE.md](AUTO-UPDATE.md) e [HUB-AUTO-UPDATE.md](HUB-AUTO-UPDATE.md).
