# ESTADO — Nossas Contas

Atualizado em 31/08/2026 — fim do bloco 4: contas fixas. NO AR.

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

## O que falta na fase 1

Nada de frontend foi escrito ainda. Falta, na ordem:

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

Única dependência de terceiros: **@supabase/supabase-js 2.112.4**, build UMD,
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
em volta falsificado. Placar: **55 / 4 / 11 medidas, 0 falhas.**

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

## PRÓXIMA AÇÃO EXATA

Jonathan, no iPhone:
1. Abrir setembro (seta ›). Conferir os 21 lançamentos.
2. Rodapé > "contas fixas" > "Transformar as contas do mês em fixas".
3. **Desligar** as cinco parcelas/one-offs (ver o buraco conhecido acima).
4. Ir para outubro e tocar em "Trazer N contas fixas". Tem que aparecer a lista
   inteira, com "Dom mercado" ainda em "???".

Depois disso, decidir entre parcelas (fase 3) e push (fase 2).
