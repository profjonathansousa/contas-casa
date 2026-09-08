-- ============================================================
-- Nossas Contas — PROVA do bloco 12.
--
-- Rodar DEPOIS de sql/12_graficos.sql.
-- Nada persiste: os dados de prova são inseridos numa transação e desfeitos.
-- ============================================================

select 'rpc_graficos' as parte,
       to_regprocedure('public.graficos()') is not null as existe,
       p.prosecdef as security_definer,
       p.provolatile as volatilidade,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       has_function_privilege('anon', 'public.graficos()', 'EXECUTE') as anon_executa,
       has_function_privilege('authenticated', 'public.graficos()', 'EXECUTE') as auth_executa
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname = 'graficos';
-- esperado: t | f | s | (vazio) | f | t

create temp table _quem_graficos as
select id as uid, casa_id from public.perfil limit 1;

create temp table _casa_graficos_estranha (
  id uuid primary key
);
insert into _casa_graficos_estranha values (gen_random_uuid());
grant select on table _casa_graficos_estranha to authenticated;

begin;

insert into public.casa (id, nome)
select id, 'Casa de prova gráficos' from _casa_graficos_estranha;

-- Dados de prova apenas na casa principal.
insert into public.lancamento
  (casa_id, competencia, descricao, dia_vencimento, valor_previsto,
   valor_pago, pago)
values
  ((select casa_id from _quem_graficos), '2099-01-01', 'Despesa gráfico',
   5, 100.00, 80.00, true);

insert into public.receita
  (casa_id, competencia, descricao, valor, recebido)
values
  ((select casa_id from _quem_graficos), '2099-01-01', 'Receita gráfico',
   200.00, true);

-- Dado de prova na outra casa, em competência distinta, para testar RLS.
insert into public.lancamento
  (casa_id, competencia, descricao, dia_vencimento, valor_previsto, pago)
values
  ((select id from _casa_graficos_estranha), '2099-02-01', 'Despesa outra casa',
   5, 999.00, true);

select 'grafico_esperado' as parte,
       despesa_prevista,
       despesa_paga,
       despesa_a_pagar,
       despesa_contas,
       receita_total,
       receita_recebida,
       receita_contas,
       saldo
  from public.graficos()
 where competencia = '2099-01-01';
-- esperado: 100 | 80 | 0 | 1 | 200 | 200 | 1 | 120

select set_config(
  'request.jwt.claims',
  json_build_object('sub', (select uid from _quem_graficos),
                    'role', 'authenticated')::text,
  false);
set role authenticated;

select 'grafico_sob_rls' as parte,
       (select count(*) from public.graficos()
         where competencia = '2099-01-01') as propria_visivel,
       (select count(*) from public.graficos()
         where competencia = '2099-02-01') as outra_invisivel;
-- esperado: 1 | 0

rollback;

reset role;
select set_config('request.jwt.claims', null, false);

drop table _casa_graficos_estranha;
drop table _quem_graficos;

-- ============================================================
-- LEITURA DO RESULTADO
--   1: t | f | s | (vazio) | f | t
--   2: 100 | 80 | 0 | 1 | 200 | 200 | 1 | 120
--   3: 1 | 0
-- ============================================================
