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
medir('selects feitos', LOG.selects.length, 2);      // modelo + lancamento
medir('primeiro foi o das fixas', LOG.selects[0].tabela, 'modelo');
medir('competencia pedida', LOG.selects[1].comp, MESHOJE);
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
medir('formato do selo', /^pago por Marina, \d\d:\d\d$/.test(selo || ''), true);

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
medir('selo diz quem foi', /^pago por Marina, \d\d:\d\d$/.test(selo3 || ''), true);

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

print('\n== 12. segurar apaga; toque curto nao ==');
function descricoes() {
  return itensDesenhados().map(function (d) { return d.filhos[1].filhos[0]._txt; });
}
var alvoD = itensDesenhados()[1];
var descD = descricoes()[1];
var idEsperado = BANCO.filter(function (x) { return x.descricao === descD; })[0].id;

// CONTROLE: soltar antes do tempo nao pode abrir nada
alvoD.disparar('pointerdown');
alvoD.disparar('pointerup');
avancarTempo(2000);
medir('toque curto NAO abre a confirmacao', q('#folha-apagar').hidden, true);

alvoD.disparar('pointerdown');
avancarTempo(699);
medir('meio segundo AINDA nao abre', q('#folha-apagar').hidden, true);
avancarTempo(700);
medir('segurar 0,7s abriu a confirmacao', q('#folha-apagar').hidden, false);
medir('diz qual conta', q('#ap-desc')._txt, descD);

// o clique que o navegador manda depois do toque longo nao pode marcar pago
var upAntes = LOG.updates.length;
alvoD.disparar('click');
esperar();
medir('nao marcou pago junto', LOG.updates.length - upAntes, 0);

var antesD = descricoes();
q('#ap-confirmar').disparar('click');
esperar();
medir('delete enviado', LOG.deletes.length, 1);
medir('id certo', LOG.deletes[0].id, idEsperado);
var depoisD = descricoes();
medir('sumiu exatamente a que eu segurei',
      antesD.filter(function (d) { return depoisD.indexOf(d) < 0; }), [descD]);
medir('confirmacao fechou', q('#folha-apagar').hidden, true);

// CONTROLE: rolar a lista (dedo se move) nao pode apagar
var outro = itensDesenhados()[1];
outro.disparar('pointerdown');
outro.disparar('pointermove', { clientX: 0, clientY: 90, preventDefault: function(){}, stopPropagation: function(){} });
avancarTempo(2000);
medir('rolar a lista NAO abre a confirmacao', q('#folha-apagar').hidden, true);

print('\n== 13. contas fixas ==');
function fixasDesenhadas() {
  return q('#fx-lista').filhos.filter(function (f) { return f.className.indexOf('item') === 0; });
}
// No mes ja existem Aluguel e Luz; Escola esta desligada; falta so Condominio.
medir('botao de trazer aparece', q('#btn-gerar').hidden, false);
medir('e diz quantas faltam', q('#btn-gerar')._txt, 'Trazer 1 conta fixa para este mês');

q('#btn-fixas').disparar('click');
esperar();
medir('abriu a tela de fixas', q('#tela-fixas').hidden, false);
medir('escondeu a tela do mes', q('#tela-mes').hidden, true);
medir('desenhou as fixas', fixasDesenhadas().length, 4);
var desligadas = fixasDesenhadas().filter(function (f) { return f.className.indexOf('desligado') > 0; });
medir('uma esta desligada', desligadas.length, 1);

print('\n  -- tocar liga e desliga --');
var upA = LOG.updates.length;
fixasDesenhadas()[2].disparar('click');          // Escola, desligada
esperar();
medir('campos no update', LOG.updates[upA].campos, ['ativo']);
medir('valor enviado', LOG.updates[upA].valores.ativo, true);
medir('tabela', LOG.updates[upA].tabela, 'modelo');
medir('acendeu na tela', fixasDesenhadas()[2].className.indexOf('desligado') > 0, false);

print('\n  -- editar o valor padrao --');
var luzFixa = fixasDesenhadas()[1];              // Luz, sem valor
medir('mostra ??? antes', luzFixa.filhos[2]._html, '???');
var upB = LOG.updates.length;
luzFixa.filhos[2].disparar('click');
var campoF = fixasDesenhadas()[1].filhos[2];
campoF.value = '210,90';
campoF.disparar('blur');
esperar();
medir('campos no update', LOG.updates[upB].campos, ['valor_padrao']);
medir('numero interpretado', LOG.updates[upB].valores.valor_padrao, 210.90);

print('\n  -- segurar apaga a fixa (nao o lancamento) --');
var delA = LOG.deletes.length;
fixasDesenhadas()[3].disparar('pointerdown');
avancarTempo(700);
medir('pediu confirmacao', q('#folha-apagar').hidden, false);
medir('diz qual', q('#ap-desc')._txt, 'Condominio');
q('#ap-confirmar').disparar('click');
esperar();
medir('apagou na tabela certa', LOG.deletes[delA].tabela, 'modelo');
medir('sumiu da lista de fixas', fixasDesenhadas().length, 3);

print('\n  -- o + desta tela cria fixa, nao lancamento --');
var insA = LOG.inserts.length;
q('#fx-add').disparar('click');
medir('titulo da folha', q('#ad-titulo')._txt, 'Nova conta fixa');
q('#ad-desc').value = 'Seguro';
q('#ad-dia').value = '9';
q('#ad-valor').value = '77,00';
q('#folha-add').disparar('submit');
esperar();
medir('inserts feitos', LOG.inserts.length - insA, 1);
medir('virou modelo, com valor_padrao', Object.keys(LOG.inserts[insA]).sort(),
      ['casa_id','descricao','dia_vencimento','valor_padrao']);
medir('voltou a ter 4 fixas', fixasDesenhadas().length, 4);

print('\n  -- voltar e gerar o mes --');
q('#fx-voltar').disparar('click');
esperar();
medir('voltou para o mes', q('#tela-mes').hidden, false);
var rpcA = LOG.rpcs.length;
q('#btn-gerar').disparar('click');
esperar();
medir('chamou a funcao do banco', LOG.rpcs[rpcA].nome, 'gerar_mes');
medir('para o mes que esta na tela', LOG.rpcs[rpcA].args.p_competencia, MESHOJE);

print('\n  -- CONTROLE NEGATIVO --');
print('  (se nenhuma fixa faltasse, o botao NAO podia aparecer)');
var guardaM = MODELOS.slice();
MODELOS.length = 0;
MODELOS.push(mod('so-essa', 'Aluguel', 5, 1800, true));   // ja existe no mes
q('#btn-fixas').disparar('click');
esperar();
q('#fx-voltar').disparar('click');
esperar();
medir('botao sumiu quando nao falta nada', q('#btn-gerar').hidden, true);
guardaM.forEach(function (x) { MODELOS.push(x); });

print('\n----------------------------------------');
print('medidas ok: ' + ok + '   falhas: ' + falhou);
