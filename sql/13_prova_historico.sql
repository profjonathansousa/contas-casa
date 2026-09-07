-- ============================================================
-- Nossas Contas — PROVA do histórico (manual, no SQL Editor).
--
-- Por que este arquivo existe: a bancada mede o app.js real, mas não o
-- Postgres. Esta prova confere que public.historico() devolve exatamente os
-- mesmos agregados que a tabela public.lancamento possui sob a RLS.
--
-- Troque o e-mail abaixo pelo e-mail de login de uma das pessoas.
-- Rodar DEPOIS de sql/13_historico.sql.
-- ============================================================

create temporary table _prova_historico as
select id as meu_id from auth.users
where lower(email) = lower('pessoa1@exemplo.com');   -- <<< TROQUE AQUI

select set_config(
  'request.jwt.claims',
  json_build_object('sub', (select meu_id from _prova_historico), 'role', 'authenticated')::text,
  false);
set role authenticated;

do $$
declare
  r record;
  p numeric;
  g numeric;
  a numeric;
  c bigint;
  s bigint;
  qtd_lanc bigint;
  qtd_hist bigint;
begin
  -- Permissões da RPC, sem depender de comando comentado.
  if has_function_privilege('anon', 'public.historico()', 'EXECUTE') then
    raise exception 'anon possui EXECUTE em public.historico()';
  end if;
  if not has_function_privilege('authenticated', 'public.historico()', 'EXECUTE') then
    raise exception 'authenticated não possui EXECUTE em public.historico()';
  end if;

  -- Cardinalidade.
  select count(distinct l.competencia) into qtd_lanc
    from public.lancamento l;
  select count(*) into qtd_hist
    from public.historico();

  if qtd_lanc is distinct from qtd_hist then
    raise exception 'Cardinalidade divergente: lancamento=%, historico=%',
      qtd_lanc, qtd_hist;
  end if;

  -- Sentido A) tudo que existe em lancamento aparece em historico().
  if exists (
    select 1
    from (select distinct l.competencia from public.lancamento l) l
    where not exists (
      select 1
      from public.historico() h
      where h.competencia = l.competencia
    )
  ) then
    raise exception 'Há competência em lancamento ausente em historico()';
  end if;

  -- Sentido B) tudo que historico() devolve existe em lancamento.
  if exists (
    select 1
    from public.historico() h
    where not exists (
      select 1
      from public.lancamento l
      where l.competencia = h.competencia
    )
  ) then
    raise exception 'Há competência em historico() sem lançamento correspondente';
  end if;

  -- Agregados por competência.
  for r in select * from public.historico() loop
    select coalesce(sum(l.valor_previsto), 0),
           coalesce(sum(case when l.pago then coalesce(l.valor_pago, l.valor_previsto, 0) else 0 end), 0),
           coalesce(sum(case when not l.pago and l.valor_previsto is not null then l.valor_previsto else 0 end), 0),
           count(*),
           count(*) filter (where not l.pago and l.valor_previsto is null)
      into p, g, a, c, s
      from public.lancamento l
     where l.competencia = r.competencia;

    if r.previsto  is distinct from p
       or r.pago    is distinct from g
       or r.a_pagar is distinct from a
       or r.contas  is distinct from c
       or r.sem_valor is distinct from s then
      raise exception 'Divergência no histórico para %', r.competencia;
    end if;
  end loop;
end $$;

reset role;
select set_config('request.jwt.claims', null, false);
drop table _prova_historico;

-- Leitura esperada: uma linha por competência, da mais recente para a mais
-- antiga, apenas com as competências da casa do usuário.
