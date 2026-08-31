# ESTADO — Nossas Contas

Atualizado em 30/08/2026 — fim do bloco 1 (fundação).

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

## PRÓXIMA AÇÃO EXATA

**É minha, não sua.** O banco ainda não existe.

Jonathan precisa fazer os passos manuais no painel do Supabase (criar o
projeto, rodar `sql/01_schema_rls.sql`, criar os dois usuários, rodar a versão
preenchida do `sql/02_config_inicial.sql`, e copiar a URL do projeto e a
`anon key`).

Quando ele confirmar que o banco está de pé e passar a URL e a `anon key`,
começar pelo item 1 da lista acima e seguir até o 12.
