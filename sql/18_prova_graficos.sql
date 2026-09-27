-- ============================================================
-- Nossas Contas — PROVA do bloco 18 (manual, no SQL Editor). Só leitura.
--
-- Troque o e-mail abaixo pelo e-mail de login de uma das pessoas.
-- Rodar DEPOIS de sql/18_graficos_desde_o_inicio.sql. Substitui a prova do
-- bloco 12, que conhecia a graficos() antiga.
-- ============================================================

create temporary table _prova_18 as
select id as meu_id from auth.users
where lower(email) = lower('pessoa1@exemplo.com');   -- <<< TROQUE AQUI

select set_config(
  'request.jwt.claims',
  json_build_object('sub', (select meu_id from _prova_18), 'role', 'authenticated')::text,
  false);
set role authenticated;

do $$
begin
  -- 1. Permissões.
  if has_function_privilege('anon', 'public.graficos()', 'EXECUTE') then
    raise exception 'anon executa graficos()';
  end if;

  -- 2. Todo mês da tela de histórico está nos gráficos, com a mesma conta.
  if exists (
    select 1 from public.historico_completo() h
     where not exists (
       select 1 from public.graficos() g
        where g.competencia = h.competencia and g.origem = h.origem
          and g.despesa_prevista = h.previsto and g.despesa_paga = h.pago
          and g.despesa_riscada = h.riscado and g.despesa_riscadas = h.riscadas)) then
    raise exception 'há mês do histórico que os gráficos contam diferente';
  end if;

  -- 3. Mês antigo não tem saldo; mês do app tem.
  if exists (select 1 from public.graficos() where origem = 'legado' and saldo is not null) then
    raise exception 'mês antigo com saldo';
  end if;
  if exists (select 1 from public.graficos() where origem = 'app' and saldo is null) then
    raise exception 'mês do app sem saldo';
  end if;

  -- 4. Receita nunca cai em linha do arquivo antigo.
  if exists (select 1 from public.graficos() where origem = 'legado' and receita_total <> 0) then
    raise exception 'receita do app somada a mês antigo';
  end if;

  -- 5. As receitas do app estão todas lá.
  if (select coalesce(sum(receita_total), 0) from public.graficos())
     <> (select coalesce(sum(total), 0) from public.receitas_mensais()) then
    raise exception 'receitas somem ou duplicam nos gráficos';
  end if;
end $$;

-- 6. Controle negativo: um id sem perfil não enxerga mês nenhum.
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-000000000000', 'role', 'authenticated')::text,
  false);
select 'controle_negativo' as parte, count(*) as meses from public.graficos();
-- esperado: 0

reset role;
select 'bloco 18 provado' as resultado;
