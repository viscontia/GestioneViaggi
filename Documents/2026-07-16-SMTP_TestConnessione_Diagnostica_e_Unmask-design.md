# SMTP: diagnostica test connessione, messaggi errore centralizzati, unmask password — design

> Hardening UX/diagnostica sul dialog di configurazione SMTP azienda. Validato con Adriano (2026-07-16).
> Nasce da una sessione di test go-live su azienda 2 (Sardegna Fuori Traccia).

## Contesto e root cause (verificati con prove)

Durante i test è emerso: (a) il "Test connessione" andava in **timeout**; (b) la password **sembrava non salvarsi**. Indagine sistematica:

- **Timeout = VPN.** Le porte mail (465/587/993) del server rispondono da **IP residenziale** ma sono **filtrate dai range datacenter/VPN** (provato: KO da exit ZA-Datacamp e IT-PacketHub, OK da ADSL residenziale; `gmail:465` invece sempre OK → filtro specifico del server, anti-spam). Non è un bug dell'app né del gestore: con VPN attiva il Connect va in timeout a prescindere.
- **Password "non salvata" = falso (percezione).** La password **è** salvata e decifrabile: `pgp_sym_decrypt(password_enc, master)` → `Sardegna2025`. Il write-path (`pgp_sym_encrypt`) è corretto. La percezione è causata da due difetti reali che tolgono ogni modo di verificare:
  - **Bug A (confermato):** `AziendaSmtpService.GetRealPasswordAsync` legge `password_enc->>'value'` (JSONB) su colonna ora **bytea/pgcrypto** (migrazione 475) → `ERROR: operator does not exist: bytea ->> unknown` → catch → `null`. Il tasto Test su config salvata risponde "Password non recuperabile. Salvare la configurazione…" anche se la password c'è.
  - **Bug B (design):** il campo password mostra sempre la sentinella `***`, non smascherabile → l'utente non può mai verificare il valore salvato.

## Decisioni approvate

1. **Unmask password**: su config salvata, smascherando si mostra la **password reale decifrata** dal DB (via `GV_SECRET_KEY`). Vale outbound **e** inbound. Chi accede al dialog ha già le credenziali per farlo.
2. **Messaggi errore centralizzati**: nuovo `SmtpErrorTranslator` (mirror di `DbErrorTranslator`), **unico posto**, usato **sia** dal test connessione **sia** da `SmtpEmailSender`.
3. **Tipizzazione errori — set completo**: DNS/host inesistente, connessione rifiutata, timeout, SSL/TLS handshake, autenticazione, protocollo, generico.
4. **Diagnostica VPN/firewall**: al timeout di Connect, **sonda differenziale** (host:443 raggiungibile?) → messaggio mirato "porta bloccata: firewall o VPN attiva". Nessun tentativo di "rilevare la VPN" in modo deterministico (inaffidabile: falsi positivi su `utun*`). In più, **testo statico** sempre visibile nel dialog che ricorda di disattivare la VPN.

## Parte 0 — Fix lettura password decifrata (DB-first, sblocca tutto)

Il recupero della password in chiaro va portato a **funzione DB** (regola DB-first) e reso pgcrypto-aware.

- **Nuova funzione** `fn_ana_aziende_smtp_secrets_get(p_smtp_id uuid, p_master text)` → ritorna `(password text, inbound_password text)` via `pgp_sym_decrypt(password_enc, p_master)` / `pgp_sym_decrypt(inbound_password_enc, p_master)` (NULL-safe su colonne NULL). Script `SqlScripts/NNN_*.sql` + aggiornare `Documents/Funzioni_DB.md`.
- **`AziendaSmtpService.GetRealPasswordAsync`**: riscritto per chiamare la funzione con la master key (`_secretKey.GetMasterKey()`), niente più SQL inline `->>'value'`. Aggiungere `GetRealInboundPasswordAsync` (o un unico metodo che ritorna entrambe). Correggere anche il commento XML stale ("JSONB {value}").
- Impatto immediato: il test su config salvata torna a recuperare la password reale (fine falso "Password non recuperabile").

## Parte 1 — `SmtpErrorTranslator` centralizzato + diagnostica

Nuovo `Services/Email/SmtpErrorTranslator.cs` (statico, ITA), unico punto dei messaggi SMTP:

`Translate(Exception ex, SmtpPhase phase, string host, int port)` → messaggio user-friendly per tipo reale:

| Errore reale | Messaggio ITA |
|---|---|
| `SocketException` HostNotFound / NoData | "Server di posta non trovato (DNS): controlla il nome host." |
| `SocketException` ConnectionRefused | "Connessione rifiutata sulla porta {port}: porta chiusa o servizio non attivo." |
| Timeout (OperationCanceled / nostro CTS) | vedi diagnostica sotto |
| `SslHandshakeException` | "Errore TLS/SSL: metodo di sicurezza o certificato non compatibili con la porta." |
| `AuthenticationException` | "Credenziali rifiutate: username o password errati." |
| `SmtpCommandException` / `SmtpProtocolException` | "Errore protocollo SMTP: {dettaglio}." |
| fallback | "Errore imprevisto durante il test. Dettaglio tecnico nei log." (grezzo solo nei log) |

**Diagnostica timeout (sonda differenziale):** su timeout di Connect, tentare una connessione TCP breve a `host:443` (fallback `host:80`).
- 443 OK → "Il server è raggiungibile ma la porta {port} non risponde: probabile **firewall o VPN attiva**. Disattiva eventuali VPN e riprova (molti server di posta bloccano gli IP VPN/datacenter)."
- 443 KO → "Host irraggiungibile ({host}): controlla la connessione o il nome del server."

`TestConnectionAsync` e `SmtpEmailSender` smettono di comporre stringhe inline: delegano tutto a `SmtpErrorTranslator`. La struttura a fasi (Connect/Authenticate) di `TestConnectionAsync` resta; cambiano solo i blocchi `catch` che ora chiamano il translator.

## Parte 2 — Toggle "mostra password" (UI)

`AziendaSmtpDialog.razor`, campi **Password** (outbound) e **Password Inbound**:

- Stato `_showPassword` / `_showInboundPassword`; adornment `Icons.Material.Filled.Visibility` / `VisibilityOff` che alterna `InputType` Password↔Text.
- **Primo "mostra" su config salvata**: se il campo vale ancora `***` e `Entity.Id != Empty`, recuperare la password reale decifrata (Parte 0) e sostituirla nel campo, così l'utente la vede e può modificarla in sicurezza (elimina anche il rischio "append su `***`").
- **Vincolo MudBlazor**: l'adornment End è oggi occupato da `AdornmentText="*"` (obbligatorio). Si sposta il marcatore obbligatorio nella label (`Password *`); la validazione `Required` resta invariata.
- Nessun uppercase forzato sui campi password (regola UI edit-form vale per gli altri campi, non per le password).
- **Testo statico**: nota informativa nel dialog (vicino al tasto Test o nel pannello) — "Il test può fallire con VPN attiva: molti server di posta bloccano gli IP VPN/datacenter."

## File toccati

- `SqlScripts/NNN_Smtp_Secrets_Get.sql` (nuova funzione) + `Documents/Funzioni_DB.md`
- `Services/Email/SmtpErrorTranslator.cs` (nuovo)
- `Services/CRUD/AziendaSmtpService.cs` (`GetRealPasswordAsync` + inbound; `TestConnectionAsync` usa il translator)
- `Services/Email/SmtpEmailSender.cs` (usa il translator)
- `Components/Shared/AziendaSmtpDialog.razor` (toggle unmask + testo statico + label `*`)
- `Documents/ComponentiShared.md` / `Documents/Gestione_check.md` (documentare il nuovo translator come punto centralizzato)

## Test / verifica

- Config salvata → "mostra password" rivela il valore reale (`Sardegna2025`), non `***`.
- Test con VPN attiva → messaggio "porta bloccata: firewall o VPN attiva" (non timeout generico).
- Test con host inesistente → messaggio DNS; porta chiusa → "connessione rifiutata"; credenziali errate → "credenziali rifiutate".
- Salvo una password, riapro, smaschero → coincide; invio email la usa correttamente.
- `GV_SECRET_KEY` assente/errata → errore chiaro (fail-fast), nessun crash.

## Note operative

- **VPN OFF per tutti i test SMTP/newsletter** (Connect va in timeout da IP VPN/datacenter a prescindere).
- Vedi [[cifratura-segreti]] (`2026-07-11-Cifratura_Segreti_design.md`) per il modello pgcrypto/`GV_SECRET_KEY`.
