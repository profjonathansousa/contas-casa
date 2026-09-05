/* Mede o texto do aviso e a escolha do slot. Não reimplementa nada: recorta do
   enviar.mjs real a faixa marcada como pura e roda ela.
   A marca é explícita no arquivo -- antes o recorte ia de "const dinheiro" ate
   "const resumos", e qualquer renomeacao silenciosa quebrava a bancada. */
var fonte = readFile(DIR_APP + '/avisos/enviar.mjs');
var ini = fonte.indexOf('// ==== funções puras');
var fim = fonte.indexOf('// ==== fim das funções puras');
if (ini < 0 || fim < 0 || fim <= ini) throw new Error('nao achei a faixa pura no enviar.mjs');
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

print('\n== que horas sao em Brasilia ==');
print('  (o Actions roda em UTC; quem manda no aviso e o relogio daqui)');

function emBR(ano, mes0, dia, horaUTC, min) {
  return emSaoPaulo(new Date(Date.UTC(ano, mes0, dia, horaUTC, min || 0)));
}
medir('23:10 UTC -> dia',  emBR(2026, 8, 5, 23, 10).dia, '2026-09-05');
medir('23:10 UTC -> hora', emBR(2026, 8, 5, 23, 10).hora, 20);

print('\n  -- a virada do dia em UTC nao vira o dia aqui --');
print('  (a repescagem do aviso das 20h cai depois da meia-noite em UTC)');
medir('01:17 UTC do dia 6 ainda e dia 5 aqui', emBR(2026, 8, 6, 1, 17).dia, '2026-09-05');
medir('e sao 22h',                             emBR(2026, 8, 6, 1, 17).hora, 22);

print('\n  -- CONTROLE: meia-noite e 0, nao 24 --');
print('  (Intl devolve "24" em alguns motores; se voltar 24, o slot da noite nunca fecha)');
medir('meia-noite', emBR(2026, 8, 6, 3, 5).hora, 0);

print('\n== qual aviso esta aberto ==');
medir('11h: cedo demais',      slotsAbertos(11), []);
medir('12h: abre o do almoco', slotsAbertos(12), ['dia_12h']);
medir('17h: ainda vale',       slotsAbertos(17), ['dia_12h']);
medir('20h: abrem os dois da noite', slotsAbertos(20), ['vespera_20h', 'dia_20h']);
medir('23h: ainda valem',            slotsAbertos(23), ['vespera_20h', 'dia_20h']);

print('\n  -- CONTROLE NEGATIVO --');
print('  (aviso atrasado tem hora para deixar de fazer sentido; senao chega de madrugada)');
medir('18h: o do almoco ja expirou', slotsAbertos(18), []);
medir('meia-noite: nada abre',       slotsAbertos(0), []);
medir('3h da manha: nada abre',      slotsAbertos(3), []);

print('\n== slot pedido a mao tem que existir ==');
medir('vespera', slotConhecido('vespera_20h'), true);
medir('meio-dia', slotConhecido('dia_12h'),    true);
medir('noite',    slotConhecido('dia_20h'),    true);
print('  -- CONTROLE NEGATIVO --');
print('  (nome errado nao pode virar notificacao com tag inventada)');
medir('auto nao e slot',   slotConhecido('auto'),    false);
medir('dia_21h nao existe', slotConhecido('dia_21h'), false);

print('\n== o aviso da vespera pede uma acao ==');
var v = montarVespera({ dia: '2026-09-09', vencem_amanha: 2, valor_amanha: 320.50,
  titulos_amanha: ['Aluguel', 'Escola'] });
medir('titulo', v.titulo, '2 contas vencem amanha'.replace('amanha', 'amanhã'));
medir('corpo',  v.corpo, 'Aluguel, Escola — R$ 320,50 · deixe o pagamento pronto');
medir('tag propria, nao a do resumo', v.tag, 'vespera-2026-09-09');

print('\n  -- uma so: singular --');
var v1 = montarVespera({ dia: '2026-09-09', vencem_amanha: 1, valor_amanha: 80,
  titulos_amanha: ['Luz'] });
medir('titulo', v1.titulo, '1 conta vence amanhã');

print('\n  -- lista longa nao estoura --');
var v4 = montarVespera({ dia: '2026-09-09', vencem_amanha: 6, valor_amanha: 999.99,
  titulos_amanha: ['Água','Escola','Internet','Luz','Mercado','Telefone'] });
medir('corta em 4', v4.corpo,
      'Água, Escola, Internet, Luz e mais 2 — R$ 999,99 · deixe o pagamento pronto');

print('\n  -- CONTROLE NEGATIVO --');
print('  (nada vencendo amanha NAO pode virar aviso de vespera)');
medir('vespera vazia', montarVespera({ dia: '2026-09-09', vencem_amanha: 0,
  valor_amanha: 0, titulos_amanha: null }), null);
print('  (e conta atrasada nao entra na vespera: ela e assunto dos avisos do dia)');
medir('atrasada nao vira vespera', montarVespera({ dia: '2026-09-09', vencem_amanha: 0,
  valor_amanha: 0, atrasadas: 5, valor_atrasado: 900, titulos_amanha: null }), null);

print('\n== a vespera diz o que falta preparar ==');
print('  (era o pedido original: em vez de so informar, pedir uma acao)');
function vespera(quantas, semCodigo) {
  return montarVespera({ dia: '2026-09-09', vencem_amanha: quantas, valor_amanha: 100,
    titulos_amanha: ['Luz', 'Agua'].slice(0, quantas), sem_codigo_amanha: semCodigo }).corpo;
}
medir('nenhum codigo colado',  vespera(2, 2), 'Luz, Agua — R$ 100,00 · faltam colar 2 códigos no app');
medir('falta um',              vespera(2, 1), 'Luz, Agua — R$ 100,00 · falta colar 1 código no app');
medir('esta tudo pronto',      vespera(2, 0), 'Luz, Agua — R$ 100,00 · pagamento já preparado');

print('\n  -- CONTROLE NEGATIVO --');
print('  (banco sem o sql/10 nao devolve o campo; o aviso NAO pode afirmar');
print('   que esta tudo pronto quando ele nem sabe)');
medir('sem o campo, nao afirma nada', vespera(2, undefined),
      'Luz, Agua — R$ 100,00 · deixe o pagamento pronto');

print('\n== cada slot puxa a coluna certa do perfil ==');
medir('vespera',  colunaDoSlot('vespera_20h'), 'avisa_vespera_20h');
medir('meio-dia', colunaDoSlot('dia_12h'),     'avisa_dia_12h');
medir('noite',    colunaDoSlot('dia_20h'),     'avisa_dia_20h');

print('\n== e monta o texto certo para cada slot ==');
var rTudo = { dia: '2026-09-09', vencem_hoje: 1, valor_hoje: 50, atrasadas: 0,
  valor_atrasado: 0, sem_valor: 0, titulos: ['Agua'],
  vencem_amanha: 1, valor_amanha: 80, titulos_amanha: ['Luz'] };
medir('vespera fala do amanha',  montarDoSlot(rTudo, 'vespera_20h').titulo, '1 conta vence amanhã');
medir('meio-dia fala do hoje',   montarDoSlot(rTudo, 'dia_12h').titulo,     '1 conta vence hoje');
medir('noite tambem fala do hoje', montarDoSlot(rTudo, 'dia_20h').titulo,   '1 conta vence hoje');

print('\n== a tag separa os dois avisos do mesmo dia ==');
print('  (mesma tag faria o da noite apagar o do almoco na tela do celular)');
var base = montarAviso({ dia: '2026-09-10', vencem_hoje: 1, valor_hoje: 10,
  atrasadas: 0, valor_atrasado: 0, sem_valor: 0, titulos: ['Luz'] }).tag;
medir('tag do almoco', tagDoSlot(base, 'dia_12h'), 'resumo-2026-09-10-dia_12h');
medir('tag da noite',  tagDoSlot(base, 'dia_20h'), 'resumo-2026-09-10-dia_20h');
medir('e as duas sao diferentes',
      tagDoSlot(base, 'dia_12h') !== tagDoSlot(base, 'dia_20h'), true);

print('\nmedidas ok: ' + ok + '   falhas: ' + falhou);
