-- ============================================================
-- Nossas Contas — configuração inicial da casa e dos dois perfis.
-- Rodar UMA vez, DEPOIS de criar os dois usuários em Authentication > Users.
--
-- ESTE ARQUIVO É UM MODELO. Troque os três valores abaixo antes de rodar.
-- NÃO comite a versão preenchida: salve-a como
--   sql/02_config_inicial.local.sql   (o .gitignore já ignora *.local.*)
-- ============================================================

do $$
declare
  -- >>> TROQUE OS TRÊS VALORES ABAIXO <<<
  email_1 text := 'pessoa1@exemplo.com';
  nome_1  text := 'Pessoa Um';
  email_2 text := 'pessoa2@exemplo.com';
  nome_2  text := 'Pessoa Dois';
  nome_da_casa text := 'Nossa Casa';
  -- >>> fim dos valores a trocar <<<

  id_casa uuid;
  id_1    uuid;
  id_2    uuid;
begin
  select id into id_1 from auth.users where lower(email) = lower(email_1);
  select id into id_2 from auth.users where lower(email) = lower(email_2);

  if id_1 is null then
    raise exception 'Usuário % não existe. Crie em Authentication > Users primeiro.', email_1;
  end if;
  if id_2 is null then
    raise exception 'Usuário % não existe. Crie em Authentication > Users primeiro.', email_2;
  end if;

  -- reaproveita a casa se este script já tiver rodado
  select casa_id into id_casa from public.perfil where id = id_1;
  if id_casa is null then
    insert into public.casa (nome) values (nome_da_casa) returning id into id_casa;
  end if;

  insert into public.perfil (id, casa_id, nome) values (id_1, id_casa, nome_1)
    on conflict (id) do update set casa_id = excluded.casa_id, nome = excluded.nome;

  insert into public.perfil (id, casa_id, nome) values (id_2, id_casa, nome_2)
    on conflict (id) do update set casa_id = excluded.casa_id, nome = excluded.nome;

  raise notice 'Casa % configurada com 2 perfis.', id_casa;
end
$$;

-- Conferência: tem que voltar 2 linhas, as duas com o MESMO casa_id.
select p.nome, p.casa_id, c.nome as casa
from public.perfil p join public.casa c on c.id = p.casa_id
order by p.nome;
