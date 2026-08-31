// Configuração do projeto Supabase.
// A anon key é pública por desenho: ela só diz "sou um visitante deste
// projeto". Quem decide o que cada pessoa enxerga é a RLS, no banco.
// A service_role key NUNCA entra aqui.
window.CONFIG = {
  URL:  'https://mcwgiqwbbgdltzqgopcq.supabase.co',
  // Chave pública VAPID. A privada mora só em GitHub Secrets.
  VAPID: 'BJCD9F-1q98wB2V7PvMNJ0PcbZ3BgzucUBFeyqMC320D7Dg-x_SCGQJDb0Mk5IVLpPnP05ADmsQMV8wfsWYXOXE',
  ANON: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jd2dpcXdiYmdkbHR6cWdvcGNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxNDA1NjgsImV4cCI6MjEwMzcxNjU2OH0.tmCzVwD-d-bM4kMziKMmP77a0eBrhdyP1v4rJP1PJxE'
};
