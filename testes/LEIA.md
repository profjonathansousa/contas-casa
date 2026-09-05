# testes/

Prova por execução, sem navegador e sem instalar nada:

```
./testes/rodar.sh
```

Roda o `app.js` e o `sw.js` **reais** dentro do `jsc` (que já vem no macOS)
ou, onde não há `jsc` — Linux, o CI do GitHub —, dentro do `node`, com DOM,
relógio, `localStorage` e cliente Supabase falsos. Nada da lógica do app é
reimplementado aqui — o que se finge é só o mundo em volta.

O `node` não sabe esvaziar a fila de microtarefas no meio de uma medição, que
é do que a bancada precisa; `testes/ponte_node.js` repõe isso (e mais o `print`
e o `readFile`), e por isso o `rodar.sh` chama o node com
`--allow-natives-syntax`. A ponte não finge nada do app.

Cada bloco termina em número. O placar tem que fechar em **81 / 4 / 23 / 27**
medidas e **0 falhas**. O `rodar.sh` confere isso sozinho e sai com código
diferente de zero se qualquer medida falhar, se o motor morrer ou se o placar
mudar — antes ele saía zero mesmo com a bancada vermelha, e um CI assim seria
pior do que nenhum. O placar esperado mora na primeira linha do `rodar.sh`:
medida nova só passa quando o número também for atualizado ali.

O quarto bloco recorta do `avisos/enviar.mjs` real a faixa marcada como pura —
entre `// ==== funções puras` e `// ==== fim das funções puras` — e roda ela.
A marca é explícita no arquivo de propósito: antes o recorte ia de
`const dinheiro` até `const resumos`, e renomear uma variável quebrava a
bancada sem que ninguém entendesse por quê.

Há controles negativos de propósito: um evento de tempo real de outro mês tem
que ser ignorado; um service worker sem cache e sem rede tem que devolver nada
em vez de inventar resposta; uma sessão sem perfil tem que voltar para o login.
Se essas medidas passarem a "dar certo" sozinhas, a bancada quebrou.

Quem roda isso sozinho: `.github/workflows/testes.yml`, a cada push e a cada
pull request. É um workflow separado do Web Push de propósito — a bancada não
toca no banco, não manda notificação e não usa Secret nenhum.
