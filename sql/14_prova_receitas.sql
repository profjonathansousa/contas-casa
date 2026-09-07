-- ============================================================
-- Nossas Contas — PROVA do bloco 14.
--
-- Rodar DEPOIS de sql/14_receitas.sql.
-- Nada persiste: as receitas de prova são inseridas dentro de uma transação
-- e desfeitas no final. As verificações de metadados rodam como postgres;
-- as verificações de RLS/autoria rodam como authenticated.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Metadados, grants e RLS (como postgres, antes de trocar de role)
-- ------------------------------------------------------------

select 'tabela_receita' as parte,
       to_regclass('public.receita') is not null as existe,
       (select count(*) from information_schema.columns
         where table_schema = 'public'
           and table_name = 'receita'
           and column_name in
             ('id','casa_id','competencia','descricao','valor','recebido',
              'recebido_em','recebido_por','observacao','criado_em','atualizado_em'))
         as colunas_esperadas;
-- esperado: t | 11

select 'rls_receita' as parte,
       c.relrowsecurity       as ligada,
       c.relforcerowsecurity  as forcada,
       (select array_agg(polname order by polname) from pg_policy
         where polrelid = c.oid) as politicas
  from pg_class c
 where c.oid = 'public.receita'::regclass;
-- esperado: t | t | {receita_apagar,receita_criar,receita_editar,receita_ler}

select 'grants_receita' as parte,
       has_table_privilege('anon', 'public.receita', 'SELECT') as anon_select,
       has_table_privilege('anon', 'public.receita', 'INSERT') as anon_insert,
       has_table_privilege('anon', 'public.receita', 'UPDATE') as anon_update,
       has_table_privilege('anon', 'public.receita', 'DELETE') as anon_delete,
       has_table_privilege('authenticated', 'public.receita', 'SELECT') as auth_select,
       has_table_privilege('authenticated', 'public.receita', 'INSERT') as auth_insert,
       has_table_privilege('authenticated', 'public.receita', 'UPDATE') as auth_update,
       has_table_privilege('authenticated', 'public.receita', 'DELETE') as auth_delete;
-- esperado: f | f | f | f | t | t | t | t

select 'rpc_receitas_mensais' as parte,
       p.prosecdef                                     as security_definer,
       p.provolatile                                   as volatilidade,
       pg_get_function_identity_arguments(p.oid)       as argumentos,
       p.proconfig                                     as search_path,
       has_function_privilege('anon', 'public.receitas_mensais()', 'EXECUTE')
                                                       as anon_executa,
       has_function_privilege('authenticated', 'public.receitas_mensais()', 'EXECUTE')
                                                       as auth_executa
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname = 'receitas_mensais';
-- esperado: f | s | (vazio) | {search_path=public} | f | t

select 'trigger_receita' as parte,
       has_function_privilege('anon', 'public.tg_receita()', 'EXECUTE') as anon_executa,
       has_function_privilege('authenticated', 'public.tg_receita()', 'EXECUTE') as auth_executa;
-- esperado: f | f

select 'realtime_receita' as parte,
       c.relreplident as replica_identity,
       (select count(*) from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
            and tablename = 'receita') as na_publicacao
  from pg_class c
 where c.oid = 'public.receita'::regclass;
-- esperado: f | 1

-- ------------------------------------------------------------
-- 2. Usuário e casa de prova
-- ------------------------------------------------------------

create temp table _quem_receita as
select id as uid from public.perfil limit 1;

create temp table _casa_receita_estranha (
  id uuid primary key
);
insert into _casa_receita_estranha values (gen_random_uuid());
grant select on table _casa_receita_estranha to authenticated;

select set_config(
  'request.jwt.claims',
  json_build_object('sub', (select uid from _quem_receita),
                    'role', 'authenticated')::text,
  false);

-- ------------------------------------------------------------
-- 3. Dados de prova, dentro de uma transação
-- ------------------------------------------------------------

begin;

-- Cria uma segunda casa real, apenas dentro desta transação, para que a prova
-- de RLS abaixo esbarre na política por casa_id — e não antes, na FK.
insert into public.casa (id, nome)
select id, 'Casa de prova receita' from _casa_receita_estranha;

set role authenticated;

insert into public.receita
  (casa_id, competencia, descricao, valor, recebido, observacao)
values
  (public.minha_casa(),
   date_trunc('month', now() at time zone 'America/Sao_Paulo')::date,
   'Receita de prova atual', 100.00, false, 'prova');

insert into public.receita
  (casa_id, competencia, descricao, valor, recebido)
values
  (public.minha_casa(),
   (date_trunc('month', now() at time zone 'America/Sao_Paulo')::date
      - interval '1 month')::date,
   'Receita de prova anterior', 250.00, true);

insert into public.receita
  (casa_id, competencia, descricao, valor, recebido)
values
  (public.minha_casa(), '2099-01-01', 'Receita só para excluir do histórico', 999.99, true);

-- ------------------------------------------------------------
-- 4. Agregação da RPC, nos dois sentidos
-- ------------------------------------------------------------

do $$
declare
  r record;
  t numeric;
  rec numeric;
  a numeric;
  c bigint;
  qtd_receita bigint;
  qtd_rpc bigint;
begin
  select count(distinct rr.competencia) into qtd_receita
    from public.receita rr;
  select count(*) into qtd_rpc
    from public.receitas_mensais();

  if qtd_receita is distinct from qtd_rpc then
    raise exception 'Cardinalidade divergente: receita=%, rpc=%',
      qtd_receita, qtd_rpc;
  end if;

  if exists (
    select 1
    from (select distinct rr.competencia from public.receita rr) rr
    where not exists (
      select 1 from public.receitas_mensais() m
      where m.competencia = rr.competencia
    )
  ) then
    raise exception 'Há competência em receita ausente em receitas_mensais()';
  end if;

  if exists (
    select 1
    from public.receitas_mensais() m
    where not exists (
      select 1 from public.receita rr
      where rr.competencia = m.competencia
    )
  ) then
    raise exception 'receitas_mensais() devolveu competência sem receita';
  end if;

  for r in select * from public.receitas_mensais() loop
    select coalesce(sum(rr.valor), 0),
           coalesce(sum(rr.valor) filter (where rr.recebido), 0),
           coalesce(sum(rr.valor) filter (where not rr.recebido), 0),
           count(*)
      into t, rec, a, c
      from public.receita rr
     where rr.competencia = r.competencia;

    if r.total     is distinct from t
       or r.recebido is distinct from rec
       or r.a_receber is distinct from a
       or r.contas  is distinct from c then
      raise exception 'Agregação divergente para %', r.competencia;
    end if;
  end loop;
end
$$;

-- ------------------------------------------------------------
-- 5. Trigger de autoria e normalização
-- ------------------------------------------------------------

do $$
declare
  eu uuid := auth.uid();
  outro uuid;
  id_forjada uuid;
  id_limpa uuid;
begin
  select id into outro
    from public.perfil
   where id <> eu
   limit 1;

  insert into public.receita
    (casa_id, competencia, descricao, valor, recebido,
     recebido_em, recebido_por)
  values
    (public.minha_casa(), '2026-04-15', 'Tenta forjar autoria', 50.00, true,
     '2000-01-01T00:00:00Z', outro)
  returning id into id_forjada;

  if exists (
    select 1 from public.receita
     where id = id_forjada
       and (recebido_por is distinct from eu
            or recebido_em < now() - interval '1 minute')
  ) then
    raise exception 'Autoria de receita foi forjada';
  end if;

  if exists (
    select 1 from public.receita
     where id = id_forjada
       and recebido_em is null
  ) then
    raise exception 'Recebido true não gravou recebido_em';
  end if;

  insert into public.receita
    (casa_id, competencia, descricao, valor, recebido,
     recebido_em, recebido_por)
  values
    (public.minha_casa(), '2026-04-15', 'Recebido false limpa autoria', 50.00, false,
     '2000-01-01T00:00:00Z', eu)
  returning id into id_limpa;

  if exists (
    select 1 from public.receita
     where id = id_limpa
       and (recebido_em is not null or recebido_por is not null)
  ) then
    raise exception 'Recebido false não limpou autoria';
  end if;
end
$$;

-- ------------------------------------------------------------
-- 6. historico() continua sendo só despesa
-- ------------------------------------------------------------

do $$
begin
  if exists (
    select 1 from public.historico() h
     where h.competencia = '2099-01-01'
  ) then
    raise exception 'Uma receita vazou para public.historico()';
  end if;
end
$$;

-- ------------------------------------------------------------
-- 7. RLS: outra casa não entra
-- ------------------------------------------------------------

do $$
declare
  outra uuid := (select id from _casa_receita_estranha);
begin
  begin
    insert into public.receita
      (casa_id, competencia, descricao, valor, recebido)
    values
      (outra, '2099-01-01', 'Invasão de outra casa', 1.00, false);
    raise notice 'FALHA  inserção em outra casa foi aceita';
    raise exception 'desfazer' using errcode = 'P0001';
  exception
    when sqlstate 'P0001' then null;
    when others then raise notice 'ok     inserção em outra casa recusada (%)', sqlstate;
  end;
end
$$;

rollback;

reset role;
select set_config('request.jwt.claims', null, false);

drop table _quem_receita;
drop table _casa_receita_estranha;

-- ============================================================
-- LEITURA DO RESULTADO
--   1: t | 11
--   2: t | t | {receita_apagar,receita_criar,receita_editar,receita_ler}
--   3: f | f | f | f | t | t | t | t
--   4: f | s | (vazio) | {search_path=public} | f | t
--   5: f | f
--   6: f | 1
--   DOs: nenhuma exception.
--   7: uma linha "ok inserção em outra casa recusada".
-- ============================================================
