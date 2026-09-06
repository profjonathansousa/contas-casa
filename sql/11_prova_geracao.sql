-- ============================================================
-- Nossas Contas — PROVA do bloco 11.
--
-- Por que isto existe: o SQL Editor roda como "postgres", que ignora RLS e
-- enxerga tudo. Então "abri o app e apareceu" não prova nada sobre a trava,
-- sobre a RLS nem sobre os grants. Este arquivo mede o que dá para medir numa
-- sessão só, e diz explicitamente o que NÃO mede.
--
-- Rodar DEPOIS do sql/11_geracao_automatica.sql.
-- Nada aqui escreve. Pode rodar quantas vezes quiser.
--
-- O QUE ESTE ARQUIVO NÃO PROVA
--   A serialização entre dois aparelhos. Uma sessão só não consegue abrir duas
--   transações concorrentes, então a garantia de concorrência aqui é o
--   MECANISMO — a chave primária de mes_gerado e o bloqueio do "on conflict"
--   até o commit do vencedor —, verificado pela existência da chave, e não uma
--   medida de duas sessões disputando. Está registrado assim no ESTADO.md de
--   propósito: chamar isto de "prova de concorrência" seria inflar o que foi
--   medido.
-- ============================================================

-- ---------- medição 1: a trava existe e tem a forma certa ----------
select 'a marca do mes' as parte,
       to_regclass('public.mes_gerado') is not null                as tabela_existe,
       (select array_agg(a.attname order by k.ord)
          from pg_constraint ct
          join lateral unnest(ct.conkey) with ordinality as k(att, ord) on true
          join pg_attribute a on a.attrelid = ct.conrelid and a.attnum = k.att
         where ct.conrelid = 'public.mes_gerado'::regclass
           and ct.contype = 'p')                                   as chave_primaria,
       (select count(*) from pg_constraint
         where conrelid = 'public.mes_gerado'::regclass
           and contype = 'c'
           and conname in ('mes_gerado_dia_1', 'mes_gerado_origem_ok')) as checks_esperados;
-- esperado: t | {casa_id,competencia} | 2

-- ---------- medição 2: a RLS da marca ----------
select 'rls da marca' as parte,
       c.relrowsecurity as ligada,
       c.relforcerowsecurity as forcada,
       (select array_agg(polname order by polname) from pg_policy
         where polrelid = c.oid) as politicas
  from pg_class c where c.oid = 'public.mes_gerado'::regclass;
-- esperado: t | t | {mes_gerado_ler}
-- SÓ a de leitura. Não há policy de INSERT porque não há grant de INSERT: o
-- cliente não escreve nesta tabela por caminho nenhum. Se aparecer política de
-- update ou delete, a exclusão durável quebrou; se aparecer uma de insert,
-- alguém reabriu a porta de marcar o mês sem gerar.

-- ---------- medição 3: grants — o anon não entra ----------
select 'grants' as parte,
       has_table_privilege('anon', 'public.mes_gerado', 'SELECT')          as anon_le,
       has_function_privilege('anon', 'public.garantir_mes()', 'EXECUTE')  as anon_executa,
       has_table_privilege('authenticated', 'public.mes_gerado', 'SELECT') as eu_leio,
       has_table_privilege('authenticated', 'public.mes_gerado', 'INSERT') as eu_gravo,
       has_table_privilege('authenticated', 'public.mes_gerado', 'UPDATE') as eu_atualizo,
       has_table_privilege('authenticated', 'public.mes_gerado', 'DELETE') as eu_apago,
       has_function_privilege('authenticated', 'public.garantir_mes()', 'EXECUTE') as eu_chamo,
       has_schema_privilege('anon', 'privado', 'USAGE')                    as anon_entra_no_privado,
       has_function_privilege('anon', 'privado.marcar_mes_corrente()', 'EXECUTE') as anon_marca;
-- esperado: f | f | t | f | f | f | t | f | f
-- Os quatro falsos do meio são o coração desta correção: authenticated LÊ a
-- marca e não escreve nela por caminho nenhum — nem insert, nem update, nem
-- delete. A única porta é o garantir_mes(), que ele pode executar.
-- O Supabase concede execute a anon por padrão em função nova, e é o revoke da
-- migration que desfaz isso — por isso essas colunas são medidas, não supostas.

-- ---------- medição 4: a identidade do lançamento gerado ----------
select 'identidade da linha' as parte,
       indexdef
  from pg_indexes
 where schemaname = 'public' and indexname = 'lancamento_do_modelo_idx';
-- esperado: CREATE UNIQUE INDEX ... ON public.lancamento
--           USING btree (casa_id, competencia, modelo_id)
-- Único e SEM cláusula WHERE: lançamento manual tem modelo_id nulo, e nulo não
-- colide. Se aparecer "WHERE", alguém trocou o desenho.

-- ---------- medição 5: as duas funções ----------
select 'funcoes' as parte,
       p.proname,
       p.prosecdef                                   as security_definer,
       p.proconfig                                   as config,
       pg_get_function_result(p.oid)                 as devolve,
       pg_get_function_identity_arguments(p.oid)     as recebe,
       md5(pg_get_functiondef(p.oid))                as impressao
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('gerar_mes', 'garantir_mes')
 order by p.proname;
-- esperado:
--   garantir_mes | f | {search_path=public} | TABLE(competencia date, criadas integer) | (vazio)
--   gerar_mes    | f | {search_path=public} | integer                                  | p_competencia date
--
-- security_definer TEM que ser falso nas duas: a RLS é que impede gerar mês na
-- casa de outro. E garantir_mes NÃO pode receber argumento — é a assinatura
-- que garante que navegar para um mês histórico nunca vira escrita.
--
-- A coluna "impressao" é o detector de divergência entre o arquivo SQL e a
-- função realmente instalada. Anote o md5 do gerar_mes aqui embaixo depois de
-- aplicar, e confira nas próximas auditorias:
--   gerar_mes do sql/10 (antes do bloco 11): 0619f9ab536a4d80c0a1c7ea32a3e3cc
--   gerar_mes do sql/11 (com o on conflict):  <anote depois de aplicar>
-- Numa réplica local em PostgreSQL 16 o sql/11 deu
-- baa0fc265c328a164282a4f08a201f14; o banco de produção é PostgreSQL 17 e pode
-- formatar a definição de outro jeito, então o valor que vale é o daqui.

-- ---------- medição 6: o backfill marcou o que devia ----------
select 'backfill' as parte,
       (select count(*) from public.mes_gerado where origem = 'backfill')   as marcados_no_backfill,
       (select count(*) from public.mes_gerado where origem = 'automatico') as nascidos_automaticamente,
       (select count(*) from (
          select distinct casa_id, competencia
            from public.lancamento where modelo_id is not null) g
         where not exists (select 1 from public.mes_gerado m
                            where m.casa_id = g.casa_id
                              and m.competencia = g.competencia))           as geradas_sem_marca,
       (select count(*) from public.mes_gerado m
         where not exists (select 1 from public.lancamento l
                            where l.casa_id = m.casa_id
                              and l.competencia = m.competencia
                              and l.modelo_id is not null))                 as marcas_sem_conta_gerada;
-- esperado logo após aplicar: 2 | 0 | 0 | 0
--
-- "geradas_sem_marca" TEM que ser zero, hoje e sempre: é uma competência que
-- comprovadamente já gerou contas e ficou sem marca — na próxima abertura o mês
-- seria dado como novo e tudo que foi apagado de propósito voltaria.
--
-- "marcas_sem_conta_gerada" é o inverso: uma marca num mês que não tem nenhuma
-- conta vinda de modelo. Logo após aplicar tem que ser zero (uma marca falsa
-- teria comido a primeira geração daquele mês para sempre). Com o tempo pode
-- deixar de ser zero por motivo legítimo — um mês que nasceu com todas as
-- fixas desligadas, ou um mês em que tudo foi apagado à mão.

-- ---------- medição 7: controle negativo da RLS ----------
-- Um uuid que não tem perfil nenhum: minha_casa() devolve NULL, e
-- "casa_id = NULL" nunca é verdadeiro.
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-000000000000',
                    'role', 'authenticated')::text,
  false);
set role authenticated;

select 'controle negativo' as parte,
       (select count(*) from public.mes_gerado) as marcas_que_o_estranho_ve;

reset role;
select set_config('request.jwt.claims', null, false);

-- ---------- medição 8: a policy de INSERT, tentada de verdade ----------
-- A policy existir não prova nada: o que prova é tentar gravar e apanhar.
-- Aqui a sessão vira um usuário REAL da casa e tenta as quatro marcas que o
-- cliente não pode gravar, mais a que pode, mais o caminho do garantir_mes().
--
-- Nada fica no banco: cada tentativa roda numa subtransação do plpgsql, e as
-- que dão certo são desfeitas por um raise de propósito.

create temporary table _quem as
select id as uid from public.perfil limit 1;

select set_config(
  'request.jwt.claims',
  json_build_object('sub', (select uid from _quem), 'role', 'authenticated')::text,
  false);
set role authenticated;

do $$
declare
  eu_casa uuid := public.minha_casa();
  mes     date := date_trunc('month', (now() at time zone 'America/Sao_Paulo'))::date;
  outra   uuid := '00000000-0000-0000-0000-0000000000ff';
begin
  raise notice 'casa: %  mes corrente no banco: %', eu_casa, mes;

  begin
    insert into public.mes_gerado (casa_id, competencia, origem)
    values (eu_casa, (mes - interval '1 month')::date, 'automatico');
    raise notice 'FALHA  mes PASSADO foi aceito';
    raise exception 'desfazer' using errcode = 'P0001';
  exception
    when sqlstate 'P0001' then null;
    when others then raise notice 'ok     mes passado recusado (%)', sqlstate;
  end;

  begin
    insert into public.mes_gerado (casa_id, competencia, origem)
    values (eu_casa, (mes + interval '1 month')::date, 'automatico');
    raise notice 'FALHA  mes FUTURO foi aceito — este e o pior: o mes nunca nasceria';
    raise exception 'desfazer' using errcode = 'P0001';
  exception
    when sqlstate 'P0001' then null;
    when others then raise notice 'ok     mes futuro recusado (%)', sqlstate;
  end;

  begin
    insert into public.mes_gerado (casa_id, competencia, origem)
    values (eu_casa, mes, 'backfill');
    raise notice 'FALHA  origem BACKFILL forjada foi aceita';
    raise exception 'desfazer' using errcode = 'P0001';
  exception
    when sqlstate 'P0001' then null;
    when others then raise notice 'ok     origem backfill recusada (%)', sqlstate;
  end;

  begin
    insert into public.mes_gerado (casa_id, competencia, origem)
    values (outra, mes, 'automatico');
    raise notice 'FALHA  marca para OUTRA CASA foi aceita';
    raise exception 'desfazer' using errcode = 'P0001';
  exception
    when sqlstate 'P0001' then null;
    when others then raise notice 'ok     outra casa recusada (%)', sqlstate;
  end;

  -- CONTROLE NEGATIVO, e o mais importante dos cinco: nem o mes CORRENTE da
  -- PROPRIA casa com a origem certa pode ser gravado a mao. Se isto passar, da
  -- para marcar o mes como nascido sem gerar nada — e as contas do mes nao vem.
  begin
    insert into public.mes_gerado (casa_id, competencia, origem)
    values (eu_casa, mes, 'automatico');
    raise notice 'FALHA  o mes CORRENTE ainda pode ser marcado a mao, sem gerar nada';
    raise exception 'desfazer' using errcode = 'P0001';
  exception
    when sqlstate 'P0001' then null;
    when others then raise notice 'ok     insert direto do mes corrente recusado (%)', sqlstate;
  end;

  begin
    perform * from public.garantir_mes();
    raise exception 'desfazer' using errcode = 'P0001';
  exception
    when sqlstate 'P0001' then raise notice 'ok     garantir_mes() continua funcionando (e foi desfeito)';
    when others           then raise notice 'FALHA  garantir_mes() quebrou (%)', sqlstate;
  end;
end $$;

reset role;
select set_config('request.jwt.claims', null, false);

-- ---------- medição 9: o ajudante não é endpoint ----------
-- O PostgREST publica só o schema public. Se marcar_mes_corrente aparecer ali,
-- vira /rest/v1/rpc/marcar_mes_corrente e a brecha volta inteira — agora com
-- autoridade de dono de tabela.
select 'o ajudante mora fora do alcance do PostgREST' as parte,
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public'  and p.proname = 'marcar_mes_corrente') as em_public,
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'privado' and p.proname = 'marcar_mes_corrente') as em_privado,
       (select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'privado' and p.proname = 'marcar_mes_corrente') as ele_e_definer,
       (select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public'  and p.proname = 'garantir_mes')        as garantir_e_definer,
       (select p.pronargs from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'privado' and p.proname = 'marcar_mes_corrente') as argumentos_do_ajudante;
-- esperado: 0 | 1 | t | f | 0
-- ele_e_definer = t e garantir_e_definer = f: a autoridade fica no menor
-- pedaço possível, e o gerar_mes() continua rodando sob a RLS da pessoa.
-- argumentos_do_ajudante = 0: casa e mês ele calcula sozinho, não recebe.

drop table _quem;

-- ============================================================
-- LEITURA DO RESULTADO
--   1: t | {casa_id,competencia} | 2
--   2: t | t | {mes_gerado_criar,mes_gerado_ler}
--   3: f | f | f | t | t | f | f
--   4: índice único, sem WHERE
--   5: security_definer falso nas duas, garantir_mes sem argumento
--   6: 2 | 0 | 0 | 0   (as duas últimas colunas zero é o que importa)
--   7: marcas_que_o_estranho_ve = 0            <- obrigatório
--   8: seis linhas começando em "ok". Um único "FALHA" ali é buraco aberto:
--      quer dizer que uma sessão logada consegue gravar a marca à mão — e um
--      mês marcado sem ter sido gerado é um mês que não traz as contas.
--   9: 0 | 1 | t | f | 0
-- Qualquer número diferente de zero na medição 7 é RLS furada. Me avise.
-- ============================================================
