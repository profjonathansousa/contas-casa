-- ============================================================
-- Nossas Contas — bloco 14: receitas.
--
-- Receita NÃO é lançamento negativo. É uma tabela separada, com sua própria
-- RLS, trigger de autoria e resumo mensal. O bloco 13 continua intocado:
-- public.historico() segue sendo exclusivamente o histórico de despesas.
--
-- Idempotente: pode rodar de novo sem quebrar o que já existe.
-- ============================================================

-- ------------------------------------------------------------
-- 1. A tabela de receitas
-- ------------------------------------------------------------

create table if not exists public.receita (
  id            uuid primary key default gen_random_uuid(),
  casa_id       uuid not null references public.casa(id) on delete cascade,
  competencia   date not null,
  descricao     text not null,
  valor         numeric(12,2) not null,
  recebido      boolean not null default false,
  recebido_em   timestamptz,
  recebido_por  uuid references public.perfil(id) on delete set null,
  observacao    text,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),

  constraint receita_competencia_dia_1
    check (extract(day from competencia) = 1),
  constraint receita_descricao_nao_vazia
    check (length(btrim(descricao)) > 0),
  constraint receita_valor_ok
    check (valor >= 0)
);

create index if not exists receita_casa_comp_idx
  on public.receita (casa_id, competencia, descricao);

-- ------------------------------------------------------------
-- 2. Trigger: o banco decide competência, timestamps e autoria
-- ------------------------------------------------------------
-- Mesmo princípio de public.tg_lancamento(): o cliente manda só o que a
-- pessoa realmente decide. Quem grava recebido_em e recebido_por é o banco.

create or replace function public.tg_receita()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.competencia := date_trunc('month', new.competencia)::date;

  if tg_op = 'INSERT' then
    new.criado_em     := now();
    new.atualizado_em := now();

    if new.recebido then
      new.recebido_em  := now();
      new.recebido_por := auth.uid();
    else
      new.recebido_em  := null;
      new.recebido_por := null;
    end if;
  else
    new.criado_em     := old.criado_em;
    new.atualizado_em := now();

    if new.recebido is distinct from old.recebido then
      if new.recebido then
        new.recebido_em  := now();
        new.recebido_por := auth.uid();
      else
        new.recebido_em  := null;
        new.recebido_por := null;
      end if;
    else
      new.recebido_em  := old.recebido_em;
      new.recebido_por := old.recebido_por;
    end if;
  end if;

  return new;
end
$$;

-- A função de trigger não é endpoint. Sem este revoke, ela apareceria em
-- /rest/v1/rpc/tg_receita como SECURITY DEFINER chamável por qualquer papel.
revoke all on function public.tg_receita() from public, anon, authenticated;

drop trigger if exists receita_antes_de_gravar on public.receita;
create trigger receita_antes_de_gravar
  before insert or update on public.receita
  for each row execute function public.tg_receita();

-- ------------------------------------------------------------
-- 3. RLS: só a própria casa
-- ------------------------------------------------------------

alter table public.receita enable row level security;
alter table public.receita force  row level security;

drop policy if exists receita_ler    on public.receita;
drop policy if exists receita_criar  on public.receita;
drop policy if exists receita_editar on public.receita;
drop policy if exists receita_apagar on public.receita;

create policy receita_ler    on public.receita for select to authenticated
  using (casa_id = public.minha_casa());
create policy receita_criar  on public.receita for insert to authenticated
  with check (casa_id = public.minha_casa());
create policy receita_editar on public.receita for update to authenticated
  using (casa_id = public.minha_casa())
  with check (casa_id = public.minha_casa());
create policy receita_apagar on public.receita for delete to authenticated
  using (casa_id = public.minha_casa());

revoke all on public.receita from anon;
grant select, insert, update, delete on public.receita to authenticated;

-- ------------------------------------------------------------
-- 4. Realtime
-- ------------------------------------------------------------

alter table public.receita replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.receita;
exception
  when duplicate_object then null;
end
$$;

-- ------------------------------------------------------------
-- 5. Resumo mensal de receitas
-- ------------------------------------------------------------
-- Security invoker, sem parâmetro: a RLS limita à casa de quem chama.

create or replace function public.receitas_mensais()
returns table (
  competencia date,
  total       numeric,
  recebido    numeric,
  a_receber   numeric,
  contas      bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  select r.competencia,
         coalesce(sum(r.valor), 0) as total,
         coalesce(sum(r.valor) filter (where r.recebido), 0) as recebido,
         coalesce(sum(r.valor) filter (where not r.recebido), 0) as a_receber,
         count(*) as contas
    from public.receita r
   group by r.competencia
   order by r.competencia desc;
$$;

revoke all on function public.receitas_mensais() from public, anon;
grant execute on function public.receitas_mensais() to authenticated;

-- ------------------------------------------------------------
-- Conferência
-- ------------------------------------------------------------

select 'receita_rls' as parte,
       c.relrowsecurity as ligada,
       c.relforcerowsecurity as forcada,
       (select array_agg(polname order by polname) from pg_policy
         where polrelid = c.oid) as politicas
  from pg_class c
 where c.oid = 'public.receita'::regclass;

select 'receitas_mensais' as parte,
       p.prosecdef as security_definer,
       p.provolatile as volatilidade,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       has_function_privilege('anon', 'public.receitas_mensais()', 'EXECUTE') as anon_executa,
       has_function_privilege('authenticated', 'public.receitas_mensais()', 'EXECUTE') as authenticated_executa
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname = 'receitas_mensais';
