# ESTADO — Nossas Contas

Atualizado em 02/09/2026 — fim da fase 0: auditoria e estabilização. NO AR.

## Duas contagens diferentes, e a confusão entre elas

Este projeto usa duas palavras que parecem a mesma coisa e não são:

- **Fase** é escopo de produto — o que o app faz. Estão no `README.md`: fase 1
  (a tela do mês), fase 2 (o aviso), fase 3 (parcelas, gráficos, histórico).
- **Bloco** é unidade de trabalho — uma sessão, uma entrega.

A auditoria de 05/09 foi pedida como **"Fase 0"** e ficou com esse nome, mas é
um bloco de trabalho, não uma fase do produto. Fica registrado para ninguém
procurar uma "fase 0" no roadmap do README e não achar.

E há um buraco: **os blocos 1, 2 e 3 nunca foram numerados.** Este arquivo só
batiza "Bloco 4 — contas fixas" e "Bloco 5 — notificação push"; o que veio
antes está descrito, mas sem número. Reconstruído do histórico do git, para a
numeração parar de ter começo faltando:

| bloco | quando | o que foi |
|---|---|---|
| **1 — banco e RLS** | 30/08 23:53 a 31/08 00:50 | as três tabelas, as constraints, os triggers de vencimento e de autoria, RLS ligada e forçada, e a prova de RLS com controle negativo (`sql/01` a `sql/04`) |
| **2 — a interface da fase 1** | 31/08 01:09 a 08:28 | login, tela do mês, toque marca pago, tempo real, selo de autoria, editar valor, conta avulsa, navegar entre meses, PWA, apagar segurando o dedo, e o ajuste do toque longo de 0,5 para 0,7 s |
| **3 — publicação** | 31/08 08:04 | GitHub Pages no ar, service worker registrando de verdade, e as medições no site publicado |
| **4 — contas fixas** | 31/08 08:51 | descrito adiante, com esse nome |
| **5 — notificação push** | 31/08 09:12 a 11:29 | descrito adiante, com esse nome |
| **0 — auditoria** ("Fase 0") | 05/09 | descrito adiante |
| **6 — pontualidade do agendador** | 05/09 | descrito adiante |
| **7 — três avisos, por pessoa** | 05/09 | descrito adiante |

Os blocos 2 e 3 se cruzam no histórico: a publicação foi registrada às 08:04 e
o ajuste do toque longo às 08:28. A fronteira entre os dois não é limpa, e não
adianta fingir que é.

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
| **cron diário do aviso** | sim | não | sim, roda todo dia — mas **atrasava de 3h35 a 4h15** |
| **slots de aviso por hora de Brasília** | sim (bloco 6) | sim | sim — na `main` desde 05/09, com `sql/07` no banco |
| **três avisos, um por pessoa** | sim (bloco 7) | sim | parcialmente: **os interruptores apareceram no iPhone** (05/09); os avisos em si ainda não chegaram |
| **contas que acabam (parcelas)** | sim (bloco 9) | sim (121/4/24/45) | **não — no ar, mas nenhuma conta foi marcada como parcelada ainda** |
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

## Bloco 6 — pontualidade do agendador (05/09/2026)

**Feito.** Espera merge e um SQL.

O problema, medido: o cron do GitHub agendado para 11:00 UTC disparou às 14:35,
14:44, 14:45 e 15:15 em quatro dias seguidos. Não dá para prometer "20h" em
cima disso.

A saída foi **parar de confiar no horário do cron**:

- ele roda **de hora em hora, no minuto 17** (o `:00` é onde todo mundo agenda
  e onde a fila é pior), das 12:17 às 20:17 de Brasília, mais 21:17 e 22:17 de
  repescagem;
- quem decide o que mandar é o **relógio de Brasília dentro do `enviar.mjs`**,
  não a hora em que o run acordou;
- cada aviso tem hora para **abrir** e hora para **deixar de fazer sentido**.
  Conta que vence hoje avisada à meia-noite chegou tarde demais para servir e
  cedo demais para ser educada: melhor não mandar. O do meio-dia expira às 18h;
  o das 20h, à meia-noite;
- `sql/07_avisos.sql` cria `aviso_enviado`, a memória que impede o robô de
  mandar o mesmo aviso doze vezes por dia. Um por casa, por dia e por slot. RLS
  ligada e forçada, **sem política e sem grant**: ninguém do app lê nem
  escreve, só o robô com a chave de serviço.

Detalhes que valem estar escritos:

- **O dia do registro é o de Brasília, não o de UTC.** A repescagem das 21h e
  22h cai depois da meia-noite em UTC e ainda é o mesmo dia aqui. Errar isso
  faria o aviso das 20h ser mandado duas vezes.
- **Só registra se algum aparelho recebeu.** Se todos falharam, o run da hora
  seguinte tenta de novo.
- **A tag muda por slot.** Mesma tag faria o aviso da noite apagar o do
  meio-dia na tela do celular.
- O aviso, que era um só de manhã, passa a ser dois: **12h e 20h**. O de
  véspera é do bloco 7, que precisa de SQL novo.
- A faixa de funções puras do `enviar.mjs` agora tem **marca explícita** no
  arquivo. Antes a bancada recortava de `const dinheiro` até `const resumos`, e
  renomear uma variável quebrava tudo sem explicar por quê.

Bancada: **81 / 4 / 23 / 27**, 0 falhas. As 16 medidas novas cobrem a hora de
Brasília (inclusive a virada do dia em UTC e a meia-noite, que alguns motores
devolvem como "24" e faria o slot da noite nunca fechar), a abertura e a
expiração de cada slot, e a tag por slot. Três são controle negativo: 18h,
meia-noite e 3h da manhã não podem abrir aviso nenhum.

**Concluído em 05/09**, com autorização de Jonathan: `sql/07_avisos.sql`
aplicado no banco (`aviso_enviado` de pé, RLS ligada e forçada, zero políticas,
`anon` e `authenticated` sem leitura, zero linhas) e a branch mesclada na
`main`. A primeira execução do cron novo é às 15:17 UTC — 12:17 de Brasília —
e é ela que mede se o remédio funcionou.

## Bloco 7 — três avisos, um por pessoa (05/09/2026)

**No ar desde 05/09/2026.** `sql/08_avisos_por_pessoa.sql` aplicado no banco
**antes** do merge, como manda a regra de ordem registrada adiante; branch
mesclada na `main` em seguida.

Conferido no banco depois de aplicar: três colunas novas no `perfil`, as duas
pessoas com os três avisos ligados (é o padrão), e `resumo_do_dia` continua
`security invoker`, com `search_path` fixo, sem execução para `anon` e com
execução para `authenticated` e para o robô.

Até aqui o robô montava **uma mensagem por casa** e mandava para todos os
aparelhos dela. Quem paga a maioria das contas quer só o aviso das 20h; o
Jonathan quer os três. Então o laço passou a ser **por pessoa**.

### Onde a preferência mora, e por quê

Na **pessoa** (`perfil`), não no aparelho (`push_inscricao`). Um aparelho é
endereço de entrega; querer ou não querer é da pessoa — quem desliga um aviso
espera que ele desligue no iPhone e no iPad. E há uma economia real nisso: a
política `perfil_editar_o_meu` já deixa cada um mexer na própria linha e só
nela, com o `with check` impedindo mudar de casa. **Nenhuma política nova.**

Três colunas booleanas, `default true`: quem não quiser, desliga uma vez.

### Os três avisos

| slot | hora (Brasília / UTC) | o que diz |
|---|---|---|
| `vespera_20h` | 20h / 23:00 | "2 contas vencem amanhã — R$ 320,50 · deixe o pagamento pronto" |
| `dia_12h` | 12h / 15:00 | "3 contas vencem hoje — …" |
| `dia_20h` | 20h / 23:00 | o mesmo do meio-dia, com o que sobrou por pagar |

Os dois das 20h são **a mesma execução**, com tags diferentes, senão um apaga
o outro na tela do celular.

O texto da véspera **pede uma ação em vez de informar** — foi ideia de
Jonathan, e é melhor do que o desenho anterior: quem paga prepara o pagamento
na noite anterior, com calma. Por ora diz "deixe o pagamento pronto"; vira
"cole o código de pagamento no app" no bloco 8, quando existir onde colar.
Prometer antes disso seria pedir uma coisa que o app não sabe fazer.

### Detalhes que valem estar escritos

- **`resumo_do_dia` passou a enxergar o dia seguinte.** É `drop` e `create`,
  não `create or replace`: mudar as colunas devolvidas muda o tipo de retorno,
  e o Postgres não deixa substituir. O `drop` leva as permissões junto, então
  os `grant` estão repetidos logo abaixo no arquivo.
- **"Sem valor" continua sendo só do que já venceu.** A conta de amanhã ainda
  tem o dia de hoje para ganhar valor; contá-la ali seria cobrar cedo.
- **Registro antigo, sem pessoa, vale por todo mundo da casa.** No dia da
  virada existem linhas de `aviso_enviado` gravadas pelo bloco 6, quando o
  aviso era da casa inteira. Sem essa regra, quem já tinha recebido receberia
  de novo.
- **A tabela de slot virou função** (`colunaDoSlot`), porque `const` dentro do
  recorte da bancada não escapa dele. A bancada só mede o que consegue chamar.
- **O controle negativo do "sem perfil" ficou explícito.** Ele é montado
  trocando uma linha do `prelude.js` por `sed`; antes o `sed` casava com um
  objeto inteiro, e mexer no perfil falso quebraria a troca em silêncio — o
  controle passaria a medir a mesma coisa da rodada normal. Agora o alvo é uma
  linha própria e o `rodar.sh` **confere que a troca aconteceu** e para se não
  aconteceu.

### Correções da auditoria de véspera (05/09)

Auditoria pedida antes de mesclar, contra o remoto. Três achados:

1. **O disparo manual não oferecia o `vespera_20h`** — `options: ['', 'dia_12h',
   'dia_20h']`. Justamente o aviso novo era o único que não dava para conferir
   à mão, porque só abre às 20h. Os três estão lá agora, e a opção vazia virou
   `'auto'`: opção de string vazia num `type: choice` é canto escuro do GitHub,
   e este arquivo ainda não tinha sido exercitado por dispatch nenhum.
2. **Slot desconhecido passava direto** e viraria notificação com tag
   inventada. Agora o robô recusa e sai com erro. Medido, com controle
   negativo.
3. **O README se contradizia sozinho**: dizia "o aviso é um por dia" doze
   linhas depois de descrever "um aviso por casa, por dia **e por slot**". E
   não mencionava nem os três avisos, nem a escolha por pessoa, nem os três
   interruptores. Corrigido.

Um quarto ponto virou regra de operação, não conserto: **`sql/08` tem que ser
aplicado ANTES do merge, nunca depois.** O `app.js` seleciona as três colunas
novas do perfil; sem elas o PostgREST devolve erro, o `carregarPerfis` lança, o
`abrirApp` faz `signOut()` e os dois moradores caem na tela de login com a
mensagem crua do Postgres. Como o Pages publica no instante do merge, a ordem
invertida derruba o app. A ordem certa é segura dos dois lados: aplicar o SQL
com a `main` de então não quebra nada, porque o `montarAviso` do bloco 6 lê só
os campos que conhece.

Bancada: **91 / 4 / 23 / 45**, 0 falhas. As medidas novas cobrem o texto da
véspera (plural, singular, lista longa), a coluna que cada slot consulta, o
texto certo para cada slot, e os três interruptores na tela — inclusive o
controle de que mexer em preferência de aviso não encosta em lançamento
nenhum.

### O que falta para o bloco 7 estar provado

Código e banco estão prontos; o que falta é gente e aparelho.

1. **A segunda pessoa da casa entrar no app** e ligar os avisos no iPhone
   dela — sem isso não há para onde mandar as 20h. Depois é ela quem desliga
   os dois que não quer, na própria tela.
2. **Ver o aviso de véspera chegar.** Actions > "Aviso diário das contas" >
   Run workflow, escolhendo `vespera_20h` e marcando **seco** para conferir o
   texto sem mandar; depois sem o seco.
3. ~~Ver os três interruptores no rodapé do app, no iPhone.~~ **Feito em
   05/09: apareceram.** É a primeira parte do bloco 7 validada em produção.

### O que o cron mostrou no dia do merge

O run de 05/09 disparou às 13:35 UTC (10:35 de Brasília) **com o arquivo
antigo** — `head_sha 75cfa6c` —, porque a hora de disparo caiu antes do merge
do bloco 6. Foi o sistema velho, 2h35 atrasado, e não mede nada sobre o
remédio. A primeira execução do cron novo é às 15:17 UTC.

Detalhe do dia: às 14:40 UTC o `resumo_do_dia` já devolvia **zero linhas** — as
seis contas que venciam hoje foram pagas depois do aviso da manhã. Então a
primeira execução do cron novo provavelmente **não vai mandar nada**, e estará
certa ao não mandar. Medir a pontualidade vai exigir um dia com conta em
aberto.

## Roadmap — blocos 6 a 9

| bloco | o que é | estado | depende de |
|---|---|---|---|
| **6** | pontualidade do agendador | **feito e no ar** | — |
| **7** | três avisos, um por pessoa | **escrito e medido**, espera `sql/08` + merge | bloco 6 e o login da segunda pessoa |
| **9** | parcelas | desenhado abaixo | nada |
| **8** | código de barras / PIX colado | desenhado | nada |

Ordem recomendada: **6 → 7 → 9 → 8**. Parcelas passa na frente do código de
pagamento por dois motivos: é o que custa trabalho manual todo mês, e uma conta
parcelada que já acabou e continua voltando vira, com os avisos do bloco 7,
**três alarmes falsos por dia**. Ou seja, o bloco 9 protege o 7.

## Bloco 9 — parcelas (desenho, 05/09/2026)

Isto nunca tinha sido desenhado. O que existia era só o enunciado, no "Buraco
conhecido" mais acima: cinco contas de setembro não são mensais para sempre —
são acordos parcelados, uma parcela de imposto e um material escolar —, e
enquanto não houver controle de parcelas elas voltam todo mês e cabe a Jonathan
desligá-las na mão quando acabarem.

### A ideia, em uma frase

Uma conta fixa passa a poder dizer **"sou 12 vezes, a partir de tal mês"**, e o
`gerar_mes()` para de trazê-la quando a última passou.

### Onde os dados moram

Na `modelo` (a conta fixa), duas colunas, as duas anuláveis:

- `parcelas_total int` — nulo quer dizer **mensal para sempre**, que é o caso
  da maioria;
- `parcela_1 date` — a competência da primeira parcela.

A parcela do mês M é aritmética simples: `n = (ano(M) - ano(p1)) * 12 +
(mês(M) - mês(p1)) + 1`. Entra no mês se `1 <= n <= parcelas_total`.

Na `lancamento`, duas colunas preenchidas pelo `gerar_mes()`:
`parcela_n` e `parcela_de`.

### A armadilha que decide o desenho

O caminho óbvio seria escrever "Acordo X (5/12)" na **descrição**. Não pode: a
regra que impede o `gerar_mes()` de duplicar compara **por descrição**, e uma
descrição que muda todo mês faria a mesma conta entrar de novo toda vez. Por
isso o contador vai em coluna própria e a tela é que junta as duas coisas:
`Acordo X · 5/12`.

### O que muda em cada lugar

- **`gerar_mes()`**: filtra pela janela e preenche `parcela_n` / `parcela_de`.
- **Tela do mês**: a linha mostra `5/12` ao lado da descrição, do mesmo jeito
  discreto que a tela de fixas já mostra "todo dia 8".
- **Tela de contas fixas**: mostra "parcela 5 de 12" e, quando passou da
  última, "acabou" — aí é só apagar.
- **`faltandoNoMes()` no `app.js`**: o contador de "Trazer N contas fixas"
  precisa da mesma janela, senão fica oferecendo para sempre uma conta que
  acabou.

**Custo aceito, e escrito antes:** a regra da janela passa a existir em dois
lugares — no SQL do `gerar_mes()` e no JavaScript do `faltandoNoMes()`. É
aritmética de três linhas dos dois lados, e a bancada mede o lado JavaScript.
A alternativa (o `gerar_mes()` desligar a conta sozinha ao gerar a última) foi
descartada porque cria um segundo mecanismo: `ativo` quer dizer "eu quero", e a
janela quer dizer "ainda existe". Misturar os dois confunde na hora de entender
por que uma conta sumiu.

### O trabalho de verdade está na tela, não no banco

Hoje, na tela de contas fixas, **não existe como editar uma conta fixa**: toque
liga e desliga, toque no valor edita o valor, segurar apaga. Não há onde pôr
"12 parcelas a partir de março". É preciso inventar um gesto — o candidato é
tocar na linha "todo dia 8", que hoje não faz nada, e abrir uma folha com dia,
parcelas e mês da primeira. Isso precisa respeitar a regra do projeto: polegar
de uma mão só, sem burocracia.

### As cinco contas que já existem

Depois que a tela existir, Jonathan abre cada uma e preenche. Se preferir,
um `update` no SQL Editor resolve em um minuto — ele sabe quais são; **elas não
estão no repositório e não vão estar.**

### O que a bancada vai medir

A janela é função pura: parcela 1 no mês da primeira, 12 no décimo segundo,
nada no décimo terceiro, nada antes da primeira. Mais o controle negativo de
sempre: conta sem `parcelas_total` continua vindo todo mês, para sempre.

## Bloco 9 — contas que acabam (05/09/2026)

**No ar desde 05/09/2026.** `sql/09_parcelas.sql` aplicado no banco **antes**
do merge; branch mesclada em seguida.

Conferido no banco depois de aplicar: duas colunas novas na `modelo`, duas no
`lancamento`, a janela fazendo conta certa (parcela 1 no mês da primeira, 12 na
décima segunda, 13 fora do intervalo, nulo para conta mensal), um gatilho só na
`modelo` e nenhuma fixa parcelada ainda. Provado também que o gatilho normaliza
o mês da primeira parcela: um insert com `2026-03-17` foi gravado como
`2026-03-01`, e a prova foi desfeita por `raise exception`, sem deixar linha.

O buraco estava registrado desde o começo, em "Buraco conhecido": cinco contas
não são mensais para sempre — acordos parcelados, uma parcela de imposto, um
material escolar — e voltavam todo mês até alguém desligá-las na mão. Ficou
mais caro depois do bloco 7: uma parcelada encerrada que continua vindo vira
**três alarmes falsos por dia**.

Uma frase: uma conta fixa passa a poder dizer "sou 12 vezes, a partir de tal
mês", e o `gerar_mes()` para de trazê-la quando a última passou.

### As decisões que valem estar escritas

- **O contador vai em coluna própria, não na descrição.** Escrever "Acordo
  (5/12)" seria o caminho óbvio e estaria errado: a regra que impede o
  `gerar_mes()` de duplicar compara **por descrição**, e uma descrição que muda
  todo mês faria a mesma conta entrar de novo toda vez. Quem junta as duas
  coisas é a tela.
- **As duas colunas andam em par**, com constraint no banco e conferência na
  tela: "12 vezes" sem dizer a partir de quando não diz nada.
- **Nada de desligar sozinho.** O `gerar_mes()` poderia marcar `ativo = false`
  ao gerar a última, e foi descartado: `ativo` quer dizer "eu quero" e a janela
  quer dizer "ainda existe". Misturar os dois confunde na hora de entender por
  que uma conta sumiu.
- **Custo aceito:** a aritmética da janela existe em dois lugares — na função
  `parcela_no_mes()` do banco e no `parcelaNoMes()` do `app.js`. São três
  linhas de cada lado, e o lado JavaScript é medido.
- **O gesto novo:** tocar na linha "todo dia 8" da conta fixa abre a folha de
  parcelas. Era a única parte da linha que não fazia nada. O toque para lá
  **não pode** ligar nem desligar a fixa — isso é medido.
- **O mês é digitado à mão**, não em `<input type="month">`: o Safari do iPhone
  não é confiável nesse tipo de campo. A leitura é função pura e recusa
  rabisco.

### Conserto no mesmo dia: a barra que o teclado não tem

Jonathan tentou cadastrar a primeira conta parcelada e não conseguiu. O campo
do mês pede **teclado numérico** — que é o certo, é um número —, e o teclado
numérico do iPhone **não tem barra**. O `paraCompetencia()` exigia `mm/aaaa`.
Ou seja: o app pedia uma tecla que a pessoa não tinha na tela.

Conserto: os dígitos soltos passam a valer tanto quanto a forma com barra —
`092026` e `92026` viram 09/2026 —, e **sair do campo mostra como foi
entendido**, para não precisar salvar para descobrir. As formas com barra e com
traço continuam valendo.

### E o conserto não chegou: o service worker servia código vencido

O conserto acima foi publicado e **não funcionou** — Jonathan viu a explicação
nova da folha e continuou recebendo a recusa do formato. Diagnóstico:
`index.html` chegou, `app.js` não.

Causa, e é estrutural: **o `fetch()` de dentro do service worker ainda passa
pelo cache HTTP do navegador**, e o GitHub Pages manda `max-age=600`. Ou seja,
o "rede primeiro" do `sw.js` era, na prática, "cache do navegador primeiro, por
até dez minutos". Como cada arquivo vence no seu próprio relógio, dá para
receber a **tela nova rodando o código velho** — que é pior do que receber tudo
velho, porque parece que atualizou.

Conserto: os arquivos do app passam a ser pedidos com `cache: 'no-cache'`, que
não quer dizer "baixe tudo de novo" e sim "pergunte se mudou" — a resposta 304
continua barata. Requisição de navegação não pode ser reconstruída (o navegador
recusa), então essa vai como veio. E o `VERSAO` subiu para `v5`, o que faz o
`activate` limpar a casca antiga.

Isso vale para todo conserto futuro: **até agora, publicar não garantia
entregar.** Uma medida nova guarda a regra.

De quebra, a bancada ensinou de novo a mesma lição do `URL`: o node traz um
`Request` de verdade, que recusa o pedido de mentira da bancada. O falso agora
vale nos dois motores, sem `typeof`.

A lição, que vale para o bloco 8: **escolher o teclado é escolher o alfabeto**.
Pedir `inputmode="numeric"` e depois exigir pontuação é contradição, e nenhuma
medida da bancada pegaria isso — ela digita direto no campo, sem teclado. Só
aparece no aparelho, na mão de quem usa.

Sete medidas novas, duas de controle negativo: aceitar dígito solto não pode
virar aceitar qualquer coisa (mês 13 e ano sozinho continuam recusados).

### O que a bancada mede

23 medidas novas, quatro delas controle negativo: parcelada que acabou some do
"Trazer N contas fixas" e avisa "acabou, eram 3"; conta comum não ganha
contador; um campo sem o outro não salva; mês rabiscado não passa. Placar:
**121 / 4 / 24 / 45**, 0 falhas.

De quebra, a auditoria do placar pegou uma dívida da rodada anterior: o
`rodar.sh` já exigia 45 no quarto bloco, mas o README e o `testes/LEIA.md`
ainda diziam 40. O guarda do placar confere o `rodar.sh`, não os documentos.

### Um nome fictício vazou para a documentação

Achado em 05/09, ao conferir um nome: **"Marina" é o nome de mentira da
bancada** (`testes/prelude.js`), e ele escorregou de lá para quatro pontos
deste arquivo e para um comentário do `sql/08`, como se fosse a esposa do
Jonathan. Trocado por papel — "a segunda pessoa da casa", "quem paga a maioria
das contas".

Não é um vazamento de dado real: o nome que estava escrito é falso. É pior de
outro jeito — documentação que apresenta invenção como fato. E encosta na regra
do `README.md`: **nenhum nome de familiar entra neste repositório**, regra que
já custou um commit de conserto uma vez (`f1f74cf`, "tira nome real de familiar
dos arquivos de teste"). O nome verdadeiro foi dito na conversa e **fica na
conversa**.

Nos arquivos de teste "Marina" continua, e está certo: ali é dado fictício de
propósito, como o "Jonathan" que também é só um rótulo da bancada.

### O que falta

**Preencher as cinco contas** que já existem, pela tela: abrir "contas fixas",
tocar na linha "todo dia N" de cada uma e dizer quantas parcelas e o mês da
primeira. Quais são elas está no banco e na conversa, **não aqui**. Enquanto
isso não for feito, o bloco 9 está no ar sem estar em uso.

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

## O primeiro run do robô novo, medido (05/09/2026)

A pergunta que o bloco 6 existia para responder tem resposta:

| medição | resultado |
|---|---|
| agendado para | 15:17 UTC |
| disparou às | 17:20:54 UTC — **2h04 de atraso** |
| hora de Brasília lida pelo robô | 14h |
| slot que ele abriu | `dia_12h` (12 ≤ 14 < 18) |
| pessoas percorridas | 2 |
| enviados | 0 — nada a dizer, tudo pago |

**O minuto torto não resolveu a pontualidade** — de 3h35–4h15 caiu para 2h04, e
continua na casa das horas. **O que resolveu foi decidir pelo relógio de
Brasília em vez da hora do gatilho:** o slot do meio-dia ainda estava aberto às
14h, então o atraso foi absorvido em vez de virar aviso perdido. Se o conserto
tivesse sido só mudar o minuto do cron, o aviso de hoje teria se perdido.

`pessoas: 2` é o laço por pessoa do bloco 7 rodando em produção pela primeira
vez, lendo as colunas novas do perfil sem erro.

## PRÓXIMA AÇÃO EXATA

1. **Conferir no Actions a que horas os runs de hoje dispararam** e se o aviso
   chegou perto do meio-dia. É a medição que decide se o GitHub serve ou se a
   conversa do `pg_cron` volta. Primeira execução do cron novo: 15:17 UTC.
2. ~~Rodar `sql/08` e mesclar o bloco 7.~~ **Feito.** ~~E o `sql/09` do bloco
   9.~~ **Feito.**
3. **A segunda pessoa da casa entra no app** e liga os avisos no iPhone dela.
   Sem isso o bloco 7 não tem para onde mandar as 20h.
4. **Realtime com dois aparelhos** — a última coisa da fase 1 sem prova.
5. Rodar `sql/04_prova_rls.sql` depois das migrações de 05/09.
6. Depois: bloco 9 (parcelas), bloco 8 (código colado).
