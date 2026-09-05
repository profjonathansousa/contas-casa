-- ============================================================
-- Nossas Contas — bloco 8: o código de pagamento colado.
--
-- O que NÃO é: busca automática de boletos pelo CPF. Isso é o DDA, operado
-- pela Nuclea, e o acesso é de instituição financeira — não de app doméstico.
-- O único caminho que não inverteria o modelo de risco deste projeto (entregar
-- credencial de banco a terceiro) é o Jonathan colar o código à mão.
--
-- O que É: guardar o código, ler dele o valor e o vencimento sem chamar
-- ninguém, e devolvê-lo com um toque na hora de pagar.
--
-- A sutileza que manda no desenho: a linha digitável do boleto MUDA TODO MÊS
-- (os 47 dígitos carregam fator de vencimento e valor). Então ela pertence ao
-- lançamento do mês, não à conta fixa. O que cabe na conta fixa é PIX
-- estático — chave sem valor —, que não muda: esse o gerar_mes copia sozinho.
-- Idempotente.
-- ============================================================

-- ------------------------------------------------------------
-- 1. No lançamento: o código daquele mês
-- ------------------------------------------------------------
alter table public.lancamento add column if not exists codigo_pagamento text;
alter table public.lancamento add column if not exists codigo_tipo      text;

do $$
begin
  alter table public.lancamento add constraint lancamento_codigo_tipo_ok
    check (codigo_tipo is null or codigo_tipo in ('boleto', 'arrecadacao', 'pix'));
exception when duplicate_object then null; end $$;

do $$
begin
  -- os dois andam juntos: código sem tipo não sabe ser lido, tipo sem código
  -- não é nada
  alter table public.lancamento add constraint lancamento_codigo_em_par
    check ((codigo_pagamento is null) = (codigo_tipo is null));
exception when duplicate_object then null; end $$;

-- ------------------------------------------------------------
-- 2. Na conta fixa: só o que não muda de mês
-- ------------------------------------------------------------
alter table public.modelo add column if not exists pix_estatico text;

-- ------------------------------------------------------------
-- 3. Gerar o mês já traz o PIX estático preenchido
-- ------------------------------------------------------------
create or replace function public.gerar_mes(p_competencia date)
returns int
language plpgsql
security invoker
set search_path = public
as $$
declare c uuid; mes date; n int;
begin
  c := public.minha_casa();
  if c is null then raise exception 'Você não pertence a nenhuma casa.'; end if;
  mes := date_trunc('month', p_competencia)::date;

  insert into public.lancamento
    (casa_id, modelo_id, competencia, descricao, dia_vencimento, valor_previsto,
     parcela_n, parcela_de, codigo_pagamento, codigo_tipo)
  select c, m.id, mes, m.descricao, m.dia_vencimento, m.valor_padrao,
         public.parcela_no_mes(m.parcelas_total, m.parcela_1, mes),
         m.parcelas_total,
         m.pix_estatico,
         case when m.pix_estatico is not null then 'pix' end
    from public.modelo m
   where m.casa_id = c
     and m.ativo
     and (m.parcelas_total is null
          or public.parcela_no_mes(m.parcelas_total, m.parcela_1, mes)
             between 1 and m.parcelas_total)
     and not exists (
       select 1 from public.lancamento l
        where l.casa_id = c and l.competencia = mes
          and lower(btrim(l.descricao)) = lower(btrim(m.descricao))
     );

  get diagnostics n = row_count;
  return n;
end $$;

-- ------------------------------------------------------------
-- 4. O aviso da véspera passa a saber quantas faltam preparar
-- ------------------------------------------------------------
-- É o pedido que originou este bloco: "conta x vencendo amanhã, cole o código
-- de pagamento no app". Sem esta contagem o aviso pediria o que já está feito.
-- Drop e create de novo: muda o tipo de retorno, e o drop leva os grants.

drop function if exists public.resumo_do_dia(date);

create function public.resumo_do_dia(p_dia date default null)
returns table (
  casa_id            uuid,
  dia                date,
  vencem_hoje        int,
  valor_hoje         numeric,
  atrasadas          int,
  valor_atrasado     numeric,
  sem_valor          int,
  titulos            text[],
  vencem_amanha      int,
  valor_amanha       numeric,
  titulos_amanha     text[],
  sem_codigo_amanha  int
)
language sql
stable
security invoker
set search_path = public
as $$
  with d as (
    select coalesce(p_dia, (now() at time zone 'America/Sao_Paulo')::date) as hoje
  )
  select l.casa_id,
         d.hoje,
         count(*) filter (where l.vencimento = d.hoje)::int,
         coalesce(sum(l.valor_previsto) filter (where l.vencimento = d.hoje), 0),
         count(*) filter (where l.vencimento < d.hoje)::int,
         coalesce(sum(l.valor_previsto) filter (where l.vencimento < d.hoje), 0),
         count(*) filter (where l.valor_previsto is null and l.vencimento <= d.hoje)::int,
         array_agg(l.descricao order by l.vencimento, l.descricao)
           filter (where l.vencimento = d.hoje),
         count(*) filter (where l.vencimento = d.hoje + 1)::int,
         coalesce(sum(l.valor_previsto) filter (where l.vencimento = d.hoje + 1), 0),
         array_agg(l.descricao order by l.descricao)
           filter (where l.vencimento = d.hoje + 1),
         count(*) filter (where l.vencimento = d.hoje + 1
                            and l.codigo_pagamento is null)::int
    from public.lancamento l
    cross join d
   where not l.pago
     and l.vencimento <= d.hoje + 1
   group by l.casa_id, d.hoje
$$;

revoke all on function public.resumo_do_dia(date) from public, anon;
grant execute on function public.resumo_do_dia(date) to authenticated, service_role;

-- Conferência: colunas novas, e a função devolvendo o campo do código.
select (select count(*) from information_schema.columns where table_schema='public'
          and table_name='lancamento' and column_name in ('codigo_pagamento','codigo_tipo')) as colunas_no_lancamento,
       (select count(*) from information_schema.columns where table_schema='public'
          and table_name='modelo' and column_name = 'pix_estatico')                          as pix_na_fixa;
