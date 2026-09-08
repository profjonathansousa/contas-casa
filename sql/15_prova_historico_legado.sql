-- ============================================================
-- Nossas Contas — PROVA do bloco 15.
--
-- Rodar DEPOIS de sql/15_historico_legado.sql.
-- Nada persiste: a importação de prova é feita numa transação e desfeita.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Metadados, grants e RLS
-- ------------------------------------------------------------

select 'tabelas_legado' as parte,
       to_regclass('public.historico_legado') is not null as despesas_existe,
       to_regclass('public.historico_legado_receita') is not null as receitas_existe,
       to_regclass('public.historico_legado_resumo') is not null as resumos_existe;
-- esperado: t | t | t

select 'rls_legado' as parte,
       c.relname,
       c.relrowsecurity as ligada,
       c.relforcerowsecurity as forcada,
       (select array_agg(polname order by polname) from pg_policy
         where polrelid = c.oid) as politicas
  from pg_class c
 where c.relnamespace = 'public'::regnamespace
   and c.relname in
     ('historico_legado','historico_legado_receita','historico_legado_resumo')
 order by c.relname;
-- esperado: só política de leitura em cada tabela.

select 'grants_legado' as parte,
       t.tabela,
       has_table_privilege('anon', t.tabela, 'SELECT') as anon_select,
       has_table_privilege('authenticated', t.tabela, 'SELECT') as auth_select,
       has_table_privilege('authenticated', t.tabela, 'INSERT') as auth_insert,
       has_table_privilege('authenticated', t.tabela, 'UPDATE') as auth_update,
       has_table_privilege('authenticated', t.tabela, 'DELETE') as auth_delete
  from (values ('public.historico_legado'),
               ('public.historico_legado_receita'),
               ('public.historico_legado_resumo')) as t(tabela);
-- esperado: anon_select=f, auth_select=t, insert/update/delete=f.

select 'importador_legado' as parte,
       p.prosecdef as security_definer,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       has_function_privilege('anon', 'privado.importar_historico_legado(uuid,jsonb)', 'EXECUTE') as anon_executa,
       has_function_privilege('authenticated', 'privado.importar_historico_legado(uuid,jsonb)', 'EXECUTE') as auth_executa
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'privado'
   and p.proname = 'importar_historico_legado';
-- esperado: t | p_casa_id uuid, p_itens jsonb | f | f

-- ------------------------------------------------------------
-- 2. Setup de casas e contadores
-- ------------------------------------------------------------

create temp table _casa_legado as
select casa_id from public.perfil limit 1;

create temp table _casa_legado_estranha (
  id uuid primary key
);
insert into _casa_legado_estranha values (gen_random_uuid());
grant select on table _casa_legado_estranha to authenticated;

create temp table _antes_legado as
select
  (select count(*) from public.modelo)     as modelos,
  (select count(*) from public.lancamento) as lancamentos,
  (select count(*) from public.mes_gerado) as mes_gerado,
  (select count(*) from public.receita)    as receitas;

-- ------------------------------------------------------------
-- 3. Importação de prova, em transação
-- ------------------------------------------------------------

begin;

insert into public.casa (id, nome)
select id, 'Casa de prova histórico legado' from _casa_legado_estranha;

select privado.importar_historico_legado(
  (select casa_id from _casa_legado),
  jsonb_build_array(
    jsonb_build_object(
      'tipo','despesa',
      'competencia','2026-09-01',
      'dia',5,
      'descricao','Despesa legada de prova',
      'valor',100.00,
      'pago',true,
      'riscado',false,
      'observacao',null,
      'parcela_n',null,
      'parcela_de',null,
      'linha_original','- [x] 100,00 Despesa legada de prova',
      'ordem',1
    ),
    jsonb_build_object(
      'tipo','receita',
      'competencia','2026-09-01',
      'dia',null,
      'descricao','Receita legada de prova',
      'valor',200.00,
      'recebido',true,
      'observacao',null,
      'linha_original','200,00 Receita legada de prova',
      'ordem',2
    ),
    jsonb_build_object(
      'tipo','resumo',
      'competencia','2026-09-01',
      'secao','total_despesas',
      'texto','Total de prova',
      'valor',300.00,
      'linha_original','Total: R$ 300,00',
      'ordem',3
    )
  )
);

select privado.importar_historico_legado(
  (select id from _casa_legado_estranha),
  jsonb_build_array(
    jsonb_build_object(
      'tipo','despesa',
      'competencia','2026-09-01',
      'dia',5,
      'descricao','Despesa da outra casa',
      'valor',50.00,
      'pago',true,
      'riscado',false,
      'observacao',null,
      'parcela_n',null,
      'parcela_de',null,
      'linha_original','- [x] 50,00 Despesa da outra casa',
      'ordem',1
    )
  )
);

select 'importado_propria_casa' as parte,
       (select count(*) from public.historico_legado
         where casa_id = (select casa_id from _casa_legado)
           and descricao = 'Despesa legada de prova') as despesas,
       (select count(*) from public.historico_legado_receita
         where casa_id = (select casa_id from _casa_legado)
           and descricao = 'Receita legada de prova') as receitas,
       (select count(*) from public.historico_legado_resumo
         where casa_id = (select casa_id from _casa_legado)
           and texto = 'Total de prova') as resumos;
-- esperado: 1 | 1 | 1

do $$
declare
  antes record;
  modelos int;
  lancamentos int;
  mes_gerado int;
  receitas int;
begin
  select * into antes from _antes_legado;
  select count(*) into modelos     from public.modelo;
  select count(*) into lancamentos from public.lancamento;
  select count(*) into mes_gerado from public.mes_gerado;
  select count(*) into receitas    from public.receita;

  if modelos is distinct from antes.modelos
     or lancamentos is distinct from antes.lancamentos
     or mes_gerado is distinct from antes.mes_gerado
     or receitas is distinct from antes.receitas then
    raise exception 'A importação legada alterou tabelas correntes';
  end if;
end
$$;

-- ------------------------------------------------------------
-- 4. RLS: authenticated só enxerga a própria casa
-- ------------------------------------------------------------

select set_config(
  'request.jwt.claims',
  json_build_object('sub', (select id from public.perfil limit 1),
                    'role', 'authenticated')::text,
  false);
set role authenticated;

select 'visao_legado_authenticated' as parte,
       (select count(*) from public.historico_legado
         where descricao = 'Despesa legada de prova') as despesa_propria_visivel,
       (select count(*) from public.historico_legado
         where descricao = 'Despesa da outra casa') as despesa_outra_invisivel,
       (select count(*) from public.historico_legado_receita
         where descricao = 'Receita legada de prova') as receita_propria_visivel,
       (select count(*) from public.historico_legado_resumo
         where texto = 'Total de prova') as resumo_proprio_visivel;
-- esperado: 1 | 0 | 1 | 1 — a despesa da outra casa não aparece.

do $$
declare
  outra uuid := (select id from _casa_legado_estranha);
begin
  begin
    insert into public.historico_legado
      (casa_id, competencia, descricao, pago, riscado, linha_original,
       ordem_original)
    values
      (outra, '2026-09-01', 'Invasão', false, false, 'invasão', 999);
    raise notice 'FALHA  inserção direta em historico_legado foi aceita';
    raise exception 'desfazer' using errcode = 'P0001';
  exception
    when sqlstate 'P0001' then null;
    when others then raise notice 'ok     inserção direta em historico_legado recusada (%)', sqlstate;
  end;
end
$$;

rollback;

reset role;
select set_config('request.jwt.claims', null, false);

drop table _antes_legado;
drop table _casa_legado_estranha;
drop table _casa_legado;

-- ============================================================
-- LEITURA DO RESULTADO
--   1: t | t | t
--   2: RLS ligada e forçada, uma política de leitura por tabela.
--   3: anon_select=f, auth_select=t, insert/update/delete=f.
--   4: importador security_definer, anon/auth sem EXECUTE.
--   5: importado_propria_casa = 1 | 1 | 1.
--   6: nenhuma exception em "não altera tabelas correntes".
--   7: visao_legado_authenticated = 1 | 0 | 1 | 1.
--   8: "ok inserção direta em historico_legado recusada".
-- ============================================================
