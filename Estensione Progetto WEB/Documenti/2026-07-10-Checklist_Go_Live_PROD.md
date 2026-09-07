# Checklist Go-Live PROD — Estensione Web

> **Scopo.** Documento **operativo e vivo**: elenca *tutto* ciò che va modificato/configurato in produzione (Supabase) prima di rilasciare l'Estensione Web. Va aggiornato **a ogni nuovo script SQL o requisito di deploy**. In locale si lavora su Docker (`postgres_db`); la PROD è Supabase/PgBouncer.
>
> **Ultimo aggiornamento:** 2026-08-09 (nuovi script `511` telefono destinatari e `512` newsletter a blocchi Fase 1; intervallo esteso a 406–512). **Stato:** NON ancora rilasciato.

---

## 0. La sequenza, in ordine di esecuzione

⚠️ **Questo è il documento che si segue mentre il cliente aspetta.** Le sezioni sotto sono
in ordine di esecuzione: si va dall'alto verso il basso. Dove l'ordine è vincolante è
scritto perché — e sono i punti in cui un'inversione fa danno, non fastidio.

### Prima del giorno del go-live (senza fretta, si può fare in anticipo)

| | Cosa | Dove |
|---|---|---|
| ☐ | Passata sui dati scritti dentro il codice | §0.1 |
| ☐ | Sanare MAIORCA MARIA (scheda doppia) | §2.10 |
| ☐ | Completare GENDUSO FRANCESCA (manca la data di nascita) | §2.11 |
| ☐ | Elenco delle 27 schede incomplete consegnato ad Antonio, e deciso come procedere | §2.12 |
| ☐ | MCP di Supabase configurato | §7 |
| ☐ | Domini e deliverability verificati | §3.6 |
| ☐ | Capitolo del manuale sugli stati dei contenuti web scritto | §3.4 |

### Il giorno del go-live, nell'ordine

| | Cosa | Dove | ⚠️ |
|---|---|---|---|
| ☐ | 1. Backup di PROD | §1 | senza questo non si comincia |
| ☐ | 2. Script `406`→`466` | §1 | |
| ☐ | 3. Voci ad attenzione manuale della prima fascia (RLS, Storage, backfill lingua) | §2.1–§2.6 | |
| ☐ | 4. Script `467`→`596` | §1 | **587→588→589→592 in quest'ordine**, §1.6 |
| ☐ | 5. `GV_SECRET_KEY` in PROD e segreti re-inseriti | §3.1 | senza, la posta non parte |
| ☐ | 6. `MAIL_DIROTTA_A` **assente** dall'ambiente | §3.8 | se c'è, nessun cliente riceve nulla |
| ☐ | 7. Resto della configurazione applicativa | §3.2 | |
| ☐ | 8. Contenuti da caricare a parte (newsletter, iscritti, `eba_countries`) | §6 | |
| ☐ | 9. Verifiche post-applicazione | §4 | |
| ☐ | 10. La consegna: **un evento solo, tre componenti** | §3.7 | l'ordine non è negoziabile |

### Le tre verifiche che dicono se è andata

```sql
-- 1. nessun movimento attraversa il confine fra aziende
SELECT count(*) FROM fn_silos_movimenti_fuori_azienda();          -- atteso: 0

-- 2. nessuno occupa un letto senza essere iscritto
SELECT count(*) FROM mov_clienti_alloggi a
CROSS JOIN LATERAL unnest(ARRAY[a.cliente_id1_fk,a.cliente_id2_fk,a.cliente_id3_fk,
                                a.cliente_id4_fk,a.cliente_id5_fk,a.cliente_id6_fk]) AS u(cli)
WHERE u.cli IS NOT NULL AND NOT EXISTS (
  SELECT 1 FROM mov_clienti_viaggi m
  WHERE m.cliente_id_fk = u.cli AND m.data_viaggio_id_fk = a.data_viaggio_id_fk);  -- atteso: 0

-- 3. i codici dei documenti sono tornati tre
SELECT DISTINCT cliente_tipodoc_identita FROM ana_clienti;        -- atteso: CI, PAS, PAT, vuoto
```

---

## 0.1 — PRIMA DEL PASSAGGIO A PROD: passata sui dati scritti dentro il codice
**Deciso il 2026-09-05.** Nel giro di una sola giornata sono emersi quattro difetti dello
**stesso ceppo**: un dato che dipende dall'**azienda** o dall'**ambiente**, scritto dentro
il programma invece che nella configurazione.

| Difetto | Cosa era cablato |
|---|---|
| 80 | I destinatari della posta: in sviluppo si spediva ai clienti veri |
| 83 | L'appartenenza all'azienda, mai controllata nei movimenti |
| — (§1.7) | Il consenso, chiesto e scritto senza sapere per quale azienda |
| — (§2-bis prossime funzioni) | L'indirizzo del sito SFT nel bottone «Esci» |

⚠️ Continuare a trovarli uno alla volta, per caso, è il modo peggiore: ognuno è costato
un'indagine, e quelli non ancora incontrati usciranno **in produzione**, dove costano di
più. Prima del passaggio a PROD va fatta **una passata mirata solo su questo**, su
entrambi i software: cercare indirizzi, identificativi di azienda, destinatari, URL e
percorsi scritti a mano, e portarli dove stanno già gli altri — configurazione
dell'azienda o variabili d'ambiente.

Non è un lavoro di rifinitura: un dato cablato che riguarda l'azienda **funziona sempre in
prova e sbaglia bersaglio in produzione**, che è esattamente il caso peggiore.

---

### Raccolta del 2026-09-05 — cosa è emerso davvero

| Dove | Cosa | Stato |
|---|---|---|
| `Classi_Tabelle_DB/lista_viaggi.py` | `AZIENDA_ID` con ripiego **`'6'`** mentre altrove è `'2'` | ✅ **fatto** — difetto 95, ora `azienda_corrente()` senza ripiego |
| `SimpleSummaryModal.jsx` | `https://www.sardegnafuoritraccia.it/it` nel bottone «Esci» | ☐ da fare |
| `Step1Content.jsx`, `Step3Content.jsx` | `segreteria@sardegnafuoritraccia.it` nei messaggi d'errore | ☐ da fare |
| `static/informativa_privacy.html` | `info@sardegnafuoritraccia.it`, 4 volte | ☐ da fare |
| `Manuale_Utente/manuale_utente.html` | indirizzo del sito, email, e **mermaid caricato da `unpkg.com`** — un CDN esterno in una pagina consegnata al cliente | ☐ da fare |
| `SmtpEmailSender.cs` (gestionale) | accetta qualunque certificato TLS | ☐ vedi §5-bis delle prossime funzioni |

⚠️ **Gli indirizzi hanno tutti la stessa cura**: quelli di posta stanno già nella
configurazione dell'azienda; manca solo un campo per l'indirizzo del sito pubblico, e poi si
leggono da lì. **Il giorno del rebrand** — OFFTRACE è in valutazione — cambiano dominio e
caselle: se restano nel codice, il rebrand diventa una ricompilazione invece di una riga di
configurazione.

## 1. Migrazione DB — script da applicare in ordine

> ## ⚠️ L'azienda dell'Estensione Web è la **2**
>
> Tutti i dati che questa checklist dice di portare in PROD — modelli di newsletter, indirizzi web,
> schede di contenuti, iscritti — appartengono all'**azienda 2, «Sardegna Fuori Traccia di Antonio
> Tolu»**. È l'unica azienda che ha dati web: la 6 («Offroad Adventures di Mironova Anna») ne ha
> zero, e ha solo un'anagrafica clienti più grande — motivo per cui è facile scambiarla.
>
> ```sql
> -- verifica al volo, prima di copiare qualunque cosa
> SELECT a.azienda_id, a.ragione_sociale,
>        (SELECT count(*) FROM web_newsletter_invii i WHERE i.azienda_id = a.azienda_id) AS newsletter,
>        (SELECT count(*) FROM web_tour_contenuti  t WHERE t.azienda_id = a.azienda_id) AS schede_web,
>        (SELECT count(*) FROM web_indirizzi       w WHERE w.azienda_id = a.azienda_id) AS indirizzi
>   FROM ana_aziende a ORDER BY 1;
> ```
>
> *(L'unico «azienda 6» che resta legittimo in questo documento è nella scheda della transazione 72,
> più sotto: è il resoconto di una riga sbagliata già corretta su PROD, non un'istruzione di copia.)*

L'Estensione Web + hardening introducono gli script **`SqlScripts/406` → `585`** (i numeri **445–449 non esistono**; il numero **499 è usato da due file** — vedi l'avviso in testa all'elenco 467–524). Su un DB PROD che non li ha mai visti, il deploy = applicarli **tutti, in ordine numerico crescente**. Sono per la maggior parte idempotenti (function `CREATE OR REPLACE`, `IF NOT EXISTS`), ma **alcuni richiedono attenzione manuale**: le note riga per riga stanno nelle due tabelle qui sotto, i dettagli operativi in §2 e §3.

> **Blocco 13 (467–474)** — re-model contenuti web **per edizione** (viaggio+data): `467` `ana_viaggi.viaggio_difficolta`; `468` `web_tour_contenuti` +`data_viaggio_id_fk`/−difficoltà/CRUD; `469–471` figlie ri-ancorate a `web_tour_contenuti_id_fk` (BIGINT); `472` public per-edizione + `fn_web_prezzo_da_data`; `473` RLS anon per-contenuto; `474` `fn_web_tour_contenuti_clona`. ⚠️ `468`+`469–471` cambiano colonne/vincoli su tabelle **presunte vuote** (nessun contenuto web esistente): su PROD applicare **prima** che esistano contenuti.

> **Blocco 5 Fase 2 — SEO assistita (486)** — `fn_web_tour_pubblicati` espone `meta_title`/`meta_description` **in coda** al `RETURNS TABLE` con fallback DB-side (`COALESCE(NULLIF(btrim(...),''), titolo/sottotitolo)`); `SECURITY INVOKER`, nessun nuovo grant colonnare necessario (`web_tour_contenuti.meta_title`/`meta_description` sono colonne originarie della tabella, già coperte dal grant `SELECT` colonnare ad `anon` — vedi §2.1). Meta non tradotti in questo pass. Nessun consumer C# nel gestionale mappa questa funzione (letta solo dal frontend pubblico via RPC).

> **Aggiunte CMS (476–479)** — §A.1/§A.2: `476` `ana_viaggi.viaggio_incluso`/`viaggio_escluso`; `477` `fn_web_tour_pubblicati` espone incluso/escluso tradotti; `478` `ana_viaggi.viaggio_capienza_max`/`viaggio_capienza_alert` + trigger `trg_mov_clienti_viaggi_posti` (solo `pg_notify('web_tour_revalidate')`); `479` `fn_web_mezzi_occupati_data` (**SECURITY DEFINER**, `EXECUTE` a `anon`) + `fn_web_tour_pubblicati` espone `posti_rimasti`/`posti_stato`; `480` `ana_tipo_viaggi.tipo_viaggio_breve` (flag tour brevi) + `fn_web_ha_tour_brevi_pubblicati` (`EXECUTE` a `anon`) + `fn_web_tour_pubblicati` espone `is_tour_breve`; `481` `fn_web_recensioni_config` (**SECURITY DEFINER**, `EXECUTE` a `anon`): config recensioni Google/TripAdvisor dal JSONB `web_aziende_funzioni.parametri` (solo se `attiva`). Tutti idempotenti (`ADD COLUMN IF NOT EXISTS`, `CREATE OR REPLACE`). ⚠️ I `GRANT EXECUTE ... TO anon` su `fn_web_mezzi_occupati_data`, `fn_web_ha_tour_brevi_pubblicati` e `fn_web_recensioni_config` vanno verificati dopo l'hardening (§ RLS anon). Il canale `web_tour_revalidate` sarà consumato dal frontend Fase 3 (Next.js on-demand revalidation). `482` converte la CRUD di `ana_tipo_viaggi` in funzioni DB (`fn_ana_tipo_viaggi_create`/`update`), nessun impatto su `anon`. `483` aggiunge `fn_ana_aziende_smtp_secrets_get` (lettura password SMTP outbound/inbound decifrate via `pgp_sym_decrypt`; nessun impatto su `anon`). `484` è un **repair dati**: rimappa i `cliente_lingua` troncati a 1 carattere dal vecchio bug del cast `::char` ai codici ISO a 2 lettere (idempotente, solo valori di lunghezza 1; `'E'`→`'EN'` di default, ambiguo con `ES`) — richiede anche il deploy dell'app col fix del cast (vedi §2.5).

Comando (adattare host/credenziali PROD — NON usare il container Docker locale):

```bash
# ⛔️ Il grep -v esclude 499_Rollback_EstensioneWeb.sql: è un DROP COLUMN, non una migrazione.
#    Senza quel filtro il loop distrugge le colonne di ana_clienti/ana_viaggi/ana_aziende.
ls SqlScripts/*.sql \
  | grep -vi 'Rollback' \
  | sed -E 's#.*/([0-9]+)_#\1 &#' \
  | awk '$1>=406 && $1<=536 {print $2}' \
  | sort -n -t/ -k2 \
  | while read -r f; do
      echo "==> $f"
      psql "$PROD_CONN" -v ON_ERROR_STOP=1 -f "$f" || break
    done
```

> Verificare **a occhio** l'elenco stampato prima di lanciarlo davvero (sostituendo `psql …` con `echo`):
> gli script con ⚠️ nelle tabelle sotto vanno applicati **a mano, uno alla volta**, non dentro il loop.

### Elenco ordinato (406–466)

> Nota: questa tabella dettaglia i primi script; per `467`–`537` c'è la **seconda tabella** subito sotto. I riquadri qui sopra restano come approfondimento tematico (grant `anon`, `SECURITY DEFINER`, re-model Blocco 13), non come elenco di deploy.

| # | Script | Note |
|---|--------|------|
| 406 | Setup_RoleAnon | ⚠️ ruolo `anon` — vedi §2.1 (su Supabase esiste già) |
| 407 | Create_FnTrgWebAudit | trigger di audit tabelle web |
| 408 | Create_WebCategorieSport | ⚠️ poi rimodellata da 459 |
| 409 | Alter_AnaTipoViaggi_WebCategoria | |
| 410 | Create_WebTourContenuti | |
| 411 | Create_WebTourItinerario | |
| 412 | Create_WebTourItinerarioPassaggi | |
| 413 | Create_WebTourImmagini | Storage: vedi §2.4 |
| 414 | Create_WebTourMappa | Storage: vedi §2.4 |
| 415 | Create_WebTraduzioni | |
| 416 | Create_WebNewsletterIscritti | |
| 417 | Create_WebNewsletterInvii | |
| 418 | Create_WebNewsletterInviiDestinatari | |
| 419 | Create_WebNewsletterSoppressioni | |
| 420 | Create_WebAziendeFunzioni | |
| 421 | Create_AnaAziendeEsp | ⚠️ campi `_enc` FINTI (plaintext) — §2.2 |
| 422 | Create_WebPagamentiConfig | ⚠️ campi `_enc` FINTI (plaintext) — §2.2 |
| 423 | Create_WebPagamentiRegole | |
| 424 | Create_WebPagamentiReminderRegole | |
| 425 | Create_WebPagamentiTransazioni | |
| 426 | Create_WebPagamentiReminderLog | |
| 427 | Create_WebBlogArticoli | |
| 428 | Alter_AnaClienti_Web | |
| 429 | Alter_AnaAziende_Token | `token_iscrizione` per azienda — §2.3 |
| 430 | Fix_Web_LinguaCheck_FkOnDelete | |
| 431 | Create_FnWebCategorieSport_Crud | ⚠️ superata da 459/460 |
| 432 | Create_FnWebTourContenuti_Crud | |
| 433 | Create_FnWebTourItinerario_Crud | |
| 434 | Create_FnWebTourItinerarioPassaggi_Crud | |
| 435 | Create_FnWebTourImmagini_Crud | |
| 436 | Create_FnWebTourMappa_Crud | |
| 437 | Create_FnWebTraduzioni_Crud | |
| 438 | Create_FnWebNewsletterIscritti_Crud | |
| 439 | Create_FnWebNewsletterInvii_Crud | |
| 440 | Create_FnWebNewsletterInviiDestinatari_Crud | |
| 441 | Create_FnWebNewsletterSoppressioni_Crud | |
| 442 | Create_FnWebAziendeFunzioni_Crud | |
| 443 | Create_FnAnaAziendeEsp_Crud | |
| 444 | Create_FnWebServizio | |
| 450 | Rls_AnonRead_WebContenuti | ⚠️ RLS anon — §2.1 |
| 451 | Rls_AnonInsert_NewsletterIscritti | ⚠️ RLS anon — §2.1 |
| 452 | Rls_AnonRead_TourOperativiGated | ⚠️ RLS anon — §2.1 |
| 453 | Rls_Harden_AnonExecute | ⚠️ RLS anon — §2.1 |
| 454 | Create_FnWebTourItinerarioReorder | |
| 455 | Create_FnWebTourItinerarioPassaggiReorder | |
| 456 | Alter_UqWebTourItinerarioGiorno_Deferrable | constraint DEFERRABLE |
| 457 | Create_FnWebTourImmaginiReorder | |
| 458 | Create_FnWebTourImmaginiSetPrincipale | |
| 459 | Reshape_WebCategorieSport_To_TipiViaggioDescrizioni | ⚠️ **RESHAPE** tabella (rename + colonne) |
| 460 | Create_FnWebTipiViaggioDescrizioni_Crud | |
| 461 | Update_FnWebTourPubblicati_DescrizioneWeb | |
| 462 | Blocco10_Traduzioni_ClaudeKey_Upsert_Obsolete | ⚠️ chiave Claude `_enc` FINTA — §2.2 |
| 463 | Create_FnAnaAziendeClaudeKey | ⚠️ chiave Claude `_enc` FINTA — §2.2 |
| 464 | Create_FnWebTraduzioniMarcaObsoleteGlobal | |
| 465 | Blocco11_ClienteLingua_Destinatari | ⚠️ **BACKFILL DATI** su clienti reali — §2.5 |
| 466 | Create_FnAnaClientiLingua | |

### Elenco ordinato (467–619)

> **Il blocco `538`–`562` è rigiocabile** — verificato il 2026-08-21 **rigiocandolo per davvero**:
> copia del DB, sequenza applicata tre volte di fila, zero errori, e stato finale corretto
> (`fn_cf_verifica` con la gravità, riconoscimento di cognome/nome invertiti, avviso nome/sesso).
> Rilanciare l'intero blocco dopo un'interruzione a metà non fa danni, e non serve capire dove si
> era fermato.
>
> ⚠️ **Non lo era prima di quella prova.** Un controllo puramente testuale sugli script diceva che
> andasse tutto bene; rigiocarli ha mostrato che **`544` e `547` fallivano** con
> `cannot change return type of existing function`. Motivo: entrambi dichiarano `fn_cf_verifica`
> con `CREATE OR REPLACE`, ma il `548` ne cambia il tipo restituito aggiungendo la gravità — quindi
> su un database che aveva già visto il `548`, rilanciare dalla testa si fermava al `544` e tutto il
> resto non partiva. Corretto aggiungendo `DROP FUNCTION IF EXISTS` in entrambi, come il `548` già
> faceva.
>
> La lezione, per gli script futuri: **leggere lo script non basta a sapere se è rigiocabile.**
> Va rigiocato su una copia. Il difetto si vede solo alla seconda esecuzione.
>
> ⚠️ **`543` ha un ordine interno obbligatorio** (prima si sanano i valori non validi, poi si
> normalizza): i vincoli `NOT VALID` scattano su qualunque `UPDATE` della riga, quindi normalizzare
> per primo farebbe fallire la bonifica. Il motivo è scritto dentro lo script — non riordinarlo.



> ⛔️ **`499_Rollback_EstensioneWeb.sql` NON va MAI applicato in produzione.** Il numero `499` è usato
> da **due** file: quello da applicare è `499_FnWebTraduzioniApprovaContenuto.sql`. L'altro è il
> rollback completo dell'estensione (fa `DROP COLUMN` su `ana_clienti`, `ana_viaggi`, `ana_aziende`)
> ed esiste solo per ripulire l'ambiente locale. Un `for f in SqlScripts/*.sql` cieco distrugge i dati.

| # | Script | Note |
|---|--------|------|
| 467 | Blocco13_AnaViaggi_Difficolta | `ana_viaggi.viaggio_difficolta` + propagazione a create/update/get. Grant colonnare anon → §2.1 |
| 468 | Blocco13_Contenuti_Edizioni | **Re-model:** `web_tour_contenuti` diventa figlio di (viaggio + data_viaggio). Aggiunge FK + `NOT NULL` + UNIQUE su `data_viaggio_id_fk`. ⚠️ Presuppone la tabella **vuota** o migrabile: su PROD verificare prima che `web_tour_contenuti` non abbia righe senza edizione |
| 469 | Blocco13_WebTourImmagini_Contenuto | Ri-ancora `web_tour_immagini` dal viaggio al contenuto (FK → `web_tour_contenuti`, ON DELETE CASCADE) |
| 470 | Blocco13_WebTourItinerario_Contenuto | Idem per `web_tour_itinerario` |
| 471 | Blocco13_WebTourMappa_Contenuto | Idem per `web_tour_mappa`. Forward migration: il file dichiara la figlia **vuota** |
| 472 | Blocco13_Public_PerEdizione | `fn_web_tour_pubblicati` emette una riga per edizione; prezzo e date dalla singola partenza |
| 473 | Blocco13_Rls_PerContenuto | ⚠️ **RLS + GRANT colonnari anon** ricablati sul contenuto — §2.1 |
| 474 | Blocco13_FnClonaContenuto | Clonazione contenuto + figlie + traduzioni su una nuova edizione |
| 475 | Cifratura_Segreti_Pgcrypto | ⚠️ **SEGRETI** — pgcrypto reale. Richiede `GV_SECRET_KEY` impostata **prima**, e il re-inserimento dei segreti — §2.2 e §3.1 |
| 476 | AnaViaggi_InclusoEscluso | Campi HTML Incluso/Escluso sul viaggio. Grant colonnare anon → §2.1 |
| 477 | Public_InclusoEscluso | Espone Incluso/Escluso tradotti nello strato pubblico |
| 478 | AnaViaggi_Capienza_Trigger | Capienza max/alert + trigger `pg_notify` di revalidation. Grant colonnare anon → §2.1 |
| 479 | Public_PostiRimasti | `posti_rimasti` calcolato live in `fn_web_tour_pubblicati` |
| 480 | TipoViaggio_Breve | Flag "esperienza breve 1–3 gg" su `ana_tipo_viaggi` |
| 481 | Public_RecensioniConfig | Config recensioni Google/TripAdvisor nel JSONB `web_aziende_funzioni.parametri` |
| 482 | TipoViaggio_Crud_Functions | CRUD DB-first dei tipi viaggio (sostituisce SQL inline) |
| 483 | Smtp_Secrets_Get | Lettura password SMTP decifrate. **Dipende dal 475**: applicare dopo, e con `GV_SECRET_KEY` attiva |
| 484 | Fix_Cliente_Lingua_Troncata | ⚠️ **BACKFILL DATI** — ripara `cliente_lingua` troncata a 1 carattere dal vecchio bug del cast `::char`. Idempotente, agisce solo sui valori di lunghezza 1. Su PROD serve solo se il bug ha toccato i dati reali: verificare con `SELECT count(*) FROM ana_clienti WHERE length(btrim(cliente_lingua))=1` |
| 485 | ClienteLingua_AutoDeriva_NotNull | ⚠️ **BACKFILL + VINCOLO** — auto-deriva la lingua dalla nazione, riempie i NULL residui, poi mette `DEFAULT 'IT'` + `NOT NULL`. Va dopo il backfill del `465` — §2.5 |
| 486 | FnWebTourPubblicati_Meta | meta_title / meta_description con fallback DB-side (SEO) |
| 487 | WebTourImmagini_NomeFile | `nome_file` per il dedup upload. Colonna nullable, **nessun backfill** |
| 488 | WebImmaginiInUso | Impedisce di eliminare una foto usata in un passaggio d'itinerario (legame debole per `storage_path`) |
| 489 | SysUtentePreferenze | Tabella preferenze utente key-value (nessuna UI CRUD) |
| 490 | WebTipiViaggioDescrizioni_OrdineUnique | UNIQUE su `ordine`. Contiene già l'UPDATE che ri-numera i duplicati prima di creare il vincolo |
| 491 | WebTipiViaggioDescrizioni_Checks | ⚠️ **CHECK senza riparazione**: `length(btrim(descrizione_web)) >= 3` e `ordine >= 1`. Se una riga PROD viola, l'`ALTER` **fallisce**. Verificare prima: `SELECT * FROM web_tipi_viaggio_descrizioni WHERE length(btrim(descrizione_web))<3 OR ordine<1` |
| 492 | FnWebTourStatoSezioni | Semaforo di completamento dei sotto-tab dei contenuti web |
| 493 | WebTourMappa_Multiple | **Re-model:** da 1 mappa per edizione a N con abbinamento dichiarato. Rimuove lo UNIQUE sul contenuto, aggiunge giornata/descrizione/`gpx_bytes` + 4 vincoli + FK composita. ⚠️ Contiene un **backfill** delle mappe esistenti che deve girare *prima* dei vincoli: è nello script, ma su PROD verificarne l'esito |
| 494 | FnWebTourMappa_Crud_Multiple | CRUD di `web_tour_mappa` adeguata alle mappe multiple |
| 495 | FnWebTourStatoSezioni_Mappe | Le descrizioni delle mappe entrano fra i campi traducibili |
| 496 | FnWebTourVerifiche | Verifiche non bloccanti sui contenuti (dimenticanze, non incoerenze) |
| 497 | WebTourMappa_DescrizioneObbligatoria | Descrizione mappa `NOT NULL`. Contiene già l'UPDATE che riempie le righe esistenti prima del vincolo |
| 498 | FnWebTourStatoSezioni_Revisionate | Il semaforo distingue `n_tradotte` da `n_revisionate`: solo le revisionate rendono pubblicabile il tour. ⚠️ Fa `DROP FUNCTION` su `fn_web_tour_stato_sezioni` (cambia il tipo di ritorno) → applicare **in ordine** con il 499 |
| 499 | FnWebTraduzioniApprovaContenuto | Approvazione in blocco delle traduzioni + `fn_web_tour_campi_traducibili` come unica definizione dei campi traducibili. Stesso `DROP FUNCTION` del 498. **⛔️ Non confondere con `499_Rollback_EstensioneWeb.sql` — vedi avviso sopra** |
| 500 | WebAiConsumi | Registro consumi Claude + soglia di spesa per azienda |
| 501 | WebAiPrezziVerifica | Promemoria di verifica del listino Anthropic (i prezzi non sono esposti via API) |
| 502 | FnAnteprimaPartenzeTraduzioni | Prossime partenze e scelta lingua nell'anteprima |
| 503 | CampiTraducibili_TitoloGiornata | Il titolo della giornata entra fra i campi traducibili. ⚠️ **Su un DB con tour già tradotti** il denominatore del semaforo cresce di una voce per giornata: quei tour tornano **non pubblicabili** finché non si traducono anche i titoli. È voluto (prima finivano sul sito in italiano senza segnalazione), ma va comunicato |
| 504 | FnWebTourContenutiClona_Allineata | Allinea il clone a mappe multiple e nuovi campi tradotti. ⚠️ **Senza il 504 la clonazione di un contenuto con mappe FALLISCE**, perché il 497 ha reso obbligatoria la descrizione della mappa: applicarli entrambi |
| 505 | FnWebTourContenutiClona_DurataDiversa | Clonazione fra partenze di durata diversa |
| 506 | FnWebPubblicati_FiltroDate | Solo partenze con `data_inizio > CURRENT_DATE`. ⚠️ **Cambia ciò che il sito pubblico mostra**: schede pubblicate con partenza già iniziata spariranno dal sito al primo deploy. È l'effetto voluto, ma va comunicato prima |
| 507 | SpAnaDateViaggiDelete_Guardie | Si elimina solo una partenza che deve ancora iniziare, non effettuata, senza scheda web e senza prenotazioni. ⚠️ **Cambia il comportamento su dati PROD esistenti**: partenze storiche finora cancellabili non lo saranno più — è la protezione voluta |
| 508 | FnWebTourContenutiDelete_Pulizia | Pulisce anche `web_traduzioni`, polimorfica (`entita`+`entita_id`) e non raggiunta da alcuna CASCADE (verificato: 96 righe orfane su una scheda clonata). Nessuna bonifica retroattiva: su PROD non possono esistere orfani, perché finora non c'era alcun percorso di eliminazione |
| 509 | AnaDateViaggi_AnnoPlausibile | ⚠️ **CHECK su dati esistenti**: anni fra 2000 e 2100. In locale 146 righe tutte valide; **su PROD eseguire prima la query di verifica in coda allo script** (deve dare zero righe), altrimenti l'`ALTER` fallisce |
| 510 | Create_FnAnaClientiConsenso | get/set del consenso marketing del cliente (Blocco 11-B). Nessun backfill: le colonne esistono dal `428`, cambia solo chi le scrive |
| 511 | FnWebDestinatariNewsletter_Telefono | `fn_web_destinatari_newsletter` espone anche `telefono` (in coda al `RETURNS TABLE`). Fa `DROP FUNCTION` prima del `CREATE` perché cambia il tipo di ritorno → applicarlo **dopo** il `465`. Nessun grant da ripristinare: **verificato che la function non è concessa ad `anon`** (`proacl` vuoto) e non deve esserlo — restituisce email e telefoni di tutti i clienti |
| 512 | Newsletter_Blocchi_Bozze | Newsletter a blocchi Fase 1: tabella `web_newsletter_blocchi` + CRUD/reorder/clona/bozze. ⚠️ Fa `ALTER TABLE web_newsletter_invii ALTER COLUMN corpo_html DROP NOT NULL` e aggiunge `is_modello`: su PROD nessun dato esistente da migrare (la newsletter non è mai stata usata in produzione) |
| 513 | FnWebNewsletterDatiAzienda | Dati aziendali (ragione sociale, P.IVA, indirizzo dalla sede principale, email, telefono, sito) per intestazione e footer della newsletter. Sola lettura, nessun impatto sui dati |
| 514 | FnWebNewsletterDatiTour | Contenuto di un riquadro tour da un'edizione (titolo, periodo, testo, slug, copertina) per la compilazione automatica del blocco. Sola lettura |
| 515 | FnWebImmaginiAzienda | Tutte le immagini della galleria di un'azienda (con nome viaggio come contesto) per il picker della newsletter. Sola lettura |
| 516 | NewsletterBlocchi_LayoutCentro | `layout` dei blocchi ammette anche `centro` (su testo/pulsante la proprietà significa allineamento). Nessuna migrazione dati |
| 517 | WebIndirizzi | Nuova tabella `web_indirizzi` (rubrica URL per-azienda) + CRUD. ⚠️ **Dato da inserire in PROD**: almeno la home del sito, altrimenti i pulsanti della newsletter non hanno destinazioni fra cui scegliere |
| 518 | NewsletterBlocchi_IndirizzoFk | `web_newsletter_blocchi.indirizzo_id_fk` → `web_indirizzi` (ON DELETE SET NULL) + congelamento all'invio. Nessuna migrazione: colonna nuova, i blocchi esistenti restano con l'URL copiato |
| 519 | WebIndirizzi_Social | `social` + `icona_url` su `web_indirizzi` e sui blocchi. Colonne nuove, nessuna migrazione |
| 520 | NewsletterBlocchi_Social | CRUD blocchi e clonazione trasportano social e icona |
| 521 | CongelaIndirizzi_Social | Il congelamento all'invio fissa anche social e icona, non solo l'URL |
| 522 | NewsletterBlocco_Info | Nuovo tipo di blocco `info` (icona + testo): CHECK esteso e catalogo tipi aggiornato. Nessuna migrazione |
| 523 | WebImmaginiLibreria | Nuova tabella `web_immagini_libreria` (icone e immagini generiche per-azienda) + CRUD + guardia d'uso. ⚠️ **Contenuto da riportare in PROD** come per `web_indirizzi`: la tabella nasce vuota e **i file vivono su Storage** sotto `libreria/{azienda}/` — vanno copiati nel bucket di produzione e gli URL riscritti, altrimenti le newsletter mostrerebbero immagini rotte |
| 524 | Pulizia_Firme_Obsolete | ⚠️ **Da applicare DOPO tutti gli altri.** `CREATE OR REPLACE` non sostituisce una function se cambia il numero di parametri: gli script `512→518→520` e `517→519` lasciano dietro **sette firme superate**, che rendono ambigua ogni chiamata che non elenchi tutti i parametri (`function is not unique`). Lo script le rimuove e verifica che ne resti una sola per nome |
| 525 | NewsletterBlocchi_LayoutPulsante | Aggiunge `web_newsletter_blocchi.layout_pulsante` (posizione del pulsante indipendente da quella dell'immagine; NULL = segue il blocco). **Ordine sicuro dopo il 524**: lo script fa da sé il `DROP` delle due firme che sostituisce (insert a 18 e update a 16 parametri) invece di lasciarle accumulare, quindi non riapre il problema che il 524 ha chiuso |
| 526 | NewsletterBlocchi_ColoriTesto | Aggiunge `colore_titolo` e `colore_sottotitolo` su `web_newsletter_blocchi` (NULL = colore predefinito, i blocchi esistenti non cambiano aspetto). Come il 525 fa da sé il `DROP` delle firme che sostituisce, e **si interrompe da solo** se ne trova più di una per nome |
| 527 | Newsletter_CollegamentiTour_Integrita | Due guardie sui collegamenti ai tour: `fn_web_tour_contenuti_delete` rifiuta se una newsletter **in bozza** punta a quella partenza (le inviate non fermano niente, sono congelate); nuova `fn_web_newsletter_collegamenti_da_verificare` usata prima di spedire. Solo function: nessuna modifica a tabelle |
| 528 | EbaCountries_NomiItaliani | Aggiunge `eba_countries.name_it` e traduce tutte e **249** le nazioni. Chiave della traduzione: `iso_alpha2`, non il nome — l'import Oracle ha rovinato le accentate (`CÙTE D'IVOIRE`, `CURAÁAO`) e un JOIN sul nome fallirebbe proprio lì. ⚠️ **Lo script si interrompe se in PROD esiste una nazione non coperta**: è voluto, meglio un errore che una voce vuota nella tendina. In quel caso aggiungere la riga mancante allo script e rilanciare |
| 529 | Newsletter_InviiSelettivi | Nuova `web_newsletter_filtri` + `includi_iscritti_web` su `web_newsletter_invii`. ⚠️ **`fn_web_destinatari_newsletter` cambia firma** (secondo parametro opzionale `p_invio_id`): lo script fa il `DROP` della versione a un parametro prima di ricrearla, altrimenti le chiamate a un argomento diventano ambigue. Richiede `eba_countries` e le tabelle geografiche (vedi sezione dedicata) |
| 530 | Albero_Partenze_Iscritti_Etichetta | `get_viaggi_grouped_by_year` restituisce anche il numero di **iscritti** — cambia il tipo del risultato, quindi la function viene rimossa e ricreata (`CREATE OR REPLACE` non può cambiare la firma del risultato). Nuova `fn_partenza_etichetta`, usata sia a video sia dalle descrizioni dei criteri newsletter |
| 531 | Newsletter_Traduzioni | Traduzione per campo dei blocchi. **Nessuna tabella nuova**: usa `web_traduzioni` con le entità `web_newsletter_blocchi` e `web_newsletter_invii`. Ricrea `fn_web_newsletter_blocchi_update` (**stessa firma**) aggiungendo l'obsolescenza automatica delle traduzioni sul campo modificato |
| 532 | Newsletter_Archivio_Lingue_Clonazione | Nuova `web_newsletter_invii_corpi`: conserva **cosa è stato spedito, per lingua**. `fn_web_newsletter_clona` riscritta a ciclo (un blocco alla volta) per poter portare con sé le traduzioni: un `INSERT ... SELECT` non restituisce la corrispondenza vecchio→nuovo id |
| 533 | Newsletter_Tour_Periodi_Traduzioni | Il riquadro tour nelle altre lingue: `fn_web_newsletter_periodi` (date per rigenerare il periodo) e `fn_web_newsletter_blocco_eredita_traduzioni`, richiamata da un **trigger** su `web_newsletter_blocchi`. Il trigger va verificato dopo il deploy: `\\d web_newsletter_blocchi` deve elencare `trg_web_newsletter_blocchi_eredita` |
| 534 | Eredita_Traduzioni_Formattazione | L'ereditarietà confronta il **testo** e non il markup (`fn_solo_testo`), così un grassetto non la rompe, e inserisce la traduzione dentro la formattazione esistente |
| 535 | Traduzioni_Newsletter_Pulizia | Trigger `AFTER DELETE` su blocchi e invii: le traduzioni seguono ciò che viene eliminato. `web_traduzioni` è polimorfica e non può avere una chiave esterna, quindi senza trigger le righe restavano orfane. **Include la pulizia delle orfane già presenti** — su PROD saranno altre, la condizione le trova comunque |
| 536 | Obsolescenza_Prima_Della_Update | In `fn_web_newsletter_blocchi_update` l'obsolescenza delle traduzioni passa **prima** della `UPDATE`: dopo, marcava obsolete proprio le traduzioni che il trigger di ereditarietà aveva appena scritto. Include il ripristino dei blocchi già salvati con l'ordine sbagliato |
| 537 | Obsolescenza_Oggetto_Newsletter | Stessa regola del `536`, applicata all'**oggetto** della newsletter: `fn_web_newsletter_invii_update` marca obsolete le traduzioni dell'oggetto **prima** di riscriverlo. Senza, l'oggetto cambiato lasciava valide le traduzioni del testo precedente e i destinatari stranieri ricevevano l'oggetto **vecchio** tradotto mentre gli italiani ricevevano quello nuovo, in silenzio. `CREATE OR REPLACE` a firma invariata, nessun dato toccato: idempotente |

| 538 | Create_AnaTitoloPersone | **Re-model anagrafica clienti.** Nuova lookup GLOBALE `ana_titolo_persone` (codice, descrizione, sesso) + `ana_clienti.cliente_titolo_fk` **NOT NULL** + migrazione dei clienti esistenti + trigger che deriva `cliente_sesso` dal titolo. ⚠️ **Prova a secco già fatta su PROD il 2026-08-19** — vedi §2.7 |
| 539 | TitoloPersone_Compatibilita | Ponte per chi scrive ancora il titolo come testo (**sito di iscrizione**, `sp_ana_clienti_*`, wizard): il trigger ricava la FK dal testo e tiene `cliente_titolo` come specchio. Senza questo, ogni iscrizione dal sito fallirebbe subito |
| 544 | CodiceFiscale_Motore | **Motore del codice fiscale in PL/pgSQL**: calcolo, verifica (forma, carattere di controllo, corrispondenza con l'anagrafica, omocodia), lettura inversa. Sostituisce le implementazioni duplicate in C# e Python. ✅ **Gia' applicato su PROD il 2026-08-20**: puramente additivo, nessuno lo chiama ancora |
| 545 | AnaClienti_Bonifica_Da_CodiceFiscale | **Repair dati guidato dal codice fiscale**, idempotente: nome/cognome invertiti, data e comune di nascita allineati a cio' che il codice dichiara. Ogni regola si applica **solo se rende il codice corretto**. ✅ **Gia' eseguito su PROD il 2026-08-20** (11 righe) e in locale (9) |
| 548 | Verifiche_Gravita | Le verifiche restituiscono la **gravità** (`OK`/`AVVISO`/`CONFERMA`/`ERRORE`), non solo valido sì/no: la politica «questo blocca, quello chiede conferma» sta nel DB e vale per entrambi i client. ⚠️ Fa `DROP FUNCTION` su `fn_cf_verifica` perché ne cambia il tipo restituito. ✅ Applicato su PROD il 2026-08-20 |
| 551 | MovClientiViaggi_CRUD | **Fase 4**: iscrizione al viaggio con la regola dell'**email obbligatoria per i piloti** (dipende dal ruolo, e il ruolo sta sull'iscrizione). La segnalazione porta il `cliente_id` per aprire il popup sulla persona giusta. ✅ Applicato su PROD |
| 554 | VerificaDuplicato_Email | L'email ripetuta entra fra i riscontri come **AVVISO** (non era implementata, e intanto il dialog la trattava come un divieto) |
| 555 | CodiceFiscale_Verifica_Cliente | `fn_cf_verifica_cliente(cf, cliente_id)`: verifica partendo da un cliente a database. Sostituisce ~70 righe di orchestrazione Python nel sito |
| 557 | Wizard_Leggi_Cliente_TitoloFk | `fn_wizard_leggi_dati_cliente` restituisce anche **la chiave del titolo** e **il consenso**: senza, il sito non ritrovava il titolo di un cliente esistente e ne avrebbe spento il consenso al primo salvataggio |
| 558 | Letture_Clienti_Complete | Le funzioni di lettura dei clienti (`fn_get_all_clienti`, `fn_get_cliente_by_id`, `fn_search_clienti`) **esistevano dal 2026-03-16 e nessuno le chiamava**. Completate con `TitoloFk`, `Lingua`, `Consenso` e i comuni annidati, cosi' il repository puo' finalmente usarle. Additivo: aggiunge chiavi al JSON, non ne toglie |
| 559 | Letture_Clienti_Residue | Le ultime quattro letture inline scendono nel DB: cliente per email, per codice fiscale, e le due guardie alla cancellazione (iscrizioni / alloggi). Le prime due **delegano** a `fn_get_cliente_by_id` invece di riscrivere la SELECT, e ordinano per `cliente_id` — l'email non e' univoca e prima quale scheda tornasse era arbitrario |
| 560 | Cliente_Detail_Unificato | `fn_get_cliente_detail` sostituisce la vecchia `get_cliente_detail` (TABLE a 41 colonne, ferma al titolo testuale). Con la 558-559, `ClienteRepository.cs` non contiene **piu' una sola SELECT** |
| 561 | Nome_Sesso_Avviso | L'avviso nome/sesso scende nel DB: `fn_nome_sesso_avviso` + tabella **GLOBALE** `ana_nomi_maschili_in_a` (17 nomi). Prima esisteva solo in C#, quindi il sito non ce l'aveva |
| 562 | Valida_Include_NomeSesso | L'avviso entra in `fn_ana_clienti_valida`, la porta comune ai due software: da qui lo ricevono sia il gestionale sia il sito, senza scriverlo due volte |
| 556 | AnaClienti_Insert_Titolo_Testuale | Ponte: il CRUD accetta anche il titolo come **testo** + sesso, perché il sito non conosce ancora la lookup. Si toglie quando il sito passa alla chiave (§2.8.3). ⚠️ **Non applicabile a PROD finché non c'è il `539`** |
| 553 | MovClientiViaggi_MezzoObbligatorio | I **dati del mezzo** (marca, modello, targa) diventano obbligatori quando `tipo_partecipante_dati_mezzo_obb` lo richiede: la colonna esisteva da sempre e non la leggeva nessuno. Allinea anche `ana_tipo_partecipante` fra i due ambienti (su PROD e' un no-op: il committente l'aveva gia' corretta). ✅ Applicato su PROD |
| 552 | AnaClienti_Valida_Formati | La validazione anticipa i formati con messaggi leggibili: senza, l'errore arriva dal vincolo e **riversa nel log l'intera riga**, dati personali compresi. ✅ Applicato su PROD |
| 550 | AnaClienti_CRUD | **Fase 3**: il CRUD unico (`valida`/`insert`/`update`/`delete`), dati in JSONB con i nomi delle colonne. Assorbe consenso e lingua. Sostituira' `ClienteRepository` (SQL inline), `sp_ana_clienti_*` e `fn_wizard_insert_cliente`/`_update`. ✅ Applicato su PROD il 2026-08-20 (additivo) |
| 549 | AnaClienti_Verifica_Duplicato | **Fase 2**: anti-omonimia a tre livelli (stesso CF · stessa anagrafica completa · stesso nome e cognome). Nessun livello richiede il CF per funzionare. ✅ Applicato su PROD il 2026-08-20 (additivo, nessuno lo chiama ancora) |
| 547 | CodiceFiscale_Riconosce_Invertiti | `fn_cf_verifica` riconosce **nome e cognome scambiati fra loro** e lo dice, invece di limitarsi a «non corrisponde». Sostituisce la versione del `544`. ✅ **Gia' applicato su PROD il 2026-08-20** (additivo, nessuno la chiama ancora) |
| 546 | AnaGeoComuni_Estero_Coerente | Il flag `comune_estero` allineato alla provincia. ✅ **Gia' eseguito** su PROD e in locale (1 riga: BOMBAY). Verificato dopo: **zero comuni italiani senza codice catastale** in entrambi gli ambienti |
| 543 | AnaClienti_Bonifica_Dati | **Repair dati, idempotente.** Codici fiscali malformati e indirizzi spazzatura → NULL, stringhe vuote → NULL, spazi in testa/coda via. ✅ **Gia' eseguito su PROD il 2026-08-20**: su un DB gia' bonificato e' un no-op (verificato, 12 × `UPDATE 0`). ⚠️ **L'ordine dei passi e' obbligatorio** — prima si sanano i valori non validi, poi si normalizza: i vincoli `NOT VALID` di `542` scattano su qualsiasi update della riga, anche su un semplice `btrim`. ⚠️ `cliente_preftelint` **non** viene toccato: i 447 spazi in coda sono formattazione voluta (`+39 ` + numero), toglierli peggiorerebbe 435 telefoni |
| 542 | AnaClienti_Vincoli_Gruppo2 | Tre `CHECK`: caratteri del telefono (validato — la regola e' stata allargata a `.` e `/`, che sono separatori veri), lunghezza del codice fiscale e minimo dell'indirizzo, questi due **`NOT VALID`**. ⚠️ `NOT VALID` non e' piu' debole su insert e update: semplicemente non boccia lo storico. Su PROD restano 4 CF e 8 indirizzi non conformi — riaprendo e salvando una di quelle schede il vincolo scatta e il dato va sistemato |
| 541 | AnaClienti_Vincoli_Invarianti | Sei `CHECK` su `ana_clienti`: formato email, minimi su nome e cognome, coerenza fra le date del documento, forma dell'IBAN. **Zero violazioni misurate su PROD il 2026-08-20**, quindi nessuna bonifica. Primo passo della centralizzazione: valgono anche per il sito di iscrizione |
| 540 | TitoloPersone_Ordinamento_e_Uso | `SIG.`/`SIG.RA` in testa alla tendina + `fn_ana_titolo_persone_conta_clienti`. Nessun impatto sui dati |
| 563 | Campi_Obbligatori_Anagrafica | ⚠️ **Il piu' impattante dei sei.** `fn_ana_clienti_campi_mancanti` definisce una volta sola cosa deve esserci in un'anagrafica; `fn_ana_clienti_valida` lo pretende al salvataggio (un errore **per campo**) e `fn_mov_clienti_viaggi_valida` **all'iscrizione**, bloccandola. Obbligatori per tutti: titolo, cognome, nome, data e comune di nascita, comune e indirizzo di residenza, e i **cinque del documento**. Solo per il pilota: prefisso e telefono. **Vedi §2.9: su PROD questo script cambia il lavoro quotidiano dal primo giorno** |
| 564 | CF_Non_Corrisponde_Errore | Il codice fiscale in disaccordo con i dati anagrafici passa da `CONFERMA` a **`ERRORE`**: quella domanda si risponde «si'» per stanchezza, e nasce una scheda in cui codice e dati si contraddicono senza sapere piu' quale dei due fosse buono |
| 565 | CF_Invertiti_Errore | Anche i **nomi invertiti** diventano `ERRORE`. Da qui `fn_cf_verifica` non emette piu' alcun `CONFERMA`: o il codice torna con l'anagrafica, o non si salva. Il messaggio dice quale lettura fa tornare il codice, quindi indica gia' la correzione |
| 566 | Duplicati_Senza_Nome | I messaggi su codice fiscale ed email duplicati **non nominano piu'** il cliente che li possiede: bastava provare codici a caso per farsi dire chi c'e' in anagrafica. Al suo posto, come ritrovare quella scheda |
| 567 | Duplicati_Nessun_Nome | La regola diventa netta: **nessuna segnalazione sui duplicati fa nomi**, nemmeno quelle in cui il nome era gia' sullo schermo |
| 568 | Consenso_Vuole_Email | Il consenso alla newsletter senza indirizzo e' rifiutato. Nasce per il gestionale, ma **serve soprattutto al sito**, dove il consenso e' ancora da aggiungere (§2.8.1): quando lo si fara', la regola ci sara' gia' |
| 569 | Duplicato_Messaggio_Neutro | Il messaggio sul codice fiscale gia' presente diventa neutro: dice cosa succede, non di chi e' la scheda |
| 570 | Viaggi_Ricerca_Nel_Database | La ricerca dell'elenco viaggi scende nel DB: **un parametro in piu'** su `fn_ana_viaggi_get_all`, non una seconda funzione. ⚠️ Richiede `DROP FUNCTION` esplicito: con un parametro aggiunto, `CREATE OR REPLACE` crea un **overload** e la chiamata diventa ambigua |
| 571 | Controparti_Lettura_Nel_Database | `fn_ana_controparti_get_all`: lettura + ricerca. Toglie dal C# una query che concatenava il filtro azienda in una **stringa** — l'invariante dei silos diventa un parametro |
| 572 | Aziende_Lettura_Nel_Database | `fn_ana_aziende_get_all`: stesso difetto, secondo e ultimo punto dove il confine fra silos era concatenato |
| 573 | Clienti_Ricerca_Nella_Lettura | La ricerca clienti diventa **un parametro di `fn_get_all_clienti`**. Chiude un difetto grave: `fn_search_clienti` restituiva **16 campi in meno**, e chi apriva un cliente trovato cercando rischiava di azzerarli salvando |
| 574 | Documenti_Validi_Per_La_Partenza | Primo impianto del controllo sui documenti di chi parte |
| 575 | Documento_Valido_Regola_Unica | La regola in un posto solo: `fn_documento_stato_per_viaggio` (MANCANTE / SCADUTO / SCADE_DURANTE / VALIDO), chiamata dalla lista partecipanti, dalle stampe **e** dall'iscrizione |
| 576 | Iscrizione_Controlla_Documento | All'iscrizione la gravita' dipende dalla destinazione: **ERRORE all'estero** (senza documento valido non si parte), AVVISO in Italia (l'albergo puo' rifiutare la registrazione) |
| 577 | Marche_Filtrate_Per_Tipo_Mezzo | `fn_ana_mezzi_marche_per_tipo`: le marche che hanno almeno un modello di quel tipo. Il tipo sta sul **modello**, non sulla marca. Nessuna modifica di schema |
| 578 | Partenza_Conclusa_Niente_Iscrizioni | ⚠️ `fn_partenza_conclusa` + rifiuto `PARTENZA_CONCLUSA` in `fn_mov_clienti_viaggi_valida`. **Vale anche per il sito Flask**, che passa dalla stessa funzione. Blocca solo l'INSERIMENTO: modificare un'iscrizione su un viaggio passato resta possibile. **Misurato su PROD il 2026-09-03** (sola lettura): 145 partenze concluse con **1.184 iscrizioni**, 5 partenze aperte con 19. Le 1.184 **non vengono toccate**: la funzione impedisce le nuove, non invalida le esistenti |
| 579 | Pilota_Senza_Recapito | `fn_partecipanti_documento_non_valido` allargata: segnala anche il **pilota senza email ne' telefono** (stato `SENZA_RECAPITO`). Solo chi guida — per un passeggero il recapito puo' mancare di proposito. ✅ **Misurato su PROD il 2026-09-03** (sola lettura): sulle 5 partenze ancora aperte, **zero** piloti senza recapito. Lo script non fara' emergere nulla il primo giorno — a differenza del `563` |
| 580 | Prefissi_Telefonici_Internazionali | ⚠️ **Crea una tabella e tocca i dati.** `ana_tel_pref_int` con i 249 prefissi ITU-E.164 (uno per paese, FK a `eba_countries`) + `fn_ana_tel_pref_int_get_all`. Sostituisce il campo di testo libero del gestionale e la lista di dieci voci scritta in Python nel sito. **Contiene un UPDATE sui clienti**: toglie gli spazi da `cliente_preftelint` — in locale ha toccato 443 righe, su PROD il numero sara' diverso ma l'effetto e' lo stesso (`+39 ` e `+39` tornano un valore solo). Da verificare dopo l'esecuzione: `SELECT DISTINCT cliente_preftelint FROM ana_clienti` non deve piu' contenere varianti con spazi |
| 581 | Consenso_Registra_Anche_Il_Rifiuto | Due colonne su `ana_clienti` (`consenso_marketing_chiesto_data`/`_fonte`) + `fn_consenso_da_chiedere` e `fn_consenso_registra_risposta`. Servono a chiedere il consenso newsletter durante l'iscrizione **senza richiederlo a chi ha gia' rifiutato**: oggi `consenso_marketing = FALSE` significa sia «mai chiesto» sia «ha detto no». Solo DDL e funzioni, nessun dato modificato |
| 582 | Documento_Esito_Chiedibile_Prima | `fn_documento_esito_per_partenza`: la severita' del documento (ERRORE all'estero, AVVISO in Italia) estratta da `fn_mov_clienti_viaggi_valida`, che ora la chiama. Serve al sito per fermare PRIMA chi non potrebbe partire, invece di rifiutarlo alla conferma finale |
| 583 | Sito_Mostra_Solo_Partenze_Aperte | `fn_wizard_get_viaggi_disponibili` usa `fn_partenza_conclusa` invece di un criterio suo. Il filtro precedente confrontava con `'S'`, un valore che il CHECK sulla colonna non ammette: non escludeva nulla. Solo funzione, nessun dato toccato |
| 584 | Partenza_Iscrivibile_Regole_Nette | `fn_partenza_iscrivibile` + trigger che vieta di marcare effettuata una partenza non ancora iniziata + vincolo ristretto a `Y`/`N`. **Misurato su PROD il 2026-09-04**: zero righe violano i nuovi vincoli |
| 585 | Tipo_Documento_Una_Tabella_Sola | ⚠️ **Tocca i dati.** Crea `ana_tipo_documento` e **normalizza i codici**: su PROD sono cinque (`CID` 144, `CI` 38, `PAT` 17, `PAS` 7, `PASSAPORTO` 1) e diventano tre. L'`UPDATE` riguarda ~145 righe — cambia la scrittura, non il documento. Verifica dopo: `SELECT DISTINCT cliente_tipodoc_identita FROM ana_clienti` deve dare solo `CI`, `PAS`, `PAT` e il vuoto |
| 586 | Cancellazione_Si_Porta_Dietro_Cio_Che_Dipende | ⚠️ **Tocca i dati.** Cancellare un partecipante ora si porta dietro i passeggeri del pilota e libera i posti letto (`fn_mov_clienti_viaggi_cancellazione_effetti`, `fn_mov_clienti_alloggi_togli_cliente`). Lo script **ripulisce anche i dati già sporchi**: chi occupa un letto su una partenza a cui non risulta iscritto. Su PROD 1 caso in azienda 2 e 5 in azienda 6 — vedi §1.5. **Le iscrizioni non vengono toccate** |
| 587 | Silos_Rimappare_I_Clienti_Fuori_Azienda | Le funzioni del riallineamento (`fn_cliente_gemello_in_azienda`, `fn_silos_movimenti_fuori_azienda`, `fn_silos_rimappa_movimenti`) + il rimappaggio dove il gemello esiste già. Vedi §1.6 — **l'ordine 587→588→589 non è negoziabile** |
| 588 | Silos_Creare_Le_Anagrafiche_Mancanti | ⚠️ **Crea 24 anagrafiche nuove in azienda 2**, copiate dall'azienda 6, e rimappa i movimenti. Riconoscibili da `created_by = 'migrazione_silos'`. **Il consenso al marketing NON viene copiato**: è stato dato a un'altra azienda |
| 589 | Silos_Il_Confine_Viene_Imposto | Trigger `trg_silo_azienda` su `mov_clienti_viaggi` e `mov_clienti_alloggi`: rifiuta i movimenti in cui il cliente appartiene a un'azienda diversa da quella del viaggio. ⚠️ **Va DOPO 587 e 588**: prima, le righe esistenti lo violerebbero e ogni loro modifica fallirebbe |
| 590 | Consenso_Solo_Sui_Clienti_Della_Propria_Azienda | ⚠️ **Sostituisce le firme** di `fn_consenso_da_chiedere` e `fn_consenso_registra_risposta` (DROP + CREATE): vogliono l'azienda. **Va applicato insieme al codice Flask** che passa il nuovo parametro, altrimenti il popup del consenso smette di funzionare. Vedi §1.7 |
| 591 | Consenso_Revocato_E_Una_Risposta | `fn_consenso_da_chiedere` riconosce anche la **revoca** come risposta: chi ha concesso e poi disdetto non viene più interpellato. Solo funzione, nessun dato toccato |
| 592 | Codice_Fiscale_Unico_Per_Azienda | Indice unico su (azienda, codice fiscale) per le schede che ne hanno uno. ⚠️ **Per azienda e non globale**: la stessa persona vive legittimamente in due anagrafiche, e lo script 588 ne crea 24 così. **Va quindi DOPO il 588**. Misurato su PROD: nessuna violazione, in nessuna azienda |
| 593 | Agganciare_L_Email_A_Chi_Non_Ce_L_Ha | `fn_ana_clienti_aggancia_email`: completa con un'email la scheda di chi ne è privo, e **solo** in quel caso. Serve agli 8 clienti dell'azienda 2 senza indirizzo, che altrimenti dal sito non potrebbero iscriversi. Non sovrascrive mai un recapito esistente |
| 594 | Nascita_Si_Cambia_Solo_Col_Codice_Fiscale | `fn_ana_clienti_nascita_modificata` + rilievo `CONFERMA / NASCITA_SENZA_CF` in `fn_ana_clienti_valida`. Data e comune di nascita si cambiano insieme al codice fiscale, che li conferma, oppure la modifica va dichiarata. ⚠️ **Riempire un campo vuoto non conta**: completare una scheda resta libero |
| 595 | Rileggere_Una_Controparte_Sola | `fn_ana_controparti_get_by_id`. Solo lettura: serve al gestionale per riaprire una scheda com'è adesso e non com'era al caricamento dell'elenco |
| 596 | Rileggere_Una_Partenza_Sola | `fn_ana_date_viaggi_get_by_id`, riga intera. Solo lettura, stessa ragione del 595. ⚠️ Riga intera e non il DTO di riepilogo: quello ha sei campi su diciannove |
| 597 | Ana_Tipo_Alloggio_Allineata_A_Produzione | Porta il catalogo degli alloggi **intero**, con le chiavi di produzione. ⚠️ **Su PROD non cambia nulla**: è da lì che i valori sono stati letti, ed è l'ambiente di sviluppo che si era disallineato (13 tipi contro 15, mancavano le tende di proprietà). Va applicato lo stesso, così i due restano uguali se un domani è PROD a cambiare. ⚠️ Spegne `ana_tipo_alloggio_trg1` per la durata dell'inserimento — vedi 598 — e rimette la sequenza dopo l'ultima chiave |
| 598 | Trigger_Delle_Chiavi_Tutti_Prudenti | ⚠️ **Corregge quattro trigger che sovrascrivevano la chiave a ogni inserimento**, rendendo inutile ogni `ON CONFLICT`: `ana_tipo_alloggio`, `ana_geo_capoluogo`, `ana_geo_ita_ripgeo`, `ana_geo_regioni_ita`. Al posto di un aggiornamento arrivava un duplicato, **in silenzio**. Ora assegnano la chiave solo se chi scrive non l'ha data (`NULL` o zero). Nessun dato modificato, solo quattro funzioni. **Va DOPO il 597**, che si appoggia ancora al comportamento vecchio spegnendo il trigger |
| 599 | Generi_Di_Alloggio_E_Coerenza_Col_Viaggio | ⚠️ **Tabelle nuove e colonna nuova.** `ana_alloggio_generi` (ALBERGO · TENDA · NESSUNA, estensibile), `ana_tipo_alloggio.genere_fk` **NOT NULL**, e `ana_tipo_pernottamento_generi` (molti a molti). Il genere dei 15 tipi e le associazioni dei 4 pernottamenti vengono dedotti **una volta sola** dai dati esistenti: da lì in poi sono un dato, non una parola da interpretare. ⚠️ Va **dopo il 597**, che allinea il catalogo: su un catalogo diverso il genere finirebbe sulle righe sbagliate |
| 600 | Alloggi_Tipi_Ammessi_E_Combinazioni | Le tre funzioni che sito e gestionale chiamano **entrambi**: `fn_alloggi_tipi_ammessi` (cosa si può assegnare su questa partenza), `fn_alloggi_combinazioni` (in che forme dividere N persone, e se serve chiedere chi sta con chi), `fn_alloggi_assegnazione_valida` (tipi ammessi, capienza, nessuno ripetuto, nessuno dimenticato). Nessun dato modificato. ⚠️ Va **dopo il 599** |
| 601 | Crud_Generi_E_Tipi_Alloggio | Le letture e scritture che servono alle pagine del gestionale: generi (elenco, salvataggio, cancellazione con guardia se sono usati), tipi di alloggio col genere, e i generi ammessi da un pernottamento. ⚠️ **`ana_tipo_pernottamento_con_albergo` non è più una scelta ma una conseguenza**: `fn_ana_tipo_pernottamento_generi_set` lo riallinea da solo in base ai generi. Il sito lo usa ancora per saltare il passo 5, quindi non si può togliere oggi — ma tenerlo come dato indipendente significherebbe due fonti che si contraddicono. ⚠️ Va **dopo il 599** |
| 602 | Sistemazione_Coerente_Col_Viaggio | Trigger `trg_alloggio_coerente` su `mov_clienti_alloggi`: rifiuta una sistemazione di un genere che il viaggio non prevede — una tenda su un viaggio in albergo, una camera su uno in campo tendato. ⚠️ **Non controlla la capienza**, di proposito: una doppia con un occupante solo è reale quando l'albergo non ha singole (parola di Antonio, 2026-09-06), e una regola rigida spingerebbe chi lavora ad annotarla fuori dal sistema. ⚠️ **Su PROD ci sono 17 righe che lo violano, tutte nell'azienda 6**: SFT ne ha zero. Restano come sono — il trigger guarda solo inserimenti e modifiche — ma toccarne una la farà rifiutare. ⚠️ Va **dopo il 599** |
| 603 | Descrizioni_Sempre_Maiuscole | Porta in maiuscolo le descrizioni di generi e tipi di alloggio, e sposta la regola **dentro le funzioni di scrittura**. ⚠️ Prima il maiuscolo lo faceva solo la scheda del gestionale, con un `ToUpper` al momento della digitazione: le righe scritte da uno script comparivano minuscole in elenco e maiuscole aprendole. Su PROD tocca poche righe — le tre dei generi arrivano già corrette dal 599 aggiornato |
| 604 | Genere_Non_Si_Cambia_Se_Rende_Incoerente | ⚠️ Rifiuta il cambio di genere di un tipo di sistemazione quando renderebbe **incoerenti assegnazioni già registrate**, dicendo quante e su quali viaggi. Misurato: cambiare CAMERA MATRIMONIALE da ALBERGO a TENDA invaliderebbe **219 assegnazioni** in silenzio. ⚠️ Non vieta il cambio su un tipo «usato» — quello impedirebbe di correggere una classificazione sbagliata, che è proprio il caso in cui serve: si guarda l'**effetto**, non l'uso. Nessun dato modificato, solo la funzione |
| 605 | Pernottamento_Coerente_Con_Le_Assegnazioni | Chiude le **tre strade** che invalidavano le assegnazioni in silenzio: togliere un genere ammesso da un pernottamento (misurato: −ALBERGO da «ALBERGO» = **414 assegnazioni** scoperte), cambiare il pernottamento **di un viaggio** (fino a 37 su un solo viaggio), e la cancellazione. ⚠️ **Aggiunge la chiave esterna** `fk_ana_viaggi_tipo_pernottamento` che non esisteva né in sviluppo né su PROD: la cancellazione era protetta solo da un trigger, e un trigger si può disattivare. Orfani esistenti: **0** in entrambi gli ambienti, quindi il vincolo si applica senza bonifiche. ⚠️ Va **dopo il 599** |
| 606 | Guardie_Complete_Sui_Generi | `fn_ana_alloggio_generi_delete` contava solo i tipi di sistemazione, non i pernottamenti che ammettono il genere. ✅ Il dato era protetto dalla chiave esterna, ⚠️ ma il messaggio era quello grezzo di PostgreSQL: una guardia che protegge il dato e non spiega il rifiuto ha fatto metà lavoro. Solo la funzione |
| 607 | Sistemazioni_Scoperte_Si_Confermano | ⚠️ **Superato dal 609**, che torna al rifiuto — applicarlo lo stesso, in ordine, perché il 609 ne sostituisce la firma. Il rifiuto dello script 605 diventava una **domanda**: `fn_ana_tipo_pernottamento_generi_set` prende `p_conferma`. ⚠️ Senza, era una **porta a senso unico** — spuntando un genere le assegnazioni storiche incoerenti diventavano coerenti, e togliendolo non si poteva più tornare indietro, nemmeno per annullare la propria modifica. È lo stesso schema di `fn_ana_clienti_guardia`: il punto non è impedirlo, è che non succeda di nascosto. ⚠️ **Sostituisce la firma a due parametri** (`DROP FUNCTION`): va applicato insieme al gestionale |
| 608 | Si_Chiede_Solo_Se_Si_Peggiora | ⚠️ **La parte sulla conferma è superata dal 609**; resta valida — e conservata dal 609 — la parte sul *come si conta*, che è il vero contenuto. La domanda scattava **solo per le assegnazioni oggi valide** che smetterebbero di esserlo, non per quelle già incoerenti in partenza. ⚠️ Prima la domanda arrivava anche risalvando senza modifiche, o togliendo un genere che nessuno usava: **un controllo che grida quando non succede niente insegna a rispondere senza leggere**, e il giorno in cui il numero conta nessuno lo guarda. Corregge sia `fn_ana_tipo_pernottamento_generi_set` sia `fn_ana_tipo_alloggio_upsert` |
| 609 | Configurazione_In_Uso_Non_Si_Rompe | ⛔️ **Si rifiuta, non si chiede** (decisione dell'utente, 2026-09-06: «la B perché la A è molto pericolosa»): un solo clic su «Procedi» poteva scoprire **414 assegnazioni** valide. Chi vuole cambiare la configurazione sistema prima le assegnazioni. ⚠️ **Colonna nuova** `ana_tipo_pernottamento_di_sistema`, `TRUE` su «NESSUNO»: un pernottamento che significa «non si dorme da nessuna parte» non può ammettere sistemazioni, e spuntargliene una era proprio il gesto che creava lo stato senza ritorno per cui era nato il 607. Da lì il divieto in scheda **e** il trigger `trg_pernottamento_di_sistema`, che ne impedisce rinomina e cancellazione a chiunque, sito compreso. ⚠️ La riga si riconosce **una volta sola** dalla descrizione, in questo script: da lì in poi è una colonna — riconoscerla dal testo è il difetto tolto quattro volte fra il 5 e il 6 settembre. ⚠️ **Sostituisce la firma a tre parametri del 607** (`DROP FUNCTION`): va applicato insieme al gestionale |
| 610 | Init_Partecipanti_Solo_Sistemazioni_Ammesse | ⚠️ **La quinta strada.** `fn_get_viaggio_partecipanti_init_data` costruisce in un colpo solo tutto ciò che serve alla scheda dei partecipanti, e l'elenco delle sistemazioni lo leggeva da `ana_tipo_alloggio` **per intero, senza guardare il viaggio**: su un viaggio in tenda offriva le camere d'albergo. Le altre tre schede chiamavano già `fn_alloggi_tipi_ammessi`; questa no, ed è la più usata. Trovato con la prova D2 su PIRENEI IN FUORISTRADA. ⚠️ Su PROD la definizione era **identica** a quella locale (md5 verificato in sola lettura), quindi si applica senza sorprese. Nessun dato modificato. ⚠️ Va **dopo il 600** |
| 611 | Tenda_Singola_E_Sistemazioni_Mai_Proposte | ⚠️ **Colonna nuova** `ana_tipo_alloggio.tipo_alloggio_mai_proposta`, `TRUE` sulle due righe DISABILI: restano in elenco e scegliibili, ma il programma non le propone mai d'ufficio. Prima non uscivano solo perché create più tardi delle altre — per fortuna, non per regola. ⚠️ **Le due tende da 1 posto (id 38 e 40) le ha inserite Adriano direttamente su PROD** il 2026-09-06: l'INSERT qui è idempotente e **su PROD non fa nulla**, serve al locale e a chi ricostruisca un ambiente. Le chiavi sono le sue, non generate. ⚠️ Cambia la firma di `fn_ana_tipo_alloggio_upsert` (sesto parametro) e il tracciato di `fn_ana_tipo_alloggio_get_all` e `fn_alloggi_tipi_ammessi`: va applicato **insieme al gestionale**. ⚠️ Va **dopo il 599** (usa `genere_fk`) e **dopo il 600** |
| 612 | Spostare_Una_Persona_Di_Camera_E_Atomico | `fn_alloggi_salva_camera`: salva una sistemazione e, **nella stessa transazione**, toglie i suoi occupanti dalle altre sistemazioni della stessa partenza, eliminando quelle che restano vuote. ⚠️ Nasce da un rilievo di Adriano: lo spostamento era **due** chiamate, e fra l'una e l'altra ci sta tutto ciò che non dipende dal codice — la rete, PgBouncer che chiude, l'app che va giù (ed è successo davvero). Si sarebbe restati con una persona in due camere o una camera vuota mai eliminata: ⚠️ **nessuna delle due dà errore**, sono dati che sembrano buoni e si scoprono in albergo. Nessun dato modificato, solo la funzione. ⚠️ Va **insieme al gestionale** |
| 613 | Le_Camere_Portano_Anche_L_Id_Del_Tipo | `get_rooms_with_occupants` e `fn_get_viaggio_partecipanti_init_data` espongono anche `tipo_alloggio_id`, non solo la descrizione. Serve a far **crescere** una sistemazione quando qualcuno si aggiunge dopo (il pilota iscritto da solo, la moglie che decide di venire più tardi): senza l'id, il gestionale dovrebbe risalire al tipo dal nome — ⛔️ la strada che non si prende. Sola lettura, nessun dato modificato. ⚠️ Va **insieme al gestionale** |
| 614 | Capienza_Rigorosa_Nella_Scrittura | ⚠️ **La parte sull'adeguamento automatico è superata dal 615**; resta valido il controllo di capienza, che il 615 conserva. ⛔️ `fn_alloggi_salva_camera` **rifiuta** una sistemazione il cui numero di occupanti non corrisponde alla capienza — decisione di Adriano del 2026-09-06: «rigoroso sul rapporto persone/capienza, nessuna scappatoia; le eccezioni con l'albergo restano offline». ⚠️ Il genere `NESSUNA` è escluso, e non è una scappatoia: capienza 0 con un occupante è il modo in cui si registra chi dorme nel proprio mezzo (2 casi su PROD azienda 2). ⚠️ Le **7 assegnazioni storiche sotto capienza** non vengono toccate: la funzione è nuova e in PROD non l'ha ancora usata nessuno — restano finché qualcuno non le modifica. ⚠️ Chi resta in una sistemazione dopo che qualcuno se ne va vede il **tipo adeguarsi** alla capienza rimasta (una tripla con due diventa matrimoniale): senza, spostare una persona da una doppia sarebbe impossibile. Nessun dato modificato dallo script |
| 615 | La_Camera_Che_Resta_La_Sceglie_L_Utente | ⛔️ `fn_alloggi_salva_camera` **non sceglie più** il tipo della sistemazione da cui qualcuno se ne va: se resta con meno persone, il tipo nuovo va indicato in `p_adeguamenti`, altrimenti **rifiuta** dicendo quale. ⚠️ Lo 614 lo adeguava da solo e in silenzio, su una camera che l'operatore non stava guardando — «rischi di mettere in matrimoniale due amici che vogliono letti separati» (Adriano). ⚠️ **Supera lo 614** e ne cambia la firma (sesto parametro): va applicato in ordine e **insieme al gestionale**. ⚠️ Contiene anche due correzioni trovate provandolo: il viaggio ora si **deriva dalla partenza** invece di fidarsi di chi chiama (una camera poteva finire agganciata al viaggio sbagliato, senza che nessuno se ne accorgesse), e con l'elenco occupanti vuoto il messaggio non parla più di «stessa persona due volte» |
| 616 | Capienza_Rigorosa_Anche_Nel_Trigger | ⛔️ La capienza scende nella **guardia** di `mov_clienti_alloggi`: vale per il gestionale, per il sito e per una UPDATE a mano — chiude il buco che la prova G1e aveva mostrato. ⚠️ Il genere `NESSUNA` resta escluso (capienza 0 con un occupante è come si registra chi dorme nel proprio mezzo). ⚠️ **Cambia anche la cancellazione**: `fn_mov_clienti_viaggi_delete` e `fn_mov_clienti_alloggi_togli_cliente` prendono `p_adeguamenti` — senza, togliere qualcuno da una camera condivisa verrebbe rifiutato. **Le firme vecchie a 3 parametri vengono eliminate** (DROP): va applicato **insieme al gestionale**, altrimenti le cancellazioni si fermano. ⚠️ Le righe storiche sotto capienza non vengono toccate e non sono più modificabili, ✅ ma sono **tutte su partenze già concluse**: nessun lavoro di bonifica prima del go-live — vedi 617 |
| 617 | Bonifica_Sistemazioni_Sotto_Capienza | ⛔️ **Non si applica, e non si applicherà: deciso il 2026-09-06 di lasciare quelle righe come sono** — «non fanno male a nessuno e fanno storia». Correggerle scriverebbe CAMERA SINGOLA dove l'albergo le singole non le aveva, cioè riscriverebbe cosa è stato prenotato e pagato su viaggi già fatti. È un rapporto. ✅ Accertato il 2026-09-06 (rilievo di Adriano: «per viaggi già conclusi non cambia nulla») che **tutte** le righe sotto capienza stanno su partenze **già finite** — 7 su PROD azienda 2, la più recente del 18/05/2026, **zero su partenze future**. Il controllo del 616 scatta solo su inserimento e modifica, e nessuno modifica le camere di un viaggio già fatto: quelle righe non incontreranno mai la guardia. Resta da rilanciare quando serve — se un domani il conto sulle partenze future non fosse più zero, vorrebbe dire che qualcosa scrive aggirando le funzioni |
| 618 | Tipo_Predefinito_E_Tetto_Sei_Posti | `fn_alloggi_tipo_predefinito` — quale sistemazione mettere d'ufficio a un gruppo di N persone. ⚠️ La regola **scende dal C# al database** perché serve anche al sito: il passo 5 non fa scegliere il tipo (chi si iscrive non sa se quell'albergo ha le singole), e due copie della stessa regola divergono. Più `fn_alloggi_tipi_per_capienza` per l'ultimo passo. ⚠️ **Vincolo nuovo** `chk_tipo_alloggio_capienza_max`: la capienza non può superare **6**, quante sono le colonne cliente in `mov_clienti_alloggi` — un tipo da 7 verrebbe offerto dalle combinazioni e poi non ci starebbe dentro nessuno. Nessuna riga esistente lo viola. ⚠️ Va **insieme al gestionale**, che non ha più la sua copia della regola |
| 619 | Una_Sola_Scrittura_Per_Le_Sistemazioni | ⛔️ **Da nove funzioni che scrivevano `mov_clienti_alloggi` a una.** Misurato prima di toccare: il gestionale ne usava tre strade, il sito una quarta, le altre erano rimaste indietro senza chiamanti — e quattro su cinque non controllavano niente. Resta `fn_alloggi_salva_camera`, che prende anche `p_created_by` (serviva al sito). ⚠️ **Elimina** `fn_wizard_insert_alloggio_assegnato`, `sp_mov_clienti_alloggi_create/update`, `sp_assign_to_first_free_slot`, `sp_resolve_room_violation_move`: verificato che nessuno le chiami più. Restano a parte `fn_mov_clienti_alloggi_togli_cliente` (cancellazione), `sp_remove_client_from_room` (usata da altre tre) e `fn_silos_rimappa_movimenti` (bonifica una tantum). ⚠️ Va **insieme al gestionale E al sito**: entrambi cambiano strada nello stesso momento |


> **Dopo `542` + `543`**, i due vincoli nati `NOT VALID` possono essere promossi a validati, perché
> a quel punto nessuna riga li viola (verificato in locale il 2026-08-20):
> ```sql
> ALTER TABLE ana_clienti VALIDATE CONSTRAINT ana_clienti_codicefiscale_lunghezza_check;
> ALTER TABLE ana_clienti VALIDATE CONSTRAINT ana_clienti_indirizzo_minimo_check;
> ```
> Il comando riesce solo se non resta nessuna violazione: è anche la verifica che la bonifica è andata a buon fine.

> ⚠️ **Stato reale di PROD al 2026-08-20 — da conoscere prima del deploy.**
> Per eseguire la bonifica del `545` sono stati applicati a PROD gli script **`543` e `544`→`555`**.
> **Non** sono stati applicati `538`-`542`. PROD ha quindi **23 funzioni nuove ma non lo schema che
> presuppongono**: mancano `ana_titolo_persone`, la colonna `ana_clienti.cliente_titolo_fk` e i
> vincoli del `541`/`542`.
>
> **Non è un guasto:** quelle funzioni sono inerti — nessun software le chiama, il gestionale in
> produzione è ancora la 1.35 e il sito usa le sue `fn_wizard_*`. E **si sana da sola**: al go-live
> gli script si applicano in ordine numerico crescente, quindi `538`-`542` arrivano prima e le
> funzioni vengono ricreate sopra uno schema completo.
>
> **La regola che ne discende:** non applicare altri script a PROD fuori dalla sequenza. Fino al
> go-live PROD resta com'è.

**Riepilogo di cosa NON è un semplice apply** (dettagli in §2/§3):
`473` grant anon · `475` + `483` segreti e `GV_SECRET_KEY` · `484` + `485` backfill su clienti reali ·
`468` e `493` re-model con migrazione dati · `538` re-model titolo/sesso clienti (§2.7) · **revisione del sito di iscrizione, prerequisito (§2.8)** · `491` e `509` vincoli che falliscono su dati sporchi ·
`499_Rollback` da non eseguire mai · **`563` campi obbligatori: cambia il lavoro quotidiano dal primo giorno (§2.9)** · `570` da precedere con `DROP FUNCTION` · `578` blocca le iscrizioni su partenze concluse, **da misurare su PROD prima** · `579` misurato su PROD, nessun caso sulle partenze aperte · `580` crea una tabella e normalizza i prefissi esistenti.

> La verità sulle *funzioni* DB resta `Documents/Funzioni_DB.md` (rigenerato da `deploy_sql.sh`). Questo documento traccia il **deploy**, non la definizione.

---

### 1.5 — `SqlScripts/586` modifica dati esistenti (posti letto)
Oltre alle funzioni, lo script **libera i posti letto occupati da chi non risulta
iscritto** a quella partenza (difetto 82). Misurato su PROD il 2026-09-05:

| Azienda | Camere coinvolte | Posti da liberare |
|---|---|---|
| 2 (SFT) | 1 | 1 |
| 6 | 5 | 5 |

Le camere in cui **nessun** occupante risulta iscritto vengono eliminate; le altre
perdono solo il posto di chi non è iscritto. ⚠️ **Le iscrizioni non vengono toccate**:
togliere qualcuno da un viaggio è una decisione dell'azienda, non una pulizia.

Controllo dopo l'applicazione — deve dare 0:

```sql
SELECT count(*) FROM mov_clienti_alloggi a
CROSS JOIN LATERAL unnest(ARRAY[a.cliente_id1_fk,a.cliente_id2_fk,a.cliente_id3_fk,
                                a.cliente_id4_fk,a.cliente_id5_fk,a.cliente_id6_fk]) AS u(cli)
WHERE u.cli IS NOT NULL AND NOT EXISTS (
  SELECT 1 FROM mov_clienti_viaggi m
  WHERE m.cliente_id_fk = u.cli AND m.data_viaggio_id_fk = a.data_viaggio_id_fk);
```

---

### 1.6 — `SqlScripts/587-588-589` rimettono in ordine i silos (**in quest'ordine**)
Residuo dell'importazione da Oracle: clienti di un'azienda risultano iscritti ai viaggi
di un'altra. Misura su PROD del 2026-09-05:

| | |
|---|---|
| Righe da rimappare (iscrizioni, riferimenti al pilota, posti letto) | **81** |
| Persone coinvolte | **26** |
| **Anagrafiche da creare nell'azienda del viaggio** | **24** |

- **587** — le funzioni (`fn_cliente_gemello_in_azienda`, `fn_silos_movimenti_fuori_azienda`,
  `fn_silos_rimappa_movimenti`) e il rimappaggio dove il gemello esiste già.
- **588** — ⚠️ **crea 24 anagrafiche nuove nell'azienda 2**, copiate dall'azienda 6, e
  rimappa il resto. Le nuove schede si riconoscono da `created_by = 'migrazione_silos'`.
  **Il consenso al marketing NON viene copiato**: è stato dato a un'altra azienda e vale
  verso chi lo ha raccolto. Le schede nascono come «mai chiesto», così le regole del
  consenso lo chiederanno alla prima occasione utile.
- **589** — la guardia che impedisce di rifarlo. ⚠️ **Va dopo gli altri due**: prima, i
  dati esistenti la violerebbero e ogni modifica di quelle righe fallirebbe.

Controllo dopo l'applicazione — deve dare 0 righe:

```sql
SELECT * FROM fn_silos_movimenti_fuori_azienda();
```

⚠️ **Effetto da sapere prima**: le 24 persone entrano nel perimetro dell'azienda 2, quindi
nei conteggi clienti e nel bacino potenziale della newsletter (senza consenso, che andrà
chiesto).

---

### 1.7 — `SqlScripts/590`: il consenso solo sui propri clienti
Le due funzioni del consenso non guardavano l'azienda, e i loro endpoint leggono
l'identificativo del cliente **direttamente dalla richiesta**: bastava cambiare un numero
per registrare un consenso — o un rifiuto — a nome di chiunque. Ora richiedono l'azienda
e su un cliente che non è suo non rispondono e non scrivono.

⚠️ Lo script **sostituisce le firme** (`DROP FUNCTION` + `CREATE`): va applicato insieme
al codice Flask che passa il nuovo parametro, altrimenti il popup del consenso smette di
funzionare.

---

## 2. Voci che richiedono attenzione MANUALE (oltre al semplice apply)

### 2.1 — Ruolo `anon` + RLS (406, 450–453)
- Su **Supabase** il ruolo `anon` **esiste già** (usato da PostgREST). Lo script `406_Setup_RoleAnon` va **riconciliato**: NON ricreare il ruolo, applicare solo i `GRANT`/policy mancanti. Verificare che i `GRANT EXECUTE` verso `anon` (hardening 453) combacino con la config Supabase.
- Le policy RLS anon (450–453) espongono in lettura solo i contenuti web pubblicati e consentono l'insert delle iscrizioni newsletter. **Verificare in staging** che nessuna tabella per-azienda sia leggibile da `anon` oltre il previsto (invariante silos: [[multitenancy-invariant-silos]]).
- ⚠️ **Grant colonnari anon da ESTENDERE (aggiunte CMS 467–480)**: `fn_web_tour_pubblicati` e `fn_web_ha_tour_brevi_pubblicati` sono **SECURITY INVOKER** e leggono colonne **nuove** non incluse nel grant colonnare originale dello script `452`. Su PROD/Supabase aggiungere ad `anon` il `SELECT` (column-level) su:
  - `ana_viaggi`: `viaggio_difficolta` (467), `viaggio_incluso`, `viaggio_escluso` (476), `viaggio_capienza_max`, `viaggio_capienza_alert` (478);
  - `ana_tipo_viaggi`: `tipo_viaggio_breve` (480).
  Senza questi grant, la lettura pubblica fallisce con *permission denied for column …*. NB: `fn_web_mezzi_occupati_data` e `fn_web_recensioni_config` sono **SECURITY DEFINER** e **non** richiedono grant su `mov_clienti_viaggi`/`web_aziende_funzioni`. (In locale il ruolo `anon` non ha i grant colonnari: la verifica va fatta in staging Supabase.)
- ✅ **`meta_title`/`meta_description` (script 486, Blocco 5 Fase 2)**: NON richiedono grant aggiuntivo — sono colonne **originarie** di `web_tour_contenuti` (script `410`), già incluse nel grant colonnare `anon` esistente. Verificato in locale (`\dp web_tour_contenuti`): `anon=r` presente su entrambe.

### 2.2 — Cifratura segreti (`_enc`) — **FATTA (script 475, 2026-07-11)**
Cifratura reale implementata con **pgcrypto** (`pgp_sym_encrypt/decrypt`), master key dall'ambiente. Vedi design `Documents/2026-07-11-Cifratura_Segreti_design.md`. Coperti: SMTP (`ana_aziende_smtp.password_enc`/`inbound_password_enc`), ESP (`ana_aziende_esp.api_key_enc`), Claude (`ana_aziende.claude_api_key_enc`). Colonne `_enc` ora **bytea**; i valori finti sono stati **azzerati** dalla migrazione. Esclusi: Geoapify (deciso), `sys_redis_endpoints` (infra).

**Da fare in PROD (go-live):**
- [ ] Impostare la variabile d'ambiente **`GV_SECRET_KEY`** (stringa forte, es. base64 di 32 byte), **la STESSA su tutte le installazioni** che condividono il DB. Senza, le operazioni sui segreti falliscono con errore chiaro (fail-fast).
- [ ] **Re-inserire** i segreti reali (SMTP/Claude/ESP) dalle form dopo il deploy di `475` (i finti sono stati azzerati; in PROD non c'erano segreti reali cifrati).
- [ ] `web_pagamenti_config.stripe_*_enc`: formato bytea pronto (Fase 4), nessun valore.

> **ESP-come-provider abbandonato (deciso 2026-07-12):** il canale email (incluse le newsletter) è lo **SMTP del cliente** (`ana_aziende_smtp`, già in anagrafica), instradato da `EmailSenderFactory` (SMTP configurato → usato; fallback Resend). **Nessun provider ESP esterno** (Brevo/Mailchimp/SES) da wire-are. La tabella `ana_aziende_esp` resta **predisposta ma inutilizzata** (schema/funzioni già cifrati, pronta per un eventuale uso futuro): nessun tab UI, nessun wiring nel factory. Niente da fare qui per il go-live.

### 2.3 — `token_iscrizione` per azienda (429)
Serve come **segreto HMAC** per il link di disiscrizione newsletter (`NewsletterUnsubscribe`). Ogni azienda in PROD deve avere un `token_iscrizione` valorizzato (random, per-azienda). Verificare che il backfill/valore non sia NULL prima di inviare newsletter.

⚠️ **Con `token_iscrizione` NULL l'app non si accorge di nulla:** `NewsletterUnsubscribe.BuildUrl` passa `token ?? ""` a `Sign`, quindi l'HMAC viene calcolato **con chiave vuota**. Il link esiste ed è ben formato, ma la firma è **identica fra tutti i tenant** a parità di email e ricalcolabile da chiunque. Nessun errore, nessun log: si scopre solo confrontando due firme. Prova rapida: stessa email da due aziende diverse → i `sig` devono essere **diversi**.

⚠️ **Da chiarire prima di scriverlo:** lo script `429` dice che il valore va *allineato al segreto dell'app Flask su Hetzner* (`AZIENDA_ID`/`FLASK_SECRET_KEY`), mentre qui sopra si dice *random per-azienda*. La stessa colonna sta servendo a due scopi (token del link "Iscriviti" di Flask **e** segreto HMAC della disiscrizione): un valore random rompe Flask, tenere quello di Flask significa condividere il segreto HMAC con un'app esterna. **Decidere prima del go-live**, eventualmente separando le due cose in due colonne.

#### Requisito per la Fase 3 — l'endpoint `/unsubscribe` deve creare una SOPPRESSIONE
Non basta mettere `stato='disiscritto'` sull'iscritto. **Verificato in locale il 2026-08-08** (Piano di Test §8 C5-bis): se la stessa email è anche un **cliente con `consenso_marketing=true`**, la riga del cliente sopravvive alla `FULL JOIN` di `fn_web_destinatari_newsletter` e **la persona continua a ricevere le newsletter**; `fonte` scivola da `entrambi` a `cliente` senza alcun segnale che una revoca è stata ignorata.

L'implementazione corretta dell'unsubscribe, in ordine:
1. verificare la firma HMAC (`sig`) con il `token_iscrizione` dell'azienda;
2. **inserire la riga in `web_newsletter_soppressioni`** (motivo `unsubscribe`) — è l'unico filtro che blocca *qualunque* fonte;
3. opzionalmente marcare anche `stato='disiscritto'` sull'iscritto, ma **come conseguenza, non come sostituto** del passo 2.

Chi implementa solo il passo 3 produce un "Disiscriviti" che non disiscrive: nessun errore visibile, e la persona continua a ricevere posta.

### 2.4 — Supabase Storage (immagini WebP, mappe GPX)
Blocco 7 (immagini tour, WebP) e Blocco 9 (mappe da GPX) salvano su **Supabase Storage**. In PROD devono esistere i **bucket** corrispondenti con le policy corrette. La `Service Key` Supabase va configurata lato app (NON committata). Verificare bucket + permessi prima di caricare media.

**⚠️ Due punti emersi in test (2026-07-21) — NON dimenticare:**
- [ ] **Creare il bucket `tour-media` (PUBBLICO)** nel progetto Supabase PROD. Nel progetto di test i bucket erano **azzerati** (`GET /storage/v1/bucket` → `[]`): è stato creato `tour-media-dev` (pubblico) il 2026-07-21. Il bucket dev'essere **public** perché l'URL pubblico usa `…/object/public/<bucket>/…` (`SupabaseMediaStorage.BuildPublicUrl`). Il nome bucket è per-ambiente in `appsettings` (`WebMediaStorage:Bucket`): dev = `tour-media-dev`, prod = `tour-media`.
- [ ] **Formato chiave Storage.** Se si usa una **nuova chiave Supabase `sb_secret_…`** (non-JWT), DEVE essere passata nell'header **`apikey`** (il solo `Authorization: Bearer` dà `400 Invalid Compact JWS`). Già gestito nel codice: `SupabaseMediaStorage` invia `apikey` + `Bearer`. La vecchia `service_role` (JWT `eyJ…`) funziona con entrambi. Ricorda comunque il debito go-live: la ServiceKey NON deve restare nel binario MAUI (estraibile) → chiave scoped al bucket o upload server-side.

### 2.5 — Backfill `ana_clienti.cliente_lingua` (465)
Lo script 465 fa `UPDATE ana_clienti SET cliente_lingua = COALESCE(fn_lingua_da_comune(...), 'IT') WHERE cliente_lingua IS NULL`. **Va eseguito sui clienti reali di PROD** (in locale ha popolato 740 clienti Docker). È **idempotente** (`WHERE cliente_lingua IS NULL`). Vedi [[prod-backfill-cliente-lingua]]. Dopo il backfill, verificare la distribuzione lingue prima del primo invio newsletter.

**Fix troncamento `cliente_lingua` (script 484 + app):** il vecchio `ClienteLinguaService.SetAsync` usava il cast `@L::char` (= `char(1)`), che troncava `'IT'`→`'I'` **prima** della funzione DB → il select in `ClienteDialog` mostrava il codice grezzo al rientro. Corretto in `::varchar`. Lo **script 484** ripara le righe già salvate corrotte (rimappa il singolo carattere → ISO 2 lettere; `'E'`→`'EN'` di default, ambiguo con `ES`). Su PROD: eseguire 484 **dopo** aver rilasciato l'app col fix del cast, poi riverificare la distribuzione lingue.

**`cliente_lingua` mai NULL (script 485):** `fn_ana_clienti_set_lingua` auto-deriva dalla nazione di residenza quando il campo è vuoto (`fn_lingua_da_comune`, fallback `IT`); backfilla i NULL residui; imposta colonna `DEFAULT 'IT'` + `NOT NULL`. La newsletter legge `cliente_lingua` senza ragionare (il `COALESCE` in `fn_web_destinatari_newsletter` resta solo come fallback difensivo). Applicare 485 su PROD **dopo** 484.

### 2.6 — Dati di tabelle "tecniche" da MIGRARE (contenuto, non solo schema)

⚠️ **`web_indirizzi` (script `517`/`519`) — CONTENUTO da riportare in PROD, non solo lo schema.**
È la rubrica degli indirizzi web dell'azienda (sito, pagine, social) da cui i pulsanti della
newsletter pescano le destinazioni. Lo script crea la tabella **vuota**: senza i record, i pulsanti
non hanno nulla fra cui scegliere e l'operatore si ritrova a dover riscrivere gli URL a mano —
cioè proprio la cosa che la tabella evita.
Da riportare per ogni azienda: `descrizione`, `url`, `note`, `ordine`, `attivo`, `social`.
Le **icone** (`icona_url` / `icona_storage_path`) puntano a file su Supabase Storage: vanno
ricaricate dalla scheda dell'indirizzo in PROD, oppure i file vanno copiati nel bucket di produzione
e gli URL riscritti. Un `icona_url` che punta al bucket di sviluppo produrrebbe un'icona rotta in
tutte le newsletter.

Alcune tabelle sono troppo tecniche per gli utenti finali: vengono **compilate a mano in TEST** con i dati corretti e poi il **contenuto** (non solo lo schema creato dagli script §1) va copiato sul DB Supabase di PROD. Riguarda:

- **`web_tipi_viaggio_descrizioni`** — lookup **GLOBALE** delle descrizioni web dei tipi di viaggio + le relative **traduzioni** (`web_traduzioni` per questa entità).
- **`ana_tipo_viaggi`** — tipologie di viaggio (**GLOBALE**/condivisa), inclusa la colonna `descrizione_web_fk` che referenzia la tabella sopra.

> **Stato TEST (2026-07-25):** test funzionale delle "Descrizioni web dei tipi" **superato**. Contenuto attuale in TEST (Docker): **10** righe in `web_tipi_viaggio_descrizioni`, **9** righe in `ana_tipo_viaggi` (tutte con `descrizione_web_fk` valorizzato — sono stati **aggiunti record** rispetto al set originario), **0** righe in `web_traduzioni` (nessuna traduzione ancora generata: se al momento del go-live ce ne saranno, vanno migrate anch'esse).

⚠️ **Ordine di migrazione**: prima `web_tipi_viaggio_descrizioni` (referenziata), poi `ana_tipo_viaggi` (che la referenzia via `descrizione_web_fk`), infine le eventuali righe di `web_traduzioni` con `entita = 'web_tipi_viaggio_descrizioni'`. Migrare i record **così come sono in TEST** (`ordine`/`slug` già conformi ai vincoli 490/491, `ordine` UNIQUE e ≥ 1). Da fare **dopo** aver applicato gli script §1 (schema + vincoli) e **prima** di pubblicare contenuti che dipendono da questi tipi.

**Metodo consigliato** — dump dati da TEST e restore su PROD mantenendo gli **id** (le FK dipendono da essi):

```bash
# 1) export da TEST (Docker)
docker exec -i postgres_db pg_dump -U postgres -d gestione_viaggi --data-only \
  -t web_tipi_viaggio_descrizioni -t ana_tipo_viaggi > /tmp/tipi_viaggio_data.sql

# 2) su PROD: svuotare le due tabelle SOLO se contengono dati non voluti,
#    rispettando la FK (prima ana_tipo_viaggi, poi le descrizioni), poi:
psql "$PROD_CONN" -v ON_ERROR_STOP=1 -f /tmp/tipi_viaggio_data.sql
```

⚠️ **Dopo il restore, riallineare le sequence identity** (altrimenti il primo insert da UI va in errore di chiave duplicata):

```sql
SELECT setval(pg_get_serial_sequence('web_tipi_viaggio_descrizioni','web_tipi_viaggio_descrizioni_id'),
              COALESCE((SELECT MAX(web_tipi_viaggio_descrizioni_id) FROM web_tipi_viaggio_descrizioni),1));
SELECT setval(pg_get_serial_sequence('ana_tipo_viaggi','tipo_viaggi_id'),
              COALESCE((SELECT MAX(tipo_viaggi_id) FROM ana_tipo_viaggi),1));
```

Verifica finale: conteggi identici a TEST, nessun `descrizione_web_fk` orfano, `ordine` = 1..N senza duplicati.

---

### 2.7 — Titolo e sesso del cliente: re-model `ana_clienti` (538–540)

**Perché esiste.** `cliente_titolo` era testo libero e `cliente_sesso` un campo a parte: nulla
impediva di salvare un titolo maschile su una donna, e infatti era successo. Non è un errore degli
utenti, è un errore dello schema: chi compila in fretta prende la prima voce del combobox senza
leggerla, e questo continuerà a succedere sempre. L'unico rimedio che regge è togliere la possibilità
di essere incoerenti — il sesso ora **si deriva** dal titolo, non si digita.

**Prova a secco eseguita su PROD il 2026-08-19** (sola lettura, nessuna scrittura). Simulata la
mappatura dello script `538` sui clienti veri:

| Titolo attuale | Sesso | Diventa | Clienti |
|---|---|---|---|
| `SIG` | M | `SIG.` | 493 |
| `SRA` | F | `SIG.RA` | 264 |
| `SIG` | F | `SIG.RA` | **11** ← le incoerenze storiche |
| `SIG.` | M | `SIG.` | 5 |
| `SIG.RA` | F | `SIG.RA` | 4 |
| *(vuoto)* | M | `SIG.` | 1 |

**778 clienti, nessuno resta senza titolo**: il `SET NOT NULL` passerà. Verificati anche: PostgreSQL
17.6, vincolo `cliente_sesso IN ('M','F')` presente, le 9 function che citano `cliente_titolo` sono
le stesse del locale, nessuna vista, i 4 trigger preesistenti su `ana_clienti` non confliggono (il
nuovo scatta dopo `trg_ana_clienti_audit`, che è BEFORE e alfabeticamente precedente).

> **PROD non è una copia del locale:** 778 clienti contro 742, e PROD ha **un cliente senza titolo**
> che in locale non esiste — era il caso che poteva far fallire il `NOT NULL`. In compenso PROD non
> ha nessun `DOTT.`. Le prove fatte solo in locale non avrebbero intercettato né l'uno né l'altro.

**Regola d'ordine, obbligatoria:** applicare `538`→`540` **PRIMA** di distribuire l'eseguibile nuovo.
L'app nuova scrive solo `cliente_titolo_fk` e su uno schema vecchio non funziona; il sito di
iscrizione invece funziona **con o senza** gli script (lo copre il ponte del `539`). Quindi:
script → poi eseguibile. Mai il contrario.

**Due trappole latenti — da conoscere, non da risolvere ora:**

- **RLS attiva su `ana_clienti` con zero policy.** Solo il proprietario della tabella la vede: tutto
  funziona perché app e sito si collegano come `postgres`. Non è introdotto da questo re-model, ma il
  giorno in cui qualcosa si collegasse con un ruolo diverso, `ana_clienti` sarebbe già invisibile.
- **`fn_wizard_insert_cliente` non è `SECURITY DEFINER`**: gira coi privilegi del chiamante, e il
  trigger nuovo — che legge `ana_titolo_persone` — pure. Oggi il chiamante è `postgres`. Se il sito
  passasse a un ruolo limitato servirebbe una `GRANT SELECT` sulla tabella nuova, altrimenti **ogni
  iscrizione web fallirebbe**. Non aggiunta ora perché nessuna lookup del progetto ha grant diversi
  da `postgres`: farlo solo qui sarebbe un'incoerenza.

---

### 2.8 — Sito di iscrizione ai viaggi: la revisione che manca

Il sito Flask (§12 di `Funzioni_DB.md`) **continua a funzionare senza alcuna modifica** dopo il
re-model: manda il titolo come testo (`SIG.`, `SIG.RA`, maiuscolo come tutti i suoi campi) e un sesso
separato, e il ponte del `539` gli assegna la FK. Verificato il 2026-08-19 su inserimento, rilettura
e aggiornamento, anche con titolo e sesso in contraddizione fra loro: vince il sesso, esattamente
come nel gestionale.

> ⛔️ **PREREQUISITO DI GO-LIVE (deciso il 2026-08-19).** Il sito va rivisto **prima** di andare in
> produzione, non dopo. Non perché si rompa — funziona — ma perché il giorno in cui gli script
> `406+` arrivano su PROD, il sito comincia a creare clienti su uno schema che ha il consenso, i
> titoli normalizzati e i controlli del gestionale, **senza rispettarne nessuno**. Ogni iscrizione
> raccolta in quella finestra è un dato che poi non si sistema più: il consenso non si recupera con
> un backfill (§2.8.1) e le anagrafiche entrate senza controlli restano com'erano.
>
> Il momento giusto per chiudere questi quattro punti è quello in cui il sito **non ha ancora**
> scritto nulla sul nuovo schema.

#### 2.8.1 — Il consenso all'invio di email: **grave, e non recuperabile dopo**

Lo schema prevede il consenso fatto a norma — non un flag, ma **tre** colonne (`SqlScripts/428`):

| Colonna | Cosa contiene |
|---|---|
| `consenso_marketing` | `BOOLEAN NOT NULL DEFAULT false` |
| `consenso_marketing_data` | quando è stato raccolto |
| `consenso_marketing_fonte` | da dove |

Le ultime due esistono perché il GDPR non chiede di *avere* il consenso, chiede di poterlo
**dimostrare**. Il sito non ne valorizza nessuna delle tre: `fn_wizard_insert_cliente` non le nomina.

**Cosa questo NON è.** Non è un invio senza consenso: il default è `false`, quindi chi si iscrive dal
sito non entra in nessuna newsletter. Da questo lato il sistema sbaglia dalla parte giusta.

**Cosa questo è, e perché è grave lo stesso.** Chi si iscrive e *vorrebbe* essere ricontattato non
viene mai interpellato: è irraggiungibile per sempre, e la newsletter è la funzione su cui è stato
speso l'ultimo mese. Ma il pericolo peggiore viene dopo: quando ci si accorgerà del buco, la
tentazione sarà **accendere il flag in blocco** sugli iscritti dal sito. Sarebbe *quella* la
violazione — `data` e `fonte` resterebbero vuote e non ci sarebbe nulla da esibire in caso di
contestazione. Il consenso si raccoglie alla fonte o non si raccoglie: **non è recuperabile a
posteriori**, e nessun backfill lo rende lecito.

**Cosa serve:** una casella di spunta esplicita nella form del sito (non pre-spuntata, separata
dall'accettazione delle condizioni: sono due consensi distinti), e il passaggio dei tre valori a
`fn_wizard_insert_cliente` — `true/false`, `now()`, e una fonte riconoscibile tipo `SITO_ISCRIZIONE`.

#### 2.8.2 — L'avviso nome/sesso va replicato

`CoerenzaNomeSessoValidator` (vedi `Gestione_check.md`) avvisa, senza bloccare, quando il nome
smentisce il sesso: nome in `-a` con sesso M, o in `-o` con sesso F. Nel gestionale intercetta chi
lascia `SIG.` anche su una donna — l'errore tipico da quando il sesso si deriva dal titolo.

Sul sito quel controllo **non c'è**, e lì il sesso è per giunta un campo a sé: la stessa incoerenza
può rientrare dalla finestra. Da replicare insieme al punto 2.8.3, con la stessa lista di eccezioni
(`ANDREA, LUCA, NICOLA, ELIA, MATTIA, ENEA, ISAIA, GEREMIA, ZACCARIA, BATTISTA, EVANGELISTA, COSMA`
+ composti attaccati + `MARIA` come secondo nome) e la stessa regola: **avvisa, non blocca**. Senza
la lista scatta 56 volte su 56 a torto, misurato sui clienti veri.

#### 2.8.3 — Titolo e sesso: le tre strade

**Ma resta l'ultima porta da cui può entrare un'incoerenza.** Nel gestionale il sesso non è più
digitabile; sul sito sì, ed è un campo separato dal titolo. Chi si iscrive in fretta può ancora
scegliere `SIG.` ed essere donna. Il DB oggi lo corregge in silenzio — il che va bene per il dato,
ma significa che il sito mostra all'utente una cosa e ne salva un'altra.

**Va allineato, e va deciso quando.** Non è urgente e non è bloccante per il go-live: sono due
interventi indipendenti, e questo può seguire mesi dopo. Le tre strade, dalla più leggera:

1. **Solo cosmetica sul sito** — togliere il campo sesso dalla form e derivarlo dal titolo scelto,
   lasciando invariate le chiamate DB. È il minimo che elimina la contraddizione a video. Il ponte
   del `539` resta necessario.
2. **Il sito legge la lookup** — la tendina dei titoli viene da `ana_titolo_persone` invece che da un
   elenco cablato, così i titoli nuovi aggiunti dal gestionale compaiono anche sul sito. Serve una
   function di sola lettura esposta al ruolo del sito.
3. **Il sito passa alla FK** — nuove `fn_wizard_insert_cliente`/`update` che accettano
   `p_titolo_fk INTEGER` invece di testo e sesso. È la sola strada che permette poi di **eliminare**
   `ana_clienti.cliente_titolo`, il ponte del `539` e `fn_ana_titolo_persone_da_testo`.

Finché non si fa la 3, il debito dichiarato in `Funzioni_DB.md` §8.3 resta aperto: la colonna
deprecata non si può togliere.

#### 2.8.4 — I controlli sul cliente: due implementazioni, nessuna condivisa

> **Ordine dei lavori, deciso il 2026-08-19.** Questo è il **primo** lavoro da fare, prima di tutto
> il resto del go-live — e si fa in due tempi ravvicinati: **prima il gestionale** (centralizzare i
> controlli di `ana_clienti`, facendo scendere nel DB quelli che devono valere ovunque), **subito
> dopo il sito**, che a quel punto si allinea a una regola sola invece che a diciassette sparse.
>
> L'ordine non è un dettaglio: replicare sul sito controlli che nel gestionale sono ancora
> frammentati significherebbe duplicare la frammentazione invece di chiuderla. Fatto così, su
> `ana_clienti` non ci si torna più.

**Da verificare, non ancora deciso.** Il CRUD cliente del sito applica i suoi controlli; il
gestionale applica i propri. Nessuno dei due sa cosa fa l'altro, e non esiste un punto in cui la
regola sia scritta una volta sola.

L'inventario del gestionale, rilevato il 2026-08-19:

| Dove | Cosa |
|---|---|
| `Validation/Business/ClienteValidator` | **17 metodi**: email, cognome, nome, indirizzo, data di nascita, telefono, prefisso, tipo/numero/ente del documento, date di rilascio e scadenza (incrociate fra loro e con la nascita), IBAN, unicità email passeggeri |
| `Validation/Syntax/CodiceFiscaleValidator` | formato e coerenza del CF |
| `Validation/Semantic/CoerenzaNomeSessoValidator` | avviso nome/sesso (§2.8.2) |
| Annotazioni su `Models/Cliente` | obbligatorietà, lunghezze, formato email, `[MF]` |
| **Database** | **un solo `CHECK`**: `cliente_sesso IN ('M','F')` — più la FK e il `NOT NULL` del titolo aggiunti dal `538` |

È qui il problema: **tutte le regole vivono nel C#, dove il sito non arriva.** Il database accetta
quasi tutto, quindi il sito può scrivere un'anagrafica che il gestionale avrebbe rifiutato — email
malformata, CF incoerente, documento scaduto prima di essere rilasciato — e nessuno se ne accorge
finché quel cliente non viene riaperto nella form desktop.

**Verifiche da fare** (per ciascuna riga della tabella sopra): il sito la applica? con quale regola?
e cosa succede al dato se le due regole divergono?

**Direzione probabile, da confermare.** Non si possono condividere i validator C# con un sito Flask.
L'unico strato che entrambi attraversano davvero è **il database**, ed è anche quello che la regola
DB-First del progetto (`overview.md` §3.1) indica come casa naturale della logica. Quindi: le regole
che devono valere *ovunque* scendono nel DB — come `CHECK`, o come funzione di validazione
richiamabile da entrambi — e in C# resta solo ciò che serve all'immediatezza dell'interfaccia
(messaggio inline, fuoco sul campo, avvisi non bloccanti). Da valutare caso per caso: alcune regole
sono genuinamente di presentazione e nel DB non ci stanno.

> **Nota:** dopo il re-model del `538`, `ClienteValidator.ValidateTitolo` e `ValidateSesso` non hanno
> più chiamanti — il titolo è una FK e il sesso è derivato. Non rimossi: vanno riviste insieme a
> questa verifica, non prima.

---

### 2.9 — Campi obbligatori dell'anagrafica (563): l'unico script che si sente il primo giorno

Deciso il 2026-08-31: i dati del documento d'identità servono a **ogni** partecipante, perché alla
registrazione in albergo si presentano per legge i documenti di tutti gli occupanti della stanza.
La regola sta nel database, quindi vale per il gestionale e per il sito insieme.

Tutti gli altri script di questo blocco sono additivi o cambiano messaggi. Questo no: **cambia cosa
si può fare con i dati che già ci sono**.

> 🟢 **Ridimensionato il 2026-09-05: l'impatto è molto minore del previsto.** Le misure fatte ad
> agosto guardavano **tutte le aziende** (779 clienti, di cui 575 senza numero documento: il 74%).
> Ma l'azienda che lavora davvero è la **2 — SFT**, e lì i clienti sono **206** con numeri
> tutt'altri:
>
> | manca | clienti SFT | su 206 |
> |---|---|---|
> | ente che ha rilasciato il documento | 21 | 10% |
> | numero documento | 16 | 8% |
> | data di scadenza | 15 | 7% |
> | indirizzo di residenza | 8 | 4% |
> | email | 8 | 4% |
> | data di nascita | 2 | 1% |
>
> Il grosso dei 575 sta nell'**azienda 6**, che non opera. Il go-live si sente quindi su qualche
> decina di schede, non su centinaia: si completano man mano che quelle persone si riscrivono a
> un viaggio, senza bisogno di una bonifica preventiva.

**Due momenti in cui si fa sentire:**

1. **Aprendo una scheda incompleta** — il gestionale la segnala all'apertura, campo per campo, e non
   la lascia salvare finché non è completa. Anche per cambiare solo un numero di telefono.
2. **Iscrivendo un cliente incompleto** — l'iscrizione è **rifiutata** con l'elenco di cosa manca
   (`ANAGRAFICA_INCOMPLETA`). È il caso che intercetta le schede mai riaperte.

**Da misurare su PROD prima del go-live** (sola lettura, [[db-locale-e-di-test-non-di-riferimento]]):

```sql
-- Quante anagrafiche sarebbero da completare, e quali dati mancano di più
SELECT count(*) FILTER (WHERE cliente_documento_numero IS NULL)              AS senza_numero_doc,
       count(*) FILTER (WHERE cliente_documento_rilasciato_scadenza IS NULL) AS senza_scadenza,
       count(*) FILTER (WHERE cliente_data_nascita IS NULL)                  AS senza_nascita,
       count(*) FILTER (WHERE btrim(coalesce(cliente_indirizzo_residenza,'')) = '') AS senza_indirizzo,
       count(*)                                                              AS totale
FROM ana_clienti;

-- Quelle che servono davvero adesso: gli iscritti alle partenze future
SELECT count(DISTINCT c.cliente_id)
FROM ana_clienti c
JOIN mov_clienti_viaggi v ON v.cliente_id_fk = c.cliente_id
JOIN ana_date_viaggi d ON d.data_viaggio_id = v.data_viaggio_id_fk
WHERE d.data_viaggio_inizio >= CURRENT_DATE
  AND (c.cliente_documento_numero IS NULL OR c.cliente_documento_rilasciato_scadenza IS NULL);
```

Il primo numero dice quanto lavoro di sanamento c'è in tutto; **il secondo dice quanto ne serve
subito**, ed è quello su cui decidere. Sanare le schede delle partenze imminenti *prima* di
consegnare evita che il primo giorno di uso sia una fila di rifiuti.

> ⚠️ **Se il secondo numero è alto**, le strade sono due, e vanno scelte prima e non durante:
> completare quelle schede in anticipo (è lavoro d'ufficio, non tecnico), oppure applicare il `563`
> in un secondo momento, dopo il resto della sequenza — gli altri cinque script non dipendono da lui.
> Quello che **non** si può fare è scoprirlo il lunedì mattina con il cliente al telefono.

#### Misurato su PROD il 2026-09-01 (sola lettura): **si può applicare**

| Partenza | Iscritti | Di cui incompleti |
| :--- | ---: | ---: |
| 18/10/2026 | 9 | **0** |
| 22/10/2026 | 6 | **0** |
| 29/10/2026 | 1 | **0** |
| 31/10/2026 | 3 | **0** |
| 04/12/2026 | 0 | — |

Su **779** clienti in anagrafica ne mancano **575** di numero documento (74%), **580** dell'ente di
rilascio, **34** della data di nascita e **67** dell'indirizzo. Ma sono **tutti storici**: chi
viaggia da qui a dicembre ha la scheda a posto, e nessuna iscrizione reale verrebbe rifiutata.

Il `563` si applica quindi **nella sequenza, senza rinvii**. Il sanamento dei 575 avverrà da sé,
una scheda alla volta, quando qualcuno la riaprirà — che è esattamente il disegno.

> 🔴 **Trovato misurando: la partenza `1588` ha anno `8202`** (19/01/8202 – 27/01/8202,
> azienda 2) e **12 iscritti veri attaccati**. È il terzo refuso d'anno della stessa famiglia — il
> `262` del bug 9 e la transazione 72 con `2202` — e stavolta è sfuggito perché il vincolo
> `chk_data_viaggio_anno_plausibile` è nato **dopo** questo dato. Due conseguenze concrete:
> risulta **futura per sempre**, quindi falsa ogni conteggio sulle partenze a venire (ha falsato
> anche questa misura, che l'ha contata come imminente); e con le guardie del bug 8 **non è più
> eliminabile** finché l'anno non viene corretto.
>
> ✅ **CORRETTA su PROD il 2026-09-01.** Ora `2026-08-19` → `2026-08-27`, nove giorni, coerente con
> la durata dichiarata e con le dodici iscrizioni (l'ultima è del 10 agosto, nove giorni prima della
> partenza). Ricontrollata l'intera tabella: su **150 partenze**, zero anni fuori dal 2000–2100,
> zero date di fine precedenti all'inizio, zero partenze future segnate come effettuate.
> ⚠️ La correzione è avvenuta **in due passaggi**: il primo aveva sistemato solo l'anno lasciando il
> mese di gennaio, e il dato sembrava a posto. Ciò che ha svelato l'errore residuo non è stata una
> data ma **le iscrizioni**: dieci su dodici registrate fra giugno e agosto, cioè *dopo* una
> partenza di gennaio. Nessuno si iscrive a un viaggio già fatto.
>
> **Date vere accertate il 2026-09-01** (chieste al committente): la partenza è
> **19–27 agosto 2026**, ed è realmente conclusa — quindi `data_viaggio_effettuato_sino = 'Y'` è
> corretto e non va toccato. **Il giorno era giusto**: sbagliati sono anno *e* mese, `8202-01`
> invece di `2026-08`. Correzione da applicare su PROD:
>
> ```sql
> UPDATE ana_date_viaggi
>    SET data_viaggio_data_inizio = DATE '2026-08-19',
>        data_viaggio_data_fine   = DATE '2026-08-27'
>  WHERE data_viaggio_id = 1588
>    AND data_viaggio_data_inizio = DATE '8202-01-19';   -- guardia: non tocca nulla se già corretta
> ```
>
> ⚠️ **Quello che questo caso insegna vale più della riga da correggere.** Il dato è stato scritto
> su PROD il **2026-08-31 alle 15:24**, dalla versione 1.35 — cioè *mentre* collaudavamo le difese
> che lo impediscono. E la forma dell'errore (giorno intatto, anno e mese scambiati e stravolti) è
> la stessa che si è manifestata in collaudo digitando in fretta in un campo data: il valore viene
> ricomposto male mentre si scrive. Non è quindi un refuso d'utente isolato come il `262` o il
> `2202`: è un **difetto della maschera data che in produzione sta corrompendo dati reali**, e il
> vincolo di plausibilità dell'anno lo intercetta solo quando l'anno finisce fuori scala — qui per
> fortuna è successo. Un `2026-01-19` al posto di `2026-08-19` sarebbe passato senza che nessuno se
> ne accorgesse.

---

### 2.10 — DA FARE A MANO: MAIORCA MARIA è doppia
Nell'azienda 2 ci sono **due schede MAIORCA MARIA**, stessa data di nascita:

| id | email | creata |
|---|---|---|
| 3324 | mariamaio1@hotmail.it | 07/06/2025 |
| 3327 | *(nessuna)* | 08/06/2025 |

Non c'entra con i silos: le ha inserite la segreteria a un giorno di distanza. **Adriano
la sistema a mano** (deciso il 2026-09-05) — nessuno script la tocca, perché fondere due
anagrafiche significa decidere quale storia tenere, e quella decisione è dell'azienda.

☐ Fatto — verifica: `SELECT count(*) FROM ana_clienti WHERE azienda_fk = 2
AND upper(btrim(cliente_cognome))='MAIORCA' AND upper(btrim(cliente_nome))='MARIA';`
deve dare 1.

---

### 2.11 — DA FARE A MANO: GENDUSO FRANCESCA non ha la data di nascita
Cliente `3023` dell'azienda 2, **senza email e senza data di nascita**. Lo script 593
risolve il caso di chi è riconoscibile, ma lei non lo è: senza data di nascita la regola
di riconoscimento (`STESSA_ANAGRAFICA`) non scatta, quindi presentandosi sul sito
creerebbe una **scheda doppia**.

☐ Completare la sua scheda dal gestionale (data di nascita, e l'email se la si ha).

---

### 2.12 — 27 clienti su 206 non potranno iscriversi finché non si completano
Misurato su PROD (azienda 2) il 2026-09-05. Le regole di completezza dell'anagrafica
(`fn_ana_clienti_campi_mancanti`, script 563) sono **nuove**: nascono in questo ciclo. I
clienti inseriti prima non le hanno mai attraversate.

| Cosa manca | Clienti |
|---|---|
| Documento incompleto (tipo, numero, ente, rilascio o scadenza) | **21** |
| Indirizzo di residenza | **8** |
| Data di nascita | **2** |
| **Almeno una di queste** | **27 su 206 (13%)** |

⚠️ **Conseguenza operativa da dire ad Antonio prima del go-live**: `fn_mov_clienti_viaggi_valida`
rifiuta l'iscrizione di chi ha l'anagrafica incompleta — **dal gestionale e dal sito**.
Quelle 27 persone non si potranno iscrivere a un viaggio finché qualcuno non completa la
loro scheda. Non è un difetto: è la regola dei documenti obbligatori per legge che entra in
vigore su dati raccolti quando non c'era. Ma se nessuno lo sa in anticipo, il giorno del
go-live sembra che il software si sia rotto.

☐ Elenco delle 27 schede consegnato ad Antonio
☐ Deciso se completarle prima del go-live o man mano che si iscrivono

Query per l'elenco:

```sql
SELECT cliente_id, cliente_cognome, cliente_nome,
       string_agg(m.etichetta, ', ') AS cosa_manca
FROM ana_clienti c
CROSS JOIN LATERAL fn_ana_clienti_campi_mancanti(to_jsonb(c), FALSE) m
WHERE c.azienda_fk = 2
GROUP BY 1,2,3 ORDER BY 2,3;
```

---

### 2.14 — DA FARE PRIMA DEL GO-LIVE: la stessa ricognizione su TUTTO il sito

Chiesto da Adriano il 2026-09-07: «bisogna tornare su Flask per fare una verifica più
profonda e uniformare tutte le chiamate compresi i CRUD tra MAUI e Flask».

Quella fatta finora ha coperto **solo le sistemazioni**, ed è bastata a trovare: cinque
regole duplicate nel JavaScript, ⚠️ **nove funzioni che scrivevano sulla stessa tabella** —
quattro delle quali senza alcun controllo — e nessuna che guardasse il genere del viaggio.

⚠️ **Non c'è motivo di credere che le sistemazioni fossero un caso isolato.** Le altre aree
dove il sito e il gestionale toccano gli stessi dati, e che vanno guardate allo stesso modo:

| Area | Cosa verificare |
|---|---|
| **Anagrafica cliente** | Già misurata il 2026-08-20 e già nota: 17 validator in C#, **un solo CHECK a database**. È il caso peggiore conosciuto |
| **Iscrizione al viaggio** (`mov_clienti_viaggi`) | Quante funzioni scrivono? Il sito e il gestionale usano la stessa? |
| **Mezzi** (marca, modello, targa) | Il sito ha il passaggio del tipo, il gestionale l'ha aggiunto dopo: le regole coincidono? |
| **Documenti d'identità** | Già unificati col `585`, ma va verificato che il sito usi davvero `fn_ana_tipo_documento_get_all` |
| **Consensi e newsletter** | Il sito raccoglie, il gestionale invia: una regola sola su chi si può contattare |

**Il metodo che ha funzionato**, da ripetere tale e quale: contare **chi scrive** ogni
tabella con una query su `pg_proc`, poi contare **chi le chiama** da C# e da Python. Le
funzioni senza chiamanti non sono innocue: sono la prossima strada che qualcuno prenderà.

---

### 2.13 — DA SCRIVERE PRIMA DELLA CONSEGNA: il manuale di cosa è cambiato

⛔️ **Non è documentazione di cortesia: senza, l'operatore fa danni.** Deciso da Adriano il
2026-09-06, dopo aver visto lui stesso quanto è facile prendere la strada sbagliata.

Il 5 e 6 settembre la gestione delle sistemazioni è cambiata da cima a fondo: capienza
rigorosa, generi di sistemazione, spostamento fra camere, cancellazione che chiede cosa
diventa la camera di chi resta. ⚠️ **Chi usa il programma non ha modo di dedurre da solo il
percorso giusto**, e quello sbagliato non dà errori — porta a camere singole create e poi
cambiate, con stati intermedi che sembrano corretti.

Destinatari: Antonio oggi, e chi verrà dopo di lui.

**Cosa il manuale deve spiegare, come minimo:**

1. ⚠️ **Come si iscrive una coppia** — questa è la parte che serve davvero.
   La strada giusta: **spegnere «Assegna camera»**, iscrivere tutti e due, poi dalla linguetta
   **«Partecipanti senza camere» → Assegna** comporre **una sola** matrimoniale.
   La strada sbagliata (che viene naturale): iscrivere il primo con una singola e poi
   correggere. Funziona, ⛔️ **ma nel mezzo il database dice che lui ha una singola** — e se in
   quel momento qualcuno stampa la rooming list per l'albergo, quella singola ci finisce
   dentro. Un dato sbagliato che sembra giusto è peggio di uno mancante, che almeno è
   segnalato in giallo.
   Regola pratica da scrivere in grassetto: **quando sai già che dormiranno insieme, non
   assegnare la camera al momento dell'iscrizione.**
   ⚠️ **Dal 2026-09-07 questa è la strada preimpostata**: l'interruttore «Assegna la camera
   adesso» nasce **spento**, e le due attività — iscrivere e sistemare — sono separate, come
   erano su Oracle. Il manuale deve spiegare che è una scelta, non una dimenticanza: chi
   arriva da una versione precedente si aspetta di trovarlo acceso.

2. **La capienza deve corrispondere**: non esistono camere «a metà». Le eccezioni con
   l'albergo — una doppia pagata a uso singola — si gestiscono fuori dal programma
   (decisione del 2026-09-06).

3. **Le due porte per comporre le sistemazioni**: la **matita** su una camera che c'è già,
   **Assegna** su chi non ce l'ha. Non ce ne sono altre, e non servono.

4. **Cosa succede togliendo qualcuno da una camera**: la domanda «partecipa ancora al
   viaggio?», e perché non si può rimandare la risposta.

5. **Il genere della sistemazione**: perché su un viaggio in tenda non compaiono le camere
   d'albergo, e dove si configura (Tipologie di Pernottamento → sistemazioni previste).

6. **Le sistemazioni che non si propongono da sole** (camere attrezzate per disabili): ci sono
   in elenco, non vengono suggerite, e perché.

7. **L'interruttore «Assegna la camera adesso» nasce SPENTO** (dal 2026-09-07). ⚠️ Chi arriva
   dalla versione precedente si aspetta di trovarlo acceso: va detto che è una scelta e non
   una dimenticanza, altrimenti la prima cosa che farà sarà riaccenderlo e tornare al problema
   del punto 1. Iscrivere e sistemare sono due lavori distinti, come erano su Oracle.

8. **La linguetta «Partecipanti senza camere»**: compare solo quando c'è qualcuno da
   sistemare, elenca i nomi, e da lì si assegna. È il posto in cui si finisce il lavoro
   lasciato aperto dal punto 7 — e il fatto che sparisca da sola è il segnale che non è
   rimasto niente indietro.

9. **«Iscrizione Veloce — solo pilota»**: che cosa fa e cosa non fa. Iscrive **una** persona
   che viaggia da sola e le dà subito una sistemazione da un posto; per una coppia o una
   famiglia si passa da «Gestisci Partecipanti». ⚠️ Lì l'interruttore è invece **acceso**, ed
   è voluto: è l'unica scheda dove la sistemazione si conosce già.

⚠️ **Con gli screenshot** (chiesto da Adriano il 2026-09-07). Questa parte non si spiega a
parole: le schede sono cambiate — l'interruttore, la linguetta nuova, la finestra «Dove dorme
X», la domanda «partecipa ancora al viaggio?» — e chi legge deve riconoscere quello che ha
davanti. Le immagini vanno prese **dopo** che il comportamento è fermo, altrimenti invecchiano
prima del testo.

⚠️ Da scrivere **al momento della consegna**, non prima: fino ad allora il comportamento può
ancora cambiare, e un manuale che non corrisponde è peggio di nessun manuale. ⚠️ Il conto dei
punti è salito da 6 a 9 in un solo giorno di prove: è la misura di quanto è cambiato, e del
perché senza manuale l'operatore non ci arriva da solo.

## 3. Configurazione applicativa PROD (fuori dal DB)

> ⚠️ **Questa sezione è quella che fa fallire una consegna.** Il DB può essere perfetto: se l'eseguibile parte sulla macchina del cliente senza queste configurazioni, le schede che toccano segreti (Traduzioni, SMTP) si presentano con le funzioni disabilitate. Prima di consegnare, eseguire la **§3.3 Prova di consegna**.

### 3.1 — `GV_SECRET_KEY` (master key dei segreti) — la voce più insidiosa

Cifra e decifra SMTP, ESP e chiave Claude (pgcrypto, §2.2). Va letta dall'**ambiente del processo** dell'app: `Environment.GetEnvironmentVariable("GV_SECRET_KEY")`.

**Regole non negoziabili:**
- **La stessa identica stringa** su tutte le installazioni che condividono il DB. Chiavi diverse = segreti scritti da una postazione illeggibili dall'altra (`Wrong key or corrupt data`).
- **Non** finisce in git né dentro il pacchetto dell'app: è configurazione d'ambiente, non un file dell'applicativo.
- Cambiarla dopo aver salvato dei segreti li rende **irrecuperabili**: vanno re-inseriti dalle form.

**Come impostarla, per sistema operativo:**

| Ambiente | Comando | Ambito |
|---|---|---|
| **Windows 11** (macchina cliente) | `setx GV_SECRET_KEY "<valore>" /M` da **prompt come amministratore** | tutte le utenze della macchina |
| Windows 11 (solo utente corrente) | `setx GV_SECRET_KEY "<valore>"` | utente corrente |
| macOS — avvio da terminale | `export` in `~/.zshrc`, oppure il file locale caricato da `run_maui.sh` | shell |
| macOS — avvio da Finder/IDE | `launchctl setenv GV_SECRET_KEY "<valore>"` | app grafiche, **fino al riavvio** |

⚠️ **Trappola verificata sul campo (2026-07-27):** su macOS un'app lanciata da **Finder o dall'IDE non eredita** gli `export` di `~/.zshrc` — la variabile risulta assente e le funzioni sui segreti si disabilitano. Per questo `run_maui.sh` carica da sé la master key. Su **Windows** vale lo stesso principio con una differenza importante: `setx` **non tocca i processi già avviati**, quindi dopo averla impostata bisogna **chiudere e riaprire** il prompt (o fare logout/login) prima di lanciare l'app, altrimenti sembra che non abbia funzionato.

**Come verificare che l'app la veda davvero** (non basta che il sistema la conosca):
- Windows: `echo %GV_SECRET_KEY%` in un prompt **nuovo**; poi avviare l'app e aprire una scheda **Traduzioni**.
- macOS: `ps eww <pid-app> | tr ' ' '\n' | grep GV_SECRET_KEY` sul processo dell'app in esecuzione.
- **Prova che vale per entrambi:** aprire la scheda **Traduzioni** di un tour. Se compare l'avviso *"Master key dei segreti non disponibile"*, l'app **non** la sta vedendo, comunque sia configurato il sistema.

### 3.2 — Resto della configurazione

- [ ] **Supabase**: connection string PROD, `Service Key` (Storage), eventuale `anon key`.
- [ ] **Geoapify** API key (Blocco 9, generazione mappe statiche). Senza, il tab Mappa avvisa e disabilita la generazione.
- [ ] **Chiave Claude per-azienda** (Blocco 10/11 traduzioni + newsletter) — via UI form azienda, salvata cifrata (§2.2). **Richiede `GV_SECRET_KEY` già attiva**: senza, la form non permette nemmeno di salvarla.
- [ ] **SMTP per-azienda** (invio email/newsletter) — via config azienda, cifrata (§2.2). Stessa dipendenza dalla master key.
- [ ] **`sito_web` azienda** valorizzato: base URL usata per costruire il link di disiscrizione (`{sito_web}/unsubscribe?...`). La verifica HMAC lato sito è **Fase 3** (sito pubblico) — non ancora implementata.
- [ ] Connection pool PROD: MaxPoolSize=10, MinPoolSize=0, IdleLifetime=180s, ConnectionLifetime=600s (già in config).
- [ ] **Prezzi Claude per la stima dei consumi** (sezione `Claude` in appsettings: `PrezzoInputPerMilione`, `PrezzoOutputPerMilione`, `Valuta`). Sono valori di **configurazione**, non letti dall'API. Listino verificato il **2026-07-28** su `platform.claude.com/docs/en/docs/about-claude/pricing`:

  | Modello | Input / MTok | Output / MTok |
  |---|---|---|
  | **Claude Haiku 4.5** ← in uso (`claude-haiku-4-5-20251001`) | **$1** | **$5** |
  | Claude Sonnet 5 | $2 (introduttivo fino al 31/08/2026, poi $3) | $10 (poi $15) |
  | Claude Opus 5 | $5 | $25 |

  I default in codice **coincidono** con Haiku 4.5, quindi non serve toccarli finché non si cambia modello. Il gestionale **ricorda da solo** di ricontrollare: passati 90 giorni dall'ultima conferma, la scheda Traduzioni dell'anagrafica azienda mostra un avviso con il link al listino e il pulsante *"Ho verificato oggi"*. Non legge i prezzi da internet: Anthropic non ha un'API dei prezzi (`/v1/models` non li espone) e interpretare la pagina di documentazione si romperebbe in silenzio. ⚠️ Se cambi i prezzi in `appsettings`, aggiorna anche `ClaudeOptions.DataVerificaPrezzi` nel codice, altrimenti il promemoria dichiara una data di verifica falsa. Ricontrollare il listino prima della consegna: il costo viene congelato su ogni riga al momento della chiamata, quindi correggere i prezzi **non** ricalcola lo storico. La stima non considera prompt caching né Batch API (non usati).
  Ordine di grandezza utile: tradurre un tour completo (~20 campi × 4 lingue) costa circa **$0,30**.
- [ ] **Soglia di spesa Claude** (facoltativa, dalla scheda Traduzioni dell'anagrafica azienda): al 90% parte un avviso in app e **una** email all'indirizzo principale dell'azienda — quindi serve un'email principale valorizzata e l'SMTP funzionante.
- [ ] `appsettings.json` della macchina cliente: connection string, `WebMediaStorage:Bucket` = `tour-media` (non `tour-media-dev`), `Geoapify:ApiKey`. Ricorda che questi file sono **per-macchina** e non arrivano da git (vedi nota su `skip-worktree`).

### 3.3 — Prova di consegna (da fare PRIMA di dare l'eseguibile al cliente)

Sulla macchina di destinazione, con l'utenza con cui lavorerà il cliente, e con l'app **riavviata** dopo aver impostato le variabili:

- [ ] L'app si avvia e si collega al DB PROD (non a Docker locale: controllare la connection string).
- [ ] Scheda **Traduzioni** di un tour: **nessun** avviso sulla master key; il pulsante "Salva chiave" è attivo.
- [ ] Salvataggio e rilettura di un segreto: inserire la chiave Claude, salvare, riaprire la scheda → risulta configurata. Questo prova end-to-end che cifratura e decifratura funzionano con la key di quella macchina.
- [ ] Scheda **Mappa**: nessun avviso su Geoapify; una generazione di prova produce l'immagine (verifica anche il bucket Storage, §2.4).
- [ ] Invio email di prova dalla configurazione SMTP dell'azienda (attenzione: [[smtp-tests-require-vpn-off]]).
- [ ] Un tour di prova arriva a **pubblicato**, quindi il gating (contenuti completi + traduzioni revisionate) è soddisfacibile su quella macchina.

---

### 3.4 — Manuale utente: il capitolo sugli stati dei contenuti web (da scrivere PRIMA della consegna)

Durante i test è emerso che il comportamento dei contenuti web è **corretto ma non ovvio**: diverse regole,
prese singolarmente, sembrano difetti del programma finché non si conosce il motivo. Vanno raccolte e
spiegate **in linguaggio semplice** nel manuale, non lasciate ai soli messaggi dell'interfaccia.

Argomenti che il capitolo deve coprire:

- [ ] **I tre stati di una scheda** — *bozza*, *pubblicato*, *archiviato*. In particolare: **archiviato,
      per il sito, è identico a bozza**; la differenza è solo editoriale (finito e da non toccare, contro
      in lavorazione). Chi si aspetta che "archiviato" faccia qualcosa di diverso resta spiazzato.
- [ ] **Il controllo scatta al salvataggio, non alla scelta della voce.** Si seleziona "Pubblicato", si
      salva, e se manca qualcosa il programma riporta a "Bozza" spiegando cosa. Senza saperlo sembra che
      il campo non funzioni.
- [ ] **Cosa serve per pubblicare**: tutte le sezioni complete (icone verdi), **traduzioni revisionate**
      — non basta che siano tradotte — e una partenza che **deve ancora iniziare** e non è segnata come
      effettuata.
- [ ] **Il tour sparisce dal sito da solo** quando la partenza inizia, pur restando "Pubblicato". Va detto
      chiaramente, insieme al perché non esiste un automatismo che cambi lo stato: il tempo che passa non
      produce nessun evento sul database, quindi il filtro è in lettura.
- [ ] **Lo stato della partenza** (chip con il flag "effettuato" incrociato col calendario) e i suoi
      **quattro casi**, comprese le due anomalie: conclusa ma non spuntata, spuntata ma non ancora conclusa.
      Spiegare dove si corregge.
- [ ] **Clonazione** da un'altra partenza: cosa viene copiato (compresi itinerario, mappe e traduzioni già
      approvate), che la copia nasce sempre in **bozza**, e che **foto e mappe restano gli stessi file**
      dell'originale — eliminare un media dalla scheda di origine lo toglie anche alla copia.
- [ ] **Clonazione fra partenze di durata diversa**: quando succede (il numero di giorni del viaggio è stato
      cambiato in anagrafica dopo), cosa chiede il programma, e perché **l'ultima giornata clonata va
      riscritta a mano** — in un viaggio più corto il finale cambia e non è una decisione automatizzabile.
- [ ] **Eliminare una scheda web**: possibile solo da bozza o archiviato, **irreversibile**, e porta via
      giornate, foto, mappe e traduzioni revisionate. I file restano in archivio perché possono essere
      condivisi con una copia.
- [ ] **Eliminare una partenza**: **non si cancella lo storico**. Una partenza effettuata o già iniziata è
      rifiutata; lo sono anche quelle con una scheda web o con prenotazioni. Spiegare l'ordine dei
      controlli e che una data inserita per sbaglio nel passato si corregge e poi si elimina.
- [ ] **Le verifiche non bloccanti** (giornate senza foto o senza mappa, incluso/escluso vuoti…): sono
      promemoria, non errori, e non impediscono di pubblicare.
- [ ] **Traduzioni**: perché la revisione è obbligatoria per pubblicare, cosa fa "traduci mancanti" rispetto
      a "traduci tutto", e che ogni traduzione ha un **costo** (registro consumi e soglia di spesa).

**Materiale già pronto da cui attingere** — il testo semplice esiste già, va raccolto:
- i popover "?" nella scheda Contenuti (in particolare quello sullo **stato di pubblicazione**, il più esteso);
- `Documentazione_Versioni/Note_Rilascio_Versione_2_0.md`, Sezione 1 (funzionalità) e Sezione 2 (bug risolti,
  righe 6 e 8: stato della partenza e cancellazione);
- `2026-07-09-Piano_Test_Estensione_Web.md`, sezioni **26–32**: ogni caso di prova è di fatto una regola
  raccontata a parole;
- le testate dei relativi script SQL (`505`–`508`), che contengono il *perché* di ogni scelta.

---

### 3.5 — Verifica date su PROD (fatta il 2026-08-01, sola lettura)

Controllo eseguito su Supabase dopo aver scoperto il refuso sull'anno (bug 9 delle note di rilascio).
Sono state esaminate **tutte le 108 colonne data/ora** dello schema `public` cercando anni fuori da 1900–2100.

**Esito:**

- ✅ **`ana_date_viaggi` è pulita**: 150 partenze, dalla più antica **09/02/2019** alla più lontana
  **04/12/2026**, nessuna fuori da 2000–2100. Lo **script `509` si applica senza riparazioni**.
- ✅ Nessuna data di nascita cliente implausibile, nessuna transazione o partenza collocata molto avanti
  nel futuro.
- ✅ **Verifica estesa a clienti e aziende (2026-08-01)**: nessuna data di nascita futura o precedente al 1900,
  nessun documento con rilascio futuro o scadenza fuori scala, nessuna azienda con costituzione, inizio
  attività o iscrizione REA futura o precedente al 1900. **Zero righe da correggere.**
- ⚠️ **Una data sbagliata trovata**, in contabilità:

  | tabella | id | campo | valore | valore corretto (evidente) |
  |---|---|---|---|---|
  | `mov_transazioni` | **72** | `transazione_data_pagamento` | **20/02/2202** | 20/02/2022 |

  Sulla stessa riga `transazione_data` è **20/02/2022**: stesso giorno e stesso mese, quindi il pagamento
  era certamente del 2022. Importo 110,00 — causale BENZINA — stato PAGATO — azienda 6.
  **Stessa identica classe di errore** del bug 9: `2022` → `2202`, una cifra fuori posto. Conferma
  indipendente del meccanismo, su un'altra form e per mano di un altro utente.

- [x] **Corretta su PROD il 2026-08-01** (una riga, `UPDATE` condizionato al valore sbagliato, verificato prima e dopo):

  ```sql
  UPDATE mov_transazioni SET transazione_data_pagamento = DATE '2022-02-20'
   WHERE transazione_id = 72 AND transazione_data_pagamento = DATE '2202-02-20';
  ```

- [x] **Protezione estesa alle altre form il 2026-08-01.** `DateFormat` aggiunto a tutti i **16** campi che ne erano privi, e validazione di plausibilità aggiunta alle form che registrano dati. Erano coinvolti:
  `MovTransazioniEditDialog` (Data Transazione, Data Documento, Data Scadenza, Data Pagamento),
  `PagaOraDialog`, `MovTransazioniPage` e i dialoghi di stampa (bilancio, scadenzario, registro IVA, movimenti).
  Senza `DateFormat`, su una macchina con lingua di sistema non italiana quei campi avrebbero
  **scambiato giorno e mese** senza segnalare nulla.

---

### 3.6 — Domini, brand e deliverability email (verificato il 2026-08-06)

> Nessuno script SQL coinvolto, ma tocca **due voci di configurazione già in §3.2** (`sito_web` azienda,
> SMTP per-azienda) e può invalidare newsletter **già spedite**. Va deciso **prima** del go-live, non dopo.

### Stato reale dei domini (WHOIS, 2026-08-06)

| Dominio | Stato |
|---|---|
| `sardegnafuoritraccia.it` | **Registrato dal 14/03/2016**, scadenza **04/05/2027**, registrar **Netsons**, intestato a *Sardegna Fuori Traccia* (l'azienda, non l'agenzia). Sito live, **e ci gira la posta aziendale** (`mail.sardegnafuoritraccia.it`) |
| `sardegnafuoritraccia.com` | **Mai registrato da nessuno.** In corso di acquisto dal cliente su Aruba (2026-08-05) |
| `sardegnafuoritraccia.net` / `.eu` | Mai registrati |

### Rebrand in valutazione

Il cliente sta valutando di **abbandonare "Sardegna" dal nome** per non restare legato a una sola
destinazione. La decisione non è ancora presa, ma **condiziona il go-live**: finché il dominio
definitivo non è deciso, le voci qui sotto non sono chiudibili.

Stato della scelta al 2026-08-06: il candidato preferito (**OFFTRACE**) è bloccato sul costo del
dominio — `offtrace.com` è sul mercato secondario a **$7.888** (offerta minima accettata **$4.999**).
Anche il semplice **"Fuori Traccia"** senza "Sardegna" **non è disponibile**: `fuoritraccia.com` è
occupato dal 2005 e `fuoritraccia.it` dal 2022 (privato, dominio parcheggiato). La scelta reale è
fra pagare un dominio premium a quattro cifre o adottare un nome composto/coniato con il `.com`
libero.

### Cosa comporta per il rilascio

- [ ] **`sito_web` dell'azienda (§3.2) deve puntare al dominio DEFINITIVO prima del primo invio newsletter.**
      È la base URL con cui si costruisce il link di disiscrizione (`{sito_web}/unsubscribe?...`). Le email
      già spedite conservano il link com'era: se il dominio cambia dopo, quei link puntano nel vuoto e
      l'iscritto non può più disiscriversi — che è un problema di conformità, non solo di cortesia.
- [ ] **Il dominio `.it` non va MAI lasciato scadere**, nemmeno dopo un eventuale rebrand: ci gira la posta
      aziendale e l'SMTP usato dal motore newsletter (§3.2). Perderlo significa perdere la posta, non solo
      il sito. Scadenza attuale: **04/05/2027** — a calendario, con rinnovo automatico attivo.
- [ ] **Registrar frammentati**: `.it` su Netsons, `.com` in acquisto su Aruba. Due pannelli e due scadenze
      distinte sono il modo classico in cui un dominio si perde per un rinnovo non visto. **Consolidare su
      un unico registrar** o quantomeno verificare il rinnovo automatico su entrambi.
- [ ] **Se cambia il dominio mittente delle email**: SPF, DKIM e DMARC vanno rifatti sul dominio nuovo, e la
      **reputazione di invio riparte da zero**. Una newsletter sparata a tutta la lista da un dominio appena
      registrato finisce in spam. Serve un *warm-up*: primi invii a volumi bassi, crescendo nei giorni
      successivi. Da pianificare **prima** del primo invio massivo, non quando ci si accorge del problema.
- [ ] **Redirect 301 dal dominio storico** verso quello nuovo, da mantenere per anni: il `.it` ha 10 anni di
      posizionamento e di link esterni. È lavoro di Fase 3 (sito pubblico), ma la decisione sul nome è
      un prerequisito.

---

### 3.7 — La consegna è **un evento solo, con tre componenti**

Fino a luglio 2026 il rilascio era una cosa sola: la nuova versione del gestionale. Dopo la
centralizzazione dei controlli non lo è più. Le regole di `ana_clienti` e dell'iscrizione ora
vivono nel database, e **tutti e tre** i pezzi devono arrivare insieme, perché nessuno dei tre
funziona con gli altri due vecchi.

### L'ordine non è negoziabile

| | Cosa | Perché in questa posizione |
|---|---|---|
| 1 | **Script DB** `406` → `585` su Supabase, in ordine numerico | Le funzioni devono esistere prima che qualcuno le chiami |
| 2 | **Flask nuovo** in produzione | Chiama funzioni che prima del passo 1 non esistono |
| 3 | **MAUI 2.0** consegnata | Idem, e i client vanno aggiornati dopo lo schema |

### La finestra fra il passo 1 e il 2 è il momento pericoloso

Appena applicati gli script, **il sito vecchio smette di funzionare**: chiama
`fn_wizard_insert_cliente`, `fn_wizard_check_cf_esistenza`, `fn_wizard_get_smtp_config` — funzioni
che il nuovo assetto ha sostituito. Non degrada: si rompe.

Quindi la finestra va tenuta stretta, e provata **prima** in staging. Se il sito riceve iscrizioni
in quelle ore, meglio metterlo in manutenzione per la durata del passaggio che lasciarlo rispondere
con errori a chi si sta iscrivendo.

### Il rischio speculare, che è peggiore

Applicare gli script e **non** aggiornare uno dei due client non dà un errore visibile: dà un
software che scrive senza i controlli nuovi. È così che sono nati i problemi che questo lavoro ha
chiuso — una scheda cliente duplicata creata dal sito il 2026-05-13, direttamente su produzione,
con `created_by` vuoto.

### Prima di dichiarare fatto

- [ ] I due piani di test eseguiti: `Documents/2026-08-20-Piano_Test_MAUI.md` e
      `Documents/2026-08-20-Piano_Test_Flask.md`
- [ ] In particolare il **gruppo F** del piano Flask (prova incrociata): la stessa anagrafica
      sbagliata rifiutata da entrambi i software, con lo stesso messaggio
- [ ] `GV_SECRET_KEY` presente nell'ambiente di **entrambi** i processi
- [ ] Verificato nel log del sito: `Flask-Mail inizializzato da DB (…)`
- [ ] Backfill `cliente_lingua` eseguito (§2.5)
- [ ] Solo **dopo** che tutto gira: eliminare le funzioni dell'elenco di ritiro
      (`Documents/Funzioni_DB.md`, sezione «Elenco di ritiro»). Non prima: restano in piedi finché
      non si è verificato che nessun altro software le usi

---

### 3.8 — `MAIL_DIROTTA_A` NON deve esistere in produzione
In sviluppo tutta la posta viene dirottata su un solo indirizzo (`.env.local`), perché il
database locale è di test ma **il server di posta e i destinatari sono quelli veri**: il
2026-09-05 una prova di iscrizione ha mandato una conferma a un cliente reale e la notifica
alla segreteria (difetto 80).

⚠️ **Se quella variabile finisce in produzione, nessun cliente riceve più niente** — e non
se ne accorgerebbe nessuno subito, perché gli invii risultano riusciti. Verificare che
l'ambiente del processo Flask in PROD **non** la contenga:

```bash
# sul server, prima di dichiarare fatto il go-live
grep -c MAIL_DIROTTA_A .env    # deve dare 0
```

---

## 4. Checklist finale di rilascio

- [ ] Applicati in ordine i **114** script 406–524 su PROD (§1) senza errori, **escluso `499_Rollback_EstensioneWeb.sql`**.
- [ ] Eseguite **prima** le query di pre-verifica degli script che possono fallire su dati sporchi: `491` (descrizioni < 3 caratteri, ordine < 1) e `509` (anni fuori 2000–2100).
- [ ] Ruolo `anon` + RLS riconciliati e verificati in staging (§2.1).
- [ ] **Cifratura reale segreti implementata** e segreti caricati (§2.2). ← bloccante
- [ ] `token_iscrizione` valorizzato per ogni azienda (§2.3).
- [ ] Bucket Supabase Storage creati + policy (§2.4).
- [ ] Backfill `cliente_lingua` eseguito e verificato (§2.5).
- [ ] Migrati i **dati** di `web_tipi_viaggio_descrizioni` (+ traduzioni) e `ana_tipo_viaggi` da TEST a PROD, nell'ordine e con FK coerenti, **sequence identity riallineate** (§2.6).
- [ ] Config app PROD completata (§3), **`GV_SECRET_KEY` verificata sulla macchina del cliente** (§3.1) e **Prova di consegna superata** (§3.3) — è il passo che evita di consegnare un'app con le funzioni sui segreti spente.
- [ ] **Dominio definitivo deciso** (rebrand sì/no) e `sito_web` azienda valorizzato di conseguenza **prima del primo invio newsletter**; SPF/DKIM/DMARC + warm-up pianificati se il dominio mittente cambia (§3.6). ← condiziona i link di disiscrizione già spediti
- [ ] **`GV_SECRET_KEY` nell'ambiente del processo Flask** — il sito legge la configurazione SMTP dell'azienda con `fn_get_smtp_config_for_email`, la stessa funzione del gestionale, e la password è cifrata con pgcrypto. Senza la chiave la posta resta spenta — con un avviso esplicito nel log — e **non parte nessuna conferma di iscrizione**.

  **È la stessa chiave del gestionale, non una seconda.** Una chiave diversa non dà «password errata»: rende il dato illeggibile (`Wrong key or corrupt data`). Se in PROD si cifrassero i segreti con una chiave e si leggessero con un'altra, il guasto si scoprirebbe solo alla prima email non partita.

  **Dov'è oggi (macchina di sviluppo):** un unico file,
  `MAUI/GestioneViaggi/.gv_secret_key.local.sh`, contenente `export GV_SECRET_KEY=…`.
  Lo caricano `~/.zshrc` (quindi ogni terminale interattivo la esporta) e `run_maui.sh`.
  Nel repository Flask c'è un **symlink** allo stesso file, non una copia: il segreto resta in un posto solo. Entrambi i file sono gitignored e non tracciati.

  **In PROD** il file di sviluppo non esiste, e la chiave va messa nell'ambiente del processo che serve l'applicazione. In ordine di preferenza:

  1. **systemd** — nell'unit di gunicorn:
     `Environment="GV_SECRET_KEY=…"`, oppure `EnvironmentFile=/etc/gestioneviaggi/segreti.env` con il file a `chmod 600` e proprietario l'utente del servizio. È l'opzione migliore: la chiave non sta in nessun file del progetto.
  2. **Pannello dell'hosting** — se il sito gira su una piattaforma con gestione variabili d'ambiente, si imposta lì.
  3. **File accanto allo script** — `.gv_secret_key.local.sh` nella cartella del progetto, che `start_prod.sh` carica da solo. Comodo, ma mette il segreto sul disco dell'applicazione: da usare solo se le prime due non sono praticabili, e comunque `chmod 600`.

  ⚠️ **Non** metterla in `.env`: quel file viene sovrascritto da `avvia-locale.sh` / `avvia-supabase.sh`, e la chiave sparirebbe al primo cambio di ambiente.

  **Come si verifica che sia a posto**, senza stampare il segreto: avviare il sito e leggere il log. Deve comparire
  `Flask-Mail inizializzato da DB (Server=…, Porta=…, Security=…)`.
  Se compare invece `GV_SECRET_KEY non impostata` o `Nessuna configurazione SMTP utilizzabile`, la chiave manca o è quella sbagliata.
- [ ] **Sito di iscrizione ai viaggi rivisto (§2.8)** — consenso email raccolto alla fonte con data e fonte (§2.8.1), avviso nome/sesso replicato (§2.8.2), titolo/sesso allineati (§2.8.3), controlli del CRUD cliente confrontati con quelli del gestionale (§2.8.4). ← **prerequisito**: dopo il deploy degli script il sito scrive su uno schema che non rispetta, e quei dati non si sistemano più
- [ ] Eseguito il Piano di Test (`2026-07-09-Piano_Test_Estensione_Web.md`) end-to-end.
- [x] Corretta la data errata di `mov_transazioni` id 72 e allineati i campi data delle altre form (§3.5) — fatto il 2026-08-01.
- [ ] **Manuale utente scritto**, con il capitolo sugli stati dei contenuti web, la pubblicabilità, la clonazione e le cancellazioni (§3.4). ← senza, il cliente scambierà per difetti comportamenti voluti
- [ ] `Documents/Funzioni_DB.md` allineato allo stato PROD.

---

## 6. Dati e contenuti da portare in PROD

Contenuti che non arrivano con gli script: vanno caricati a parte, e nessuno se ne
accorge se restano indietro — il software funziona lo stesso, solo senza contenuti.

### 6.1 — Modelli di newsletter da portare in PROD
Oltre agli script, vanno **copiati i dati**: i modelli di newsletter composti qui in locale
servono ad Antonio come base di partenza, invece di farlo ricominciare da una pagina bianca.

**Cosa copiare:** le righe di `web_newsletter_invii` con `is_modello = true` e **tutti** i loro
blocchi in `web_newsletter_blocchi`, per l'**azienda 2 — Sardegna Fuori Traccia di Antonio Tolu**.

```sql
-- ricognizione in locale: cosa c'è da portare
SELECT i.web_newsletter_invii_id, i.oggetto, count(b.*) AS blocchi
  FROM web_newsletter_invii i
  LEFT JOIN web_newsletter_blocchi b ON b.invio_id_fk = i.web_newsletter_invii_id
 WHERE i.is_modello = true AND i.azienda_id = 2   -- Sardegna Fuori Traccia
 GROUP BY 1, 2 ORDER BY 1;
```

**Attenzione a tre cose**, in quest'ordine:

1. **Gli id non si portano dietro.** Le chiavi sono `generated always as identity`: inserire in
   PROD assegna id nuovi, e `web_newsletter_blocchi.invio_id_fk` va rimappato sull'id nuovo. Non
   copiare le colonne id.
2. **Le immagini stanno su Storage, non nel database.** `immagine_url` e `immagine_storage_path`
   puntano al bucket: i file vanno caricati sul bucket di PROD **prima**, altrimenti i modelli
   arrivano con le immagini rotte. Vale anche per le icone dei pulsanti social.
3. **Gli indirizzi vanno prima.** `indirizzo_id_fk` punta a `web_indirizzi`, che è già in questa
   checklist come tabella da copiare nei contenuti: falla prima, oppure i modelli perdono il
   legame con la rubrica (l'indirizzo resta, il riaggancio automatico no).

Verifica finale in PROD: aprire un modello e controllare che si vedano le immagini e che i
pulsanti abbiano il colore e l'icona del social.

---

---

### 6.2 — Bonifica dati PROD: quattro anomalie che il software non può sanare da solo
*(Misurate il 2026-09-05 su Supabase, in sola lettura. Il database locale mostra gli stessi
numeri: **non è "sporco", rispecchia PROD** — le anomalie sono reali, non artefatti di test.)*

⚠️ **I numeri che contano sono quelli dell'azienda 2 (SFT)**: è l'unica che opera davvero, e
guardare il totale gonfia il problema. Sotto sono riportati entrambi.

Le anomalie di **forma** sono a zero: nessuna email malformata, nessun codice fiscale di
lunghezza sbagliata, nessuno spazio in testa o coda, nessun prefisso o tipo documento fuori
tabella (chiusi dagli script `580` e `585`). Restano quattro anomalie **di merito**.

| # | Anomalia | **SFT** | tutte | Perché non si sana con uno script |
|---|---|---|---|---|
| 1 | Partenze **concluse ma non marcate effettuate** | **8** | 50 | Marcarle tutte significherebbe dichiarare *fatti* viaggi che forse non si sono fatti. O il viaggio c'è stato e manca la spunta, o è stato annullato: lo sa solo chi c'era |
| 2 | Iscrizioni con **mezzo obbligatorio incompleto** | **9** | 18 | Manca marca, modello o targa. Inventarli è falsificare. Sono iscrizioni entrate *prima* che la regola esistesse (`SqlScripts/551`) |
| 3 | **Passeggeri senza pilota** assegnato | **0** | 11 | 🟢 Su SFT non ce n'è nessuno. Gli 11 sono dell'azienda 6, e sono tutti su partenze con più piloti — non ricostruibili |
| 4 | **Piloti senza email** | **0** | 9 | 🟢 Su SFT non ce n'è nessuno. È il caso storico che motivò la regola (`551`), ma riguarda l'altra azienda |

**Nessuna blocca il go-live**, e nessuna peggiora applicando gli script: le regole nuove valgono
sui dati *nuovi*, e questi restano leggibili e stampabili. Il punto 1 in particolare non ha effetti
pratici — quelle 50 partenze hanno comunque la data passata, quindi `fn_partenza_iscrivibile` le
esclude lo stesso.

**Come affrontarle**, quando ci sarà tempo e con Antonio a fianco. ⚠️ Sono **17 righe in tutto**
su SFT (8 + 9), non le decine che sembravano: è mezz'ora di lavoro, non un cantiere.
- il **punto 1** si chiude scorrendo le **8** partenze passate non spuntate — è anche l'occasione
  per accorgersi di viaggi mai realizzati che risultano ancora in archivio;
- i **punti 2 e 4** si sanano da soli col tempo: alla prossima iscrizione di quelle persone il
  software chiede i dati mancanti e non lascia proseguire;
- il **punto 3** va guardato caso per caso, ed è il meno urgente: riguarda viaggi già fatti.

⚠️ **Da non fare**: uno script che "sistemi" questi numeri. Sono dati che raccontano una storia,
e riscriverli a tavolino significherebbe perdere l'unica traccia di cosa è andato storto.

### 6.3 — Iscritti alla sola newsletter: la lista esistente va caricata
`web_newsletter_iscritti` in PROD nasce **vuota**. Chi si è iscritto alla newsletter dal vecchio
sito non è in `ana_clienti` — non ha mai comprato un viaggio — e quindi oggi non riceverebbe nulla.

**Da fare al go-live:** recuperare la lista degli iscritti esistente e caricarla per l'**azienda 2**,
con `stato = 'attivo'`, `consenso = true` e un `token_disiscrizione` generato per ciascuno (il
token serve al link di disiscrizione: senza, quella persona non può cancellarsi).

> **Confermato da Antonio (2026-09-04): quelle persone si erano iscritte espressamente alla
> newsletter dal vecchio sito.** È il motivo per cui si caricano con `consenso = true` senza
> chiedere niente a nessuno: il consenso l'hanno già dato, e ricominciare da capo sarebbe un
> favore fatto a nessuno. ⚠️ Va però conservata la **prova**: nella colonna della fonte si
> scrive da dove vengono (es. `sito_precedente`), e se Antonio ha una data di iscrizione la
> si porta dietro. Un consenso senza traccia di dove è stato raccolto vale poco il giorno in
> cui qualcuno lo contesta.

⚠️ **Da non confondere con il consenso dei clienti.** Sono due insiemi distinti e due tabelle
diverse:

| | Chi sono | Dove stanno | Al go-live |
|---|---|---|---|
| **Iscritti newsletter** | si sono iscritti dal vecchio sito, non hanno mai comprato un viaggio | `web_newsletter_iscritti` | si **caricano** con consenso già dato |
| **Clienti** | hanno viaggiato; SFT ne ha **206, di cui 198 con email** | `ana_clienti.consenso_marketing` | partono **tutti a zero**: la colonna non esiste ancora su PROD, e il consenso non gliel'ha mai chiesto nessuno |

I secondi si raccolgono uno alla volta, iscrizione dopo iscrizione (§ Sezione 3-A delle Note di
Rilascio 2.0). I primi sono già acquisiti e vanno solo importati.

> **Conseguenza da tenere a mente per gli invii selettivi.** Gli iscritti dal sito hanno solo
> email, nome e lingua: **non hanno anagrafica**. Nessun filtro che guardi data di inserimento,
> residenza, nazione o viaggi fatti può riguardarli, e attivando uno di quei filtri restano
> automaticamente fuori. Non è un difetto, è una conseguenza del non avere quei dati — ma va
> mostrato a schermo, non lasciato accadere in silenzio.

---

### 6.5 — ⚠️ `ESTERO - FRANCIA` è una riga di prova, NON va portata

`ana_geo_regioni_ita` ha 41 righe in sviluppo e 40 su PROD. La differenza è
`488 | ESTERO - FRANCIA`, **inserita dall'utente per fare delle prove** (2026-09-06).

☐ **Non propagarla.** È annotata qui solo perché la prossima volta che qualcuno confronta i
due cataloghi la ritrovi già spiegata, invece di riaprire l'indagine.

---

### 6.4 — Tabella `eba_countries`: va portata in PROD
Serve al filtro «clienti residenti in…» degli invii selettivi, attraverso la catena
`ana_clienti → ana_geo_comuni → ana_geo_province → ana_geo_regioni_ita → eba_countries`.

**Prima di applicare lo script `528`, verificare cosa c'è già in PROD:**

```sql
SELECT to_regclass('public.eba_countries') AS tabella,
       (SELECT count(*) FROM eba_countries) AS righe;   -- atteso: 249
```

| Esito | Cosa fare |
|---|---|
| Tabella assente | **Copiare l'intera tabella** da locale (struttura + 249 righe), poi applicare il `528` |
| Tabella presente con 249 righe | Applicare solo il `528`: aggiunge `name_it` e traduce |
| Tabella presente con righe **diverse** | Applicare il `528` e **leggere l'errore**: si interrompe elencando le nazioni non coperte. Aggiungerle allo script e rilanciare |

> Non copiare la sola colonna `name_it` su una tabella disallineata: la traduzione è agganciata a
> `iso_alpha2`, quindi va applicata dallo script e non con un travaso di valori posizionale.

Vale lo stesso ragionamento per le tre tabelle geografiche a monte (`ana_geo_comuni`,
`ana_geo_province`, `ana_geo_regioni_ita`): senza quelle, la nazione di un cliente non è
ricavabile e il filtro per residenza resta vuoto. Verificarle **prima** di annunciare la funzione
ad Antonio.

---

## 7. Configurazione MCP di Supabase — da completare **prima** del go-live
Il server MCP di Supabase è registrato nel **profilo utente** (non nel repository: era in
`.mcp.json` nella radice del progetto e faceva fallire la build MAUI — vedi l'esclusione nel
`.csproj`). Risulta però ancora **`! Needs authentication`**.

**Da fare:** in una sessione interattiva, `/mcp` → autenticare Supabase (OAuth).

⚠️ **I server MCP si caricano all'avvio della sessione**: dopo averlo aggiunto o autenticato serve
riaprire Claude Code, altrimenti `/mcp` continua a mostrare l'elenco di quando la sessione è
partita.

**Perché prima del go-live e non dopo:** senza autenticazione l'assistente non può interrogare il
database di PROD. Il deploy sono **128 script da applicare in ordine** più tabelle da copiare, e le
verifiche che questa checklist chiede — quante righe ha `eba_countries`, quali function hanno firme
sovrapposte, se `web_indirizzi` è arrivata — vanno fatte **su PROD**, non in locale. Farle a mano
una per una è possibile ma è esattamente il punto in cui si salta un controllo.

Verifica rapida dello stato:

```bash
claude mcp list | grep supabase
# atteso dopo l'autenticazione: ✔ Connected
```

## 8. Manutenzione di questo documento

Ogni volta che si aggiunge uno script SQL all'Estensione Web (numero > 510) o un nuovo requisito di configurazione:
1. aggiungere la riga in §1 (con eventuale ⚠️ e rimando a §2 se serve azione manuale);
2. se comporta backfill/segreti/config, aggiungere la voce in §2/§3 e la spunta in §4;
2bis. se introduce o cambia una **regola di comportamento** visibile all'utente (stati, pubblicabilità, cancellazioni, automatismi), aggiungere la voce da spiegare in §3.4: il manuale si scrive alla fine, ma l'elenco di cosa spiegare si costruisce strada facendo;
3. aggiornare la data in testa.

---

⚠️ **Aggiunto il 2026-09-05, dopo la rilettura.** Il documento si era disordinato in un
modo preciso: ogni voce nuova veniva appesa dove capitava, con numeri come `3.0-quater-ter`
per infilarla fra due esistenti. Sette sezioni in un giorno solo, e gli script `586`–`596`
**non erano nemmeno nell'elenco delle migrazioni** — la sequenza di go-live non li avrebbe
applicati.

**Quando si aggiunge qualcosa qui:**

- uno script nuovo va **nella tabella di §1**, sempre, anche se sembra minore;
- una voce da fare a mano va in **§2**, con il numero successivo;
- una variabile o un parametro d'ambiente va in **§3**;
- un contenuto da caricare va in **§6**;
- e se è un passo del giorno del go-live, va **anche nella sequenza di §0** — che è
  l'unica parte che qualcuno leggerà davvero mentre il cliente aspetta.

Niente numeri con i suffissi latini: se serve infilare una voce in mezzo, si rinumera.

### ⚠️ Il controllo che non dipende dal ricordarsene

La regola qui sopra è stata scritta il 2026-09-05 e **violata il 2026-09-06**: gli script
`597` e `598` sono nati e non sono finiti nella tabella di §1. Non per distrazione — perché
una regola che vive solo in un documento viene applicata finché qualcuno se ne ricorda.

Da eseguire **prima del go-live**, dalla cartella del progetto: elenca gli script che
esistono e non sono citati qui.

```bash
# Solo dal 406 in su: gli script precedenti sono lo schema storico, in PROD da tempo
# e fuori dal perimetro di questo documento.
for f in SqlScripts/*.sql; do
  n=$(basename "$f" | grep -oE '^[0-9]+' | sed 's/^0*//')
  [ -z "$n" ] || [ "$n" -lt 406 ] && continue
  grep -q "^| $n |" "Estensione Progetto WEB/Documenti/2026-07-10-Checklist_Go_Live_PROD.md" \
    || echo "MANCA in checklist: $(basename "$f")"
done
```

Se stampa qualcosa, la sequenza di go-live **non applicherebbe quegli script**: è esattamente
com'era il 2026-09-05, quando gli undici script del giorno non erano nell'elenco e nessuno
se ne era accorto.

⚠️ **Un'eccezione nota e legittima**: `999_Verify_Azienda_RegimeFiscale_Integrity.sql` non è
una migrazione, è una **verifica** — stampa lo stato dei regimi fiscali e non modifica
niente. Non va nell'elenco delle migrazioni e non va applicata in sequenza. Se il controllo
segnala solo quello, va bene così.
