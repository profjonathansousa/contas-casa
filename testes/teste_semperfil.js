var ok=0, falhou=0;
function medir(n,o,e){ if(JSON.stringify(o)===JSON.stringify(e)){ok++;print('  ok   '+n+' = '+JSON.stringify(o));}
  else{falhou++;print('  FALHA '+n+' = '+JSON.stringify(o)+' (esperado '+JSON.stringify(e)+')');} }
for (var i=0;i<60;i++) drainMicrotasks();
var q=function(s){return document.querySelector(s);};
print('\n== sessao valida, mas sem perfil na casa ==');
medir('voltou para o login',      q('#tela-login').hidden, false);
medir('nao mostra o mes',         q('#tela-mes').hidden, true);
medir('nem tentou carregar o mes', LOG.selects.length, 0);
medir('avisou o que houve',       q('#aviso')._txt, 'Este usuário não tem perfil em nenhuma casa.');
print('\nmedidas ok: '+ok+'   falhas: '+falhou);
