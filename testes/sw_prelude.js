if (typeof URL === 'undefined') {
  URL = function (u, base) {
    var abs = u;
    if (!/^[a-z]+:\/\//.test(u)) {
      abs = String(base || '').replace(/[^\/]*$/, '') + String(u).replace(/^\.\//, '');
    }
    var m = /^([a-z]+:\/\/[^\/]+)(.*)$/.exec(abs);
    this.origin = m ? m[1] : ''; this.pathname = m ? m[2] : abs; this.href = abs;
  };
}
// Sempre o falso, nos dois motores: o node traz um Request de verdade, que
// recusa o pedido de mentira da bancada. Aqui o mundo em volta é todo fingido.
var Request = function (req, init) {
  this.url = req.url || req;
  this.method = req.method || 'GET';
  this.mode = req.mode;
  this.cache = init && init.cache;
};

var GUARDADO = {};      // nome do cache -> { url: resposta }
var REDE_CAI = false;
var PEDIDOS_REDE = [];
var MODOS_REDE = [];    // como cada pedido foi a rede: 'no-cache' ou nada

function Resp(url, status, tipo) { this.url = url; this.status = status === undefined ? 200 : status; this.type = tipo || 'basic'; }
Resp.prototype.clone = function () { return new Resp(this.url, this.status, this.type); };

function fetch(req) {
  var url = req.url || req;
  PEDIDOS_REDE.push(url);
  MODOS_REDE.push(req.cache);
  if (REDE_CAI) return Promise.reject(new Error('offline'));
  return Promise.resolve(new Resp(url, 200, 'basic'));
}

var caches = {
  open: function (n) {
    GUARDADO[n] = GUARDADO[n] || {};
    return Promise.resolve({
      addAll: function (lista) { lista.forEach(function (u) { GUARDADO[n][u] = new Resp(u); }); return Promise.resolve(); },
      put: function (req, resp) { GUARDADO[n][req.url || req] = resp; return Promise.resolve(); }
    });
  },
  keys: function () { return Promise.resolve(Object.keys(GUARDADO)); },
  delete: function (n) { delete GUARDADO[n]; return Promise.resolve(true); },
  match: function (req) {
    var u = req.url || req;
    for (var n in GUARDADO) if (GUARDADO[n][u]) return Promise.resolve(GUARDADO[n][u]);
    return Promise.resolve(undefined);
  }
};

var ouvintes = {};
var MOSTRADAS = [];      // notificacoes que o sw pediu para mostrar
var ABAS = [];           // janelas abertas do app
var ABERTAS = [];        // janelas que o sw mandou abrir
var FOCADAS = [];
var ESCOPO = 'https://exemplo.github.io/contas-casa/';
var self = {
  addEventListener: function (n, f) { ouvintes[n] = f; },
  skipWaiting: function () { return Promise.resolve('skipWaiting'); },
  clients: {
    claim: function () { return Promise.resolve('claim'); },
    matchAll: function () { return Promise.resolve(ABAS); },
    openWindow: function (u) { ABERTAS.push(u); return Promise.resolve({ url: u }); }
  },
  registration: {
    scope: ESCOPO,
    showNotification: function (titulo, opcoes) {
      MOSTRADAS.push({ titulo: titulo, opcoes: opcoes });
      return Promise.resolve();
    }
  },
  location: { origin: 'https://exemplo.github.io', href: ESCOPO + 'sw.js' }
};
function aba(url) {
  return { url: url, focus: function () { FOCADAS.push(url); return Promise.resolve(); } };
}
function disparar(nome, ev) { ouvintes[nome](ev); }
