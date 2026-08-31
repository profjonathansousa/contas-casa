import webpush from 'web-push';

const URL_BASE = process.env.SUPABASE_URL;
const CHAVE = process.env.SUPABASE_SERVICE_ROLE;
const vapid = {
  publicKey: process.env.VAPID_PUBLIC_KEY,
  privateKey: process.env.VAPID_PRIVATE_KEY,
  subject: process.env.VAPID_SUBJECT
};

const ausentes = [
  ['SUPABASE_URL', URL_BASE],
  ['SUPABASE_SERVICE_ROLE', CHAVE],
  ['VAPID_PUBLIC_KEY', vapid.publicKey],
  ['VAPID_PRIVATE_KEY', vapid.privateKey],
  ['VAPID_SUBJECT', vapid.subject]
].filter(([, valor]) => !valor).map(([nome]) => nome);

if (ausentes.length) {
  console.error('Faltam: ' + ausentes.join(', ') + '.');
  process.exit(1);
}

webpush.setVapidDetails(vapid.subject, vapid.publicKey, vapid.privateKey);

const cabecalho = {
  apikey: CHAVE,
  Authorization: 'Bearer ' + CHAVE,
  'Content-Type': 'application/json'
};

async function api(caminho, opcoes = {}) {
  const r = await fetch(URL_BASE + '/rest/v1' + caminho, {
    ...opcoes,
    headers: cabecalho
  });
  if (!r.ok) throw new Error(caminho + ' -> ' + r.status + ' ' + (await r.text()).slice(0, 200));
  return r.status === 204 ? null : r.json();
}

const inscricoes = await api('/push_inscricao?select=id,endpoint,p256dh,auth');
const aviso = {
  titulo: 'Teste de notificação',
  corpo: 'O Web Push do Contas da Casa está funcionando.',
  tag: 'teste-push'
};

console.log(`inscrições encontradas: ${inscricoes.length}`);

let enviados = 0;
let falhas = 0;
let expiradasRemovidas = 0;

for (const inscricao of inscricoes) {
  const alvo = {
    endpoint: inscricao.endpoint,
    keys: { p256dh: inscricao.p256dh, auth: inscricao.auth }
  };

  try {
    await webpush.sendNotification(alvo, JSON.stringify(aviso), { TTL: 12 * 3600 });
    enviados++;
  } catch (erro) {
    if (erro.statusCode === 404 || erro.statusCode === 410) {
      try {
        await api('/push_inscricao?id=eq.' + encodeURIComponent(inscricao.id), { method: 'DELETE' });
        expiradasRemovidas++;
        console.log('inscrição expirada removida');
      } catch (erroAoRemover) {
        falhas++;
        console.log('falhou ao remover inscrição expirada: ' + (erroAoRemover.message || '').slice(0, 120));
      }
    } else {
      falhas++;
      console.log('falhou: ' + (erro.statusCode || '') + ' ' + (erro.message || '').slice(0, 120));
    }
  }
}

console.log(`Push enviados: ${enviados}`);
console.log(`falhas: ${falhas}`);
console.log(`inscrições expiradas removidas: ${expiradasRemovidas}`);

if (falhas > 0) process.exitCode = 1;
