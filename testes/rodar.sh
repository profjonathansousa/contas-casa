#!/bin/sh
# Roda o app.js e o sw.js REAIS fora do navegador, com DOM, relógio e Supabase
# falsos. No macOS usa o jsc, que já vem no sistema; onde não há jsc (Linux, o
# CI do GitHub) usa o node com a ponte de testes/ponte_node.js.
#
# Sai com código != 0 se qualquer medida falhar, se o motor morrer, ou se o
# placar não fechar no esperado — senão o CI ficaria verde com a bancada
# quebrada, que é pior do que não ter CI.
set -e

ESPERADO='91 / 4 / 23 / 40'

AQUI=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP=$(CDPATH= cd -- "$AQUI/.." && pwd)

JSC=/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc
if [ -x "$JSC" ]; then
  MOTOR=jsc
  PONTE=/dev/null                      # o jsc já traz print, readFile e drainMicrotasks
elif command -v node >/dev/null 2>&1; then
  MOTOR=node
  PONTE="$AQUI/ponte_node.js"
else
  echo "Não achei nem o jsc (macOS) nem o node. Instale um dos dois." >&2
  exit 1
fi
echo "motor: $MOTOR"

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT INT TERM

echo "var DIR_APP = '$APP';" > "$T/dir.js"

FALHOU=0
PLACAR=''

rodar() {                              # rodar <título> <arquivo>
  set +e
  if [ "$MOTOR" = jsc ]; then
    "$JSC" "$2" > "$T/saida" 2>&1
  else
    node --allow-natives-syntax "$2" > "$T/saida" 2>&1
  fi
  CODIGO=$?
  set -e
  cat "$T/saida"

  if [ "$CODIGO" -ne 0 ]; then
    echo "!! $1: o motor saiu com código $CODIGO"
    FALHOU=1
    return
  fi
  if grep -q '^  FALHA' "$T/saida"; then
    echo "!! $1: há medidas falhando"
    FALHOU=1
  fi
  if ! grep -q 'falhas: 0' "$T/saida"; then
    echo "!! $1: não terminou com 'falhas: 0'"
    FALHOU=1
  fi
  N=$(sed -n 's/^medidas ok: \([0-9][0-9]*\).*/\1/p' "$T/saida" | tail -1)
  [ -n "$N" ] || N='?'
  if [ -z "$PLACAR" ]; then PLACAR="$N"; else PLACAR="$PLACAR / $N"; fi
}

cat "$PONTE" "$T/dir.js" "$AQUI/prelude.js" "$APP/app.js" "$AQUI/testes.js" > "$T/a.js"
rodar 'app.js' "$T/a.js"

# controle negativo: sessão válida sem perfil na casa tem que voltar ao login.
# O sed abaixo é o controle inteiro: se ele parar de casar, o bloco passa a
# medir a mesma coisa da rodada normal e "dá certo" pelo motivo errado. Por
# isso a troca é conferida logo em seguida.
sed "s|^var ID_DO_PERFIL_1 = ID_EU;|var ID_DO_PERFIL_1 = 'nao-e-voce';|" \
  "$AQUI/prelude.js" > "$T/p2.js"
if ! grep -q "^var ID_DO_PERFIL_1 = 'nao-e-voce';" "$T/p2.js"; then
  echo "!! o controle negativo do 'sem perfil' não foi aplicado: o sed não casou"
  exit 1
fi
cat "$PONTE" "$T/dir.js" "$T/p2.js" "$APP/app.js" "$AQUI/teste_semperfil.js" > "$T/b.js"
rodar 'sem perfil' "$T/b.js"

cat "$PONTE" "$AQUI/sw_prelude.js" "$APP/sw.js" "$AQUI/sw_testes.js" > "$T/c.js"
rodar 'sw.js' "$T/c.js"

cat "$PONTE" "$T/dir.js" "$AQUI/aviso_testes.js" > "$T/d.js"
rodar 'texto do aviso' "$T/d.js"

echo
echo "----------------------------------------"
echo "placar: $PLACAR"
if [ "$PLACAR" != "$ESPERADO" ]; then
  echo "!! placar diferente do esperado ($ESPERADO): medida sumiu ou nasceu sem virar documentação"
  FALHOU=1
fi
if [ "$FALHOU" -ne 0 ]; then
  echo "BANCADA VERMELHA"
  exit 1
fi
echo "bancada verde"
