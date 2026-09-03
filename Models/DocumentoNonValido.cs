namespace GestioneViaggi.Models;

/// <summary>
/// Un partecipante da sistemare prima della partenza: il documento non arriva valido alla
/// fine del viaggio, oppure guida e non ha alcun recapito in anagrafica.
///
/// Porta con sé email e telefono perché chi lo legge deve poter <b>avvisare la persona</b>,
/// non solo sapere che c'è un problema: è il motivo per cui questo controllo esiste.
/// </summary>
public class DocumentoNonValido
{
    public int ClienteId { get; set; }
    public string Cognome { get; set; } = string.Empty;
    public string Nome { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? Prefisso { get; set; }
    public string? Telefono { get; set; }
    public DateTime? DocumentoScadenza { get; set; }

    /// <summary>MANCANTE · SCADUTO · SCADE_DURANTE · SENZA_RECAPITO (mai VALIDO: quelli non arrivano qui).</summary>
    public string Stato { get; set; } = string.Empty;

    /// <summary>All'estero senza documento valido non si parte affatto.</summary>
    public bool ViaggioEstero { get; set; }

    /// <summary>Il messaggio già scritto dal database, con le date dentro.</summary>
    public string Messaggio { get; set; } = string.Empty;

    public string Nominativo => $"{Cognome} {Nome}".Trim();

    /// <summary>Il telefono come si scrive, prefisso compreso.</summary>
    public string TelefonoCompleto =>
        string.IsNullOrWhiteSpace(Telefono) ? string.Empty : $"{Prefisso}{Telefono}".Trim();

    /// <summary>
    /// Non può partire: il documento manca o è già scaduto alla partenza.
    /// Chi invece scade <i>durante</i> il viaggio parte, ma va avvisato di rinnovare —
    /// sono due telefonate diverse, e vanno distinte anche a colpo d'occhio.
    /// </summary>
    public bool Impedisce => Stato is "MANCANTE" or "SCADUTO";

    /// <summary>
    /// Guida e non ha né email né telefono: parte, ma se il programma cambia non c'è modo
    /// di dirglielo. La regola che rende il telefono obbligatorio per i piloti esiste dal
    /// 2026 (SqlScripts/563) e vale al salvataggio dell'anagrafica: i clienti storici, che
    /// nessuno ha più riaperto, non ci sono mai passati.
    /// </summary>
    public bool SenzaRecapito => Stato == "SENZA_RECAPITO";
}
