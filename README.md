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
│   ├── 05_modelos.sql         contas fixas + gerar_mes() + fixar_mes()
│   ├── 06_push.sql            inscrições de aviso + resumo_do_dia()
│   ├── 02_config_inicial.sql  modelo: cria a casa e os dois perfis
│   ├── 03_seed_ficticio.sql   dados de mentira, opcional, só para ver a tela
│   └── 04_prova_rls.sql       prova a RLS fingindo ser um usuário autenticado
├── icones/                    ícones do PWA (gerados, 4 PNGs)
├── avisos/                    envio do resumo diário (roda só no Actions)
│                              package.json + package-lock.json, instalado com npm ci
├── .github/workflows/         cron diário do aviso, teste do push e a bancada
├── testes/                    bancada: roda app.js e sw.js reais no jsc ou no node
├── vendor/supabase.js         supabase-js 2.112.4 (UMD), versionado de propósito
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

## Testes

```
./testes/rodar.sh
```

Roda o `app.js` e o `sw.js` **reais** dentro do `jsc` (que já vem no macOS) ou,
onde não há `jsc`, dentro do `node`, com DOM, relógio e Supabase falsos. Tem que
fechar em 81 / 4 / 23 / 11 medidas e zero falhas — e o próprio `rodar.sh` sai
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

**Fase 1 (esta)** — estrutura e SQL; login por e-mail e senha; tela do mês
agrupada por dia de vencimento; toque único marca e desmarca pago; sync em
tempo real; selo "pago por fulano, 14:32"; cabeçalho fixo com previsto / pago /
a pagar e a contagem de itens em aberto sem valor; editar valor; adicionar
conta avulsa; apagar conta segurando o dedo; navegar entre meses; PWA
instalável; contas fixas com geração do mês.

**Fase 2** — Web Push com VAPID e cron diário no GitHub Actions: **escrito e
medido na bancada, ainda não validado em produção** — nenhuma notificação
chegou a nenhum aparelho até agora, e falta o Secret `SUPABASE_SERVICE_ROLE`.
O `ESTADO.md` separa, item por item, o que está implementado, o que está
testado e o que já foi validado no aparelho. Falta o bot do Telegram como
redundância e o offline com IndexedDB.

O aviso é **um por dia, e só quando há o que dizer**: dia sem conta vencendo e
sem atraso não gera notificação nenhuma. Notificação que chega todo dia sem
motivo é notificação que a pessoa aprende a ignorar.

**Fase 3** — modelos recorrentes e geração automática do mês, parcelas,
gráficos, importação de histórico, receitas.

Fora da fase 1 nada disso é implementado nem preparado.
