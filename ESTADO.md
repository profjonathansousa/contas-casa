# ESTADO — Nossas Contas

Atualizado em 07/09/2026 — blocos 11 e 13 em produção; blocos 14 e 15
implementados, aplicados e provados no banco. Blocos 1 a 15 concluídos.

## ESTADO ATUAL

### O que está de pé

- Blocos **1 a 15** concluídos.
- Bloco **11** (o mês corrente nasce sozinho ao abrir o app) **no ar**:
  `sql/11_geracao_automatica.sql` aplicado em 06/09/2026, provado em produção,
  e o app mesclado depois disso.
- Bloco **13** (histórico) **em produção**: `sql/13_historico.sql` aplicado e
  `sql/13_prova_historico.sql` aprovado em 07/09/2026.
- Bloco **14** (receitas) **implementado e provado no banco**:
  `sql/14_receitas.sql` aplicado e `sql/14_prova_receitas.sql` aprovado em
  07/09/2026. Ainda não validado num aparelho.
- Bloco **15** (histórico legado) **implementado e provado no banco**:
  `sql/15_historico_legado.sql` aplicado, `sql/15_prova_historico_legado.sql`
  aprovado e o histórico real importado em tabelas próprias.
- Bancada verde em **230 / 4 / 27 / 49** com **0 falhas**; o `rodar.sh`
  confere o placar e
  derruba o CI se alguma medida falhar, se o motor morrer ou se o número mudar
  sem atualização explícita.
- **Realtime validado manualmente entre dois aparelhos.** A bancada cobre o
  lado local (`aplicarDeFora()`); a validação manual cobre a travessia da rede
  via Supabase Realtime filtrado por `casa_id`.
- Bloco **8** (código de pagamento), bloco **9** (parcelas) e bloco **10**
  (troca e recuperação de senha) estão implementados e no ar.
- **Telegram** e **offline com IndexedDB** foram removidos do roadmap e não
  voltam.

### Quadro de implementado, testado e validado

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
| **Realtime entre dois aparelhos** | sim | sim (o lado do app reage a evento fabricado) | **sim — validado manualmente entre dois aparelhos** |
| **Web Push: inscrever o aparelho** | sim | não (não dá para medir fora do navegador) | sim: 1 inscrição no banco |
| **Web Push: enviar de verdade** | sim | só o texto do aviso (11 medidas) | **sim — chegou no iPhone; último envio 03/09/2026** |
| **cron diário do aviso** | sim | não | sim, roda todo dia — mas **atrasava de 3h35 a 4h15** |
| **slots de aviso por hora de Brasília** | sim (bloco 6) | sim | sim — na `main` desde 05/09, com `sql/07` no banco |
| **três avisos, um por pessoa** | sim (bloco 7) | sim | parcialmente: **os interruptores apareceram no iPhone** (05/09); os avisos em si ainda não chegaram |
| **contas que acabam (parcelas)** | sim (bloco 9) | sim | **sim — confirmado por Jonathan em 05/09; 3 contas fixas já parceladas no banco** |
| **código de barras / PIX colado** | sim (bloco 8) | sim (140/4/24/49) | **não — no ar, mas nenhum código colado ainda** |
| **o mês corrente nasce sozinho** | sim (bloco 11) | sim (bancada 170/4/27/49 com dois controles negativos + réplica local, inclusive concorrência com duas sessões) | **parcialmente — `sql/11` aplicado e provado em produção em 06/09; falta um aparelho de verdade abrir o app num mês novo** |
| **histórico derivado** | sim (bloco 13) | sim (bancada + prova SQL) | **sim — aplicado, provado no banco e publicado no Pages** |
| **receitas** | sim (bloco 14) | sim (bancada + prova SQL do 14) | **não — aplicado e provado no banco; nenhuma receita real lançada ainda** |
| **histórico legado** | sim (bloco 15) | sim (bancada + prova SQL do 15) | **sim — aplicado, provado e importado no banco; UI integrada** |
| **trocar e recuperar a senha** | sim (bloco 10) | sim (os controles estão no placar atual) | **não — ainda não exercitado num aparelho depois do bloco 10** |
| segundo morador (a esposa) | — | — | **não: nunca entrou** |

### Validações manuais ainda pendentes

1. **Primeiro código de pagamento colado** e conferido num aparelho.
2. **Login da segunda pessoa da casa** e inscrição do aparelho dela nos avisos.
3. **Aviso de véspera / por pessoa** chegando de verdade num aparelho, além do
   aviso único já validado.
4. **Lançar a primeira receita real** num aparelho e conferir que ela aparece
   separada das despesas.
5. **Conferir a visualização do histórico legado** num aparelho, depois do push
   desta implementação.

O **Realtime entre dois aparelhos** já está validado manualmente; não é uma
pendência, mas deve ser revalidado em qualquer mudança futura que toque no
`postgres_changes` ou no redesenho da tela.

### Decisões registradas nesta auditoria

Esta seção preserva as decisões de desenho. Os itens marcados como
**IMPLEMENTADO** são estado atual; os demais continuam pendentes de auditoria
ou implementação.

**Bloco 11 — geração automática do mês — IMPLEMENTADO**

As sete questões levantadas aqui foram respondidas antes de qualquer linha de
código, e a seção **Bloco 11** no fim deste arquivo registra o desenho e o
porquê de cada resposta. Em resumo:

- **Concorrência**: a chave primária de `mes_gerado (casa_id, competencia)`.
- **Idempotência**: em três camadas — o `NOT EXISTS` por descrição, o índice
  único `(casa_id, competencia, modelo_id)` e a marca do mês.
- **Constraint e `ON CONFLICT`**: sim aos dois, com **alvo nomeado**, e a
  constraint é invariante de integridade, não a trava da automação.
- **Mês parcialmente preenchido**: `gerar_mes()` traz só o que falta, como
  sempre trouxe; nada muda aí.
- **Lançamentos existentes**: nunca tocados — a função só faz INSERT.
- **Momento da chamada**: ao abrir o app, e ao voltar do segundo plano se o mês
  virou. **Nunca ao navegar entre meses**: navegar é leitura.
- **Remoção do botão**: **não**. Ele passa a ter outro papel — trazer a conta
  fixa cadastrada depois que o mês já nasceu.

**Bloco 13 — histórico**

- Implementado e em produção. `public.historico()` é `security invoker`, sem
  `casa_id`, agrupa `lancamento` por `competencia` e devolve `previsto`,
  `pago`, `a_pagar`, `contas` e `sem_valor`.
- A tela lista os meses da competência mais recente para a mais antiga e
  reusa a tela mensal ao tocar.
- Não existe tabela `historico` nem snapshot.

**Bloco 14 — receitas — IMPLEMENTADO**

- `public.receita` é tabela separada, com `competencia` sempre dia 1, `valor`
  obrigatório e não negativo, `recebido`, `recebido_em`, `recebido_por`,
  `observacao`, `criado_em` e `atualizado_em`.
- RLS ligada e forçada por `casa_id`; `anon` sem acesso; `authenticated` com
  CRUD.
- `public.tg_receita()` segue o padrão de `tg_lancamento()`: normaliza a
  competência, controla timestamps e grava/limpa `recebido_em` e `recebido_por`.
- Realtime com `replica identity full` e `public.receita` na publicação
  `supabase_realtime`.
- `public.receitas_mensais()` é `security invoker`, sem parâmetros, e devolve
  `competencia`, `total`, `recebido`, `a_receber` e `contas`.
- Na tela, receitas aparecem numa seção própria do mês, separada das despesas;
  o canal Realtime continua único, agora com duas assinaturas
  (`lancamento` e `receita`).
- `public.historico()` continua exclusivamente despesas. Não existe tabela
  `historico` nem snapshot.

**Bloco 15 — histórico legado — IMPLEMENTADO**

- O histórico antigo foi importado em três tabelas próprias:
  `public.historico_legado`, `public.historico_legado_receita` e
  `public.historico_legado_resumo`.
- As três tabelas são somente leitura para o app e têm RLS por `casa_id`.
- A importação é feita por `privado.importar_historico_legado(uuid, text, jsonb)`,
  agora com `lote_id` e sem EXECUTE para `anon`/`authenticated`. A tabela
  `historico_legado_lote` e o índice `(casa_id, lote_id, ordem_original)`
  impedem que o mesmo lote seja duplicado.
- Histórico legado não vira `modelo`, não entra em `lancamento` e não participa
  da geração automática.
- Na tela, o histórico legado aparece numa seção própria do mês, abaixo das
  receitas, sem alterar totais correntes.
- `outubro/26` foi preservado na ordem original do arquivo; a posição incomum
  não foi reinterpretada.

**Bloco 12 — gráficos**

- Só implementar depois de 13 e 14, para não refazer agregação.
- Para “despesas por categoria” será necessário um campo formal de categoria
  em `lancamento` (e provavelmente em `receita`); **sem classificação
  automática por IA**.
- Usar SVG/CSS nativo ou uma pequena camada desenhada à mão, sem framework de
  gráfico no frontend.

**“Parcelar” direto no lançamento**

- **Ainda NÃO implementado.** Registrado como decisão/questão de produto para
  auditoria antes da implementação.
- Reusar `modelo`, sem criar entidade de “série”.
- Ação nova na linha do lançamento: `Parcelar`.
- No primeiro uso, criar ou ativar um `modelo` correspondente por descrição
  normalizada; preencher `parcelas_total` e `parcela_1`; vincular o lançamento
  atual (`modelo_id`) e preencher `parcela_n` / `parcela_de`; `gerar_mes()`
  continua cuidando dos próximos meses.
- Preferência de implementação: função RPC `parcelar_lancamento(...)` em SQL,
  `security invoker`, para que a criação/ativação do modelo e a atualização do
  lançamento sejam atômicas sob RLS. O cliente passa `lancamento_id`,
  `parcelas_total` e `parcela_1`; `parcela_1` vem preenchida com a competência
  do lançamento atual, mas permanece editável.
- Se o lançamento tiver PIX estático, copiar para `modelo.pix_estatico`; não
  copiar boleto/arrecadação nem PIX dinâmico.

**UX do código de pagamento**

- **Ainda NÃO implementado no código atual.** É melhoria pendente.
- O rótulo do botão passa a depender do `codigo_tipo`:
  `PIX → copiar código PIX`, `boleto → copiar código do boleto`,
  `arrecadacao → copiar código da conta`.
- `alterar` e `remover` ficam visíveis, não apenas no toque longo. O toque
  longo pode continuar como atalho.
- `alterar` abre a mesma folha de código já existente, preenchida; `remover`
  limpa o código. Sem confirmação extra, mantendo o mesmo custo de um toque do
  restante do app.

## ROADMAP

```text
14 → 15 → 12
```

| bloco | entrega |
|---|---|
| **14** | receitas em tabela separada `receita` — concluído |
| **15** | histórico legado em tabelas próprias — concluído |
| **12** | gráficos — próximo bloco, sobre o modelo financeiro estabilizado |

Gráficos ficam por último de propósito: devem ser construídos sobre um modelo
financeiro já estável, com histórico e receitas definidos, para não nascerem
sobre agregações que depois mudam.

## PRÓXIMO PASSO

1. **Abrir o app num aparelho** e confirmar que a tela do mês aparece normal.
   Em 06/09 o mês corrente já estava marcado pelo backfill, então a primeira
   geração automática de verdade só acontece em **01/10**: é nela que o bloco 11
   se prova sozinho.
2. **Colar o primeiro código de pagamento** e conferir que o valor vem
   sozinho — pendência do bloco 8.
3. **A segunda pessoa da casa entra no app** e liga os avisos no aparelho
   dela — pré-requisito humano dos avisos por pessoa.
4. **Manter a validação manual de Realtime** a cada mudança que tocar na tela
   ou no mecanismo de `postgres_changes`.
5. **Auditar o Bloco 15** antes de abrir o Bloco 12.
6. Depois das pendências humanas e da auditoria do Bloco 15, seguir o roadmap
   **14 → 15 → 12**, em blocos pequenos, com auditoria antes e depois e com a
   bancada verde.

## HISTÓRICO TÉCNICO

O restante deste arquivo preserva o registro técnico de cada bloco. Está
mantido como foi escrito; o estado que vale agora é o da seção acima.

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
- `sql/05_modelos.sql` — tabela `modelo`, `gerar_mes()` e `fixar_mes()`.
- `sql/06_push.sql` — `push_inscricao` e `resumo_do_dia()`.
- `sql/07_avisos.sql` — `aviso_enviado`, a memória de um aviso por dia e por
  slot.
- `sql/08_avisos_por_pessoa.sql` — preferências de aviso no `perfil` e aviso
  da véspera.
- `sql/09_parcelas.sql` — `parcelas_total` / `parcela_1` no `modelo`,
  `parcela_n` / `parcela_de` no `lancamento`, e a função `parcela_no_mes()`.
- `sql/10_codigo_pagamento.sql` — `codigo_pagamento` / `codigo_tipo` no
  `lancamento`, `pix_estatico` no `modelo`, e a leitura de boleto,
  arrecadação e PIX no `app.js`.

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
(Depois dos blocos 4 e 5 virou 81 / 4 / 23 / 11, naquele ponto da história.)

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
2. **Realtime entre dois aparelhos.** *Histórico: naquele dia ainda não havia
   validação; depois foi validado manualmente — ver ESTADO ATUAL.* A bancada
   provava que o app reage ao evento, mas não provava a travessia da rede.
3. **Contas fixas no aparelho.** Provei no banco e na bancada, não no iPhone.

## Buraco conhecido

Cinco das contas de setembro **não são mensais para sempre** — são acordos
parcelados, uma parcela de imposto e um material escolar. Este buraco foi
fechado pelo bloco 9, que pôs o controle de parcelas em `modelo` e
`lancamento`. O registro abaixo ficou como estava para preservar a ordem dos
fatos.

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
3. **Realtime entre dois aparelhos.** *Histórico: já validado depois; ver
   ESTADO ATUAL.*
4. **Pontualidade do cron.** O do GitHub entra em fila e atrasa; não é defeito
   nosso, é como ele funciona.

## Fora do escopo do bloco 5, de propósito

Registrado depois: **Telegram como redundância** e **offline com IndexedDB**
foram removidos do roadmap. O controle de parcelas virou o bloco 9, concluído.

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
Isso é validação manual. O Realtime entre dois aparelhos já foi validado
depois (ver ESTADO ATUAL); continuam pendentes a validação do aviso de
véspera/por pessoa e o primeiro código colado.

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

Este roadmap de 05/09 foi concluído: **6**, **7**, **9** e **8** estão no ar.
O próximo roadmap é **11 → 13 → 14 → 12** e está descrito na seção
**Estado atual e decisões para os próximos blocos**, no topo deste arquivo.

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

### O que faltava naquele dia

*Histórico.* Na época faltava preencher as cinco contas pela tela. Isso foi
resolvido depois: Jonathan confirmou as parcelas em produção, e há três contas
fixas já parceladas no banco. O estado atual está na seção **ESTADO ATUAL**.

## Bloco 8 — o código de pagamento colado (05/09/2026)

**No ar desde 05/09/2026.** `sql/10_codigo_pagamento.sql` aplicado **antes** do
merge, pela terceira vez pela mesma razão; branch mesclada em seguida.

Conferido no banco: duas colunas novas no `lancamento`, o PIX estático na
`modelo`, as duas regras de integridade (tipo válido, e código e tipo andando
em par), e `resumo_do_dia` ainda `security invoker` e sem execução para
`anon`.

Fecha o pedido que abriu esta conversa: *"conta x vencendo amanhã, cole o
código de pagamento no app"*.

### O que ficou de fora, e por quê

Buscar boleto pelo CPF é o **DDA**, operado pela Nuclea; o acesso é de
instituição financeira. Existem APIs comerciais (Celcoin, TecnoSpeed), mas são
B2B, com CNPJ e contrato. O único caminho para uma pessoa física seria um
agregador com a credencial do banco dela — o que inverteria o modelo de risco
do projeto inteiro. Jonathan cola.

### A aritmética, que é o coração do bloco

Tudo offline: nenhuma chamada de rede, nenhum terceiro, nenhuma credencial.

- **Boleto bancário (47 dígitos):** módulo 10 nos três campos, módulo 11 no
  dígito geral, valor nos últimos dez dígitos e vencimento no fator.
- **O fator estourou.** Ele tem quatro dígitos, chegou a 9999 em 21/02/2025 e a
  FEBRABAN reiniciou em 1000 no dia 22 (FB-009/2023). São **dois ciclos com
  bases diferentes** — 07/10/1997 e 29/05/2022 — e o mesmo número quer dizer
  datas diferentes em cada um. A regra escolhida: vale o ciclo novo; se ele
  jogar a conta para daqui a mais de dois anos, o código é do velho. Confirmado
  numericamente: 1997-10-07 + 9999 dias = 2025-02-21, o dia anterior à virada.
  **Sem isso, toda data lida sairia errada.**
- **Arrecadação (48 dígitos, começa com 8):** quatro blocos, e o 3º dígito diz
  se o verificador é módulo 10 ou 11 — e as duas variantes têm regras de resto
  diferentes das do boleto bancário. Se o dígito mentir, a outra variante é
  tentada: recusar conta boa é pior do que aceitar um código que o banco vai
  conferir de novo.
- **PIX:** TLV do BR Code com CRC16-CCITT. É o CRC que pega o "colei pela
  metade". Distingue cobrança **dinâmica** (que expira) da estática.

Cada algoritmo foi provado por **ida e volta** antes de entrar no `app.js`: a
bancada gera um código válido de mentira e o app real lê de volta.

### Na tela

O chip fica na linha, embaixo da descrição: **"+ código"** quando não há, e
**"copiar código"** quando há. Toque copia, segurar abre para trocar ou tirar —
mesmo vocabulário do resto do app, nenhum gesto novo para aprender. O
`stopPropagation` impede que segurar ali vire "apagar a conta", e isso é
medido.

Ao colar, o app diz o que entendeu **antes** de salvar. E **se a conta estava
sem valor, o valor vem do código** — o "???" morre no gesto de colar. Se já
havia valor digitado, o da pessoa manda.

**Código que não fecha os dígitos é recusado.** Aqui recusar é o certo, ao
contrário do campo do mês: o dígito verificador é garantia de quem emitiu, e
código truncado é pior do que nenhum, porque na hora de pagar a pessoa
confiaria nele.

O campo de colar **não tem `inputmode`**, de propósito: PIX tem letras, e
prender o teclado no numérico foi exatamente o erro que travou o campo do mês
horas antes.

### O aviso da véspera fecha o ciclo

Passa a dizer o que falta preparar: *"faltam colar 2 códigos no app"*, *"falta
colar 1 código"*, ou *"pagamento já preparado"*. E se o banco ainda não tiver o
`sql/10`, o campo não vem e o aviso volta ao texto antigo — **não afirma que
está tudo pronto quando não sabe**. Medido com controle negativo.

### Privacidade

Linha digitável e PIX são dado de pagamento: identificam beneficiário e valor.
Ficam sob a mesma RLS, entram no cache do `localStorage` (que o logout já
limpa, desde a fase 0) e **nunca no repositório** — os códigos das medidas são
gerados na hora pela bancada, com dígitos de mentira.

Bancada: **140 / 4 / 24 / 49**, 0 falhas. Vinte medidas novas na tela e quatro
no texto do aviso, com controles negativos para código quebrado, conta que já
tem valor e segurar sem apagar.

### O que falta

**Colar o primeiro código de verdade e conferir no aparelho.** É a única coisa
que separa este bloco de estar validado — e a que nenhuma bancada faz.

## Risco descoberto em 05/09: ninguém sabe as senhas

Jonathan perguntou onde estão as senhas. Não estão em lugar nenhum, e **isso é
o desenho certo**: o Supabase Auth guarda hash bcrypt, não a senha. Não existe
"onde ver" — existe "como trocar".

O que o banco mostra, e é o incômodo:

| medição | resultado |
|---|---|
| último login do Jonathan | **31/08**, uma única vez |
| último login da segunda pessoa | **nunca** |
| e-mail confirmado nas duas contas | sim |
| senha definida nas duas | sim (o hash existe; ninguém o lê) |

Ou seja: o app funciona há cinco dias montado numa **sessão persistida de
31/08**. Ele está a um logout de perder o acesso às próprias contas, e não há
como reaver sozinho.

**O app não tem recuperação de senha.** A tela de login pede e-mail e senha e
não oferece "esqueci a senha". Foi decisão da fase 1 que nunca virou pendência
escrita.

Caminho para reaver, hoje, sem código: painel do Supabase >
**Authentication > Users >** a pessoa > definir uma senha nova. Direto, sem
depender de e-mail.

Por que não basta "botar um esqueci a senha": o fluxo por e-mail depende de
SMTP, e o serviço embutido do Supabase é limitado e, em projeto novo, só
entrega para endereços da própria organização — o e-mail dela não receberia.
Recuperação por e-mail de verdade exige **configurar SMTP próprio** primeiro.
Enquanto isso não existir, a recuperação é manual, pelo painel, e essa é a
decisão honesta a registrar.

Detalhe que ajuda e já está certo no código: os campos de login têm
`autocomplete="username"` e `current-password`, então o Chaveiro do iPhone
oferece guardar a senha no próximo login. **Guardar ali resolve o problema
prático das duas pessoas.**

## Bloco 10 — senha: trocar, e esquecer (05/09/2026)

Nasceu de um aperto real, à noite, com a esposa do Jonathan do lado.

### A parede que ninguém tinha visto

O link de recuperação funcionou: ela entrou pelo Safari do iPhone. Aí adicionou
o app à tela de início e **caiu na tela de login**.

Não é defeito do app. **No iPhone, o Safari e o app da tela de início têm
armazenamentos separados.** A sessão vive no `localStorage`, e o `localStorage`
de um não é o do outro. Não existe como copiar a sessão de lá para cá: **só a
senha atravessa essa parede.**

Isso torna a troca de senha dentro do app não um luxo, mas o único caminho para
quem entrou por link.

### E a pergunta que veio junto

"Onde fica a senha dela no Supabase?" Em lugar nenhum. O que existe é
`auth.users.encrypted_password`, um **hash bcrypt** (`$2a$`, 60 caracteres),
que é matemática de mão única — ninguém com acesso total ao banco volta dele
para a senha. Não há tela, tabela nem log com a senha em texto, e se houvesse
seria falha grave do Supabase. Fica registrado porque a pergunta é natural e a
resposta não é óbvia.

### O que entrou

- **"trocar senha"** no rodapé, para quem está dentro. Duas caixas, confere se
  batem e se tem 6 caracteres, e chama `updateUser`.
- **"Esqueci a senha"** na tela de login, com `redirectTo` apontando para o
  próprio app — sem isso o link cai no Site URL do projeto, que foi o que
  mandou todo mundo para um `localhost:3000` a tarde inteira.
- Quem chega por link de recuperação **já encontra a folha da senha aberta**. A
  leitura do endereço acontece antes de perguntar pela sessão, porque o
  `supabase-js` consome o token e limpa o hash.
- A folha explica, na hora, por que a senha importa: o app instalado não
  enxerga a sessão do Safari, e o Chaveiro do iPhone deve guardar.

### E o botão não fazia nada: a terceira vez no mesmo dia

Publicado, Jonathan tocou em "trocar senha" no Safari e **não aconteceu nada**.
Auditado antes de supor: os 66 seletores que o `app.js` procura existem todos
no `index.html`, e os dois arquivos estão na `main`. Logo, o código estava
certo — o aparelho é que rodava o **`app.js` velho com o `index.html` novo**. O
botão aparecia (HTML) e não havia quem escutasse o toque (JS).

Terceira vez no mesmo dia. O `no-cache` no service worker não bastou, e a razão
é simples: ele só vale depois que o service worker novo assume, e a página já
aberta continua com o script que carregou.

Conserto que não depende de comportamento de cache: **versão no endereço**.
`app.js?v=10`, `app.css?v=10`, `config.js?v=10`. Endereço novo é endereço que
nenhum cache tem — não há como servir o velho. Ao subir a versão, muda-se nos
dois arquivos, e **a bancada confere que o `sw.js` pede exatamente os endereços
que o `index.html` pede**, com controle negativo para o endereço sem versão.

Vale registrar a armadilha que escondeu isso das medidas: o `querySelector`
falso da bancada **cria** o elemento quando não acha, enquanto o navegador
devolve `null`. Um seletor errado passaria despercebido ali e derrubaria o
`app.js` inteiro no aparelho. Desta vez não era isso — mas foi preciso conferir
para saber.

Bancada: **154 / 4 / 27 / 49**, 0 falhas. Quatro medidas de controle negativo:
senhas diferentes não passam, senha curta não passa, "esqueci" sem e-mail não
chama nada, e trocar senha não encosta em conta nenhuma.

De quebra, uma medida minha reaproveitou um contador de um bloco anterior e
falhou por baseline velho — o mesmo tipo de fragilidade que o contador de
filhos tinha. Corrigida na hora.

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
5. ~~**Realtime entre dois aparelhos.**~~ **Feito: validado manualmente.**
   Manter essa validação em mudanças futuras que toquem no
   `postgres_changes` ou no redesenho da tela.
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

## Bloco 11 — o mês nasce sozinho (06/09/2026)

Uma frase: ao abrir o app, o mês corrente nasce uma vez — e nasce no banco,
não no JavaScript.

O buraco que fecha: até aqui o mês só existia depois que alguém tocava "Trazer
N contas fixas". Se ninguém tocasse, o robô dos avisos não tinha o que avisar,
e a conta vencia em silêncio.

### A primeira tentativa, e por que foi descartada

Houve uma implementação anterior (commit local `86c81c5`, nunca publicado) que
foi auditada e recusada **antes** de qualquer SQL entrar no banco. Ela errava
em quatro pontos, e os quatro viraram requisito do desenho definitivo:

1. **Gerava mês ao navegar.** A chamada entrava também no `irPara()`, então
   voltar para janeiro *criava* janeiro a partir dos modelos de hoje. Uma
   passada distraída seis meses para trás fabricaria seis meses de história
   inventada. Ler não pode escrever.
2. **Ressuscitava conta apagada.** Sem marca de "este mês já nasceu", apagar
   uma conta virava escolha temporária: ela voltava na próxima abertura.
3. **Punha a trava no lugar errado.** A constraint proposta era
   `(casa_id, competencia, lower(btrim(descricao)))`. Como `modelo` não tem
   unicidade por descrição, duas contas fixas chamadas "Internet" na mesma casa
   teriam virado uma só — em silêncio, por causa do `ON CONFLICT DO NOTHING`.
4. **Removia o botão.** Sem ele, uma conta fixa cadastrada no dia 12 não teria
   como entrar no mês que já nasceu.

### As três separações que mandam no desenho

**Nascer ≠ trazer o que falta.** Nascer é automático, acontece uma vez por mês
e é o que o bloco 11 criou. Trazer o que falta continua sendo o botão,
explícito, quantas vezes a pessoa quiser. Sem essa separação, o item 4 acima
não tem conserto.

**A trava é o MÊS, não a linha.** O que precisa ser idempotente é "este mês já
nasceu nesta casa". Por isso a trava é a chave primária de `mes_gerado`, e não
uma constraint na `lancamento`.

**Quem decide se gera ≠ quem decide se é a mesma linha.** A primeira é o
`NOT EXISTS` por descrição, que continua inteiro e é o que impede duplicar uma
conta digitada à mão. A segunda é o índice único por `modelo_id`, que só
arbitra entre linhas que a função já decidiu inserir — todas com `modelo_id`.
A auditoria anterior temia que trocar a chave para `modelo_id` quebrasse a
regra da conta manual: não quebra, porque são perguntas diferentes, feitas em
momentos diferentes.

### O que entrou

- **`public.mes_gerado (casa_id, competencia, gerado_em, origem)`**, PK
  `(casa_id, competencia)`. Uma linha quer dizer "esta competência desta casa
  já foi inicializada". `origem` distingue `'automatico'` de `'backfill'`.
- **RLS com `force`, e só SELECT e INSERT** para `authenticated`. Sem UPDATE e
  sem DELETE, de propósito: é isso que torna durável apagar uma conta. Se o app
  pudesse desmarcar um mês, a durabilidade seria convenção do cliente; sem os
  dois verbos, é propriedade do banco.
- **E o cliente não escreve aqui por caminho nenhum.** Sem grant de INSERT e
  sem policy de INSERT: o PostgREST recusa antes de a RLS ser consultada. Foram
  três rodadas de auditoria até chegar aqui, e as duas primeiras erraram do
  mesmo jeito — fecharam **valores** (que mês, que origem) quando o que faltava
  era fechar **autoridade** (quem pode escrever). Com uma policy de INSERT, por
  mais estreita que fosse, a sessão logada ainda gravava à mão a marca do mês
  corrente sem gerar nada: `garantir_mes()` acharia a marca, devolveria zero e
  não chamaria `gerar_mes()` — mês marcado como nascido, contas do mês nunca
  vêm. Um POST de uma linha, em silêncio, contra as duas invariantes do bloco.
- **A única porta é `privado.marcar_mes_corrente()`**, `security definer`, sem
  parâmetro, num schema que o PostgREST não publica. Sem parâmetro é o que a
  torna segura: casa e mês ela calcula do JWT e do relógio de São Paulo, então
  não existe valor que o cliente possa mandar. Se morasse no `public`, viraria
  `/rest/v1/rpc/marcar_mes_corrente` e a brecha voltaria inteira, agora com
  autoridade de dono de tabela.
- **`garantir_mes()` continua `security invoker`**, e isso é decisão, não
  descuido. Marcá-la inteira como `definer` fecharia a mesma porta com um diff
  menor — mas o dono da função no Supabase é o `postgres`, que tem
  `rolbypassrls`, e o `gerar_mes()` chamado lá de dentro passaria a rodar com a
  **RLS desligada** em `modelo` e `lancamento`. Medido numa réplica com duas
  casas: a mesma consulta devolve 0 lançamentos como `authenticated` e 1 (o da
  outra casa) dentro de um `definer`. O `gerar_mes()` continuaria correto — ele
  filtra por `casa_id` em todo lugar —, mas o `where` viraria a única parede
  entre as casas, em vez da segunda.
- **`lancamento_do_modelo_idx`**, índice único em
  `(casa_id, competencia, modelo_id)`. Não é parcial e não precisa ser:
  lançamento manual tem `modelo_id` nulo, e nulo não colide em índice único.
  De quebra fecha um defeito antigo — renomear uma conta fixa com o mês já
  gerado fazia o `NOT EXISTS` deixar de casar, e a mesma conta entrava duas
  vezes.
- **`gerar_mes(date)`**: regra de negócio **idêntica** à do `sql/10`. Uma única
  linha nova, de mecanismo: `on conflict (casa_id, competencia, modelo_id) do
  nothing`, com alvo nomeado. Ela é necessária porque o botão chama a função
  sem passar pela trava do `mes_gerado`.
- **`garantir_mes()`**, sem argumento. É a assinatura que garante que navegar
  para um mês histórico nunca vira escrita: não existe pedido que o cliente
  possa formular. O mês vem de `date_trunc('month', now() at time zone
  'America/Sao_Paulo')`, no banco — o `mesDeHoje()` do app usa o relógio do
  aparelho, que às 21h de 30/09 num telefone em UTC já virou outubro. É a mesma
  lição do bloco 6.
- **Na tela**: `garantirMesCorrente()` roda **antes** do `carregarMes()`, e o
  app adota a competência que o servidor devolveu. O `irPara()` não mudou uma
  linha. O `visibilitychange` passou a perguntar de novo quando o relógio do
  aparelho discorda do que o banco confirmou — sem mexer no mês que a pessoa
  está vendo, porque um PWA que fica semanas aberto na tela de início nunca faz
  um `abrirApp()` novo.

### Concorrência: medida numa réplica local, não em produção

Dois aparelhos chamam `garantir_mes()` no mesmo segundo. Um insere a marca; o
outro **bloqueia** na chave primária até a transação do primeiro terminar, e só
então recebe o conflito. Como o PostgREST roda a função inteira numa transação,
a marca e os lançamentos do vencedor commitam juntos — então `criadas = 0` quer
dizer literalmente "as contas já estão gravadas", nunca "estão a caminho". É
por isso que a chamada vem **antes** da leitura do mês: assim o perdedor espera
o vencedor gravar em vez de pintar um mês vazio.

A bancada **não** mede isso: ela finge o banco inteiro. Mas o `sql/11` foi
exercitado antes do commit numa **réplica local em PostgreSQL 16** — schema
mínimo com `casa`, `perfil`, `modelo`, `lancamento`, `minha_casa()` e
`parcela_no_mes()`, RLS ligada e forçada, rodando como `authenticated`. Com
**duas sessões `psql` de verdade**:

| medição | resultado |
|---|---|
| A abre transação e chama `garantir_mes()` | gerou 5 contas, sem commitar |
| B chama ao mesmo tempo, com `statement_timeout = 2s` | **bloqueou** e estourou o timeout — `while inserting index tuple in relation "mes_gerado"`, dentro do `on conflict` |
| A commita, B chama de novo | `criadas = 0`, e B enxerga as 5 contas de A |
| estado final | 5 lançamentos, **1 marca** |

B não recebeu zero cedo demais: ele esperou. É exatamente a propriedade que
impede o mês pela metade, e agora é medida, não só argumentada.

**O que continua não medido:** o mesmo comportamento no banco de produção
(PostgreSQL 17, via PostgREST) e com dois aparelhos de verdade. A réplica prova
o mecanismo; não prova a produção.

### O resto do bloco, exercitado na mesma réplica

Antes do commit, na réplica local e como `authenticated`:

- o mês nasce com 4 contas e **os dois modelos chamados "Internet" entram os
  dois** — é o caso que a chave por descrição teria comido em silêncio;
- modelo desligado não entra; parcelada fora da janela não entra; parcelada
  dentro vem com `9/12`; PIX estático vem copiado com `codigo_tipo = 'pix'`;
- chamar `garantir_mes()` de novo devolve `criadas = 0`;
- **apagar o Aluguel e chamar de novo: ele NÃO volta** — a exclusão é durável;
- o botão (`gerar_mes`) traz o Aluguel de volta, e apertar duas vezes traz zero;
- uma conta "Mercado" digitada à mão não é duplicada por um modelo `"mercado "`
  — maiúscula e espaço sobrando incluídos: o `NOT EXISTS` por descrição segue
  inteiro;
- tentar gravar uma segunda linha do mesmo modelo no mesmo mês é **recusada**
  pelo índice único, mesmo com descrição diferente;
- `authenticated` **não consegue apagar** de `mes_gerado`: `permission denied`.
  Foi descoberto por acidente, tentando limpar a réplica — e é a garantia da
  exclusão durável funcionando.
- e, sob um usuário real da casa, **cinco** inserts diretos são recusados com
  **42501 — `permission denied for table mes_gerado`**: mês passado, mês futuro,
  `origem = 'backfill'`, marca para outra casa e — o que mais importa — o
  **mês corrente da própria casa com a origem certa**. Esse quinto era aceito na
  versão anterior e virou controle negativo. O `garantir_mes()` continua
  funcionando. Está na medição 8 da prova, e nada fica gravado: cada tentativa
  roda numa subtransação desfeita de propósito.
- dentro do `garantir_mes()`, `current_user = authenticated` e o lançamento da
  outra casa continua invisível: a RLS segue sendo a segunda parede na geração.
- o backfill depende do **role**, não da policy: rodado como `postgres`
  (`rolbypassrls = true`, conferido no catálogo) ele grava as marcas
  `'backfill'`; a mesma instrução rodada como `authenticated` apanha com
  `new row violates row-level security policy`. Falha alta, não silenciosa.

O `sql/11_prova_geracao.sql` também roda inteiro nessa réplica, sem erro, e o
controle negativo da RLS devolve zero.

### O backfill, e a marca que não pode mentir

O banco já tinha duas competências. Sem backfill, o primeiro app aberto depois
da migration marcaria o mês corrente como novo e rodaria a geração nele.

A regra é seletiva: só marca competência onde a geração **demonstravelmente já
rodou**, isto é, onde existe lançamento com `modelo_id` não nulo. Um mês que
tenha apenas conta digitada à mão não é marcado — e é exatamente o mês em que a
primeira geração automática ainda deve acontecer. Em 06/09/2026 essa cláusula
não exclui nada (as duas competências são 100% vindas de modelo: 2026-09 com 20
lançamentos e 2026-10 com 14, nenhum manual em todo o banco); a razão de ela
existir é o mês em que vai excluir. A prova confere que marcou **exatamente 2**.

### O que a bancada mede

170 medidas no bloco do `app.js`, 16 delas novas. Ela mede o **lado cliente**:
quando chama, com o quê, e o que faz com a resposta.

- `garantir_mes` é chamada na abertura, **sem argumento**, e **antes** de
  qualquer leitura de mês (o `mesesLidosAntes` do log prova a ordem).
- **Controle negativo**: navegar para frente e para trás não faz nenhuma
  chamada de geração. Com a chamada reposta dentro do `irPara()` — o defeito do
  `86c81c5` — a bancada acusa 4 chamadas e fica vermelha.
- A competência devolvida pelo servidor vence o palpite do aparelho.
- Voltar do segundo plano com o mês no lugar não pergunta nada; com o relógio
  discordando, pergunta — e em nenhum dos dois casos arrasta a tela para outro
  mês.
- O botão continua existindo e continua chamando `gerar_mes` para o mês que
  está na tela, não para o corrente.

### O que fica pendente

- **Aplicar `sql/11_geracao_automatica.sql` no banco e rodar
  `sql/11_prova_geracao.sql`** antes do merge. O app já chama `garantir_mes()`.
- **Anotar na prova o md5 do `gerar_mes()` instalado** depois de aplicar. O
  anterior, do `sql/10`, era `0619f9ab536a4d80c0a1c7ea32a3e3cc`. É o detector
  de divergência entre o arquivo SQL e a função realmente instalada, que até
  aqui não existia.
- **Limite conhecido, não resolvido aqui:** o mês só nasce quando alguém abre o
  app. Se ninguém abrir no dia 1º, o robô dos avisos não terá o que avisar
  naquele dia. Isso já era verdade com o botão, então não é regressão — mas é o
  argumento para, um dia, o robô também garantir o mês. **Fora do escopo do
  bloco 11.**

### Aplicado em produção em 06/09/2026

Migration `bloco_11_geracao_automatica_do_mes` aplicada no banco, e provada ali
mesmo — não na réplica, no banco de verdade:

| medição | resultado |
|---|---|
| chave primária de `mes_gerado` | `{casa_id, competencia}`, 2 checks |
| RLS | ligada, **forçada**, e só a política `mes_gerado_ler` |
| grants (`anon` lê / `anon` executa / eu leio / eu gravo / eu atualizo / eu apago / eu chamo / `anon` no `privado` / `anon` marca) | `f f t f f f t f f` |
| índice | `unique (casa_id, competencia, modelo_id)`, sem `where` |
| `privado.marcar_mes_corrente` | definer, `search_path=public`, **0 argumentos**, fora do `public` |
| `public.garantir_mes` | **não** é definer, 0 argumentos |
| backfill | **2** marcas, `2026-09-01` e `2026-10-01`, ambas `backfill` |
| `geradas_sem_marca` / `marcas_sem_conta_gerada` | 0 / 0 |

E as tentativas reais, sob um usuário de verdade da casa (`current_user =
authenticated`), com tudo desfeito por subtransação:

| tentativa | resultado |
|---|---|
| insert direto, mês passado | `42501 permission denied for table mes_gerado` |
| insert direto, mês futuro | `42501 permission denied` |
| insert direto, `origem = 'backfill'` | `42501 permission denied` |
| insert direto, outra casa | `42501 permission denied` |
| **insert direto, mês corrente da própria casa** | `42501 permission denied` |
| `garantir_mes()` | `2026-09-01, criadas = 0` |
| marcas depois de tudo | 2 — nada persistiu |
| controle negativo: um uuid sem perfil | vê **0** marcas e **0** contas |

O linter de segurança do Supabase confirma de fora: **nenhum alerta novo**. Em
particular, `privado.marcar_mes_corrente` **não** aparece no aviso "signed-in
users can execute SECURITY DEFINER function" — justamente porque mora fora do
schema publicado. Continuam os três de sempre: `aviso_enviado` sem política (só
o robô escreve, com `service_role`), `minha_casa()` definer e chamável
(intencional, devolve a sua própria casa) e a proteção de senha vazada
desligada, que é um clique no painel.

**O que ainda não foi provado:** a primeira geração automática de verdade. Em
06/09 o mês corrente já estava marcado pelo backfill, então `garantir_mes()`
devolve zero — corretamente. É em **01/10**, quando alguém abrir o app, que o
bloco se prova sozinho: `mes_gerado` deve ganhar uma linha `2026-10-01`... que
já existe, também pelo backfill. Então o teste de verdade é **01/11**. Até lá,
o que está provado é o mecanismo, não o ciclo completo.
