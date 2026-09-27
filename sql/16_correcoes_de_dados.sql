-- ============================================================
-- Nossas Contas — bloco 16: duas correções de dados, antes de 01/10/2026.
--
-- Nenhuma tabela, função ou permissão muda. Só dados, e só os dois pontos
-- abaixo. Idempotente: rodar de novo não faz nada.
-- ============================================================

-- ------------------------------------------------------------
-- 1. "outubro/26" do arquivo antigo era outubro/2025.
--
-- O arquivo vai do mês mais novo para o mais antigo, e esse bloco estava
-- entre novembro/25 e setembro/25 — exatamente onde outubro/25 deveria
-- estar, e outubro/25 não existia em nenhum outro lugar. A importação do
-- bloco 15 guardou a data ao pé da letra. Confirmado por Jonathan em
-- 27/09/2026.
--
-- O filtro por ordem_original é o que prende a correção a esse bloco:
-- setembro/2026 (o topo do arquivo, ordens 1–21) não é tocado.
-- ------------------------------------------------------------

update public.historico_legado
   set competencia = date '2025-10-01'
 where competencia = date '2026-10-01'
   and ordem_original between 272 and 293;

-- ------------------------------------------------------------
-- 2. Outubro/2026 estava marcado como nascido sem ter conta nenhuma.
--
-- O backfill do bloco 11 (06/09) marcou 2026-10 porque havia 14 contas
-- geradas de modelo nele. Depois elas foram apagadas, e a marca ficou:
-- com ela, garantir_mes() devolveria zero em 01/10 e o mês abriria vazio.
--
-- A regra do próprio backfill é "só marca onde a geração demonstravelmente
-- rodou". Aqui ela deixou de valer, então a marca sai. Tirar a marca não
-- cria conta nenhuma agora: quem cria é o garantir_mes(), no dia 01/10,
-- quando outubro virar o mês corrente no relógio de São Paulo.
--
-- A condição é genérica de propósito: só remove marca de backfill de mês
-- futuro que não tem nenhuma conta vinda de modelo.
-- ------------------------------------------------------------

delete from public.mes_gerado m
 where m.origem = 'backfill'
   and m.competencia > date_trunc('month', now() at time zone 'America/Sao_Paulo')::date
   and not exists (
     select 1 from public.lancamento l
      where l.casa_id = m.casa_id
        and l.competencia = m.competencia
        and l.modelo_id is not null);
