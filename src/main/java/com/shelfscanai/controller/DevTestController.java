package com.shelfscanai.controller;

import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class DevTestController {

    @GetMapping(value = "/dev", produces = MediaType.TEXT_HTML_VALUE)
    @ResponseBody
    public String devDashboard() {
        return """
        <!doctype html>
        <html lang="it">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>ShelfScan Dev Dashboard</title>
          <style>
            body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; margin: 24px; }
            .row { display: grid; grid-template-columns: 1fr; gap: 16px; max-width: 980px; }
            .card { border: 1px solid #ddd; border-radius: 12px; padding: 16px; }
            .card h3 { margin: 0 0 10px; }
            .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
            label { display: block; font-size: 12px; color: #444; margin-bottom: 4px; }
            input, select, button, textarea { padding: 10px; border-radius: 10px; border: 1px solid #ccc; width: 100%; box-sizing: border-box; }
            textarea { min-height: 44px; resize: vertical; }
            button { cursor: pointer; }
            .actions { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
            pre { background: #0b1020; color: #d6e1ff; padding: 12px; border-radius: 12px; overflow: auto; }
            .hint { color: #666; font-size: 12px; margin-top: 6px; }
            .small { font-size: 12px; color: #444; }
            .pill { display:inline-block; padding: 4px 8px; border-radius: 999px; border: 1px solid #ccc; font-size: 12px; margin-right: 6px; }
            .ok { border-color: #3bb273; color: #3bb273; }
            .warn { border-color: #d8a20a; color: #d8a20a; }
            .bad { border-color: #d64545; color: #d64545; }
            .divider { height: 1px; background: #eee; margin: 14px 0; }
            .imgbox { display:flex; gap:12px; align-items:flex-start; }
            .imgprev { width: 160px; height: 160px; border-radius: 12px; border: 1px solid #ddd; object-fit: cover; background: #fafafa; }
            .muted { color:#777; }
            details { border: 1px dashed #ddd; border-radius: 12px; padding: 10px 12px; }
            summary { cursor:pointer; font-weight: 600; }
          </style>
        </head>
        <body>
          <h2>ShelfScan – Dev Dashboard</h2>
          <p class="hint">
            Obiettivo test: verificare Gemini + dedup: 1) scan nuovo, 2) scan ripetuto (no enrich), 3) scan con hint title/author (bypass).
          </p>

          <div class="row">

            <div class="card">
              <h3>0) Stato rapido</h3>
              <div class="grid">
                <div>
                  <button onclick="ping()">Ping API (GET /actuator/health)</button>
                  <div class="hint">Se non hai actuator esposto, questo fallirà: non è un problema.</div>
                </div>
                <div>
                  <button onclick="clearAll()">Pulisci tutti gli output</button>
                  <div class="hint">Reset UI senza refresh.</div>
                </div>
              </div>
              <pre id="pingOut">--</pre>
            </div>

            <div class="card" id="scanCard">
              <h3>1) Scan (POST /api/scan)</h3>

              <div class="imgbox">
                <div>
                  <img id="imgPreview" class="imgprev" alt="preview"/>
                  <div class="small muted" id="fileInfo">Nessun file selezionato</div>
                </div>

                <div style="flex:1;">
                  <form id="scanForm">
                    <div class="grid">
                      <div>
                        <label>Immagine</label>
                        <input id="imageInput" type="file" name="image" accept="image/*" required>
                      </div>
                      <div>
                        <label>Titolo (opzionale)</label>
                        <input id="scanTitle" type="text" name="title" placeholder="title">
                      </div>
                      <div>
                        <label>Autore (opzionale)</label>
                        <input id="scanAuthor" type="text" name="author" placeholder="author">
                      </div>
                      <div style="display:flex; align-items:end;">
                        <button type="submit">Esegui scan</button>
                      </div>
                    </div>
                  </form>

                  <div class="divider"></div>

                  <details open>
                    <summary>Scenari di test guidati</summary>
                    <div class="hint" style="margin-top:10px;">
                      Usa sempre la stessa immagine per verificare il dedup. Il secondo scan deve essere più veloce e idealmente non deve richiamare l’arricchimento.
                    </div>
                    <div class="grid" style="margin-top:10px;">
                      <button onclick="runScenario('new')">Scenario A: Primo scan (nuovo libro)</button>
                      <button onclick="runScenario('repeat')">Scenario B: Scan ripetuto (no enrich)</button>
                      <button onclick="runScenario('hint')">Scenario C: Scan con hint (bypass Gemini se già arricchito)</button>
                      <button onclick="runScenario('fallback')">Scenario D: Fallback (svuota hint + usa immagine difficile)</button>
                    </div>
                  </details>

                  <div class="divider"></div>

                  <div class="small">
                    <span class="pill" id="lastStatusPill">status: --</span>
                    <span class="pill" id="lastTimePill">time: --</span>
                    <span class="pill" id="lastBookIdPill">bookId: --</span>
                  </div>
                </div>
              </div>

              <pre id="scanOut">--</pre>

              <div class="grid" style="margin-top:10px;">
                <button onclick="copyScanBookIdToDetail()">Usa bookId dello scan nel dettaglio</button>
                <button onclick="copyScanBookIdToLibraryOps()">Usa bookId dello scan in aggiungi/rimuovi</button>
              </div>

              <div class="hint">
                Risposta attesa: JSON di ScanResponse. Se vedi 401, devi essere loggato (EasyAuth). Se vedi 5xx, incolla i log del backend.
              </div>
            </div>

            <div class="card">
              <h3>2) Catalogo globale (GET /api/books?query=...)</h3>
              <div class="grid">
                <div>
                  <label>Query</label>
                  <input id="bookQuery" type="text" placeholder="es. harry potter">
                </div>
                <div style="display:flex; align-items:end;">
                  <button onclick="searchBooks()">Cerca</button>
                </div>
              </div>
              <pre id="booksOut">--</pre>
            </div>

            <div class="card">
              <h3>3) Libreria utente (GET /api/library)</h3>
              <div class="actions">
                <button onclick="getLibrary()">Carica libreria</button>
                <button onclick="clearOut('libraryOut')">Pulisci output</button>
              </div>
              <pre id="libraryOut">--</pre>
            </div>

            <div class="card" id="detailCard">
              <h3>4) Dettaglio libreria (GET /api/library/{bookId})</h3>
              <div class="grid">
                <div>
                  <label>bookId</label>
                  <input id="detailBookId" type="number" placeholder="es. 1">
                </div>
                <div style="display:flex; align-items:end;">
                  <button onclick="getLibraryItem()">Carica dettaglio</button>
                </div>
              </div>

              <div class="grid" style="margin-top:10px;">
                <button onclick="extractDescTags()">Estrai description/tags dal dettaglio (se presenti)</button>
                <button onclick="clearOut('detailOut')">Pulisci output</button>
              </div>

              <pre id="detailOut">--</pre>

              <details>
                <summary>description / tags (dal dettaglio)</summary>
                <div class="grid" style="margin-top:10px;">
                  <div>
                    <label>Description</label>
                    <textarea id="descOut" readonly></textarea>
                  </div>
                  <div>
                    <label>Tags</label>
                    <textarea id="tagsOut" readonly></textarea>
                  </div>
                </div>
              </details>
            </div>

            <div class="card" id="libraryOpsCard">
              <h3>5) Aggiungi/Rimuovi libro dalla libreria</h3>
              <div class="grid">
                <div>
                  <label>bookId</label>
                  <input id="libBookId" type="number" placeholder="es. 1">
                </div>
                <div class="actions" style="align-items:end;">
                  <button onclick="addToLibrary()">Aggiungi (POST)</button>
                  <button onclick="removeFromLibrary()">Rimuovi (DELETE)</button>
                </div>
              </div>
              <pre id="addRemoveOut">--</pre>
            </div>

            <div class="card">
              <h3>6) Cambia status (PATCH /api/library/{bookId}/status)</h3>
              <div class="grid">
                <div>
                  <label>bookId</label>
                  <input id="statusBookId" type="number" placeholder="es. 1">
                </div>
                <div>
                  <label>Status</label>
                  <select id="statusValue">
                    <option value="TO_READ">TO_READ</option>
                    <option value="READING">READING</option>
                    <option value="READ">READ</option>
                  </select>
                </div>
              </div>
              <div style="margin-top:10px;">
                <button onclick="updateStatus()">Aggiorna status</button>
              </div>
              <pre id="statusOut">--</pre>
            </div>

          </div>

          <script>
            function setPill(elId, text, cls) {
              const el = document.getElementById(elId);
              el.className = 'pill ' + (cls || '');
              el.textContent = text;
            }

            function clearOut(id) {
              document.getElementById(id).textContent = '--';
            }

            function clearAll() {
              ['pingOut','scanOut','booksOut','libraryOut','detailOut','addRemoveOut','statusOut'].forEach(clearOut);
              document.getElementById('descOut').value = '';
              document.getElementById('tagsOut').value = '';
              setPill('lastStatusPill', 'status: --');
              setPill('lastTimePill', 'time: --');
              setPill('lastBookIdPill', 'bookId: --');
            }

            async function fetchJson(url, options) {
              const t0 = performance.now();
              const res = await fetch(url, options);
              const t1 = performance.now();
              const text = await res.text();
              let body;
              try { body = JSON.parse(text); } catch { body = text; }
              return { status: res.status, ms: Math.round(t1 - t0), body };
            }

            function pretty(obj) {
              return typeof obj === 'string' ? obj : JSON.stringify(obj, null, 2);
            }

            async function ping() {
              const r = await fetchJson('/actuator/health');
              document.getElementById('pingOut').textContent = pretty(r);
            }

            let lastScanBookId = null;

            function updateLastScanMeta(r) {
              const status = r.status;
              const ms = r.ms;

              let statusCls = 'ok';
              if (status >= 400 && status < 500) statusCls = 'warn';
              if (status >= 500) statusCls = 'bad';

              setPill('lastStatusPill', 'status: ' + status, statusCls);
              setPill('lastTimePill', 'time: ' + ms + 'ms', statusCls);

              // prova a trovare id nel body
              let id = null;
              if (r && r.body && typeof r.body === 'object') {
                if (r.body.id != null) id = r.body.id;
                // fallback: se ScanResponse ha bookId invece di id
                if (id == null && r.body.bookId != null) id = r.body.bookId;
              }
              if (id != null) {
                lastScanBookId = id;
                setPill('lastBookIdPill', 'bookId: ' + id, 'ok');
              } else {
                setPill('lastBookIdPill', 'bookId: --', statusCls);
              }
            }

            function copyScanBookIdToDetail() {
              if (lastScanBookId == null) return alert('Nessun bookId dallo scan.');
              document.getElementById('detailBookId').value = lastScanBookId;
              document.getElementById('detailCard').scrollIntoView({ behavior:'smooth', block:'start' });
            }

            function copyScanBookIdToLibraryOps() {
              if (lastScanBookId == null) return alert('Nessun bookId dallo scan.');
              document.getElementById('libBookId').value = lastScanBookId;
              document.getElementById('statusBookId').value = lastScanBookId;
              document.getElementById('libraryOpsCard').scrollIntoView({ behavior:'smooth', block:'start' });
            }

            async function searchBooks() {
              const q = document.getElementById('bookQuery').value || '';
              const url = '/api/books?query=' + encodeURIComponent(q.trim());
              const r = await fetchJson(url);
              document.getElementById('booksOut').textContent = pretty(r);
            }

            async function getLibrary() {
              const r = await fetchJson('/api/library');
              document.getElementById('libraryOut').textContent = pretty(r);
            }

            async function getLibraryItem() {
              const id = document.getElementById('detailBookId').value;
              if (!id) return alert('Inserisci bookId');
              const r = await fetchJson('/api/library/' + encodeURIComponent(id));
              document.getElementById('detailOut').textContent = pretty(r);
              return r;
            }

            async function addToLibrary() {
              const id = document.getElementById('libBookId').value;
              if (!id) return alert('Inserisci bookId');
              const r = await fetchJson('/api/library/' + encodeURIComponent(id), { method: 'POST' });
              document.getElementById('addRemoveOut').textContent = pretty(r);
            }

            async function removeFromLibrary() {
              const id = document.getElementById('libBookId').value;
              if (!id) return alert('Inserisci bookId');
              const r = await fetchJson('/api/library/' + encodeURIComponent(id), { method: 'DELETE' });
              document.getElementById('addRemoveOut').textContent = pretty(r);
            }

            async function updateStatus() {
              const id = document.getElementById('statusBookId').value;
              const status = document.getElementById('statusValue').value;
              if (!id) return alert('Inserisci bookId');

              const r = await fetchJson('/api/library/' + encodeURIComponent(id) + '/status', {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ status })
              });

              document.getElementById('statusOut').textContent = pretty(r);
            }

            async function extractDescTags() {
              const r = await getLibraryItem();
              if (!r || typeof r.body !== 'object') return;

              // prova pattern comuni: { book: { description, tags } } oppure { description, tags }
              let desc = '';
              let tags = '';

              const b = r.body.book ? r.body.book : r.body;
              if (b && typeof b === 'object') {
                if (b.description) desc = b.description;
                if (b.tags) tags = (typeof b.tags === 'string') ? b.tags : JSON.stringify(b.tags);
              }

              document.getElementById('descOut').value = desc || '';
              document.getElementById('tagsOut').value = tags || '';
            }

            // --- SCAN via fetch per avere tempo/status/output nello stesso riquadro (meglio del submit form)
            const scanForm = document.getElementById('scanForm');
            scanForm.addEventListener('submit', async (e) => {
              e.preventDefault();
              await doScan();
            });

            async function doScan() {
              const file = document.getElementById('imageInput').files[0];
              if (!file) return alert('Seleziona un file');

              const fd = new FormData();
              fd.append('image', file);

              const title = document.getElementById('scanTitle').value || '';
              const author = document.getElementById('scanAuthor').value || '';
              if (title.trim()) fd.append('title', title.trim());
              if (author.trim()) fd.append('author', author.trim());

              const r = await fetchJson('/api/scan', { method: 'POST', body: fd });
              document.getElementById('scanOut').textContent = pretty(r);
              updateLastScanMeta(r);

              // se ho un id, precompila campi utili
              if (lastScanBookId != null) {
                document.getElementById('detailBookId').value = lastScanBookId;
                document.getElementById('libBookId').value = lastScanBookId;
                document.getElementById('statusBookId').value = lastScanBookId;
              }

              return r;
            }

            async function runScenario(kind) {
              // scenario: non possiamo "scegliere un file" via JS (browser security)
              // quindi: l'utente deve aver già selezionato l'immagine nel file input.
              const file = document.getElementById('imageInput').files[0];
              if (!file) {
                alert('Prima seleziona un file immagine in "Scan". Poi riprova lo scenario.');
                document.getElementById('scanCard').scrollIntoView({ behavior:'smooth', block:'start' });
                return;
              }

              if (kind === 'new') {
                document.getElementById('scanTitle').value = '';
                document.getElementById('scanAuthor').value = '';
                return doScan();
              }

              if (kind === 'repeat') {
                // ripeti identico: niente hint
                document.getElementById('scanTitle').value = '';
                document.getElementById('scanAuthor').value = '';
                return doScan();
              }

              if (kind === 'hint') {
                // usa hint basati sul risultato precedente (se disponibili)
                const out = document.getElementById('scanOut').textContent;
                try {
                  const parsed = JSON.parse(out);
                  const body = parsed.body || {};
                  if (body.title) document.getElementById('scanTitle').value = body.title;
                  if (body.author) document.getElementById('scanAuthor').value = body.author;
                } catch {}
                return doScan();
              }

              if (kind === 'fallback') {
                document.getElementById('scanTitle').value = '';
                document.getElementById('scanAuthor').value = '';
                alert('Scenario fallback: usa una copertina difficile (sfocata / testo piccolo). Poi fai scan.');
                return;
              }
            }

            // preview immagine
            const imageInput = document.getElementById('imageInput');
            imageInput.addEventListener('change', () => {
              const f = imageInput.files[0];
              if (!f) return;

              document.getElementById('fileInfo').textContent =
                f.name + ' • ' + Math.round(f.size / 1024) + 'KB • ' + (f.type || 'image/*');

              const url = URL.createObjectURL(f);
              document.getElementById('imgPreview').src = url;
            });
          </script>
        </body>
        </html>
        """;
    }
}