# testes/

Prova por execução, sem navegador e sem instalar nada:

```
./testes/rodar.sh
```

Roda o `app.js` e o `sw.js` **reais** dentro do `jsc` (que já vem no macOS),
com DOM, relógio, `localStorage` e cliente Supabase falsos. Nada da lógica do
app é reimplementado aqui — o que se finge é só o mundo em volta.

Cada bloco termina em número. O placar tem que fechar em **45 / 4 / 11**
medidas e **0 falhas**.

Há controles negativos de propósito: um evento de tempo real de outro mês tem
que ser ignorado; um service worker sem cache e sem rede tem que devolver nada
em vez de inventar resposta; uma sessão sem perfil tem que voltar para o login.
Se essas medidas passarem a "dar certo" sozinhas, a bancada quebrou.
