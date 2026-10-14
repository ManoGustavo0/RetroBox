# Contrato permanente de distribuição · API 2

**RAW do bootstrap confirmado → HttpGet → loadstring → Library → CreateWindow → CreateTab → CreateSection → controles.**

A URL permanente é https://raw.githubusercontent.com/ManoGustavo0/RetroBox/main/dist/bootstrap/v2.lua. O bootstrap usa manifesto de canal e artefato imutável, com hash/tamanho e compatibilidade. Stable é o padrão; Preview e Pinned são opt-ins separados. Ver [AUTO-UPDATE.md](AUTO-UPDATE.md).

A fonte histórica `RetroBox-UI-v1.1.0/retrobox-ui/RetroBox.lua` continua standalone. Arquivos locais/ModuleScript/Studio não são requisitos. readfile/writefile/makefolder são opcionais para cache/perfis, com sessão quando ausentes. HTTP/loadstring e bit32 requeridos são verificados. Uma falha não é substituída por instalação local obrigatória.

Scripts fixados em commits antigos precisam migrar o loader uma vez; eles não podem receber novos bytes no mesmo commit. Após a migração, releases 2.x compatíveis chegam na próxima execução. Uma janela ativa não recebe hot swap. Código de Hub tem bootstrap e versão próprios: [HUB-AUTO-UPDATE.md](HUB-AUTO-UPDATE.md).

Antes da entrega: execute o builder, a suíte, verify_distribution.py e validate_prompt.py; compare os RAWs publicados com os SHA-256/bytes do Git tree e execute o exemplo extraído do prompt com o bootstrap, sem capacidades de arquivo do executor. As verificações de fonte/rede/semântica não são uma renderização do cliente Roblox.

Um commit de branch não torna um canal de main disponível. Só informe publicado depois de merge e verificação pública do bootstrap, manifesto e artefato. O prompt completo deve manter APIs, sequência tradicional, temas, ícones, runtime, perfis e exemplos; sua validação é adaptada à API 2.
