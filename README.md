# Nossas Contas

PWA de controle de contas domésticas, compartilhado entre duas pessoas da mesma
casa. Substitui a lista que hoje vive num app de notas.

O critério de sucesso é simples: **se ficar mais lento ou mais burocrático que a
nota, a nota ganha.** Abrir já no mês corrente, marcar pago com um toque, ler no
carro sem apertar os olhos, funcionar com o polegar de uma mão só.

## Stack

| Camada | Escolha |
|---|---|
| Interface | HTML + CSS + JavaScript puro. Sem framework, sem build, sem npm. |
| Robô do aviso diário | Node no GitHub Actions, com `npm ci` e `package-lock.json` (só em `avisos/`, nunca no frontend) |
| Banco, sync e login | Supabase (Postgres + Realtime + Auth), free tier |
| Hospedagem | GitHub Pages, repositório público `contas-casa` |

## Estrutura

```
CONTAS_CASA/
├── README.md                  este arquivo
├── ESTADO.md                  estado atual, histórico, roadmap e próximo passo
├── .gitignore
├── .nojekyll                  desliga o Jekyll no GitHub Pages
├── sql/
│   ├── 01_schema_rls.sql      schema + RLS (rodar uma vez)
│   ├── 02_config_inicial.sql  modelo: cria a casa e os dois perfis
│   ├── 03_seed_ficticio.sql   dados de mentira, opcional, só para ver a tela
│   ├── 04_prova_rls.sql       prova a RLS fingindo ser um usuário autenticado
│   ├── 05_modelos.sql         contas fixas + gerar_mes() + fixar_mes()
│   ├── 06_push.sql            inscrições de aviso + resumo_do_dia()
│   ├── 07_avisos.sql          memória de aviso enviado (um por dia e por slot)
│   ├── 08_avisos_por_pessoa.sql  preferência de aviso por pessoa + véspera
│   ├── 09_parcelas.sql        contas que acabam: 12 vezes a partir de tal mês
│   ├── 10_codigo_pagamento.sql  código de barras e PIX guardados no lançamento
│   ├── 11_geracao_automatica.sql  mes_gerado + garantir_mes(): o mês nasce sozinho
│   └── 11_prova_geracao.sql   prova do bloco 11 (trava, índice, RLS, backfill)
├── icones/                    ícones do PWA (gerados, 4 PNGs)
├── avisos/                    envio do resumo diário (roda só no Actions)
│                              package.json + package-lock.json, instalado com npm ci
├── .github/workflows/         cron diário do aviso, teste do push e a bancada
├── testes/                    bancada: roda app.js e sw.js reais no jsc ou no node
├── vendor/supabase.js         supabase-js 2.97.0 (UMD), versionado de propósito
├── index.html
├── app.css
├── app.js
├── config.js                  URL, anon key e chave pública VAPID
├── manifest.webmanifest
└── sw.js                      service worker: casca, fetch e push
```

## Contas fixas

Para não redigitar a lista toda no dia 1º. Cada conta fixa guarda descrição,
dia e um valor padrão — e **valor padrão vazio continua vazio todo mês**, que é
o caso da conta de mercado, cujo valor só se sabe depois.

O botão "Transformar as contas do mês em fixas" cria as fixas de uma vez a
partir do mês que está na tela. Depois é só desligar as que não se repetem.

**O mês corrente nasce sozinho.** Ao abrir o app, o banco confere se aquela
competência já foi inicializada nesta casa e, se não foi, traz as contas fixas
— uma vez, e só do mês corrente, decidido pelo relógio de São Paulo no próprio
banco. **Navegar entre meses é leitura**: voltar para janeiro não cria janeiro.

**O botão continua.** Ele mudou de papel: automático é *o mês nasce*; o botão
"Trazer N contas fixas" é *traga o que falta*, para a conta fixa cadastrada
depois que o mês já nasceu. Aparece sozinho quando há o que trazer.

**Apagar vale.** Uma conta apagada não volta ao reabrir o app, ao voltar do
segundo plano nem ao navegar até o mês. Só volta se você tocar no botão — que é
o pedido explícito de trazê-la de volta.

Gerar o mês duas vezes não duplica nada: a comparação é por descrição, então
conta já digitada na mão também não vem repetida. E um modelo produz no máximo
uma conta por mês, garantido por índice único no banco.

**Conta que acaba.** Acordo parcelado, parcela de imposto, material escolar —
o que vem doze vezes e para. Toque na linha "todo dia 8" de uma conta fixa e
diga quantas vezes e o mês da primeira — no mês dá para digitar só os números,
`092026` vira 09/2026; a partir daí ela vem sozinha enquanto
vale, mostra "5/12" na tela do mês, e **para de ser oferecida quando a última
passou**. Deixar os dois campos vazios é o normal: conta que se repete para
sempre.

O contador mora em coluna própria, não na descrição — descrição que muda todo
mês faria a mesma conta entrar de novo toda vez, porque é por descrição que o
banco compara.

## Código de pagamento

Cada conta guarda o código de barras ou o PIX copia-e-cola. Um toque em
**"copiar código"** na linha devolve ele para a área de transferência na hora
de pagar; **segurar** abre para trocar ou tirar.

O app **lê o código sem chamar ninguém**: os 47 dígitos do boleto carregam o
valor e o fator de vencimento, os 48 da conta de consumo carregam o valor, e o
PIX é um BR Code com CRC. Então, ao colar, ele confere os dígitos verificadores
e diz o que entendeu — *"Boleto · R$ 212,30 · vence 10/09"* — antes de guardar.
**Se a conta ainda estava sem valor, o valor vem do código**: é o fim do "???"
no gesto de colar. Se você já tinha digitado um valor, o seu manda.

Código que não fecha os dígitos é recusado. Aqui recusar é o certo: dígito
verificador é garantia de quem emitiu, e código truncado é pior do que nenhum,
porque na hora de pagar você confiaria nele.

O que **não** existe, e não vai existir: buscar boletos pelo seu CPF. Isso é o
DDA, operado pela Nuclea, e o acesso é de instituição financeira. O único
caminho seria entregar credencial de banco a um intermediário, o que inverteria
o modelo de risco deste projeto inteiro.

Uma conta fixa pode guardar um **PIX estático** — chave sem valor, que não muda
de mês. Esse o "Trazer contas fixas" copia sozinho para o mês novo. A linha
digitável do boleto não: ela muda todo mês, porque carrega vencimento e valor.

## Como se usa

Um toque em qualquer ponto da linha **marca ou desmarca pago**, sem confirmação
— o toque de volta desfaz. Um toque no valor **edita o valor**. Segurar o dedo
na linha **apaga a conta**, e esse pede confirmação, porque apagar não se
desfaz. O `+` adiciona uma conta avulsa ao mês que está na tela. Tocar no nome
do mês volta para o mês corrente.

No rodapé, **"Avisar neste aparelho"** liga as notificações, e os três
interruptores logo abaixo dizem quais avisos você quer receber. Toque liga e
desliga cada um.

Na tela de login há **"Esqueci a senha"**, com retorno para o próprio app.
Quem já está dentro encontra **"trocar senha"** no rodapé — importante no
iPhone, porque o app instalado não enxerga a sessão do Safari.

## Testes

```
./testes/rodar.sh
```

Roda o `app.js` e o `sw.js` **reais** dentro do `jsc` (que já vem no macOS) ou,
onde não há `jsc`, dentro do `node`, com DOM, relógio e Supabase falsos. Tem que
fechar em 170 / 4 / 27 / 49 medidas e zero falhas — e o próprio `rodar.sh` sai
com erro quando não fecha. O CI roda a mesma bancada a cada push, em workflow
separado do Web Push, sem tocar no banco e sem Secret nenhum.

## Modelo de dados

**casa** — `id`, `nome`

**perfil** — `id` (= `auth.uid()`), `casa_id`, `nome`,
`avisa_vespera_20h`, `avisa_dia_12h`, `avisa_dia_20h` (preferências de aviso
por pessoa, todas `default true`).

**mes_gerado** — `casa_id`, `competencia`, `gerado_em`, `origem`
(`'automatico'` ou `'backfill'`), chave primária `(casa_id, competencia)`. Uma
linha quer dizer "esta competência desta casa já foi inicializada". É a trava
que resolve dois aparelhos abrindo o app ao mesmo tempo, e é o que torna
durável apagar uma conta. Sem UPDATE e sem DELETE, de propósito.

**lancamento** — `id`, `casa_id`, `modelo_id` (nulo em conta digitada na mão;
preenchido no que veio das contas fixas), `competencia` (date, sempre dia 1 do
mês), `descricao`, `dia_vencimento` (int), `vencimento` (date),
`valor_previsto` (numeric, anulável), `valor_pago` (numeric, anulável),
`pago` (bool), `pago_em`, `pago_por`, `observacao`, `parcela_n`, `parcela_de`,
`codigo_pagamento`, `codigo_tipo`, `criado_em`, `atualizado_em`.

**modelo** — `id`, `casa_id`, `descricao`, `dia_vencimento`, `valor_padrao`
(anulável), `ativo`, `parcelas_total`, `parcela_1`, `pix_estatico`,
`criado_em`, `atualizado_em`.

**push_inscricao** — `id`, `casa_id`, `perfil_id`, `endpoint`, `p256dh`,
`auth`, `aparelho`, `criado_em`, `ultimo_envio`, `falhas`, `ultimo_erro`.

**aviso_enviado** — `id`, `casa_id`, `perfil_id` (nulo no aviso antigo da casa
inteira), `dia`, `slot`, `enviado_em`; não é lido nem escrito pelo app, só
pelo robô com a chave de serviço.

Detalhe que manda no desenho da tela: **`valor_previsto` nulo é a conta cujo
valor ainda não se sabe** — o "???" da nota. Ela aparece como campo a preencher
e entra num total separado, "em aberto", em vez de contar como zero.

Três coisas o banco decide sozinho, e o cliente nunca escreve:
`vencimento` (dia pedido, limitado ao último dia do mês — dia 31 em fevereiro
não estoura), `pago_em` e `pago_por` (preenchidos por trigger quando `pago`
vira verdadeiro, apagados quando volta a falso). É isso que faz o toque único
mandar só `pago = true` e o selo de autoria não poder ser forjado — nem no
`update`, nem no `insert`, que até a fase 0 aceitava autor e hora vindos do
cliente.

## Segurança

- RLS ligado e forçado nas tabelas de dados da casa (`casa`, `perfil`,
  `lancamento`, `modelo`, `push_inscricao`, `aviso_enviado`), isolando por
  `casa_id` — e por pessoa, no caso das inscrições e das preferências de aviso.
- No frontend só a `anon key`, que é pública por desenho — quem protege os
  dados é a RLS, não o segredo da chave.
- `service_role key` e chave privada VAPID ficam só em GitHub Secrets. Nunca no
  repositório.
- **Nenhum dado financeiro real entra neste repositório.** Nem valor, nem nome
  de credor, nem nome de familiar, nem print. Todo seed e todo exemplo usa dado
  fictício.

## Estado atual

Os blocos **1 a 10** estão concluídos e no ar. O bloco **11** está
implementado e medido, mas **ainda não no ar**: depende de aplicar
`sql/11_geracao_automatica.sql` no banco antes do merge. A bancada fecha em
`170 / 4 / 27 / 49` e o CI roda a mesma bancada a cada push.

- Bloco **8** (código de pagamento), **9** (parcelas) e **10** (troca e
  recuperação de senha) estão implementados e no ar.
- **Realtime entre dois aparelhos** foi validado manualmente: a mudança feita
  num aparelho aparece no outro praticamente imediatamente. A bancada cobre o
  lado local; a validação manual cobre a travessia da rede.
- **Telegram** e **offline com IndexedDB** foram removidos do roadmap e não
  voltam.

## Roadmap

Os próximos blocos são, nesta ordem:

```text
13 → 14 → 12
```

| bloco | entrega | observação |
|---|---|---|
| ~~**11**~~ | ~~geração automática do mês~~ | feito em 06/09; falta aplicar o `sql/11` e mesclar |
| **13** | histórico | listar meses, previsto, pago, a pagar e número de contas |
| **14** | receitas | nova tabela `receita`, separada de `lancamento` |
| **12** | gráficos | só depois de histórico e receitas estabilizados |

As decisões de desenho de “Parcelar” direto no lançamento e da UX do código de
pagamento estão registradas em `ESTADO.md`, nas seções **ESTADO ATUAL** e
**ROADMAP**.

## Fases

Três estados diferentes, e a diferença importa: **escrito** é código no
repositório; **medido** é a bancada ou a prova de RLS dizendo que funciona;
**validado** é alguém tendo usado aquilo num aparelho de verdade. O `ESTADO.md`
tem o quadro item por item.

**Fase 1 — escrita e medida; validação item a item no `ESTADO.md`.** Estrutura e SQL; login por e-mail e
senha; tela do mês agrupada por dia de vencimento; toque único marca e desmarca
pago; selo "pago por fulano, 14:32"; cabeçalho fixo com previsto / pago / a
pagar e a contagem de itens em aberto sem valor; editar valor; adicionar conta
avulsa; apagar conta segurando o dedo; navegar entre meses; PWA instalável;
contas fixas com geração do mês (que era da fase 3 e veio para cá, porque sem
ela o app perdia do app de notas no dia 1º).

O **sync em tempo real entre dois aparelhos** está implementado, medido na
bancada e validado manualmente em produção. O mecanismo é
`postgres_changes` filtrado por `casa_id`, reaplicado pelo `aplicarDeFora()`.

**Fase 2 — escrita, medida e validada.** Web Push com VAPID e cron diário no
GitHub Actions. O Secret está posto, o cron roda todo dia e **a notificação
chega no iPhone** (último envio registrado: 03/09/2026). Dia sem conta vencendo
e sem atraso não gera aviso — e é isso que explica um dia de silêncio no meio.

**O cron do GitHub atrasa horas, não minutos.** Medido neste repositório em
quatro execuções seguidas: agendado para 11:00 UTC (08:00 de Brasília),
disparou às 14:35, 14:44, 14:45 e 15:15 UTC — de 3h35 a 4h15 de atraso. A
saída, no bloco 6, foi parar de confiar no horário do cron: ele roda de hora em
hora, em minuto torto, e quem decide o que mandar é o relógio de Brasília
dentro do `enviar.mjs`. Cada aviso tem hora para abrir e hora para deixar de
fazer sentido — conta que vence hoje não chega de madrugada —, e a tabela
`aviso_enviado` garante um aviso por casa, por dia e por slot, mesmo com o robô
rodando doze vezes.

São **até três avisos por dia, e só quando há o que dizer**:

| quando | o que diz |
|---|---|
| véspera, 20h | "2 contas vencem amanhã — deixe o pagamento pronto" |
| no dia, meio-dia | "3 contas vencem hoje — R$ …" |
| no dia, 20h | o que sobrou por pagar, mais as atrasadas |

Dia sem conta vencendo e sem atraso não gera notificação nenhuma, e conta já
paga não pinga de novo. Notificação que chega todo dia sem motivo é notificação
que a pessoa aprende a ignorar — e é justamente por isso que **cada pessoa
escolhe quais dos três quer**, nos três interruptores embaixo do botão de
avisos. A escolha é da pessoa, não do aparelho: desligar num aparelho desliga
em todos os dela.

**Fase 0 — auditoria e estabilização, feita depois das outras duas.** Bancada
que sabe ficar vermelha e roda no CI, `npm ci` com lockfile, quatro furos de
RLS e de permissão fechados no SQL. Sem funcionalidade nova. Os consertos de
SQL foram reaplicados no banco em 05/09/2026; o detalhe está no `ESTADO.md`.

**Blocos 8, 9 e 10 — concluídos depois da fase 0.** O bloco 9 tirou o buraco
das parcelas; o bloco 8 pôs o código de pagamento no lançamento; o bloco 10
devolveu ao usuário a capacidade de trocar a senha e recuperar o acesso.
Continuam pendentes os blocos do roadmap acima.
