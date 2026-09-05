# ESTADO — Nossas Contas

Atualizado em 02/09/2026 — fim da fase 0: auditoria e estabilização. NO AR.

## Em que grau cada coisa está de pé

Três colunas diferentes, e a diferença importa: **implementado** é código
escrito; **testado** é medido pela bancada ou pela prova de RLS no banco;
**validado em produção** é alguém tendo usado aquilo num aparelho de verdade.
A terceira coluna é a que quase sempre falta.

| coisa | implementado | testado | validado em produção |
|---|---|---|---|
| login por e-mail e senha | sim | sim (senha errada, sessão sem perfil) | sim, só o Jonathan |
| tela do mês, totais, agrupamento | sim | sim (81 medidas) | sim |
| toque marca e desmarca pago | sim | sim | sim |
| selo "pago por fulano" | sim | sim | sim |
| editar valor, conta avulsa, apagar | sim | sim | sim |
| navegar entre meses | sim | sim | sim |
| contas fixas e gerar o mês | sim | sim (banco + bancada) | sim |
| PWA instalável e service worker | sim | sim (23 medidas) | sim, no iPhone do Jonathan |
| RLS isolando por casa | sim | sim (prova 04, com controle negativo) | sim |
| **Realtime entre dois aparelhos** | sim | só o lado do app, com evento fabricado | **não** |
| **Web Push: inscrever o aparelho** | sim | não (não dá para medir fora do navegador) | sim: 1 inscrição no banco |
| **Web Push: enviar de verdade** | sim | só o texto do aviso (11 medidas) | **sim — chegou no iPhone; último envio 03/09/2026** |
| **cron diário do aviso** | sim | não | sim, roda todo dia — mas **atrasa de 3h35 a 4h15** |
| segundo morador (a esposa) | — | — | **não: nunca entrou** |

## O que foi feito

- Pasta de trabalho criada em
  `~/Library/Mobile Documents/com~apple~CloudDocs/03_PROJETO/CONTAS_CASA`,
  com `.git` apontando para `~/GitRepos/contas-casa.git` (mesma convenção do
  PORTAL).
- `.gitignore` com `.env*`, `*.local.*`, `/dados/`, `/backup/` já no primeiro
  commit.
- `README.md` com stack, modelo de dados, regras de segurança e as três fases.
- `sql/01_schema_rls.sql` — três tabelas, constraints, trigger de vencimento e
  de autoria do pago, RLS ligada e forçada nas três, permissões e Realtime.
- `sql/02_config_inicial.sql` — modelo para criar a casa e os dois perfis a
  partir dos e-mails de login.
- `sql/03_seed_ficticio.sql` — nove lançamentos de mentira, dois deles sem
  valor previsto, para testar a tela antes de digitar conta de verdade.
- `sql/04_prova_rls.sql` — prova a RLS fingindo ser um usuário autenticado,
  com controle negativo (um id sem perfil tem que enxergar zero).

## O que faltava na fase 1 (lista de 31/08, hoje toda cumprida)

Fica registrada como estava, para o histórico. Tudo isto foi feito no mesmo
dia, e a fase 0 conferiu item por item no quadro lá em cima.

1. `config.js` com a URL do projeto e a `anon key`
2. Login por e-mail e senha (tela mínima, sessão persistida)
3. Tela do mês: agrupada por dia de vencimento, ordem crescente do dia
4. Toque único marca e desmarca pago, sem diálogo
5. Realtime: a tela do outro muda sozinha
6. Selo "pago por [nome], 14:32"
7. Cabeçalho fixo: previsto, pago, a pagar, e a contagem de itens em aberto
   sem valor
8. Editar o valor de um lançamento
9. Adicionar conta avulsa ao mês
10. Navegar entre meses
11. `manifest.webmanifest`, ícone e service worker mínimo (instalável)
12. Publicar no GitHub Pages

## Banco: rodado e provado em 31/08/2026

Projeto Supabase criado (Postgres 17.6, região sa-east-1). Acesso por `psql`
(`brew install libpq`; binário em `/opt/homebrew/opt/libpq/bin/psql`), com a
URI do Session pooler no `.env` — que o git ignora (`.gitignore:2`).

Os quatro SQLs rodaram sem erro. Números medidos:

| medição | resultado |
|---|---|
| tabelas com RLS ligada | 3 de 3 |
| políticas ativas | 7 |
| casa / perfis / lançamentos | 1 / 2 / 9 |
| lancamento na publicação realtime | 1 |
| prova RLS — eu | 1 casa, 2 perfis, 9 lançamentos |
| prova RLS — id sem perfil (controle negativo) | 0 / 0 / 0 |
| selo forjado (assinar como o outro, data de 2000) | banco gravou o autor certo e a hora certa |
| desmarcar pago limpa o selo | sim |
| enxergar lançamento de outra casa | 0 |
| inserir na casa alheia | bloqueado (42501) |
| alterar linha de outra casa | 0 linhas |

Cada número acima pôde voltar diferente — o controle negativo é o par de
medições 1 e 2 da prova de RLS, e o teste de casa vizinha (criada e revertida
por rollback, não ficou no banco).

## Interface: escrita em 31/08/2026

Arquivos: `index.html`, `app.css`, `app.js`, `config.js`, `sw.js`,
`manifest.webmanifest`, `icones/` (4 PNGs gerados), `vendor/supabase.js`.

Única dependência de terceiros: **@supabase/supabase-js 2.97.0**, build UMD,
versionada dentro do repositório em `vendor/` em vez de vir de CDN — assim o
app não depende de outro servidor no ar e o service worker consegue cachear.

Decisões tomadas no caminho:
- O cliente nunca escreve `vencimento`, `pago_em`, `pago_por`. Marcar pago
  manda **um campo só** (`pago`), o resto é trigger. Medido.
- Toque no valor edita; toque em qualquer outro ponto marca. Sem confirmação.
- Cache de pintura em `localStorage` (só leitura) para a tela aparecer antes da
  rede responder. Não é a fila offline da fase 2 — não guarda escrita nenhuma.
- Realtime cacheado por casa, com filtro `casa_id=eq.<id>` no servidor.

## Provas rodadas

`./testes/rodar.sh` — roda o `app.js` e o `sw.js` reais no `jsc` com o mundo
em volta falsificado. Placar naquele dia: **55 / 4 / 11 medidas, 0 falhas.**
(Depois dos blocos 4 e 5 virou 81 / 4 / 23 / 11, que é o placar de hoje.)

A bancada lê o `index.html` real para saber quais elementos nascem escondidos.
Um controle negativo pegou exatamente esse erro: com os elementos nascendo
visíveis, o teste do toque curto passava pelo motivo errado.

No navegador, servindo em 127.0.0.1:
| medição | resultado |
|---|---|
| login com senha errada, pela tela | "E-mail ou senha não conferem.", não entrou |
| leitura sem sessão (controle negativo) | `permission denied for table lancamento` |
| tela do mês, iPhone 375px, claro e escuro | conferida por captura |
| service worker registrando | **NÃO verificado** — o painel de navegador bloqueia |

## Publicado em 31/08/2026

Repositório público `profjonathansousa/contas-casa`, 6 commits, 27 arquivos.

**Endereço: https://jonathansousa.com.br/contas-casa/**
(também responde em https://profjonathansousa.github.io/contas-casa/)

Atenção: o app caiu no domínio profissional porque o site de usuário do
GitHub Pages já tem esse domínio configurado, e projeto herda. Nada de conta
aparece sem login, mas o endereço é público. Se Jonathan preferir outro,
dá para pôr um CNAME próprio no repositório.

A autoria dos 6 commits foi reescrita para
`297038968+profjonathansousa@users.noreply.github.com`, porque a conta bloqueia
push que expõe o e-mail pessoal. Histórico e arquivos intactos (6 commits,
27 arquivos, conferidos depois da reescrita). O `user.email` local do
repositório já está apontando para o noreply — os próximos commits saem certos
sem precisar fazer nada.

## Medido no site publicado

| medição | resultado |
|---|---|
| index e os 7 arquivos-chave | 200 em HTTPS |
| service worker | **registrado e ativo**, escopo `/contas-casa/` |
| casca guardada no cache | 11 arquivos, batendo com a lista do `sw.js` |
| manifest | "Nossas Contas", standalone, 3 ícones |
| leitura sem sessão (controle negativo) | `permission denied for table lancamento` |
| senha errada (controle negativo) | `Invalid login credentials` |

O service worker não registrava no servidor local de teste; no site publicado,
registra. Aquele erro era do painel de navegador, como eu suspeitava.

## Bloco 4 — contas fixas (31/08/2026)

Feito **a pedido de Jonathan, fora da ordem original**: era fase 3, mas sem
isso ele redigitaria vinte contas todo dia 1º, e nesse ponto o app perdia do
app de notas.

Banco (`sql/05_modelos.sql`): tabela `modelo` com RLS própria, FK de
`lancamento.modelo_id`, e duas funções `security invoker` (a RLS continua
valendo): `gerar_mes(competencia)` e `fixar_mes(competencia)`. A comparação
para não duplicar é por **descrição**, não por `modelo_id` — assim conta
digitada na mão também não vem repetida.

Tela: segunda tela "Contas fixas", alcançada pelo rodapé. Toque liga e desliga;
toque no valor edita o padrão; segurar apaga. O `+` dessa tela cria fixa, não
lançamento. Na tela do mês aparece "Trazer N contas fixas" quando falta alguma.

Provas no banco, com controle negativo:

| medição | resultado |
|---|---|
| setembro virando fixas | 21 |
| modelos sem valor (o "???") | 1 |
| gerar setembro DE NOVO | 0 |
| gerar outubro | 21, com o "???" ainda vazio e nada marcado como pago |
| novembro com uma fixa desligada | 20 |
| estranho enxergando modelos | 0 |
| estranho gerando mês | bloqueado: "Você não pertence a nenhuma casa" |

Bancada: **81 / 4 / 11 medidas, 0 falhas.**

## Dados reais

Setembro/2026 foi inserido direto no banco por `psql`, a partir da lista que
Jonathan mandou: 21 lançamentos, um deles sem valor. **Descrições, credores e
valores não estão no repositório** — nem em arquivo, nem em commit, nem aqui.
Para conferir os números, olhar o banco. O seed fictício de agosto foi apagado
(9 linhas).

## O que ainda NÃO foi provado

1. **Login de verdade.** Nunca entrei no app; não tenho senha de ninguém.
   (Jonathan confirmou que entrou e instalou na tela de início. A esposa ainda não.)
2. **Realtime entre dois aparelhos.** A bancada prova que o app reage ao
   evento; ela não prova que o evento chega pela rede.
3. **Contas fixas no aparelho.** Provei no banco e na bancada, não no iPhone.

## Buraco conhecido

Cinco das contas de setembro **não são mensais para sempre** — são acordos
parcelados, uma parcela de imposto e um material escolar. Controle de parcelas
é fase 3. Enquanto não existir, essas contas voltam todo mês se estiverem
ligadas nas fixas, e cabe a Jonathan desligá-las quando acabarem. Quais são
elas está no banco e na conversa, não aqui.

## Bloco 5 — notificação push (31/08/2026)

Banco (`sql/06_push.sql`): tabela `push_inscricao` com RLS por **pessoa**, não
por casa — cada um manda só nos próprios aparelhos. Mais a função
`resumo_do_dia(dia)`, `security invoker`: o robô entra com a chave de serviço e
enxerga todas as casas; uma pessoa logada chama a MESMA função e a RLS a limita
à casa dela. Uma função, dois usos, nenhum furo. Medido.

Chaves VAPID geradas com `openssl` e guardadas em GitHub Secrets
(`VAPID_PRIVATE_KEY`, `VAPID_PUBLIC_KEY`, `VAPID_SUBJECT`). A privada foi
apagada da máquina e nunca foi impressa. A pública está no `config.js`, que é
onde ela deve estar.

App: botão no rodapé que pede permissão, inscreve e grava. Toca de novo,
desliga. O botão só aparece onde `PushManager` existe — numa aba comum do
Safari do iPhone ele nem aparece, porque lá push não funciona.

`sw.js`: recebe o `push` e mostra a notificação; o toque foca o app se já
estiver aberto, e só abre janela nova se não estiver. Mensagem que não for JSON
não derruba o service worker (medido).

Agendador: `.github/workflows/avisos.yml`, cron diário às 11:00 UTC (08:00 de
Brasília) mais disparo manual com data simulada e modo seco. O envio é o
`avisos/enviar.mjs`, que usa `web-push` do npm — **no Actions, não no
frontend**.

Bancada: **81 / 4 / 23 / 11 medidas, 0 falhas.** O quarto bloco recorta do
`enviar.mjs` real as funções puras que montam o texto e mede o resultado; não
reimplementa nada.

## Falta um segredo, e só Jonathan pode pôr

`SUPABASE_SERVICE_ROLE` ainda **não** está nos GitHub Secrets. Sem ela o
workflow falha na primeira execução. Está em Supabase > Settings > API Keys,
escondida atrás de "Reveal". Comando:

```
gh secret set SUPABASE_SERVICE_ROLE -R profjonathansousa/contas-casa
```

(cola a chave quando ele pedir, e ela não fica no histórico do terminal)

## O que ainda NÃO foi provado

1. **Envio de verdade.** Nenhuma notificação chegou a nenhum aparelho ainda.
   Falta o segredo acima e falta alguém inscrito.
2. **Login da esposa.** Nunca aconteceu.
3. **Realtime entre dois aparelhos.**
4. **Pontualidade do cron.** O do GitHub entra em fila e atrasa; não é defeito
   nosso, é como ele funciona.

## Fora do escopo do bloco 5, de propósito

Bot do Telegram (a redundância) e offline com IndexedDB continuam por fazer.
Controle de parcelas continua na fase 3.

## Fase 0 — auditoria e estabilização (02/09/2026)

Nenhuma funcionalidade nova. O trabalho foi olhar o que já existe, medir e
tapar o que estava aberto.

### A bancada podia estar vermelha e ninguém saber

O `rodar.sh` saía com código **zero mesmo com medidas falhando** — o `jsc`
termina bem, e os arquivos de teste só imprimem "FALHA" sem derrubar nada.
Ou seja: qualquer CI ligado ali daria verde para bancada quebrada, que é pior
do que não ter CI. Agora o `rodar.sh` confere três coisas e sai com erro em
qualquer uma: medida falhando, motor morrendo, placar diferente de
`81 / 4 / 23 / 11`. Conferido com controle negativo — injetei uma medida falsa,
um `throw` e a remoção de uma medida, e as três ficaram vermelhas.

O outro impedimento era o motor: o script só rodava no macOS, com o caminho
fixo do `jsc`, em `#!/bin/zsh` e com expansão de caminho que só o zsh entende.
Agora é `sh`, aguenta caminho com espaço (a pasta de trabalho está dentro do
iCloud Drive, que tem) e, quando não acha o `jsc`, roda no `node` pela ponte de
`testes/ponte_node.js`. A ponte repõe só `print`, `readFile` e
`drainMicrotasks` — nada do app é fingido ali. Os dois motores rodam os mesmos
arquivos e fecham no mesmo placar.

### CI

`.github/workflows/testes.yml`, novo: roda `./testes/rodar.sh` a cada push e a
cada pull request. Separado do Web Push de propósito — não toca no banco, não
manda notificação, não usa Secret nenhum e pede só `contents: read`.

### avisos/ com npm ci

`avisos/package-lock.json` gerado, travando `web-push` em **3.6.7** e mais 16
pacotes indiretos, sem mudar nenhuma dependência. Os dois workflows do push
passaram de `npm install` para `npm ci --ignore-scripts` (a árvore inteira não
tem script de instalação, então isso não muda nada além de fechar a porta) e
ganharam `permissions: contents: read`. `node_modules/` entrou no `.gitignore`.

### Segurança — o que estava concretamente aberto

Medido no projeto real pelo linter do Supabase, não por leitura de código:

1. **`tg_lancamento()` assinava o que o cliente mandasse, no `insert`.** No
   `update` o banco já forçava autor e hora; no `insert` havia `coalesce`, e um
   `insert` com `pago = true`, `pago_por` do outro morador e `pago_em` de 2000
   era gravado como veio. O README prometia que o selo não podia ser forjado;
   agora é verdade nos dois caminhos. O seed e o `gerar_mes()` não mudam de
   comportamento (inserem sem `pago`).
2. **`minha_casa()` e `tg_lancamento()` chamáveis por quem não entrou.** Ambas
   são `security definer` e apareciam em `/rest/v1/rpc/...` para o papel `anon`.
   O `revoke ... from public` do script não bastava: o Supabase concede EXECUTE
   nominalmente a `anon` e a `authenticated` por *default privileges*, e revogar
   de `public` não tira concessão nominal. Agora os `revoke` nomeiam os papéis.
   A trigger continua disparando: o Postgres cobra EXECUTE de quem cria o
   gatilho, não de quem grava a linha.
3. **`push_inscricao` deixava mudar de casa.** A política de `insert` cobrava
   `casa_id = minha_casa()`; a de `update` não cobrava. Alguém podia apontar a
   própria inscrição para outra casa e passar a receber o resumo diário dela —
   precisaria adivinhar o uuid da casa, o que na prática não acontece, mas a
   assimetria era real e o conserto é uma linha.
4. **`calc_vencimento()` e `tg_modelo()` com `search_path` solto.** Aviso do
   linter, risco baixo (são `security invoker`), corrigido no mesmo passo.
5. **Cache de pintura sobrevivia ao "sair".** O `localStorage` guarda descrição
   e valor das contas do mês para a tela aparecer antes da rede; o logout não
   apagava. Agora apaga.

Nenhum segredo foi acrescentado, e o histórico do repositório foi varrido:
não há `.env`, nem chave de serviço, nem VAPID privada, nem dado financeiro em
nenhum commit. A `anon key` e a VAPID pública no `config.js` são públicas por
desenho e continuam onde estavam.

**Os quatro consertos de SQL só valem depois de rodar de novo, no SQL Editor,
os arquivos `sql/01_schema_rls.sql`, `sql/05_modelos.sql` e `sql/06_push.sql`.
Os três são idempotentes. Enquanto isso não for feito, o banco em produção
continua com os furos acima.**

### O aviso diário funciona — e o cron atrasa horas

Corrigido em 05/09/2026, depois de Jonathan avisar que recebeu notificação no
iPhone. O que a auditoria mediu no Actions e no banco:

| medição | resultado |
|---|---|
| execuções do "Aviso diário" em 01, 02, 03 e 04/09 | as quatro verdes |
| último envio registrado em `push_inscricao.ultimo_envio` | 03/09/2026, 11:45 de Brasília |
| dia 04/09 | rodou verde e **não enviou** — nada vencendo, nada atrasado |
| aparelhos inscritos | 1 |

O silêncio do dia 04 não é defeito: é a regra "só quando há o que dizer"
funcionando. O bloco 5 dizia que faltava o Secret e faltava alguém inscrito;
as duas coisas foram resolvidas por Jonathan e o ESTADO não tinha registrado.

**O defeito real é a pontualidade.** O cron está agendado para 11:00 UTC
(08:00 de Brasília) e disparou às 14:35, 14:44, 14:45 e 15:15 UTC nos quatro
dias — de 3h35 a 4h15 de atraso, todo dia. O README dizia "de dez a sessenta
minutos", que era o que a documentação do GitHub sugere; a medição diz outra
coisa. Agendar em minuto `:00` é o pior caso, porque é onde todo mundo agenda.
Qualquer aviso com hora marcada (o pedido das notificações de 12h e 20h)
esbarra nisto primeiro.

### Realtime e Web Push: o que a auditoria pode e não pode dizer

Não foi criada nenhuma camada nova. O que existe é o que já existia: o canal
`postgres_changes` filtrado por `casa_id` e o robô do Actions com `web-push`.

O que a bancada prova: que o app **reage** a um evento de tempo real fabricado
e ignora o de outro mês; que o `sw.js` monta a notificação a partir de um
`push` fabricado e não morre com mensagem que não é JSON; que o texto do aviso
sai certo no singular, no plural, na lista longa e no dia vazio.

O que a bancada **não** prova, e nenhum teste automático aqui vai provar:
que o evento atravessa a rede até o outro aparelho, e que a notificação chega.
Isso é validação manual, e está pendente — a lista está logo abaixo.

### Divergência entre o banco e o repositório

O banco em produção tem uma tabela **`public.cron_push_inscricao`** que não
existe em nenhum arquivo de `sql/`. Está vazia (0 linhas), com RLS ligada e sem
política nenhuma, então ninguém lê nem escreve nela — não há risco, mas também
não há razão para ela existir. `pg_cron` e `pg_net` não estão instalados e não
há Edge Function nenhuma: não existe um segundo caminho de envio rodando por
trás. Decidir se apaga ou se documenta é do Jonathan; a fase 0 não mexeu em
produção.

Contagem do banco em 02/09/2026: casa 1, perfil 2, lancamento 35, modelo 21,
push_inscricao **1** — ou seja, já há um aparelho inscrito, ao contrário do que
dizia o bloco 5.

## Plano combinado em 05/09/2026

Conversado com Jonathan depois da fase 0. Decisões dele, registradas para não
se perderem:

- **Quem paga é a esposa, na maioria das contas.** Ela recebe **só o aviso das
  20h**; Jonathan recebe os três.
- **Nada de DDA.** Buscar boleto por CPF é serviço de instituição financeira e
  está fora de alcance (e trocar credencial de banco por conveniência inverte o
  modelo de risco do projeto). Jonathan cola os códigos à mão.
- **O aviso de véspera vira pedido de ação**, e só para quem cola: "Aluguel
  vence amanhã — cole o código de pagamento no app".
- **Agendador**: domar o GitHub primeiro, antes de cogitar trocar de
  plataforma.

### A dependência que decide a ordem

"Cole o código" só é frase honesta depois que existir onde colar. Escolhida a
ordem que entrega valor antes: o aviso de véspera nasce dizendo "deixe o
pagamento pronto" e vira "cole o código" no bloco seguinte. Custo: mexer duas
vezes numa frase.

### Bloco 6 — pontualidade do agendador

Fundação: sem isso, aviso com hora marcada é promessa que o GitHub não cumpre.

- sair do minuto `:00` (é onde todo mundo agenda) e passar a rodar de hora em
  hora
- `enviar.mjs` decide pelo horário de São Paulo qual slot está aberto
- tabela-registro `aviso_enviado` com chave única por pessoa, dia e slot: run
  atrasado ainda manda, e **nunca manda duas vezes**
- medir uma semana e anotar aqui o atraso observado
- bancada: medidas para a escolha do slot e para o "não repete"

### Bloco 7 — três avisos, por pessoa

Hoje o robô monta **uma mensagem por casa** e manda para todos os aparelhos da
casa. Para cada um receber uma coisa, o laço passa a ser **por pessoa**.

- a preferência mora no `perfil` (a pessoa), não na `push_inscricao` (o
  aparelho): assim iPhone e iPad da mesma pessoa seguem a mesma regra, e a
  inscrição continua sendo só o endereço de entrega. **A RLS de `perfil` já
  permite cada um editar a própria linha — não precisa de política nova.**
- três colunas booleanas, todas `default true`; a esposa desliga duas, uma vez
- `resumo_do_dia` ganha o de amanhã (`vencem_amanha`, `titulos_amanha`) — mesma
  função, mesmo princípio de "uma função, dois usos"
- app: três interruptores debaixo do botão de avisos
- tag por slot, senão o aviso da noite some por cima do do meio-dia

| slot (Brasília / UTC) | quem recebe | o que diz |
|---|---|---|
| véspera, 20h / 23:00 | só Jonathan | "Aluguel vence amanhã — deixe o pagamento pronto" |
| dia, 12h / 15:00 | só Jonathan | "3 contas vencem hoje — R$ …" |
| dia, 20h / 23:00 | os dois | "ainda hoje, não pago: …" + atrasadas |

Os dois slots das 20h são **a mesma execução**: véspera e dia caem no mesmo
relógio.

**Pré-requisito humano:** a esposa nunca entrou no app. Sem o login dela e sem
"avisar neste aparelho" no iPhone dela, não há para onde mandar as 20h.

### Bloco 8 — código de pagamento colado

A sutileza que manda no desenho: **a linha digitável muda todo mês.** Os 47
dígitos do boleto bancário (e os 48 do de arrecadação) carregam fator de
vencimento e valor. Então o código pertence ao **lançamento do mês**, não à
conta fixa. O que cabe na conta fixa é **PIX estático** — chave sem valor —,
que não muda.

- `lancamento` ganha `codigo_pagamento` e `codigo_tipo`
- `modelo` ganha o PIX estático
- app: "colar código" → valida (módulo 10 e 11 no boleto, CRC16 no PIX),
  **extrai valor e vencimento** e mostra para conferir. Isso mata o "???" no
  gesto de colar.
- na linha da conta, um botão "copiar"
- o aviso de véspera passa a dizer quantas ainda estão sem código
- bancada: validador e extrator são funções puras, exatamente o que ela mede bem

Privacidade: linha digitável e PIX são dado de pagamento — identificam
beneficiário e valor. Ficam sob a mesma RLS, passam a estar também no cache do
`localStorage` (o que justifica melhor a limpeza no logout feita na fase 0) e
**nunca entram no repositório**.

### Riscos que ficam escritos antes de começar

1. **O atraso pode não ceder.** Se depois de uma semana continuar acima de uma
   hora, volta a conversa do `pg_cron` — e aí a chave VAPID privada sai dos
   GitHub Secrets e vai para o Vault do Supabase. É outra camada e outro modelo
   de segredo; não entra sem decisão explícita.
2. **Três avisos por dia é muito.** Com 21 contas fixas espalhadas, é
   notificação em quase todo dia útil. O liga-desliga protege, mas vale
   reavaliar depois de duas semanas de uso — o próprio README diz que
   notificação sem motivo é notificação que se aprende a ignorar.
3. **Dado novo e sensível** no banco e no aparelho, com o bloco 8.

### Fora de fila, e continua doendo

**Parcelas.** Cinco contas voltam todo mês e Jonathan desliga na mão. Nenhum
dos três blocos acima encosta nisso.

## VALIDAÇÕES MANUAIS PENDENTES

Nenhuma delas pode ser feita por código; todas precisam de aparelho, de gente
ou do painel do Supabase.

1. ~~Rodar de novo os três SQLs.~~ **Feito em 05/09/2026**, com autorização de
   Jonathan, como a migração `fase_0_correcoes_de_seguranca` (só as partes que
   mudaram; o resto dos arquivos já estava aplicado e igual). Provado no banco:
   um `insert` tentando assinar como o outro morador, com data de 2000, foi
   gravado com a hora de agora e sem autor forjado — e a prova foi desfeita por
   `raise exception`, sem deixar linha nenhuma. O linter do Supabase caiu de 7
   avisos para 2: `minha_casa` chamável por quem está logado (é de propósito, o
   app precisa) e a proteção de senha vazada, que é um clique no painel.
2. ~~Pôr `SUPABASE_SERVICE_ROLE` nos Secrets.~~ **Feito por Jonathan.**
3. ~~Aviso diário, modo seco.~~ **Feito.**
4. ~~Aviso diário de verdade.~~ **Feito: a notificação chegou no iPhone.**
   Fica no lugar dela a pontualidade do cron, acima.
5. **Realtime entre dois aparelhos.** Duas telas abertas na mesma casa, marcar
   pago numa e ver a outra mudar sozinha, sem recarregar.
6. **Login da esposa**, e a inscrição do aparelho dela nos avisos.
7. **Ligar a proteção de senha vazada** no Supabase (Authentication > Policies),
   apontada pelo linter: hoje está desligada, e é um clique.
8. **Decidir o destino de `public.cron_push_inscricao`.**

## PRÓXIMA AÇÃO EXATA

1. **Bloco 6**, o agendador. É a fundação dos outros dois.
2. Em paralelo, duas coisas humanas: **a esposa entra no app** e liga os avisos
   no iPhone dela (sem isso o bloco 7 não tem para onde mandar), e **o teste do
   Realtime com dois aparelhos**, que é a última coisa da fase 1 sem prova.
3. Rodar `sql/04_prova_rls.sql` para conferir que a RLS continua de pé depois
   da migração de 05/09.
4. Bloco 7, depois bloco 8. Nada dos três foi começado nem preparado de
   véspera.
