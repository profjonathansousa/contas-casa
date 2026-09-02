-- ============================================================
-- Nossas Contas — contas fixas (modelos recorrentes).
-- Resolve o problema de redigitar a lista toda no dia 1º.
-- Idempotente: pode rodar de novo.
-- ============================================================

create table if not exists public.modelo (
  id             uuid primary key default gen_random_uuid(),
  casa_id        uuid not null references public.casa(id) on delete cascade,
  descricao      text not null,
  dia_vencimento int  not null,
  valor_padrao   numeric(12,2),          -- NULO = valor muda todo mês ("???")
  ativo          boolean not null default true,
  criado_em      timestamptz not null default now(),
  atualizado_em  timestamptz not null default now(),

  constraint modelo_dia_ok        check (dia_vencimento between 1 and 31),
  constraint modelo_desc_nao_vazia check (length(btrim(descricao)) > 0),
  constraint modelo_valor_ok      check (valor_padrao is null or valor_padrao >= 0)
);

create index if not exists modelo_casa_idx on public.modelo (casa_id, dia_vencimento, descricao);

-- de onde veio cada lançamento gerado
do $$
begin
  alter table public.lancamento
    add constraint lancamento_modelo_fk
    foreign key (modelo_id) references public.modelo(id) on delete set null;
exception when duplicate_object then null;
end $$;

create or replace function public.tg_modelo()
returns trigger language plpgsql
set search_path = public
as $$
begin new.atualizado_em := now(); return new; end $$;

revoke all on function public.tg_modelo() from public, anon, authenticated;

drop trigger if exists modelo_antes_de_gravar on public.modelo;
create trigger modelo_antes_de_gravar
  before update on public.modelo
  for each row execute function public.tg_modelo();

-- ------------------------------------------------------------
-- RLS: mesma regra das outras tabelas, isolando por casa_id
-- ------------------------------------------------------------

alter table public.modelo enable row level security;
alter table public.modelo force  row level security;

drop policy if exists modelo_ler    on public.modelo;
drop policy if exists modelo_criar  on public.modelo;
drop policy if exists modelo_editar on public.modelo;
drop policy if exists modelo_apagar on public.modelo;

create policy modelo_ler    on public.modelo for select to authenticated
  using (casa_id = public.minha_casa());
create policy modelo_criar  on public.modelo for insert to authenticated
  with check (casa_id = public.minha_casa());
create policy modelo_editar on public.modelo for update to authenticated
  using (casa_id = public.minha_casa()) with check (casa_id = public.minha_casa());
create policy modelo_apagar on public.modelo for delete to authenticated
  using (casa_id = public.minha_casa());

revoke all on public.modelo from anon;
grant select, insert, update, delete on public.modelo to authenticated;

-- ------------------------------------------------------------
-- Gerar o mês a partir das contas fixas.
-- SECURITY INVOKER de propósito: a RLS continua valendo, então ninguém
-- gera mês na casa de outro.
-- Pula o que já está lá: comparação por descrição, não por modelo_id, para
-- não duplicar uma conta que a pessoa já digitou na mão.
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
    (casa_id, modelo_id, competencia, descricao, dia_vencimento, valor_previsto)
  select c, m.id, mes, m.descricao, m.dia_vencimento, m.valor_padrao
    from public.modelo m
   where m.casa_id = c
     and m.ativo
     and not exists (
       select 1 from public.lancamento l
        where l.casa_id = c and l.competencia = mes
          and lower(btrim(l.descricao)) = lower(btrim(m.descricao))
     );

  get diagnostics n = row_count;
  return n;
end $$;

-- ------------------------------------------------------------
-- Transformar as contas de um mês em contas fixas (para não cadastrar
-- as vinte à mão). Só pega o que ainda não virou modelo.
-- ------------------------------------------------------------

create or replace function public.fixar_mes(p_competencia date)
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

  with criados as (
    insert into public.modelo (casa_id, descricao, dia_vencimento, valor_padrao)
    select c, l.descricao, l.dia_vencimento, l.valor_previsto
      from public.lancamento l
     where l.casa_id = c and l.competencia = mes
       and not exists (
         select 1 from public.modelo m
          where m.casa_id = c
            and lower(btrim(m.descricao)) = lower(btrim(l.descricao))
       )
    returning id, descricao
  )
  update public.lancamento l
     set modelo_id = k.id
    from criados k
   where l.casa_id = c and l.competencia = mes and l.modelo_id is null
     and lower(btrim(l.descricao)) = lower(btrim(k.descricao));

  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public.gerar_mes(date), public.fixar_mes(date) from public, anon;
grant execute on function public.gerar_mes(date), public.fixar_mes(date) to authenticated;

do $$
begin alter publication supabase_realtime add table public.modelo;
exception when duplicate_object then null; end $$;
alter table public.modelo replica identity full;

-- conferência: 4 tabelas, todas com RLS
select relname as tabela, relrowsecurity as rls
from pg_class
where relnamespace = 'public'::regnamespace
  and relname in ('casa','perfil','lancamento','modelo')
order by relname;
