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
| 691 | `691_Web_Coda_Anagrafica_Traduzioni.sql` | La coda di rigenerazione si accorge anche di anagrafica dell'azienda, WhatsApp, recensioni, nomi delle sezioni, testi delle giornate e traduzioni (8 trigger in più) | Sito pubblico (pagine e PDF) | ✅ **2026-10-17** (via di Adriano; funzione identica al locale `4776150b…`; 14 trigger; test in transazione annullata superato, nessun residuo) | `Funzioni_DB.md`; note 2.4 §4 |
| 692 | `692_Web_Sito_Contenuti.sql` | La scheda «Sito web» dell'azienda (home, «In evidenza», email dei messaggi del sito) e le garanzie del tour operator; la coda si accorge della scheda (L24, L26, L28) | Sito pubblico + gestionale 2.4 | ✅ **2026-10-20** (funzioni identiche al locale, trigger della coda `20fad16d…`; test superato in PROD; dati di Antonio inseriti con il via di Adriano: motto, frase, email `info@`) | `Funzioni_DB.md` |
| 693 | `693_Web_Sito_Letture.sql` | Le letture del sito per home, «In evidenza», piede e zone della mappa | Sito pubblico | ✅ **2026-10-20** (identiche al locale; solo `anon`/`authenticated`; test superato in PROD) | `Funzioni_DB.md` |
| 694 | `694_Web_Utente_Sito_Posta.sql` | L'utente `sito_posta` (posta del modulo Contatti, nessuna scrittura) | Sito pubblico | ✅ **2026-10-20** (identica al locale; test superato in PROD). **Login dato il 2026-10-21** con la sola impronta SCRAM, calcolata sul server; password solo nel `.env` del server (`DATABASE_URL_POSTA`); provato dal server: legge la posta, niente tabelle né funzione del guardiano | `Funzioni_DB.md` |
| 695 | `695_Web_Sito_Titolo_Sottotitolo.sql` | Home: titolo e sottotitolo al posto della «frase d'apertura» (colonna rinominata, traduzioni seguite, firma del salvataggio con un parametro in più) | Sito pubblico + gestionale 2.4 | ✅ **2026-10-20** (identiche al locale; test superato in PROD; testi di Antonio inseriti e tradotti) | `Funzioni_DB.md` |
| 696 | `696_Web_Sito_Partenze.sql` | Le partenze della home in ordine di data (blocco «Si parte») | Sito pubblico | ✅ **2026-10-20** (identica al locale `ec017814…`; test superato in PROD) | `Funzioni_DB.md` |
| 697 | `697_Messaggio_Pilota_Senza_CF.sql` | Pilota senza codice fiscale: il messaggio dice la residenza in anagrafica e cosa correggere (regola invariata) | Gestionale e sito Flask | ✅ **2026-10-20** (identica al locale `02abdd18…`; test superato in PROD) | `Note_Rilascio_Versione_2_4.md` §2.4 |
| 698 | `698_Web_Sito_Video_Home.sql` | Foto e video d'apertura della home caricati dalla scheda «Sito web» (colonne, `fn_web_sito_foto_home_save`, `fn_web_sito_video_home_save`, `fn_web_sito_home` con `video`) | Sito pubblico e gestionale 2.4 | ✅ **2026-10-20** (identiche al locale: home `0edb40ed…`, video `3f4a2839…`, foto `e63462d6…`; test superato in PROD). Registrato il video d'esempio (file dello Storage di prova), su richiesta di Adriano | `Funzioni_DB.md`, `Note_Rilascio_Versione_2_4.md` §1.7 |
| 699 | `699_Web_Sito_Video_Copertina.sql` | La copertina del video d'apertura (primo fotogramma), nuova firma di `fn_web_sito_video_home_save` | Sito pubblico e gestionale 2.4 | ✅ **2026-10-20** (identiche al locale: home `a6ca0a2e…`, video `57b8c358…`; test superato in PROD). Video d'esempio ri-registrato con la copertina | `Funzioni_DB.md`, `Note_Rilascio_Versione_2_4.md` §1.7 |
| 700 | `700_Web_Sito_Piede_Email.sql` | Il sito mostra l'email dei messaggi del sito (scheda «Sito web»), altrimenti la principale | Sito pubblico | ✅ **2026-10-21** (identica al locale `6050365e…`; test superato in PROD). Destinataria scelta: `info@fuoritracciatravel.com` (id 21), casella provata | `Funzioni_DB.md` |
| 701 | `701_Web_Sito_Testi_Legali.sql` | Testi legali del sito (note legali, privacy, cookie): salvataggio, lettura tradotta, elenco delle pagine | Sito pubblico e gestionale 2.4 | ✅ **2026-10-23** (identiche al locale: pagina `54f08dbd…`, pagine `97bdda1c…`, salvataggio `47175ca4…`, html_pieno `4611fc74…`; in PROD il salvataggio nasce chiuso grazie alla revoca; test superato in PROD). Testi non ancora inseriti (revisione del consulente) | `Funzioni_DB.md` |
| 702 | `702_Web_Pdf_Impronte_12_Mesi.sql` | Le impronte del conteggio dei PDF si cancellano dopo 12 mesi | Sito pubblico | ✅ **2026-10-23** (identica al locale `ba3236dd…`; test superato in PROD; le 41 impronte, dal 2026-10-19, intatte) | `Funzioni_DB.md` |
| 703 | `703_Web_Sito_Chi_Siamo.sql` | La pagina «Chi siamo»: testo e 2 foto in `web_sito_contenuti`, salvataggi del gestionale, `fn_web_sito_pagina` con `chi_siamo` e le foto, `chi_siamo` in testa all'elenco delle pagine | Sito pubblico e gestionale 2.4 | ✅ **2026-10-27** insieme al sito del 4C (identiche al locale: pagina `57624d09…`, salvataggio `3548040a…`, foto `99675403…`; salvataggi chiusi ad `anon`/`authenticated`; test superato in PROD). Nessun testo in PROD: la pagina non esiste finché Antonio non lo scrive | `Funzioni_DB.md` |
| 704 | `704_Web_Sito_Faq.sql` | Le FAQ in gruppi: tabelle `web_sito_faq_gruppi` e `web_sito_faq` (RLS accese, chiuse al pubblico), `fn_web_sito_faq_save`, `fn_web_sito_faq_list`, `fn_web_sito_faq`; `faq` nell'elenco; la coda avvisata dalle FAQ e dalle loro traduzioni (`trg_web_revalidate_func`) | Sito pubblico e gestionale 2.4 | ✅ **2026-10-27** (identiche al locale: lettura `ac4ec61b…`, salvataggio `6abbe292…`, elenco `d3b3d72b…`, trigger `32f5b1b7…`; trigger PROD confrontato prima: uguale alla 692 salvo le righe FAQ; test superato in PROD). **Dati:** copiate dal DB locale le FAQ di Adriano (8 gruppi, 19 domande, 164 traduzioni; `created_by`/`updated_by` = `copia-locale-2026-10-27`), con `fn_web_sito_faq_save`; pagine IT, EN, DE, FR, ES identiche al locale (impronte md5) | `Funzioni_DB.md` |
| 705 | `705_Web_Sito_Galleria.sql` | La Galleria: `fn_web_sito_galleria` (foto di galleria dei tour pubblicati e archiviati, per tipo di viaggio, link solo ai tour in vendita); `galleria` nell'elenco | Sito pubblico | ✅ **2026-10-27** (identiche al locale: galleria `8de35c35…`, pagine `c6471b6a…`; test superato in PROD). In PROD: 3 tipi, 31 foto | `Funzioni_DB.md` |
| 706 | `706_Traduzioni_Solo_Formattazione.sql` | L29: se nell'italiano cambia solo la formattazione, le traduzioni la ricevono blocco per blocco e restano valide; `fn_html_blocchi`, `fn_html_involucro`, `fn_html_riporta_formattazione`, `fn_web_traduzioni_dopo_modifica` (+ `_global`, `_tutte`); `fn_web_sito_faq_save` con la regola nuova | Gestionale 2.4 (e FAQ subito) | ✅ **2026-10-28** (7 funzioni identiche al locale: regola `5b23d234…`, dopo modifica `6147b685…`, FAQ `0d138d67…`; FAQ PROD confrontata prima: uguale alla 704; tutte chiuse ad `anon`/`authenticated`; test superato in PROD e annullato, FAQ intatte 8/19/164). ⚠️ Il gestionale 2.3 continua a usare `fn_web_traduzioni_marca_obsolete` (resta); la regola vale nel gestionale dalla 2.4 | `Funzioni_DB.md` |
| 707 | `707_Web_Newsletter_Dal_Sito.sql` | Newsletter dal sito (4D, L7): iscrizione con doppio consenso (`in_attesa`, codice come impronta, 48 ore, limiti in `web_newsletter_richieste`), conferma, disiscrizione dal link firmato (`ana_aziende.segreto_disiscrizione`, HMAC); via `anon_insert_iscrizione`; `fn_web_newsletter_richiedi`, `_conferma`, `_disiscrivi` solo a `sito_posta` | Sito pubblico e gestionale 2.4 | ✅ **2026-10-29** (3 funzioni identiche al locale: richiedi `55c65b0a…`, conferma `9d7fdd9f…`, disiscrivi `88e7922a…`; chiuse ad `anon`/`authenticated`, aperte a `sito_posta`; segreto e richieste chiusi al pubblico, un segreto per azienda; test superato in PROD e annullato; 2484 iscritti attivi intatti). ⚠️ Va prima del gestionale nuovo (link di disiscrizione firmato col segreto nuovo) | `Funzioni_DB.md` |
| 708 | `708_Web_Statistiche_Settimana.sql` | I numeri del database per la mail settimanale delle statistiche (4E): `fn_web_statistiche_settimana(azienda, dal, al)`, arrivi e iscrizioni per edizione, PDF consegnati, newsletter; sola lettura, solo a `sito_guardiano` | Sito pubblico (mail del lunedì) | ✅ **2026-10-29** (identica al locale `745e6b1e…`; chiusa ad `anon`/`authenticated`; test superato in PROD e annullato). **Dati:** cancellate da `web_pdf_richieste` le 152 richieste dei nostri collaudi (2 impronte, 23–29/10; restano le 11 vere), con l'autorizzazione di Adriano; da oggi il sito conta solo le richieste passate da nginx | `Funzioni_DB.md` |
| 709 | `709_Web_Foto_Archivio_Privato.sql` | Protezione delle foto (L27, Task 1): regola `sito_foto_legge_originali` su `storage.objects` (sola lettura di `tour-media` e `tour-media-dev` per l'utente con `app_metadata.sito_foto`, il server del sito); archivio pubblico `newsletter-media` (solo immagini, 5 MB) per le newsletter. Sul database locale non fa nulla (niente schema storage) | Sito pubblico; gestionale 2.4 (newsletter) | ✅ **2026-10-30** (lanciato da Adriano; test fallito prima e superato dopo in PROD, annullato: il sito legge i due archivi, un utente qualunque, uno con `sito_foto` falso o nei dati scrivibili e l'anonimo non leggono nulla; il sito non scrive né cancella). Utente `sito-foto@fuoritracciatravel.com` creato con la chiave di servizio (password solo nei `.env`). `tour-media` **resta pubblico** fino al Task 7 | `Documenti/Analisi/2026-10-29-L27_Protezione_Foto_Disegno_e_Piano.md` (sito) |
| 710 | `710_Web_Slug_Forma.sql` | Forma degli slug controllata dal database (L21): vincoli `ck_*_slug_forma` (`^[a-z0-9]+(-[a-z0-9]+)*$`, la stessa del proxy del sito) su `web_tipi_viaggio_descrizioni`, `web_tour_contenuti`, `web_blog_articoli`. Messaggio chiaro nel gestionale dalla 2.5 | Sito pubblico (proxy) | ✅ **2026-10-30** (lanciato da Adriano; 3 vincoli validati, definizione identica al locale; 10 forme sbagliate rifiutate in una prova annullata; 11 tour e 5 sezioni invariati; collaudo del sito 1512/1512) |

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
