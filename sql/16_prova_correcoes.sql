-- ============================================================
-- Nossas Contas — PROVA do bloco 16. Só leitura.
-- Rodar DEPOIS de sql/16_correcoes_de_dados.sql.
-- ============================================================

-- 1. O histórico legado não tem mais outubro/2026, e tem outubro/2025.
select 'legado_outubro' as parte,
       count(*) filter (where competencia = date '2026-10-01') as out_2026,
       count(*) filter (where competencia = date '2025-10-01') as out_2025
  from public.historico_legado;
-- esperado: 0 | 22

-- 2. A ordem do arquivo volta a ser uma sequência de meses sem buraco:
--    cada bloco é exatamente o mês anterior ao bloco de cima.
select 'legado_sequencia' as parte,
       count(*) filter (where anterior is not null
                          and competencia <> (anterior - interval '1 month')::date) as quebras
  from (select competencia,
               lag(competencia) over (order by min(ordem_original)) as anterior
          from public.historico_legado
         group by competencia) s;
-- esperado: 0

-- 3. Nenhuma marca de mês sem conta gerada (a medida do bloco 11).
select 'marcas_sem_conta_gerada' as parte, count(*) as n
  from public.mes_gerado m
 where not exists (select 1 from public.lancamento l
                    where l.casa_id = m.casa_id
                      and l.competencia = m.competencia
                      and l.modelo_id is not null);
-- esperado: 0

-- 4. Setembro/2026 continua marcado (é o mês corrente e tem contas).
select 'setembro_marcado' as parte, count(*) as n
  from public.mes_gerado where competencia = date '2026-09-01';
-- esperado: 1
