-- ============================================================
-- Nossas Contas — Fase 1
-- Schema + RLS. Rodar UMA vez, inteiro, no SQL Editor do Supabase.
-- É idempotente: pode rodar de novo sem quebrar nada.
-- ============================================================

-- ------------------------------------------------------------
-- 1. TABELAS
-- ------------------------------------------------------------

create table if not exists public.casa (
  id   uuid primary key default gen_random_uuid(),
  nome text not null
);

create table if not exists public.perfil (
  id      uuid primary key references auth.users(id) on delete cascade,
  casa_id uuid not null references public.casa(id) on delete cascade,
  nome    text not null
);

create index if not exists perfil_casa_idx on public.perfil (casa_id);

create table if not exists public.lancamento (
  id              uuid primary key default gen_random_uuid(),
  casa_id         uuid not null references public.casa(id) on delete cascade,
  modelo_id       uuid,                       -- sempre nulo na fase 1
  competencia     date not null,              -- sempre dia 1 do mês
  descricao       text not null,
  dia_vencimento  int  not null,
  vencimento      date not null,              -- calculado por trigger
  valor_previsto  numeric(12,2),              -- NULO = valor ainda desconhecido
  valor_pago      numeric(12,2),
  pago            boolean not null default false,
  pago_em         timestamptz,
  pago_por        uuid references public.perfil(id) on delete set null,
  observacao      text,
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now(),

  constraint competencia_dia_1  check (extract(day from competencia) = 1),
  constraint dia_vencimento_ok  check (dia_vencimento between 1 and 31),
  constraint descricao_nao_vazia check (length(btrim(descricao)) > 0),
  constraint valor_previsto_ok  check (valor_previsto is null or valor_previsto >= 0),
  constraint valor_pago_ok      check (valor_pago     is null or valor_pago     >= 0)
);

-- índice que serve exatamente a consulta da tela do mês
create index if not exists lancamento_mes_idx
  on public.lancamento (casa_id, competencia, dia_vencimento, descricao);

-- ------------------------------------------------------------
-- 2. FUNÇÕES DE APOIO
-- ------------------------------------------------------------

-- Casa do usuário logado.
-- SECURITY DEFINER de propósito: lê perfil ignorando RLS, senão a política
-- de perfil chamaria a si mesma (recursão infinita).
create or replace function public.minha_casa()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select casa_id from public.perfil where id = auth.uid()
$$;

revoke all on function public.minha_casa() from public;
grant execute on function public.minha_casa() to authenticated;

-- Data de vencimento real: dia pedido, limitado ao último dia do mês.
-- (dia 31 em fevereiro vira 28 ou 29 em vez de estourar)
create or replace function public.calc_vencimento(comp date, dia int)
returns date
language sql
immutable
as $$
  select comp + (
    least(dia, extract(day from (comp + interval '1 month' - interval '1 day'))::int) - 1
  )
$$;

-- ------------------------------------------------------------
-- 3. TRIGGERS
-- ------------------------------------------------------------

-- O cliente nunca escreve vencimento, pago_em, pago_por nem atualizado_em.
-- O banco preenche. Assim o toque único no celular manda só "pago = true"
-- e o selo de autoria não pode ser forjado.
create or replace function public.tg_lancamento()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.competencia := date_trunc('month', new.competencia)::date;
  new.vencimento  := public.calc_vencimento(new.competencia, new.dia_vencimento);

  if tg_op = 'INSERT' then
    new.criado_em     := now();
    new.atualizado_em := now();
    if new.pago then
      new.pago_em  := coalesce(new.pago_em, now());
      new.pago_por := coalesce(new.pago_por, auth.uid());
    else
      new.pago_em  := null;
      new.pago_por := null;
    end if;
  else
    new.criado_em     := old.criado_em;
    new.atualizado_em := now();
    if new.pago is distinct from old.pago then
      if new.pago then
        new.pago_em  := now();
        new.pago_por := auth.uid();
      else
        new.pago_em  := null;
        new.pago_por := null;
      end if;
    else
      new.pago_em  := old.pago_em;
      new.pago_por := old.pago_por;
    end if;
  end if;

  return new;
end
$$;

drop trigger if exists lancamento_antes_de_gravar on public.lancamento;
create trigger lancamento_antes_de_gravar
  before insert or update on public.lancamento
  for each row execute function public.tg_lancamento();

-- ------------------------------------------------------------
-- 4. RLS — ligado em TODAS as tabelas, isolando por casa_id
-- ------------------------------------------------------------

alter table public.casa       enable row level security;
alter table public.perfil     enable row level security;
alter table public.lancamento enable row level security;

alter table public.casa       force row level security;
alter table public.perfil     force row level security;
alter table public.lancamento force row level security;

-- casa: só leitura da própria casa. Criar casa é ato de administrador,
-- feito pelo SQL Editor (que roda como postgres e ignora RLS).
drop policy if exists casa_ler on public.casa;
create policy casa_ler on public.casa
  for select to authenticated
  using (id = public.minha_casa());

-- perfil: enxergo os perfis da minha casa (preciso do nome do outro para o selo).
drop policy if exists perfil_ler on public.perfil;
create policy perfil_ler on public.perfil
  for select to authenticated
  using (casa_id = public.minha_casa());

-- perfil: só posso mexer no meu próprio nome, e não posso me mudar de casa.
drop policy if exists perfil_editar_o_meu on public.perfil;
create policy perfil_editar_o_meu on public.perfil
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and casa_id = public.minha_casa());

-- lancamento: leitura, criação, edição e exclusão, sempre dentro da minha casa.
drop policy if exists lancamento_ler on public.lancamento;
create policy lancamento_ler on public.lancamento
  for select to authenticated
  using (casa_id = public.minha_casa());

drop policy if exists lancamento_criar on public.lancamento;
create policy lancamento_criar on public.lancamento
  for insert to authenticated
  with check (casa_id = public.minha_casa());

drop policy if exists lancamento_editar on public.lancamento;
create policy lancamento_editar on public.lancamento
  for update to authenticated
  using (casa_id = public.minha_casa())
  with check (casa_id = public.minha_casa());

drop policy if exists lancamento_apagar on public.lancamento;
create policy lancamento_apagar on public.lancamento
  for delete to authenticated
  using (casa_id = public.minha_casa());

-- ------------------------------------------------------------
-- 5. PERMISSÕES
-- ------------------------------------------------------------

revoke all on public.casa, public.perfil, public.lancamento from anon;

grant select                         on public.casa       to authenticated;
grant select, update                 on public.perfil     to authenticated;
grant select, insert, update, delete on public.lancamento to authenticated;

-- ------------------------------------------------------------
-- 6. REALTIME (a tela do outro muda sozinha)
-- ------------------------------------------------------------

alter table public.lancamento replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.lancamento;
exception
  when duplicate_object then null;
end
$$;

-- ============================================================
-- Fim. Se rodou sem erro, o banco está de pé.
-- Confira com a consulta abaixo: deve devolver 3 linhas, todas com rls = true.
-- ============================================================

select relname as tabela, relrowsecurity as rls
from pg_class
where relnamespace = 'public'::regnamespace
  and relname in ('casa','perfil','lancamento')
order by relname;
