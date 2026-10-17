# Registro degli script SQL in produzione

> **Documento vivo.** Una riga per ogni script **dal 637 in poi**: gli script dal 406 al 636 sono
> stati applicati tutti insieme al go-live dell'estensione web (2026-09-09, vedi
> `2026-09-09-Go_Live_Eseguito.md` e la checklist, ora chiusa). Da allora ogni script va in PROD da
> solo, con il via di Adriano, e **si aggiunge qui** (oltre che, se è del gestionale, nella nota di
> rilascio della sua versione, sezione «Database»).
>
> Creato il **2026-10-16**: la checklist del go-live era ferma al 636 e una ventina di script non
> comparivano in nessuna nota di rilascio. Lo stato qui sotto è **verificato**, non ricordato.

## Come si verifica (ripetibile)

1. **Script che creano funzioni**: impronta (`md5(prosrc)`) di ogni funzione creata dallo script, in
   locale e in PROD, con la stessa query:
   ```sql
   select proname, string_agg(md5(prosrc), ',' order by md5(prosrc))
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and proname = any(array['…'])
    group by proname;
   ```
   Uguali → applicato. Diverse → si confronta il codice (se cambiano solo spazi o nomi senza
   effetto, è «equivalente»). Assente in PROD → non applicato.
2. **Script che cambiano tabelle o dati**: si controlla l'effetto (tabella presente, vincolo,
   righe aggiornate o eliminate).

⚠️ Un'impronta uguale dice che **l'ultima** versione della funzione è in PROD: se uno script
successivo l'ha ridefinita, conta quello.

## Gli script (verifica del 2026-10-16)

| N | File | Cosa fa | Per | In PROD | Documentato in |
|---|---|---|---|---|---|
| 637 | `637_FnWebNewsletterImport.sql` | Import di una lista newsletter esterna | Newsletter (gestionale) | ✅ funzioni identiche al locale | — |
| 638 | `638_Bilancio_Viaggi_IvaNonDetraibile.sql` | Bilancio viaggi: il costo di chi NON detrae l'IVA è il LORDO | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 639 | `639_Calendario_Mezzi_E_MeseIniziale.sql` | Calendario dei viaggi: il numero dei mezzi, e su quale mese aprirsi | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 640 | `640_FnGetTransazioneInitData_Corretta.sql` | fn_get_transazione_init_data — la funzione che il dialog dei movimenti | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 641 | `641_FnGetTransazioneInitData_AliasSnakeCase.sql` | fn_get_transazione_init_data: alias in snake_case, uno stile solo | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 642 | `642_FnGetTransazioneInitData_ChiaviId.sql` | fn_get_transazione_init_data: la chiave di controparti e viaggi | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 643 | `643_FnGetTransazioneInitData_Viaggi.sql` | fn_get_transazione_init_data: i viaggi, con i nomi che il programma si aspetta | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 644 | `644_TransazioneInitData_ViaggiPartenze.sql` | fn_get_transazione_init_data: i viaggi sanno quando sono stati fatti | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 645 | `645_ModalitaPagamento_Tabella.sql` | Modalità di pagamento: la tabella che mancava alla contabilità | Gestionale | ✅ effetti presenti (vedi sotto) | Note di rilascio 2.2 |
| 646 | `646_ModalitaPagamento_Funzioni_E_Dati.sql` | Modalità di pagamento: le funzioni e la tabella precompilata | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 647 | `647_ModalitaPagamento_Controparti_E_InitData.sql` | Modalità di pagamento: dove si vede e dove arriva | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 648 | `648_TransazioneInitData_ModalitaPagamento.sql` | fn_get_transazione_init_data: le modalità di pagamento nella scheda movimenti | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 649 | `649_FirmeDuplicate_Pulizia.sql` | Firme duplicate: tredici mine disinnescate, e una guardia per il futuro | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 650 | `650_PROD_Stampe_Mancanti.sql` | Le cinque stampe che in produzione non c'erano | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 651 | `651_Web_ClienteProfiloPubblico.sql` | Il sito smette di consegnare la scheda a chiunque conosca un'email | Sito iscrizioni | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 652 | `652_FattureAttive_FiltriVuoti.sql` | L'elenco delle fatture attive: un filtro lasciato in bianco non e' un filtro | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.2 |
| 653 | `653_Web_SezioniTipologia.sql` | Le sezioni del sito: quali mostrare adesso, e con che nome | Sito pubblico | ✅ funzioni identiche al locale | `Funzioni_DB.md`; piani del sito |
| 654 | `654_Web_CodaRigenerazione.sql` | La coda di rigenerazione: il sito non resta indietro, nemmeno se nessuno ascolta | Sito pubblico | ✅ funzioni identiche al locale | `Funzioni_DB.md`; piani del sito |
| 655 | `655_Web_Funzioni_Pubbliche_Permessi.sql` | Il sito pubblico, com'è il database oggi, non leggerebbe niente | Sito pubblico | ✅ effetti presenti (vedi sotto) | `Funzioni_DB.md`; piani del sito |
| 656 | `656_WebIndirizzi_Social_WhatsApp.sql` | WhatsApp diventa un social riconosciuto | Newsletter (gestionale) | ✅ effetti presenti (vedi sotto) | Note di rilascio 2.3 |
| 657 | `657_Web_SezioniNomiMinuscolo.sql` | I nomi delle sezioni del sito, con maiuscole e minuscole | Sito pubblico | ✅ effetti presenti (vedi sotto) | `Funzioni_DB.md`; piani del sito |
| 658 | `658_Web_PagamentiOnline_Spenti.sql` | Pagamenti online: spenti finché la funzione non esiste | Gestionale | ✅ effetti presenti (vedi sotto) | — |
| 659 | `659_Web_Revoca_Execute_Public.sql` | Nessuna funzione nostra eseguibile da PUBLIC (quindi da anon) — di nuovo | Sicurezza (tutti) | ✅ (la sola funzione nominata è in un commento: nessun oggetto da confrontare) | — |
| 660 | `660_Web_Otp_Codici.sql` | Il codice usa e getta per vedere e modificare la propria scheda dal sito | Sito iscrizioni | ✅ funzioni identiche al locale | Note di rilascio 2.3 |
| 661 | `661_Web_Cliente_Completa.sql` | Completare una scheda esistente senza poterla sovrascrivere | Sito iscrizioni | ✅ funzioni identiche al locale | — |
| 662 | `662_Web_Email_Agganciate_Dal_Sito.sql` | Le email agganciate dal sito non aprono la scheda | Sito iscrizioni | ✅ funzioni identiche al locale | — |
| 663 | `663_Wizard_Partecipanti_Filtro_Azienda.sql` | Le letture del wizard restano dentro la propria azienda | Sito iscrizioni | ✅ funzioni identiche al locale | — |
| 664 | `664_Documento_Scaduto_Messaggio_Italiano.sql` | Il messaggio del documento scaduto si legge in italiano | Sito iscrizioni | ✅ funzioni identiche al locale | — |
| 665 | `665_Viaggi_Svuota_Link_Documentazione.sql` | Si svuota il «Link Documentazione» dei viaggi | Gestionale | ✅ effetti presenti (vedi sotto) | — |
| 666 | `666_Alloggi_Solo_Iscritti_Alla_Partenza.sql` | In camera solo chi e' iscritto alla partenza | Gestionale + sito iscrizioni | ✅ funzioni identiche al locale | — |
| 667 | `667_Wizard_Partecipanti_Via_Le_Firme_Vecchie.sql` | Via le firme delle letture del wizard senza azienda | Sito iscrizioni | ✅ effetti presenti (vedi sotto) | — |
| 668 | `668_Web_Email_Confermata_Dal_Gestionale.sql` | Il gestionale conferma un'email agganciata dal sito (L12) | Sito iscrizioni + gestionale (L12) | ✅ funzioni identiche al locale | Note di rilascio 2.3 |
| 669 | `669_Web_Proposte_Modifica.sql` | Le correzioni proposte dal cliente sul sito (L12-bis) | Sito iscrizioni + gestionale (L12) | ✅ funzioni identiche al locale | Note di rilascio 2.3 |
| 670 | `670_Web_Proposte_Decisione.sql` | Leggere, approvare e scartare le proposte del sito (L12-bis) | Sito iscrizioni + gestionale (L12) | ✅ funzioni identiche al locale | — |
| 671 | `671_Promemoria_Apertura.sql` | Il promemoria all'apertura (L2) | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.4 |
| 672 | `672_Elimina_Viaggio_Di_Test_2.sql` | Via il «VIAGGIO DI TEST 2» (viaggio 903, partenza 1865 del 09/04/2026 | Gestionale | ✅ effetti presenti (vedi sotto) | Note di rilascio 2.4 |
| 673 | `673_Promemoria_Mail_Lunedi.sql` | La mail del lunedi' (prosegue il promemoria all'apertura, L2) | Gestionale | ✅ funzioni identiche al locale | Note di rilascio 2.4 |
| 674 | `674_Rooming_List_Cane.sql` | La rooming list dice chi porta il cane | Gestionale | ✅ identica al locale dal **2026-10-16** (riapplicata col via di Adriano: prima era una versione compatta, senza gli alias ridondanti nei rami `UNION`, equivalente; permessi invariati, solo `postgres`; prova: 45 righe sulla partenza più numerosa) | — |
| 675 | `675_Web_Titoli_Leggibili.sql` | I titoli dei tour, sul sito, non in MAIUSCOLO | Sito pubblico | ✅ funzioni identiche al locale | `Funzioni_DB.md`; piani del sito |
| 676 | `676_Web_Newsletter_Titoli_Leggibili.sql` | Anche nelle newsletter i titoli dei tour non in MAIUSCOLO | Newsletter (gestionale) | ✅ funzioni identiche al locale | `Funzioni_DB.md`; piani del sito |
| 677 | `677_Web_Newsletter_Periodo_Elisioni.sql` | Il periodo delle newsletter in italiano corretto: «dall'8», «all'11» | Newsletter (gestionale) | ✅ funzioni identiche al locale | `Funzioni_DB.md`; piani del sito |
| 678 | `678_Web_Sezione_Stato.sql` | La sezione è attiva, ritirata o mai esistita? (Tappa 2 del sito) | Sito pubblico | ✅ funzioni identiche al locale | `Funzioni_DB.md`; piani del sito |
| 679 | `679_Web_Utente_Sito_Rigenera.sql` | Un utente del database che sa solo svuotare la coda di rigenerazione | Sito pubblico | ✅ funzioni identiche al locale | `Funzioni_DB.md`; piani del sito |
| 680 | `680_Web_Meta_Tradotti.sql` | Meta titolo e meta descrizione dei tour tradotti sul sito (voce L22) | Sito pubblico | ✅ funzioni identiche al locale | `Funzioni_DB.md`; piani del sito |
| 681 | `681_Web_Utente_Sito_Guardiano.sql` | Un utente del database che sa solo leggere la posta del guardiano | Sito pubblico | ✅ funzioni identiche al locale | `Funzioni_DB.md`; piani del sito |
| 682 | `682_Web_Tour_Slug_Stato.sql` | Lo stato di ogni indirizzo di tour, per il proxy del sito (Tappa 3) | Sito pubblico | ✅ **2026-10-17** (identica al locale; test in transazione annullata superato; `anon` ammesso) | `Funzioni_DB.md`; piani del sito |
| 683 | `683_Web_Tour_Scheda.sql` | La scheda di un tour in una chiamata sola, già tradotta | Sito pubblico | ✅ **2026-10-17** (identica al locale; test superato; `anon` ammesso) | `Funzioni_DB.md`; piani del sito |
| 684 | `684_Web_Titolo_Sezioni_Tradotti.sql` | Titolo del tour e nome della sezione tradotti; paese per le card | Sito pubblico + gestionale | ✅ **2026-10-17**, dopo il 685 (identiche al locale; permessi `anon`/`authenticated`/`service_role` ricreati; semaforo «Traduzioni» invariato per tutte le 11 schede, un campo in più ciascuna; italiano invariato all'impronta; test superato) | `Funzioni_DB.md`; piani del sito |
| 685 | `685_Web_Titoli_Tradotti.sql` | I titoli dei tour tradotti (dati, 44 righe revisionate) prima del 684 | Sito pubblico + gestionale | ✅ **2026-10-16** (autorizzazione di Adriano; 11 schede × 4 lingue verificate) | `Funzioni_DB.md` |
| 686 | `686_Web_Correzioni_Traduzioni.sql` | Il marchio non si traduce (3 meta titoli corretti); nomi delle 5 sezioni tradotti (20 righe revisionate) | Sito pubblico + gestionale | ✅ **2026-10-16** (autorizzazione di Adriano; verificati: nessun marchio tradotto, menu EN/DE tradotto) | `Funzioni_DB.md`; note 2.4 §2.3 |
| 687 | `687_Web_Iscrizione_Arrivi.sql` | Gli arrivi al wizard dal sito, contati (L20): tabella e due funzioni per il Flask | Sito iscrizioni + sito pubblico | ✅ **2026-10-17** (identiche al locale; RLS attiva, niente ad `anon`/`authenticated`; test superato, tabella vuota) | `Funzioni_DB.md` |
| 688 | `688_Web_Pdf_Richieste.sql` | Le richieste del PDF della scheda, contate dal server del sito con l'utente `sito_statistiche` (unica eccezione alla regola 3) | Sito pubblico | ✅ **2026-10-17** (identica al locale; `EXECUTE` solo a `sito_statistiche`; test superato, tabella vuota; login dato con la sola impronta SCRAM, password solo nel `.env.local` del sito, riga commentata di PROD) | `Funzioni_DB.md` |
| 689 | `689_Web_Andalucia_Durata_Tradotta.sql` | Andalucia: le 4 traduzioni della durata «9 giorni / 8 notti» (erano «8 …», obsolete) | Sito pubblico + gestionale | ✅ **2026-10-17** (autorizzazione di Adriano; test rosso prima e verde dopo; semaforo «Traduzioni» della scheda completo) | `Funzioni_DB.md`; note 2.4 §4 |
| 690 | `690_Web_Mongolia_Gallura_Traduzioni.sql` | Mongolia: «Equipaggiamento» tradotto (mancava); Gallura: durata e sottotitolo come l'italiano (erano in maiuscolo, obsoleti) | Sito pubblico + gestionale | ✅ **2026-10-17** (autorizzazione di Adriano; test rosso prima e verde dopo; tutte e 7 le schede pubblicate col semaforo «Traduzioni» completo) | `Funzioni_DB.md`; note 2.4 §4 |

**Effetti verificati per gli script senza funzioni (2026-10-16):** 645 tabella
`ana_modalita_pagamento` presente; 655 le quattro funzioni pubbliche del sito `SECURITY DEFINER`;
656 `whatsapp` ammesso in `chk_web_indirizzi_social`; 657 nessun nome di sezione in maiuscolo; 658
pagamenti online spenti per l'azienda 2; 665 nessun `viaggio_link` valorizzato; 667 nessuna firma
vecchia (a un parametro) delle tre letture del wizard; 672 viaggio 903 assente.

## Come si aggiunge una riga

Quando uno script va in PROD: numero, file, cosa fa, per chi, «✅ con la data» e dove è
documentato. Il controllo qui sotto, eseguito dalla cartella del gestionale, elenca gli script che
esistono e mancano in questo registro:

```bash
for f in SqlScripts/[0-9]*.sql; do
  n=$(basename "$f" | grep -oE '^[0-9]+' | sed 's/^0*//')
  [ -z "$n" ] || [ "$n" -lt 637 ] || [ "$n" -ge 999 ] && continue
  grep -q "^| $n |" Documents/PROD/Registro_Script_PROD.md || echo "MANCA nel registro: $(basename "$f")"
done
```
