-- ============================================================
-- Nossas Contas — bloco 9: contas que acabam.
--
-- O buraco que isto tapa: cinco contas da casa não são mensais para sempre —
-- são acordos parcelados, uma parcela de imposto e um material escolar. Sem
-- controle de parcelas elas voltam todo mês, e cabia ao Jonathan desligá-las
-- na mão quando acabassem. Pior agora, com três avisos por dia: uma parcelada
-- encerrada que continua vindo vira três alarmes falsos por dia.
--
-- A ideia em uma frase: uma conta fixa passa a poder dizer "sou 12 vezes, a
-- partir de tal mês", e o gerar_mes() para de trazê-la quando a última passou.
-- Idempotente.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Na conta fixa: quantas vezes, e a partir de quando
-- ------------------------------------------------------------
-- Nulo nos dois quer dizer "mensal para sempre", que é o caso da maioria.
-- As duas colunas andam juntas: uma sem a outra não diz nada.

alter table public.modelo add column if not exists parcelas_total int;
alter table public.modelo add column if not exists parcela_1      date;

do $$
begin
  alter table public.modelo add constraint modelo_parcelas_ok
    check (parcelas_total is null or parcelas_total between 1 and 360);
exception when duplicate_object then null; end $$;

do $$
begin
  alter table public.modelo add constraint modelo_parcelas_em_par
    check ((parcelas_total is null) = (parcela_1 is null));
exception when duplicate_object then null; end $$;

-- ------------------------------------------------------------
-- 2. No lançamento: qual parcela é esta
-- ------------------------------------------------------------
-- Em coluna própria, e NÃO na descrição. A regra que impede o gerar_mes() de
-- duplicar compara por descrição; uma descrição que muda todo mês ("Acordo
-- (5/12)") faria a mesma conta entrar de novo toda vez. Quem junta as duas
-- coisas é a tela.

alter table public.lancamento add column if not exists parcela_n  int;
alter table public.lancamento add column if not exists parcela_de int;

-- ------------------------------------------------------------
-- 3. A janela, em um lugar só
-- ------------------------------------------------------------
-- Devolve o número da parcela que cai naquele mês. Nulo quando a conta não é
-- parcelada. Pode devolver 0, negativo ou maior que o total — quem decide se
-- entra é quem chama, comparando com parcelas_total.

create or replace function public.parcela_no_mes(
  p_parcelas_total int, p_parcela_1 date, p_competencia date)
returns int
language sql
immutable
set search_path = public
as $$
  select case
    when p_parcelas_total is null or p_parcela_1 is null then null
    else (extract(year  from p_competencia)::int - extract(year  from p_parcela_1)::int) * 12
       + (extract(month from p_competencia)::int - extract(month from p_parcela_1)::int) + 1
  end
$$;

revoke all on function public.parcela_no_mes(int, date, date) from public, anon;
grant execute on function public.parcela_no_mes(int, date, date) to authenticated;

-- ------------------------------------------------------------
-- 4. O mês da primeira parcela é competência, não dia
-- ------------------------------------------------------------
-- O gatilho passa a valer no insert também, para normalizar quem chegar com
-- dia diferente de 1. Continua pondo a hora de atualização, como antes.

create or replace function public.tg_modelo()
returns trigger language plpgsql
set search_path = public
as $$
begin
  new.atualizado_em := now();
  new.parcela_1 := date_trunc('month', new.parcela_1)::date;   -- nulo continua nulo
  return new;
end $$;

revoke all on function public.tg_modelo() from public, anon, authenticated;

drop trigger if exists modelo_antes_de_gravar on public.modelo;
create trigger modelo_antes_de_gravar
  before insert or update on public.modelo
  for each row execute function public.tg_modelo();

-- ------------------------------------------------------------
-- 5. Gerar o mês respeitando a janela
-- ------------------------------------------------------------
-- Continua security invoker, e a comparação para não duplicar continua sendo
-- por descrição. O que muda: conta parcelada só entra dentro do intervalo, e
-- o lançamento nasce sabendo que parcela é.

create or replace function public.gerar_mes(p_competencia date)
returns int
language plpgsql
security invoker
set search_path = public
as $$
declare c uuid; mes date; n int;
begin
  c := public.minha_casa();
  if c is null then raise exception 'Você não pertence a nenhuma casa.'; end if;
  mes := date_trunc('month', p_competencia)::date;

  insert into public.lancamento
    (casa_id, modelo_id, competencia, descricao, dia_vencimento, valor_previsto,
     parcela_n, parcela_de)
  select c, m.id, mes, m.descricao, m.dia_vencimento, m.valor_padrao,
         public.parcela_no_mes(m.parcelas_total, m.parcela_1, mes),
         m.parcelas_total
    from public.modelo m
   where m.casa_id = c
     and m.ativo
     and (m.parcelas_total is null
          or public.parcela_no_mes(m.parcelas_total, m.parcela_1, mes)
             between 1 and m.parcelas_total)
     and not exists (
       select 1 from public.lancamento l
        where l.casa_id = c and l.competencia = mes
          and lower(btrim(l.descricao)) = lower(btrim(m.descricao))
     );

  get diagnostics n = row_count;
  return n;
end $$;

-- Conferência: as duas colunas em cada tabela, e a janela fazendo conta certa.
select (select count(*) from information_schema.columns
         where table_schema = 'public' and table_name = 'modelo'
           and column_name in ('parcelas_total','parcela_1'))     as colunas_na_fixa,
       (select count(*) from information_schema.columns
         where table_schema = 'public' and table_name = 'lancamento'
           and column_name in ('parcela_n','parcela_de'))         as colunas_no_lancamento,
       public.parcela_no_mes(12, '2026-03-01', '2026-03-01')      as primeira,
       public.parcela_no_mes(12, '2026-03-01', '2027-02-01')      as decima_segunda,
       public.parcela_no_mes(12, '2026-03-01', '2027-03-01')      as decima_terceira_fora,
       public.parcela_no_mes(null, null, '2026-03-01')            as nao_parcelada;
