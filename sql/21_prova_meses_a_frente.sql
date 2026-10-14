-- ============================================================
-- Nossas Contas — PROVA do bloco 21 (manual, no SQL Editor).
--
-- Troque o e-mail abaixo pelo e-mail de login de uma das pessoas.
-- Rodar DEPOIS de sql/21_meses_a_frente.sql. Usa contas fixas de mentira
-- ("Prova ... 21") e termina em ROLLBACK: nada fica gravado — nem as marcas e
-- contas que o garantir_mes() criar aqui dentro. Se passar, a última linha
-- diz 'bloco 21 provado'; se não, para com a razão.
--
-- Os meses são relativos ao mês corrente de São Paulo (h = hoje, h1 = o mês
-- que vem...): a prova vale em qualquer mês em que for rodada.
-- ============================================================

begin;

select set_config('request.jwt.claims',
  json_build_object('sub', (select id from auth.users
                             where lower(email) = lower('pessoa1@exemplo.com')),   -- <<< TROQUE AQUI
                    'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare
  c   uuid := public.minha_casa();
  h   date := privado.mes_corrente();
  h1  date := (privado.mes_corrente() + interval '1 month')::date;
  h2  date := (privado.mes_corrente() + interval '2 months')::date;
  h3  date := (privado.mes_corrente() + interval '3 months')::date;
  h12 date := (privado.mes_corrente() + interval '12 months')::date;
  r record; fid uuid; fmao uuid; lid uuid; n int; k int; v numeric; a int[];
begin
  if c is null then raise exception '0: este e-mail não tem casa — troque o e-mail no topo'; end if;

  -- 0. a porta continua estreita
  if has_function_privilege('anon', 'public.garantir_mes()', 'EXECUTE') then
    raise exception '0: anon executa garantir_mes'; end if;
  if has_table_privilege('authenticated', 'public.mes_gerado', 'INSERT') then
    raise exception '0: authenticated insere em mes_gerado'; end if;
  if (select pronargs from pg_proc where oid = 'privado.marcar_meses()'::regprocedure) <> 0 then
    raise exception '0: marcar_meses aceita parâmetro'; end if;
  if to_regprocedure('privado.marcar_mes_corrente()') is not null then
    raise exception '0: a porta antiga continua aberta'; end if;

  -- 1. garantir_mes(): o corrente primeiro, depois os 12 seguintes, em ordem
  k := 0;
  for r in select * from public.garantir_mes() loop
    if r.competencia <> (h + make_interval(months => k))::date then
      raise exception '1: a linha % devolveu %', k, r.competencia; end if;
    k := k + 1;
  end loop;
  if k <> 13 then raise exception '1: devolveu % meses', k; end if;
  if (select count(*) from public.mes_gerado where competencia between h and h12) <> 13 then
    raise exception '1: faltou marca'; end if;
  if exists (select 1 from public.mes_gerado where competencia > h and origem <> 'antecipado') then
    raise exception '1: mês à frente sem origem antecipado'; end if;
  if exists (select 1 from public.mes_gerado where competencia > h12) then
    raise exception '1: passou do horizonte'; end if;
  -- de novo: nada nasce duas vezes
  if exists (select 1 from public.garantir_mes() g where g.criadas <> 0) then
    raise exception '1: gerou de novo'; end if;

  -- 2. os meses que nasceram AGORA têm toda fixa ativa que vale neles
  --    (só os de agora: num mês nascido antes, uma conta pode ter sido apagada
  --    de propósito, e aí faltar é o certo)
  if exists (
    select 1 from public.mes_gerado g join public.modelo m on m.casa_id = g.casa_id
     where g.competencia > h and g.gerado_em = now() and m.ativo
       and (m.parcelas_total is null
            or public.parcela_no_mes(m.parcelas_total, m.parcela_1, g.competencia)
               between 1 and m.parcelas_total)
       and not exists (select 1 from public.lancamento l
                        where l.casa_id = g.casa_id and l.competencia = g.competencia
                          and (l.modelo_id = m.id
                               or lower(btrim(l.descricao)) = lower(btrim(m.descricao))))
  ) then raise exception '2: fixa faltando num mês que acabou de nascer'; end if;
  -- e nenhuma parcela por pagar fora da janela, em mês nenhum à frente
  if exists (
    select 1 from public.lancamento l join public.modelo m on m.id = l.modelo_id
     where l.competencia > h and not l.pago and m.parcelas_total is not null
       and public.parcela_no_mes(m.parcelas_total, m.parcela_1, l.competencia)
           not between 1 and m.parcelas_total
  ) then raise exception '2: parcela fora da janela'; end if;

  -- 3. fixa nova entra nos 12 meses à frente, e NÃO no corrente (lá é o botão)
  insert into public.modelo (casa_id, descricao, dia_vencimento, valor_padrao)
  values (c, 'Prova Fixa 21', 10, 100) returning id into fid;
  select count(*) into n from public.lancamento where modelo_id = fid and competencia > h;
  if n <> 12 then raise exception '3: entrou em % meses', n; end if;
  if exists (select 1 from public.lancamento where modelo_id = fid and competencia <= h) then
    raise exception '3: entrou no mês corrente'; end if;
  if exists (select 1 from public.lancamento where modelo_id = fid
              and (valor_previsto <> 100 or dia_vencimento <> 10 or parcela_n is not null)) then
    raise exception '3: campos errados'; end if;

  -- 4. valor padrão novo: vale onde ainda era o antigo; o digitado fica; o apagado não volta
  update public.lancamento set valor_previsto = 150 where modelo_id = fid and competencia = h2;
  delete from public.lancamento where modelo_id = fid and competencia = h3;
  update public.modelo set valor_padrao = 120 where id = fid;
  select count(*) into n from public.lancamento where modelo_id = fid and valor_previsto = 120;
  if n <> 10 then raise exception '4: mudou em % meses', n; end if;
  select valor_previsto into v from public.lancamento where modelo_id = fid and competencia = h2;
  if v <> 150 then raise exception '4: passou por cima do valor digitado (%)', v; end if;
  if exists (select 1 from public.lancamento where modelo_id = fid and competencia = h3) then
    raise exception '4: o apagado voltou'; end if;

  -- 5. desligar: sai dos meses à frente, menos o que já foi pago
  update public.lancamento set pago = true where modelo_id = fid and competencia = h1;
  update public.modelo set ativo = false where id = fid;
  select count(*) into n from public.lancamento where modelo_id = fid;
  if n <> 1 or not (select pago from public.lancamento where modelo_id = fid) then
    raise exception '5: ficaram % contas', n; end if;

  -- 6. religar: volta para todos os meses à frente, sem duplicar o pago
  update public.modelo set ativo = true where id = fid;
  select count(*) into n from public.lancamento where modelo_id = fid and competencia > h;
  if n <> 12 then raise exception '6: voltou para % meses', n; end if;

  -- 7. virar parcelada, 4 vezes a partir do mês que vem: ficam 1 a 4, sai o resto
  update public.modelo set parcelas_total = 4, parcela_1 = h1 where id = fid;
  select array_agg(parcela_n order by competencia) into a from public.lancamento where modelo_id = fid;
  if a is distinct from array[1,2,3,4] then raise exception '7: ficou %', a; end if;
  if exists (select 1 from public.lancamento where modelo_id = fid and parcela_de <> 4) then
    raise exception '7: parcela_de errado'; end if;

  -- 8. esticar para 6: entram a 5ª e a 6ª — e a 3ª, apagada à mão, não volta
  delete from public.lancamento where modelo_id = fid and competencia = h3;
  update public.modelo set parcelas_total = 6 where id = fid;
  select array_agg(parcela_n order by competencia) into a from public.lancamento where modelo_id = fid;
  if a is distinct from array[1,2,4,5,6] then raise exception '8: ficou %', a; end if;
  if exists (select 1 from public.lancamento where modelo_id = fid and parcela_de <> 6) then
    raise exception '8: parcela_de errado'; end if;

  -- 9. apagar a fixa: saem as não pagas; a paga fica, já sem fixa
  delete from public.modelo where id = fid;
  select count(*) into n from public.lancamento where descricao = 'Prova Fixa 21';
  if n <> 1 then raise exception '9: ficaram % contas', n; end if;
  if (select modelo_id from public.lancamento where descricao = 'Prova Fixa 21') is not null then
    raise exception '9: a paga ficou ligada a uma fixa que não existe'; end if;

  -- 10. conta digitada à mão num mês à frente, com o mesmo nome: a fixa não duplica
  insert into public.lancamento (casa_id, competencia, descricao, dia_vencimento, valor_previsto)
  values (c, h2, 'Prova Mão 21', 5, 70);
  insert into public.modelo (casa_id, descricao, dia_vencimento, valor_padrao)
  values (c, '  prova mão 21 ', 5, 70) returning id into fmao;
  select count(*) into n from public.lancamento
   where competencia = h2 and lower(btrim(descricao)) = 'prova mão 21';
  if n <> 1 then raise exception '10: duplicou (% contas)', n; end if;
  select count(*) into n from public.lancamento where modelo_id = fmao;
  if n <> 11 then raise exception '10: entrou em % meses', n; end if;

  -- 11. parcelar uma conta do mês corrente: as próximas parcelas já aparecem
  insert into public.lancamento (casa_id, competencia, descricao, dia_vencimento, valor_previsto)
  values (c, h, 'Prova Acordo 21', 12, 250) returning id into lid;
  select * into r from public.parcelar_lancamento(lid, 5, (h - interval '1 month')::date);
  if r.parcela_n <> 2 or r.parcela_de <> 5 then raise exception '11: devolveu %', r; end if;
  select array_agg(parcela_n order by competencia) into a
    from public.lancamento where modelo_id = r.modelo_id and competencia > h;
  if a is distinct from array[3,4,5] then raise exception '11: à frente ficou %', a; end if;

  -- 12. fixa que já nasce desligada não entra em nada
  insert into public.modelo (casa_id, descricao, dia_vencimento, valor_padrao, ativo)
  values (c, 'Prova Desligada 21', 3, 10, false) returning id into fid;
  if exists (select 1 from public.lancamento where modelo_id = fid) then
    raise exception '12: fixa desligada entrou'; end if;

  -- 13. histórico e gráficos param no mês corrente — com receita à frente também
  insert into public.receita (casa_id, competencia, descricao, valor) values (c, h1, 'Prova Receita 21', 10);
  if exists (select 1 from public.historico() x where x.competencia > h) then
    raise exception '13: histórico tem mês à frente'; end if;
  if exists (select 1 from public.historico_completo() x where x.competencia > h) then
    raise exception '13: histórico completo tem mês à frente'; end if;
  if exists (select 1 from public.graficos() x where x.competencia > h) then
    raise exception '13: gráficos têm mês à frente'; end if;
  if not exists (select 1 from public.historico() x where x.competencia = h) then
    raise exception '13: o mês corrente sumiu do histórico'; end if;

  -- 14. o botão continua igual: gerar_mes() traz no mês corrente a fixa que falta
  perform public.gerar_mes(h);
  if not exists (select 1 from public.lancamento where modelo_id = fmao and competencia = h) then
    raise exception '14: o botão não trouxe a fixa nova para o mês corrente'; end if;
  if (select count(*) from public.lancamento where modelo_id = fmao) <> 12 then
    raise exception '14: o botão mexeu em outro mês'; end if;
end $$;

select 'bloco 21 provado' as resultado;
rollback;
