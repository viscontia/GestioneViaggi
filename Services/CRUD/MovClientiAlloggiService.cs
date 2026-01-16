
using Dapper;
using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Npgsql;
using System.Data;

namespace GestioneViaggi.Services.CRUD
{
    public class MovClientiAlloggiService
    {
        private readonly IDatabaseConnectionManager _connectionManager;

        public MovClientiAlloggiService(IDatabaseConnectionManager connectionManager)
        {
            _connectionManager = connectionManager;
        }

        public async Task<int> AddAccommodationAsync(MovClientiAlloggi entity)
        {
            try
            {
                using var conn = await _connectionManager.GetConnectionAsync();

                // PostgreSQL FUNCTION (not PROCEDURE), use SELECT instead of CALL
                string sql = @"
                    SELECT sp_mov_clienti_alloggi_create(
                        @p_viaggio_id,
                        @p_data_viaggio_id,
                        @p_tipo_alloggio_id,
                        @p_cliente_id1,
                        @p_cliente_id2,
                        @p_cliente_id3,
                        @p_cliente_id4,
                        @p_cliente_id5,
                        @p_cliente_id6
                    )";

                return await conn.QuerySingleAsync<int>(sql, new
                {
                    p_viaggio_id = entity.ViaggioIdFk,
                    p_data_viaggio_id = entity.DataViaggioIdFk,
                    p_tipo_alloggio_id = entity.TipoAlloggioIdFk,
                    p_cliente_id1 = entity.ClienteId1Fk,
                    p_cliente_id2 = entity.ClienteId2Fk,
                    p_cliente_id3 = entity.ClienteId3Fk,
                    p_cliente_id4 = entity.ClienteId4Fk,
                    p_cliente_id5 = entity.ClienteId5Fk,
                    p_cliente_id6 = entity.ClienteId6Fk
                });
            }
            catch (PostgresException ex) when (ex.SqlState == "23503")
            {
                throw new InvalidOperationException("Impossibile assegnare l'alloggio: alcuni dati riferiti (viaggio, tipo alloggio o clienti) non sono validi.", ex);
            }
            catch (PostgresException ex) when (ex.SqlState == "23505")
            {
                throw new InvalidOperationException("Questo alloggio risulta già assegnato. Verifica i dati.", ex);
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante l'assegnazione dell'alloggio: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante l'assegnazione dell'alloggio. Riprova.", ex);
            }
        }

        public async Task UpdateAccommodationAsync(MovClientiAlloggi entity)
        {
            try
            {
                using var conn = await _connectionManager.GetConnectionAsync();

                // PostgreSQL FUNCTION (not PROCEDURE), use SELECT instead of CALL
                string sql = @"
                    SELECT sp_mov_clienti_alloggi_update(
                        @p_pk,
                        @p_viaggio_id,
                        @p_data_viaggio_id,
                        @p_tipo_alloggio_id,
                        @p_cliente_id1,
                        @p_cliente_id2,
                        @p_cliente_id3,
                        @p_cliente_id4,
                        @p_cliente_id5,
                        @p_cliente_id6
                    )";

                await conn.ExecuteAsync(sql, new
                {
                    p_pk = entity.MovClientiAlloggioPk,
                    p_viaggio_id = entity.ViaggioIdFk,
                    p_data_viaggio_id = entity.DataViaggioIdFk,
                    p_tipo_alloggio_id = entity.TipoAlloggioIdFk,
                    p_cliente_id1 = entity.ClienteId1Fk,
                    p_cliente_id2 = entity.ClienteId2Fk,
                    p_cliente_id3 = entity.ClienteId3Fk,
                    p_cliente_id4 = entity.ClienteId4Fk,
                    p_cliente_id5 = entity.ClienteId5Fk,
                    p_cliente_id6 = entity.ClienteId6Fk
                });
            }
            catch (PostgresException ex) when (ex.SqlState == "23503")
            {
                throw new InvalidOperationException("Impossibile modificare l'alloggio: alcuni dati riferiti (tipo alloggio o clienti) non sono validi.", ex);
            }
            catch (PostgresException ex) when (ex.Message.Contains("Record Alloggio non trovato"))
            {
                throw new InvalidOperationException("L'alloggio che stai cercando di modificare non esiste più. Ricarica la pagina.", ex);
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante la modifica dell'alloggio: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante la modifica dell'alloggio. Riprova.", ex);
            }
        }

        public async Task RemoveAccommodationAsync(int pk)
        {
            try
            {
                using var conn = await _connectionManager.GetConnectionAsync();

                // PostgreSQL FUNCTION (not PROCEDURE), use SELECT instead of CALL
                string sql = "SELECT sp_mov_clienti_alloggi_delete(@p_pk)";

                await conn.ExecuteAsync(sql, new { p_pk = pk });
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante la rimozione dell'alloggio: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante la rimozione dell'alloggio. Riprova.", ex);
            }
        }

        public async Task<IEnumerable<MovClientiAlloggi>> GetByDateIdAsync(int dataViaggioId)
        {
            try
            {
                using var conn = await _connectionManager.GetConnectionAsync();
                string sql = @"
                    SELECT
                        mov_clienti_alloggio_pk as MovClientiAlloggioPk,
                        viaggio_id_fk as ViaggioIdFk,
                        data_viaggio_id_fk as DataViaggioIdFk,
                        tipo_alloggio_id_fk as TipoAlloggioIdFk,
                        cliente_id1_fk as ClienteId1Fk,
                        cliente_id2_fk as ClienteId2Fk,
                        cliente_id3_fk as ClienteId3Fk,
                        cliente_id4_fk as ClienteId4Fk,
                        cliente_id5_fk as ClienteId5Fk,
                        cliente_id6_fk as ClienteId6Fk
                    FROM mov_clienti_alloggi
                    WHERE data_viaggio_id_fk = @dataId";
                return await conn.QueryAsync<MovClientiAlloggi>(sql, new { dataId = dataViaggioId });
            }
            catch (PostgresException ex)
            {
                throw new InvalidOperationException($"Errore durante il caricamento degli alloggi: {ex.MessageText}", ex);
            }
            catch (Exception ex)
            {
                throw new InvalidOperationException("Si è verificato un errore imprevisto durante il caricamento degli alloggi. Riprova.", ex);
            }
        }
    }
}
