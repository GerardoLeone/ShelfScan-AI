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
            input, select, button { padding: 10px; border-radius: 10px; border: 1px solid #ccc; width: 100%; box-sizing: border-box; }
            button { cursor: pointer; }
            .actions { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
            .actions3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px; }
            pre { background: #0b1020; color: #d6e1ff; padding: 12px; border-radius: 12px; overflow: auto; min-height: 44px; }
            .hint { color: #666; font-size: 12px; margin-top: 6px; line-height: 1.35; }
            .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace; }
            .badge { display: inline-block; padding: 2px 8px; border-radius: 999px; border: 1px solid #ddd; font-size: 12px; }
          </style>
        </head>
        <body>
          <h2>ShelfScan – Dev Dashboard</h2>
          <p class="hint">Pagina di test rapida per le API (Easy Auth gestisce il login).</p>

          <div class="row">

            <div class="card">
              <h3>1) Scan (POST /api/scan)</h3>

              <form id="scanForm" enctype="multipart/form-data">
                <div class="grid">
                  <div>
                    <label>Immagine</label>
                    <input id="scanImage" type="file" name="image" accept="image/*" required>
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
                    <button type="submit">Scan via fetch()</button>
                  </div>
                </div>
              </form>

              <div class="actions3" style="margin-top:10px;">
                <button onclick="scanOnly()">Scan</button>
                <button onclick="scanAndLoad()">Scan + GET /api/books/{id} + GET /api/library</button>
                <button onclick="clearOut('scanOut')">Pulisci output</button>
              </div>

              <pre id="scanOut">--</pre>
              <div class="hint">
                Suggerimento: rifai lo scan della stessa cover o di una variante (es. “antologia”, “vol. 1”).
                Se l’output arriva senza chiamate extra o con tempi più bassi, probabilmente sta riusando trama/tag senza enrich.
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
              <div class="actions" style="margin-top:10px;">
                <button onclick="clearOut('booksOut')">Pulisci output</button>
                <button onclick="copyOut('booksOut')">Copia output</button>
              </div>
              <pre id="booksOut">--</pre>
            </div>

            <div class="card">
              <h3>2B) Dettaglio libro (GET /api/books/{id})</h3>
              <div class="grid">
                <div>
                  <label>bookId</label>
                  <input id="bookId" type="number" placeholder="es. 5">
                </div>
                <div style="display:flex; align-items:end;">
                  <button onclick="getBookById()">Carica libro</button>
                </div>
              </div>
              <div class="actions" style="margin-top:10px;">
                <button onclick="clearOut('bookOut')">Pulisci output</button>
                <button onclick="copyOut('bookOut')">Copia output</button>
              </div>
              <pre id="bookOut">--</pre>
            </div>

            <div class="card">
              <h3>3) Libreria utente (GET /api/library)</h3>
              <div class="actions">
                <button onclick="getLibrary()">Carica libreria</button>
                <button onclick="clearOut('libraryOut')">Pulisci output</button>
              </div>
              <pre id="libraryOut">--</pre>
            </div>

            <div class="card">
              <h3>4) Dettaglio libreria (GET /api/library/{bookId})</h3>
              <div class="grid">
                <div>
                  <label>bookId</label>
                  <input id="detailBookId" type="number" placeholder="es. 5">
                </div>
                <div style="display:flex; align-items:end;">
                  <button onclick="getLibraryItem()">Carica dettaglio</button>
                </div>
              </div>
              <div class="actions" style="margin-top:10px;">
                <button onclick="clearOut('detailOut')">Pulisci output</button>
                <button onclick="copyOut('detailOut')">Copia output</button>
              </div>
              <pre id="detailOut">--</pre>
            </div>

            <div class="card">
              <h3>5) Aggiungi/Rimuovi libro dalla libreria</h3>
              <div class="grid">
                <div>
                  <label>bookId</label>
                  <input id="libBookId" type="number" placeholder="es. 5">
                </div>
                <div class="actions" style="align-items:end;">
                  <button onclick="addToLibrary()">Aggiungi (POST)</button>
                  <button onclick="removeFromLibrary()">Rimuovi (DELETE)</button>
                </div>
              </div>
              <div class="actions" style="margin-top:10px;">
                <button onclick="clearOut('addRemoveOut')">Pulisci output</button>
                <button onclick="copyOut('addRemoveOut')">Copia output</button>
              </div>
              <pre id="addRemoveOut">--</pre>
            </div>

            <div class="card">
              <h3>6) Cambia status (PATCH /api/library/{bookId}/status)</h3>
              <div class="grid">
                <div>
                  <label>bookId</label>
                  <input id="statusBookId" type="number" placeholder="es. 5">
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
              <div class="actions" style="margin-top:10px;">
                <button onclick="clearOut('statusOut')">Pulisci output</button>
                <button onclick="copyOut('statusOut')">Copia output</button>
              </div>
              <pre id="statusOut">--</pre>
            </div>

          </div>

          <script>
            function clearOut(id) {
              document.getElementById(id).textContent = '--';
            }

            async function copyOut(id) {
              const text = document.getElementById(id).textContent;
              try {
                await navigator.clipboard.writeText(text);
              } catch {}
            }

            async function fetchJson(url, options) {
              const res = await fetch(url, options);
              const text = await res.text();
              let body;
              try { body = JSON.parse(text); } catch { body = text; }
              return { status: res.status, body };
            }

            async function postScan() {
              const file = document.getElementById('scanImage').files[0];
              if (!file) throw new Error("Seleziona un file immagine");

              const title = document.getElementById('scanTitle').value || '';
              const author = document.getElementById('scanAuthor').value || '';

              const fd = new FormData();
              fd.append("image", file);
              if (title.trim()) fd.append("title", title.trim());
              if (author.trim()) fd.append("author", author.trim());

              const res = await fetch("/api/scan", { method: "POST", body: fd });
              const text = await res.text();
              let body;
              try { body = JSON.parse(text); } catch { body = text; }
              return { status: res.status, body };
            }

            async function scanOnly() {
              const out = document.getElementById('scanOut');
              out.textContent = "Scanning...";
              try {
                const r = await postScan();
                out.textContent = JSON.stringify(r, null, 2);
              } catch (e) {
                out.textContent = String(e);
              }
            }

            async function scanAndLoad() {
              const out = document.getElementById('scanOut');
              out.textContent = "Scanning...";
              try {
                const r = await postScan();

                if (r.status === 200 && r.body && (r.body.bookId || r.body.id)) {
                  const id = r.body.bookId || r.body.id;
                  const book = await fetchJson("/api/books/" + encodeURIComponent(id));
                  const lib  = await fetchJson("/api/library");

                  out.textContent = JSON.stringify({
                    scan: r,
                    book,
                    library: lib
                  }, null, 2);
                } else {
                  out.textContent = JSON.stringify(r, null, 2);
                }
              } catch (e) {
                out.textContent = String(e);
              }
            }

            async function searchBooks() {
              const q = document.getElementById('bookQuery').value || '';
              const url = '/api/books?query=' + encodeURIComponent(q.trim());
              const r = await fetchJson(url);
              document.getElementById('booksOut').textContent = JSON.stringify(r, null, 2);
            }

            async function getBookById() {
              const id = document.getElementById('bookId').value;
              const r = await fetchJson('/api/books/' + encodeURIComponent(id));
              document.getElementById('bookOut').textContent = JSON.stringify(r, null, 2);
            }

            async function getLibrary() {
              const r = await fetchJson('/api/library');
              document.getElementById('libraryOut').textContent = JSON.stringify(r, null, 2);
            }

            async function getLibraryItem() {
              const id = document.getElementById('detailBookId').value;
              const r = await fetchJson('/api/library/' + encodeURIComponent(id));
              document.getElementById('detailOut').textContent = JSON.stringify(r, null, 2);
            }

            async function addToLibrary() {
              const id = document.getElementById('libBookId').value;
              const r = await fetchJson('/api/library/' + encodeURIComponent(id), { method: 'POST' });
              document.getElementById('addRemoveOut').textContent = JSON.stringify(r, null, 2);
            }

            async function removeFromLibrary() {
              const id = document.getElementById('libBookId').value;
              const r = await fetchJson('/api/library/' + encodeURIComponent(id), { method: 'DELETE' });
              document.getElementById('addRemoveOut').textContent = JSON.stringify(r, null, 2);
            }

            async function updateStatus() {
              const id = document.getElementById('statusBookId').value;
              const status = document.getElementById('statusValue').value;

              const r = await fetchJson('/api/library/' + encodeURIComponent(id) + '/status', {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ status })
              });

              document.getElementById('statusOut').textContent = JSON.stringify(r, null, 2);
            }

            document.addEventListener("DOMContentLoaded", () => {
              const f = document.getElementById("scanForm");
              if (f) {
                f.addEventListener("submit", (ev) => {
                  ev.preventDefault();
                  scanOnly();
                });
              }
            });
          </script>
        </body>
        </html>
        """;
    }
}