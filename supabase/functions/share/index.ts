import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const BOTS = [
  'facebookexternalhit', 'twitterbot', 'linkedinbot',
  'slackbot', 'telegrambot', 'whatsapp', 'discord',
  'applebot', 'pinterest', 'googlebot', 'redditbot',
  'skypeuripreview', 'vkshare',
];

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? 'https://vjmzileqdrhxiklxqftv.supabase.co';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZqbXppbGVxZHJoeGlrbHhxZnR2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3MjM2NTMsImV4cCI6MjEwMDI5OTY1M30.4DLkLbMfJ67JeJGwjoJ9lXlIGMWAE_N0hEQD4Lm1HQo';

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

async function fetchEntryMeta(id: string, isPublished: boolean) {
  if (!id || !SUPABASE_ANON_KEY) return null;
  const table = isPublished ? 'published_entries' : 'write_backs';
  const url = `${SUPABASE_URL}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}&select=title,content,display_name,is_anonymous`;
  try {
    const resp = await fetch(url, {
      headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${SUPABASE_ANON_KEY}` },
    });
    if (!resp.ok) return null;
    const rows = await resp.json();
    return rows?.[0] ?? null;
  } catch (_) {
    return null;
  }
}

serve(async (req: Request) => {
  const url  = new URL(req.url);
  const id   = url.searchParams.get('entry_id') ?? '';
  const img  = url.searchParams.get('img') ?? '';
  const pub  = url.searchParams.get('pub') === 'true';
  const ua   = (req.headers.get('user-agent') ?? '').toLowerCase();

  const isBot = BOTS.some(b => ua.includes(b));

  if (isBot) {
    const meta = await fetchEntryMeta(id, pub);
    const author = meta?.is_anonymous ? 'Anonymous' : (meta?.display_name || 'A Writer');
    const title = meta?.title?.trim() ? escapeHtml(meta.title) : 'Sanctuary';
    const rawDesc = (meta?.content ?? '').replace(/[#*_>`]/g, '').trim();
    const desc = rawDesc
      ? escapeHtml(rawDesc.length > 200 ? `${rawDesc.slice(0, 200)}…` : rawDesc)
      : `A reflection shared by ${escapeHtml(author)} from Sanctuary — a private writing space.`;

    return new Response(
      `<!DOCTYPE html><html><head>
      <meta charset="UTF-8">
      <title>${title}</title>
      <meta property="og:title" content="${title}" />
      <meta property="og:description" content="${desc}" />
      <meta property="og:image" content="${escapeHtml(img)}" />
      <meta property="og:image:width" content="1080" />
      <meta property="og:image:height" content="1080" />
      <meta property="og:type" content="article" />
      <meta property="og:site_name" content="Sanctuary" />
      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:title" content="${title}" />
      <meta name="twitter:description" content="${desc}" />
      <meta name="twitter:image" content="${escapeHtml(img)}" />
      </head><body></body></html>`,
      { headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'public, max-age=3600' } }
    );
  }

  const deepLink = pub && id ? `penhaven://community/entry/${id}` : `penhaven://community`;
  const webFallback = SUPABASE_URL;

  return new Response(
    `<!DOCTYPE html><html><head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="0; url=${deepLink}">
    <script>
      window.location = '${deepLink}';
      setTimeout(function () {
        var el = document.getElementById('fallback');
        if (el) el.style.display = 'block';
      }, 1200);
    </script>
    </head><body>
    <p>Opening Sanctuary…</p>
    <div id="fallback" style="display:none">
      <p>Don't have PenHaven? <a href="${webFallback}">Learn more</a></p>
    </div>
    </body></html>`,
    { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
  );
});