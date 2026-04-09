# Note di rilascio — Versione 1.35

Questa versione introduce correzioni e miglioramenti all'esperienza d'uso
quotidiana dell'applicazione. Le modifiche descritte di seguito sono già
attive e non richiedono alcuna azione da parte tua.

---

## Correzioni

### Nomi dei file delle stampe relative ai viaggi

**Problema**

Quando veniva generata una stampa relativa a un viaggio — come la Scheda
Viaggio, la Scheda Dettagliata o la Rooming List — il file PDF salvato
riportava nel nome la parola generica "Viaggio" al posto del nome effettivo
del viaggio. Ad esempio, una stampa del viaggio Ichnusa veniva salvata come:

```
SchedaViaggio_Viaggio_Dal_25-04-2026_al_01-05-2026.pdf
```

Questo rendeva difficile riconoscere e ritrovare il file in un secondo momento,
specialmente quando erano presenti più stampe relative a viaggi diversi.

**Come funziona adesso**

Il nome del file include ora il nome del viaggio correttamente. Tutte le stampe
relative ai viaggi seguono questo formato:

| Tipo di stampa      | Esempio nome file                                        |
|---------------------|----------------------------------------------------------|
| Scheda Sintetica    | `SchedaViaggio_ICHNUSA_Dal_25-04-2026_al_01-05-2026.pdf` |
| Scheda Dettagliata  | `SchedaViaggioDettaglio_ICHNUSA_Dal_25-04-2026_al_01-05-2026.pdf` |
| Rooming List        | `RoomingList_ICHNUSA_Dal_25-04-2026_al_01-05-2026.pdf`  |

Il nome del file conterrà sempre il nome del viaggio e le date di inizio e fine,
rendendo ogni stampa immediatamente identificabile anche a distanza di tempo.
