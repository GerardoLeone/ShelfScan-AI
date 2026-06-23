package com.shelfscanai.service;

public class Prompts {

    public static final String EXTRACT_PROMPT =
            """
            SYSTEM:
            Restituisci SOLO JSON valido compatibile con lo schema richiesto.
            Nessun markdown.
            Nessun testo extra.

            TASK:
            Dall'immagine della copertina del libro estrai:

            - title (string oppure null)
            - author (string oppure null)

            Regole:
            - Se è visibile un volume/numero (es. Vol. 3, #3, Tome 3),
              includilo nel titolo.
            - Se ci sono più candidati, scegli il più probabile.
            - Restituisci confidence tra 0 e 1.
            - notes deve spiegare eventuali dubbi.
            - Non inventare l’autore se non è visibile: usa null.
            """;

    public static String enrichPrompt(String title, String author) {
        return """
                SYSTEM:
                Restituisci SOLO JSON valido compatibile con lo schema richiesto.
                Nessun markdown.
                Nessun testo extra.

                TASK:

                - author:
                  se l'autore nel contesto manca oppure è sconosciuto,
                  prova a inferire l’autore reale più probabile.

                - description:
                  scrivi la TRAMA/SINOSSI del libro,
                  NON la descrizione della copertina.

                  5-8 frasi
                  tono neutro
                  niente spoiler importanti
                  non rivelare il finale

                - tags:
                  genera 5-8 tag brevi, utili per la ricerca in libreria

                  Regole tag:
                  * rigorosamente in italiano
                  * minuscoli
                  * massimo 1-3 parole
                  * senza duplicati
                  * niente frasi complete
                  * niente inglese

                - confidence:
                  valore tra 0 e 1 sulla correttezza dell’identificazione

                REGOLE IMPORTANTI:

                1. NON descrivere l’immagine/copertina
                   (niente colori, persone, font, layout)

                2. Usa titolo e autore per ricostruire
                   la vera trama del libro

                3. Se il titolo è ambiguo
                   (più libri con stesso nome),
                   mantieni una trama generica
                   e imposta confidence <= 0.4

                4. Se non puoi inferire bene l’autore,
                   restituisci author = "unknown"
                   e confidence <= 0.4

                5. Description e tags devono essere
                   SEMPRE in italiano

                CONTEXT:

                title: "%s"
                author: "%s"
                """.formatted(title, author);
    }
}