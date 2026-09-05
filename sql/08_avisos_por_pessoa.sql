-- ============================================================
-- Nossas Contas — bloco 7: cada um recebe o aviso que quer.
--
-- Até aqui o robô montava UMA mensagem por casa e mandava para todos os
-- aparelhos dela. Quem paga a maioria das contas quer só o aviso das 20h; o
-- Jonathan quer os três. Então o laço passa a ser por pessoa.
-- (Nome de familiar não entra no repositório — é regra do projeto.)
-- Idempotente.
-- ============================================================

-- ------------------------------------------------------------
-- 1. A preferência mora na PESSOA, não no aparelho.
-- ------------------------------------------------------------
-- Um aparelho é endereço de entrega; querer ou não querer é da pessoa. Assim
-- o iPhone e um eventual iPad da mesma pessoa seguem a mesma regra sozinhos.
--
-- Não precisa de política nova: perfil_editar_o_meu já deixa cada um mexer na
-- própria linha e só nela, e o with check já impede mudar de casa.
-- Padrão ligado: quem não quiser, desliga uma vez.

alter table public.perfil add column if not exists avisa_vespera_20h boolean not null default true;
alter table public.perfil add column if not exists avisa_dia_12h     boolean not null default true;
alter table public.perfil add column if not exists avisa_dia_20h     boolean not null default true;

-- ------------------------------------------------------------
-- 2. O resumo passa a enxergar o dia seguinte.
-- ------------------------------------------------------------
-- Uma função, três usos, como antes: o robô entra com a chave de serviço e vê
-- todas as casas; uma pessoa logada chama a MESMA função e a RLS a limita à
-- casa dela.
--
-- É drop e create, não "create or replace": mudar as colunas devolvidas muda o
-- tipo de retorno, e o Postgres não deixa substituir. Por isso os grants estão
-- repetidos logo abaixo — o drop leva as permissões junto.

drop function if exists public.resumo_do_dia(date);

create function public.resumo_do_dia(p_dia date default null)
returns table (
  casa_id        uuid,
  dia            date,
  vencem_hoje    int,
  valor_hoje     numeric,
  atrasadas      int,
  valor_atrasado numeric,
  sem_valor      int,
  titulos        text[],
  vencem_amanha  int,
  valor_amanha   numeric,
  titulos_amanha text[]
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
         -- "sem valor" continua sendo só do que já venceu: o de amanhã ainda
         -- tem o dia de hoje para ganhar valor.
         count(*) filter (where l.valor_previsto is null and l.vencimento <= d.hoje)::int,
         array_agg(l.descricao order by l.vencimento, l.descricao)
           filter (where l.vencimento = d.hoje),
         count(*) filter (where l.vencimento = d.hoje + 1)::int,
         coalesce(sum(l.valor_previsto) filter (where l.vencimento = d.hoje + 1), 0),
         array_agg(l.descricao order by l.descricao)
           filter (where l.vencimento = d.hoje + 1)
    from public.lancamento l
    cross join d
   where not l.pago
     and l.vencimento <= d.hoje + 1
   group by l.casa_id, d.hoje
$$;

revoke all on function public.resumo_do_dia(date) from public, anon;
grant execute on function public.resumo_do_dia(date) to authenticated, service_role;

-- Conferência: as três colunas novas no perfil, e a função devolvendo 11 colunas.
select (select count(*) from information_schema.columns
         where table_schema = 'public' and table_name = 'perfil'
           and column_name in ('avisa_vespera_20h','avisa_dia_12h','avisa_dia_20h')) as colunas_de_preferencia,
       (select count(*) from information_schema.columns
         where table_schema = 'public' and table_name = 'resumo_do_dia') as colunas_do_resumo;
