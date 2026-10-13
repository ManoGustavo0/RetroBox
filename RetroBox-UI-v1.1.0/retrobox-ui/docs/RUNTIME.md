# Runtime e componentes dinâmicos · 1.7.0

A RetroBox continua em um único `RetroBox.lua`, com blocos internos para recursos, estados, tarefas, animações e componentes de dados. Os exemplos usam apenas dados simulados; a library não implementa lógica de jogos. [dashboard.lua](../examples/dashboard.lua) reúne os recursos abaixo.

[ADVANCED.md](ADVANCED.md) documenta Runtime Inspector, Command Palette e componentes da 1.7, sem substituir esses serviços.

Para esperas, tarefas dentro de grupos, status observável, BindTask e migrações, veja [INTEGRATION.md](INTEGRATION.md) e [runtime-integration.lua](../examples/runtime-integration.lua).

## Cards de estatísticas

```lua
local total=window:CreateState(1250)
local card=section:AddStatCard({
    Id="total",Title="Total",Icon="star",State=total,TwoWay=false,
    Format="Compact",Precision=1,Unit="itens",Subtitle="Atualizado agora",
    Trend=25,TrendText="+25 nesta sessão",Sparkline=true,MaxPoints=40,
})
total:Set(2500)
card:SetTrend(100):SetSubtitle("Nova amostra"):AddPoint(2500)
```

`Value` ou `Default` define o valor inicial (padrão 0). Valores aceitos: número finito, texto até 2048 bytes ou nil via `SetValue`. `Loading=true` exibe Carregando; `Unavailable=true` exibe Indisponível. `SetLoading(bool)` e `SetUnavailable(bool, text?)` alternam esses estados sem perder o valor. Há também `SetUnit(text)`, `SetSubtitle(text)`, `SetTrend(number, text?)`, `SetHistory(array)`, `GetHistory()` e `AddPoint(number, label?)`.

Formatos: `Raw` (padrão), `Compact` (K/M/B/T), `Percent` (45 vira 45%), `Time` (segundos viram mm:ss ou hh:mm:ss) ou `function(value)` retornando texto. `Precision` aceita 0–6. `Library:FormatValue(value, format?, precision?)` usa a mesma formatação. `Animated=true` dá um breve feedback de cor ao mudar um valor numérico.

Altura padrão 140, ou 174 com sparkline; descrição acrescenta 20. `Height` aceita 116–600. Sparkline guarda no máximo `MaxPoints` (2–256, padrão 40). Dados são copiados. O card não entra no save, mesmo com Persist=true.

## Gráficos nativos

```lua
local chart=section:AddLineChart({
    Title="Histórico",MaxPoints=60,RefreshRate=20,
    Data={{Value=10,Label="A"},12,15},ShowLegend=true,Legend="Amostras",
})
chart:AddPoint(18,"B",os.clock())
chart:SetRange(0,100) -- ambos nil restauram escala automática
```

`AddChart({Type=...})` aceita `Line`, `Bar`, `Progress` e `Sparkline`. Atalhos: `AddLineChart`, `AddBarChart`, `AddProgressChart`, `AddSparkline`. São Frames/labels nativos, sem imagens remotas ou uma conexão por ponto.

| Opção | Contrato |
| --- | --- |
| `Data` / `Default` | Array denso de números ou `{Value, Label?, Time?}`; no máximo 4096 pontos de entrada |
| `MaxPoints` | 2–512, padrão 60; mantém os pontos mais recentes na ordem recebida |
| `Min` / `Max` | Limites finitos opcionais; Max > Min quando ambos definidos |
| `StartAtZero` | Inclui zero na escala automática; barras sempre incluem zero |
| `RefreshRate` | 1–60 desenhos/s, padrão 20; dados mudam imediatamente e desenhos próximos são coalescidos |
| `ShowGrid` / `ShowLabels` | true por padrão em Line/Bar; Sparkline/Progress omitem |
| `ShowLegend` / `Legend` | Legenda opcional para a série única |
| `Color` | Color3/HEX opcional; sem ela, segue Accent do tema |
| `Format` / `Precision` | Formatos dos cards para rótulos dos eixos; padrão Compact / 1 |
| `Thickness` / `Animated` | Linha 1–12 px, padrão 2; animação de geometria opcional, false por padrão |
| `Height` | 64–800; padrão Line/Bar 220, Progress 80, Sparkline 82 |

`SetData(array, silent?)`/`SetValue`, `AddPoint(value, label?, time?)`, `Clear()`, `SetRange(min?, max?)` e `SetMaxPoints(number)` atualizam os gráficos. Label aceita até 128 bytes e Time deve ser finito. Time é metadado: o eixo X distribui pontos pela ordem, sem interpolar intervalos de tempo. Uma série vazia mostra Sem dados; uma série constante recebe uma margem de escala. Histórico retornado por GetValue é uma cópia.

Progress usa `Value`/`Default` numérico, `Min=0`, `Max=100`, clamping e porcentagem relativa ao intervalo. Alterar o intervalo renormaliza o valor. Não aceita AddPoint; Clear retorna ao Min.

O pool cresce só até o histórico usado; elementos excedentes ficam ocultos e são reaproveitados. Reduzir MaxPoints libera excedentes. Atualizações pendentes, animações e a conexão de resize pertencem ao controle. Cards/gráficos são transitórios: não salvam históricos ou dados de sessão. Use `CreateRow` para cards lado a lado com empilhamento em telas estreitas.

## Recursos e ciclo de vida

```lua
local scope=window:CreateScope() -- também control:CreateScope()
scope:Add(connection)           -- Disconnect
scope:Add(instance)             -- Destroy
scope:Add(function() restoreOriginalValue() end)
scope:Add(handle,"Cancel","operation")
scope:Clean()                   -- reutilizável
scope:Destroy()                 -- encerra definitivamente
```

`Library:CreateScope()` cria um escopo independente; você deve destruí-lo. Window/Control oferecem `Manage(resource, method?, key?)`, equivalente a adicionar ao escopo principal do dono. O método é inferido entre Destroy/Disconnect/Cancel/Stop, ou pode ser uma string/método explícito ou `function(resource)`.

Scopes oferecem `Add`, `Remove(key, keep?)`, `Clean`, `Destroy`, `Child(options?)` e `GetCount()`. Uma chave repetida limpa o recurso anterior. Remove com keep=true apenas solta a referência. A limpeza ocorre em ordem inversa, uma vez por registro, com erros isolados. Adicionar a um escopo destruído limpa imediatamente. GetCount conta registros diretos, não descendentes.

Políticas opcionais em CreateScope: `CancelOnHide`, `CancelOnDisable` e `CancelOnFalse`. As duas últimas valem para escopos de um controle. Elas executam Clean; não destroem o componente nem o escopo. Não confunda limpar com impedir que o desenvolvedor registre novos recursos depois.

Ocultar, minimizar, pesquisar e trocar aba **mantém o trabalho ativo por padrão**. Hide aplica apenas CancelOnHide. Desabilitar aplica CancelOnDisable; um valor booleano que muda para false aplica CancelOnFalse, após o lote inteiro. Destroy da janela/controle limpa seus recursos. StopAll envia cancelamento a tarefas e ações; não remove conexões ou Instances avulsas registradas com Manage.

Threads arbitrárias precisam de uma função de limpeza explícita e de cancelamento cooperativo no próprio código. A RetroBox não chama task.cancel nem tenta matar uma coroutine externa. Registre recursos próprios para a reexecução com o mesmo Window.Id encerrar a instância anterior.

## Tarefas periódicas

```lua
local job=window:CreateTask({
    Id="sample",Interval=.5,OnError="Stop",
    Callback=function(ctx)
        ctx:ThrowIfCancelled()
        -- Atualize dados da sua aplicação.
    end,
})
job:Start(); job:Start() -- a segunda chamada não cria outra execução
job:Stop("paused")
```

CreateTask também existe no Control. Opções: Id único (1–128 bytes), Interval .03–86400 s (padrão 1), Callback(ctx), Start=false, Immediate=true, Once=false e OnError=Stop/Continue. Aceita Scope explícito na Window e CancelOnHide; tarefas do controle também aceitam CancelOnDisable/CancelOnFalse. Máximo 128 tarefas por janela.

Métodos: Start (ok, err), Stop/Cancel(reason?), IsRunning(), SetInterval(seconds), Destroy(), GetStatus() e Subscribe(). Status é State somente leitura; Group/Policy opcionais integram RunAction. Window tem StartTask(id), StopTask(id, reason?) e StopAll. IsRunning inclui uma execução cancelada que ainda está retornando. O intervalo conta a partir do término do callback; frames atrasados não geram uma sequência de chamadas acumuladas.

O scheduler usa uma única conexão RenderStepped preguiçosa por janela, compartilhada com arraste e redraws; ela sai quando não há trabalho. Não há sobreposição, mesmo se o callback der yield. Parar e reiniciar espera o worker anterior retornar. Políticas de limpeza continuam valendo após um restart.

Contexto: `IsCancelled()`, `ThrowIfCancelled()`, `Cancel(reason?)` e `Manage(resource, method?, key?)`. Recursos de ctx pertencem à iteração e são limpos ao terminar ou cancelar. Confira cancelamento antes de efeitos e após waits em operações longas. O sistema não interrompe código síncrono bloqueante ou um yield que nunca retorna. Erro pára a tarefa por padrão; Continue mantém as próximas iterações e registra a falha.

## Ações, grupos e botões

```lua
local action,err=window:RunAction({
    Id="operation",Group="processing",Policy="Replace",
    Callback=function(ctx)
        for step=1,10 do
            ctx:ThrowIfCancelled()
            ctx:SetProgress(step,10,"Processando")
            task.wait(.1)
        end
        return {Count=10}
    end,
})
if action then window:Manage(action:Subscribe(function(status) print(status.Status,status.Progress) end),"Disconnect") end
```

Id e Group aceitam 1–128 bytes. Group padrão: Id ou "default"; Id omitido é gerado. Id não pode repetir enquanto ativo. Máximo 32 grupos simultâneos, 32 ações em fila por grupo e 32 handles no histórico terminal.

| Policy | Quando o grupo está ocupado |
| --- | --- |
| Reject (padrão) | Retorna nil, motivo |
| Ignore | Retorna nil, "ignored" |
| Queue | Aguarda a operação anterior |
| Replace | Cancela ativa e fila; espera a ativa retornar antes de iniciar a nova |

O handle oferece Status (State somente leitura), GetStatus() (cópia), Subscribe(fn, immediate?), Cancel(reason?), Destroy(), Result, Error e Context. O estado contém Status, Step, Total, Progress (0–1), Message e Result/Error ao terminar. Estados: Queued, Running, Cancelling, Cancelled, Completed e Failed. Result no status só inclui dados compatíveis com State; o resultado original está em handle.Result. Handles antigos podem ter sua State destruída quando o histórico exceder 32; guarde o resultado se precisar dele depois.

Ctx também tem Action (handle), SetProgress(step, total, message?) e SetMessage(text). Opções OnProgress(status, handle), OnComplete(handle), ControlId e CancelOnHide são opcionais. `return false, "motivo"` ou um erro marca Failed; outros retornos completam. Falha e cancelamento liberam grupo e recursos. Cancelamento é cooperativo: Replace não inicia concorrência com um worker que ignorou o token.

`AddButton({Group?, Policy?, Cancelable=true, Callback=function(control,ctx) ... end})` usa esse runtime. GetAction() consulta o handle e Cancel(reason?) solicita parada. O texto mostra execução/fila/cancelamento; o botão libera ao concluir. Feedback=true exibe resultado. Botões tradicionais continuam recebendo só o controle e mantêm sua proteção contra cliques repetidos. Um botão gerenciado ocupado também rejeita Press; Queue/Replace são úteis entre botões do mesmo grupo ou em RunAction. Desabilitar/ocultar não cancela ações por padrão; CancelOnHide opta pelo cancelamento.

## Estados, bindings e condições

CreateState aceita valor acíclico e options={Name?, Validate?}. Validate(value) retorna true ou false, reason. Há Get (cópia), Set (bool: mudou), Update(fn), Subscribe(fn, immediate?) e Destroy. Window gerencia seus estados; Library cria estados independentes. Tables têm até 16 níveis e 1024 itens por nível, com chaves string/número; valores Roblox são preservados. Estados não são salvos automaticamente.

Window:Computed({state1,...}, calculate) observa 1–32 fontes e cria State somente leitura. GetFlagState(id) exige controle já criado e é somente leitura. Ambos atualizam em silêncio também.

```lua
local volume=window:CreateState(50)
local slider=section:AddSlider({Id="volume",Title="Volume",State=volume,Min=0,Max=100})
local card=section:AddStatCard({Title="Volume atual",State=volume,TwoWay=false,Format="Percent"})
card:BindState(volume,{Property="Subtitle",Transform=function(v) return "Valor: "..v end})
```

State na criação é um atalho de BindState. TwoWay=true por padrão nesse atalho; para visualizações ou fontes somente leitura, use TwoWay=false. FireOnState=true opta por callbacks de controle nas mudanças da fonte. O padrão apenas atualiza UI/flags.

`control:BindState(state,{Property?, Transform?, TwoWay?, FireCallback?, Reason?})` retorna um scope; Destroy dele desfaz a inscrição. Property aceita Value (padrão), Text (requer SetText), Subtitle, Visible, Enabled e Disabled. Transform(value) converte antes de aplicar. TwoWay só existe em Value e requer state gravável: mudanças do controle, mesmo silent, escrevem na State. Normalização do controle também retorna à State. Use Transform com TwoWay=false quando não houver transformação inversa. Um novo binding da mesma Property substitui o anterior e limpa seus listeners.

`control:DependsOn({Visible=rule?, Enabled=rule?, Reason=text?})`, também opção na criação, liga condições. Window:Condition(rule) cria uma State booleana. Rule aceita boolean, State, `{Flag="id", Equals=value?}`, `{State=state, Test=function(value) ... end}`, `{All={...}}`, `{Any={...}}` e `{Not=...}`. Sem Equals/Test, avalia verdade/falso do valor. Lua considera 0 e string vazia verdadeiros. Reason acrescenta uma dica quando desabilitado. Máximo 8 níveis, 64 nós e 32 fontes. Evite efeitos em Test/Transform/Computed; ciclos de atualização são interrompidos após 128 eventos por drenagem e diagnosticados.

## Lotes e perfis

`window:SetFlags({id=value,...},{Silent=true?})` retorna ok, err. Primeiro valida todas as flags/valores; um ID desconhecido ou valor inválido não altera nenhum controle. Depois aplica em ordem de ID dentro de Batch. Observadores recebem a coleção de flags já completa. O padrão chama os callbacks dos valores alterados após a aplicação; Silent evita esses callbacks/OnChanged, mas mantém observadores/bindings e UI. Callbacks pendentes antigos das flags alteradas são descartados pela versão da atualização.

`Library:Batch(fn)` coalesce notificações de State e executa fn imediatamente. É composição de notificações, não rollback de código arbitrário: se fn der erro depois de uma escrita, ela permanece e o erro é repassado após liberar o lote. Não dê yield dentro de Batch, pois o lote é compartilhado pela instância da library.

ImportConfig/LoadConfig continuam usando Schema=1; os novos campos Appearance.Animations e Appearance.Drag são opcionais e perfis anteriores continuam válidos. Primeiro valida o perfil completo, depois aplica valores/visual, então notifica observadores e callbacks. Silent=true evita callbacks tradicionais; observadores ainda executam. Não coloque efeitos inesperados em observadores de UI. Loads normais reaplicam callbacks persistentes mesmo para valores iguais: use Start idempotente e Stop para atualizar a lógica com segurança. Botões, ações, tarefas, conexões, gráficos/históricos, States e diagnósticos não são persistidos.

## Animações, arraste e seções

`Animations={Enabled=true,Speed=1,Intensity="Normal"}` na janela e `SetAnimations(options)` configuram o animador. Options mescla com os valores atuais, GetAnimations retorna cópia. Speed .25–4 acelera a duração; Intensity Normal/Subtle/Off. ReducedMotion=true ou animações desativadas aplicam o destino imediatamente. SetReducedMotion/SetAnimations encerram transições pendentes no destino.

Transições cobrem janela, minimizar/restaurar, botões, checkbox, dropdown, slider, abas, ColorPicker, seções, notificações e diálogos; cards/gráficos animam quando Animated=true. Tweens por propriedade/canal são cancelados em conflitos e liberados ao concluir/destruir. Modais mantêm a barreira de interação até a saída; toasts encolhem para acomodar a lista. Hover não reconstrói pixel art.

O gesto manual da barra acompanha diretamente a diferença de entrada e a posição local da âncora, sem relayout, salto por inset ou inércia ao soltar. SmoothDragging=false é o padrão; a opção true e DragResponsiveness=24 (8–80) continuam aceitas para reposicionamentos gerenciados como Center. ReducedMotion evita essa interpolação. Só o dedo que iniciou arrasta; foco perdido/soltar encerra a captura. Resize continua recalculando layout para adaptar controles.

`tab:CreateSection({Title="Opções",Collapsible=true,Collapsed=false})` habilita cabeçalho expansível. `SetCollapsed(bool, instant?)` e `IsCollapsed()` controlam a seção. FocusControl expande o destino antes de navegar, sem executar uma função. Estado de recolhimento é transitório. Preferências de animação/arraste aparecem em Configurações → Aparência e acompanham saves/Reset.

## Diagnóstico

Debug=false não coleta traceback ou snapshots. SetDebug(true) acrescenta Traceback (se debug.traceback existir) e estado do controle/tarefa/ação quando disponível. GetDiagnostics retorna cópia dos últimos 64 registros: Time (os.clock), ControlId, Operation, Phase, Message e, em Debug, Traceback/State. Mensagem tem limite de 2048 bytes; traceback, 8192. Erros repetidos da mesma fase/ID têm aviso/toast limitado a uma vez a cada 2 s; todos ainda entram no histórico e em OnError(fn). Use o listener retornado com Manage ou Disconnect.

`CallbackExecutor=function(callback,args,context) return callback(table.unpack(args,1,args.n)) end` é um adaptador opcional para instrumentar o contexto. Pode dar yield em workers, mas precisa executar e devolver os resultados do callback dentro da chamada; não agende a execução separadamente. SetCallbackExecutor(nil) restaura a execução padrão. A proteção xpcall, erros e tokens continuam na library. Não há API de um executor específico obrigatória.

GetRuntimeStats retorna Tasks, RunningTasks, Actions, WaitingActions (esperas de conclusão), Animations, QueuedVisuals, Resources (registros diretos da janela) e FrameConnection. As contagens descrevem o runtime gerenciado, não todas as conexões da engine. Veja [VALIDATION.md](VALIDATION.md) para resultados e limites dos testes.
