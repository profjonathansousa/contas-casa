var ok = 0, falhou = 0;
function medir(n, o, e) {
  if (JSON.stringify(o) === JSON.stringify(e)) { ok++; print('  ok   ' + n + ' = ' + JSON.stringify(o)); }
  else { falhou++; print('  FALHA ' + n + ' = ' + JSON.stringify(o) + ' (esperado ' + JSON.stringify(e) + ')'); }
}
function esperar() { for (var i = 0; i < 40; i++) drainMicrotasks(); }

print('\n== install: guarda a casca do app ==');
var esperou = null;
disparar('install', { waitUntil: function (p) { esperou = p; } });
esperar();
var caixa = GUARDADO[VERSAO] || {};
medir('arquivos guardados', Object.keys(caixa).length, 11);
medir('guardou o app.js', !!caixa['./app.js'], true);
medir('guardou a biblioteca', !!caixa['./vendor/supabase.js'], true);
medir('guardou o icone maskable', !!caixa['./icones/icone-maskable-512.png'], true);

print('\n== activate: apaga versao velha ==');
GUARDADO[VERSAO + '-velho'] = { velho: 1 };
disparar('activate', { waitUntil: function (p) { esperou = p; } });
esperar();
medir('caches restantes', Object.keys(GUARDADO), [VERSAO]);

print('\n== fetch: o Supabase passa direto, sem cache ==');
var respondeu;
function pedir(url, metodo) {
  respondeu = undefined;
  disparar('fetch', { request: { url: url, method: metodo || 'GET' },
                      respondWith: function (p) { respondeu = p; } });
  esperar();
  return respondeu;
}
medir('chamada ao Supabase nao e interceptada',
      pedir('https://mcwgiqwbbgdltzqgopcq.supabase.co/rest/v1/lancamento') === undefined, true);
medir('POST nao e interceptado',
      pedir('https://exemplo.github.io/app.js', 'POST') === undefined, true);
medir('arquivo do app E interceptado',
      pedir('https://exemplo.github.io/app.css') !== undefined, true);

print('\n== fetch: rede primeiro ==');
PEDIDOS_REDE = [];
var p = pedir('https://exemplo.github.io/app.js');
esperar();
medir('foi na rede', PEDIDOS_REDE.length, 1);

print('\n== fetch: sem rede, cai no cache ==');
REDE_CAI = true;
var resultado = null;
pedir('https://exemplo.github.io/app.js').then(function (r) { resultado = r; });
esperar();
medir('devolveu do cache', resultado ? resultado.url : null, 'https://exemplo.github.io/app.js');

print('\n== CONTROLE NEGATIVO ==');
print('  (com o cache vazio E sem rede, tem que devolver o index, nao inventar resposta)');
GUARDADO = {};
var r2 = 'nao-resolveu';
pedir('https://exemplo.github.io/app.js').then(function (r) { r2 = r === undefined ? 'undefined' : r.url; });
esperar();
medir('sem cache e sem rede', r2, 'undefined');
REDE_CAI = false;

print('\n== push: recebe o aviso e monta a notificacao ==');
disparar('push', {
  data: { json: function () { return { titulo: '3 contas vencem hoje',
                                       corpo: 'Aluguel, Luz, Internet', tag: 'dia' }; },
          text: function () { return 'cru'; } },
  waitUntil: function (p) { return p; }
});
esperar();
medir('notificacoes mostradas', MOSTRADAS.length, 1);
medir('titulo', MOSTRADAS[0].titulo, '3 contas vencem hoje');
medir('corpo',  MOSTRADAS[0].opcoes.body, 'Aluguel, Luz, Internet');
medir('idioma', MOSTRADAS[0].opcoes.lang, 'pt-BR');
medir('substitui a do dia anterior', MOSTRADAS[0].opcoes.tag, 'dia');

print('\n  -- CONTROLE: mensagem que nao e JSON nao pode derrubar o sw --');
disparar('push', {
  data: { json: function () { throw new Error('nao e json'); }, text: function () { return 'texto solto'; } },
  waitUntil: function (p) { return p; }
});
esperar();
medir('mostrou assim mesmo', MOSTRADAS.length, 2);
medir('usou o texto cru', MOSTRADAS[1].opcoes.body, 'texto solto');
medir('titulo padrao', MOSTRADAS[1].titulo, 'Nossas Contas');

print('\n== tocar no aviso abre o app ==');
print('  -- com o app ja aberto: foca, nao abre outra --');
ABAS = [ aba(ESCOPO + 'index.html') ];
disparar('notificationclick', {
  notification: { close: function () {}, data: { url: './index.html' } },
  waitUntil: function (p) { return p; }
});
esperar();
medir('focou a aba existente', FOCADAS.length, 1);
medir('nao abriu janela nova', ABERTAS.length, 0);

print('  -- CONTROLE: sem app aberto, ai sim abre --');
ABAS = [];
disparar('notificationclick', {
  notification: { close: function () {}, data: { url: './index.html' } },
  waitUntil: function (p) { return p; }
});
esperar();
medir('abriu uma janela', ABERTAS.length, 1);
medir('no endereco certo', ABERTAS[0], ESCOPO + 'index.html');

print('\n----------------------------------------');
print('medidas ok: ' + ok + '   falhas: ' + falhou);
