-- ============================================================
-- Nossas Contas — bloco 18: os gráficos desde o início do controle.
--
-- graficos() passa a ler as despesas de historico_completo() (bloco 17) em
-- vez de historico(): entram os meses do arquivo antigo, de novembro/2024 em
-- diante, com a mesma regra de corte e a mesma conta por mês que a tela de
-- histórico mostra. Continua sem tabela nova e sem segunda fonte de verdade.
--
-- O que muda na saída:
-- - origem ('app' ou 'legado'), para a tela saber o que cada linha pode
--   dizer;
-- - despesa_riscada e despesa_riscadas: a parte do mês que saiu do controle
--   no arquivo antigo. Fica em coluna própria; quem desenha decide se soma, e
--   a tela mostra as duas partes empilhadas;
-- - saldo só existe em mês do app. O arquivo antigo quase não tem receitas
--   (só novembro/2024), então "saldo" ali seria só a despesa com sinal
--   trocado — número que parece dado e não é. Fica nulo.
--
-- Mudar as colunas muda o tipo de retorno: é drop e create, e as permissões
-- vão junto — por isso estão repetidas abaixo.
-- ============================================================

drop function if exists public.graficos();

create function public.graficos()
returns table (
  competencia        date,
  origem             text,
  despesa_prevista   numeric,
  despesa_paga       numeric,
  despesa_a_pagar    numeric,
  despesa_contas     bigint,
  despesa_sem_valor  bigint,
  despesa_riscada    numeric,
  despesa_riscadas   bigint,
  receita_total      numeric,
  receita_recebida   numeric,
  receita_a_receber  numeric,
  receita_contas     bigint,
  saldo              numeric
)
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(d.competencia, r.competencia)       as competencia,
         coalesce(d.origem, 'app')                    as origem,
         coalesce(d.previsto, 0)                      as despesa_prevista,
         coalesce(d.pago, 0)                          as despesa_paga,
         coalesce(d.a_pagar, 0)                       as despesa_a_pagar,
         coalesce(d.contas, 0)                        as despesa_contas,
         coalesce(d.sem_valor, 0)                     as despesa_sem_valor,
         coalesce(d.riscado, 0)                       as despesa_riscada,
         coalesce(d.riscadas, 0)                      as despesa_riscadas,
         coalesce(r.total, 0)                         as receita_total,
         coalesce(r.recebido, 0)                      as receita_recebida,
         coalesce(r.a_receber, 0)                     as receita_a_receber,
         coalesce(r.contas, 0)                        as receita_contas,
         case when coalesce(d.origem, 'app') = 'app'
              then coalesce(r.recebido, 0) - coalesce(d.pago, 0)
         end                                          as saldo
    from public.historico_completo() d
    full outer join public.receitas_mensais() r
      on d.competencia = r.competencia and d.origem = 'app'
   order by competencia desc, origem;
$$;

revoke all on function public.graficos() from public, anon;
grant execute on function public.graficos() to authenticated;

-- Conferência
select p.proname as funcao,
       p.prosecdef as security_definer,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       has_function_privilege('anon', 'public.graficos()', 'EXECUTE') as anon_executa,
       has_function_privilege('authenticated', 'public.graficos()', 'EXECUTE') as auth_executa
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace
   and p.proname = 'graficos';
-- esperado: f | (vazio) | f | t
