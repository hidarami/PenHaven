// @ts-ignore - Deno URL import
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const BOTS = [
  'facebookexternalhit', 'twitterbot', 'linkedinbot',
  'slackbot', 'telegrambot', 'whatsapp', 'discord',
  'applebot', 'pinterest', 'googlebot',
];

serve(async (req: Request) => {
  const url  = new URL(req.url);
  const id   = url.searchParams.get('entry_id') ?? '';
  const img  = url.searchParams.get('img') ?? '';
  const pub  = url.searchParams.get('pub') === 'true';
  const ua   = (req.headers.get('user-agent') ?? '').toLowerCase();

  const isBot = BOTS.some(b => ua.includes(b));

  const title = 'Sanctuary';
  const desc  = 'A reflection shared from Sanctuary — a private writing space.';

  if (isBot) {
    return new Response(
      `<!DOCTYPE html><html><head>
      <meta charset="UTF-8">
      <meta property="og:title" content="${title}" />
      <meta property="og:description" content="${desc}" />
      <meta property="og:image" content="${img}" />
      <meta property="og:image:width" content="1080" />
      <meta property="og:image:height" content="1080" />
      <meta property="og:type" content="article" />
      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:image" content="${img}" />
      </head><body></body></html>`,
      { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
    );
  }

  // Real users: deep-link into app
  // Published = go to that entry in community; unpublished = go to community panel
  const deepLink = pub && id
    ? `flow://community/entry/${id}`
    : `flow://community`;

  return new Response(
    `<!DOCTYPE html><html><head>
    <meta http-equiv="refresh" content="0; url=${deepLink}">
    <script>window.location='${deepLink}';</script>
    </head><body><p>Opening Sanctuary…</p></body></html>`,
    { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
  );
});