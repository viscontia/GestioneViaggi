using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Shared.Storage;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// La scheda «Sito web» dell'azienda e le garanzie del tour operator (script 692).
/// Solo funzioni fn_*; ogni salvataggio avvisa da sé la coda di rigenerazione del sito (trigger).
/// </summary>
/// <remarks>
/// Disegno: Sito Web SFT/Documenti/Analisi/2026-10-19-Tappa_4_Contorno_Disegno.md.
/// Quando un testo italiano cambia, le sue traduzioni diventano obsolete (come per i testi dei tour):
/// il sito mostra l'italiano finché non si ritraduce.
/// </remarks>
public sealed class WebSitoContenutiService
{
    private readonly IDatabaseService _db;
    private readonly WebTraduzioniService _traduzioni;
    private readonly IWebMediaStorage _storage;
    private readonly ILogger<WebSitoContenutiService> _logger;

    public WebSitoContenutiService(IDatabaseService db, WebTraduzioniService traduzioni, IWebMediaStorage storage,
                                   ILogger<WebSitoContenutiService> logger)
    {
        _db = db; _traduzioni = traduzioni; _storage = storage; _logger = logger;
    }

    /// <summary>I contenuti dell'azienda; vuoti (non null) se la riga non c'è ancora.</summary>
    public async Task<WebSitoContenuti> GetAsync(int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT * FROM fn_web_sito_contenuti_get(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new WebSitoContenuti { AziendaId = aziendaId };
        return new WebSitoContenuti
        {
            AziendaId = aziendaId,
            FotoHomeFk = r["foto_home_fk"] as long?,
            Motto = r["motto"] as string,
            TitoloHome = r["titolo_home"] as string,
            SottotitoloHome = r["sottotitolo_home"] as string,
            EmailMessaggiFk = r["email_messaggi_fk"] as int?,
            EvidenzaTitolo = r["evidenza_titolo"] as string,
            FotoHomeUrl = r["foto_home_url"] as string,
            FotoHomeLarghezza = r["foto_home_larghezza"] as int?,
            FotoHomeAltezza = r["foto_home_altezza"] as int?,
            VideoHomeUrl = r["video_home_url"] as string,
            VideoHomeTelefonoUrl = r["video_home_telefono_url"] as string,
            VideoHomeLarghezza = r["video_home_larghezza"] as int?,
            VideoHomeAltezza = r["video_home_altezza"] as int?,
            VideoHomeDurata = r["video_home_durata"] as decimal?,
            NoteLegali = r["note_legali"] as string,
            Privacy = r["privacy"] as string,
            Cookie = r["cookie"] as string,
            NoteLegaliAggiornato = r["note_legali_aggiornato"] as DateTime?,
            PrivacyAggiornato = r["privacy_aggiornato"] as DateTime?,
            CookieAggiornato = r["cookie_aggiornato"] as DateTime?,
            UpdatedBy = r["updated_by"] as string,
            Updated = r["updated"] as DateTime?,
        };
    }

    /// <summary>
    /// Salva la sotto-scheda Home. I testi italiani cambiati rendono obsolete le loro traduzioni.
    /// Restituisce quanti campi tradotti sono diventati da ritradurre.
    /// </summary>
    public async Task<int> SaveAsync(WebSitoContenuti c, string utente)
    {
        var prima = await GetAsync(c.AziendaId);

        await using (var conn = await _db.GetConnectionAsync())
        await using (var cmd = new NpgsqlCommand(
            "SELECT fn_web_sito_contenuti_save(@Az::integer, @Foto::bigint, @Motto::varchar, @TitoloHome::varchar, " +
            "@SottotitoloHome::varchar, @Email::integer, @Titolo::varchar, @Utente::varchar)", conn))
        {
            cmd.Parameters.AddWithValue("Az", c.AziendaId);
            cmd.Parameters.AddWithValue("Foto", (object?)c.FotoHomeFk ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Motto", (object?)c.Motto ?? DBNull.Value);
            cmd.Parameters.AddWithValue("TitoloHome", (object?)c.TitoloHome ?? DBNull.Value);
            cmd.Parameters.AddWithValue("SottotitoloHome", (object?)c.SottotitoloHome ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Email", (object?)c.EmailMessaggiFk ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Titolo", (object?)c.EvidenzaTitolo ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Utente", utente);
            await cmd.ExecuteNonQueryAsync();
        }

        // Il confronto si fa sui valori puliti, come li salva il database (spazi ai bordi, vuoto = NULL):
        // aggiungere uno spazio non deve buttare via una traduzione rivista.
        var dopo = await GetAsync(c.AziendaId);
        var obsolete = 0;
        var vecchi = prima.CampiTraducibili().ToDictionary(x => x.Campo, x => x.Valore);
        foreach (var (campo, _, valore) in dopo.CampiTraducibili())
        {
            if (string.Equals(vecchi[campo], valore, StringComparison.Ordinal)) continue;
            obsolete += await _traduzioni.MarkObsoleteAsync(c.AziendaId, WebSitoContenuti.Entita, c.AziendaId, campo);
        }
        if (obsolete > 0)
            _logger.LogInformation("Scheda «Sito web» {Az}: {N} traduzioni diventate obsolete", c.AziendaId, obsolete);
        return obsolete;
    }

    /// <summary>
    /// Salva i tre testi legali (script 701; a parte dalla Home). Il database normalizza l'HTML vuoto di Quill e
    /// aggiorna la data solo del testo che cambia. Le traduzioni dei testi cambiati diventano obsolete.
    /// </summary>
    public async Task<int> SaveTestiLegaliAsync(WebSitoContenuti c, string utente)
    {
        var prima = await GetAsync(c.AziendaId);
        await using (var conn = await _db.GetConnectionAsync())
        await using (var cmd = new NpgsqlCommand(
            "SELECT fn_web_sito_testi_legali_save(@Az::integer, @Note::text, @Privacy::text, @Cookie::text, @Utente::varchar)", conn))
        {
            cmd.Parameters.AddWithValue("Az", c.AziendaId);
            cmd.Parameters.AddWithValue("Note", (object?)c.NoteLegali ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Privacy", (object?)c.Privacy ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Cookie", (object?)c.Cookie ?? DBNull.Value);
            cmd.Parameters.AddWithValue("Utente", utente);
            await cmd.ExecuteNonQueryAsync();
        }
        var dopo = await GetAsync(c.AziendaId);
        var obsolete = 0;
        var vecchi = prima.CampiTestiLegali().ToDictionary(x => x.Campo, x => x.Valore);
        foreach (var (campo, _, valore) in dopo.CampiTestiLegali())
        {
            if (string.Equals(vecchi[campo], valore, StringComparison.Ordinal)) continue;
            obsolete += await _traduzioni.MarkObsoleteAsync(c.AziendaId, WebSitoContenuti.Entita, c.AziendaId, campo);
        }
        return obsolete;
    }

    /// <summary>I contenuti dei tour in evidenza, nell'ordine.</summary>
    public async Task<List<long>> ListEvidenzaAsync(int aziendaId)
    {
        var list = new List<long>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT web_tour_contenuti_id FROM fn_web_sito_evidenza_list(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(r.GetInt64(0));
        return list;
    }

    /// <summary>Sostituisce l'elenco dei tour in evidenza (al massimo 3: lo controlla il database).</summary>
    public async Task SaveEvidenzaAsync(int aziendaId, IReadOnlyList<long> contenuti, string utente)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT fn_web_sito_evidenza_save(@Az::integer, @Ids::bigint[], @Utente::varchar)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("Ids", contenuti.ToArray());
        cmd.Parameters.AddWithValue("Utente", utente);
        await cmd.ExecuteNonQueryAsync();
    }

    /// <summary>
    /// I tour che si possono scegliere per «In evidenza»: quelli che il sito mostra adesso. Si usa la stessa
    /// funzione del sito (fn_web_tour_pubblicati), così «pubblicato» ha una definizione sola.
    /// </summary>
    public async Task<List<TourPubblicatoScelta>> ListTourPubblicatiAsync(int aziendaId)
    {
        var list = new List<TourPubblicatoScelta>();
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT contenuto_id, titolo, data_inizio FROM fn_web_tour_pubblicati(@Az::integer, 'IT')", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            list.Add(new TourPubblicatoScelta(
                r.GetInt64(0),
                r.IsDBNull(1) ? "(senza titolo)" : r.GetString(1),
                r.IsDBNull(2) ? null : DateOnly.FromDateTime(r.GetDateTime(2))));
        return list;
    }

    public async Task<GaranzieAzienda> GetGaranzieAsync(int aziendaId)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT * FROM fn_ana_aziende_garanzie_get(@Az::integer)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        await using var r = await cmd.ExecuteReaderAsync();
        if (!await r.ReadAsync()) return new GaranzieAzienda(null, null, null, null);
        return new GaranzieAzienda(
            r["polizza_rc_compagnia"] as string, r["polizza_rc_numero"] as string,
            r["fondo_garanzia_ente"] as string, r["fondo_garanzia_estremi"] as string);
    }

    /// <summary>Salva polizza RC e fondo di garanzia (testi vuoti → NULL, lo fa il database).</summary>
    public async Task SaveGaranzieAsync(int aziendaId, GaranzieAzienda g)
    {
        await using var conn = await _db.GetConnectionAsync();
        await using var cmd = new NpgsqlCommand(
            "SELECT fn_ana_aziende_garanzie_save(@Az::integer, @C::varchar, @N::varchar, @E::varchar, @S::varchar)", conn);
        cmd.Parameters.AddWithValue("Az", aziendaId);
        cmd.Parameters.AddWithValue("C", (object?)g.PolizzaRcCompagnia ?? DBNull.Value);
        cmd.Parameters.AddWithValue("N", (object?)g.PolizzaRcNumero ?? DBNull.Value);
        cmd.Parameters.AddWithValue("E", (object?)g.FondoGaranziaEnte ?? DBNull.Value);
        cmd.Parameters.AddWithValue("S", (object?)g.FondoGaranziaEstremi ?? DBNull.Value);
        await cmd.ExecuteNonQueryAsync();
    }

    /// <summary>
    /// Manda allo Storage la foto della home (698) e la registra; cancella quella vecchia. Se il database
    /// rifiuta, si cancella il file appena caricato: niente file orfani. <c>null</c> = togliere la foto.
    /// </summary>
    public async Task SalvaFotoHomeAsync(int aziendaId, FotoHomeNuova? foto, string utente, CancellationToken ct = default)
    {
        string? path = null, url = null;
        if (foto is not null)
        {
            path = $"libreria/{aziendaId}/home-foto-{Guid.NewGuid():N}.webp";
            await using (var ms = new MemoryStream(foto.Bytes))
                await _storage.UploadAsync(path, ms, foto.Mime, ct);
            url = _storage.BuildPublicUrl(path);
        }
        var vecchi = await RegistraAsync(
            "SELECT percorso FROM fn_web_sito_foto_home_save(@Az::integer, @Url::text, @Path::text, @W::integer, @H::integer, @Utente::varchar)",
            cmd =>
            {
                cmd.Parameters.AddWithValue("Az", aziendaId);
                cmd.Parameters.AddWithValue("Url", (object?)url ?? DBNull.Value);
                cmd.Parameters.AddWithValue("Path", (object?)path ?? DBNull.Value);
                cmd.Parameters.AddWithValue("W", (object?)foto?.Larghezza ?? DBNull.Value);
                cmd.Parameters.AddWithValue("H", (object?)foto?.Altezza ?? DBNull.Value);
                cmd.Parameters.AddWithValue("Utente", utente);
            }, new[] { path }, ct);
        await CancellaAsync(vecchi, ct);
    }

    /// <summary>
    /// Manda allo Storage le due versioni del video della home e la sua copertina (698, 699) e le registra; cancella le vecchie.
    /// Stesse regole della foto. <c>null</c> = togliere il video.
    /// </summary>
    public async Task SalvaVideoHomeAsync(int aziendaId, WebVideoProcessor.VideoPreparato? video, string utente, CancellationToken ct = default)
    {
        string? path = null, pathTel = null, pathCop = null;
        if (video is not null)
        {
            var nome = $"libreria/{aziendaId}/home-video-{Guid.NewGuid():N}";
            var caricati = new List<string>();
            try
            {
                foreach (var (p, file, mime) in new[]
                         {
                             ($"{nome}.mp4", video.FileComputer, WebVideoProcessor.Mime),
                             ($"{nome}-telefono.mp4", video.FileTelefono, WebVideoProcessor.Mime),
                             ($"{nome}-copertina.jpg", video.FileCopertina, WebVideoProcessor.MimeCopertina),
                         })
                {
                    await using var f = File.OpenRead(file);
                    await _storage.UploadAsync(p, f, mime, ct);
                    caricati.Add(p);
                }
            }
            catch
            {
                // un caricamento a metà non lascia file orfani
                foreach (var p in caricati)
                    try { await _storage.DeleteAsync(p, ct); } catch { }
                throw;
            }
            (path, pathTel, pathCop) = (caricati[0], caricati[1], caricati[2]);
        }
        var vecchi = await RegistraAsync(
            "SELECT percorso FROM fn_web_sito_video_home_save(@Az::integer, @Url::text, @Path::text, @UrlTel::text, @PathTel::text, " +
            "@UrlCop::text, @PathCop::text, @W::integer, @H::integer, @Durata::numeric, @Utente::varchar)",
            cmd =>
            {
                cmd.Parameters.AddWithValue("Az", aziendaId);
                cmd.Parameters.AddWithValue("Url", path is null ? DBNull.Value : _storage.BuildPublicUrl(path));
                cmd.Parameters.AddWithValue("Path", (object?)path ?? DBNull.Value);
                cmd.Parameters.AddWithValue("UrlTel", pathTel is null ? DBNull.Value : _storage.BuildPublicUrl(pathTel));
                cmd.Parameters.AddWithValue("PathTel", (object?)pathTel ?? DBNull.Value);
                cmd.Parameters.AddWithValue("UrlCop", pathCop is null ? DBNull.Value : _storage.BuildPublicUrl(pathCop));
                cmd.Parameters.AddWithValue("PathCop", (object?)pathCop ?? DBNull.Value);
                cmd.Parameters.AddWithValue("W", (object?)video?.Larghezza ?? DBNull.Value);
                cmd.Parameters.AddWithValue("H", (object?)video?.Altezza ?? DBNull.Value);
                cmd.Parameters.AddWithValue("Durata", video is null ? DBNull.Value : (decimal)Math.Round(video.Durata, 2));
                cmd.Parameters.AddWithValue("Utente", utente);
            }, new[] { path, pathTel, pathCop }, ct);
        await CancellaAsync(vecchi, ct);
    }

    // Registra nel database e restituisce i percorsi vecchi; se il database rifiuta, toglie i file nuovi.
    private async Task<List<string>> RegistraAsync(string sql, Action<NpgsqlCommand> parametri, string?[] nuovi, CancellationToken ct)
    {
        try
        {
            var vecchi = new List<string>();
            await using var conn = await _db.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(sql, conn);
            parametri(cmd);
            await using var r = await cmd.ExecuteReaderAsync(ct);
            while (await r.ReadAsync(ct)) vecchi.Add(r.GetString(0));
            return vecchi;
        }
        catch
        {
            foreach (var p in nuovi.OfType<string>())
                try { await _storage.DeleteAsync(p, ct); } catch { /* resta orfano: lo si vede nello Storage */ }
            throw;
        }
    }

    // I file vecchi: se non si cancellano restano orfani nello Storage, ma la scheda è salvata: lo si scrive nel giornale.
    private async Task CancellaAsync(IEnumerable<string> percorsi, CancellationToken ct)
    {
        foreach (var p in percorsi)
        {
            try { await _storage.DeleteAsync(p, ct); }
            catch (Exception ex) { _logger.LogWarning(ex, "Sito web: file vecchio {Path} non cancellato dallo Storage", p); }
        }
    }

    /// <summary>Carica (o ricarica) lo stato della scheda dal database: bozza = salvato.</summary>
    public async Task CaricaBozzaAsync(SitoWebBozza b, int aziendaId)
    {
        b.AziendaId = aziendaId;
        b.Salvato = await GetAsync(aziendaId);
        b.Bozza = b.Salvato.Copia();
        b.EvidenzaSalvata = await ListEvidenzaAsync(aziendaId);
        b.Evidenza = b.EvidenzaSalvata.ToList();
        b.ScartaMedia();
        b.Modificata = false;
        b.Caricata = true;
    }

    /// <summary>
    /// Salva la bozza (testi e, se cambiato, l'elenco «In evidenza») e la ricarica. La usano il bottone
    /// «Aggiorna» del dialogo e «Traduci» della scheda. Restituisce le traduzioni diventate obsolete.
    /// </summary>
    public async Task<int> SalvaBozzaAsync(SitoWebBozza b, string utente)
    {
        var obsolete = await SaveAsync(b.Bozza, utente);
        if (b.Bozza.TestiLegaliDiversiDa(b.Salvato))
            obsolete += await SaveTestiLegaliAsync(b.Bozza, utente);
        if (!b.Evidenza.SequenceEqual(b.EvidenzaSalvata))
            await SaveEvidenzaAsync(b.AziendaId, b.Evidenza, utente);
        // Foto e video dopo i testi: una foto caricata spegne la scelta dalla libreria (698), e i testi la
        // salvano ancora com'era. Ognuno si salva da sé: se il video non va, testi e foto restano salvati.
        if (b.FotoNuova is not null || b.FotoTolta)
        {
            await SalvaFotoHomeAsync(b.AziendaId, b.FotoNuova, utente);
            b.FotoNuova = null; b.FotoTolta = false;   // salvata: un secondo «Aggiorna» non la ricarica
        }
        if (b.VideoNuovo is not null || b.VideoTolto)
            await SalvaVideoHomeAsync(b.AziendaId, b.VideoNuovo, utente);
        await CaricaBozzaAsync(b, b.AziendaId);
        return obsolete;
    }

    /// <summary>I testi della sotto-scheda Home da tradurre (solo quelli compilati).</summary>
    public static List<TranslatableItem> ElementiHome(WebSitoContenuti c) =>
        c.CampiTraducibili()
         .Where(x => !string.IsNullOrWhiteSpace(x.Valore))
         .Select(x => new TranslatableItem(WebSitoContenuti.Entita, c.AziendaId, x.Campo, x.Etichetta, x.Valore!))
         .ToList();

    /// <summary>I testi legali da tradurre (solo quelli compilati).</summary>
    public static List<TranslatableItem> ElementiTestiLegali(WebSitoContenuti c) =>
        c.CampiTestiLegali()
         .Where(x => !string.IsNullOrWhiteSpace(x.Valore))
         .Select(x => new TranslatableItem(WebSitoContenuti.Entita, c.AziendaId, x.Campo, x.Etichetta, x.Valore!))
         .ToList();

    /// <summary>Tutti i testi della scheda «Sito web» da tradurre: «Aggiorna» li controlla tutti.</summary>
    public static List<TranslatableItem> ElementiDaTradurre(WebSitoContenuti c) =>
        c.CampiTraducibili().Concat(c.CampiTestiLegali())
         .Where(x => !string.IsNullOrWhiteSpace(x.Valore))
         .Select(x => new TranslatableItem(WebSitoContenuti.Entita, c.AziendaId, x.Campo, x.Etichetta, x.Valore!))
         .ToList();
}
