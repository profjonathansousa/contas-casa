/* Medições sobre o app.js real, já carregado acima. */
var ok = 0, falhou = 0;
function medir(nome, obtido, esperado) {
  var bate = JSON.stringify(obtido) === JSON.stringify(esperado);
  if (bate) { ok++; print('  ok   ' + nome + ' = ' + JSON.stringify(obtido)); }
  else { falhou++; print('  FALHA ' + nome + ' = ' + JSON.stringify(obtido) + '  (esperado ' + JSON.stringify(esperado) + ')'); }
}
function esperar() { for (var i = 0; i < 60; i++) drainMicrotasks(); }

var q = function (s) { return document.querySelector(s); };
function itensDesenhados() {
  return q('#lista').filhos.filter(function (f) { return f.className.indexOf('item') === 0; });
}
function textoDe(el) {
  return (el._txt || '') + (el._html || '') + el.filhos.map(textoDe).join(' ');
}

esperar();

print('\n== 1. abriu no mes corrente e pediu so esse mes ==');
var MESHOJE = (function(){var d=new Date();return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-01';})();
medir('selects feitos', LOG.selects.length, 1);
medir('competencia pedida', LOG.selects[0].comp, MESHOJE);
medir('tela de login escondida', q('#tela-login').hidden, true);
medir('tela do mes visivel', q('#tela-mes').hidden, false);

print('\n== 2. totais do cabecalho ==');
// previsto = 1800 + 95,40 + 129,90 = 2025,30 | pago = 129,90 | a pagar = 1895,40 | sem valor = 2
medir('previsto', q('#t-previsto').innerHTML, '<i>R$</i> 2.025,30');
medir('pago',     q('#t-pago').innerHTML,     '<i>R$</i> 129,90');
medir('a pagar',  q('#t-apagar').innerHTML,   '<i>R$</i> 1.895,40');
medir('aviso de em aberto', q('#t-aberto')._txt, '2 contas em aberto, sem valor');
medir('aviso visivel', q('#t-aberto').hidden, false);

print('\n== 3. agrupamento por dia, ordem crescente ==');
var cabecalhos = q('#lista').filhos.filter(function (f) { return f.className === 'dia'; })
                    .map(function (f) { return f._txt; });
medir('cabecalhos de dia (dd/mm)', cabecalhos,
      [MESHOJE.slice(0,8)+'05', MESHOJE.slice(0,8)+'08', MESHOJE.slice(0,8)+'10', MESHOJE.slice(0,8)+'15']
        .map(function (d) { return d.slice(8) + '/' + d.slice(5,7); }));
medir('itens desenhados', itensDesenhados().length, 5);

print('\n== 4. selo de autoria ==');
var pagos = itensDesenhados().filter(function (i) { return i.className.indexOf('pago') > 0; });
medir('itens ja pagos', pagos.length, 1);
var selo = null;
(function busca(el){ if (el.className==='selo') selo = el._txt; el.filhos.forEach(busca); })(pagos[0]);
medir('formato do selo', /^pago por Diva, \d\d:\d\d$/.test(selo || ''), true);

print('\n== 5. um toque marca pago, mandando UM campo so ==');
var antesUp = LOG.updates.length;
var primeiro = itensDesenhados()[0];          // Aluguel, nao pago
primeiro.disparar('click');
medir('marcou na hora (otimista)', itensDesenhados()[0].className.indexOf('pago') > 0, true);
esperar();
medir('updates enviados', LOG.updates.length - antesUp, 1);
medir('campos no update', LOG.updates[antesUp].campos, ['pago']);
medir('valor enviado', LOG.updates[antesUp].valores.pago, true);
medir('id enviado', LOG.updates[antesUp].id, 'l1');
var selo2 = null;
(function busca(el){ if (el.className==='selo') selo2 = el._txt; el.filhos.forEach(busca); })(itensDesenhados()[0]);
medir('selo agora e meu', /^pago por Jonathan, \d\d:\d\d$/.test(selo2 || ''), true);

print('\n== 6. o mesmo toque desmarca ==');
var antes2 = LOG.updates.length;
itensDesenhados()[0].disparar('click');
esperar();
medir('campos no update', LOG.updates[antes2].campos, ['pago']);
medir('valor enviado', LOG.updates[antes2].valores.pago, false);
medir('voltou a nao-pago', itensDesenhados()[0].className.indexOf('pago') > 0, false);

print('\n== 7. editar valor (o "???" vira numero) ==');
var luz = itensDesenhados()[1];               // Luz, dia 8, sem valor
var botaoValor = luz.filhos[2];
medir('mostra ??? antes', botaoValor._html, '???');
var antes3 = LOG.updates.length;
botaoValor.disparar('click');
var campo = luz.filhos[2];
medir('virou campo de digitacao', campo.className, 'editando');
campo.value = '1.234,56';
campo.disparar('blur');
esperar();
medir('campos no update', LOG.updates[antes3].campos, ['valor_previsto']);
medir('numero interpretado', LOG.updates[antes3].valores.valor_previsto, 1234.56);
medir('contagem de em-aberto caiu de 2 para 1', q('#t-aberto')._txt, '1 conta em aberto, sem valor');

print('\n== 8. navegar entre meses ==');
var antes4 = LOG.selects.length;
q('#mes-prox').disparar('click');
esperar();
var p = MESHOJE.split('-'); var prox = new Date(+p[0], +p[1], 1);
var esperadoProx = prox.getFullYear() + '-' + String(prox.getMonth()+1).padStart(2,'0') + '-01';
medir('mes seguinte pedido', LOG.selects[antes4].comp, esperadoProx);
q('#mes-ant').disparar('click');
esperar();
medir('voltou para o mes corrente', LOG.selects[LOG.selects.length-1].comp, MESHOJE);

print('\n== 9. conta avulsa ==');
q('#btn-add').disparar('click');
medir('folha abriu', q('#folha-add').hidden, false);
q('#ad-desc').value = 'Gas';
q('#ad-dia').value = '22';
q('#ad-valor').value = '';                    // valor desconhecido de proposito
q('#folha-add').disparar('submit');
esperar();
medir('insert feito', LOG.inserts.length, 1);
medir('descricao', LOG.inserts[0].descricao, 'Gas');
medir('dia', LOG.inserts[0].dia_vencimento, 22);
medir('valor vazio vira nulo', LOG.inserts[0].valor_previsto, null);
medir('competencia do mes na tela', LOG.inserts[0].competencia, MESHOJE);
medir('folha fechou', q('#folha-add').hidden, true);
medir('entrou na lista', itensDesenhados().length, 6);
var descs = itensDesenhados().map(function (i) { return i.filhos[1].filhos[0]._txt; });
medir('a nova entrou ordenada pelo dia', descs[descs.length-1], 'Gas');

print('\n== 10. tempo real: a tela do outro muda sozinha ==');
medir('canal assinado', LOG.canais.length, 1);
medir('filtro do canal', LOG.canais[0].cfg.filter,
      'casa_id=eq.cccccccc-0000-0000-0000-000000000003');
var alvo = itensDesenhados()[0];
medir('Aluguel esta nao-pago antes', alvo.className.indexOf('pago') > 0, false);
LOG.canais[0].fn({ eventType: 'UPDATE', new: {
  id: 'l1', competencia: MESHOJE, descricao: 'Aluguel', dia_vencimento: 5,
  vencimento: MESHOJE.slice(0,8)+'05', valor_previsto: 1800, valor_pago: null,
  pago: true, pago_em: '2026-08-31T09:15:00.000Z',
  pago_por: 'bbbbbbbb-0000-0000-0000-000000000002' } });
medir('mudou sozinho, sem eu tocar', itensDesenhados()[0].className.indexOf('pago') > 0, true);
var selo3 = null;
(function busca(el){ if (el.className==='selo') selo3 = el._txt; el.filhos.forEach(busca); })(itensDesenhados()[0]);
medir('selo diz quem foi', /^pago por Diva, \d\d:\d\d$/.test(selo3 || ''), true);

print('\n== 11. CONTROLE NEGATIVO ==');
print('  (se a bancada nao medisse nada de verdade, isto passaria — tem que falhar)');
var antesN = LOG.updates.length;
var itemQualquer = itensDesenhados()[1];
// nao disparo clique nenhum: nada pode ter sido enviado
medir('update sem clique (tem que ser 0)', LOG.updates.length - antesN, 0);
// e um evento de outro mes tem que ser ignorado
var nItens = itensDesenhados().length;
LOG.canais[0].fn({ eventType: 'UPDATE', new: {
  id: 'zzz', competencia: '1999-01-01', descricao: 'De outro mes', dia_vencimento: 1,
  vencimento: '1999-01-01', valor_previsto: 10, valor_pago: null, pago: false,
  pago_em: null, pago_por: null } });
medir('item de outro mes NAO entrou', itensDesenhados().length, nItens);

print('\n----------------------------------------');
print('medidas ok: ' + ok + '   falhas: ' + falhou);
