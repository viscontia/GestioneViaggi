using GestioneViaggi.Models.Web;
using GestioneViaggi.Services.CRUD;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.Web;

/// <summary>
/// Il promemoria all'apertura (L2, SqlScripts/671). Le righe le decide il database
/// (fn_promemoria_apertura); qui si leggono, e si ricorda chi le ha già viste oggi.
/// </summary>
public class PromemoriaService
{
    /// <summary>Preferenza utente: la data (yyyy-MM-dd) in cui ha scelto «Non mostrarmelo più oggi».</summary>
    public const string ChiaveNascostoIl = "promemoria_nascosto_il";

    // Una volta per avvio e per utente: il servizio è scoped, l'avvio no.
    private static readonly HashSet<Guid> _mostratoInQuestoAvvio = new();

    private readonly IDatabaseService _databaseService;
    private readonly UserPreferenzeService _preferenze;
    private readonly ILogger<PromemoriaService> _logger;

    public PromemoriaService(IDatabaseService databaseService, UserPreferenzeService preferenze, ILogger<PromemoriaService> logger)
    {
        _databaseService = databaseService;
        _preferenze = preferenze;
        _logger = logger;
    }

    /// <summary>
    /// Le cose in sospeso, nell'ordine del database (urgenza, data).
    /// ⛔️ Un errore si rilancia: un promemoria che tace su un errore sembra «tutto a posto».
    /// </summary>
    public async Task<List<PromemoriaVoce>> ElencoAsync(int aziendaId)
    {
        try
        {
            await using var conn = await _databaseService.GetConnectionAsync();
            await using var cmd = new NpgsqlCommand(
                "SELECT * FROM fn_promemoria_apertura(@AziendaId::integer) ORDER BY urgenza, data_rif, oggetto", conn);
            cmd.Parameters.AddWithValue("AziendaId", aziendaId);

            var righe = new List<PromemoriaVoce>();
            await using var reader = await cmd.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                righe.Add(new PromemoriaVoce(
                    reader.GetString(reader.GetOrdinal("voce")),
                    reader.GetString(reader.GetOrdinal("voce_titolo")),
                    reader.IsDBNull(reader.GetOrdinal("perche")) ? "" : reader.GetString(reader.GetOrdinal("perche")),
                    reader.GetString(reader.GetOrdinal("oggetto")),
                    reader.GetInt32(reader.GetOrdinal("urgenza")),
                    reader.IsDBNull(reader.GetOrdinal("data_rif")) ? null : reader.GetFieldValue<DateOnly>(reader.GetOrdinal("data_rif")),
                    IntONull(reader, "viaggio_id"),
                    IntONull(reader, "data_viaggio_id"),
                    IntONull(reader, "cliente_id")));
            }
            return righe;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Errore nella lettura del promemoria per l'azienda {AziendaId}", aziendaId);
            throw;
        }
    }

    public async Task<bool> NascostoOggiAsync()
        => await _preferenze.GetAsync(ChiaveNascostoIl) == Oggi();

    public Task NascondiOggiAsync()
        => _preferenze.SetAsync(ChiaveNascostoIl, Oggi());

    public bool GiaMostratoInQuestoAvvio(Guid utenteId)
    {
        lock (_mostratoInQuestoAvvio) return _mostratoInQuestoAvvio.Contains(utenteId);
    }

    public void SegnaMostrato(Guid utenteId)
    {
        lock (_mostratoInQuestoAvvio) _mostratoInQuestoAvvio.Add(utenteId);
    }

    private static string Oggi() => DateOnly.FromDateTime(DateTime.Now).ToString("yyyy-MM-dd");

    private static int? IntONull(NpgsqlDataReader r, string col)
    {
        var i = r.GetOrdinal(col);
        return r.IsDBNull(i) ? null : r.GetInt32(i);
    }
}
