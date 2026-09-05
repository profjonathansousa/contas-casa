/* Service worker mínimo: existe para o app ser instalável e abrir rápido.
   Guarda só os arquivos do próprio app. Nada do Supabase é cacheado — dado de
   conta tem que vir do servidor, senão a tela mente. Fila offline é fase 2. */

var VERSAO = 'nossas-contas-v5';
var CASCA = [
  './', './index.html', './app.css', './app.js', './config.js',
  './vendor/supabase.js', './manifest.webmanifest',
  './icones/icone-192.png', './icones/icone-512.png',
  './icones/icone-maskable-512.png', './icones/apple-touch-icon.png'
];

self.addEventListener('install', function (ev) {
  ev.waitUntil(
    caches.open(VERSAO).then(function (c) { return c.addAll(CASCA); })
          .then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (ev) {
  ev.waitUntil(
    caches.keys().then(function (nomes) {
      return Promise.all(nomes.map(function (n) {
        return n === VERSAO ? null : caches.delete(n);
      }));
    }).then(function () { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function (ev) {
  var req = ev.request;
  if (req.method !== 'GET') return;
  var url = new URL(req.url);
  if (url.origin !== self.location.origin) return;   // Supabase passa direto

  // Rede primeiro, cache como rede de segurança: assim uma versão nova do app
  // aparece sem precisar desinstalar nada.
  //
  // O "no-cache" não é enfeite. O fetch de dentro do service worker AINDA passa
  // pelo cache HTTP do navegador, e o GitHub Pages manda max-age=600. Sem isto,
  // "rede primeiro" é na verdade "cache do navegador primeiro, por até dez
  // minutos" -- e index.html e app.js vencem em momentos diferentes. Em
  // 05/09/2026 isso entregou a tela nova rodando o código velho, e o conserto
  // que eu tinha acabado de publicar não chegou. "no-cache" não quer dizer
  // "baixe tudo de novo": quer dizer "pergunte se mudou", e a resposta 304
  // continua barata.
  //
  // Requisição de navegação não pode ser reconstruída (o navegador recusa), e
  // por isso ela vai como veio.
  var pedido = req.mode === 'navigate' ? req : new Request(req, { cache: 'no-cache' });

  ev.respondWith(
    fetch(pedido).then(function (resp) {
      if (resp && resp.status === 200 && resp.type === 'basic') {
        var copia = resp.clone();
        caches.open(VERSAO).then(function (c) { c.put(req, copia); });
      }
      return resp;
    }).catch(function () {
      return caches.match(req).then(function (c) {
        return c || caches.match('./index.html');
      });
    })
  );
});

/* ---------- avisos ---------- */

self.addEventListener('push', function (ev) {
  var d = {};
  try { d = ev.data ? ev.data.json() : {}; }
  catch (e) { d = { corpo: ev.data ? ev.data.text() : '' }; }
  ev.waitUntil(self.registration.showNotification(d.titulo || 'Nossas Contas', {
    body:  d.corpo || '',
    icon:  './icones/icone-192.png',
    badge: './icones/icone-192.png',
    lang:  'pt-BR',
    tag:   d.tag || 'contas-do-dia',   // um aviso por dia substitui o anterior
    renotify: true,
    data:  { url: d.url || './index.html' }
  }));
});

self.addEventListener('notificationclick', function (ev) {
  ev.notification.close();
  var destino = (ev.notification.data && ev.notification.data.url) || './index.html';
  ev.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (abas) {
      for (var i = 0; i < abas.length; i++) {
        if (abas[i].url.indexOf(self.registration.scope) === 0 && 'focus' in abas[i]) {
          return abas[i].focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(new URL(destino, self.location.href).href);
      }
    })
  );
});
