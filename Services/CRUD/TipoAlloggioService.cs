using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class TipoAlloggioService : BaseCrudService<TipoAlloggio>
{
    protected override string TableName => "ana_tipo_alloggio";
    protected override string IdColumnName => "tipo_alloggio_id";

    public TipoAlloggioService(IDatabaseService databaseService, ILogger<TipoAlloggioService> logger)
        : base(databaseService, logger)
    {
    }

    // ⚠️ La SQL stava scritta qui dentro, contro la regola del progetto («tutta la SQL
    // vive in funzioni PostgreSQL»). Aggiungendo il genere quelle query andavano
    // comunque toccate: si e' colta l'occasione per portarle dove sta il resto
    // (SqlScripts/601). Cosi' la stessa regola vale anche per il sito di iscrizione.

    /// <summary>Tutti i tipi, con la descrizione del genere per l'elenco.</summary>
    public new async Task<List<TipoAlloggio>> GetAllAsync()
    {
        var esito = new List<TipoAlloggio>();
        await using var connection = await _databaseService.GetConnectionAsync();
        await using var command = new NpgsqlCommand("SELECT * FROM fn_ana_tipo_alloggio_get_all()", connection);

        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync()) esito.Add(MapFromReader(reader));
        return esito;
    }

    /// <summary>
    /// Fra le sistemazioni ammesse, quella da proporre per un gruppo di questa dimensione.
    /// Torna <c>null</c> se non c'è niente di adatto — e allora non si propone nulla,
    /// invece di proporre qualcosa che poi la validazione rifiuta.
    ///
    /// ⚠️ La capienza deve CORRISPONDERE, non bastare. Una doppia con una persona sola si
    /// chiama «doppia uso singola» ed è un tipo suo, con il suo supplemento: proporre una
    /// matrimoniale per uno solo significa far pagare all'azienda un letto in più.
    ///
    /// ⚠️ E il tipo non si riconosce mai dal nome. La versione precedente cercava
    /// «MATRIMONIALE» dentro la descrizione: su un viaggio in tenda non trovava niente, e
    /// bastava rinominare una riga per spegnere il suggerimento in silenzio.
    ///
    /// Sta qui perché era scritta due volte, nella gestione alloggi e nella scheda
    /// Partecipanti, e le due copie erano già divergenti.
    /// </summary>
    public static TipoAlloggio? Suggerisci(IEnumerable<TipoAlloggio> ammessi, int persone)
    {
        if (persone <= 0) return null;

        return ammessi
            .Where(t => t.NumeroOccupanti == persone)
            // A parità di capienza si propone quello senza supplemento: è il più economico
            // per chi viaggia, e resta comunque cambiabile.
            .OrderBy(t => t.Supplemento ? 1 : 0)
            // ⚠️ A parità anche di supplemento serve un criterio, e l'ordine alfabetico non
            // va: fra CAMERA DOPPIA USO SINGOLA, CAMERA SINGOLA e CAMERA SINGOLA DISABILI —
            // tutte da 1 posto e tutte con supplemento — proponeva la prima, cioè la doppia.
            // Si prende la più vecchia (id più basso), che è il tipo base: le varianti sono
            // state aggiunte dopo.
            //
            // ⚠️ È un ripiego, e va detto: il dato NON sa quale sia la sistemazione normale
            // né quale sia riservata a chi ha esigenze particolari. Una camera per disabili
            // non andrebbe mai proposta da sola, e oggi non succede solo perché è stata
            // creata più tardi — per fortuna, non per regola. Servirebbe una colonna.
            // ⛔️ Quello che NON si fa è riconoscerla dal nome: è il difetto tolto dai generi.
            .ThenBy(t => t.Id)
            .FirstOrDefault();
    }

    /// <summary>
    /// I tipi assegnabili su una PARTENZA: quelli del genere che il viaggio prevede, più
    /// «nessuna sistemazione» che vale sempre.
    ///
    /// ⚠️ Da usare al posto di <see cref="GetAllAsync"/> ovunque si stia componendo una
    /// sistemazione. Offrire l'elenco intero è ciò che ha prodotto le 17 assegnazioni
    /// incoerenti trovate in produzione — camere d'albergo su viaggi senza albergo — e il
    /// gestionale è il posto da cui sono nate.
    /// DB Function: fn_alloggi_tipi_ammessi (SqlScripts/600)
    /// </summary>
    public async Task<List<TipoAlloggio>> GetAmmessiPerPartenzaAsync(int dataViaggioId)
    {
        var esito = new List<TipoAlloggio>();
        await using var connection = await _databaseService.GetConnectionAsync();
        await using var command = new NpgsqlCommand(
            "SELECT * FROM fn_alloggi_tipi_ammessi(@dataViaggioId)", connection);
        command.Parameters.AddWithValue("dataViaggioId", dataViaggioId);

        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            esito.Add(new TipoAlloggio
            {
                Id = reader.GetInt32(reader.GetOrdinal("tipo_id")),
                Descrizione = reader.GetString(reader.GetOrdinal("descrizione")),
                NumeroOccupanti = reader.GetInt32(reader.GetOrdinal("posti")),
                SupplementoDb = reader.GetBoolean(reader.GetOrdinal("supplemento")) ? "Y" : "N",
                GenereDescrizione = reader.GetString(reader.GetOrdinal("genere"))
            });
        }
        return esito;
    }

    public override async Task<TipoAlloggio> CreateAsync(TipoAlloggio entity) => await SalvaAsync(entity);

    public override async Task<TipoAlloggio> UpdateAsync(TipoAlloggio entity) => await SalvaAsync(entity);

    private async Task<TipoAlloggio> SalvaAsync(TipoAlloggio entity)
    {
        try
        {
            await using var connection = await _databaseService.GetConnectionAsync();
            await using var command = new NpgsqlCommand(
                "SELECT fn_ana_tipo_alloggio_upsert(@id, @descrizione, @occupanti, @supplemento, @genere)", connection);
            command.Parameters.AddWithValue("id", entity.Id);
            command.Parameters.AddWithValue("descrizione", entity.Descrizione);
            command.Parameters.AddWithValue("occupanti", entity.NumeroOccupanti);
            command.Parameters.AddWithValue("supplemento", entity.SupplementoDb);
            command.Parameters.AddWithValue("genere", entity.GenereFk);

            entity.Id = Convert.ToInt32(await command.ExecuteScalarAsync());
            return entity;
        }
        catch (PostgresException ex)
        {
            // Il messaggio lo scrive il database: e' li' che vive la regola.
            _logger.LogWarning(ex, "Tipo di alloggio non salvato: {Messaggio}", ex.MessageText);
            throw new InvalidOperationException(ex.MessageText, ex);
        }
    }

    protected override TipoAlloggio MapFromReader(NpgsqlDataReader reader)
    {
        return new TipoAlloggio
        {
            Id = ReadInt(reader, "tipo_alloggio_id"),
            Descrizione = reader.GetString(reader.GetOrdinal("tipo_alloggio_descrizione")),
            NumeroOccupanti = reader.GetInt32(reader.GetOrdinal("tipo_alloggio_numero_occupanti")),
            SupplementoDb = reader.GetString(reader.GetOrdinal("tipo_alloggio_supplemento")),
            GenereFk = ReadInt(reader, "genere_fk"),
            GenereDescrizione = HasColumn(reader, "genere_descrizione")
                ? reader.GetString(reader.GetOrdinal("genere_descrizione")) : null
        };
    }
}
