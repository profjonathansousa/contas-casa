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
  apDesc: $('#ap-desc'), apCancelar: $('#ap-cancelar'), apConfirmar: $('#ap-confirmar'),
  adTitulo: $('#ad-titulo'), btnGerar: $('#btn-gerar'), btnFixas: $('#btn-fixas'),
  fixas: $('#tela-fixas'), fxLista: $('#fx-lista'), fxVoltar: $('#fx-voltar'),
  fxAdd: $('#fx-add'), fxDoMes: $('#fx-do-mes'), btnAvisos: $('#btn-avisos'),
  prefAvisos: $('#pref-avisos'), prefVespera: $('#pref-vespera'),
  pref12: $('#pref-12h'), pref20: $('#pref-20h'),
  fundoParcelas: $('#fundo-parcelas'), folhaParcelas: $('#folha-parcelas'),
  pcDesc: $('#pc-desc'), pcTotal: $('#pc-total'), pcMes: $('#pc-mes'),
  pcCancelar: $('#pc-cancelar'), erroParcelas: $('#erro-parcelas')
};

var COLUNAS = 'id,competencia,descricao,dia_vencimento,vencimento,' +
              'valor_previsto,valor_pago,pago,pago_em,pago_por,' +
              'parcela_n,parcela_de';

var eu = null;        // { id, casa_id, nome }
var nomes = {};       // id do perfil -> primeiro nome
var comp = mesDeHoje();
var itens = [];
var canal = null;
var editando = false;
var renderPendente = false;
var paraApagar = null;      // item aguardando confirmação de exclusão
var tipoApagar = 'lancamento';
var modoFolha = 'lancamento';   // a folha de "+" serve às duas telas
var modelos = [];               // contas fixas
var COLUNAS_MODELO = 'id,descricao,dia_vencimento,valor_padrao,ativo,parcelas_total,parcela_1';
var COLUNAS_PERFIL = 'id, casa_id, nome, avisa_vespera_20h, avisa_dia_12h, avisa_dia_20h';

// Os três avisos do dia, e a coluna do perfil que manda em cada um. A
// preferência é da PESSOA, não do aparelho: desligar aqui desliga em todos os
// aparelhos dela, que é o que se espera de "não quero ser avisado assim".
var AVISOS = [
  { onde: 'prefVespera', campo: 'avisa_vespera_20h', rotulo: 'na véspera, 20h' },
  { onde: 'pref12',      campo: 'avisa_dia_12h',     rotulo: 'no dia, meio-dia' },
  { onde: 'pref20',      campo: 'avisa_dia_20h',     rotulo: 'no dia, 20h' }
];

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

/* ---------- parcelas ---------- */

// Qual parcela cai neste mês. Nulo quando a conta não é parcelada. Pode voltar
// 0, negativo ou maior que o total — quem decide se entra é quem pergunta.
// A mesma conta existe no banco, em parcela_no_mes(): são três linhas de cada
// lado, e as duas são medidas.
function parcelaNoMes(m, competencia) {
  if (m.parcelas_total == null || !m.parcela_1) return null;
  var a = m.parcela_1.split('-'), b = competencia.split('-');
  return (+b[0] - +a[0]) * 12 + (+b[1] - +a[1]) + 1;
}
function valeNoMes(m, competencia) {
  var n = parcelaNoMes(m, competencia);
  return n === null || (n >= 1 && n <= m.parcelas_total);
}

// "03/2026", "3/2026", "3-2026" -> "2026-03-01". Vazio = sem parcelas.
// Rabisco devolve NaN, mesma convenção do paraNumero.
function paraCompetencia(txt) {
  var s = String(txt == null ? '' : txt).trim();
  if (!s) return null;
  var m = /^(\d{1,2})\s*[\/\-.]\s*(\d{4})$/.exec(s);
  if (!m) return NaN;
  var mes = +m[1], ano = +m[2];
  if (mes < 1 || mes > 12) return NaN;
  return ano + '-' + String(mes).padStart(2, '0') + '-01';
}
function deCompetencia(iso) {
  if (!iso) return '';
  var p = iso.split('-');
  return p[1] + '/' + p[0];
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
// Sair tem que levar o dinheiro embora: o cache de pintura guarda descrição e
// valor das contas, e sem isto eles ficavam no aparelho depois do logout.
function cacheApagar() {
  try {
    if (typeof localStorage.length === 'number' && typeof localStorage.key === 'function') {
      for (var i = localStorage.length - 1; i >= 0; i--) {
        var k = localStorage.key(i);
        if (k && k.indexOf('mes:') === 0) localStorage.removeItem(k);
      }
    } else {
      localStorage.removeItem(chaveCache());
    }
  } catch (e) {}
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
  cacheApagar();
  await db.auth.signOut();
  eu = null; itens = []; modelos = []; comp = mesDeHoje();
  el.mes.hidden = true; el.fixas.hidden = true; el.login.hidden = false;
});

/* ---------- carregar ---------- */

async function carregarPerfis() {
  var r = await db.from('perfil').select(COLUNAS_PERFIL);
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

  atualizarBotaoGerar();

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

// Um toque faz a ação principal; segurar 0,7 s faz a destrutiva.
// Rolar a lista cancela: dedo que anda mais de 10 px não é dedo parado.
function ligarToques(div, aoTocar, aoSegurar) {
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
      aoSegurar();
    }, 700);   // 0,7 s: longo o bastante para não apagar sem querer
  });
  div.addEventListener('pointermove', function (ev) {
    if (Math.abs((ev.clientX || 0) - x0) > 10 || Math.abs((ev.clientY || 0) - y0) > 10) soltar();
  });
  div.addEventListener('pointerup', soltar);
  div.addEventListener('pointercancel', soltar);
  div.addEventListener('pointerleave', soltar);
  div.addEventListener('click', function () {
    if (longo) { longo = false; return; }   // já virou exclusão
    aoTocar();
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
  if (it.parcela_n != null && it.parcela_de != null) {
    var pc = document.createElement('div');
    pc.className = 'parcela';
    pc.textContent = it.parcela_n + '/' + it.parcela_de;
    corpo.appendChild(pc);
  }
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

  ligarToques(div, function () { alternarPago(it); }, function () { pedirApagar(it, 'lancamento'); });

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

function pedirApagar(it, tipo) {
  paraApagar = it;
  tipoApagar = tipo || 'lancamento';
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
  var it = paraApagar, tipo = tipoApagar;
  if (!it) return;
  fecharApagar();

  if (tipo === 'modelo') {
    var guardaM = modelos.slice();
    modelos = modelos.filter(function (x) { return x.id !== it.id; });
    desenharFixas();
    var rm = await db.from('modelo').delete().eq('id', it.id);
    if (rm.error) { modelos = guardaM; desenharFixas(); aviso('Não deu para apagar. ' + rm.error.message); }
    return;
  }

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

/* ---------- contas fixas ---------- */

async function carregarModelos() {
  var r = await db.from('modelo').select(COLUNAS_MODELO)
            .order('dia_vencimento', { ascending: true })
            .order('descricao', { ascending: true });
  if (r.error) { aviso('Não consegui carregar as contas fixas. ' + r.error.message); return; }
  modelos = r.data;
}

// Fixas ligadas que ainda não estão no mês na tela. A comparação é por
// descrição, igual à do banco, para não oferecer o que a pessoa já digitou.
function faltandoNoMes() {
  var tem = {};
  itens.forEach(function (i) { tem[i.descricao.trim().toLowerCase()] = 1; });
  return modelos.filter(function (m) {
    return m.ativo && valeNoMes(m, comp) && !tem[m.descricao.trim().toLowerCase()];
  });
}

function atualizarBotaoGerar() {
  var faltam = faltandoNoMes().length;
  el.btnGerar.hidden = faltam === 0;
  el.btnGerar.textContent = faltam === 1
    ? 'Trazer 1 conta fixa para este mês'
    : 'Trazer ' + faltam + ' contas fixas para este mês';
}

el.btnGerar.addEventListener('click', async function () {
  el.btnGerar.disabled = true;
  var r = await db.rpc('gerar_mes', { p_competencia: comp });
  el.btnGerar.disabled = false;
  if (r.error) { aviso('Não deu para gerar. ' + r.error.message); return; }
  await carregarMes();
  aviso(r.data === 1 ? '1 conta trazida.' : r.data + ' contas trazidas.');
});

function mostrarTela(nome) {
  el.mes.hidden = nome !== 'mes';
  el.fixas.hidden = nome !== 'fixas';
}
el.btnFixas.addEventListener('click', async function () {
  mostrarTela('fixas');
  await carregarModelos();
  desenharFixas();
});
el.fxVoltar.addEventListener('click', function () {
  mostrarTela('mes');
  desenhar();
});

el.fxDoMes.addEventListener('click', async function () {
  el.fxDoMes.disabled = true;
  var r = await db.rpc('fixar_mes', { p_competencia: comp });
  el.fxDoMes.disabled = false;
  if (r.error) { aviso('Não deu certo. ' + r.error.message); return; }
  await carregarModelos();
  await carregarMes();
  desenharFixas();
  aviso(r.data === 1 ? '1 conta virou fixa.' : r.data + ' contas viraram fixas.');
});

function desenharFixas() {
  el.fxDoMes.hidden = itens.length === 0;
  el.fxDoMes.textContent = 'Transformar as contas do mês em fixas';

  el.fxLista.textContent = '';
  if (modelos.length === 0) {
    var vazio = document.createElement('p');
    vazio.className = 'vazio-mes';
    vazio.textContent = 'Nenhuma conta fixa ainda. Use o botão abaixo para '
      + 'transformar as contas do mês em fixas de uma vez.';
    el.fxLista.appendChild(vazio);
    return;
  }
  modelos.forEach(function (m) { el.fxLista.appendChild(linhaModelo(m)); });
}

function linhaModelo(m) {
  var div = document.createElement('div');
  div.className = 'item' + (m.ativo ? '' : ' desligado');

  var marca = document.createElement('div');
  marca.className = 'marca';
  marca.textContent = m.ativo ? '✓' : '';
  if (m.ativo) marca.className += ' aceso';

  var corpo = document.createElement('div');
  corpo.className = 'corpo';
  var desc = document.createElement('div');
  desc.className = 'desc';
  desc.textContent = m.descricao;
  corpo.appendChild(desc);
  var dia = document.createElement('button');
  dia.type = 'button';
  dia.className = 'fx-dia';
  dia.textContent = 'todo dia ' + m.dia_vencimento + rotuloParcela(m);
  dia.setAttribute('aria-label', 'Parcelas de ' + m.descricao);
  // tocar aqui abre as parcelas; tocar no resto da linha liga e desliga
  dia.addEventListener('click', function (ev) { ev.stopPropagation(); abrirParcelas(m); });
  dia.addEventListener('pointerdown', function (ev) { ev.stopPropagation(); });
  corpo.appendChild(dia);

  var valor = document.createElement('button');
  valor.type = 'button';
  valor.className = 'valor' + (m.valor_padrao == null ? ' vazio' : '');
  valor.innerHTML = m.valor_padrao == null ? '???' : '<i>R$</i> ' + reais(m.valor_padrao);
  valor.addEventListener('click', function (ev) { ev.stopPropagation(); editarPadrao(m, valor); });
  valor.addEventListener('pointerdown', function (ev) { ev.stopPropagation(); });

  ligarToques(div, function () { alternarAtivo(m); },
                   function () { pedirApagar(m, 'modelo'); });

  div.appendChild(marca);
  div.appendChild(corpo);
  div.appendChild(valor);
  return div;
}

function rotuloParcela(m) {
  var n = parcelaNoMes(m, comp);
  if (n === null) return '';
  if (n < 1) return ' · começa em ' + deCompetencia(m.parcela_1);
  if (n > m.parcelas_total) return ' · acabou, eram ' + m.parcelas_total;
  return ' · parcela ' + n + ' de ' + m.parcelas_total;
}

var fixaEmEdicao = null;
function abrirParcelas(m) {
  fixaEmEdicao = m;
  el.pcDesc.textContent = m.descricao;
  el.pcTotal.value = m.parcelas_total == null ? '' : String(m.parcelas_total);
  el.pcMes.value = deCompetencia(m.parcela_1);
  el.erroParcelas.hidden = true;
  el.fundoParcelas.hidden = false;
  el.folhaParcelas.hidden = false;
}
function fecharParcelas() {
  fixaEmEdicao = null;
  el.fundoParcelas.hidden = true;
  el.folhaParcelas.hidden = true;
}
el.pcCancelar.addEventListener('click', fecharParcelas);
el.fundoParcelas.addEventListener('click', fecharParcelas);

el.folhaParcelas.addEventListener('submit', async function (ev) {
  ev.preventDefault();
  var m = fixaEmEdicao;
  if (!m) return;
  function erro(txt) { el.erroParcelas.textContent = txt; el.erroParcelas.hidden = false; }
  el.erroParcelas.hidden = true;

  var bruto = String(el.pcTotal.value).trim();
  var total = bruto === '' ? null : parseInt(bruto, 10);
  var mes = paraCompetencia(el.pcMes.value);

  if (typeof mes === 'number' && isNaN(mes)) { erro('Não entendi o mês. Use mm/aaaa.'); return; }
  if (total !== null && !(total >= 1 && total <= 360)) { erro('Quantas parcelas? Um número de 1 a 360.'); return; }
  // uma sem a outra não diz nada: "12 vezes" a partir de quando?
  if ((total === null) !== (mes === null)) { erro('Preencha os dois, ou deixe os dois vazios.'); return; }

  var antesT = m.parcelas_total, antesM = m.parcela_1;
  m.parcelas_total = total; m.parcela_1 = mes;
  fecharParcelas();
  desenharFixas();
  var r = await db.from('modelo').update({ parcelas_total: total, parcela_1: mes }).eq('id', m.id);
  if (r.error) {
    m.parcelas_total = antesT; m.parcela_1 = antesM;
    desenharFixas();
    aviso('Não deu para salvar. ' + r.error.message);
  }
});

async function alternarAtivo(m) {
  var antes = m.ativo;
  m.ativo = !m.ativo;
  desenharFixas();
  var r = await db.from('modelo').update({ ativo: m.ativo }).eq('id', m.id);
  if (r.error) { m.ativo = antes; desenharFixas(); aviso('Não deu para salvar. ' + r.error.message); }
}

function editarPadrao(m, botao) {
  editando = true;
  var inp = document.createElement('input');
  inp.type = 'text'; inp.inputMode = 'decimal'; inp.className = 'editando';
  inp.placeholder = '???';
  inp.value = m.valor_padrao == null ? '' : reais(m.valor_padrao);
  botao.replaceWith(inp);
  inp.focus(); inp.select();
  var terminou = false;
  async function salvar() {
    if (terminou) return;
    terminou = true;
    var n = paraNumero(inp.value);
    editando = false;
    if (typeof n === 'number' && isNaN(n)) { aviso('Não entendi esse valor.'); desenharFixas(); return; }
    if (n === m.valor_padrao) { desenharFixas(); return; }
    var antes = m.valor_padrao;
    m.valor_padrao = n;
    desenharFixas();
    var r = await db.from('modelo').update({ valor_padrao: n }).eq('id', m.id);
    if (r.error) { m.valor_padrao = antes; desenharFixas(); aviso('Não deu para salvar. ' + r.error.message); }
  }
  inp.addEventListener('blur', salvar);
  inp.addEventListener('keydown', function (ev) {
    if (ev.key === 'Enter') { ev.preventDefault(); inp.blur(); }
    if (ev.key === 'Escape') { terminou = true; editando = false; desenharFixas(); }
  });
}

/* ---------- avisos no celular ---------- */

// No iPhone isto só existe se o app tiver sido adicionado à Tela de Início.
// Numa aba comum do Safari, PushManager não existe e o botão nem aparece.
function temPush() {
  return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
}

function chaveVapid() {
  var b64 = (window.CONFIG.VAPID + '='.repeat((4 - window.CONFIG.VAPID.length % 4) % 4))
              .replace(/-/g, '+').replace(/_/g, '/');
  var cru = atob(b64), arr = new Uint8Array(cru.length);
  for (var i = 0; i < cru.length; i++) arr[i] = cru.charCodeAt(i);
  return arr;
}

async function inscricaoAtual() {
  if (!temPush()) return null;
  var reg = await navigator.serviceWorker.getRegistration();
  if (!reg) return null;
  return await reg.pushManager.getSubscription();
}

async function pintarBotaoAvisos() {
  pintarPreferencias();
  el.prefAvisos.hidden = !temPush();
  if (!temPush()) { el.btnAvisos.hidden = true; return; }
  el.btnAvisos.hidden = false;
  el.btnAvisos.className = 'avisos';
  if (Notification.permission === 'denied') {
    el.btnAvisos.className = 'avisos bloqueado';
    el.btnAvisos.textContent = 'avisos bloqueados nos Ajustes do aparelho';
    return;
  }
  var sub = await inscricaoAtual();
  if (sub) {
    el.btnAvisos.className = 'avisos ligado';
    el.btnAvisos.textContent = '✓ avisos ligados neste aparelho';
  } else {
    el.btnAvisos.textContent = 'Avisar neste aparelho';
  }
}

// Coluna ausente conta como ligada: no banco elas são NOT NULL com padrão
// true, então isto só acontece antes de alguém rodar o sql/08.
function querAviso(a) { return !eu || eu[a.campo] !== false; }

function pintarPreferencias() {
  AVISOS.forEach(function (a) {
    var b = el[a.onde];
    var ligado = querAviso(a);
    b.className = 'pref' + (ligado ? ' ligado' : '');
    b.textContent = (ligado ? '✓ ' : '○ ') + a.rotulo;
  });
}

AVISOS.forEach(function (a) {
  el[a.onde].addEventListener('click', async function () {
    if (!eu) return;
    var antes = querAviso(a);
    eu[a.campo] = !antes;
    pintarPreferencias();                       // resposta imediata, como o resto do app
    var campos = {};
    campos[a.campo] = eu[a.campo];
    var r = await db.from('perfil').update(campos).eq('id', eu.id);
    if (r.error) {
      eu[a.campo] = antes;
      pintarPreferencias();
      aviso('Não deu para salvar. ' + r.error.message);
    }
  });
});

el.btnAvisos.addEventListener('click', async function () {
  if (Notification.permission === 'denied') {
    aviso('Libere as notificações nos Ajustes do aparelho, para o Nossas Contas.');
    return;
  }
  el.btnAvisos.disabled = true;
  try {
    var jaTem = await inscricaoAtual();
    if (jaTem) {
      await db.from('push_inscricao').delete().eq('endpoint', jaTem.endpoint);
      await jaTem.unsubscribe();
      aviso('Avisos desligados neste aparelho.');
    } else {
      var permissao = await Notification.requestPermission();
      if (permissao !== 'granted') { aviso('Sem permissão, não dá para avisar.'); return; }
      var reg = await navigator.serviceWorker.ready;
      var sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: chaveVapid()
      });
      var j = sub.toJSON();
      var r = await db.from('push_inscricao').upsert({
        casa_id: eu.casa_id, perfil_id: eu.id,
        endpoint: sub.endpoint,
        p256dh: j.keys.p256dh, auth: j.keys.auth,
        aparelho: (navigator.userAgent.indexOf('iPhone') >= 0 ? 'iPhone' : 'outro'),
        falhas: 0, ultimo_erro: null
      }, { onConflict: 'endpoint' });
      if (r.error) { await sub.unsubscribe(); aviso('Não deu para salvar. ' + r.error.message); return; }
      aviso('Pronto. Você recebe um resumo por dia.');
    }
  } catch (e) {
    aviso('Não deu certo: ' + (e && e.message ? e.message : e));
  } finally {
    el.btnAvisos.disabled = false;
    await pintarBotaoAvisos();
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

function abrirFolha(modo) {
  modoFolha = modo || 'lancamento';
  el.adTitulo.textContent = modoFolha === 'modelo' ? 'Nova conta fixa' : 'Nova conta';
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
el.btnAdd.addEventListener('click', function () { abrirFolha('lancamento'); });
el.fxAdd.addEventListener('click', function () { abrirFolha('modelo'); });
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

  if (modoFolha === 'modelo') {
    var rm = await db.from('modelo').insert({
      casa_id: eu.casa_id, descricao: desc, dia_vencimento: dia, valor_padrao: val
    }).select(COLUNAS_MODELO).single();
    if (rm.error) { el.erroAdd.textContent = rm.error.message; el.erroAdd.hidden = false; return; }
    fecharFolha();
    modelos.push(rm.data);
    modelos.sort(function (a, b) {
      return a.dia_vencimento - b.dia_vencimento || a.descricao.localeCompare(b.descricao, 'pt-BR');
    });
    desenharFixas();
    return;
  }

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
    el.fixas.hidden = true;
    el.login.hidden = false;
    aviso(e.message || 'Sua sessão expirou. Entre de novo.');
    return;
  }
  el.login.hidden = true;
  el.mes.hidden = false;
  comp = mesDeHoje();
  mostrarTela('mes');
  await carregarModelos();
  await carregarMes();
  ligarTempoReal();
  pintarBotaoAvisos();
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
