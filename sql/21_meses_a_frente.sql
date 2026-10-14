-- ============================================================
-- Nossas Contas — bloco 21: os meses à frente já vêm com o que está programado.
--
-- O buraco que isto tapa: até aqui só o mês corrente nascia. Avançar para
-- novembro mostrava a tela vazia, e não havia como saber o que vinha nos
-- próximos meses — as contas fixas e as parcelas que faltam — sem fazer a
-- conta de cabeça. O pedido de Jonathan, em 14/10/2026: "é melhor eu excluir
-- algo que tenha mudado no mês seguinte do que não conseguir fazer uma
-- projeção".
--
-- A ideia em uma frase: ao abrir o app, nascem o mês corrente E os 12
-- seguintes; e, dali em diante, os meses à frente acompanham as contas fixas.
--
-- O que muda em relação ao bloco 11, e o que NÃO muda:
--
--   1. MUDA: "navegar é leitura" continua valendo, mas agora há o que ler.
--      Os meses à frente nascem junto com o corrente, na mesma chamada do
--      garantir_mes(), e não ao navegar. Navegar continua sem escrever nada.
--
--   2. NÃO MUDA: o cliente continua sem poder escolher mês. garantir_mes() não
--      recebe parâmetro, e quais meses nascem quem decide é o banco, pelo
--      relógio de São Paulo. O horizonte (12) mora num lugar só, em
--      privado.marcar_meses().
--
--   3. NÃO MUDA: apagar vale. Uma conta apagada num mês à frente não volta
--      sozinha — nem quando o mês chega, porque a marca dele já existe.
--
--   4. NOVO: os meses à frente acompanham as fixas. Um gatilho em modelo leva
--      para os meses posteriores ao corrente, e SÓ para as contas ainda não
--      pagas, o que muda na fixa: nascer, desligar, religar, apagar, mudar o
--      valor padrão e mudar as parcelas. O mês corrente não é tocado: nele
--      continua valendo o botão "Trazer N contas fixas", como antes.
--
--   5. NOVO: histórico e gráficos param no mês corrente. Mês à frente é
--      previsão, não passado; somado aos gráficos, "a pagar" viraria doze meses
--      de conta em aberto.
--
-- Idempotente.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Que mês é hoje, em um lugar só
-- ------------------------------------------------------------
-- Até aqui a conta morava dentro de privado.marcar_mes_corrente(). Agora três
-- lugares precisam dela (as marcas, o gatilho e o corte do histórico), e três
-- cópias da mesma conta são três chances de discordar à meia-noite.

create or replace function privado.mes_corrente()
returns date
language sql
stable
set search_path = public
as $$
  select date_trunc('month', (now() at time zone 'America/Sao_Paulo'))::date
$$;

revoke all    on function privado.mes_corrente() from public, anon;
grant execute on function privado.mes_corrente() to authenticated;

-- ------------------------------------------------------------
-- 2. A marca de mês nascido antes da hora
-- ------------------------------------------------------------
-- 'antecipado' quer dizer: este mês nasceu quando ainda estava à frente. A
-- marca continua não mentindo — daqui a seis meses dá para saber quais meses
-- nasceram como previsão e quais nasceram no dia 1º.

alter table public.mes_gerado drop constraint if exists mes_gerado_origem_ok;
alter table public.mes_gerado add constraint mes_gerado_origem_ok
  check (origem in ('automatico', 'backfill', 'antecipado'));

-- ------------------------------------------------------------
-- 3. O que uma conta fixa vira num mês, em um lugar só
-- ------------------------------------------------------------
-- É o corpo do gerar_mes() de sempre (blocos 9, 10 e 11), sem tirar nem pôr
-- regra: fixa ativa, valor padrão, janela de parcelas, parcela_n / parcela_de,
-- PIX estático, o "not exists" por descrição e o "on conflict" com alvo
-- nomeado. A única novidade é p_modelo: nulo traz todas as fixas, como o
-- botão; preenchido traz só aquela, que é o que o gatilho do item 6 precisa.
-- O gatilho NÃO pode chamar o gerar_mes() inteiro: ele traria de volta, num
-- mês à frente, as contas que a pessoa apagou de propósito.
--
-- security invoker e no schema privado: o PostgREST não publica, e a RLS de
-- modelo e lancamento continua valendo — p_casa de outra casa não insere
-- nada, porque a policy de lancamento exige casa_id = minha_casa().

create or replace function privado.lancar_fixas(p_casa uuid, p_mes date, p_modelo uuid default null)
returns int
language plpgsql
security invoker
set search_path = public
as $$
declare mes date; n int;
begin
  mes := date_trunc('month', p_mes)::date;

  insert into public.lancamento
    (casa_id, modelo_id, competencia, descricao, dia_vencimento, valor_previsto,
     parcela_n, parcela_de, codigo_pagamento, codigo_tipo)
  select p_casa, m.id, mes, m.descricao, m.dia_vencimento, m.valor_padrao,
         public.parcela_no_mes(m.parcelas_total, m.parcela_1, mes),
         m.parcelas_total,
         m.pix_estatico,
         case when m.pix_estatico is not null then 'pix' end
    from public.modelo m
   where m.casa_id = p_casa
     and m.ativo
     and (p_modelo is null or m.id = p_modelo)
     and (m.parcelas_total is null
          or public.parcela_no_mes(m.parcelas_total, m.parcela_1, mes)
             between 1 and m.parcelas_total)
     and not exists (
       select 1 from public.lancamento l
        where l.casa_id = p_casa and l.competencia = mes
          and lower(btrim(l.descricao)) = lower(btrim(m.descricao))
     )
  on conflict (casa_id, competencia, modelo_id) do nothing;

  get diagnostics n = row_count;
  return n;
end $$;

revoke all    on function privado.lancar_fixas(uuid, date, uuid) from public, anon;
grant execute on function privado.lancar_fixas(uuid, date, uuid) to authenticated;

-- O botão "Trazer N contas fixas" continua chamando gerar_mes(), com a mesma
-- assinatura e o mesmo resultado: agora ele só descobre a casa e delega.
create or replace function public.gerar_mes(p_competencia date)
returns int
language plpgsql
security invoker
set search_path = public
as $$
declare c uuid;
begin
  c := public.minha_casa();
  if c is null then raise exception 'Você não pertence a nenhuma casa.'; end if;
  return privado.lancar_fixas(c, p_competencia);
end $$;

-- ------------------------------------------------------------
-- 4. A única porta que grava as marcas
-- ------------------------------------------------------------
-- Substitui privado.marcar_mes_corrente(), com as mesmas garantias: SEM
-- PARÂMETRO (casa e meses vêm do JWT e do relógio de São Paulo), security
-- definer só aqui, e a única coisa que faz é gravar linhas cujas colunas ela
-- mesma decide. A diferença: em vez de uma marca, treze — o mês corrente e
-- os 12 seguintes.
--
-- O 12 é O horizonte da previsão, e mora só aqui. Na virada de cada mês, o
-- primeiro app aberto faz nascer mais um mês no fim da janela; a parcela que
-- cai depois do horizonte aparece quando o horizonte chega até ela.
--
-- Concorrência: dois aparelhos chamam isto ao mesmo tempo. As marcas são
-- gravadas sempre na mesma ordem (do corrente para a frente), então quem
-- chega depois BLOQUEIA na chave primária da primeira marca que disputa, até
-- a transação do primeiro terminar — e recebe conflito. Mesma ordem nos dois
-- lados quer dizer que não há como um esperar pelo outro em círculo.

create or replace function privado.marcar_meses(out mes date, out nasceu boolean)
returns setof record
language plpgsql
security definer
set search_path = public
as $$
declare c uuid; corrente date; k int;
begin
  c := public.minha_casa();
  if c is null then raise exception 'Você não pertence a nenhuma casa.'; end if;

  corrente := privado.mes_corrente();

  for k in 0 .. 12 loop
    mes := (corrente + make_interval(months => k))::date;

    insert into public.mes_gerado (casa_id, competencia, origem)
    values (c, mes, case when k = 0 then 'automatico' else 'antecipado' end)
    on conflict do nothing;

    nasceu := found;
    return next;
  end loop;
end $$;

revoke all    on function privado.marcar_meses() from public, anon;
grant execute on function privado.marcar_meses() to authenticated;

-- ------------------------------------------------------------
-- 5. Garantir o mês corrente e os 12 seguintes
-- ------------------------------------------------------------
-- Continua sem parâmetro e continua security invoker: o gerar_mes() roda como
-- a pessoa, e a RLS segue como segunda parede (ver bloco 11).
--
-- Devolve uma linha por mês, e a PRIMEIRA é o mês corrente. É o que mantém o
-- app de antes deste bloco funcionando: ele lê data[0].competencia como "o mês
-- que o banco diz ser o corrente". O app deste bloco não depende da ordem —
-- toma o menor.
--
-- "criadas = 0" continua querendo dizer "as contas já estão gravadas": a
-- marca e os lançamentos de quem venceu a disputa commitam juntos.

create or replace function public.garantir_mes()
returns table (competencia date, criadas int)
language plpgsql
security invoker
set search_path = public
as $$
declare m record;
begin
  for m in select * from privado.marcar_meses() loop
    competencia := m.mes;
    criadas := case when m.nasceu then public.gerar_mes(m.mes) else 0 end;
    return next;
  end loop;
end $$;

revoke all    on function public.garantir_mes() from public, anon;
grant execute on function public.garantir_mes() to authenticated;

-- A porta antiga sai: ninguém mais a chama, e uma porta security definer
-- sem uso é só superfície.
drop function if exists privado.marcar_mes_corrente();

-- ------------------------------------------------------------
-- 6. Os meses à frente acompanham as fixas
-- ------------------------------------------------------------
-- Só meses POSTERIORES ao corrente, e só os que já nasceram (têm marca). Só
-- conta NÃO PAGA é apagada ou alterada: o que já foi pago é registro, não
-- previsão.
--
--   fixa nova, ou religada   -> entra em todos os meses à frente
--   desligada, ou apagada    -> sai dos meses à frente
--   valor padrão mudou       -> muda onde a conta ainda tem o valor antigo;
--                               onde a pessoa digitou outro, o dela manda
--   parcelas mudaram         -> parcela_n / parcela_de acertados; sai o que
--                               ficou fora da janela; entra SÓ o mês que
--                               acabou de entrar nela (um mês que estava na
--                               janela e não tem a conta é um mês em que ela
--                               foi apagada de propósito)
--
-- "parcelar" (bloco 19) e "transformar as contas do mês em fixas" passam por
-- aqui sem mudar uma linha: os dois criam ou alteram a fixa, e o gatilho faz o
-- resto.
--
-- security invoker, como todo o resto: roda como a pessoa, sob a RLS. Dois
-- gatilhos, e não um, porque o apagar tem que vir ANTES: a chave estrangeira
-- de lancamento.modelo_id é "on delete set null", e depois do delete não há
-- mais como achar as contas daquela fixa.

create or replace function public.tg_modelo_meses_a_frente()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  corrente     date := privado.mes_corrente();
  entra_tudo   boolean := true;     -- fixa nova; no update, só se estava desligada
  janela_mudou boolean := false;
  g            record;
begin
  if tg_op = 'DELETE' then
    delete from public.lancamento l
     where l.casa_id = old.casa_id and l.modelo_id = old.id
       and l.competencia > corrente and not l.pago;
    return old;
  end if;

  if not new.ativo then
    if tg_op = 'UPDATE' and old.ativo then
      delete from public.lancamento l
       where l.casa_id = new.casa_id and l.modelo_id = new.id
         and l.competencia > corrente and not l.pago;
    end if;
    return null;
  end if;

  if tg_op = 'UPDATE' then
    entra_tudo := not old.ativo;

    if new.valor_padrao is distinct from old.valor_padrao then
      update public.lancamento l
         set valor_previsto = new.valor_padrao
       where l.casa_id = new.casa_id and l.modelo_id = new.id
         and l.competencia > corrente and not l.pago
         and l.valor_previsto is not distinct from old.valor_padrao;
    end if;

    janela_mudou := (new.parcelas_total, new.parcela_1)
                    is distinct from (old.parcelas_total, old.parcela_1);
    if janela_mudou then
      delete from public.lancamento l
       where l.casa_id = new.casa_id and l.modelo_id = new.id
         and l.competencia > corrente and not l.pago
         and new.parcelas_total is not null
         and public.parcela_no_mes(new.parcelas_total, new.parcela_1, l.competencia)
             not between 1 and new.parcelas_total;

      update public.lancamento l
         set parcela_n  = public.parcela_no_mes(new.parcelas_total, new.parcela_1, l.competencia),
             parcela_de = new.parcelas_total
       where l.casa_id = new.casa_id and l.modelo_id = new.id
         and l.competencia > corrente;
    end if;
  end if;

  for g in
    select m.competencia from public.mes_gerado m
     where m.casa_id = new.casa_id and m.competencia > corrente
     order by m.competencia
  loop
    if entra_tudo
       or (janela_mudou
           and old.parcelas_total is not null
           and public.parcela_no_mes(old.parcelas_total, old.parcela_1, g.competencia)
               not between 1 and old.parcelas_total)
    then
      perform privado.lancar_fixas(new.casa_id, g.competencia, new.id);
    end if;
  end loop;

  return null;
end $$;

revoke all on function public.tg_modelo_meses_a_frente() from public, anon, authenticated;

create or replace trigger modelo_meses_a_frente
  after insert or update on public.modelo
  for each row execute function public.tg_modelo_meses_a_frente();

create or replace trigger modelo_antes_de_apagar
  before delete on public.modelo
  for each row execute function public.tg_modelo_meses_a_frente();

-- ------------------------------------------------------------
-- 7. Histórico e gráficos param no mês corrente
-- ------------------------------------------------------------
-- historico() é a fonte do histórico_completo(), que é a fonte dos gráficos:
-- um corte aqui vale para as duas telas. Mesma assinatura, mesmo corpo do
-- bloco 13, mais o where.

create or replace function public.historico()
returns table (
  competencia date,
  previsto    numeric,
  pago        numeric,
  a_pagar     numeric,
  contas      bigint,
  sem_valor   bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  select l.competencia,
         coalesce(sum(l.valor_previsto), 0) as previsto,
         coalesce(sum(
           case when l.pago
                then coalesce(l.valor_pago, l.valor_previsto, 0)
                else 0
           end
         ), 0) as pago,
         coalesce(sum(
           case when not l.pago and l.valor_previsto is not null
                then l.valor_previsto
                else 0
           end
         ), 0) as a_pagar,
         count(*) as contas,
         count(*) filter (where not l.pago and l.valor_previsto is null) as sem_valor
    from public.lancamento l
   where l.competencia <= privado.mes_corrente()
   group by l.competencia
   order by l.competencia desc;
$$;

-- Os gráficos juntam as receitas por fora do histórico: uma receita lançada
-- num mês à frente entraria por ali. Mesma assinatura e mesmo corpo do bloco
-- 18, mais o where.
create or replace function public.graficos()
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
   where coalesce(d.competencia, r.competencia) <= privado.mes_corrente()
   order by competencia desc, origem;
$$;

-- ------------------------------------------------------------
-- Conferência
-- ------------------------------------------------------------
select n.nspname || '.' || p.proname as funcao,
       p.prosecdef as security_definer,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_executa,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_executa
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where (n.nspname = 'privado' and p.proname in ('mes_corrente', 'lancar_fixas', 'marcar_meses', 'marcar_mes_corrente'))
    or (n.nspname = 'public'  and p.proname in ('gerar_mes', 'garantir_mes', 'historico', 'graficos'))
 order by 1;
-- esperado (marcar_mes_corrente NÃO aparece):
--   privado.lancar_fixas  | f | p_casa uuid, p_mes date, p_modelo uuid | f | t
--   privado.marcar_meses  | t | OUT mes date, OUT nasceu boolean       | f | t
--   privado.mes_corrente  | f |                                        | f | t
--   public.garantir_mes   | f |                                        | f | t
--   public.gerar_mes      | f | p_competencia date                     | f | t
--   public.graficos       | f |                                        | f | t
--   public.historico      | f |                                        | f | t
