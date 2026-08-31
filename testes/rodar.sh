#!/bin/zsh
# Roda o app.js e o sw.js REAIS fora do navegador, com DOM, relógio e Supabase
# falsos. Não existe node nesta máquina; o jsc já vem no macOS.
set -e
AQUI="${0:A:h}"; APP="$AQUI/.."
JSC=/System/Library/Frameworks/JavaScriptCore.framework/Versions/A/Helpers/jsc
T=$(mktemp -d)

cat "$AQUI/prelude.js" "$APP/app.js" "$AQUI/testes.js" > "$T/a.js"
"$JSC" "$T/a.js"

sed "s|return { data: \[ { id: ID_EU, casa_id: CASA, nome: 'Jonathan' },|return { data: [ { id: 'nao-e-voce', casa_id: CASA, nome: 'Jonathan' },|" \
  "$AQUI/prelude.js" > "$T/p2.js"
cat "$T/p2.js" "$APP/app.js" "$AQUI/teste_semperfil.js" > "$T/b.js"
"$JSC" "$T/b.js"

cat "$AQUI/sw_prelude.js" "$APP/sw.js" "$AQUI/sw_testes.js" > "$T/c.js"
"$JSC" "$T/c.js"

rm -rf "$T"
