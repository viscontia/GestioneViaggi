
using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Npgsql;
using System.Data;

namespace GestioneViaggi.Services.CRUD
{
    public class MovClientiViaggiService
    {
        private readonly IDatabaseConnectionManager _connectionManager;

        public MovClientiViaggiService(IDatabaseConnectionManager connectionManager)
        {
            _connectionManager = connectionManager;
        }

        public async Task<int> AddParticipantAsync(MovClientiViaggi entity)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                var p = new DynamicParameters();
                p.Add("p_viaggio_id", entity.ViaggioIdFk);
                p.Add("p_data_viaggio_id", entity.DataViaggioIdFk);
                p.Add("p_cliente_id", entity.ClienteIdFk);
                p.Add("p_tipo_partecipante_id", entity.TipoPartecipanteIdFk);
                p.Add("p_ana_mezzi_id", entity.AnaMezziIdFk);
                p.Add("p_mezzo_modello_id", entity.MezzoModelloIdFk);
                p.Add("p_sconto_val_totale", entity.MovClienteViaggioScontovalTotale);
                p.Add("p_targa_mezzo", entity.MovClienteViaggioTargaMezzo);
                p.Add("p_cane_sino", entity.MovClienteViaggioCaneSino);
                p.Add("p_note", entity.MovClienteViaggioNote);
                p.Add("p_cliente_pilota_id", entity.ClientePilotaIdFk);

                await conn.ExecuteAsync("SELECT sp_mov_clienti_viaggi_create(@p_viaggio_id, @p_data_viaggio_id, @p_cliente_id, @p_tipo_partecipante_id, @p_ana_mezzi_id, @p_mezzo_modello_id, @p_sconto_val_totale, @p_targa_mezzo, @p_cane_sino, @p_note, @p_cliente_pilota_id)", p);
                return 1;
            }
            catch (PostgresException ex) when (ex.SqlState == "23505")
            {
                // Unique violation - Cliente già presente nel viaggio
                throw new InvalidOperationException("Questo cliente è già iscritto a questo viaggio. Non è possibile inserirlo nuovamente.", ex);
            }
            catch (PostgresException ex) when (ex.SqlState == "23503")
            {
                // Foreign key violation
                throw new InvalidOperationException("Impossibile aggiungere il partecipante: alcuni dati riferiti (cliente, viaggio o tipo partecipante) non sono validi.", ex);
            }
            catch (PostgresException ex)
            {
                // Generic PostgreSQL error
                throw new InvalidOperationException($"Errore durante l'aggiunta del partecipante: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante l'aggiunta del partecipante. Riprova.", ex);
            }
        }

        public async Task UpdateParticipantAsync(MovClientiViaggi entity)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                var p = new DynamicParameters();
                p.Add("p_viaggio_id", entity.ViaggioIdFk);
                p.Add("p_data_viaggio_id", entity.DataViaggioIdFk);
                p.Add("p_cliente_id", entity.ClienteIdFk);
                p.Add("p_tipo_partecipante_id", entity.TipoPartecipanteIdFk);
                p.Add("p_ana_mezzi_id", entity.AnaMezziIdFk);
                p.Add("p_mezzo_modello_id", entity.MezzoModelloIdFk);
                p.Add("p_sconto_val_totale", entity.MovClienteViaggioScontovalTotale);
                p.Add("p_targa_mezzo", entity.MovClienteViaggioTargaMezzo);
                p.Add("p_cane_sino", entity.MovClienteViaggioCaneSino);
                p.Add("p_note", entity.MovClienteViaggioNote);
                p.Add("p_cliente_pilota_id", entity.ClientePilotaIdFk);

                await conn.ExecuteAsync("SELECT sp_mov_clienti_viaggi_update(@p_viaggio_id, @p_data_viaggio_id, @p_cliente_id, @p_tipo_partecipante_id, @p_ana_mezzi_id, @p_mezzo_modello_id, @p_sconto_val_totale, @p_targa_mezzo, @p_cane_sino, @p_note, @p_cliente_pilota_id)", p);
            }
            catch (PostgresException ex) when (ex.SqlState == "23503")
            {
                // Foreign key violation
                throw new InvalidOperationException("Impossibile modificare il partecipante: alcuni dati riferiti (veicolo, modello o pilota) non sono validi.", ex);
            }
            catch (PostgresException ex) when (ex.Message.Contains("Record non trovato"))
            {
                // Record not found
                throw new InvalidOperationException("Il partecipante che stai cercando di modificare non esiste più. Ricarica la pagina.", ex);
            }
            catch (PostgresException ex)
            {
                // Generic PostgreSQL error
                throw new InvalidOperationException($"Errore durante la modifica del partecipante: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante la modifica del partecipante. Riprova.", ex);
            }
        }

        public async Task RemoveParticipantAsync(int viaggioId, int dataId, int clienteId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                var p = new DynamicParameters();
                p.Add("p_viaggio_id", viaggioId);
                p.Add("p_data_viaggio_id", dataId);
                p.Add("p_cliente_id", clienteId);

                await conn.ExecuteAsync("SELECT sp_mov_clienti_viaggi_delete(@p_viaggio_id, @p_data_viaggio_id, @p_cliente_id)", p);
            }
            catch (PostgresException ex) when (ex.SqlState == "23503")
            {
                // Foreign key violation - probably referenced by alloggi
                throw new InvalidOperationException("Impossibile rimuovere il partecipante: è collegato ad altri dati (es. alloggi). Rimuovi prima i collegamenti.", ex);
            }
            catch (PostgresException ex)
            {
                // Generic PostgreSQL error
                throw new InvalidOperationException($"Errore durante la rimozione del partecipante: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante la rimozione del partecipante. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Function: fn_get_mov_clienti_viaggi_by_date(p_data_viaggio_id INTEGER)
        /// Input: ID della data viaggio
        /// Output: Tutti i partecipanti iscritti (dati raw senza arricchimenti)
        /// </summary>
        public async Task<IEnumerable<MovClientiViaggi>> GetByDateIdAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                return await conn.QueryAsync<MovClientiViaggi>(
                    "SELECT * FROM fn_get_mov_clienti_viaggi_by_date(@dataId)",
                    new { dataId = dataViaggioId });
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento dei partecipanti: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante il caricamento dei partecipanti. Riprova.", ex);
            }
        }
        /// <summary>
        /// DB Function: fn_get_participants_view(p_data_viaggio_id INTEGER)
        /// Input: ID della data viaggio
        /// Output: Vista arricchita partecipanti con dati anagrafici, ruolo e mezzo, ordinati per equipaggio
        /// </summary>
        public async Task<IEnumerable<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>> GetParticipantsViewAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                return await conn.QueryAsync<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>(
                    "SELECT * FROM fn_get_participants_view(@dataId)",
                    new { dataId = dataViaggioId });
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento della lista partecipanti: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante il caricamento della lista partecipanti. Riprova.", ex);
            }
        }

        public async Task<string> GetParticipantsSummaryAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                return await conn.QueryFirstOrDefaultAsync<string>(
                    "SELECT get_viaggio_partecipanti_summary(@dataId)",
                    new { dataId = dataViaggioId }) ?? "Nessun partecipante";
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento del riepilogo partecipanti: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante il caricamento del riepilogo. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Function: fn_get_trip_header_string(p_viaggio_id INTEGER, p_data_viaggio_id INTEGER)
        /// Input: ID viaggio e ID data viaggio
        /// Output: Intestazione formattata "Descrizione (Dal GG/MM/AAAA al GG/MM/AAAA)"
        /// </summary>
        public async Task<string> GetTripHeaderStringAsync(int viaggioId, int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                return await conn.QueryFirstOrDefaultAsync<string>(
                    "SELECT fn_get_trip_header_string(@vid, @did)",
                    new { vid = viaggioId, did = dataViaggioId }) ?? "Intestazione non disponibile";
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento dell'intestazione viaggio: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante il caricamento dell'intestazione. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Function: get_participants_sorted(p_data_viaggio_id INTEGER)
        /// Input: ID della data viaggio
        /// Output: Partecipanti ordinati per: cognome pilota → pilota prima dei passeggeri → cognome passeggeri
        /// </summary>
        public async Task<IEnumerable<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>> GetParticipantsSortedAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                // CRITICAL: Usa alias espliciti per garantire il corretto mapping Dapper snake_case → PascalCase
                return await conn.QueryAsync<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>(@"
                    SELECT
                        viaggio_id as ViaggioId,
                        data_id as DataId,
                        cliente_id as ClienteId,
                        nominativo as Nominativo,
                        tipo_partecipante_id as TipoPartecipanteId,
                        ruolo as Ruolo,
                        note as Note,
                        cane_sino as CaneSino,
                        intolleranze as Intolleranze,
                        mezzo_dettagli as MezzoDettagli,
                        cliente_pilota_id as ClientePilotaId,
                        grouping_key as GroupingKey,
                        is_pilot as IsPilot,
                        email as Email
                    FROM get_participants_sorted(@dataId)",
                    new { dataId = dataViaggioId });
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento partecipanti ordinati: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante il caricamento partecipanti. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Function: get_participants_without_accommodation(p_data_viaggio_id INTEGER)
        /// Input: ID della data viaggio
        /// Output: Solo partecipanti senza camera assegnata (LEFT JOIN atomico con mov_clienti_alloggi)
        /// </summary>
        public async Task<IEnumerable<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>> GetParticipantsWithoutAccommodationAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                return await conn.QueryAsync<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>(
                    "SELECT * FROM get_participants_without_accommodation(@dataId)",
                    new { dataId = dataViaggioId });
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento partecipanti senza camera: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto. Riprova.", ex);
            }
        }

        /// <summary>
        /// DB Function: get_participants_count(p_data_viaggio_id INTEGER)
        /// Input: ID della data viaggio
        /// Output: Conteggio totale partecipanti (più efficiente di Count() in memoria)
        /// </summary>
        public async Task<int> GetParticipantsCountAsync(int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                return await conn.QuerySingleAsync<int>(
                    "SELECT get_participants_count(@dataId)",
                    new { dataId = dataViaggioId });
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il conteggio partecipanti: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto. Riprova.", ex);
            }
        }

        public async Task<GestioneViaggi.Models.DTOs.ViaggioPartecipantiInitData> GetPartecipantiInitDataAsync(int viaggioId, int dataViaggioId)
        {
            try
            {
                await using var conn = await _connectionManager.GetConnectionAsync();
                var json = await conn.QuerySingleAsync<string>("SELECT fn_get_viaggio_partecipanti_init_data(@vid, @did)", new { vid = viaggioId, did = dataViaggioId });
                return System.Text.Json.JsonSerializer.Deserialize<GestioneViaggi.Models.DTOs.ViaggioPartecipantiInitData>(json, 
                    new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true }) 
                    ?? new GestioneViaggi.Models.DTOs.ViaggioPartecipantiInitData();
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento consolidato dei partecipanti: {ex.Message}", ex);
            }
        }
    }
}
