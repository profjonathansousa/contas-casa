/* Mede o texto do aviso. Não reimplementa nada: recorta do enviar.mjs real
   as duas funções puras (dinheiro e montarAviso) e roda elas. */
var fonte = readFile(DIR_APP + '/avisos/enviar.mjs');
var ini = fonte.indexOf('const dinheiro');
var fim = fonte.indexOf('const resumos');
if (ini < 0 || fim < 0 || fim <= ini) throw new Error('nao achei as funcoes no enviar.mjs');
eval(fonte.slice(ini, fim));

var ok = 0, falhou = 0;
function medir(n, o, e) {
  if (JSON.stringify(o) === JSON.stringify(e)) { ok++; print('  ok   ' + n + ' = ' + JSON.stringify(o)); }
  else { falhou++; print('  FALHA ' + n + ' = ' + JSON.stringify(o) + ' (esperado ' + JSON.stringify(e) + ')'); }
}

print('\n== texto do aviso (valores ficticios) ==');

var a = montarAviso({ dia: '2026-09-10', vencem_hoje: 4, valor_hoje: 212.30,
  atrasadas: 9, valor_atrasado: 1500.00, sem_valor: 0,
  titulos: ['Água','Internet','Luz','Telefone'] });
medir('titulo', a.titulo, '4 contas vencem hoje');
medir('corpo',  a.corpo, 'Água, Internet, Luz, Telefone — R$ 212,30 · 9 atrasadas (R$ 1.500,00)');
medir('tag do dia', a.tag, 'resumo-2026-09-10');

print('\n  -- uma conta só: singular em tudo --');
var b = montarAviso({ dia: '2026-09-03', vencem_hoje: 1, valor_hoje: 80,
  atrasadas: 1, valor_atrasado: 45, sem_valor: 0, titulos: ['Aluguel'] });
medir('titulo', b.titulo, '1 conta vence hoje');
medir('corpo',  b.corpo, 'Aluguel — R$ 80,00 · 1 atrasada (R$ 45,00)');

print('\n  -- lista longa nao estoura a notificacao --');
var c = montarAviso({ dia: '2026-09-05', vencem_hoje: 6, valor_hoje: 999.99,
  atrasadas: 0, valor_atrasado: 0, sem_valor: 0,
  titulos: ['Água','Escola','Internet','Luz','Mercado','Telefone'] });
medir('corta em 4 e diz quantas faltam', c.corpo,
      'Água, Escola, Internet, Luz e mais 2 — R$ 999,99');

print('\n  -- o "???" aparece no aviso --');
var d = montarAviso({ dia: '2026-09-14', vencem_hoje: 2, valor_hoje: 250,
  atrasadas: 0, valor_atrasado: 0, sem_valor: 1, titulos: ['Ginástica','Mercado'] });
medir('avisa que falta valor', d.corpo,
      'Ginástica, Mercado — R$ 250,00 · 1 ainda sem valor');

print('\n  -- so atrasadas, nada vencendo hoje --');
var e = montarAviso({ dia: '2026-09-30', vencem_hoje: 0, valor_hoje: 0,
  atrasadas: 3, valor_atrasado: 1200.5, sem_valor: 0, titulos: null });
medir('titulo', e.titulo, '3 contas atrasadas');
medir('corpo',  e.corpo, 'R$ 1.200,50');

print('\n  -- CONTROLE NEGATIVO --');
print('  (dia sem nada NAO pode gerar aviso; senao a pessoa aprende a ignorar)');
medir('dia limpo nao vira aviso',
      montarAviso({ dia: '2026-09-02', vencem_hoje: 0, valor_hoje: 0,
                    atrasadas: 0, valor_atrasado: 0, sem_valor: 0, titulos: null }), null);
// formatacao do dinheiro medida pelo caminho real, nao chamando a funcao solta
medir('virgula decimal e ponto de milhar',
      montarAviso({ dia: '2026-09-01', vencem_hoje: 0, valor_hoje: 0,
                    atrasadas: 21, valor_atrasado: 9876.54, sem_valor: 0, titulos: null }).corpo,
      'R$ 9.876,54');

print('\nmedidas ok: ' + ok + '   falhas: ' + falhou);
