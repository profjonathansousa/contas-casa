-- ============================================================
-- Nossas Contas — bloco 19: "Parcelar" direto na conta do mês.
--
-- Até aqui, dizer "sou 10 vezes a partir de julho" só era possível na tela de
-- contas fixas — e só para conta que já era fixa. Uma conta digitada à mão
-- no mês (o acordo novo, o material escolar) precisava virar fixa primeiro,
-- em outra tela. Agora ela se parcela de onde está.
--
-- Nenhuma entidade nova: parcelar é criar (ou reaproveitar) a conta fixa
-- dela, com a janela de parcelas, e ligar a conta do mês a essa fixa. Os meses
-- seguintes quem traz é o gerar_mes(), como sempre — e ele já sabe parar
-- quando a última parcela passa (bloco 9).
--
-- Tudo numa função só, security invoker: a fixa e a conta do mês mudam
-- juntas ou não mudam, e a RLS continua valendo, como em gerar_mes().
-- Idempotente: rodar de novo só recria a função.
-- ============================================================

create or replace function public.parcelar_lancamento(
  p_lancamento     uuid,
  p_parcelas_total int,
  p_parcela_1      date)
returns table (modelo_id uuid, parcela_n int, parcela_de int, criou_fixa boolean)
language plpgsql
security invoker
set search_path = public
as $$
declare
  c     uuid;
  l     public.lancamento%rowtype;
  m_id  uuid;
  mes1  date;
  n     int;
  pix   text;
  criou boolean := false;
begin
  c := public.minha_casa();
  if c is null then raise exception 'Você não pertence a nenhuma casa.'; end if;

  if p_parcelas_total is null or p_parcelas_total not between 1 and 360 then
    raise exception 'Quantas parcelas? Um número de 1 a 360.';
  end if;
  if p_parcela_1 is null then
    raise exception 'Falta o mês da primeira parcela.';
  end if;
  mes1 := date_trunc('month', p_parcela_1)::date;

  -- A RLS já esconde conta de outra casa; o casa_id aqui é a segunda parede.
  select * into l from public.lancamento
   where id = p_lancamento and casa_id = c
   for update;
  if not found then raise exception 'Não achei essa conta.'; end if;

  -- A conta do mês tem que caber na janela: parcelar "10 vezes a partir de
  -- janeiro" uma conta de dezembro seria dizer que ela é a 12ª de 10.
  n := public.parcela_no_mes(p_parcelas_total, mes1, l.competencia);
  if n < 1 or n > p_parcelas_total then
    raise exception 'Com esses números, a conta deste mês seria a parcela % de %, fora do intervalo. Confira o mês da primeira.',
      n, p_parcelas_total;
  end if;

  -- PIX estático é chave sem prazo: serve para todos os meses, então vai para
  -- a fixa. Boleto e conta de consumo mudam todo mês, e PIX dinâmico expira —
  -- ficam só neste mês. A regra é a mesma do lerPix() do app: o campo 01 do
  -- BR Code igual a 12 é cobrança dinâmica, e ele vem logo depois do 000201.
  if l.codigo_tipo = 'pix' and l.codigo_pagamento not like '000201010212%' then
    pix := l.codigo_pagamento;
  end if;

  -- Qual fixa: a que já está ligada; senão, a de mesma descrição (a mesma
  -- comparação que o gerar_mes() usa para não duplicar); senão, uma nova.
  if l.modelo_id is not null then
    select m.id into m_id from public.modelo m
     where m.id = l.modelo_id and m.casa_id = c for update;
  end if;
  if m_id is null then
    select m.id into m_id from public.modelo m
     where m.casa_id = c and lower(btrim(m.descricao)) = lower(btrim(l.descricao))
     order by m.ativo desc, m.criado_em
     limit 1
     for update;
  end if;

  if m_id is null then
    insert into public.modelo
      (casa_id, descricao, dia_vencimento, valor_padrao, ativo,
       parcelas_total, parcela_1, pix_estatico)
    values
      (c, btrim(l.descricao), l.dia_vencimento, l.valor_previsto, true,
       p_parcelas_total, mes1, pix)
    returning id into m_id;
    criou := true;
  else
    update public.modelo m
       set parcelas_total = p_parcelas_total,
           parcela_1      = mes1,
           ativo          = true,
           pix_estatico   = coalesce(pix, m.pix_estatico)
     where m.id = m_id;
  end if;

  -- Um modelo produz no máximo uma conta por mês (índice do bloco 11). Se já
  -- houver outra conta deste mês ligada a essa fixa, ligar esta também
  -- estouraria o índice com uma mensagem crua; melhor dizer o que é.
  if exists (select 1 from public.lancamento x
              where x.casa_id = c and x.competencia = l.competencia
                and x.modelo_id = m_id and x.id <> l.id) then
    raise exception 'Já existe outra conta deste mês ligada à conta fixa "%".', btrim(l.descricao);
  end if;

  update public.lancamento x
     set modelo_id  = m_id,
         parcela_n  = n,
         parcela_de = p_parcelas_total
   where x.id = l.id;

  return query select m_id, n, p_parcelas_total, criou;
end $$;

revoke all    on function public.parcelar_lancamento(uuid, int, date) from public, anon;
grant execute on function public.parcelar_lancamento(uuid, int, date) to authenticated;

-- Conferência
select p.proname as funcao,
       p.prosecdef as security_definer,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_executa,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_executa
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace and p.proname = 'parcelar_lancamento';
-- esperado: f | p_lancamento uuid, p_parcelas_total integer, p_parcela_1 date | f | t
