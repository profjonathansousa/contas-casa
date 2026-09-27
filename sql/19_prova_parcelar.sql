-- ============================================================
-- Nossas Contas — PROVA do bloco 19 (manual, no SQL Editor).
--
-- Troque o e-mail abaixo pelo e-mail de login de uma das pessoas.
-- Rodar DEPOIS de sql/19_parcelar_lancamento.sql. Usa contas de mentira em
-- 2030 e termina em ROLLBACK: nada fica gravado. Se passar, a última linha
-- diz 'bloco 19 provado'; se não, para com a razão.
-- ============================================================

begin;

select set_config('request.jwt.claims',
  json_build_object('sub', (select id from auth.users
                             where lower(email) = lower('pessoa1@exemplo.com')),   -- <<< TROQUE AQUI
                    'role', 'authenticated')::text, true);
set local role authenticated;

do $$
declare c uuid := public.minha_casa(); lid uuid; r record; mm record; x record; n_mod_antes int; ok boolean;
begin
  if has_function_privilege('anon', 'public.parcelar_lancamento(uuid,int,date)', 'EXECUTE') then
    raise exception 'anon executa parcelar_lancamento';
  end if;

  -- 1. conta à mão em mar/2030, 10x desde jan/2030 -> parcela 3/10, fixa nova
  insert into public.lancamento (casa_id, competencia, descricao, dia_vencimento, valor_previsto)
  values (c, '2030-03-01', 'Prova Acordo', 12, 250) returning id into lid;
  select * into r from public.parcelar_lancamento(lid, 10, '2030-01-17');
  if r.parcela_n <> 3 or r.parcela_de <> 10 or not r.criou_fixa then raise exception '1: devolveu %', r; end if;
  select * into mm from public.modelo where id = r.modelo_id;
  if mm.parcelas_total <> 10 or mm.parcela_1 <> '2030-01-01' or not mm.ativo or mm.valor_padrao <> 250
     or mm.dia_vencimento <> 12 or mm.pix_estatico is not null then raise exception '1: fixa %', mm; end if;
  select * into x from public.lancamento where id = lid;
  if x.modelo_id <> r.modelo_id or x.parcela_n <> 3 or x.parcela_de <> 10 then raise exception '1: conta %', x; end if;

  -- 2. o gerar_mes() traz abril como 4/10, e nada depois da 10ª
  perform public.gerar_mes('2030-04-01');
  select * into x from public.lancamento where competencia = '2030-04-01' and modelo_id = r.modelo_id;
  if x.parcela_n is distinct from 4 or x.parcela_de is distinct from 10 then raise exception '2: abril %', x; end if;
  perform public.gerar_mes('2030-11-01');
  if exists (select 1 from public.lancamento where competencia = '2030-11-01' and modelo_id = r.modelo_id) then
    raise exception '2: veio depois da última'; end if;

  -- 3. parcelar de novo a mesma conta não cria outra fixa
  select count(*) into n_mod_antes from public.modelo;
  select * into r from public.parcelar_lancamento(lid, 12, '2030-02-01');
  if r.criou_fixa or r.parcela_n <> 2 or (select count(*) from public.modelo) <> n_mod_antes then raise exception '3: %', r; end if;

  -- 4. fixa desligada de mesma descrição (maiúscula e espaço) é reaproveitada e religada
  insert into public.modelo (casa_id, descricao, dia_vencimento, valor_padrao, ativo) values (c, 'Prova Material', 5, 80, false);
  insert into public.lancamento (casa_id, competencia, descricao, dia_vencimento, valor_previsto)
  values (c, '2030-03-01', '  prova material ', 5, 80) returning id into lid;
  select count(*) into n_mod_antes from public.modelo;
  select * into r from public.parcelar_lancamento(lid, 3, '2030-03-01');
  if r.criou_fixa or (select count(*) from public.modelo) <> n_mod_antes
     or not (select ativo from public.modelo where id = r.modelo_id) then raise exception '4: %', r; end if;

  -- 5. PIX estático vai para a fixa; dinâmico (campo 01 = 12) não
  insert into public.lancamento (casa_id, competencia, descricao, dia_vencimento, valor_previsto, codigo_pagamento, codigo_tipo)
  values (c, '2030-03-01', 'Prova PIX fixo', 7, 50, '00020101021126360014br.gov.bcb.pix0114prova6304ABCD', 'pix') returning id into lid;
  select * into r from public.parcelar_lancamento(lid, 5, '2030-03-01');
  if (select pix_estatico from public.modelo where id = r.modelo_id) is null then raise exception '5: estático não copiado'; end if;
  insert into public.lancamento (casa_id, competencia, descricao, dia_vencimento, valor_previsto, codigo_pagamento, codigo_tipo)
  values (c, '2030-03-01', 'Prova PIX cobranca', 7, 50, '00020101021226360014br.gov.bcb.pix0114prova6304ABCD', 'pix') returning id into lid;
  select * into r from public.parcelar_lancamento(lid, 5, '2030-03-01');
  if (select pix_estatico from public.modelo where id = r.modelo_id) is not null then raise exception '5: dinâmico copiado'; end if;

  -- 6. controles negativos
  ok := false; begin perform public.parcelar_lancamento(lid, 5, '2030-04-01'); exception when others then ok := sqlerrm like '%fora do intervalo%'; end;
  if not ok then raise exception '6a: primeira depois da conta passou'; end if;
  ok := false; begin perform public.parcelar_lancamento(lid, 2, '2029-12-01'); exception when others then ok := sqlerrm like '%parcela 4 de 2%'; end;
  if not ok then raise exception '6b: conta depois da última passou'; end if;
  ok := false; begin perform public.parcelar_lancamento(lid, 0, '2030-03-01'); exception when others then ok := sqlerrm like 'Quantas parcelas%'; end;
  if not ok then raise exception '6c: zero parcelas passou'; end if;
  ok := false; begin perform public.parcelar_lancamento(gen_random_uuid(), 5, '2030-03-01'); exception when others then ok := sqlerrm like 'Não achei%'; end;
  if not ok then raise exception '6d: conta inexistente passou'; end if;

  -- 7. duas contas do mesmo mês na mesma fixa: recusa com mensagem clara
  insert into public.lancamento (casa_id, competencia, descricao, dia_vencimento, valor_previsto)
  values (c, '2030-03-01', 'Prova Acordo', 12, 250) returning id into lid;
  ok := false; begin perform public.parcelar_lancamento(lid, 10, '2030-01-01'); exception when others then ok := sqlerrm like 'Já existe outra conta%'; end;
  if not ok then raise exception '7: duplicou na fixa'; end if;
end $$;

select 'bloco 19 provado' as resultado;
rollback;
