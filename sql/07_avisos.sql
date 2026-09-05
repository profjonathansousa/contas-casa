-- ============================================================
-- Nossas Contas — bloco 6: registro de aviso enviado.
--
-- Por que isto existe: o cron do GitHub atrasa horas, não minutos (medido
-- neste projeto: de 3h35 a 4h15, todo dia). A saída é rodar de hora em hora e
-- deixar o robô decidir, pelo relógio de Brasília, qual aviso está aberto.
-- Só que aí ele passaria a mandar o mesmo aviso a cada hora. Esta tabela é a
-- memória que impede isso: um aviso por casa, por dia e por slot.
--
-- Ninguém do app lê nem escreve aqui. RLS ligada e forçada, sem política
-- nenhuma e sem grant nenhum: só o robô, que entra com a chave de serviço.
-- Idempotente.
-- ============================================================

create table if not exists public.aviso_enviado (
  id         uuid primary key default gen_random_uuid(),
  casa_id    uuid not null references public.casa(id)   on delete cascade,
  -- Nulo enquanto o aviso é da casa inteira. O bloco 7, que manda coisa
  -- diferente para cada pessoa, passa a preencher.
  perfil_id  uuid          references public.perfil(id) on delete cascade,
  -- Dia de Brasília, não de UTC: a repescagem do aviso das 20h cai depois da
  -- meia-noite em UTC e ainda é o mesmo dia aqui.
  dia        date not null,
  slot       text not null,
  enviado_em timestamptz not null default now(),

  constraint aviso_slot_ok check (slot in ('vespera_20h', 'dia_12h', 'dia_20h'))
);

-- coalesce no índice porque, em índice único, nulo não é igual a nulo — e sem
-- isto a linha de casa inteira poderia entrar duas vezes.
create unique index if not exists aviso_enviado_uma_vez
  on public.aviso_enviado
     (casa_id, coalesce(perfil_id, '00000000-0000-0000-0000-000000000000'::uuid), dia, slot);

create index if not exists aviso_enviado_dia_idx on public.aviso_enviado (dia, slot);

alter table public.aviso_enviado enable row level security;
alter table public.aviso_enviado force  row level security;

revoke all on public.aviso_enviado from public, anon, authenticated;

-- Conferência: tem que voltar 1 linha, com rls = true e 0 políticas.
select c.relname as tabela,
       c.relrowsecurity as rls,
       (select count(*) from pg_policies p
         where p.schemaname = 'public' and p.tablename = 'aviso_enviado') as politicas
from pg_class c
where c.relnamespace = 'public'::regnamespace
  and c.relname = 'aviso_enviado';
