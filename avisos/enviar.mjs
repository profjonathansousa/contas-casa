/* Resumo diário das contas, por Web Push.
   Roda no GitHub Actions, nunca no navegador. Usa a chave de serviço, que
   ignora a RLS de propósito: precisa enxergar todas as casas.

   Variáveis esperadas:
     SUPABASE_URL, SUPABASE_SERVICE_ROLE,
     VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT
   Opcionais:
     DIA=2026-09-10   força a data (para testar)
     SECO=1           calcula e mostra, mas não envia nada
*/
import webpush from 'web-push';

const URL_BASE = process.env.SUPABASE_URL;
const CHAVE    = process.env.SUPABASE_SERVICE_ROLE;
const DIA      = process.env.DIA || null;
const SECO     = process.env.SECO === '1';

if (!URL_BASE || !CHAVE) { console.error('Faltam SUPABASE_URL / SUPABASE_SERVICE_ROLE.'); process.exit(1); }

// Sem isto, faltar uma chave VAPID derrubava o processo com um stack trace do
// web-push, em vez de dizer qual Secret está faltando.
const semVapid = [
  ['VAPID_PUBLIC_KEY',  process.env.VAPID_PUBLIC_KEY],
  ['VAPID_PRIVATE_KEY', process.env.VAPID_PRIVATE_KEY]
].filter(([, valor]) => !valor).map(([nome]) => nome);
if (semVapid.length) { console.error('Faltam: ' + semVapid.join(', ') + '.'); process.exit(1); }

webpush.setVapidDetails(
  process.env.VAPID_SUBJECT || 'mailto:ninguem@exemplo.com',
  process.env.VAPID_PUBLIC_KEY,
  process.env.VAPID_PRIVATE_KEY
);

const cabecalho = {
  apikey: CHAVE,
  Authorization: 'Bearer ' + CHAVE,
  'Content-Type': 'application/json'
};

async function api(caminho, opcoes = {}) {
  const r = await fetch(URL_BASE + '/rest/v1' + caminho, { ...opcoes, headers: cabecalho });
  if (!r.ok) throw new Error(caminho + ' -> ' + r.status + ' ' + (await r.text()).slice(0, 200));
  return r.status === 204 ? null : r.json();
}

const dinheiro = (v) =>
  'R$ ' + Number(v || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

// Monta o texto. Devolve null quando não há nada a dizer — dia sem conta
// não gera aviso, senão a pessoa aprende a ignorar.
function montarAviso(r) {
  const hoje = r.vencem_hoje || 0;
  const atras = r.atrasadas || 0;
  if (hoje === 0 && atras === 0) return null;

  let titulo;
  if (hoje > 0) titulo = hoje === 1 ? '1 conta vence hoje' : `${hoje} contas vencem hoje`;
  else titulo = atras === 1 ? '1 conta atrasada' : `${atras} contas atrasadas`;

  const partes = [];
  if (hoje > 0) {
    const nomes = (r.titulos || []).slice(0, 4).join(', ');
    const resto = (r.titulos || []).length - 4;
    partes.push(nomes + (resto > 0 ? ` e mais ${resto}` : '') + ' — ' + dinheiro(r.valor_hoje));
    if (atras > 0) partes.push(`${atras} atrasada${atras > 1 ? 's' : ''} (${dinheiro(r.valor_atrasado)})`);
  } else {
    partes.push(dinheiro(r.valor_atrasado));
  }
  if (r.sem_valor > 0) {
    partes.push(r.sem_valor === 1 ? '1 ainda sem valor' : `${r.sem_valor} ainda sem valor`);
  }
  return { titulo, corpo: partes.join(' · '), tag: 'resumo-' + r.dia };
}

const resumos = await api('/rpc/resumo_do_dia', {
  method: 'POST',
  body: JSON.stringify(DIA ? { p_dia: DIA } : {})
});
const inscricoes = await api('/push_inscricao?select=id,casa_id,endpoint,p256dh,auth');

console.log(`casas com conta em aberto: ${resumos.length} | aparelhos inscritos: ${inscricoes.length}`);

let enviados = 0, limpos = 0, falhos = 0, semAviso = 0;

for (const r of resumos) {
  const aviso = montarAviso(r);
  if (!aviso) { semAviso++; continue; }
  const alvos = inscricoes.filter((i) => i.casa_id === r.casa_id);
  console.log(`casa ${r.casa_id.slice(0, 8)} | ${alvos.length} aparelho(s) | ${aviso.titulo} — ${aviso.corpo}`);
  if (SECO) continue;

  for (const i of alvos) {
    const alvo = { endpoint: i.endpoint, keys: { p256dh: i.p256dh, auth: i.auth } };
    try {
      await webpush.sendNotification(alvo, JSON.stringify(aviso), { TTL: 12 * 3600 });
      enviados++;
      await api('/push_inscricao?id=eq.' + i.id, {
        method: 'PATCH',
        body: JSON.stringify({ ultimo_envio: new Date().toISOString(), falhas: 0, ultimo_erro: null })
      });
    } catch (e) {
      // 404 e 410 querem dizer "esse aparelho não existe mais". Apaga, não insiste.
      if (e.statusCode === 404 || e.statusCode === 410) {
        await api('/push_inscricao?id=eq.' + i.id, { method: 'DELETE' });
        limpos++;
        console.log('  inscrição morta, removida');
      } else {
        falhos++;
        console.log('  falhou: ' + (e.statusCode || '') + ' ' + (e.message || '').slice(0, 120));
        await api('/push_inscricao?id=eq.' + i.id, {
          method: 'PATCH',
          body: JSON.stringify({ ultimo_erro: String(e.statusCode || e.message).slice(0, 200) })
        });
      }
    }
  }
}

console.log(`enviados: ${enviados} | inscrições mortas removidas: ${limpos} | falhas: ${falhos} | casas sem nada a avisar: ${semAviso}`);
if (falhos > 0) process.exitCode = 1;
