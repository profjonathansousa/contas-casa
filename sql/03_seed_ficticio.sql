-- ============================================================
-- Nossas Contas — seed OPCIONAL, só para ver a tela com conteúdo.
-- TODOS os dados aqui são fictícios (regra do projeto: nenhum dado
-- financeiro real entra no repositório).
-- Rodar só se quiser testar a interface antes de digitar as contas de verdade.
-- Para limpar depois: delete from public.lancamento where observacao = 'seed';
-- ============================================================

do $$
declare
  id_casa uuid;
  mes     date := date_trunc('month', current_date)::date;
begin
  select id into id_casa from public.casa order by nome limit 1;
  if id_casa is null then
    raise exception 'Nenhuma casa cadastrada. Rode o 02_config_inicial primeiro.';
  end if;

  delete from public.lancamento where casa_id = id_casa and observacao = 'seed';

  insert into public.lancamento
    (casa_id, competencia, descricao, dia_vencimento, valor_previsto, pago, observacao)
  values
    (id_casa, mes, 'Aluguel',              5,  1800.00, false, 'seed'),
    (id_casa, mes, 'Luz',                  8,  null,    false, 'seed'),
    (id_casa, mes, 'Água',                 8,   95.40,  false, 'seed'),
    (id_casa, mes, 'Internet',            10,  129.90,  true,  'seed'),
    (id_casa, mes, 'Cartão azul',         15,  null,    false, 'seed'),
    (id_casa, mes, 'Escola',              15,  740.00,  false, 'seed'),
    (id_casa, mes, 'Plano de saúde',      20,  612.35,  true,  'seed'),
    (id_casa, mes, 'Assinatura de vídeo', 28,   39.90,  false, 'seed'),
    (id_casa, mes, 'Condomínio',          31,  480.00,  false, 'seed');

  raise notice 'Seed fictício inserido no mês %.', mes;
end
$$;

-- Conferência: 9 linhas; note que "Condomínio" (dia 31) já vem com o
-- vencimento ajustado para o último dia do mês.
select dia_vencimento, descricao, vencimento, valor_previsto, pago
from public.lancamento
where observacao = 'seed'
order by dia_vencimento, descricao;
