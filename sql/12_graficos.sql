-- ============================================================
-- Nossas Contas — bloco 12: gráficos.
--
-- Camada somente leitura. Não cria tabela nem segunda fonte de verdade:
-- reaproveita public.historico() e public.receitas_mensais(), ambas já
-- limitadas pela RLS.
-- ============================================================

create or replace function public.graficos()
returns table (
  competencia       date,
  despesa_prevista  numeric,
  despesa_paga      numeric,
  despesa_a_pagar   numeric,
  despesa_contas    bigint,
  despesa_sem_valor bigint,
  receita_total     numeric,
  receita_recebida  numeric,
  receita_a_receber numeric,
  receita_contas    bigint,
  saldo             numeric
)
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(d.competencia, r.competencia) as competencia,
         coalesce(d.previsto, 0)  as despesa_prevista,
         coalesce(d.pago, 0)      as despesa_paga,
         coalesce(d.a_pagar, 0)   as despesa_a_pagar,
         coalesce(d.contas, 0)    as despesa_contas,
         coalesce(d.sem_valor, 0) as despesa_sem_valor,
         coalesce(r.total, 0)     as receita_total,
         coalesce(r.recebido, 0)  as receita_recebida,
         coalesce(r.a_receber, 0) as receita_a_receber,
         coalesce(r.contas, 0)    as receita_contas,
         coalesce(r.recebido, 0) - coalesce(d.pago, 0) as saldo
    from public.historico() d
    full outer join public.receitas_mensais() r
      on d.competencia = r.competencia
   order by competencia desc;
$$;

revoke all on function public.graficos() from public, anon;
grant execute on function public.graficos() to authenticated;

-- Conferência
select p.proname as funcao,
       p.prosecdef as security_definer,
       p.provolatile as volatilidade,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       has_function_privilege('anon', 'public.graficos()', 'EXECUTE') as anon_executa,
       has_function_privilege('authenticated', 'public.graficos()', 'EXECUTE') as auth_executa
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname = 'graficos';
