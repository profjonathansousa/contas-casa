# vendor/

Biblioteca de terceiros, copiada para cá de propósito.

- `supabase.js` — @supabase/supabase-js **v2.97.0**, build UMD, baixado de
  https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js

A URL de download aponta para `@2`, que é um apelido móvel: ela entrega o que
for a última 2.x no dia. Por isso o número acima tem que sair do arquivo, e não
da memória de quem baixou. Para conferir qual versão está aqui:

```
grep -o 'v2\.[0-9]*\.[0-9]*' vendor/supabase.js | sort -u
```

(Até 05/09/2026 este arquivo dizia 2.112.4, e o arquivo era 2.97.0.)

Está aqui em vez de vir de CDN por dois motivos: o app não fica dependendo de
outro servidor no ar para abrir, e o service worker consegue cachear o arquivo.
Expõe o global `supabase`. Não editar à mão — para atualizar, baixar de novo
e trocar a versão acima.
