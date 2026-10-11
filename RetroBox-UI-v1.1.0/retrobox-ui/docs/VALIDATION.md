# Validação · RetroBox UI 1.1.0

## Executado

- Compilação sintática de todos os arquivos Lua pelo subconjunto compatível com Lua 5.4.
- **41 testes de lógica** com sinais, instâncias e serviços simulados.
- Carregamento dos quatro exemplos por HTTP simulado + compilação do conteúdo real de `RetroBox.lua`.
- Loader com respostas inválidas, falha de download e erro de compilação.
- GUI por gethui/CoreGui/PlayerGui: preferência, fallback quando falta permissão, Parent explícito, falhas e limpeza ao executar de novo.
- Arquivos: detecção parcial, fallback para memória, pastas criadas sob demanda, restauração em outra instância da library, JSON inválido, falha de escrita, nomes sem colisões, caminhos inválidos, funções opcionais e debounce do AutoSave.
- Componentes, callbacks, listeners, enums, cores, RGB compartilhado, importação atômica, temas, teclas, foco, configurações, buffers, notificações e limpeza das conexões.
- Verificação dos links locais da documentação, fontes dentro do ZIP e integridade CRC.

```bash
python3 tests/run_headless.py
# ou, com Lua 5.4 instalado:
lua tests/headless.lua
```

O runner Python requer liblua5.4 e usa a biblioteca padrão do Python. O build da imagem e do ZIP usa Pillow:

```bash
python3 tools/build_package.py
```

## Limites

Os testes não renderizam texto, bordas, rolagem ou imagens, nem executam eventos reais de mouse/toque. HTTP e funções de arquivo do executor são simulados. Eles verificam a lógica, mas não comprovam compatibilidade com um executor específico.

**Nenhum executor Roblox estava disponível neste ambiente.** A conferência em jogo e no executor alvo, incluindo Unbound, permanece pendente. Não há promessa de suporte a todos os executores.

## Conferir no executor

1. Publique a fonte e substitua a URL em `examples/showcase.lua`.
2. Execute o showcase e confira perfil, temas, textos, rolagem, arraste, redimensionamento, minimizar/maximizar e RightShift.
3. Confira HSV, R/G/B, HEX, opacidade, RGB e velocidade. O círculo do showcase é um exemplo de ligação por callback.
4. Salve um perfil, altere valores e carregue-o. Execute de novo com o mesmo ID para conferir a substituição da janela e a restauração do arquivo.
5. Verifique toque e tela pequena nos dispositivos que quiser suportar.
6. Substitua a URL e execute `tests/executor-smoke.lua`. O teste cria todos os componentes, troca temas, importa configurações e alterna RGB usando a engine real.
7. Confira a mensagem `[RetroBox] Real-engine smoke passed`, depois inspecione a aparência e entrada. Essa mensagem sozinha não valida a experiência visual.
8. Teste `window:Destroy()` e confirme que atalhos, RGB e callbacks anteriores foram encerrados.

`docs/visual-concept.png` é uma ilustração gerada a partir da paleta; não é captura de tela da GUI em execução.
