using System;

namespace GestioneViaggi.Models.Exceptions;

/// <summary>
/// Eccezione personalizzata per errori di business o di integrità dati 
/// che devono essere comunicati all'utente in modo chiaro.
/// </summary>
public class GestioneViaggiException : Exception
{
    public string? ErrorCode { get; }
    public string? DatabaseTable { get; }

    public GestioneViaggiException(string message) : base(message)
    {
    }

    public GestioneViaggiException(string message, Exception innerException) : base(message, innerException)
    {
    }

    public GestioneViaggiException(string message, string errorCode, string? databaseTable = null) : base(message)
    {
        ErrorCode = errorCode;
        DatabaseTable = databaseTable;
    }
}
