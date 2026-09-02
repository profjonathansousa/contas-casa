-- ============================================================
-- Nossas Contas — fase 2, parte 1: inscrições de notificação.
-- Idempotente.
-- ============================================================

create table if not exists public.push_inscricao (
  id            uuid primary key default gen_random_uuid(),
  casa_id       uuid not null references public.casa(id)   on delete cascade,
  perfil_id     uuid not null references public.perfil(id) on delete cascade,
  endpoint      text not null unique,       -- endereço que o navegador dá
  p256dh        text not null,              -- chaves da criptografia da mensagem
  auth          text not null,
  aparelho      text,                       -- só para a pessoa se reconhecer
  criado_em     timestamptz not null default now(),
  ultimo_envio  timestamptz,
  falhas        int not null default 0,
  ultimo_erro   text
);

create index if not exists push_casa_idx on public.push_inscricao (casa_id);

alter table public.push_inscricao enable row level security;
alter table public.push_inscricao force  row level security;

-- Cada pessoa manda só nas inscrições dos próprios aparelhos.
drop policy if exists push_ler    on public.push_inscricao;
drop policy if exists push_criar  on public.push_inscricao;
drop policy if exists push_editar on public.push_inscricao;
drop policy if exists push_apagar on public.push_inscricao;

create policy push_ler    on public.push_inscricao for select to authenticated
  using (perfil_id = auth.uid());
create policy push_criar  on public.push_inscricao for insert to authenticated
  with check (perfil_id = auth.uid() and casa_id = public.minha_casa());
-- O with check repete o casa_id de propósito: sem ele, alguém podia apontar
-- a própria inscrição para outra casa e passar a receber o resumo diário
-- dela. O insert já cobrava isso; o update não cobrava.
create policy push_editar on public.push_inscricao for update to authenticated
  using (perfil_id = auth.uid())
  with check (perfil_id = auth.uid() and casa_id = public.minha_casa());
create policy push_apagar on public.push_inscricao for delete to authenticated
  using (perfil_id = auth.uid());

revoke all on public.push_inscricao from anon;
grant select, insert, update, delete on public.push_inscricao to authenticated;

-- ------------------------------------------------------------
-- O que o aviso diário precisa saber, por casa.
--
-- SECURITY INVOKER de propósito: o robô do agendador entra com a chave de
-- serviço e enxerga todas as casas; uma pessoa logada chama a MESMA função e
-- a RLS a limita à casa dela. Uma função, dois usos, nenhum furo.
-- ------------------------------------------------------------

create or replace function public.resumo_do_dia(p_dia date default null)
returns table (
  casa_id        uuid,
  dia            date,
  vencem_hoje    int,
  valor_hoje     numeric,
  atrasadas      int,
  valor_atrasado numeric,
  sem_valor      int,
  titulos        text[]
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
         count(*) filter (where l.valor_previsto is null)::int,
         array_agg(l.descricao order by l.vencimento, l.descricao)
           filter (where l.vencimento = d.hoje)
    from public.lancamento l
    cross join d
   where not l.pago
     and l.vencimento <= d.hoje
   group by l.casa_id, d.hoje
$$;

revoke all on function public.resumo_do_dia(date) from public, anon;
grant execute on function public.resumo_do_dia(date) to authenticated, service_role;

select relname as tabela, relrowsecurity as rls
from pg_class
where relnamespace = 'public'::regnamespace
  and relname in ('casa','perfil','lancamento','modelo','push_inscricao')
order by relname;
