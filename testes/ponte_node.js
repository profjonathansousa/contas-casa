/* Ponte para rodar a bancada no node (Linux, CI) em vez do jsc do macOS.
   Repõe as três funções que o jsc oferece de graça e mais nada: o mundo
   falso continua sendo o dos preludes, e o app.js e o sw.js continuam
   sendo os reais.

   drainMicrotasks é o ponto delicado: no node a fila de microtarefas só
   é esvaziada quando a pilha se esvazia, e a bancada precisa esvaziá-la
   no meio de uma medição. %PerformMicrotaskCheckpoint() faz exatamente
   isso, e por isso o rodar.sh chama o node com --allow-natives-syntax. */

var __fs = require('fs');

function print(t) { console.log(t === undefined ? '' : String(t)); }
function readFile(caminho) { return __fs.readFileSync(caminho, 'utf8'); }

var drainMicrotasks;
try {
  drainMicrotasks = new Function('return %PerformMicrotaskCheckpoint()');
} catch (e) {
  throw new Error('node sem --allow-natives-syntax: rode pelo testes/rodar.sh');
}
