# SMTP Test Connessione — Diagnostica, Messaggi Centralizzati, Unmask — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rendere il "Test connessione" SMTP diagnostico e chiaro (errori centralizzati, VPN/firewall riconosciuti), sbloccare la lettura della password cifrata (bug pgcrypto) e permettere di smascherare la password nel dialog.

**Architecture:** Tre parti. Parte 0: funzione DB `pgp_sym_decrypt` + riscrittura del recupero password in `AziendaSmtpService` (DB-first). Parte 1: `SmtpErrorTranslator` statico (unico punto messaggi) + sonda differenziale al timeout, usato da test e da `SmtpEmailSender`. Parte 2: toggle unmask (outbound/inbound) + testo VPN nel dialog.

**Tech Stack:** .NET 9 / MAUI Blazor, MudBlazor, MailKit, PostgreSQL 17 + pgcrypto, xUnit + Moq, Dapper/Npgsql.

**Riferimento design:** `Documents/2026-07-16-SMTP_TestConnessione_Diagnostica_e_Unmask-design.md`

**Branch:** `feature/estensione-web` (lavorare qui, salvo diversa scelta).

**Pre-condizioni ambiente:** `GV_SECRET_KEY` in ambiente (già in `~/.zshrc`); container `postgres_db` attivo; test SMTP runtime solo con **VPN OFF**.

---

## Task 1: Funzione DB `fn_ana_aziende_smtp_secrets_get` (Parte 0 — DB)

**Files:**
- Create: `SqlScripts/NNN_Smtp_Secrets_Get.sql` (NNN = prossimo numero sequenziale)
- Docs: `Documents/Funzioni_DB.md`

**Step 1: Scegliere il numero script**

Run: `ls SqlScripts | grep -E '^[0-9]+_' | sort -n | tail -3`
Usa il numero successivo al più alto (es. se l'ultimo è 479 → `480_Smtp_Secrets_Get.sql`).

**Step 2: Scrivere la funzione**

```sql
-- SqlScripts/NNN_Smtp_Secrets_Get.sql
-- Recupera outbound + inbound password DECIFRATE per una config SMTP (pgcrypto).
-- Sostituisce la lettura inline rotta password_enc->>'value' (JSONB su colonna bytea).
CREATE OR REPLACE FUNCTION fn_ana_aziende_smtp_secrets_get(
    p_smtp_id  uuid,
    p_master   text
)
RETURNS TABLE (password text, inbound_password text)
LANGUAGE sql
AS $$
    SELECT
        CASE WHEN password_enc         IS NULL THEN NULL ELSE pgp_sym_decrypt(password_enc,         p_master) END,
        CASE WHEN inbound_password_enc IS NULL THEN NULL ELSE pgp_sym_decrypt(inbound_password_enc, p_master) END
    FROM ana_aziende_smtp
    WHERE smtp_id = p_smtp_id;
$$;
```

**Step 3: Deploy in locale**

Run: `docker exec -i postgres_db psql -U postgres -d gestione_viaggi < SqlScripts/NNN_Smtp_Secrets_Get.sql`
Expected: `CREATE FUNCTION`

**Step 4: Verificare il round-trip su azienda 2**

Run (VPN irrilevante qui, è solo DB):
```bash
source .gv_secret_key.local.sh; KEY="$GV_SECRET_KEY"
docker exec -i postgres_db psql -U postgres -d gestione_viaggi -tA <<SQL
SELECT (fn_ana_aziende_smtp_secrets_get(smtp_id, '$KEY')).password
FROM ana_aziende_smtp WHERE azienda_fk = 2;
SQL
```
Expected: `Sardegna2025`

**Step 5: Documentare + commit**

Aggiungi la funzione a `Documents/Funzioni_DB.md` (sezione SMTP, come `fn_get_smtp_config_for_email`).
```bash
git add SqlScripts/NNN_Smtp_Secrets_Get.sql Documents/Funzioni_DB.md
git commit -m "feat(db): fn_ana_aziende_smtp_secrets_get — lettura password SMTP decifrate (pgcrypto)"
```

---

## Task 2: Riscrivere `GetRealPasswordAsync` (Parte 0 — C#)

**Files:**
- Modify: `Services/CRUD/AziendaSmtpService.cs:669-689` (metodo `GetRealPasswordAsync` + commento XML stale)

**Step 1: Sostituire il metodo (usa la funzione DB, master key)**

Rimpiazza `GetRealPasswordAsync` e aggiungi il recupero inbound. Usa Dapper o Npgsql coerente col resto del service.

```csharp
/// <summary>
/// Recupera outbound + inbound password reali (decifrate via pgcrypto) per una config SMTP.
/// La master key arriva dall'ambiente (GV_SECRET_KEY) via ISecretKeyProvider.
/// </summary>
private async Task<(string? password, string? inboundPassword)> GetRealSecretsAsync(Guid smtpId)
{
    try
    {
        var master = _secretKey.GetMasterKey();
        await using var connection = await _databaseService.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT password, inbound_password FROM fn_ana_aziende_smtp_secrets_get(@id, @master)", connection);
        cmd.Parameters.AddWithValue("id", smtpId);
        cmd.Parameters.AddWithValue("master", master);
        await using var r = await cmd.ExecuteReaderAsync();
        if (await r.ReadAsync())
            return (r.IsDBNull(0) ? null : r.GetString(0),
                    r.IsDBNull(1) ? null : r.GetString(1));
        return (null, null);
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Errore recupero segreti SMTP per smtp_id {SmtpId}", smtpId);
        return (null, null);
    }
}

// Compat: mantiene la firma usata dal test connessione outbound
private async Task<string?> GetRealPasswordAsync(Guid smtpId)
    => (await GetRealSecretsAsync(smtpId)).password;
```

**Step 2: Aggiornare il riferimento in `TestConnectionAsync` (già chiama `GetRealPasswordAsync`, resta valido).**

Nessuna modifica al chiamante (`:549`) — la firma è invariata.

**Step 3: Build**

Run: `dotnet build -f net9.0-maccatalyst 2>&1 | tail -5`
Expected: `Build succeeded` (0 error)

**Step 4: Verifica runtime del recupero (con VPN OFF non serve; è solo DB read)**

Riavvia l'app, apri config SMTP azienda 2, clicca "Test connessione" (VPN OFF): non deve più comparire "Password non recuperabile"; deve arrivare a Connect/Authenticate.

**Step 5: Commit**

```bash
git add Services/CRUD/AziendaSmtpService.cs
git commit -m "fix(smtp): recupero password decifrata via fn DB pgcrypto (era ->>'value' rotto su bytea)"
```

---

## Task 3: `SmtpErrorTranslator` — messaggi centralizzati (Parte 1, TDD)

**Files:**
- Create: `Services/Email/SmtpErrorTranslator.cs`
- Test: `Unit_Tests/TestsProject/SmtpErrorTranslatorTests.cs`

**Step 1: Scrivere i test che falliscono**

```csharp
using Xunit;
using System.Net.Sockets;
using MailKit.Security;
using GestioneViaggi.Services.Email;

namespace GestioneViaggi.Unit_Tests;

public class SmtpErrorTranslatorTests
{
    [Fact] public void HostNotFound_DaMessaggioDns()
    {
        var ex = new SocketException((int)SocketError.HostNotFound);
        var msg = SmtpErrorTranslator.Translate(ex, SmtpPhase.Connect, "x.y", 465);
        Assert.Contains("DNS", msg);
    }

    [Fact] public void ConnectionRefused_CitaLaPorta()
    {
        var ex = new SocketException((int)SocketError.ConnectionRefused);
        var msg = SmtpErrorTranslator.Translate(ex, SmtpPhase.Connect, "x.y", 587);
        Assert.Contains("587", msg);
        Assert.Contains("rifiutata", msg);
    }

    [Fact] public void Auth_MessaggioCredenziali()
    {
        var ex = new AuthenticationException("bad");
        var msg = SmtpErrorTranslator.Translate(ex, SmtpPhase.Authenticate, "x.y", 465);
        Assert.Contains("Credenziali", msg);
    }

    [Fact] public void Ssl_MessaggioTls()
    {
        var ex = new SslHandshakeException("tls");
        var msg = SmtpErrorTranslator.Translate(ex, SmtpPhase.Connect, "x.y", 465);
        Assert.Contains("TLS", msg);
    }
}
```

**Step 2: Verificare che falliscano (non compila: tipo mancante)**

Run: `dotnet test Unit_Tests/TestsProject/GestioneViaggi.Tests.csproj --filter SmtpErrorTranslatorTests 2>&1 | tail -15`
Expected: errore di compilazione "SmtpErrorTranslator does not exist".

**Step 3: Implementare il translator**

```csharp
using System.Net.Sockets;
using MailKit.Security;
using MailKit.Net.Smtp;

namespace GestioneViaggi.Services.Email;

public enum SmtpPhase { Connect, Authenticate }

/// <summary>
/// Punto UNICO dei messaggi d'errore SMTP (ITA). Mirror di DbErrorTranslator per il dominio rete/posta.
/// Usato da AziendaSmtpService.TestConnectionAsync e da SmtpEmailSender.
/// </summary>
public static class SmtpErrorTranslator
{
    public static string Translate(Exception ex, SmtpPhase phase, string host, int port) => ex switch
    {
        SocketException se when se.SocketErrorCode is SocketError.HostNotFound
                                                    or SocketError.NoData
                                                    or SocketError.TryAgain
            => $"Server di posta non trovato (DNS): controlla il nome host \"{host}\".",
        SocketException se when se.SocketErrorCode == SocketError.ConnectionRefused
            => $"Connessione rifiutata sulla porta {port}: porta chiusa o servizio non attivo su \"{host}\".",
        SocketException
            => $"Rete non raggiungibile verso \"{host}:{port}\": controlla la connessione.",
        SslHandshakeException
            => $"Errore TLS/SSL su \"{host}:{port}\": metodo di sicurezza o certificato non compatibili con la porta.",
        AuthenticationException
            => "Credenziali rifiutate: username o password errati.",
        SmtpCommandException sce
            => $"Errore SMTP dal server: {sce.Message}",
        SmtpProtocolException
            => "Errore di protocollo SMTP nella comunicazione con il server.",
        OperationCanceledException
            => $"Timeout: nessuna risposta da \"{host}:{port}\".", // dettaglio VPN/firewall aggiunto dal chiamante (Task 4)
        _ => "Errore imprevisto durante l'operazione SMTP. Dettaglio tecnico nei log."
    };
}
```

**Step 4: Verificare che i test passino**

Run: `dotnet test Unit_Tests/TestsProject/GestioneViaggi.Tests.csproj --filter SmtpErrorTranslatorTests 2>&1 | tail -8`
Expected: `Passed! - Failed: 0`

**Step 5: Commit**

```bash
git add Services/Email/SmtpErrorTranslator.cs Unit_Tests/TestsProject/SmtpErrorTranslatorTests.cs
git commit -m "feat(smtp): SmtpErrorTranslator — messaggi errore centralizzati ITA per tipo reale"
```

---

## Task 4: Sonda differenziale al timeout (Parte 1 — diagnostica VPN/firewall)

**Files:**
- Modify: `Services/Email/SmtpErrorTranslator.cs` (helper reachability)
- Test: `Unit_Tests/TestsProject/SmtpErrorTranslatorTests.cs`

**Step 1: Test per il messaggio timeout diagnosticato**

```csharp
[Fact] public void Timeout_HostRaggiungibile_SuggerisceVpnFirewall()
{
    var msg = SmtpErrorTranslator.TimeoutMessage(hostReachableOnWeb: true, "x.y", 465);
    Assert.Contains("VPN", msg);
    Assert.Contains("firewall", msg);
}

[Fact] public void Timeout_HostIrraggiungibile_SuggerisceConnessione()
{
    var msg = SmtpErrorTranslator.TimeoutMessage(hostReachableOnWeb: false, "x.y", 465);
    Assert.Contains("irraggiungibile", msg);
}
```

**Step 2: Verificare fail**

Run: `dotnet test ... --filter SmtpErrorTranslatorTests 2>&1 | tail -8`
Expected: FAIL (TimeoutMessage inesistente)

**Step 3: Aggiungere helper al translator**

```csharp
// dentro SmtpErrorTranslator
public static string TimeoutMessage(bool hostReachableOnWeb, string host, int port) =>
    hostReachableOnWeb
        ? $"Il server \"{host}\" è raggiungibile ma la porta {port} non risponde: probabile firewall o VPN attiva. " +
          "Disattiva eventuali VPN e riprova (molti server di posta bloccano gli IP VPN/datacenter)."
        : $"Host irraggiungibile (\"{host}\"): controlla la connessione o il nome del server.";

/// <summary>Probe TCP breve: il server risponde su 443 (o 80)? Usato per diagnosticare i timeout.</summary>
public static async Task<bool> IsHostReachableOnWebAsync(string host, int timeoutMs = 4000)
{
    foreach (var p in new[] { 443, 80 })
    {
        try
        {
            using var c = new System.Net.Sockets.TcpClient();
            using var cts = new CancellationTokenSource(timeoutMs);
            await c.ConnectAsync(host, p, cts.Token);
            if (c.Connected) return true;
        }
        catch { /* prova la prossima porta */ }
    }
    return false;
}
```

**Step 4: Verificare pass**

Run: `dotnet test ... --filter SmtpErrorTranslatorTests 2>&1 | tail -8`
Expected: `Passed! - Failed: 0`

**Step 5: Commit**

```bash
git add Services/Email/SmtpErrorTranslator.cs Unit_Tests/TestsProject/SmtpErrorTranslatorTests.cs
git commit -m "feat(smtp): diagnostica timeout (sonda web 443/80) — distingue VPN/firewall da host irraggiungibile"
```

---

## Task 5: Cablare `TestConnectionAsync` e `SmtpEmailSender` sul translator (Parte 1)

**Files:**
- Modify: `Services/CRUD/AziendaSmtpService.cs:575-626` (blocchi catch di Connect/Authenticate)
- Modify: `Services/Email/SmtpEmailSender.cs` (catch invio)

**Step 1: Connect — usare translator + diagnostica timeout**

Sostituire i `catch` della Fase 1 (`:582-598`):
```csharp
catch (OperationCanceledException)
{
    var reachable = await SmtpErrorTranslator.IsHostReachableOnWebAsync(config.Host);
    result.IsSuccess = false;
    result.ErrorMessage = SmtpErrorTranslator.TimeoutMessage(reachable, config.Host, config.Port);
    result.Message = "Connessione fallita: timeout";
    result.Duration = DateTime.Now - startTime;
    return result;
}
catch (Exception ex)
{
    result.IsSuccess = false;
    result.ErrorMessage = SmtpErrorTranslator.Translate(ex, SmtpPhase.Connect, config.Host, config.Port);
    result.Message = "Connessione al server fallita";
    result.Duration = DateTime.Now - startTime;
    _logger.LogError(ex, "Errore Connect SMTP a {Host}:{Port}", config.Host, config.Port);
    return result;
}
```

**Step 2: Authenticate — usare translator** (sostituire `:607-626`):
```csharp
catch (Exception ex)
{
    result.IsSuccess = false;
    result.ErrorMessage = SmtpErrorTranslator.Translate(ex, SmtpPhase.Authenticate, config.Host, config.Port);
    result.Message = "Autenticazione fallita";
    result.Duration = DateTime.Now - startTime;
    _logger.LogWarning(ex, "Auth SMTP fallita per {Username} su {Host}", config.Username, config.Host);
    try { await client.DisconnectAsync(true); } catch { }
    return result;
}
```
(Rimuove il ramo `AuthenticationException` dedicato: ora il translator lo copre. Verifica il `using` di `AuthenticationException` — è `MailKit.Security`.)

**Step 3: `SmtpEmailSender`** — nel/nei catch dell'invio, sostituire i messaggi grezzi con `SmtpErrorTranslator.Translate(ex, phase, host, port)`. (Individua i catch con `graphify query "SmtpEmailSender invio errori"` poi apri il file.)

**Step 4: Build**

Run: `dotnet build -f net9.0-maccatalyst 2>&1 | tail -5`
Expected: `Build succeeded`

**Step 5: Verifica runtime (VPN ON per provocare il timeout diagnosticato)**

Con **VPN attiva**, "Test connessione" azienda 2 → messaggio deve contenere "firewall o VPN attiva" (non più timeout generico). Poi **VPN OFF** → il test arriva ad Authenticate e riesce.

**Step 6: Commit**

```bash
git add Services/CRUD/AziendaSmtpService.cs Services/Email/SmtpEmailSender.cs
git commit -m "refactor(smtp): test connessione e invio usano SmtpErrorTranslator (messaggi unici + diagnostica VPN)"
```

---

## Task 6: Unmask password + testo VPN nel dialog (Parte 2 — UI)

**Files:**
- Modify: `Components/Shared/AziendaSmtpDialog.razor` (campo Password `:100-113`, Inbound `:282-290`, stato/handler in `@code`)

**Step 1: Stato + handler nel blocco `@code`**

```csharp
private bool _showPassword;
private bool _showInboundPassword;

private async Task ToggleShowPassword()
{
    if (!_showPassword && Entity.Password == "***" && Entity.Id != Guid.Empty)
    {
        var real = await SmtpService.GetRealPasswordForEditAsync(Entity.Id); // nuovo metodo pubblico (vedi nota)
        if (!string.IsNullOrEmpty(real)) Entity.Password = real;
    }
    _showPassword = !_showPassword;
}
// analogo ToggleShowInboundPassword usando l'inbound
```
Nota: esporre in `AziendaSmtpService` un metodo pubblico sottile `Task<string?> GetRealPasswordForEditAsync(Guid)` e `GetRealInboundPasswordForEditAsync(Guid)` che riusano `GetRealSecretsAsync` (Task 2). Rispetta il tenant (verifica accesso azienda) prima di restituire.

**Step 2: Campo Password (outbound) con toggle**

Sostituire l'adornment `*` con l'icona toggle e spostare l'obbligatorietà nella label:
```razor
<MudTextField @bind-Value="Entity.Password"
              For="@(() => Entity.Password)"
              Label="Password *"
              Variant="Variant.Outlined"
              Required="true"
              RequiredError="La password è obbligatoria"
              Validation="@(new Func<string, IEnumerable<string>>(ValidateSmtpPassword))"
              Immediate="true"
              InputType="@(_showPassword ? InputType.Text : InputType.Password)"
              Adornment="Adornment.End"
              AdornmentIcon="@(_showPassword ? Icons.Material.Filled.VisibilityOff : Icons.Material.Filled.Visibility)"
              OnAdornmentClick="ToggleShowPassword"
              AdornmentAriaLabel="Mostra/Nascondi password"
              Class="mb-3" />
```

**Step 3: Campo Password Inbound** — stesso pattern con `_showInboundPassword` / `ToggleShowInboundPassword` (resta opzionale, nessun `Required`).

**Step 4: Testo statico VPN** (vicino al tasto Test o sotto il pannello):
```razor
<MudText Typo="Typo.caption" Class="mud-text-secondary mb-2">
    Il test può fallire con VPN attiva: molti server di posta bloccano gli IP VPN/datacenter. Disattiva la VPN per testare.
</MudText>
```

**Step 5: Build**

Run: `dotnet build -f net9.0-maccatalyst 2>&1 | tail -5`
Expected: `Build succeeded`

**Step 6: Verifica runtime**

Apri config azienda 2 (VPN OFF): clic sull'occhio sul campo Password → mostra `Sardegna2025`; inbound analogo; testo VPN visibile.

**Step 7: Commit**

```bash
git add Components/Shared/AziendaSmtpDialog.razor Services/CRUD/AziendaSmtpService.cs
git commit -m "feat(smtp-ui): toggle mostra password (outbound+inbound) con decifratura reale + avviso VPN"
```

---

## Task 7: Documentazione + grafo

**Files:**
- Modify: `Documents/ComponentiShared.md` (dialog SMTP: nuovo toggle), `Documents/Gestione_check.md` (SmtpErrorTranslator come punto centralizzato messaggi SMTP)

**Step 1:** Aggiungere a `Gestione_check.md` una sezione "SmtpErrorTranslator" accanto a DbErrorTranslator (unico posto messaggi SMTP; come estenderlo).

**Step 2:** Nota in `ComponentiShared.md` sul toggle unmask del dialog SMTP.

**Step 3: Commit**
```bash
git add Documents/ComponentiShared.md Documents/Gestione_check.md
git commit -m "docs(smtp): SmtpErrorTranslator centralizzato + unmask dialog"
```

**Step 4:** Aggiornare il grafo (doc semantici): eseguire nell'assistente `/graphify --update`.

---

## Definition of Done

- [ ] Test su config salvata (VPN OFF) arriva ad Authenticate e riesce; nessun "Password non recuperabile".
- [ ] Timeout (VPN ON) → messaggio "firewall o VPN attiva".
- [ ] DNS/porta chiusa/credenziali/SSL → messaggi dedicati corretti.
- [ ] Occhio mostra/nasconde password reale (outbound + inbound).
- [ ] Testo avviso VPN visibile.
- [ ] `dotnet build -f net9.0-maccatalyst` verde; `dotnet test` verde.
- [ ] `Funzioni_DB.md`, `Gestione_check.md`, `ComponentiShared.md` aggiornati; `/graphify --update` eseguito.

## Note

- **VPN OFF** per ogni verifica runtime che coinvolge l'auth/invio reale.
- Script SQL 480 (o successivo) va aggiunto anche alla checklist Go-Live PROD (`Estensione Progetto WEB/Documenti/2026-07-10-Checklist_Go_Live_PROD.md`).
- Il metodo pubblico di recupero password per la UI deve validare il tenant (accesso azienda) prima di restituire il chiaro.
