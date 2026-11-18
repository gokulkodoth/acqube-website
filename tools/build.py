#!/usr/bin/env python3
"""
Acqube website page generator.

Takes src/index.html (the single-page site) and produces one real, pre-rendered HTML
file per page, so Google sees every service, article and page at its own address with
its own title, description and content:

    /                         /services/   /services/gst/ ... (10 services)
    /pricing/  /about/  /testimonials/  /contact/  /blog/  /blog/<article>/ ...
    /privacy-policy/  /terms/  /disclaimer/  /admin/ (noindex)

Also writes sitemap.xml, robots.txt and 404.html, and copies static files.

Usage:
    python tools/build.py --out _site                       # live data from Supabase (GitHub Action)
    python tools/build.py --out . --mock data.json --supabase-js path/to/supabase.js   # offline
"""
import argparse, datetime, http.server, json, os, re, shutil, socketserver, threading
from urllib.parse import urlparse
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
SITE = 'https://acqube.com'
STATIC = ['favicon.png', 'favicon.ico', 'apple-touch-icon.png', 'CNAME']


def serve(directory):
    index = open(os.path.join(directory, 'index.html'), 'rb').read()

    class H(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **k): super().__init__(*a, directory=directory, **k)
        def log_message(self, *a): pass
        def do_GET(self):
            path = urlparse(self.path).path
            if os.path.isfile(os.path.join(directory, path.lstrip('/'))) and path != '/':
                return super().do_GET()
            self.send_response(200); self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(index))); self.end_headers(); self.wfile.write(index)

    srv = socketserver.ThreadingTCPServer(('127.0.0.1', 0), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, f'http://127.0.0.1:{srv.server_address[1]}'


def page_segment(html, page_id):
    """Return (start, end) of <div class="page" id="p-..."> ... up to the next section marker."""
    start = html.index(f'<div class="page" id="p-{page_id}">')
    ends = [i for i in (html.find('\n<!-- =================', start + 10), html.find('</main>', start)) if i != -1]
    return start, min(ends)


def set_head(html, info):
    def sub(pattern, repl):
        nonlocal html
        new, n = re.subn(pattern, lambda m: repl, html, count=1, flags=re.S)
        assert n == 1, pattern
        html = new
    esc = lambda s: (s or '').replace('&', '&amp;').replace('"', '&quot;').replace('<', '&lt;')
    sub(r'<title>.*?</title>', f'<title>{esc(info["title"])}</title>')
    sub(r'<meta name="description" content="[^"]*">', f'<meta name="description" content="{esc(info["desc"])}">')
    sub(r'<link rel="canonical" href="[^"]*">', f'<link rel="canonical" href="{esc(info["canonical"])}">')
    sub(r'<meta property="og:title" content="[^"]*">', f'<meta property="og:title" content="{esc(info["title"])}">')
    sub(r'<meta property="og:description" content="[^"]*">', f'<meta property="og:description" content="{esc(info["desc"])}">')
    sub(r'<meta property="og:url" content="[^"]*">', f'<meta property="og:url" content="{esc(info["canonical"])}">')
    sub(r'<meta property="og:type" content="[^"]*">', f'<meta property="og:type" content="{esc(info["ogtype"])}">')
    sub(r'<meta name="robots" content="[^"]*">', f'<meta name="robots" content="{esc(info["robots"])}">')
    html = html.replace('</head>', '<meta name="acqube-prerendered" content="1">\n</head>', 1)
    if info.get('ld'):
        ld = info['ld'].replace('</', '<\\/')
        html = html.replace('</head>', f'<script type="application/ld+json" id="page-ld">{ld}</script>\n</head>', 1)
    return html


def build(out, mock=None, supabase_js=None):
    template = open(os.path.join(SRC, 'index.html'), encoding='utf-8').read()
    data = json.load(open(mock, encoding='utf-8')) if mock else None
    srv, base = serve(SRC)
    results = {}
    with sync_playwright() as p:
        browser = p.chromium.launch()
        ctx = browser.new_context(viewport={'width': 1366, 'height': 900})

        def handle(route):
            url = route.request.url
            if 'supabase-js' in url and supabase_js:
                return route.fulfill(path=supabase_js, content_type='application/javascript')
            if data is not None and '/rest/v1/' in url:
                table = urlparse(url).path.split('/rest/v1/')[1]
                rows = data.get(table, [])
                single = 'vnd.pgrst.object' in (route.request.headers.get('accept') or '')
                body = json.dumps(rows[0] if (single and rows) else (None if single else rows))
                return route.fulfill(status=200, content_type='application/json', body=body)
            if any(h in url for h in ('googletagmanager', 'google-analytics', 'fonts.googleapis', 'fonts.gstatic')):
                return route.abort()
            return route.continue_()
        ctx.route('**/*', handle)

        page = ctx.new_page()
        errors = []
        page.on('pageerror', lambda e: errors.append(str(e)))
        ready = "() => typeof STATE!=='undefined' && STATE.posts!==null && STATE.testis!==null"
        page.goto(base + '/'); page.wait_for_function(ready, timeout=30000); page.wait_for_timeout(800)
        routes = page.evaluate('window.__routes()')
        print(f'{len(routes)} public pages')

        for r in routes + ['/admin/']:
            page.goto(base + r); page.wait_for_function(ready, timeout=30000); page.wait_for_timeout(600)
            info = page.evaluate("""() => {
              document.querySelectorAll('.reveal').forEach(e=>e.classList.add('in'));
              const active=document.querySelector('.page.on').cloneNode(true);
              // a single service page carries only its own service (no hidden copies of the others)
              const det=active.querySelector('#svc-detail'); const blocks=active.querySelector('#svc-blocks');
              if(det && det.innerHTML.trim() && blocks) blocks.innerHTML='';
              const g=(sel,attr)=>{const e=document.head.querySelector(sel);return e?e.getAttribute(attr):''};
              const ld=document.getElementById('page-ld');
              return {title:document.title, desc:g('meta[name="description"]','content'), canonical:g('link[rel="canonical"]','href'),
                      ogtype:g('meta[property="og:type"]','content')||'website', robots:g('meta[name="robots"]','content')||'index,follow',
                      ld:ld?ld.textContent:'', id:active.id.slice(2), html:active.outerHTML, path:location.pathname,
                      h1:(active.querySelector('h1')||{}).textContent||''};
            }""")
            if r.startswith('/blog/') and r != '/blog/' and info['h1'] in ('Article not found', 'Loading…', ''):
                raise SystemExit(f'Article did not render: {r}')
            results[r] = info
        if errors:
            raise SystemExit('Page errors during build:\n' + '\n'.join(errors))
        browser.close()
    srv.shutdown()

    # ---- write pages ----
    os.makedirs(out, exist_ok=True)
    for r, info in results.items():
        if r == '/admin/':
            # the admin console is rendered live in the browser only
            info['html'] = None
        html = set_head(template, info)
        if info['html']:
            a, b = page_segment(html, info['id'])
            html = html[:a] + info['html'] + html[b:]
        dest = os.path.join(out, r.strip('/'), 'index.html') if r != '/' else os.path.join(out, 'index.html')
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        open(dest, 'w', encoding='utf-8').write(html)

    # 404: plain app shell; it routes by URL (new articles work before the next rebuild)
    nf = template.replace('<meta name="robots" content="index,follow">', '<meta name="robots" content="noindex">', 1)
    open(os.path.join(out, '404.html'), 'w', encoding='utf-8').write(nf)

    # sitemap + robots
    today = datetime.date.today().isoformat()
    def prio(r): return '1.0' if r == '/' else '0.9' if r.startswith('/services/') else '0.7' if r.startswith('/blog/') else '0.6'
    urls = [r for r in results if r != '/admin/']
    xml = ['<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    for r in urls:
        xml.append(f'  <url><loc>{SITE}{r}</loc><lastmod>{today}</lastmod><priority>{prio(r)}</priority></url>')
    xml.append('</urlset>')
    open(os.path.join(out, 'sitemap.xml'), 'w').write('\n'.join(xml) + '\n')
    open(os.path.join(out, 'robots.txt'), 'w').write(f'User-agent: *\nAllow: /\nDisallow: /admin/\nSitemap: {SITE}/sitemap.xml\n')
    for f in STATIC:
        s = os.path.join(SRC, f)
        if os.path.exists(s) and os.path.abspath(out) != SRC:
            shutil.copy(s, os.path.join(out, f))
    print(f'Wrote {len(results)} pages + 404.html, sitemap.xml ({len(urls)} URLs), robots.txt to {out}')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='_site')
    ap.add_argument('--mock')
    ap.add_argument('--supabase-js')
    a = ap.parse_args()
    build(a.out, a.mock, a.supabase_js)
