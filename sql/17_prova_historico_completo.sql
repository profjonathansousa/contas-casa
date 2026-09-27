-- ============================================================
-- Nossas Contas — PROVA do bloco 17 (manual, no SQL Editor). Só leitura.
--
-- Troque o e-mail abaixo pelo e-mail de login de uma das pessoas.
-- Rodar DEPOIS de sql/17_historico_completo.sql. Se passar, a última linha
-- diz 'bloco 17 provado'; se não, para com a razão.
-- ============================================================

create temporary table _prova_17 as
select id as meu_id from auth.users
where lower(email) = lower('pessoa1@exemplo.com');   -- <<< TROQUE AQUI

select set_config(
  'request.jwt.claims',
  json_build_object('sub', (select meu_id from _prova_17), 'role', 'authenticated')::text,
  false);
set role authenticated;

do $$
declare
  corte date;
  n_app bigint; n_hist bigint;
  n_leg bigint; n_meses_leg bigint;
  soma_fn numeric; soma_tab numeric;
begin
  -- 1. Permissões.
  if has_function_privilege('anon', 'public.historico_completo()', 'EXECUTE')
     or has_function_privilege('anon', 'public.historico_legado_mensal()', 'EXECUTE') then
    raise exception 'anon executa uma das funções do bloco 17';
  end if;

  select min(competencia) into corte from public.mes_gerado;
  if corte is null then raise exception 'sem mes_gerado: a prova precisa de uma casa com app em uso'; end if;

  -- 2. Os meses do app são exatamente os da historico().
  select count(*) into n_app  from public.historico_completo() where origem = 'app';
  select count(*) into n_hist from public.historico();
  if n_app <> n_hist then raise exception 'meses do app: % na lista, % na historico()', n_app, n_hist; end if;

  -- 3. Os meses antigos são exatamente os do legado antes do corte.
  select count(*) into n_leg from public.historico_completo() where origem = 'legado';
  select count(distinct competencia) into n_meses_leg
    from public.historico_legado where competencia < corte;
  if n_leg <> n_meses_leg then raise exception 'meses antigos: % na lista, % no legado', n_leg, n_meses_leg; end if;

  -- 4. Nenhum mês do legado a partir do corte: setembro/2026 não conta duas vezes.
  if exists (select 1 from public.historico_completo()
              where origem = 'legado' and competencia >= corte) then
    raise exception 'o legado entrou num mês que já é do app';
  end if;

  -- 5. Nada se perde: previsto + riscado = soma de tudo o que o legado tem antes do corte.
  select coalesce(sum(previsto + riscado), 0) into soma_fn
    from public.historico_completo() where origem = 'legado';
  select coalesce(sum(valor), 0) into soma_tab
    from public.historico_legado where competencia < corte;
  if soma_fn <> soma_tab then raise exception 'soma diverge: função %, tabela %', soma_fn, soma_tab; end if;

  -- 6. pago + a_pagar = previsto, mês a mês.
  if exists (select 1 from public.historico_legado_mensal() where pago + a_pagar <> previsto) then
    raise exception 'pago + a_pagar diferente de previsto em algum mês antigo';
  end if;

  -- 7. Ordem: do mais recente para o mais antigo.
  if exists (
    select 1 from (select c, lag(c) over (order by ord) as ant
                     from public.historico_completo()
                          with ordinality as t(c, o, p1, p2, p3, n1, n2, r1, r2, ord)) s
     where ant is not null and c > ant) then
    raise exception 'lista fora de ordem';
  end if;
end $$;

-- 8. Controle negativo: um id sem perfil não enxerga mês nenhum.
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-000000000000', 'role', 'authenticated')::text,
  false);
select 'controle_negativo' as parte, count(*) as meses from public.historico_completo();
-- esperado: 0

reset role;
select 'bloco 17 provado' as resultado;
