
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
            using var conn = await _connectionManager.GetConnectionAsync();
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

        public async Task UpdateParticipantAsync(MovClientiViaggi entity)
        {
            using var conn = await _connectionManager.GetConnectionAsync();
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

        public async Task RemoveParticipantAsync(int viaggioId, int dataId, int clienteId)
        {
            using var conn = await _connectionManager.GetConnectionAsync();
            var p = new DynamicParameters();
            p.Add("p_viaggio_id", viaggioId);
            p.Add("p_data_viaggio_id", dataId);
            p.Add("p_cliente_id", clienteId);

            await conn.ExecuteAsync("SELECT sp_mov_clienti_viaggi_delete(@p_viaggio_id, @p_data_viaggio_id, @p_cliente_id)", p);
        }

        public async Task<IEnumerable<MovClientiViaggi>> GetByDateIdAsync(int dataViaggioId)
        {
            using var conn = await _connectionManager.GetConnectionAsync();
            // Manual mapping via aliases to safe PascalCase
            string sql = @"
                SELECT 
                    viaggio_id_fk as ViaggioIdFk,
                    data_viaggio_id_fk as DataViaggioIdFk,
                    cliente_id_fk as ClienteIdFk,
                    tipo_partecipante_id_fk as TipoPartecipanteIdFk,
                    ana_mezzi_id_fk as AnaMezziIdFk,
                    mezzo_modello_id_fk as MezzoModelloIdFk,
                    cliente_pilota_id_fk as ClientePilotaIdFk,
                    mov_cliente_viaggio_scontoval_totale as MovClienteViaggioScontovalTotale,
                    mov_cliente_viaggio_targa_mezzo as MovClienteViaggioTargaMezzo,
                    mov_cliente_viaggio_cane_sino as MovClienteViaggioCaneSino,
                    mov_cliente_viaggio_note as MovClienteViaggioNote
                FROM mov_clienti_viaggi 
                WHERE data_viaggio_id_fk = @dataId";

            return await conn.QueryAsync<MovClientiViaggi>(sql, new { dataId = dataViaggioId });
        }
        public async Task<IEnumerable<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>> GetParticipantsViewAsync(int dataViaggioId)
        {
            using var conn = await _connectionManager.GetConnectionAsync();
            string sql = @"
                SELECT 
                    v.viaggio_id_fk as ViaggioId,
                    v.data_viaggio_id_fk as DataId,
                    v.cliente_id_fk as ClienteId,
                    c.cliente_cognome || ' ' || c.cliente_nome as Nominativo,
                    v.tipo_partecipante_id_fk as TipoPartecipanteId,
                    tp.tipo_partecipante_descrizione as Ruolo,
                    v.mov_cliente_viaggio_note as Note,
                    v.mov_cliente_viaggio_cane_sino as CaneSino,
                    c.cliente_intolleranza as Intolleranze,
                    get_mezzo_by_pilot(v.viaggio_id_fk, v.data_viaggio_id_fk, v.cliente_id_fk) as MezzoDettagli,
                    v.cliente_pilota_id_fk as ClientePilotaId,
                    CASE 
                        WHEN v.cliente_pilota_id_fk IS NOT NULL AND v.cliente_pilota_id_fk > 0 THEN v.cliente_pilota_id_fk 
                        WHEN tp.tipo_partecipante_descrizione LIKE '%PILOTA%' THEN v.cliente_id_fk 
                        ELSE 0 
                    END as GroupingKey
                FROM mov_clienti_viaggi v
                JOIN ana_clienti c ON v.cliente_id_fk = c.cliente_id
                JOIN ana_tipo_partecipante tp ON v.tipo_partecipante_id_fk = tp.tipo_partecipante_id
                WHERE v.data_viaggio_id_fk = @dataId
                ORDER BY c.cliente_cognome, c.cliente_nome";

            return await conn.QueryAsync<GestioneViaggi.Models.DTOs.ParticipantsViewDTO>(sql, new { dataId = dataViaggioId });
        }

        public async Task<string> GetParticipantsSummaryAsync(int dataViaggioId)
        {
            using var conn = await _connectionManager.GetConnectionAsync();
            return await conn.QueryFirstOrDefaultAsync<string>(
                "SELECT get_viaggio_partecipanti_summary(@dataId)",
                new { dataId = dataViaggioId }) ?? "Nessun partecipante";
        }

        public async Task<string> GetTripHeaderStringAsync(int viaggioId, int dataViaggioId)
        {
            using var conn = await _connectionManager.GetConnectionAsync();
            string sql = @"
                SELECT 
                    v.viaggio_descrizione_breve || ' (Dal ' || TO_CHAR(d.data_viaggio_data_inizio, 'DD/MM/YYYY') || ' al ' || TO_CHAR(d.data_viaggio_data_fine, 'DD/MM/YYYY') || ')'
                FROM ana_viaggi v
                JOIN ana_date_viaggi d ON d.viaggio_id_fk = v.viaggio_id
                WHERE v.viaggio_id = @vid AND d.data_viaggio_id = @did";

            return await conn.QueryFirstOrDefaultAsync<string>(sql, new { vid = viaggioId, did = dataViaggioId }) ?? "Intestazione non disponibile";
        }
    }
}
