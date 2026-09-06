using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GestioneViaggi.Models;

/// <summary>
/// Il genere di una sistemazione: albergo, tenda, nessuna — e domani ciò che servirà.
///
/// ⚠️ È una tabella e non un elenco scritto nel codice perché le condizioni di alloggio
/// cambiano: bungalow, case mobili, rifugi. Aggiungerne uno deve costare una riga, non una
/// modifica al programma — l'alternativa (un booleano per genere) è già fallita una volta
/// con <c>ana_tipo_pernottamento_con_albergo</c>, che all'arrivo delle tende non ha saputo
/// dire niente.
/// </summary>
[Table("ANA_ALLOGGIO_GENERI")]
public class AlloggioGenere : BaseEntity
{
    /// <summary>
    /// Il codice con cui il programma riconosce il genere.
    /// ⚠️ <c>NESSUNA</c> ha un significato speciale: vale su qualunque viaggio senza
    /// comparire fra i generi ammessi — «non mi serve una sistemazione» è legittimo ovunque.
    /// </summary>
    [Required(ErrorMessage = "Il codice è obbligatorio")]
    [StringLength(20, ErrorMessage = "Max 20 caratteri")]
    [Column("GENERE_CODICE")]
    public string Codice { get; set; } = string.Empty;

    [Required(ErrorMessage = "La descrizione è obbligatoria")]
    [StringLength(60, ErrorMessage = "Max 60 caratteri")]
    [Column("GENERE_DESCRIZIONE")]
    public string Descrizione { get; set; } = string.Empty;

    [Column("GENERE_ORDINE")]
    [Range(1, 99, ErrorMessage = "L'ordine deve essere compreso tra 1 e 99")]
    public short Ordine { get; set; } = 99;

    [Column("GENERE_ATTIVO")]
    public bool Attivo { get; set; } = true;
}
