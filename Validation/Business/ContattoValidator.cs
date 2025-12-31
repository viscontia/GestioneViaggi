using GestioneViaggi.Validation.Core;
using GestioneViaggi.Validation.Syntax;

namespace GestioneViaggi.Validation.Business;

public static class ContattoValidator
{
    public static ValidationResult ValidateNome(string? nome)
    {
        return PersonNameValidator.CheckNome(nome);
    }

    public static ValidationResult ValidateCognome(string? cognome)
    {
        return PersonNameValidator.CheckCognome(cognome);
    }

    public static ValidationResult ValidateRuolo(string? ruolo)
    {
        return PersonNameValidator.CheckRuolo(ruolo);
    }

    public static ValidationResult ValidateEmail(string? email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return ValidationResult.Success();

        return EmailValidator.CheckEmail(email);
    }

    public static ValidationResult ValidateCellulare(string? cellulare)
    {
        if (string.IsNullOrWhiteSpace(cellulare))
            return ValidationResult.Success();

        return PhoneValidator.CheckTelefonoItaly(cellulare);
    }

    public static ValidationResult ValidateTelefonoDiretto(string? telefonoDiretto)
    {
        if (string.IsNullOrWhiteSpace(telefonoDiretto))
            return ValidationResult.Success();

        return PhoneValidator.CheckTelefonoItaly(telefonoDiretto);
    }

    public static ValidationResult ValidateSedeFk(int? sedeFk)
    {
        if (!sedeFk.HasValue || sedeFk.Value <= 0)
            return ValidationResult.Failure(
                ValidationMessages.ContattoSedeFkRequired,
                "CHK_CNT_SEDE_001"
            );

        return ValidationResult.Success();
    }

    public static ValidationResult ValidateSedeExists(int? sedeFk, bool sedeExists)
    {
        if (!sedeFk.HasValue)
            return ValidationResult.Failure(
                ValidationMessages.ContattoSedeFkRequired,
                "CHK_CNT_SEDE_001"
            );

        if (!sedeExists)
            return ValidationResult.Failure(
                ValidationMessages.ContattoSedeFkNotExists,
                "CHK_CNT_SEDE_FK_001"
            );

        return ValidationResult.Success();
    }

    public static ValidationResult ValidateSedeAziendaMatch(int? sedeFk, int? sedeAziendaFk, int? contattoAziendaFk)
    {
        if (!sedeFk.HasValue || !sedeAziendaFk.HasValue || !contattoAziendaFk.HasValue)
            return ValidationResult.Success();

        if (sedeAziendaFk.Value != contattoAziendaFk.Value)
            return ValidationResult.Failure(
                ValidationMessages.ContattoSedeAziendaMismatch,
                "CHK_CNT_SEDE_AZ_001"
            );

        return ValidationResult.Success();
    }

    public static ValidationResult ValidateNomeRequired(string? nome)
    {
        if (string.IsNullOrWhiteSpace(nome))
            return ValidationResult.Failure(
                ValidationMessages.ContattoNomeRequired,
                "CHK_CNT_NOME_001"
            );

        return ValidationResult.Success();
    }

    public static ValidationResult ValidateCognomeRequired(string? cognome)
    {
        if (string.IsNullOrWhiteSpace(cognome))
            return ValidationResult.Failure(
                ValidationMessages.ContattoCognomeRequired,
                "CHK_CNT_COGN_001"
            );

        return ValidationResult.Success();
    }

    public static ValidationResult ValidateRecapitoPresence(string? email, string? cellulare, string? telefonoDiretto)
    {
        bool hasEmail = !string.IsNullOrWhiteSpace(email);
        bool hasCellulare = !string.IsNullOrWhiteSpace(cellulare);
        bool hasTelefonoDiretto = !string.IsNullOrWhiteSpace(telefonoDiretto);

        if (!hasEmail && !hasCellulare && !hasTelefonoDiretto)
            return ValidationResult.Failure(
                ValidationMessages.ContattoRecapitoRequired,
                "CHK_CNT_CONTACT_001"
            );

        return ValidationResult.Success();
    }
}
