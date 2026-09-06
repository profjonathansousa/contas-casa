-- ============================================================
-- Nossas Contas — bloco 11: o mês nasce sozinho.
--
-- O buraco que isto tapa: até aqui o mês só existia depois que alguém tocava
-- "Trazer N contas fixas". Se ninguém tocasse, o robô dos avisos não tinha o
-- que avisar. A conta vencia em silêncio.
--
-- A ideia em uma frase: ao abrir o app, o mês corrente nasce uma vez — e
-- nasce no banco, não no JavaScript.
--
-- As três separações que mandam no desenho, e que a auditoria obrigou a
-- escrever antes de qualquer linha:
--
--   1. NASCER e TRAZER O QUE FALTA são coisas diferentes.
--      Nascer é automático, acontece UMA vez por mês, e é o que esta migration
--      cria. Trazer o que falta continua sendo o botão, explícito, quantas
--      vezes a pessoa quiser. Sem essa separação, uma conta fixa cadastrada no
--      dia 12 nunca entraria no mês.
--
--   2. A TRAVA é o MÊS, não a linha.
--      O que precisa ser idempotente é "este mês já nasceu nesta casa". Por
--      isso a trava é a chave primária de mes_gerado, e não uma constraint na
--      lancamento. Uma tentativa anterior pôs a trava na descrição do
--      lançamento: duas contas fixas chamadas "Internet" teriam virado uma só,
--      em silêncio.
--
--   3. QUEM DECIDE SE GERA e QUEM DECIDE SE É A MESMA LINHA são perguntas
--      distintas. A primeira é o "not exists" por descrição, que continua
--      inteiro e é o que impede duplicar uma conta digitada à mão. A segunda é
--      o índice único por modelo_id, que só arbitra entre linhas que a função
--      já decidiu inserir — todas com modelo_id preenchido. Trocar uma pela
--      outra quebra uma das duas garantias.
--
-- Ler nunca escreve: navegar entre meses não gera nada, e não pode gerar,
-- porque garantir_mes() não aceita competência.
-- Idempotente.
-- ============================================================

-- ------------------------------------------------------------
-- 1. A marca de que o mês nasceu
-- ------------------------------------------------------------
-- Uma linha aqui quer dizer: "esta competência desta casa já foi
-- inicializada". A chave primária é o que arbitra dois aparelhos abrindo o app
-- no mesmo segundo — não é índice de apoio, é a trava.
--
-- origem existe para que a marca nunca minta: 'automatico' foi este bloco que
-- fez nascer; 'backfill' é um mês que já tinha nascido antes deste bloco
-- existir, pelo botão. Daqui a seis meses a diferença não se recupera de
-- memória.

create table if not exists public.mes_gerado (
  casa_id     uuid        not null references public.casa(id) on delete cascade,
  competencia date        not null,
  gerado_em   timestamptz not null default now(),
  origem      text        not null default 'automatico',
  primary key (casa_id, competencia),
  constraint mes_gerado_dia_1
    check (competencia = date_trunc('month', competencia)::date),
  constraint mes_gerado_origem_ok
    check (origem in ('automatico', 'backfill'))
);

-- ------------------------------------------------------------
-- 2. RLS da marca
-- ------------------------------------------------------------
-- Sem UPDATE e sem DELETE, de propósito: é isso que torna durável apagar uma
-- conta. Se o app pudesse desmarcar um mês, a durabilidade seria uma
-- convenção do cliente; sem os dois verbos, é propriedade do banco. Um mês,
-- uma vez nascido, não desnasce.
--
-- E o cliente não escreve aqui de jeito nenhum. A tabela fica exposta em
-- /rest/v1/mes_gerado como qualquer outra, e uma policy de INSERT — por mais
-- estreita que fosse — ainda deixaria a sessão logada gravar À MÃO a marca do
-- mês corrente sem gerar nada. Aí garantir_mes() encontraria a marca, devolveria
-- zero e não chamaria gerar_mes(): o mês ficaria marcado como nascido sem ter
-- nascido, e as contas do mês simplesmente não viriam. Um POST de uma linha,
-- em silêncio, contra as duas invariantes do bloco ("no máximo uma geração por
-- competência" e "toda marca é verdadeira").
--
-- Duas versões anteriores desta migration tentaram fechar isso escolhendo
-- VALORES aceitáveis (que mês, que origem). O que faltava era fechar
-- AUTORIDADE: quem pode escrever. Por isso não há grant de INSERT e não há
-- policy de INSERT. Sem o privilégio, o PostgREST recusa antes de a RLS ser
-- consultada. A única porta é a função do item 5.

alter table public.mes_gerado enable row level security;
alter table public.mes_gerado force  row level security;

drop policy if exists mes_gerado_ler   on public.mes_gerado;
drop policy if exists mes_gerado_criar on public.mes_gerado;

create policy mes_gerado_ler on public.mes_gerado for select to authenticated
  using (casa_id = public.minha_casa());

revoke all on public.mes_gerado from anon, authenticated;
grant select on public.mes_gerado to authenticated;

-- ------------------------------------------------------------
-- 3. A identidade de um lançamento gerado
-- ------------------------------------------------------------
-- Um modelo produz no máximo uma conta por competência. É invariante de
-- integridade, não é a trava da automação (a trava é o item 1).
--
-- Não é índice parcial e não precisa ser: lançamento digitado à mão tem
-- modelo_id nulo, e nulo nunca colide em índice único btree — os manuais ficam
-- de fora sozinhos. Sem cláusula WHERE, o ON CONFLICT abaixo pode nomear a
-- chave com precisão.
--
-- De quebra fecha um defeito que já existia: renomear uma conta fixa com o mês
-- já gerado fazia o "not exists" por descrição deixar de casar, e a mesma
-- conta entrava duas vezes. Agora o banco recusa.

create unique index if not exists lancamento_do_modelo_idx
  on public.lancamento (casa_id, competencia, modelo_id);

-- ------------------------------------------------------------
-- 4. Gerar o mês: mesma regra de negócio, uma linha a mais de mecanismo
-- ------------------------------------------------------------
-- Idêntica à do sql/10 em TUDO que decide quais contas devem existir: modelo
-- ativo, valor padrão, janela de parcelas, parcela_n / parcela_de, PIX
-- estático e o "not exists" por descrição.
--
-- A única adição é o "on conflict" com alvo nomeado. Ele é necessário porque o
-- botão manual chama esta função sem passar pela trava do mes_gerado: duas
-- pessoas tocando "Trazer 3 contas fixas" no mesmo segundo passariam as duas
-- pelo "not exists". Alvo nomeado, e não DO NOTHING largo: assim ele declara
-- qual identidade está protegendo, e não engole conflito de constraint futura.

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
     parcela_n, parcela_de, codigo_pagamento, codigo_tipo)
  select c, m.id, mes, m.descricao, m.dia_vencimento, m.valor_padrao,
         public.parcela_no_mes(m.parcelas_total, m.parcela_1, mes),
         m.parcelas_total,
         m.pix_estatico,
         case when m.pix_estatico is not null then 'pix' end
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
     )
  on conflict (casa_id, competencia, modelo_id) do nothing;

  get diagnostics n = row_count;
  return n;
end $$;

-- ------------------------------------------------------------
-- 5. A única porta que grava a marca
-- ------------------------------------------------------------
-- Schema separado, e é o schema que faz o trabalho: o PostgREST só publica o
-- public, então nada aqui dentro vira endpoint. Se este ajudante morasse no
-- public, um POST em /rest/v1/rpc/marcar_mes_corrente reabriria a brecha
-- inteira — agora com autoridade de dono de tabela, que é pior.

create schema if not exists privado;
revoke all   on schema privado from public, anon;
grant  usage on schema privado to authenticated;

-- SEM PARÂMETRO, e é isso que o torna seguro: casa e mês ele calcula sozinho,
-- do JWT e do relógio de São Paulo. Não existe valor que o cliente possa
-- mandar para marcar outro mês ou a casa de outra pessoa. É a única coisa que
-- este definer faz — gravar uma linha cujas colunas todas ele mesmo decide.
--
-- security definer aqui, e SÓ aqui. Foi tentador marcar o garantir_mes()
-- inteiro como definer: seria um diff menor e fecharia a mesma porta. Mas o
-- dono da função no Supabase é o postgres, que tem rolbypassrls — e o
-- gerar_mes(), chamado lá de dentro, passaria a rodar com a RLS DESLIGADA em
-- modelo e lancamento. Medido numa réplica com duas casas: a mesma consulta
-- devolve 0 lançamentos como authenticated e 1 (o da outra casa) dentro de um
-- definer. O gerar_mes() continuaria correto, porque filtra por casa_id em
-- todo lugar — mas o where viraria a única parede entre as casas, em vez da
-- segunda. Não vale trocar uma invariante por outra.

create or replace function privado.marcar_mes_corrente(out mes date, out nasceu boolean)
returns record
language plpgsql
security definer
set search_path = public
as $$
declare c uuid;
begin
  c := public.minha_casa();
  if c is null then raise exception 'Você não pertence a nenhuma casa.'; end if;

  mes := date_trunc('month', (now() at time zone 'America/Sao_Paulo'))::date;

  insert into public.mes_gerado (casa_id, competencia, origem)
  values (c, mes, 'automatico')
  on conflict do nothing;

  nasceu := found;
end $$;

revoke all    on function privado.marcar_mes_corrente() from public, anon;
grant execute on function privado.marcar_mes_corrente() to authenticated;

-- ------------------------------------------------------------
-- 6. Garantir o mês corrente
-- ------------------------------------------------------------
-- NÃO recebe competência, e é a assinatura que faz a garantia: não existe
-- pedido que o cliente possa formular para gerar um mês histórico. Navegar
-- para janeiro continua sendo leitura mesmo que alguém, daqui a um ano, tente
-- ligar a automação lá.
--
-- O mês vem do relógio de São Paulo, no banco. O mesDeHoje() do app usa o
-- relógio do aparelho, que às 21h de 30/09 num telefone em UTC já virou
-- outubro. Quem decide é o Brasil, como no bloco 6.
--
-- Concorrência: dois aparelhos chamam isto ao mesmo tempo. Um insere a marca;
-- o outro BLOQUEIA na chave primária até a transação do primeiro terminar, e
-- só então recebe o conflito. Como o PostgREST roda a função inteira numa
-- transação, a marca e os lançamentos do vencedor commitam juntos — então
-- "criadas = 0" quer dizer literalmente "as contas já estão gravadas", nunca
-- "estão a caminho". É isso que impede o mês pela metade.

-- CONTINUA security invoker, de propósito: assim o gerar_mes() chamado aqui
-- roda como a pessoa, e a RLS de modelo e lancamento segue valendo como
-- segunda parede. O único trecho com autoridade de dono é a gravação da marca,
-- no item 5. Medido: dentro desta função, current_user = authenticated e o
-- lançamento da outra casa continua invisível.
--
-- O mês vem do item 5, uma vez só. Recalcular aqui seria ter duas fontes de
-- verdade para "que mês é hoje" — exatamente o que este bloco existe para
-- evitar.

create or replace function public.garantir_mes()
returns table (competencia date, criadas int)
language plpgsql
security invoker
set search_path = public
as $$
declare m record;
begin
  select * into m from privado.marcar_mes_corrente();

  if not m.nasceu then
    -- o mês já tinha nascido: por este aparelho, por outro, ou pelo backfill
    return query select m.mes, 0;
    return;
  end if;

  return query select m.mes, public.gerar_mes(m.mes);
end $$;

revoke all    on function public.garantir_mes() from public, anon;
grant execute on function public.garantir_mes() to authenticated;

-- ------------------------------------------------------------
-- 7. Backfill: os meses que já tinham nascido pelo botão
-- ------------------------------------------------------------
-- Sem isto, o primeiro app aberto depois desta migration marcaria o mês
-- corrente como novo e rodaria a geração nele. Hoje isso criaria zero linhas
-- (as duas competências estão completas), mas passaria a valer também para
-- tudo que for apagado de propósito daqui até a aplicação. A marca fecha essa
-- janela.
--
-- O "modelo_id is not null" é o que impede uma marca falsa: só marca a
-- competência onde a geração DEMONSTRAVELMENTE já rodou. Um mês que tenha
-- apenas conta digitada à mão não é marcado — e é exatamente o mês em que a
-- primeira geração automática ainda deve acontecer. Hoje essa cláusula não
-- exclui nada; a razão de existir é o mês em que ela vai excluir.
--
-- Em 06/09/2026 o banco tinha duas competências, ambas 100% vindas de modelo:
-- 2026-09 (20 lançamentos) e 2026-10 (14). Espera-se que este insert marque
-- EXATAMENTE 2 linhas. O sql/11_prova_geracao.sql confere.
--
-- CONTEXTO DE ROLE, e por que isto NÃO depende da policy do cliente: esta
-- migration roda no SQL Editor do Supabase, como "postgres", que tem
-- rolbypassrls = true (conferido no catálogo em 06/09/2026; authenticated e
-- anon têm false). RLS não se aplica, então o 'backfill' passa mesmo com a
-- policy de INSERT exigindo origem = 'automatico' e o mês corrente.
--
-- E o backfill PRECISA desse contexto por dois motivos: o select lê
-- public.lancamento de todas as casas, o que authenticated não enxerga; e
-- authenticated não tem mais nem o privilégio de INSERT nesta tabela. Rodar
-- isto como authenticated não falharia em silêncio — apanharia com
-- "permission denied for table mes_gerado". O lugar certo é o SQL Editor.

insert into public.mes_gerado (casa_id, competencia, gerado_em, origem)
select distinct l.casa_id, l.competencia, now(), 'backfill'
  from public.lancamento l
 where l.modelo_id is not null
on conflict do nothing;
