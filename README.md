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
├── ESTADO.md                  onde o trabalho parou e qual é a próxima ação
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
│   └── 08_avisos_por_pessoa.sql  preferência de aviso por pessoa + véspera
├── icones/                    ícones do PWA (gerados, 4 PNGs)
├── avisos/                    envio do resumo diário (roda só no Actions)
│                              package.json + package-lock.json, instalado com npm ci
├── .github/workflows/         cron diário do aviso, teste do push e a bancada
├── testes/                    bancada: roda app.js e sw.js reais no jsc ou no node
├── vendor/supabase.js         supabase-js 2.97.0 (UMD), versionado de propósito
├── index.html
├── app.css
├── app.js
├── config.js                  URL do projeto + anon key
├── manifest.webmanifest
└── sw.js                      service worker mínimo
```

## Contas fixas

Para não redigitar a lista toda no dia 1º. Cada conta fixa guarda descrição,
dia e um valor padrão — e **valor padrão vazio continua vazio todo mês**, que é
o caso da conta de mercado, cujo valor só se sabe depois.

O botão "Transformar as contas do mês em fixas" cria as fixas de uma vez a
partir do mês que está na tela. Depois é só desligar as que não se repetem.
Num mês onde falta alguma fixa, a tela do mês mostra "Trazer N contas fixas".

Gerar o mês duas vezes não duplica nada: a comparação é por descrição, então
conta já digitada na mão também não vem repetida.

## Como se usa

Um toque em qualquer ponto da linha **marca ou desmarca pago**, sem confirmação
— o toque de volta desfaz. Um toque no valor **edita o valor**. Segurar o dedo
na linha **apaga a conta**, e esse pede confirmação, porque apagar não se
desfaz. O `+` adiciona uma conta avulsa ao mês que está na tela. Tocar no nome
do mês volta para o mês corrente.

No rodapé, **"Avisar neste aparelho"** liga as notificações, e os três
interruptores logo abaixo dizem quais avisos você quer receber. Toque liga e
desliga cada um.

## Testes

```
./testes/rodar.sh
```

Roda o `app.js` e o `sw.js` **reais** dentro do `jsc` (que já vem no macOS) ou,
onde não há `jsc`, dentro do `node`, com DOM, relógio e Supabase falsos. Tem que
fechar em 91 / 4 / 23 / 40 medidas e zero falhas — e o próprio `rodar.sh` sai
com erro quando não fecha. O CI roda a mesma bancada a cada push, em workflow
separado do Web Push, sem tocar no banco e sem Secret nenhum.

## Modelo de dados

**casa** — `id`, `nome`

**perfil** — `id` (= `auth.uid()`), `casa_id`, `nome`

**lancamento** — `id`, `casa_id`, `modelo_id` (nulo em conta digitada na mão;
preenchido no que veio das contas fixas),
`competencia` (date, sempre dia 1 do mês), `descricao`, `dia_vencimento` (int),
`vencimento` (date), `valor_previsto` (numeric, anulável), `valor_pago`
(numeric, anulável), `pago` (bool), `pago_em`, `pago_por`, `observacao`,
`criado_em`, `atualizado_em`.

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

- RLS ligado e forçado nas cinco tabelas (`casa`, `perfil`, `lancamento`,
  `modelo`, `push_inscricao`), isolando por `casa_id` — e por pessoa, no caso
  das inscrições de aviso.
- No frontend só a `anon key`, que é pública por desenho — quem protege os
  dados é a RLS, não o segredo da chave.
- `service_role key`, chave privada VAPID e token do Telegram: só em GitHub
  Secrets. Nunca no repositório.
- **Nenhum dado financeiro real entra neste repositório.** Nem valor, nem nome
  de credor, nem nome de familiar, nem print. Todo seed e todo exemplo usa dado
  fictício.

## Fases

Três estados diferentes, e a diferença importa: **escrito** é código no
repositório; **medido** é a bancada ou a prova de RLS dizendo que funciona;
**validado** é alguém tendo usado aquilo num aparelho de verdade. O `ESTADO.md`
tem o quadro item por item.

**Fase 1 — escrita, medida e validada.** Estrutura e SQL; login por e-mail e
senha; tela do mês agrupada por dia de vencimento; toque único marca e desmarca
pago; selo "pago por fulano, 14:32"; cabeçalho fixo com previsto / pago / a
pagar e a contagem de itens em aberto sem valor; editar valor; adicionar conta
avulsa; apagar conta segurando o dedo; navegar entre meses; PWA instalável;
contas fixas com geração do mês (que era da fase 3 e veio para cá, porque sem
ela o app perdia do app de notas no dia 1º).

Uma coisa da fase 1 continua **sem validação**: o **sync em tempo real entre
dois aparelhos**. A bancada prova que o app reage ao evento; ninguém provou
ainda que o evento atravessa a rede.

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

Continuam por fazer o bot do Telegram, como redundância, e o offline com
IndexedDB.

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

Os três avisos e a escolha por pessoa são do bloco 7, e **ainda não foram
vistos chegar num aparelho** — o que já foi validado em produção é o aviso
único.

**Fase 0 — auditoria e estabilização, feita depois das outras duas.** Bancada
que sabe ficar vermelha e roda no CI, `npm ci` com lockfile, quatro furos de
RLS e de permissão fechados no SQL. Sem funcionalidade nova. Os consertos de
SQL só valem no banco depois de rodar os arquivos de novo — está no `ESTADO.md`.

**Fase 3 — nada começado, nada preparado de véspera.** Parcelas (hoje o buraco
conhecido: cinco contas não são mensais para sempre e voltam todo mês),
geração automática do mês sem apertar botão, gráficos, importação de histórico,
receitas.
