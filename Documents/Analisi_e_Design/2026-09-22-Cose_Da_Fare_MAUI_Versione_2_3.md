# Cose da fare su MAUI — versione 2.3

> **USO INTERNO.** Aperto il 2026-09-22, dopo la consegna della 2.2.
> Raccoglie le idee nate lavorando, con il **perché** di ognuna: senza quello, fra tre mesi
> resta solo un elenco di funzioni che nessuno sa più valutare.
>
> ✅ **Consegnata ad Antonio il 2026-09-27.** Questa lista resta come storico di ciò che la 2.3 ha
> portato. Le voci ancora aperte (promemoria all'apertura, scheda web dopo una data nuova, arco
> del calendario) e la sezione **«Legato al sito pubblico»**, gemella della lista del sito,
> proseguono in `2026-09-27-Cose_Da_Fare_MAUI_Versione_2_4.md`.

---

## Portato con la 2.3

✅ **2026-09-27** — versione portata a **2.3** (build 40) nel codice e nei manuali; controlli preliminari su PROD puliti. Note: `Documents/Versioni/Note_Rilascio_Versione_2_3.md`; per Antonio `Novita_Versione_2_3.pdf`. ✅ Installer `GestioneViaggi_Setup_2.3.exe` compilato (x64) e provato sulla VM: mail arrivata, foto HEIC caricata, versione 2.3; sul Mac la 2.3 sostituisce la 2.2 in `/Applications`. ✅ **Consegnata ad Antonio il 2026-09-27.**

| Cosa | Dove |
|---|---|
| 🔴 **Le mail del gestionale non arrivavano.** Con il `Message-Id` generato da MailKit il server di posta accetta la mail e poi la mail sparisce, senza errori: mail ai partecipanti, newsletter, reset password, «puoi iscriverti». Verificato il 2026-09-26 anche dalla 2.2 in produzione (mail a sé dall'anagrafica clienti: non arriva). Corretto con un `Message-Id` nostro (data + codice + dominio del mittente); provato con 16 invii una variabile alla volta. ⚠️ Riguarda la produzione **oggi**: da distribuire appena possibile, anche prima del resto della 2.3 | `SmtpEmailSender.cs`, commit `aa03792` |
| **Foto HEIC dell'iPhone**: ImageSharp non le leggeva («Image cannot be loaded. Available decoders…», Antonio, 2026-09-26). Ora si convertono con Magick.NET su Windows e ImageIO sul Mac; un formato illeggibile dice «Salva la foto come JPEG o PNG». ✅ Provato il 2026-09-27 sulla VM Windows con l'installer 2.3: la foto HEIC si carica | `WebImageProcessor.cs`, commit `d8513f2` |
| **Email agganciata dal sito: conferma** (L12). Nella scheda cliente, se l'email l'ha scritta il sito e nessuno l'ha verificata, un avviso con il bottone «È la sua email: conferma»: da lì il cliente riceve il codice per modificare i suoi dati dal sito. ✅ Script 668 in PROD dal 2026-09-26 | `ClienteDialog`, `ClienteEmailWebService`, `SqlScripts/668` |
| **Correzioni proposte dal sito** (L12-bis). Nella scheda cliente il riquadro «Correzione proposta dal sito» con *campo · in archivio · proposto* e Approva / Scarta; approvata, al cliente parte «La tua scheda è aggiornata: puoi completare l'iscrizione». ✅ Script 669-670 e sito già in PROD (2026-09-26): con la 2.3 arriva solo la schermata | `ClienteDialog`, `ClienteProposteWebService`, `SqlScripts/669`, `670` |
