using GestioneViaggi.Models;
using GestioneViaggi.Services.Database;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace GestioneViaggi.Services.CRUD;

public class AnaTipoAvvicinamentoService : BaseCrudService<AnaTipoAvvicinamento>
{
    protected override string TableName => "ana_tipo_avvicinamento";
    protected override string IdColumnName => "tipo_avvicinamento_id";

    public AnaTipoAvvicinamentoService(IDatabaseService databaseService, ILogger<AnaTipoAvvicinamentoService> logger)
        : base(databaseService, logger)
    {
    }

    public override Task<AnaTipoAvvicinamento> CreateAsync(AnaTipoAvvicinamento entity)
    {
        // Read-only logic mainly, but implementing for completeness if needed later
        return Task.FromException<AnaTipoAvvicinamento>(new NotImplementedException("Creation of Tipo Avvicinamento is not supported via UI yet."));
    }

    public override Task<AnaTipoAvvicinamento> UpdateAsync(AnaTipoAvvicinamento entity)
    {
        return Task.FromException<AnaTipoAvvicinamento>(new NotImplementedException("Update of Tipo Avvicinamento is not supported via UI yet."));
    }

    protected override AnaTipoAvvicinamento MapFromReader(NpgsqlDataReader reader)
    {
        return new AnaTipoAvvicinamento
        {
            Id = ReadInt(reader, "tipo_avvicinamento_id"),
            Descrizione = reader.GetString(reader.GetOrdinal("tipo_avvicinamento_descrizione"))
        };
    }
}
