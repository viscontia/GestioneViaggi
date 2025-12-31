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
    public const string RagioneSocialeEmpty = "La ragione sociale è obbligatoria.";
    public const string RagioneSocialeTooLong = "La ragione sociale non può superare 255 caratteri.";
    public const string WebsiteInvalid = "L'indirizzo del sito web non è valido. Deve iniziare con http:// o https://";
    public const string ReaInvalid = "Il numero REA non è valido. Deve essere alfanumerico e non superare 20 caratteri.";
    public const string DataCostituzioneFutura = "La data di costituzione non può essere futura.";
    public const string DataInizioPrecedenteCostituzione = "La data di inizio attività non può essere precedente alla data di costituzione.";
    public const string DataReaPrecedenteCostituzione = "La data di iscrizione REA non può essere precedente alla data di costituzione.";
    public const string ReaIncompleta = "Se è specificata la provincia REA, è necessario indicare anche il numero REA e viceversa.";
    public const string ContattoNomeRequired = "Il nome del contatto è obbligatorio.";
    public const string ContattoCognomeRequired = "Il cognome del contatto è obbligatorio.";
    public const string ContattoRecapitoRequired = "È necessario specificare almeno un recapito (email, cellulare o telefono diretto).";
    public const string ContattoSedeFkRequired = "La sede di riferimento è obbligatoria per il contatto.";
    public const string ContattoSedeFkNotExists = "La sede selezionata non esiste o non appartiene all'azienda del contatto.";
    public const string ContattoSedeAziendaMismatch = "La sede selezionata non appartiene all'azienda del contatto.";
    public const string NomeTooLong = "Il nome non può superare i 100 caratteri.";
    public const string CognomeTooLong = "Il cognome non può superare i 100 caratteri.";
    public const string RuoloTooLong = "Il ruolo non può superare i 100 caratteri.";

    // SMTP Server Validation
    public const string SmtpHostRequired = "L'hostname del server SMTP è obbligatorio.";
    public const string SmtpHostTooLong = "L'hostname non può superare i 253 caratteri.";
    public const string SmtpHostInvalid = "L'hostname del server SMTP non è valido. Esempi validi: smtp.gmail.com, mail.example.com, 192.168.1.100";
    public const string SmtpPortInvalid = "La porta deve essere compresa tra 1 e 65535.";
    public const string SmtpUsernameRequired = "Lo username SMTP è obbligatorio.";
    public const string SmtpUsernameTooLong = "Lo username non può superare i 255 caratteri.";
    public const string SmtpPasswordRequired = "La password SMTP è obbligatoria.";
    public const string SmtpPasswordTooShort = "La password deve contenere almeno 3 caratteri.";
}
