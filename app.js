/* Nossas Contas — fase 1.
   Regra que orienta o código: o caminho "abrir e marcar" tem que ser o mais
   curto possível. Marcar pago manda um único campo (pago) pela rede; quem
   preenche o autor e a hora é o banco. */
(function () {
'use strict';

var db = supabase.createClient(window.CONFIG.URL, window.CONFIG.ANON, {
  auth: { persistSession: true, autoRefreshToken: true, storageKey: 'nossas-contas' }
});

var $ = function (s) { return document.querySelector(s); };
var el = {
  login: $('#tela-login'), formLogin: $('#form-login'), email: $('#in-email'),
  senha: $('#in-senha'), btnEntrar: $('#btn-entrar'), erroLogin: $('#erro-login'),
  mes: $('#tela-mes'), mesAnt: $('#mes-ant'), mesProx: $('#mes-prox'), mesNome: $('#mes-nome'),
  tPrevisto: $('#t-previsto'), tPago: $('#t-pago'), tApagar: $('#t-apagar'), tAberto: $('#t-aberto'),
  lista: $('#lista'), btnAdd: $('#btn-add'), btnSair: $('#btn-sair'),
  fundoAdd: $('#fundo-add'), folhaAdd: $('#folha-add'), adDesc: $('#ad-desc'),
  adDia: $('#ad-dia'), adValor: $('#ad-valor'), adCancelar: $('#ad-cancelar'),
  erroAdd: $('#erro-add'), aviso: $('#aviso'),
  fundoApagar: $('#fundo-apagar'), folhaApagar: $('#folha-apagar'),
  apDesc: $('#ap-desc'), apCancelar: $('#ap-cancelar'), apConfirmar: $('#ap-confirmar')
};

var COLUNAS = 'id,competencia,descricao,dia_vencimento,vencimento,' +
              'valor_previsto,valor_pago,pago,pago_em,pago_por';

var eu = null;        // { id, casa_id, nome }
var nomes = {};       // id do perfil -> primeiro nome
var comp = mesDeHoje();
var itens = [];
var canal = null;
var editando = false;
var renderPendente = false;
var paraApagar = null;      // lançamento aguardando confirmação de exclusão

/* ---------- datas e dinheiro ---------- */

var fmt = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
var fmtMes = new Intl.DateTimeFormat('pt-BR', { month: 'long', year: 'numeric' });

function competenciaDe(ano, mes0) {
  var d = new Date(ano, mes0, 1);
  return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-01';
}
function mesDeHoje() { var h = new Date(); return competenciaDe(h.getFullYear(), h.getMonth()); }
function andarMes(c, n) { var p = c.split('-'); return competenciaDe(+p[0], +p[1] - 1 + n); }
function comoData(c) { var p = c.split('-'); return new Date(+p[0], +p[1] - 1, +p[2]); }
function ddmm(iso) { var p = iso.split('-'); return p[2] + '/' + p[1]; }
function hhmm(ts) {
  var d = new Date(ts);
  return String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
}
function reais(v) { return fmt.format(Number(v) || 0); }

// Aceita "1.800,50", "1800,50", "1800.50", "1.800" e "1800".
function paraNumero(txt) {
  var s = String(txt == null ? '' : txt).trim().replace(/[R$\s]/g, '');
  if (!s) return null;                                  // vazio = valor desconhecido
  if (s.indexOf(',') >= 0) s = s.replace(/\./g, '').replace(',', '.');
  else if (/^\d{1,3}(\.\d{3})+$/.test(s)) s = s.replace(/\./g, '');
  var n = Number(s);
  if (!isFinite(n) || n < 0) return NaN;
  return Math.round(n * 100) / 100;
}

/* ---------- avisos ---------- */

var avisoTimer = null;
function aviso(txt) {
  el.aviso.textContent = txt;
  el.aviso.hidden = false;
  clearTimeout(avisoTimer);
  avisoTimer = setTimeout(function () { el.aviso.hidden = true; }, 4200);
}

/* ---------- pintura instantânea (só leitura, some se der ruim) ---------- */

function chaveCache() { return 'mes:' + (eu ? eu.casa_id : '?') + ':' + comp; }
function cacheGravar() {
  try { localStorage.setItem(chaveCache(), JSON.stringify(itens)); } catch (e) {}
}
function cacheLer() {
  try { return JSON.parse(localStorage.getItem(chaveCache()) || 'null'); } catch (e) { return null; }
}

/* ---------- entrar e sair ---------- */

el.formLogin.addEventListener('submit', async function (ev) {
  ev.preventDefault();
  el.erroLogin.hidden = true;
  el.btnEntrar.disabled = true;
  el.btnEntrar.textContent = 'Entrando…';
  var r = await db.auth.signInWithPassword({
    email: el.email.value.trim(), password: el.senha.value
  });
  el.btnEntrar.disabled = false;
  el.btnEntrar.textContent = 'Entrar';
  if (r.error) {
    el.erroLogin.textContent = r.error.message === 'Invalid login credentials'
      ? 'E-mail ou senha não conferem.' : r.error.message;
    el.erroLogin.hidden = false;
    return;
  }
  el.senha.value = '';
  abrirApp();
});

el.btnSair.addEventListener('click', async function () {
  if (canal) { db.removeChannel(canal); canal = null; }
  await db.auth.signOut();
  eu = null; itens = []; comp = mesDeHoje();
  el.mes.hidden = true; el.login.hidden = false;
});

/* ---------- carregar ---------- */

async function carregarPerfis() {
  var r = await db.from('perfil').select('id, casa_id, nome');
  if (r.error) throw r.error;
  nomes = {};
  r.data.forEach(function (p) { nomes[p.id] = p.nome; });
  var u = await db.auth.getUser();
  eu = r.data.filter(function (p) { return p.id === u.data.user.id; })[0] || null;
  if (!eu) throw new Error('Este usuário não tem perfil em nenhuma casa.');
}

async function carregarMes() {
  var doCache = cacheLer();
  if (doCache) { itens = doCache; desenhar(); }
  var r = await db.from('lancamento').select(COLUNAS)
    .eq('competencia', comp)
    .order('dia_vencimento', { ascending: true })
    .order('descricao', { ascending: true });
  if (r.error) { aviso('Não consegui carregar o mês. ' + r.error.message); return; }
  itens = r.data;
  cacheGravar();
  desenhar();
}

function ligarTempoReal() {
  if (canal) db.removeChannel(canal);
  canal = db.channel('casa:' + eu.casa_id)
    .on('postgres_changes',
        { event: '*', schema: 'public', table: 'lancamento',
          filter: 'casa_id=eq.' + eu.casa_id },
        aplicarDeFora)
    .subscribe();
}

function aplicarDeFora(msg) {
  var novo = msg.new, velho = msg.old;
  var some = function (id) {
    var antes = itens.length;
    itens = itens.filter(function (i) { return i.id !== id; });
    if (itens.length !== antes) { cacheGravar(); desenhar(); }
  };
  if (msg.eventType === 'DELETE') { if (velho && velho.id) some(velho.id); return; }
  if (!novo || !novo.id) return;
  if (novo.competencia !== comp) { some(novo.id); return; }   // foi movido para outro mês
  var i = itens.findIndex(function (x) { return x.id === novo.id; });
  if (i >= 0) itens[i] = novo; else itens.push(novo);
  itens.sort(function (a, b) {
    return a.dia_vencimento - b.dia_vencimento || a.descricao.localeCompare(b.descricao, 'pt-BR');
  });
  cacheGravar();
  desenhar();
}

/* ---------- desenhar ---------- */

function desenhar() {
  if (editando) { renderPendente = true; return; }

  var rotulo = fmtMes.format(comoData(comp));            // "agosto de 2026"
  el.mesNome.textContent = rotulo.charAt(0).toUpperCase() + rotulo.slice(1);

  var previsto = 0, pago = 0, apagar = 0, semValor = 0;
  itens.forEach(function (i) {
    if (i.valor_previsto != null) previsto += Number(i.valor_previsto);
    if (i.pago) {
      pago += Number(i.valor_pago != null ? i.valor_pago
                   : (i.valor_previsto != null ? i.valor_previsto : 0));
    } else if (i.valor_previsto != null) {
      apagar += Number(i.valor_previsto);
    } else {
      semValor++;
    }
  });
  var cifra = function (v) { return '<i>R$</i> ' + reais(v); };
  el.tPrevisto.innerHTML = cifra(previsto);
  el.tPago.innerHTML     = cifra(pago);
  el.tApagar.innerHTML   = cifra(apagar);
  el.tAberto.hidden = semValor === 0;
  el.tAberto.textContent = semValor === 1
    ? '1 conta em aberto, sem valor'
    : semValor + ' contas em aberto, sem valor';

  el.lista.textContent = '';
  if (itens.length === 0) {
    var vazio = document.createElement('p');
    vazio.className = 'vazio-mes';
    vazio.textContent = 'Nenhuma conta neste mês. Toque no + para adicionar.';
    el.lista.appendChild(vazio);
    return;
  }

  var diaAtual = null;
  itens.forEach(function (it) {
    if (it.vencimento !== diaAtual) {
      diaAtual = it.vencimento;
      var h = document.createElement('div');
      h.className = 'dia';
      h.textContent = ddmm(it.vencimento);
      el.lista.appendChild(h);
    }
    el.lista.appendChild(linha(it));
  });
}

function linha(it) {
  var div = document.createElement('div');
  div.className = 'item' + (it.pago ? ' pago' : '');

  var marca = document.createElement('div');
  marca.className = 'marca';
  marca.textContent = it.pago ? '✓' : '';

  var corpo = document.createElement('div');
  corpo.className = 'corpo';
  var desc = document.createElement('div');
  desc.className = 'desc';
  desc.textContent = it.descricao;
  corpo.appendChild(desc);
  if (it.pago && it.pago_em) {
    var selo = document.createElement('div');
    selo.className = 'selo';
    var quem = nomes[it.pago_por];
    selo.textContent = 'pago por ' + (quem || 'alguém') + ', ' + hhmm(it.pago_em);
    corpo.appendChild(selo);
  }

  var valor = document.createElement('button');
  valor.type = 'button';
  valor.className = 'valor' + (it.valor_previsto == null ? ' vazio' : '');
  valor.innerHTML = it.valor_previsto == null ? '???' : '<i>R$</i> ' + reais(it.valor_previsto);
  valor.setAttribute('aria-label', 'Editar valor de ' + it.descricao);
  valor.addEventListener('click', function (ev) {
    ev.stopPropagation();          // tocar no valor edita; tocar no resto marca pago
    editarValor(it, valor);
  });
  // segurar o dedo no valor não pode apagar a conta
  valor.addEventListener('pointerdown', function (ev) { ev.stopPropagation(); });

  // Um toque marca ou desmarca, sem confirmação. Segurar apaga, com confirmação:
  // marcar pago se desfaz com outro toque, apagar não se desfaz.
  var relogio = null, longo = false, x0 = 0, y0 = 0;
  function soltar() {
    clearTimeout(relogio); relogio = null;
    div.className = div.className.replace(' segurando', '');
  }
  div.addEventListener('pointerdown', function (ev) {
    longo = false; x0 = ev.clientX || 0; y0 = ev.clientY || 0;
    div.className += ' segurando';
    relogio = setTimeout(function () {
      longo = true; soltar();
      if (navigator.vibrate) navigator.vibrate(18);
      pedirApagar(it);
    }, 500);
  });
  div.addEventListener('pointermove', function (ev) {
    // rolar a lista não é segurar
    if (Math.abs((ev.clientX || 0) - x0) > 10 || Math.abs((ev.clientY || 0) - y0) > 10) soltar();
  });
  div.addEventListener('pointerup', soltar);
  div.addEventListener('pointercancel', soltar);
  div.addEventListener('pointerleave', soltar);
  div.addEventListener('click', function () {
    if (longo) { longo = false; return; }   // já virou exclusão, não marca pago
    alternarPago(it);
  });

  div.appendChild(marca);
  div.appendChild(corpo);
  div.appendChild(valor);
  return div;
}

/* ---------- marcar pago ---------- */

async function alternarPago(it) {
  var antes = { pago: it.pago, pago_em: it.pago_em, pago_por: it.pago_por };
  it.pago = !it.pago;
  it.pago_em = it.pago ? new Date().toISOString() : null;
  it.pago_por = it.pago ? eu.id : null;
  desenhar();                                   // resposta imediata na tela
  if (navigator.vibrate) navigator.vibrate(8);

  var r = await db.from('lancamento').update({ pago: it.pago })
            .eq('id', it.id).select(COLUNAS).single();
  if (r.error) {
    it.pago = antes.pago; it.pago_em = antes.pago_em; it.pago_por = antes.pago_por;
    desenhar();
    aviso('Não deu para salvar. ' + r.error.message);
    return;
  }
  Object.keys(r.data).forEach(function (k) { it[k] = r.data[k]; });
  cacheGravar();
  desenhar();
}

/* ---------- editar valor ---------- */

function editarValor(it, botao) {
  editando = true;
  var inp = document.createElement('input');
  inp.type = 'text';
  inp.inputMode = 'decimal';
  inp.className = 'editando';
  inp.placeholder = '???';
  inp.value = it.valor_previsto == null ? '' : reais(it.valor_previsto);
  botao.replaceWith(inp);
  inp.focus();
  inp.select();

  var terminou = false;
  function fechar() {
    editando = false;
    if (renderPendente) { renderPendente = false; }
    desenhar();
  }
  async function salvar() {
    if (terminou) return;
    terminou = true;
    var n = paraNumero(inp.value);
    if (typeof n === 'number' && isNaN(n)) { aviso('Não entendi esse valor.'); fechar(); return; }
    if (n === it.valor_previsto) { fechar(); return; }
    var antes = it.valor_previsto;
    it.valor_previsto = n;
    fechar();
    var r = await db.from('lancamento').update({ valor_previsto: n }).eq('id', it.id);
    if (r.error) {
      it.valor_previsto = antes;
      desenhar();
      aviso('Não deu para salvar. ' + r.error.message);
    } else {
      cacheGravar();
    }
  }
  inp.addEventListener('blur', salvar);
  inp.addEventListener('keydown', function (ev) {
    if (ev.key === 'Enter') { ev.preventDefault(); inp.blur(); }
    if (ev.key === 'Escape') { terminou = true; fechar(); }
  });
}

/* ---------- apagar ---------- */

function pedirApagar(it) {
  paraApagar = it;
  el.apDesc.textContent = it.descricao;
  el.fundoApagar.hidden = false;
  el.folhaApagar.hidden = false;
}
function fecharApagar() {
  paraApagar = null;
  el.fundoApagar.hidden = true;
  el.folhaApagar.hidden = true;
}
el.apCancelar.addEventListener('click', fecharApagar);
el.fundoApagar.addEventListener('click', fecharApagar);

el.apConfirmar.addEventListener('click', async function () {
  var it = paraApagar;
  if (!it) return;
  fecharApagar();
  var guardado = itens.slice();
  itens = itens.filter(function (x) { return x.id !== it.id; });
  desenhar();
  var r = await db.from('lancamento').delete().eq('id', it.id);
  if (r.error) {
    itens = guardado;
    desenhar();
    aviso('Não deu para apagar. ' + r.error.message);
  } else {
    cacheGravar();
  }
});

/* ---------- navegar entre meses ---------- */

function irPara(c) {
  comp = c;
  itens = [];
  desenhar();
  carregarMes();
}
el.mesAnt.addEventListener('click', function () { irPara(andarMes(comp, -1)); });
el.mesProx.addEventListener('click', function () { irPara(andarMes(comp, +1)); });
el.mesNome.addEventListener('click', function () {
  if (comp !== mesDeHoje()) irPara(mesDeHoje());
});

/* ---------- conta avulsa ---------- */

function abrirFolha() {
  el.adDesc.value = '';
  el.adDia.value = '';
  el.adValor.value = '';
  el.erroAdd.hidden = true;
  el.fundoAdd.hidden = false;
  el.folhaAdd.hidden = false;
  el.adDesc.focus();
}
function fecharFolha() {
  el.fundoAdd.hidden = true;
  el.folhaAdd.hidden = true;
}
el.btnAdd.addEventListener('click', abrirFolha);
el.adCancelar.addEventListener('click', fecharFolha);
el.fundoAdd.addEventListener('click', fecharFolha);

el.folhaAdd.addEventListener('submit', async function (ev) {
  ev.preventDefault();
  var desc = el.adDesc.value.trim();
  var dia = parseInt(el.adDia.value, 10);
  var val = paraNumero(el.adValor.value);
  el.erroAdd.hidden = true;
  if (!desc) { el.erroAdd.textContent = 'Falta a descrição.'; el.erroAdd.hidden = false; return; }
  if (!(dia >= 1 && dia <= 31)) { el.erroAdd.textContent = 'O dia tem que ser entre 1 e 31.'; el.erroAdd.hidden = false; return; }
  if (typeof val === 'number' && isNaN(val)) { el.erroAdd.textContent = 'Não entendi esse valor.'; el.erroAdd.hidden = false; return; }

  var r = await db.from('lancamento').insert({
    casa_id: eu.casa_id, competencia: comp, descricao: desc,
    dia_vencimento: dia, valor_previsto: val
  }).select(COLUNAS).single();

  if (r.error) { el.erroAdd.textContent = r.error.message; el.erroAdd.hidden = false; return; }
  fecharFolha();
  if (!itens.some(function (i) { return i.id === r.data.id; })) itens.push(r.data);
  itens.sort(function (a, b) {
    return a.dia_vencimento - b.dia_vencimento || a.descricao.localeCompare(b.descricao, 'pt-BR');
  });
  cacheGravar();
  desenhar();
});

/* ---------- partida ---------- */

async function abrirApp() {
  try {
    await carregarPerfis();
  } catch (e) {
    // Sessão vencida ou perfil ausente: volta para o login em vez de deixar
    // a pessoa numa tela branca.
    await db.auth.signOut().catch(function () {});
    eu = null;
    el.mes.hidden = true;
    el.login.hidden = false;
    aviso(e.message || 'Sua sessão expirou. Entre de novo.');
    return;
  }
  el.login.hidden = true;
  el.mes.hidden = false;
  comp = mesDeHoje();
  await carregarMes();
  ligarTempoReal();
}

(async function iniciar() {
  var s = await db.auth.getSession();
  if (s.data.session) await abrirApp();
  else el.login.hidden = false;
})();

// Se o app ficou parado em segundo plano, recarrega ao voltar.
document.addEventListener('visibilitychange', function () {
  if (!document.hidden && eu && !editando) carregarMes();
});

if ('serviceWorker' in navigator) {
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('sw.js').catch(function () {});
  });
}

})();
