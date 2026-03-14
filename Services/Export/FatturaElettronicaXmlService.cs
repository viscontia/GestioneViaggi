using System.Xml.Linq;
using Dapper;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Printing;
using GestioneViaggi.Services.Shared;
using Microsoft.Extensions.Logging;

namespace GestioneViaggi.Services.Export;

public interface IFatturaElettronicaXmlService
{
    Task<string> GeneraXmlFatturaAsync(int transazioneId, InvoiceBankInfo? bank = null);
    List<string> ValidateForSdiExport(FatturaAttivaPrintData data);
}

public class FatturaElettronicaXmlService : IFatturaElettronicaXmlService
{
    private readonly IDatabaseService _dbService;
    private readonly FatturaAttivaPrintService _printService;
    private readonly IFileOpenerService _fileOpenerService;
    private readonly ILogger<FatturaElettronicaXmlService> _logger;

    // Namespace FatturaPA 1.2.2
    private static readonly XNamespace NsFe = "http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2";
    private static readonly XNamespace NsDs = "http://www.w3.org/2000/09/xmldsig#";
    private static readonly XNamespace NsXsi = "http://www.w3.org/2001/XMLSchema-instance";

    public FatturaElettronicaXmlService(
        IDatabaseService dbService,
        FatturaAttivaPrintService printService,
        IFileOpenerService fileOpenerService,
        ILogger<FatturaElettronicaXmlService> logger)
    {
        _dbService = dbService;
        _printService = printService;
        _fileOpenerService = fileOpenerService;
        _logger = logger;
    }

    /// <summary>
    /// Genera il file XML FatturaPA e lo salva nella cartella Downloads.
    /// Restituisce il path completo del file generato.
    /// </summary>
    public async Task<string> GeneraXmlFatturaAsync(int transazioneId, InvoiceBankInfo? bank = null)
    {
        _logger.LogInformation("Inizio generazione XML FatturaPA per transazione {TransazioneId}", transazioneId);

        // 1. Carica dati fattura (riusa lo stesso metodo del PDF)
        var data = await _printService.GetFatturaAttivaDataAsync(transazioneId);
        if (data == null)
            throw new InvalidOperationException("Fattura attiva non trovata.");

        // 2. Validazione pre-export
        var errors = ValidateForSdiExport(data);
        if (errors.Count > 0)
            throw new InvalidOperationException(
                "Impossibile generare il file XML per lo SDI.\n\n" +
                string.Join("\n", errors.Select((e, i) => $"  {i + 1}. {e}")));

        // 3. Ottieni progressivo invio
        var progressivo = await GetNextProgressivoAsync(data.Company);

        // 4. Genera XML
        var xml = BuildFatturaElettronicaXml(data, bank, progressivo);

        // 5. Salva file
        var partitaIva = data.Company.PartitaIva.Replace(" ", "").Trim();
        var fileName = $"IT{partitaIva}_{progressivo}.xml";
        var targetFolder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            "Downloads");

        Directory.CreateDirectory(targetFolder);
        var filePath = Path.Combine(targetFolder, fileName);

        await File.WriteAllTextAsync(filePath, xml.Declaration + "\n" + xml.ToString(), System.Text.Encoding.UTF8);

        _logger.LogInformation("XML FatturaPA generato: {FileName} per transazione {TransazioneId}", fileName, transazioneId);

        // 6. Proponi apertura file
        await _fileOpenerService.OpenFileAsync(filePath, "FatturaPA XML Generato");

        return filePath;
    }

    // ============================================================
    // VALIDAZIONE PRE-EXPORT
    // ============================================================

    public List<string> ValidateForSdiExport(FatturaAttivaPrintData data)
    {
        var errors = new List<string>();

        // --- Azienda (CedentePrestatore) ---
        if (string.IsNullOrWhiteSpace(data.Company.PartitaIva))
            errors.Add("Partita IVA dell'azienda non compilata.");

        if (string.IsNullOrWhiteSpace(data.Company.RegimeCodiceSdi))
            errors.Add("Codice Regime Fiscale SDI non configurato (es. RF01, RF19). Contattare l'amministratore.");

        if (string.IsNullOrWhiteSpace(data.Company.Indirizzo))
            errors.Add("Sede legale dell'azienda: indirizzo mancante.");
        if (string.IsNullOrWhiteSpace(data.Company.Cap))
            errors.Add("Sede legale dell'azienda: CAP mancante.");
        if (string.IsNullOrWhiteSpace(data.Company.Comune))
            errors.Add("Sede legale dell'azienda: Comune mancante.");
        if (string.IsNullOrWhiteSpace(data.Company.ProvinciaSigla))
            errors.Add("Sede legale dell'azienda: Provincia mancante.");

        // --- Controparte (CessionarioCommittente) ---
        var clientName = data.Client.RagioneSociale;

        if (string.IsNullOrWhiteSpace(data.Client.PartitaIva) && string.IsNullOrWhiteSpace(data.Client.CodiceFiscale))
            errors.Add($"Il cliente \"{clientName}\" non ha né Partita IVA né Codice Fiscale. Compilare almeno uno dei due nell'anagrafica.");

        if (string.IsNullOrWhiteSpace(data.Client.CodiceSdi) && string.IsNullOrWhiteSpace(data.Client.Pec))
            errors.Add($"Il cliente \"{clientName}\" non ha né Codice Destinatario SDI né PEC. Compilare almeno uno dei due nell'anagrafica.");

        if (string.IsNullOrWhiteSpace(data.Client.Indirizzo))
            errors.Add($"Il cliente \"{clientName}\": indirizzo mancante.");
        if (string.IsNullOrWhiteSpace(data.Client.Cap))
            errors.Add($"Il cliente \"{clientName}\": CAP mancante.");
        if (string.IsNullOrWhiteSpace(data.Client.Comune))
            errors.Add($"Il cliente \"{clientName}\": Comune mancante.");

        // --- Fattura ---
        if (string.IsNullOrWhiteSpace(data.NumeroDocumento))
            errors.Add("Numero documento mancante.");
        if (!data.DataDocumento.HasValue)
            errors.Add("Data documento mancante.");
        if (string.IsNullOrWhiteSpace(data.TipoDocumentoSdi))
            errors.Add("Tipo documento SDI non configurato per questa causale (es. TD01, TD04). Contattare l'amministratore.");

        if (data.Righe.Count == 0)
            errors.Add("Nessuna riga di dettaglio presente nella fattura.");

        // Verifica Natura per aliquote a 0%
        foreach (var riepilogo in data.RiepilogoIva.Where(r => r.AliquotaPercentuale == 0))
        {
            if (string.IsNullOrWhiteSpace(riepilogo.AliquotaNatura))
                errors.Add($"L'aliquota IVA \"{riepilogo.AliquotaCodice}\" ha percentuale 0% ma il campo Natura non è compilato. Compilarlo nell'anagrafica Aliquote IVA.");
        }

        return errors;
    }

    // ============================================================
    // GENERAZIONE XML
    // ============================================================

    private XDocument BuildFatturaElettronicaXml(FatturaAttivaPrintData data, InvoiceBankInfo? bank, string progressivo)
    {
        var doc = new XDocument(
            new XDeclaration("1.0", "UTF-8", null),
            new XElement(NsFe + "FatturaElettronica",
                new XAttribute("versione", "FPR12"),
                new XAttribute(XNamespace.Xmlns + "ds", NsDs.NamespaceName),
                new XAttribute(XNamespace.Xmlns + "p", NsFe.NamespaceName),
                new XAttribute(XNamespace.Xmlns + "xsi", NsXsi.NamespaceName),
                new XAttribute(NsXsi + "schemaLocation",
                    "http://ivaservizi.agenziaentrate.gov.it/docs/xsd/fatture/v1.2 " +
                    "http://www.fatturapa.gov.it/export/fatturazione/sdi/fatturapa/v1.2.2/Schema_del_file_xml_FatturaPA_v1.2.2.xsd"),
                BuildHeader(data, progressivo),
                BuildBody(data, bank)
            )
        );

        return doc;
    }

    // ---- HEADER ----

    private XElement BuildHeader(FatturaAttivaPrintData data, string progressivo)
    {
        return new XElement(NsFe + "FatturaElettronicaHeader",
            BuildDatiTrasmissione(data, progressivo),
            BuildCedentePrestatore(data.Company),
            BuildCessionarioCommittente(data.Client)
        );
    }

    private XElement BuildDatiTrasmissione(FatturaAttivaPrintData data, string progressivo)
    {
        var partitaIva = data.Company.PartitaIva.Trim();
        var codiceDestinatario = GetCodiceDestinatario(data.Client);

        var el = new XElement(NsFe + "DatiTrasmissione",
            new XElement(NsFe + "IdTrasmittente",
                new XElement(NsFe + "IdPaese", "IT"),
                new XElement(NsFe + "IdCodice", partitaIva)
            ),
            new XElement(NsFe + "ProgressivoInvio", progressivo),
            new XElement(NsFe + "FormatoTrasmissione", "FPR12"),
            new XElement(NsFe + "CodiceDestinatario", codiceDestinatario)
        );

        // PECDestinatario: solo se CodiceDestinatario = "0000000" e PEC presente
        if (codiceDestinatario == "0000000" && !string.IsNullOrWhiteSpace(data.Client.Pec))
            el.Add(new XElement(NsFe + "PECDestinatario", data.Client.Pec.Trim()));

        return el;
    }

    private XElement BuildCedentePrestatore(InvoiceCompanyInfo company)
    {
        var datiAnagrafici = new XElement(NsFe + "DatiAnagrafici",
            new XElement(NsFe + "IdFiscaleIVA",
                new XElement(NsFe + "IdPaese", "IT"),
                new XElement(NsFe + "IdCodice", company.PartitaIva.Trim())
            )
        );

        if (!string.IsNullOrWhiteSpace(company.CodiceFiscale))
            datiAnagrafici.Add(new XElement(NsFe + "CodiceFiscale", company.CodiceFiscale.Trim()));

        datiAnagrafici.Add(new XElement(NsFe + "Anagrafica",
            new XElement(NsFe + "Denominazione", company.RagioneSociale.Trim())
        ));

        datiAnagrafici.Add(new XElement(NsFe + "RegimeFiscale", company.RegimeCodiceSdi));

        // Sede
        var sede = new XElement(NsFe + "Sede",
            new XElement(NsFe + "Indirizzo", company.Indirizzo.Trim()),
            new XElement(NsFe + "CAP", company.Cap.Trim()),
            new XElement(NsFe + "Comune", company.Comune.Trim().ToUpper()),
            new XElement(NsFe + "Provincia", company.ProvinciaSigla.Trim()),
            new XElement(NsFe + "Nazione", "IT")
        );

        if (!string.IsNullOrWhiteSpace(company.NumeroCivico))
            sede.Element(NsFe + "CAP")!.AddBeforeSelf(
                new XElement(NsFe + "NumeroCivico", company.NumeroCivico.Trim()));

        // IscrizioneREA (opzionale)
        XElement? iscrizioneRea = null;
        if (!string.IsNullOrWhiteSpace(company.ReaProvinciaSigla) && !string.IsNullOrWhiteSpace(company.ReaNumero))
        {
            iscrizioneRea = new XElement(NsFe + "IscrizioneREA",
                new XElement(NsFe + "Ufficio", company.ReaProvinciaSigla.Trim()),
                new XElement(NsFe + "NumeroREA", company.ReaNumero.Trim())
            );

            if (company.CapitaleSociale.HasValue)
                iscrizioneRea.Add(new XElement(NsFe + "CapitaleSociale",
                    FormatDecimal(company.CapitaleSociale.Value)));

            iscrizioneRea.Add(new XElement(NsFe + "SocioUnico",
                company.SocioUnico ? "SU" : "SM"));

            iscrizioneRea.Add(new XElement(NsFe + "StatoLiquidazione",
                company.InLiquidazione ? "LS" : "LN"));
        }

        var cedente = new XElement(NsFe + "CedentePrestatore",
            datiAnagrafici,
            sede
        );

        if (iscrizioneRea != null)
            cedente.Add(iscrizioneRea);

        return cedente;
    }

    private XElement BuildCessionarioCommittente(InvoiceClientInfo client)
    {
        var datiAnagrafici = new XElement(NsFe + "DatiAnagrafici");

        // IdFiscaleIVA (se P.IVA presente)
        if (!string.IsNullOrWhiteSpace(client.PartitaIva))
        {
            var idPaese = client.FornitoreEstero ? GetCountryFromVat(client.PartitaIva) : "IT";
            var idCodice = client.FornitoreEstero
                ? client.PartitaIva.Trim().TrimStart('I', 'T')
                : client.PartitaIva.Trim();

            datiAnagrafici.Add(new XElement(NsFe + "IdFiscaleIVA",
                new XElement(NsFe + "IdPaese", idPaese),
                new XElement(NsFe + "IdCodice", idCodice)
            ));
        }

        // CodiceFiscale
        if (!string.IsNullOrWhiteSpace(client.CodiceFiscale))
            datiAnagrafici.Add(new XElement(NsFe + "CodiceFiscale", client.CodiceFiscale.Trim()));

        datiAnagrafici.Add(new XElement(NsFe + "Anagrafica",
            new XElement(NsFe + "Denominazione", client.RagioneSociale.Trim())
        ));

        // Sede
        var sede = new XElement(NsFe + "Sede",
            new XElement(NsFe + "Indirizzo", (client.Indirizzo ?? "").Trim()),
            new XElement(NsFe + "CAP", client.FornitoreEstero ? "00000" : (client.Cap ?? "00000").Trim()),
            new XElement(NsFe + "Comune", (client.Comune ?? "").Trim().ToUpper()),
            new XElement(NsFe + "Nazione", client.FornitoreEstero ? GetCountryFromVat(client.PartitaIva) : "IT")
        );

        // Provincia solo per clienti italiani
        if (!client.FornitoreEstero && !string.IsNullOrWhiteSpace(client.ProvinciaSigla))
            sede.Element(NsFe + "Nazione")!.AddBeforeSelf(
                new XElement(NsFe + "Provincia", client.ProvinciaSigla.Trim()));

        return new XElement(NsFe + "CessionarioCommittente",
            datiAnagrafici,
            sede
        );
    }

    // ---- BODY ----

    private XElement BuildBody(FatturaAttivaPrintData data, InvoiceBankInfo? bank)
    {
        var body = new XElement(NsFe + "FatturaElettronicaBody",
            BuildDatiGenerali(data),
            BuildDatiBeniServizi(data)
        );

        // DatiPagamento (opzionale, solo se banca presente)
        var pagamento = BuildDatiPagamento(data, bank);
        if (pagamento != null)
            body.Add(pagamento);

        return body;
    }

    private XElement BuildDatiGenerali(FatturaAttivaPrintData data)
    {
        var datiDoc = new XElement(NsFe + "DatiGeneraliDocumento",
            new XElement(NsFe + "TipoDocumento", data.TipoDocumentoSdi),
            new XElement(NsFe + "Divisa", "EUR"),
            new XElement(NsFe + "Data", data.DataDocumento!.Value.ToString("yyyy-MM-dd")),
            new XElement(NsFe + "Numero", data.NumeroDocumento!.Trim()),
            new XElement(NsFe + "ImportoTotaleDocumento", FormatDecimal(data.LordoEur))
        );

        // DatiBollo (se presente)
        if (data.HasBollo && data.BolloImporto.HasValue)
        {
            datiDoc.Add(new XElement(NsFe + "DatiBollo",
                new XElement(NsFe + "BolloVirtuale", "SI"),
                new XElement(NsFe + "ImportoBollo", FormatDecimal(data.BolloImporto.Value))
            ));
        }

        // Causale (opzionale, max 200 char per blocco, max 5 blocchi)
        if (!string.IsNullOrWhiteSpace(data.Causale))
        {
            var causaleText = data.Causale.Trim();
            // Suddividi in blocchi da 200 caratteri (limite FatturaPA)
            for (int i = 0; i < causaleText.Length && i < 1000; i += 200)
            {
                var chunk = causaleText.Substring(i, Math.Min(200, causaleText.Length - i));
                datiDoc.Add(new XElement(NsFe + "Causale", chunk));
            }
        }

        var datiGenerali = new XElement(NsFe + "DatiGenerali", datiDoc);

        // DatiCassaPrevidenziale (se riga CASSA_PREV presente)
        var rigaCassa = data.Righe.FirstOrDefault(r => r.RigaTipo == "CASSA_PREV");
        if (rigaCassa != null && data.Company.TipoCassaSdi != null)
        {
            var rigaPrestazione = data.Righe.FirstOrDefault(r => r.RigaTipo == "PRESTAZIONE");
            var imponibileCassa = rigaPrestazione?.RigaImponibile ?? data.ImponibileEur;

            var cassaEl = new XElement(NsFe + "DatiCassaPrevidenziale",
                new XElement(NsFe + "TipoCassa", data.Company.TipoCassaSdi),
                new XElement(NsFe + "AlCassa", FormatDecimal(data.Company.CassaPrevPercentuale ?? 0)),
                new XElement(NsFe + "ImportoContributoCassa", FormatDecimal(rigaCassa.RigaImponibile)),
                new XElement(NsFe + "ImponibileCassa", FormatDecimal(imponibileCassa)),
                new XElement(NsFe + "AliquotaIVA", FormatDecimal(rigaCassa.AliquotaIvaPercentuale ?? 0))
            );

            if (rigaCassa.AliquotaIvaPercentuale == 0 && !string.IsNullOrWhiteSpace(rigaCassa.AliquotaIvaNatura))
                cassaEl.Add(new XElement(NsFe + "Natura", rigaCassa.AliquotaIvaNatura.Trim()));

            datiDoc.Add(cassaEl);
        }

        return datiGenerali;
    }

    private XElement BuildDatiBeniServizi(FatturaAttivaPrintData data)
    {
        var datiBeniServizi = new XElement(NsFe + "DatiBeniServizi");

        // DettaglioLinee: solo righe PRESTAZIONE (bollo e cassa vanno nei rispettivi blocchi)
        int numeroLinea = 1;
        foreach (var riga in data.Righe.Where(r => r.RigaTipo == "PRESTAZIONE"))
        {
            var dettaglio = new XElement(NsFe + "DettaglioLinee",
                new XElement(NsFe + "NumeroLinea", numeroLinea++),
                new XElement(NsFe + "Descrizione", riga.RigaDescrizione.Trim()),
                new XElement(NsFe + "PrezzoUnitario", FormatDecimal(riga.RigaImponibile)),
                new XElement(NsFe + "PrezzoTotale", FormatDecimal(riga.RigaImponibile)),
                new XElement(NsFe + "AliquotaIVA", FormatDecimal(riga.AliquotaIvaPercentuale ?? 0))
            );

            if (riga.AliquotaIvaPercentuale == 0 && !string.IsNullOrWhiteSpace(riga.AliquotaIvaNatura))
                dettaglio.Add(new XElement(NsFe + "Natura", riga.AliquotaIvaNatura.Trim()));

            datiBeniServizi.Add(dettaglio);
        }

        // DatiRiepilogo: un blocco per ogni combinazione aliquota/natura (escluso BOLLO)
        foreach (var riepilogo in data.RiepilogoIva)
        {
            var riepilogoEl = new XElement(NsFe + "DatiRiepilogo",
                new XElement(NsFe + "AliquotaIVA", FormatDecimal(riepilogo.AliquotaPercentuale))
            );

            if (riepilogo.AliquotaPercentuale == 0 && !string.IsNullOrWhiteSpace(riepilogo.AliquotaNatura))
                riepilogoEl.Add(new XElement(NsFe + "Natura", riepilogo.AliquotaNatura.Trim()));

            riepilogoEl.Add(
                new XElement(NsFe + "ImponibileImporto", FormatDecimal(riepilogo.TotaleImponibile)),
                new XElement(NsFe + "Imposta", FormatDecimal(riepilogo.TotaleIva)),
                new XElement(NsFe + "EsigibilitaIVA", "I")
            );

            datiBeniServizi.Add(riepilogoEl);
        }

        return datiBeniServizi;
    }

    private XElement? BuildDatiPagamento(FatturaAttivaPrintData data, InvoiceBankInfo? bank)
    {
        if (bank == null || string.IsNullOrWhiteSpace(bank.Iban))
            return null;

        var dettaglio = new XElement(NsFe + "DettaglioPagamento",
            new XElement(NsFe + "ModalitaPagamento", "MP05"),
            new XElement(NsFe + "ImportoPagamento", FormatDecimal(data.LordoEur))
        );

        if (data.DataScadenza.HasValue)
            dettaglio.Element(NsFe + "ImportoPagamento")!.AddBeforeSelf(
                new XElement(NsFe + "DataScadenzaPagamento", data.DataScadenza.Value.ToString("yyyy-MM-dd")));

        if (!string.IsNullOrWhiteSpace(bank.NomeBanca))
            dettaglio.Add(new XElement(NsFe + "IstitutoFinanziario", bank.NomeBanca.Trim()));

        dettaglio.Add(new XElement(NsFe + "IBAN", bank.Iban.Replace(" ", "").Trim()));

        if (!string.IsNullOrWhiteSpace(bank.SwiftBic))
            dettaglio.Add(new XElement(NsFe + "BIC", bank.SwiftBic.Trim()));

        return new XElement(NsFe + "DatiPagamento",
            new XElement(NsFe + "CondizioniPagamento", "TP02"),
            dettaglio
        );
    }

    // ============================================================
    // HELPERS
    // ============================================================

    private async Task<string> GetNextProgressivoAsync(InvoiceCompanyInfo company)
    {
        await using var connection = await _dbService.GetConnectionAsync();

        // Recupera azienda_id dalla partita IVA
        var aziendaId = await connection.QueryFirstAsync<int>(
            "SELECT azienda_id FROM ana_aziende WHERE partita_iva = @PartitaIva",
            new { PartitaIva = company.PartitaIva.Trim() });

        var progressivo = await connection.QueryFirstAsync<string>(
            "SELECT fn_fatturapa_get_next_progressivo(@AziendaId)",
            new { AziendaId = aziendaId });

        return progressivo;
    }

    private static string GetCodiceDestinatario(InvoiceClientInfo client)
    {
        if (client.FornitoreEstero)
            return "XXXXXXX";

        if (!string.IsNullOrWhiteSpace(client.CodiceSdi) && client.CodiceSdi != "0000000")
            return client.CodiceSdi.Trim();

        return "0000000";
    }

    private static string GetCountryFromVat(string? vatNumber)
    {
        if (string.IsNullOrWhiteSpace(vatNumber) || vatNumber.Length < 2)
            return "IT";

        var prefix = vatNumber.Trim().Substring(0, 2).ToUpper();
        return char.IsLetter(prefix[0]) && char.IsLetter(prefix[1]) ? prefix : "IT";
    }

    private static string FormatDecimal(decimal value)
    {
        return value.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture);
    }
}
