-- ============================================================
-- Nossas Contas — PROVA da RLS.
--
-- Por que isto existe: o SQL Editor roda como "postgres", que ignora RLS.
-- Então um select que devolve as linhas certas ali NÃO prova nada. Este
-- script finge ser um usuário autenticado e mede duas vezes:
--   1) como você            -> tem que ver as suas linhas
--   2) como um id inventado -> TEM que ver zero  (controle negativo)
-- Se as duas contagens forem iguais, a RLS não está funcionando.
--
-- Rodar DEPOIS do 01, do 02 e (de preferência) do 03.
-- Troque o e-mail na primeira linha pelo seu e-mail de login.
-- ============================================================

create temporary table _prova as
select id as meu_id from auth.users
where lower(email) = lower('pessoa1@exemplo.com');   -- <<< TROQUE AQUI

-- ---------- medição 1: eu ----------
select set_config(
  'request.jwt.claims',
  json_build_object('sub', (select meu_id from _prova), 'role', 'authenticated')::text,
  false);
set role authenticated;

select 'medicao 1 — eu'      as quem,
       (select count(*) from public.casa)       as casas,
       (select count(*) from public.perfil)     as perfis,
       (select count(*) from public.lancamento) as lancamentos;

reset role;

-- ---------- medição 2: controle negativo ----------
-- Um uuid que não tem perfil nenhum. minha_casa() devolve NULL,
-- e "casa_id = NULL" nunca é verdadeiro.
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-000000000000',
                    'role', 'authenticated')::text,
  false);
set role authenticated;

select 'medicao 2 — estranho' as quem,
       (select count(*) from public.casa)       as casas,
       (select count(*) from public.perfil)     as perfis,
       (select count(*) from public.lancamento) as lancamentos;

reset role;
select set_config('request.jwt.claims', null, false);
drop table _prova;

-- ============================================================
-- LEITURA DO RESULTADO
--   medição 1: casas = 1, perfis = 2, lancamentos = 9 (se rodou o seed)
--   medição 2: casas = 0, perfis = 0, lancamentos = 0   <- obrigatório
-- Qualquer número diferente de zero na medição 2 é RLS furada. Me avise.
-- ============================================================
