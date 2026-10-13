# Integração de runtime e perfis · 1.6.0

[runtime-integration.lua](../examples/runtime-integration.lua) usa inventário e saldo simulados para demonstrar operações periódicas, grupos, status, toggles e migração. Não contém lógica de jogos. Os métodos tradicionais da 1.5 continuam disponíveis.

## Esperar uma ação

```lua
local action,reason=window:RunAction({Group="work",Policy="Queue",Callback=function(ctx)
    ctx:ThrowIfCancelled()
    return {Count=3}
end})
if action then
    task.spawn(function()
        local ok,result,status=action:Await({Timeout=5})
        if ok then print(result.Count) else warn(status..": "..tostring(result)) end
    end)
end
```

Formas equivalentes: `window:AwaitAction(handle, options?)`, `handle:Await(options?)` e `ctx:AwaitAction(handle, options?)`. A forma ctx acrescenta Context automaticamente. Os handles precisam pertencer à mesma janela.

Retorna `ok, resultOrReason, status`. Completed retorna true e o resultado original da ação, inclusive nil ou valores não representáveis em State. Failed retorna false, erro, Failed; cancelamento retorna false, motivo, Cancelled. O status final pode ser lido mesmo depois de destruir o handle ou removê-lo do histórico.

| Opção | Padrão / contrato |
| --- | --- |
| `Timeout` | Sem limite; 0–86400 s; zero retorna TimedOut imediatamente se ainda pendente |
| `Context` | Token de tarefa/ação da mesma janela; cancelar o token encerra a espera |
| `CancelAction` | false; true solicita cancelamento da ação quando a espera cancela ou expira |
| `Throw` | false; true propaga falhas como erro; cancelamento do próprio Context usa o token cooperativo |

Cancelar a espera **não cancela a ação por padrão**, inclusive na forma ctx. Para uma operação que pertence ao seu worker, escolha CancelAction=true. Cancelled de uma ação indica que seu callback retornou; Cancelling ainda pode estar executando até verificar o token.

A espera usa notificação de conclusão e retomada pelo scheduler, sem polling. Conclusões anteriores à inscrição são reconhecidas. Timeout, conclusão e cancelamento competem por um único resultado. Observadores e timers da espera são limpos ao terminar. Máximo 256 esperas pendentes por janela; `GetRuntimeStats().WaitingActions` conta essas esperas, não a fila de ações.

Chamadas pendentes exigem coroutine/worker que possa dar yield; fora disso retornam Rejected sem bloquear a UI. Handles já terminados podem ser consultados em qualquer contexto. Esperar a própria ação, ou uma ação em fila atrás do grupo ocupado pelo próprio ctx, retorna Rejected para evitar deadlock. Window/handle Destroy encerra esperas pendentes. A cancelabilidade de código longo continua cooperativa.

Ctx também oferece `OnCancel(fn)`, retornando listener com Disconnect. A função recebe o motivo; a inscrição é liberada quando a iteração/operação termina. Se já cancelado, chama imediatamente. Contextos concluídos não registram novos listeners. Erros no listener são protegidos.

## Tarefas periódicas dentro de grupos

```lua
local job=window:CreateTask({
    Id="periodic",Interval=2,Group="shared",Policy="Queue",
    Callback=function(ctx)
        ctx:ThrowIfCancelled()
        return {Count=3}
    end,
})
job:Start()
```

Group é opcional. Sem ele, o contrato de CreateTask permanece: um worker por tarefa e intervalo após o término. Com Group, cada iteração usa RunAction e o mesmo gerenciador de exclusão das ações e dos botões. Não há mutex separado.

Group aceita 1–128 bytes. Policy aceita Queue (padrão quando Group existe), Ignore, Reject ou Replace. Policy sem Group é inválida.

| Policy | Grupo ocupado |
| --- | --- |
| Queue | Uma ação da tarefa fica na fila; a tarefa aguarda sem agendar outras iterações |
| Ignore | Pula a amostra; LastOutcome=Skipped; tenta no próximo intervalo |
| Reject | Registra falha de concorrência; OnError=Stop/Continue decide parar ou tentar depois |
| Replace | Solicita cancelamento da ativa e da fila; espera a ativa devolver o controle |

Cada tarefa tem **no máximo uma iteração pendente ou em execução**, mesmo se o tempo de fila/execução ultrapassar Interval. Não recupera amostras atrasadas. O próximo prazo é `os.clock()+Interval` após terminar a operação inteira. O limite compartilhado continua 32 ações em fila por grupo e 32 grupos simultâneos; rejeições por capacidade seguem OnError.

Parar durante a fila remove a ação correspondente; não cancela o outro dono do grupo. Parar durante execução solicita cancelamento da operação da tarefa, mantendo IsRunning/InFlight enquanto ela retorna. Restart espera o worker antigo. StopAll envia cancelamento às tarefas e ações gerenciadas. Hide/minimizar não param por padrão.

O callback recebe o contexto da iteração, com `ctx.Task` apontando para a tarefa. Quando agrupado, ctx também oferece Action/SetProgress/SetMessage. Retornar false, reason em uma operação agrupada segue RunAction e marca Failed; tarefas sem Group preservam o contrato anterior, que usa erros lançados para OnError.

## Status observável da tarefa

`job.Status` é State somente leitura. `job:GetStatus()` retorna uma cópia com Remaining calculado naquele instante. `job:Subscribe(fn, immediate?)` observa mudanças de fase/dados e retorna um listener desconectável. Registre listeners próprios com Manage.

| Status | Significado |
| --- | --- |
| Inactive | Criada e não iniciada |
| Waiting | Solicitada, aguardando prazo ou despacho do worker |
| WaitingForGroup | Itens enfileirados/iniciando a disputa do grupo |
| Running | Callback em execução |
| Cancelling | Parada solicitada, worker ainda retornando |
| Stopped | Sem solicitação nem worker ativo |
| Failed | Erro encerrou a tarefa |
| Destroyed | Encerrada; State é destruída após essa notificação |

Campos: Id, Requested, Active, Running, InFlight, Interval, Iterations, NextRun, StartedAt, FinishedAt, LastResult, LastError, LastOutcome, StopReason e Group. NextRun existe quando aguarda prazo; Remaining é derivado de NextRun em GetStatus, não fica emitindo por frame. Active significa Requested ou InFlight; Running indica callback. IsRunning mantém o sentido amplo da 1.5: solicitado ou ainda retornando.

Iterations conta tentativas concluídas, incluindo skips/rejeições. LastOutcome pode ser Completed, Failed, Rejected, Skipped ou Cancelled. LastResult guarda o último sucesso e LastError o erro mais recente até sucesso/restart. Status contém apenas um resultado compatível com State; o resultado original está em job.LastResult. OnError=Continue mantém Requested e volta a Waiting com LastError; ele não finge que o callback está executando durante a espera. StopReason registra a parada solicitada.

Para countdowns, leia GetStatus em um intervalo adequado, por exemplo .5 s, como o exemplo. Um binding de status atualiza fases sem precisar dessa apresentação periódica:

```lua
label:BindState(job.Status,{Property="Text",Transform=function(status)
    return status.Status
end})
```

## Toggle e tarefa

```lua
local toggle=section:AddToggle({Id="enabled",Title="Ativar",Default=false})
local binding=toggle:BindTask(job)
```

BindTask é opcional e exclusivo de Toggle. O controle e a tarefa precisam estar vivos na mesma janela. O método retorna um scope; destruir esse scope desfaz a associação. Uma nova associação substitui a anterior.

| Opção | Padrão / contrato |
| --- | --- |
| `Initial` | Control: o valor atual do toggle inicia/para; Task: reflete Requested da tarefa |
| `OnStop` | TurnOff: erro, parada externa ou Once concluído desligam; KeepRequested mantém a intenção visual após parada |
| `FireCallback` | false: sincronizações vindas da tarefa são silenciosas; true opta por callbacks tradicionais |
| `StopOnUnbind` | true: remover a associação/controle solicita parada; false permite manter tarefa da janela |

O toggle representa a **solicitação**, e Status apresenta o estado efetivo. Desligar pode coexistir com Cancelling enquanto o worker sai. Com OnError=Continue, o toggle permanece ligado porque ainda existe uma solicitação; com OnStop=KeepRequested, deixá-lo ligado após parada representa apenas intenção, não execução. Use Status para deixar essa diferença clara.

A associação acompanha mudanças silenciosas e load/reset, evita recursion/duplicação e reflete falhas de Start. Ela não exige trocar a callback tradicional do toggle; evite manter uma segunda callback que inicie a mesma tarefa desnecessariamente.

## Migração de perfis do script

O envelope RetroBox mantém `Schema=1` e Version da library. `ConfigVersion` é **a versão das configurações do seu script**, padrão 1. Perfis antigos sem esse campo são tratados como versão 1. Não use Library.Version para renomear IDs do seu projeto.

```lua
local window=RetroBox:CreateWindow({
    Id="my-script",ConfigVersion=2,UnknownFlags="Preserve",
    Migrations={
        [1]=function(profile,fromVersion,toVersion)
            local old=profile.Flags.old_amount
            if old then profile.Flags.amount={Type="Slider",Value=tonumber(old.Value)}; profile.Flags.old_amount=nil end
        end,
    },
})
```

Também há `SetConfigVersion(integer)` e `RegisterMigration(fromVersion, fn)`. Versões são inteiros 1–65535. Cada função converte from para from+1; pode editar a cópia recebida e retornar nil, ou retornar uma tabela substituta. O runtime avança ConfigVersion ao concluir a etapa. Máximo 32 etapas por importação.

O pipeline decodifica/copia dados, identifica versão, migra sequencialmente, valida envelope/valores/aparência e só então aplica todas as flags em Batch. A migração pode renomear/remover IDs, converter tipos e acrescentar novos padrões. Ela deve ser síncrona, sem yield, efeitos externos ou acesso a remotes. Apenas funções registradas pelo desenvolvedor executam; código contido nos dados do perfil é rejeitado.

Versão futura, passo ausente, callback com erro/yield, envelope inválido e valores inválidos retornam false, motivo sem aplicar controles. O arquivo original e a tabela fornecida não são alterados antes do sucesso. Load não salva automaticamente o resultado convertido, salvo se AutoSave configurado concluir posteriormente; SaveConfig exporta a versão atual. Carregar um perfil já convertido não repete passos. Recarregar o arquivo antigo não salvo converte sua cópia novamente.

`ImportConfig`/`LoadConfig` aceitam Migrate=false para rejeitar perfis que precisam de conversão. UnknownFlags aceita Ignore (padrão compatível com 1.5), Preserve ou Reject, na janela ou na importação. Strict=true força Reject. Preserve retém registros de IDs desconhecidos para reexportar; controles conhecidos transitórios/internos não são persistidos. Metadados desconhecidos no topo e campos desconhecidos diretos de Appearance são mantidos; não existe promessa de retenção de campos aninhados dentro de opções conhecidas.

Dados são copiados e limitados a 16 níveis, 4096 entradas por tabela e 32768 no total. Funções/Instances e ciclos são rejeitados. O resultado serializado precisa caber em MaxConfigBytes. Color3/EnumItem fornecidos por código são convertidos em HEX/nome. Nenhum trecho importado é executado com loadstring.

## Perfis e bindings

Crie controles, registre migrações e conecte tarefas antes de carregar. Primeiro todas as flags/aparência são aplicadas; depois observadores e callbacks veem um conjunto coerente. Silent=true evita callbacks/OnChanged tradicionais, **mas mantém bindings e observadores**. Um toggle com BindTask pode iniciar sua tarefa nesse load, mesmo silent; é uma associação explícita do seu script. A tarefa executa no scheduler após o lote, sem efeitos no meio da migração.

Use migrações para dados, callbacks/bindings para aplicar opções e ações momentâneas apenas quando o usuário solicitar. O perfil não guarda execução, tokens, timers ou status de tarefas.

## Refinamentos de interação

O launcher UI pode ser arrastado pelo corpo ou pela barra ::, com mouse/toque. Deslocamentos até 4 px contam como clique; arrastar bloqueia a abertura acidental. A posição relativa já acompanha o save, ajusta-se aos limites ao mudar a resolução e Reset a restaura.

Hide/Show e minimizar/restaurar preservam aba ativa, seleção de Configurações e rolagem; uma janela nova usa o estado inicial. Conteúdo, lupa e painéis auxiliares pertencem ao Body, escondido imediatamente ao recolher. Header/controles da janela e elementos independentes como notificações continuam no papel próprio.

O arraste da barra usa a posição local da âncora e a diferença das coordenadas de entrada. Isso evita somar o inset de AbsolutePosition outra vez. Atualizações manuais são diretas, preservam a pegada, não fazem relayout e não deixam inércia ao soltar. SmoothDragging continua aceito/salvo para reposicionamentos gerenciados como Center, padrão false; ele não atrasa o gesto manual. ReducedMotion continua respeitado. GuiInset, escala e origem não zero são exercitados no double, mas precisam de conferência na engine.

Campos editáveis e dropdowns usam padding horizontal central de 12 px. Títulos externos e componentes com alinhamento próprio permanecem no papel anterior. Veja [VALIDATION.md](VALIDATION.md) para evidências e testes reais pendentes.


Na 1.9, [Script Hub Mode](SCRIPT-HUB.md) reutiliza flags, scopes e RunAction: Play é registrado em código, usa grupo exclusivo e exige cancelamento cooperativo. Catálogos/callbacks, imagens e dados de execução não são salvos. Favoritos, ordenação e seleção usam flags normais; construa o catálogo antes de LoadConfig. Detecção e restauração de perfis não acionam Play ou teleporte.
