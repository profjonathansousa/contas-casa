-- ============================================================
-- Nossas Contas — bloco 17: o histórico numa tela só.
--
-- O histórico antigo (importado no bloco 15) passa a entrar na tela de
-- histórico, ao lado dos meses do app. Nenhuma tabela nova, nenhum dado
-- copiado: duas funções de leitura, security invoker, sob a RLS de sempre.
--
-- public.historico() NÃO muda: a graficos() depende dela, e os gráficos só
-- passam a ver o legado na rodada deles.
-- ============================================================

-- ------------------------------------------------------------
-- 1. O mês antigo, somado.
--
-- Até onde o legado vale: os meses ANTERIORES ao primeiro mês que o app
-- inicializou (mes_gerado). Setembro/2026 está nos dois — no arquivo antigo e
-- no app — e vale o do app, senão o mês contaria duas vezes. mes_gerado é o
-- corte certo porque o cliente não escreve nela: uma conta digitada à mão num
-- mês antigo não arrasta o corte.
--
-- Riscada, no arquivo antigo, quer dizer "saiu do meu controle": conta paga
-- pela outra pessoa da casa, que deixou de ser acompanhada. A despesa existiu.
-- Por isso ela não some — fica nas colunas próprias (riscado, riscadas), fora
-- de previsto/pago/a_pagar, e quem mostra decide se soma. Nunca em silêncio.
-- ------------------------------------------------------------

create or replace function public.historico_legado_mensal()
returns table (
  competencia date,
  previsto    numeric,
  pago        numeric,
  a_pagar     numeric,
  contas      bigint,
  sem_valor   bigint,
  riscado     numeric,
  riscadas    bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  select h.competencia,
         coalesce(sum(h.valor) filter (where not h.riscado), 0)                  as previsto,
         coalesce(sum(h.valor) filter (where not h.riscado and h.pago), 0)       as pago,
         coalesce(sum(h.valor) filter (where not h.riscado and not h.pago), 0)   as a_pagar,
         count(*) filter (where not h.riscado)                                   as contas,
         count(*) filter (where not h.riscado and not h.pago and h.valor is null) as sem_valor,
         coalesce(sum(h.valor) filter (where h.riscado), 0)                      as riscado,
         count(*) filter (where h.riscado)                                       as riscadas
    from public.historico_legado h
   where h.competencia < coalesce((select min(m.competencia) from public.mes_gerado m),
                                  'infinity'::date)
   group by h.competencia;
$$;

revoke all on function public.historico_legado_mensal() from public, anon;
grant execute on function public.historico_legado_mensal() to authenticated;

-- ------------------------------------------------------------
-- 2. A lista da tela de histórico: os meses do app e os do arquivo antigo,
--    do mais recente para o mais antigo, cada um dizendo de onde veio.
-- ------------------------------------------------------------

create or replace function public.historico_completo()
returns table (
  competencia date,
  origem      text,
  previsto    numeric,
  pago        numeric,
  a_pagar     numeric,
  contas      bigint,
  sem_valor   bigint,
  riscado     numeric,
  riscadas    bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  select competencia, origem, previsto, pago, a_pagar, contas, sem_valor, riscado, riscadas
    from (
      select a.competencia, 'app'::text as origem, a.previsto, a.pago, a.a_pagar,
             a.contas, a.sem_valor, 0::numeric as riscado, 0::bigint as riscadas
        from public.historico() a
      union all
      select l.competencia, 'legado'::text, l.previsto, l.pago, l.a_pagar,
             l.contas, l.sem_valor, l.riscado, l.riscadas
        from public.historico_legado_mensal() l
    ) t
   order by competencia desc, origem;
$$;

revoke all on function public.historico_completo() from public, anon;
grant execute on function public.historico_completo() to authenticated;

-- Conferência
select p.proname as funcao,
       p.prosecdef as security_definer,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_executa,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_executa
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace
   and p.proname in ('historico_legado_mensal', 'historico_completo')
 order by p.proname;
-- esperado: f | (vazio) | f | t, nas duas
