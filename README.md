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
│   └── 03_seed_ficticio.sql   dados de mentira, opcional, só para ver a tela
├── icones/                    ícones do PWA
├── index.html                 (fase 1, ainda não escrito)
├── app.css                    (fase 1, ainda não escrito)
├── app.js                     (fase 1, ainda não escrito)
├── config.js                  (fase 1) URL do projeto + anon key
├── manifest.webmanifest       (fase 1)
└── sw.js                      (fase 1) service worker mínimo
```

## Modelo de dados

**casa** — `id`, `nome`

**perfil** — `id` (= `auth.uid()`), `casa_id`, `nome`

**lancamento** — `id`, `casa_id`, `modelo_id` (sempre nulo na fase 1),
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
mandar só `pago = true` e o selo de autoria não poder ser forjado.

## Segurança

- RLS ligado e forçado nas três tabelas, isolando por `casa_id`.
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
conta avulsa; navegar entre meses; PWA instalável.

**Fase 2** — Web Push com VAPID, bot do Telegram como redundância, GitHub
Actions com cron diário, offline com IndexedDB e fila de pendências.

**Fase 3** — modelos recorrentes e geração automática do mês, parcelas,
gráficos, importação de histórico, receitas.

Fora da fase 1 nada disso é implementado nem preparado.
