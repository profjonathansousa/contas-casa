/* Resumo diário das contas, por Web Push.
   Roda no GitHub Actions, nunca no navegador. Usa a chave de serviço, que
   ignora a RLS de propósito: precisa enxergar todas as casas.

   O cron do GitHub atrasa horas, não minutos. Por isso este robô roda de hora
   em hora e decide sozinho, pelo relógio de Brasília, qual aviso está aberto;
   a tabela aviso_enviado é a memória que impede mandar o mesmo aviso duas
   vezes. Run atrasado ainda manda, desde que o aviso ainda faça sentido.

   Variáveis esperadas:
     SUPABASE_URL, SUPABASE_SERVICE_ROLE,
     VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT
   Opcionais:
     DIA=2026-09-10   força a data (para testar)
     SLOT=dia_12h     força o slot, ignorando a hora (para testar).
                      'auto' ou vazio = decide pela hora, que é o normal.
     SECO=1           calcula e mostra, mas não envia nem registra
*/
import webpush from 'web-push';

const URL_BASE = process.env.SUPABASE_URL;
const CHAVE    = process.env.SUPABASE_SERVICE_ROLE;
const DIA      = process.env.DIA || null;
// 'auto' é o padrão do disparo manual e quer dizer "decida pela hora".
const SLOT_PEDIDO = process.env.SLOT || '';
const SLOT     = (SLOT_PEDIDO && SLOT_PEDIDO !== 'auto') ? SLOT_PEDIDO : null;
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
  const r = await fetch(URL_BASE + '/rest/v1' + caminho, {
    ...opcoes,
    headers: { ...cabecalho, ...(opcoes.headers || {}) }
  });
  if (!r.ok) {
    const erro = new Error(caminho + ' -> ' + r.status + ' ' + (await r.text()).slice(0, 200));
    erro.status = r.status;
    throw erro;
  }
  // PostgREST devolve corpo vazio em 201 e 204; JSON.parse('') estoura.
  const texto = await r.text();
  return texto ? JSON.parse(texto) : null;
}

// ==== funções puras: a bancada recorta daqui ====

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

// O aviso da véspera é outro recado: não informa, pede uma ação. Quem paga
// prepara o pagamento na noite anterior, com calma, em vez de descobrir a
// conta no dia. Só sai para quem tem o que preparar.
function montarVespera(r) {
  const n = r.vencem_amanha || 0;
  if (n === 0) return null;

  const nomes = (r.titulos_amanha || []).slice(0, 4).join(', ');
  const resto = (r.titulos_amanha || []).length - 4;
  return {
    titulo: n === 1 ? '1 conta vence amanhã' : `${n} contas vencem amanhã`,
    corpo: nomes + (resto > 0 ? ` e mais ${resto}` : '')
         + ' — ' + dinheiro(r.valor_amanha) + ' · deixe o pagamento pronto',
    tag: 'vespera-' + r.dia
  };
}

// Qual coluna do perfil manda em cada aviso. Via função, e não pela tabela
// solta, porque é assim que a bancada consegue medir: const dentro do recorte
// não escapa dele.
function colunaDoSlot(slot) {
  return {
    vespera_20h: 'avisa_vespera_20h',
    dia_12h: 'avisa_dia_12h',
    dia_20h: 'avisa_dia_20h'
  }[slot];
}

function montarDoSlot(r, slot) {
  return slot === 'vespera_20h' ? montarVespera(r) : montarAviso(r);
}

// Cada aviso abre numa hora e deixa de fazer sentido em outra. "Vence hoje"
// mandado à meia-noite chegou tarde demais para servir de aviso e cedo demais
// para ser educado; melhor não mandar. É isso que "expira" quer dizer aqui.
// Horas de Brasília, e o intervalo é aberto no fim: abre <= hora < expira.
const SLOTS = {
  dia_12h:     { abre: 12, expira: 18 },
  // Os dois das 20h são o mesmo relógio de propósito: uma execução manda os
  // dois recados, "vence amanhã" e "ainda hoje, não pago".
  vespera_20h: { abre: 20, expira: 24 },
  dia_20h:     { abre: 20, expira: 24 }
};

// Slot pedido à mão que não existe não pode virar notificação torta: sem isto,
// um nome errado passaria direto e mandaria um aviso com tag inventada.
function slotConhecido(slot) {
  return Object.prototype.hasOwnProperty.call(SLOTS, slot);
}

function slotsAbertos(hora) {
  return Object.keys(SLOTS).filter(function (s) {
    return hora >= SLOTS[s].abre && hora < SLOTS[s].expira;
  });
}

// Dia e hora em São Paulo, sem depender do relógio da máquina que roda o robô
// (o Actions roda em UTC). O dia é o de Brasília de propósito: a repescagem do
// aviso das 20h cai depois da meia-noite em UTC e ainda é o mesmo dia aqui.
function emSaoPaulo(quando) {
  const p = {};
  const partes = new Intl.DateTimeFormat('pt-BR', {
    timeZone: 'America/Sao_Paulo',
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', hourCycle: 'h23'
  }).formatToParts(quando);
  for (const parte of partes) p[parte.type] = parte.value;
  return { dia: p.year + '-' + p.month + '-' + p.day, hora: Number(p.hour) };
}

// O aviso das 20h não pode substituir o do meio-dia na tela do celular: são
// dois recados diferentes. Tag diferente por slot.
function tagDoSlot(tagBase, slot) {
  return tagBase + '-' + slot;
}

// ==== fim das funções puras ====

if (SLOT && !slotConhecido(SLOT)) {
  console.error(`SLOT desconhecido: "${SLOT}". Conhecidos: ${Object.keys(SLOTS).join(', ')}, auto.`);
  process.exit(1);
}

const agora = emSaoPaulo(new Date());
const dia = DIA || agora.dia;
const slots = SLOT ? [SLOT] : slotsAbertos(agora.hora);

console.log(`Brasília: ${agora.dia} ${String(agora.hora).padStart(2, '0')}h | dia do aviso: ${dia} | `
          + `slots abertos: ${slots.join(', ') || 'nenhum'}${SECO ? ' | SECO' : ''}`);

if (slots.length === 0) {
  console.log('nada a fazer nesta hora.');
  process.exit(0);
}

const resumos = await api('/rpc/resumo_do_dia', {
  method: 'POST',
  body: JSON.stringify(DIA ? { p_dia: DIA } : {})
});
const perfis = await api('/perfil?select=id,casa_id,nome,avisa_vespera_20h,avisa_dia_12h,avisa_dia_20h');
const inscricoes = await api('/push_inscricao?select=id,casa_id,perfil_id,endpoint,p256dh,auth');

console.log(`casas com conta em aberto: ${resumos.length} | pessoas: ${perfis.length} | `
          + `aparelhos inscritos: ${inscricoes.length}`);

let enviados = 0, limpos = 0, falhos = 0, semAviso = 0, repetidos = 0, naoQuer = 0, semAparelho = 0;

for (const slot of slots) {
  const registro = await api(`/aviso_enviado?dia=eq.${dia}&slot=eq.${slot}&select=casa_id,perfil_id`);
  const jaFoiPessoa = new Set((registro || []).filter((x) => x.perfil_id).map((x) => x.perfil_id));
  // Registro sem pessoa é de antes do bloco 7, quando o aviso era da casa
  // inteira. Vale por todo mundo dela: senão, no dia da virada, quem já tinha
  // recebido receberia de novo.
  const jaFoiCasa = new Set((registro || []).filter((x) => !x.perfil_id).map((x) => x.casa_id));

  for (const p of perfis) {
    if (p[colunaDoSlot(slot)] === false) { naoQuer++; continue; }
    if (jaFoiPessoa.has(p.id) || jaFoiCasa.has(p.casa_id)) { repetidos++; continue; }

    const r = resumos.find((x) => x.casa_id === p.casa_id);
    if (!r) { semAviso++; continue; }

    const aviso = montarDoSlot(r, slot);
    if (!aviso) { semAviso++; continue; }
    aviso.tag = tagDoSlot(aviso.tag, slot);

    const alvos = inscricoes.filter((i) => i.perfil_id === p.id);
    console.log(`[${slot}] ${p.nome} | ${alvos.length} aparelho(s) | ${aviso.titulo} — ${aviso.corpo}`);
    if (SECO) continue;
    if (alvos.length === 0) { semAparelho++; continue; }

    let algumChegou = false;
    for (const i of alvos) {
      const alvo = { endpoint: i.endpoint, keys: { p256dh: i.p256dh, auth: i.auth } };
      try {
        await webpush.sendNotification(alvo, JSON.stringify(aviso), { TTL: 12 * 3600 });
        enviados++;
        algumChegou = true;
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

    // Só marca como enviado se alguma coisa chegou a algum aparelho: se todos
    // falharam, o run da hora seguinte tem que tentar de novo.
    if (algumChegou) {
      try {
        await api('/aviso_enviado', {
          method: 'POST',
          headers: { Prefer: 'return=minimal' },
          body: JSON.stringify({ casa_id: p.casa_id, perfil_id: p.id, dia, slot })
        });
      } catch (e) {
        // 409 = outro run registrou primeiro. Não é erro.
        if (e.status !== 409) throw e;
      }
    }
  }
}

console.log(`enviados: ${enviados} | inscrições mortas removidas: ${limpos} | falhas: ${falhos} | `
          + `sem nada a avisar: ${semAviso} | já avisados: ${repetidos} | `
          + `não quiseram este aviso: ${naoQuer} | sem aparelho inscrito: ${semAparelho}`);
if (falhos > 0) process.exitCode = 1;
