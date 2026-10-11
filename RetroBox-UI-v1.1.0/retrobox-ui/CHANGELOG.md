# Changelog

## 1.3.0 · 2026-10-11

- Aba Configurações automática e engrenagem que a seleciona, com saves de nomes livres, lista persistente e confirmação de sobrescrita.
- Índice de nomes para listar saves em outra execução sem exigir listfiles; enumeração opcional de arquivos antigos e Storage.List para adaptadores próprios.
- Keybind com teclado e Mouse 1/2/3; seletor ao lado do toggle e valores preservados nos perfis.
- Linhas de controles combinados, que se empilham em telas estreitas.
- Atalhos flutuantes ligados a Toggle/Button/Keybind, com arraste separado da ação, Hold e aparência/posições salvas.
- Busca com resultados navegáveis, seleção por setas/Enter e destaque do controle, sem executar sua função.
- Diálogos/confirmacões retrô, estado de execução e feedback opcional de sucesso/erro em botões.
- X passa a ocultar por padrão; DestroyOnClose=true mantém destruição. RightShift continua como padrão; botão de reabrir configurável e arrastável.
- Holds e eventos antigos são encerrados antes de carregar/restaurar. Toque longo para ler ajuda não ativa o toggle.
- 72 testes locais e seis exemplos passaram. Renderização e entradas na engine real seguem pendentes.

## 1.2.0 · 2026-10-11

- Tooltip opcional em todos os controles, com texto simples ou título, atraso e largura próprios; `Tip` é um alias.
- Dicas com visual do tema, quebra de linhas, posição limitada à tela e um painel compartilhado por janela.
- Abertura por hover no mouse ou toque longo no título/descrição; ler a dica não chama callbacks.
- SetTooltip/SetTip, GetTooltip, ShowTooltip e HideTooltip para controle por código.
- Cancelamento ao mudar abas, buscar, abrir configurações, arrastar, ocultar ou destruir; limpeza de eventos e tarefas pendentes.
- Exemplo de tooltips, API documentada e oito testes novos; 49 testes locais e cinco exemplos passaram.
- Loader, documentação e exemplos apontam para o raw existente de ManoGustavo0/RetroBox.
- Conferência visual e dos eventos na engine real permanece pendente.

## 1.1.0 · 2026-10-11

- Fluxo principal por GitHub raw + loadstring para executores.
- Exemplos independentes de instalação no Studio.
- Montagem automática da GUI por gethui, CoreGui e PlayerGui, com fallback de permissão.
- Arquivos JSON automáticos, ConfigFolder, FileStorage e diagnóstico de capacidades.
- Loader com mensagens de erro e guia de publicação no GitHub.
- 41 testes locais, incluindo HTTP, arquivos, recriação da janela e quatro exemplos.
- Teste da engine adaptado ao executor; modelo Studio e projeto Rojo removidos do pacote atual.

## 1.0.0 · 2026-10-11

- Primeira implementação independente em Luau.
- Identidade retrô, seis paletas e temas personalizados.
- Perfil automático do LocalPlayer e painel de personalização.
- Controles, abas, categorias, colunas e busca.
- HSV/RGB/HEX, opacidade e atualização compartilhada.
- Atalhos, configurações, integração Storage e ciclo de vida.
- Exemplos, documentação, modelo de demonstração e testes.
