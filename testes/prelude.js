/* Bancada: DOM e Supabase falsos. Nada da logica do app e reimplementado --
   o app.js real roda em cima disto. */
var LOG = { selects: [], updates: [], inserts: [], deletes: [], rpcs: [], canais: [] };

function Elem(tag) {
  this.tag = tag; this.filhos = []; this.hs = {}; this._txt = ''; this._html = '';
  this.className = ''; this.hidden = false; this.value = ''; this.disabled = false;
  this.style = {};
}
Elem.prototype.appendChild = function (c) { this.filhos.push(c); return c; };
Elem.prototype.addEventListener = function (n, f) { (this.hs[n] = this.hs[n] || []).push(f); };
Elem.prototype.setAttribute = function () {};
Elem.prototype.focus = function () {}; Elem.prototype.select = function () {};
Elem.prototype.replaceWith = function (novo) {
  var p = this.pai; if (!p) return;
  for (var i = 0; i < p.filhos.length; i++) if (p.filhos[i] === this) { p.filhos[i] = novo; novo.pai = p; }
};
Elem.prototype.disparar = function (n, ev) {
  var hs = this.hs[n] || []; ev = ev || { preventDefault: function(){}, stopPropagation: function(){} };
  for (var i = 0; i < hs.length; i++) hs[i](ev);
};
Object.defineProperty(Elem.prototype, 'textContent', {
  get: function () { return this._txt; },
  set: function (v) { this._txt = String(v); this.filhos = []; }
});
Object.defineProperty(Elem.prototype, 'innerHTML', {
  get: function () { return this._html; },
  set: function (v) { this._html = String(v); }
});

var registro = {};
var document = {
  querySelector: function (s) { return registro[s] || (registro[s] = new Elem('div')); },
  createElement: function (t) { return new Elem(t); },
  addEventListener: function () {}, hidden: false
};
// appendChild precisa marcar o pai (para replaceWith funcionar)
var _ap = Elem.prototype.appendChild;
Elem.prototype.appendChild = function (c) { c.pai = this; return _ap.call(this, c); };

// A bancada TEM que comecar no estado em que a pagina real comeca. Elemento
// que nasce com "hidden" no index.html nasce escondido aqui tambem -- senao uma
// medicao passa pelo motivo errado.
(function () {
  var html = readFile(DIR_APP + '/index.html');
  var re = /id="([^"]+)"[^>]*\shidden/g, m;
  var n = 0;
  while ((m = re.exec(html))) { document.querySelector('#' + m[1]).hidden = true; n++; }
  if (n < 5) throw new Error('bancada nao leu o index.html: so ' + n + ' elementos escondidos');
})();

var window = { addEventListener: function () {}, CONFIG: { URL: 'http://x', ANON: 'k' } };
var navigator = {};
var localStorage = (function () {
  var m = {};
  return { getItem: function (k) { return k in m ? m[k] : null; },
           setItem: function (k, v) { m[k] = String(v); },
           removeItem: function (k) { delete m[k]; } };
})();
// Relogio controlavel: o toque longo so pode ser medido se eu mandar no tempo.
var TEMPOS = [], PROX_ID = 1;
function setTimeout(f, ms) { var id = PROX_ID++; TEMPOS.push({ id: id, f: f, quando: ms || 0 }); return id; }
function clearTimeout(id) { TEMPOS = TEMPOS.filter(function (t) { return t.id !== id; }); }
function avancarTempo(ms) {
  var venceu = TEMPOS.filter(function (t) { return t.quando <= ms; });
  TEMPOS = TEMPOS.filter(function (t) { return t.quando > ms; });
  venceu.forEach(function (t) { t.f(); });
}

/* ----- dados fixos da bancada (ficticios) ----- */
var MES = (function () { var d = new Date(); return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-01'; })();
var ID_EU = 'aaaaaaaa-0000-0000-0000-000000000001';
var ID_OUTRO = 'bbbbbbbb-0000-0000-0000-000000000002';
var CASA = 'cccccccc-0000-0000-0000-000000000003';
function lanc(id, desc, dia, valor, pago) {
  return { id: id, competencia: MES, descricao: desc, dia_vencimento: dia,
           vencimento: MES.slice(0,8) + String(dia).padStart(2,'0'),
           valor_previsto: valor, valor_pago: null, pago: !!pago,
           pago_em: pago ? '2026-08-31T14:32:00.000Z' : null,
           pago_por: pago ? ID_OUTRO : null };
}
// O rodar.sh troca ESTA linha para montar o controle negativo do "sem perfil".
// Ficar numa linha própria e curta é de proposito: antes o sed tinha que casar
// com um objeto inteiro, e qualquer virgula a mais fazia o controle passar a
// medir a mesma coisa da rodada normal, sem ninguem perceber.
var ID_DO_PERFIL_1 = ID_EU;

// Preferencia de aviso (bloco 7): o Jonathan quer os tres, a Marina so as 20h.
var PERFIS = [
  { id: ID_DO_PERFIL_1, casa_id: CASA, nome: 'Jonathan',
    avisa_vespera_20h: true,  avisa_dia_12h: true,  avisa_dia_20h: true },
  { id: ID_OUTRO, casa_id: CASA, nome: 'Marina',
    avisa_vespera_20h: false, avisa_dia_12h: false, avisa_dia_20h: true }
];

function mod(id, desc, dia, valor, ativo) {
  return { id: id, descricao: desc, dia_vencimento: dia, valor_padrao: valor, ativo: !!ativo };
}
// Aluguel e Luz JA estao no mes; Condominio falta; Escola esta desligada.
var MODELOS = [
  mod('m1', 'Aluguel', 5, 1800.00, true),
  mod('m2', 'Luz', 8, null, true),
  mod('m3', 'Escola', 15, 740.00, false),
  mod('m4', 'Condominio', 31, 480.00, true)
];
// Condominio e um acordo parcelado que ainda esta correndo: 12 vezes, comecando
// quatro meses atras, entao o mes de hoje e a parcela 5.
var MES_PARCELA_1 = (function () {
  var p = MES.split('-'), d = new Date(+p[0], +p[1] - 1 - 4, 1);
  return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-01';
})();
MODELOS[3].parcelas_total = 12;
MODELOS[3].parcela_1 = MES_PARCELA_1;

var BANCO = [
  lanc('l1', 'Aluguel', 5, 1800.00, false),
  lanc('l2', 'Luz', 8, null, false),
  lanc('l3', 'Agua', 8, 95.40, false),
  lanc('l4', 'Internet', 10, 129.90, true),
  lanc('l5', 'Cartao azul', 15, null, false)
];

// Cartao azul e a parcela 5 de 12 do mesmo acordo, ja no mes.
BANCO[4].parcela_n = 5;
BANCO[4].parcela_de = 12;

function thenable(valor) {
  var o = {
    eq: function (col, v) { o._eq = o._eq || {}; o._eq[col] = v; return o; },
    order: function () { return o; },
    select: function () { return o; },
    single: function () { o._single = true; return o; },
    then: function (res) { return Promise.resolve(valor()).then(res); }
  };
  return o;
}

var supabase = {
  createClient: function () {
    return {
      auth: {
        getSession: function () { return Promise.resolve({ data: { session: { u: 1 } } }); },
        getUser: function () { return Promise.resolve({ data: { user: { id: ID_EU } } }); },
        signInWithPassword: function () { return Promise.resolve({ error: null }); },
        signOut: function () { return Promise.resolve({}); }
      },
      channel: function (nome) {
        var c = { nome: nome, on: function (t, cfg, fn) { c.cfg = cfg; c.fn = fn; return c; },
                  subscribe: function () { LOG.canais.push(c); return c; } };
        return c;
      },
      removeChannel: function () {},
      rpc: function (nome, args) {
        LOG.rpcs.push({ nome: nome, args: args });
        return thenable(function () {
          if (nome === 'gerar_mes') return { data: 1, error: null };
          return { data: MODELOS.length, error: null };
        });
      },
      from: function (tabela) {
        return {
          select: function (cols) {
            var t = thenable(function () {
              if (tabela === 'perfil') {
                return { data: PERFIS.map(function (x) {
                  var c = {}; for (var k in x) c[k] = x[k]; return c;
                }), error: null };
              }
              if (tabela === 'modelo') {
                LOG.selects.push({ tabela: 'modelo' });
                return { data: MODELOS.map(function (x) { var c = {}; for (var k in x) c[k] = x[k]; return c; }),
                         error: null };
              }
              LOG.selects.push({ tabela: tabela, comp: t._eq && t._eq.competencia });
              return { data: BANCO.map(function (x) { var c = {}; for (var k in x) c[k] = x[k]; return c; }), error: null };
            });
            return t;
          },
          update: function (obj) {
            var reg = { tabela: tabela, campos: Object.keys(obj), valores: obj };
            LOG.updates.push(reg);
            var t = thenable(function () {
              reg.id = t._eq && t._eq.id;
              var base = BANCO.filter(function (x) { return x.id === reg.id; })[0] || BANCO[0];
              var d = {}; for (var k in base) d[k] = base[k];
              for (var k2 in obj) d[k2] = obj[k2];
              if (obj.pago === true) { d.pago_em = new Date().toISOString(); d.pago_por = ID_EU; }
              if (obj.pago === false) { d.pago_em = null; d.pago_por = null; }
              return { data: d, error: null };
            });
            return t;
          },
          'delete': function () {
            var reg = { tabela: tabela };
            LOG.deletes.push(reg);
            var t = thenable(function () { reg.id = t._eq && t._eq.id; return { error: null }; });
            return t;
          },
          insert: function (obj) {
            LOG.inserts.push(obj);
            return thenable(function () {
              var d = {}; for (var k in obj) d[k] = obj[k];
              d.id = 'novo'; d.vencimento = MES.slice(0,8) + String(obj.dia_vencimento).padStart(2,'0');
              d.pago = false; d.pago_em = null; d.pago_por = null; d.valor_pago = null;
              return { data: d, error: null };
            });
          }
        };
      }
    };
  }
};
