# I documenti del sito pubblico sono in un altro progetto

**Spostati il 2026-09-22** in `Sviluppo Software/Sito Web SFT/`.

## Perché

Il progetto «Estensione Web» aveva due metà, e tenerle insieme aveva senso finché erano una
cosa sola:

1. il **CMS dentro il gestionale** — itinerario, galleria, mappe, traduzioni, newsletter,
   edizioni. **Sono schermate di MAUI**, già realizzate: la loro documentazione resta qui;
2. il **sito pubblico** — analisi, proposte al cliente, scelte di impianto. **Non è MAUI**: è
   un prodotto suo, con una sua tecnologia e un suo rilascio.

⚠️ **Il criterio dello spostamento**: *dove vive la cosa descritta*. Un documento che spiega una
linguetta del gestionale resta qui anche se si chiama «web»; un documento che parla di pagine,
menu e visitatori se ne va.

## Cosa è andato dove

| Cosa | Nuova collocazione |
|---|---|
| Analisi del sito, valutazione critica, lavori rimanenti, protezione dati, verifica presupposti | `Sito Web SFT/Documenti/Analisi/` |
| Proposta funzionale e allegati per il cliente, versioni HTML e PDF | `Sito Web SFT/Documenti/Proposte_Cliente/` |
| Guida per Antonio alla preparazione del gestionale | `Sito Web SFT/Documenti/Manuali_Utente/` |
| Accesso al vecchio CMS Drupal, hero e loghi | `Sito Web SFT/Riferimenti/` |

## Cosa è rimasto qui, e non per dimenticanza

I design dei **blocchi CMS** (0-3, 6, 7, 9, 10, 11, 13), il **piano operativo**, il **piano
test**, la **checklist go-live**, i runbook, il dettaglio tabelle e il diagramma E/R:
descrivono il database e le schermate del gestionale.

⛔️ **Le funzioni di database restano in `SqlScripts/` di questo repository**, anche quelle che
serviranno solo al sito: il database è uno solo, e un secondo posto dove scrivere SQL è il modo
più rapido per ritrovarsi con due verità.

ℹ️ `2026-09-05-Analisi_Scelta_Camere_Step5.md` **è stato spostato nel progetto Flask**
(`GitHub/Iscrizione-Viaggi-Offroad PostgreSQL/docs/`): descrive il **passo 5 del wizard di
iscrizione**, che è una schermata di quel sito — non del gestionale e non del sito pubblico.
