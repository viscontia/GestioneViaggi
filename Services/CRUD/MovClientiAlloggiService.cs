
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
            using var conn = await _connectionManager.GetConnectionAsync();
            var p = new DynamicParameters();
            p.Add("p_viaggio_id", entity.ViaggioIdFk);
            p.Add("p_data_viaggio_id", entity.DataViaggioIdFk);
            p.Add("p_tipo_alloggio_id", entity.TipoAlloggioIdFk);
            p.Add("p_cliente_id1", entity.ClienteId1Fk);
            p.Add("p_cliente_id2", entity.ClienteId2Fk);
            p.Add("p_cliente_id3", entity.ClienteId3Fk);
            p.Add("p_cliente_id4", entity.ClienteId4Fk);
            p.Add("p_cliente_id5", entity.ClienteId5Fk);
            p.Add("p_cliente_id6", entity.ClienteId6Fk);

            return await conn.QuerySingleAsync<int>("sp_mov_clienti_alloggi_create", p, commandType: CommandType.StoredProcedure);
        }

        public async Task UpdateAccommodationAsync(MovClientiAlloggi entity)
        {
            using var conn = await _connectionManager.GetConnectionAsync();
            var p = new DynamicParameters();
            p.Add("p_pk", entity.MovClientiAlloggioPk);
            p.Add("p_viaggio_id", entity.ViaggioIdFk);
            p.Add("p_data_viaggio_id", entity.DataViaggioIdFk);
            p.Add("p_tipo_alloggio_id", entity.TipoAlloggioIdFk);
            p.Add("p_cliente_id1", entity.ClienteId1Fk);
            p.Add("p_cliente_id2", entity.ClienteId2Fk);
            p.Add("p_cliente_id3", entity.ClienteId3Fk);
            p.Add("p_cliente_id4", entity.ClienteId4Fk);
            p.Add("p_cliente_id5", entity.ClienteId5Fk);
            p.Add("p_cliente_id6", entity.ClienteId6Fk);

            await conn.ExecuteAsync("sp_mov_clienti_alloggi_update", p, commandType: CommandType.StoredProcedure);
        }

        public async Task RemoveAccommodationAsync(int pk)
        {
            using var conn = await _connectionManager.GetConnectionAsync();
            var p = new DynamicParameters();
            p.Add("p_pk", pk);

            await conn.ExecuteAsync("sp_mov_clienti_alloggi_delete", p, commandType: CommandType.StoredProcedure);
        }

        public async Task<IEnumerable<MovClientiAlloggi>> GetByDateIdAsync(int dataViaggioId)
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
    }
}
