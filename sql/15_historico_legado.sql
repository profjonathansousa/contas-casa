-- ============================================================
-- Nossas Contas — bloco 15: histórico legado.
--
-- O histórico antigo NÃO vira modelo, NÃO vira lançamento corrente e NÃO
-- participa da geração automática. Ele fica em tabelas próprias, somente
-- leitura para o app, e é importado por uma função controlada no schema
-- privado.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Despesas históricas
-- ------------------------------------------------------------

create table if not exists public.historico_legado (
  id             uuid primary key default gen_random_uuid(),
  casa_id        uuid not null references public.casa(id) on delete cascade,
  competencia    date not null,
  dia            int,
  descricao      text not null,
  valor          numeric(12,2),
  pago           boolean not null default false,
  riscado        boolean not null default false,
  observacao     text,
  parcela_n      int,
  parcela_de     int,
  origem         text not null default 'legado_markdown',
  linha_original text not null,
  ordem_original int not null,
  criado_em      timestamptz not null default now(),
  importado_em   timestamptz not null default now(),

  constraint historico_legado_competencia_dia_1
    check (extract(day from competencia) = 1),
  constraint historico_legado_dia_ok
    check (dia is null or dia between 1 and 31),
  constraint historico_legado_descricao_nao_vazia
    check (length(btrim(descricao)) > 0),
  constraint historico_legado_valor_ok
    check (valor is null or valor >= 0),
  constraint historico_legado_parcelas_ok
    check (parcela_n is null
           or (parcela_n >= 1 and parcela_de is not null and parcela_de >= 1))
);

create index if not exists historico_legado_casa_comp_idx
  on public.historico_legado (casa_id, competencia, ordem_original);

-- ------------------------------------------------------------
-- 2. Receitas históricas
-- ------------------------------------------------------------

create table if not exists public.historico_legado_receita (
  id             uuid primary key default gen_random_uuid(),
  casa_id        uuid not null references public.casa(id) on delete cascade,
  competencia    date not null,
  dia            int,
  descricao      text not null,
  valor          numeric(12,2),
  recebido       boolean not null default true,
  observacao     text,
  origem         text not null default 'legado_markdown',
  linha_original text not null,
  ordem_original int not null,
  criado_em      timestamptz not null default now(),
  importado_em   timestamptz not null default now(),

  constraint historico_legado_receita_competencia_dia_1
    check (extract(day from competencia) = 1),
  constraint historico_legado_receita_dia_ok
    check (dia is null or dia between 1 and 31),
  constraint historico_legado_receita_descricao_nao_vazia
    check (length(btrim(descricao)) > 0),
  constraint historico_legado_receita_valor_ok
    check (valor is null or valor >= 0)
);

create index if not exists historico_legado_receita_casa_comp_idx
  on public.historico_legado_receita (casa_id, competencia, ordem_original);

-- ------------------------------------------------------------
-- 3. Totais, resumos e blocos que não são lançamentos
-- ------------------------------------------------------------

create table if not exists public.historico_legado_resumo (
  id             uuid primary key default gen_random_uuid(),
  casa_id        uuid not null references public.casa(id) on delete cascade,
  competencia    date not null,
  secao          text not null,
  texto          text not null,
  valor          numeric(12,2),
  origem         text not null default 'legado_markdown',
  linha_original text not null,
  ordem_original int not null,
  criado_em      timestamptz not null default now(),
  importado_em   timestamptz not null default now(),

  constraint historico_legado_resumo_competencia_dia_1
    check (extract(day from competencia) = 1),
  constraint historico_legado_resumo_secao_nao_vazia
    check (length(btrim(secao)) > 0),
  constraint historico_legado_resumo_texto_nao_vazio
    check (length(btrim(texto)) > 0),
  constraint historico_legado_resumo_valor_ok
    check (valor is null or valor >= 0)
);

create index if not exists historico_legado_resumo_casa_comp_idx
  on public.historico_legado_resumo (casa_id, competencia, ordem_original);

-- ------------------------------------------------------------
-- 4. RLS: o app só lê, e só a própria casa
-- ------------------------------------------------------------

alter table public.historico_legado enable row level security;
alter table public.historico_legado force  row level security;
alter table public.historico_legado_receita enable row level security;
alter table public.historico_legado_receita force  row level security;
alter table public.historico_legado_resumo enable row level security;
alter table public.historico_legado_resumo force  row level security;

drop policy if exists historico_legado_ler on public.historico_legado;
create policy historico_legado_ler on public.historico_legado
  for select to authenticated
  using (casa_id = public.minha_casa());

drop policy if exists historico_legado_receita_ler on public.historico_legado_receita;
create policy historico_legado_receita_ler on public.historico_legado_receita
  for select to authenticated
  using (casa_id = public.minha_casa());

drop policy if exists historico_legado_resumo_ler on public.historico_legado_resumo;
create policy historico_legado_resumo_ler on public.historico_legado_resumo
  for select to authenticated
  using (casa_id = public.minha_casa());

-- Apenas leitura para o app. A escrita é feita pela função do item 5.
revoke all on public.historico_legado,
             public.historico_legado_receita,
             public.historico_legado_resumo
  from anon, authenticated;

grant select on public.historico_legado,
                public.historico_legado_receita,
                public.historico_legado_resumo
  to authenticated;

-- ------------------------------------------------------------
-- 5. Importador controlado
-- ------------------------------------------------------------
-- Recebe JSONB e grava nas três tabelas. Fica fora do public, sem EXECUTE
-- para anon/authenticated: o carregamento real é feito por um operador com
-- acesso ao banco, nunca pelo app.

create or replace function privado.importar_historico_legado(
  p_casa_id uuid,
  p_itens   jsonb
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
  comp date;
  n int := 0;
begin
  if p_casa_id is null then
    raise exception 'casa_id é obrigatório';
  end if;

  if not exists (select 1 from public.casa where id = p_casa_id) then
    raise exception 'casa não existe';
  end if;

  for item in select * from jsonb_array_elements(p_itens) loop
    comp := date_trunc('month', (item->>'competencia')::date)::date;

    case item->>'tipo'
      when 'despesa' then
        insert into public.historico_legado
          (casa_id, competencia, dia, descricao, valor, pago, riscado,
           observacao, parcela_n, parcela_de, linha_original, ordem_original)
        values
          (p_casa_id, comp,
           nullif(item->>'dia', '')::int,
           item->>'descricao',
           nullif(item->>'valor', '')::numeric,
           coalesce((item->>'pago')::boolean, false),
           coalesce((item->>'riscado')::boolean, false),
           nullif(item->>'observacao', ''),
           nullif(item->>'parcela_n', '')::int,
           nullif(item->>'parcela_de', '')::int,
           item->>'linha_original',
           (item->>'ordem')::int);

      when 'receita' then
        insert into public.historico_legado_receita
          (casa_id, competencia, dia, descricao, valor, recebido,
           observacao, linha_original, ordem_original)
        values
          (p_casa_id, comp,
           nullif(item->>'dia', '')::int,
           item->>'descricao',
           nullif(item->>'valor', '')::numeric,
           coalesce((item->>'recebido')::boolean, true),
           nullif(item->>'observacao', ''),
           item->>'linha_original',
           (item->>'ordem')::int);

      when 'resumo' then
        insert into public.historico_legado_resumo
          (casa_id, competencia, secao, texto, valor, linha_original,
           ordem_original)
        values
          (p_casa_id, comp,
           item->>'secao',
           item->>'texto',
           nullif(item->>'valor', '')::numeric,
           item->>'linha_original',
           (item->>'ordem')::int);

      else
        raise exception 'tipo desconhecido: %', item->>'tipo';
    end case;

    n := n + 1;
  end loop;

  return n;
end
$$;

revoke all on function privado.importar_historico_legado(uuid, jsonb)
  from public, anon, authenticated;

-- ------------------------------------------------------------
-- Conferência
-- ------------------------------------------------------------

select c.relname as tabela,
       c.relrowsecurity as rls,
       c.relforcerowsecurity as forcada
  from pg_class c
 where c.relnamespace = 'public'::regnamespace
   and c.relname in
     ('historico_legado','historico_legado_receita','historico_legado_resumo')
 order by c.relname;

select p.proname as funcao,
       p.prosecdef as security_definer,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       has_function_privilege('anon', 'privado.importar_historico_legado(uuid,jsonb)', 'EXECUTE') as anon_executa,
       has_function_privilege('authenticated', 'privado.importar_historico_legado(uuid,jsonb)', 'EXECUTE') as auth_executa
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'privado'
   and p.proname = 'importar_historico_legado';
