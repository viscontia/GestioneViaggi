namespace GestioneViaggi.Models.Web;

/// <summary>
/// Una riga del promemoria all'apertura (L2): la restituisce già pronta
/// fn_promemoria_apertura (SqlScripts/671). Il gestionale la disegna, non la ricalcola.
/// </summary>
public sealed record PromemoriaVoce(
    string Voce,
    string VoceTitolo,
    string Perche,
    string Oggetto,
    int Urgenza,
    DateOnly? DataRif,
    int? ViaggioId,
    int? DataViaggioId,
    int? ClienteId);
