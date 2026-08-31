# vendor/

Biblioteca de terceiros, copiada para cá de propósito.

- `supabase.js` — @supabase/supabase-js v2.112.4, build UMD, baixado de
  https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js

Está aqui em vez de vir de CDN por dois motivos: o app não fica dependendo de
outro servidor no ar para abrir, e o service worker consegue cachear o arquivo.
Expõe o global `supabase`. Não editar à mão — para atualizar, baixar de novo
e trocar a versão acima.
