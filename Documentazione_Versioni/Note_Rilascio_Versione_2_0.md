# Note di Rilascio — Versione 2.0

> Salto maggiore **1.35 → 2.0**: introduzione dell'**Estensione CMS per il Web** nel gestionale, più una serie di bug pre-esistenti individuati e risolti durante i test di pre-rilascio.
> Data: 2026-07-19. Stato: in preparazione (documento vivo fino al go-live).

---

## Sezione 1 — Nuove funzionalità: Estensione CMS per il Web

Il gestionale diventa l'**unico motore di contenuti** per il nuovo sito pubblico: i contenuti web sono redatti e gestiti dal gestionale (nessun CMS separato) e pubblicati verso il sito.

> **Criterio di inserimento:** in questa sezione entrano **solo le funzionalità verificate a runtime**. Le altre restano nell'elenco "In attesa di verifica" finché non sono collaudate, e vengono promosse a funzionalità rilasciata una volta testate.

### Funzionalità verificate

- **Lingua del cliente (anagrafica)** — nuovo campo *lingua preferita* in anagrafica cliente, usato dalla newsletter per l'invio multilingua. Il campo non è mai vuoto: se l'operatore non lo specifica, la lingua viene **auto-derivata dalla nazione di residenza** (fallback italiano) e memorizzata; la newsletter la legge senza dover ragionare. *(Verificato a runtime: 2026-07-19.)*

### In attesa di verifica runtime (non ancora documentate come rilasciate)

Implementate ma da collaudare prima di promuoverle sopra:

- [ ] Schede web dei tour per edizione (viaggio + data): crea / clona / anteprima
- [ ] Incluso / Escluso per tour (tradotti)
- [ ] Capienza e "posti rimasti" per tour
- [ ] Tour brevi / giornalieri
- [ ] Itinerario giorno-per-giorno (drag&drop)
- [ ] Galleria immagini tour (WebP + Supabase Storage)
- [ ] Mappe statiche da traccia GPX (Geoapify)
- [ ] Traduzioni assistite multilingua (Claude)
- [ ] Newsletter multilingua (invio, iscrizione/disiscrizione, destinatari)
- [ ] Tipi viaggio globali + descrizioni / categorie
- [ ] Configurazione funzioni web per azienda
- [ ] Recensioni Google / TripAdvisor
- [ ] SMTP: test connessione con diagnostica (firewall/VPN, DNS, TLS…), messaggi errore centralizzati, mostra/nascondi password
- [ ] Cifratura segreti (SMTP / ESP / Claude) via `pgcrypto`

> Nota architetturale: logica dati **DB-first** (funzioni PostgreSQL), componenti UI **condivisi**, contenuti web **per-azienda** (silos multi-tenant); solo tipi-viaggio e relative descrizioni sono globali.

---

## Sezione 2 — Bug pre-esistenti individuati e risolti

Bug non legati all'estensione web, emersi durante i test di pre-rilascio e corretti in questa versione.

| # | Area | Problema | Soluzione |
|---|------|----------|-----------|
| 1 | **Anagrafica Cliente — validazione** | I campi **obbligatori su tab non visitati** (es. "Documenti") **non bloccavano il salvataggio** (insert e update): `MudForm` valida solo i campi renderizzati e `MudTabs` renderizzava solo il pannello attivo, quindi i `Required` sugli altri tab non venivano registrati. | `KeepPanelsAlive="true"` sui `MudTabs`: tutti i pannelli renderizzati → tutti i campi validati. (Stesso schema già corretto in passato su `AziendaDialog`/`AnaViaggiDialog`; mancava su `ClienteDialog`.) |
| 2 | **Anagrafica Cliente — lingua (salvataggio)** | Il cast `@L::char` (= `char(1)`) in `ClienteLinguaService.SetAsync` **troncava** il codice lingua (`IT`→`I`) prima della funzione DB → al rientro il campo mostrava il codice grezzo. | Cast corretto a `::varchar`; script di **repair dati** per le righe già troncate (rimappa 1 carattere → ISO a 2 lettere). |
| 3 | **Anagrafica Cliente — lingua (NULL)** | Svuotando il campo lingua si salvava **NULL** in `cliente_lingua`, delegando alla newsletter la derivazione. | La funzione `fn_ana_clienti_set_lingua` **auto-deriva** la lingua dalla nazione di residenza quando il campo è vuoto (fallback `IT`); colonna resa `NOT NULL DEFAULT 'IT'`. La newsletter legge il valore senza dover ragionare. |
| 4 | **Anagrafica Cliente — layout** | La form del dialog aveva **altezza fissa (800px)** → grande spazio vuoto verticale e barra di scorrimento inutile; spaziatura eccessiva tra i campi. | Altezza resa **adattiva** (`max-height: 80vh`) e spaziatura dei tab compattata. |
| 5 | **SMTP — lettura password** | Il recupero della password SMTP in chiaro leggeva `password_enc->>'value'` (JSONB) su una colonna diventata `bytea` (pgcrypto) → errore silenzioso, il test dava sempre "password non recuperabile" anche con password salvata. | Nuova funzione DB `fn_ana_aziende_smtp_secrets_get` (decifra via `pgp_sym_decrypt`); C# aggiornato per usarla. |

### Note operative emerse dai test
- I **test SMTP** (test connessione, invio) vanno eseguiti con **VPN disattivata**: molti server di posta bloccano gli IP di VPN/datacenter sulle porte mail pur lasciando aperte quelle web. Il messaggio d'errore ora lo segnala esplicitamente.

---

*Documento da completare/rivedere fino al go-live. Per la sequenza tecnica di deploy in produzione vedi `Estensione Progetto WEB/Documenti/2026-07-10-Checklist_Go_Live_PROD.md`.*
