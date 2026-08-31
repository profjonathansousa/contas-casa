/* Service worker mínimo: existe para o app ser instalável e abrir rápido.
   Guarda só os arquivos do próprio app. Nada do Supabase é cacheado — dado de
   conta tem que vir do servidor, senão a tela mente. Fila offline é fase 2. */

var VERSAO = 'nossas-contas-v3';
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
  ev.respondWith(
    fetch(req).then(function (resp) {
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
