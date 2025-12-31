using GestioneViaggi.Validation.Core;
using GestioneViaggi.Validation.Syntax;
using GestioneViaggi.Validation.Semantic;

namespace GestioneViaggi.Validation.Business;

public static class AziendaValidator
{
    public static ValidationResult ValidateRagioneSociale(string? ragioneSociale)
    {
        return RagioneSocialeValidator.CheckRagioneSociale(ragioneSociale);
    }

    public static ValidationResult ValidateFormaGiuridica(string? formaGiuridica)
    {
        return TextValidator.CheckFormaGiuridica(formaGiuridica);
    }

    public static ValidationResult ValidatePartitaIva(string? partitaIva)
    {
        return ItalianFiscalValidator.CheckPartitaIva(partitaIva);
    }

    public static ValidationResult ValidateCodiceFiscale(string? codiceFiscale)
    {
        return ItalianFiscalValidator.CheckCodiceFiscale(codiceFiscale);
    }

    public static ValidationResult ValidateCodiceSdi(string? codiceSdi)
    {
        if (string.IsNullOrWhiteSpace(codiceSdi))
            return ValidationResult.Success();
        
        return CodeValidator.CheckCodiceSdi(codiceSdi);
    }

    public static ValidationResult ValidatePec(string? pec)
    {
        return EmailValidatorPEC.CheckPec(pec);
    }

    public static ValidationResult ValidateSitoWeb(string? sitoWeb)
    {
        return WebsiteValidator.CheckWebsite(sitoWeb);
    }

    public static ValidationResult ValidateTelefonoPrincipale(string? telefono)
    {
        return PhoneValidator.CheckTelefonoItaly(telefono);
    }

    public static ValidationResult ValidateCapitaleSociale(decimal? capitaleSociale)
    {
        return NumericValidator.CheckCapitaleSociale(capitaleSociale);
    }

    public static ValidationResult ValidateNumeroRea(string? numeroRea)
    {
        return ReaValidator.CheckNumeroRea(numeroRea);
    }

    public static ValidationResult ValidateDataCostituzione(DateTime? dataCostituzione, DateTime? dataInizioAttivita)
    {
        if (!dataCostituzione.HasValue)
            return ValidationResult.Success();

        if (dataCostituzione.Value > DateTime.Today)
            return ValidationResult.Failure(
                "La data di costituzione non può essere futura.",
                "CHK_AZ_DATA_COST_001"
            );

        if (dataInizioAttivita.HasValue && dataCostituzione.Value > dataInizioAttivita.Value)
            return ValidationResult.Failure(
                "La data di costituzione non può essere successiva alla data di inizio attività.",
                "CHK_AZ_DATA_COST_002"
            );

        return ValidationResult.Success();
    }

    public static ValidationResult ValidateDataInizioAttivita(DateTime? dataInizioAttivita, DateTime? dataCostituzione)
    {
        if (!dataInizioAttivita.HasValue)
            return ValidationResult.Success();

        if (dataInizioAttivita.Value > DateTime.Today)
            return ValidationResult.Failure(
                "La data di inizio attività non può essere futura.",
                "CHK_AZ_DATA_INIZIO_001"
            );

        if (dataCostituzione.HasValue && dataInizioAttivita.Value < dataCostituzione.Value)
            return ValidationResult.Failure(
                "La data di inizio attività non può essere precedente alla data di costituzione.",
                "CHK_AZ_DATA_INIZIO_002"
            );

        return ValidationResult.Success();
    }

    public static ValidationResult ValidateReaDataIscrizione(DateTime? reaDataIscrizione, DateTime? dataCostituzione)
    {
        if (!reaDataIscrizione.HasValue)
            return ValidationResult.Success();

        if (reaDataIscrizione.Value > DateTime.Today)
            return ValidationResult.Failure(
                "La data di iscrizione REA non può essere futura.",
                "CHK_AZ_REA_DATA_001"
            );

        if (dataCostituzione.HasValue && reaDataIscrizione.Value < dataCostituzione.Value)
            return ValidationResult.Failure(
                "La data di iscrizione REA non può essere precedente alla data di costituzione.",
                "CHK_AZ_REA_DATA_002"
            );

        return ValidationResult.Success();
    }

    public static ValidationResult ValidateReaConsistency(int? reaProvinciaFk, string? reaNumero)
    {
        bool hasReaProvincia = reaProvinciaFk.HasValue;
        bool hasReaNumero = !string.IsNullOrWhiteSpace(reaNumero);

        if (hasReaProvincia && !hasReaNumero)
            return ValidationResult.Failure(
                "Se è specificata la provincia REA, è necessario indicare anche il numero REA.",
                "CHK_AZ_REA_CONS_001"
            );

        if (!hasReaProvincia && hasReaNumero)
            return ValidationResult.Failure(
                "Se è specificato il numero REA, è necessario indicare anche la provincia REA.",
                "CHK_AZ_REA_CONS_002"
            );

        return ValidationResult.Success();
    }
}
