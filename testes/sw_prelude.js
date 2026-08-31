if (typeof URL === 'undefined') {
  URL = function (u) { var m = /^([a-z]+:\/\/[^\/]+)(.*)$/.exec(u); this.origin = m ? m[1] : ''; this.pathname = m ? m[2] : u; };
}
var GUARDADO = {};      // nome do cache -> { url: resposta }
var REDE_CAI = false;
var PEDIDOS_REDE = [];

function Resp(url, status, tipo) { this.url = url; this.status = status === undefined ? 200 : status; this.type = tipo || 'basic'; }
Resp.prototype.clone = function () { return new Resp(this.url, this.status, this.type); };

function fetch(req) {
  var url = req.url || req;
  PEDIDOS_REDE.push(url);
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
var self = {
  addEventListener: function (n, f) { ouvintes[n] = f; },
  skipWaiting: function () { return Promise.resolve('skipWaiting'); },
  clients: { claim: function () { return Promise.resolve('claim'); } },
  location: { origin: 'https://exemplo.github.io' }
};
function disparar(nome, ev) { ouvintes[nome](ev); }
