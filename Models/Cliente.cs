namespace GestioneViaggi.Models;

using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

/// <summary>
/// Entità Cliente - rappresenta l'anagrafica clienti (ana_clienti)
/// </summary>
public class Cliente : BaseEntity, IAuditable, IValidatableObject
{
    // Primary Key
    [Column("cliente_id")]
    public int ClienteId { get; set; }

    // Dati Anagrafici
    [Column("cliente_titolo_fk")]
    [Required(ErrorMessage = "Il titolo è obbligatorio")]
    [Range(1, int.MaxValue, ErrorMessage = "Il titolo è obbligatorio")]
    public int TitoloFk { get; set; }

    /// <summary>
    /// Lingua del cliente (ISO a 2 lettere). NOT NULL a database, default IT.
    /// </summary>
    [Column("cliente_lingua")]
    public string Lingua { get; set; } = "IT";

    /// <summary>
    /// Consenso all'invio di email commerciali. Le due colonne che lo accompagnano —
    /// data e fonte — le scrive il database quando il consenso viene acceso: servono
    /// a dimostrarlo, e un consenso che non si puo'  dimostrare non vale.
    /// </summary>
    [Column("consenso_marketing")]
    public bool Consenso { get; set; }

    /// <summary>Da dove arriva il consenso, quando lo si accende. Es. SITO_ISCRIZIONE.</summary>
    [NotMapped]
    public string? ConsensoFonte { get; set; }

    /// <summary>
    /// Descrizione del titolo, risolta dalla lookup: sola lettura, non viene mai scritta.
    /// Serve a stampe ed export, che mostrano il titolo e non il suo codice.
    /// </summary>
    [NotMapped]
    public string? TitoloDescrizione { get; set; }

    [Column("cliente_cognome")]
    [Required(ErrorMessage = "Il cognome è obbligatorio")]
    public string Cognome { get; set; } = string.Empty;

    [Column("cliente_nome")]
    [Required(ErrorMessage = "Il nome è obbligatorio")]
    public string Nome { get; set; } = string.Empty;

    [Column("cliente_sesso")]
    [Required(ErrorMessage = "Il sesso è obbligatorio")]
    [RegularExpression("[MF]", ErrorMessage = "Selezionare M o F")]
    public char Sesso { get; set; } // 'M' o 'F'

    // Residenza
    [Column("cliente_comune_residenza_fk")]
    public int ComuneResidenzaFk { get; set; }

    [Column("cliente_indirizzo_residenza")]
    public string? IndirizzoResidenza { get; set; }

    // Nascita
    [Column("cliente_comune_nascita_fk")]
    [Required(ErrorMessage = "Il comune di nascita è obbligatorio")]
    [Range(1, int.MaxValue, ErrorMessage = "Il comune di nascita è obbligatorio")]
    public int ComuneNascitaFk { get; set; }

    [Column("cliente_data_nascita")]
    public DateTime? DataNascita { get; set; }

    // Contatti
    [Column("cliente_preftelint")]
    public string? PrefTelInt { get; set; }

    [Column("cliente_telefono")]
    public string? Telefono { get; set; }

    [Column("cliente_email")]
    // Nessun obbligo qui: l'email e' richiesta dal ruolo al momento dell'iscrizione
    // (fn_mov_clienti_viaggi_valida), non dall'anagrafica. Il formato lo controlla
    // fn_ana_clienti_valida, che e' la stessa regola che vede il sito.
    public string? Email { get; set; }

    // Documenti Identificativi
    [Column("cliente_codicefiscale")]
    public string? CodiceFiscale { get; set; }

    [Column("cliente_iban")]
    public string? Iban { get; set; }

    [Column("cliente_tipodoc_identita")]
    // I dati del documento sono obbligatori per TUTTI — in albergo si presentano per
    // legge i documenti di ogni occupante della stanza — ma la regola sta in
    // fn_ana_clienti_campi_mancanti (script 563), non qui: cosi' vale anche per il sito.
    public string? TipoDocIdentita { get; set; }

    [Column("cliente_documento_numero")]
    public string? DocumentoNumero { get; set; }

    [Column("cliente_documento_rilasciato_da")]
    public string? DocumentoRilasciatoDa { get; set; }

    [Column("cliente_documento_rilasciato_data")]
    public DateTime? DocumentoRilasciatoData { get; set; }

    [Column("cliente_documento_rilasciato_scadenza")]
    public DateTime? DocumentoRilasciatoScadenza { get; set; }

    // File Binari - Foto
    [Column("cliente_foto")]
    public byte[]? Foto { get; set; }

    [Column("cliente_foto_mimetype")]
    public string? FotoMimeType { get; set; }

    [Column("cliente_foto_filename")]
    public string? FotoFilename { get; set; }

    [Column("cliente_foto_charset")]
    public string? FotoCharset { get; set; }

    [Column("cliente_foto_upd_date")]
    public DateTime? FotoUpdDate { get; set; }

    // File Binari - Documento
    [Column("cliente_carta_identita")]
    public byte[]? CartaIdentita { get; set; }

    [Column("cliente_documento_mimetype")]
    public string? DocumentoMimeType { get; set; }

    [Column("cliente_documento_filename")]
    public string? DocumentoFilename { get; set; }

    [Column("cliente_documento_chartset")]
    public string? DocumentoCharset { get; set; }

    [Column("cliente_documento_upd_date")]
    public DateTime? DocumentoUpdDate { get; set; }

    // Note e Intolleranze
    [Column("cliente_note")]
    public string? Note { get; set; }

    [Column("cliente_intolleranza")]
    public string? Intolleranza { get; set; }

    // Multi-tenant
    [Column("azienda_fk")]
    public int AziendaFk { get; set; }

    // Audit Fields
    [Column("created_by")]
    public string? CreatedBy { get; set; }

    [Column("created")]
    public DateTime? Created { get; set; }

    [Column("updated_by")]
    public string? UpdatedBy { get; set; }

    [Column("updated")]
    public DateTime? Updated { get; set; }

    // Navigation Properties (opzionali - per future implementazioni)
    public Comune? ComuneResidenza { get; set; }
    public Comune? ComuneNascita { get; set; }

    // Proprietà navigazione DTO-like per DataGrid
    public string? AziendaRagioneSociale { get; set; }
    public int? ViaggiFatti { get; set; }
    public int? ViaggiDaFare { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        // Validazione Codice Fiscale: Obbligatorio solo per clienti italiani
        // Si assume italiano se ComuneResidenza è null (default safe) o se ComuneEstero è false
        bool isEstero = ComuneResidenza?.ComuneEstero ?? false;

        if (!isEstero)
        {
            if (string.IsNullOrWhiteSpace(CodiceFiscale))
            {
                yield return new ValidationResult(
                    "Il Codice Fiscale è obbligatorio per i clienti residenti in Italia",
                    new[] { nameof(CodiceFiscale) }
                );
            }
            else if (CodiceFiscale.Length != 16)
            {
                // Nota: La validazione regex/formato potrebbe essere già gestita altrove o qui
                // Per ora ci limitiamo a controllare la presenza come richiesto.
                // Il validator fiscale specifico (CodiceFiscaleValidator) fa controlli più approfonditi.
            }
        }
    }
}
