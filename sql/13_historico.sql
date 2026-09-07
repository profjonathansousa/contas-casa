-- ============================================================
-- Nossas Contas — bloco 13: histórico derivado dos lançamentos.
--
-- NÃO existe tabela "historico". O histórico é uma leitura agregada de
-- public.lancamento, limitada pela RLS já existente. A função é security
-- invoker: quem executa enxerga somente a própria casa.
-- ============================================================

create or replace function public.historico()
returns table (
  competencia date,
  previsto    numeric,
  pago        numeric,
  a_pagar     numeric,
  contas      bigint,
  sem_valor   bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  select l.competencia,
         coalesce(sum(l.valor_previsto), 0) as previsto,
         coalesce(sum(
           case when l.pago
                then coalesce(l.valor_pago, l.valor_previsto, 0)
                else 0
           end
         ), 0) as pago,
         coalesce(sum(
           case when not l.pago and l.valor_previsto is not null
                then l.valor_previsto
                else 0
           end
         ), 0) as a_pagar,
         count(*) as contas,
         count(*) filter (where not l.pago and l.valor_previsto is null) as sem_valor
    from public.lancamento l
   group by l.competencia
   order by l.competencia desc;
$$;

revoke all on function public.historico() from public, anon;
grant execute on function public.historico() to authenticated;

-- Conferência: a função existe como security invoker e não recebe argumentos.
select p.proname                       as funcao,
       p.prosecdef                     as security_definer,
       p.provolatile                   as volatilidade,
       pg_get_function_arguments(p.oid) as argumentos
from pg_proc p
where p.proname = 'historico';
