namespace GestioneViaggi.Validation.Core;

public static class ValidationMessages
{
    public const string PartitaIvaInvalid = "Partita IVA non valida. Deve contenere esattamente 11 cifre.";
    public const string CodiceFiscaleInvalid = "Codice Fiscale non valido. Deve essere alfanumerico di 11-16 caratteri maiuscoli.";
    public const string PecInvalid = "Indirizzo PEC non valido.";
    public const string TelefonoInvalid = "Numero di telefono non valido. Formato accettato: +39 0123456789 oppure 0123456789.";
    public const string CodiceSdiInvalid = "Codice Destinatario SDI non valido. Deve essere di 7 caratteri alfanumerici maiuscoli.";
    public const string FormaGiuridicaEmpty = "Forma giuridica obbligatoria.";
    public const string CapitaleSocialeNegative = "Il capitale sociale deve essere un valore positivo o zero.";
    public const string CapInvalid = "CAP non valido. Deve contenere esattamente 5 cifre numeriche.";
}
