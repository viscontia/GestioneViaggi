using GestioneViaggi.Models;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace GestioneViaggi.Services.Printing;

/// <summary>
/// La nota in fondo alle stampe di partenza: chi parte con un documento che non arriva
/// valido alla fine del viaggio.
///
/// Sta in fondo e non in testa di proposito: la stampa serve a lavorare, e l'avviso non
/// deve prendere il posto del contenuto. Ma va sul <b>foglio</b>, non solo a schermo,
/// perché chi lo leggerà — in ufficio o alla partenza — può non essere la persona che ha
/// lanciato la stampa, e a quel punto il dialogo di avviso è già stato chiuso da un pezzo.
///
/// Solo su rooming list, scheda data viaggio e dettaglio data viaggio: sono le tre stampe
/// che si usano prima di partire. Registro IVA, scadenzario e fatture non c'entrano nulla.
/// </summary>
public static class NotaDocumentiPdf
{
    /// <summary>Disegna la nota, o non fa niente se non c'è nulla da segnalare.</summary>
    public static void Componi(QuestPDF.Infrastructure.IContainer container, List<DocumentoNonValido>? daSistemare)
    {
        if (daSistemare is null || daSistemare.Count == 0)
        {
            container.Height(0);
            return;
        }

        var impedimenti = daSistemare.Where(d => d.Impedisce).ToList();
        var inScadenza = daSistemare.Where(d => !d.Impedisce).ToList();
        var estero = daSistemare.Any(d => d.ViaggioEstero);

        container.PaddingTop(12).Column(colonna =>
        {
            colonna.Item().PaddingBottom(4).Text(testo =>
            {
                testo.Span("DOCUMENTI DA VERIFICARE PRIMA DELLA PARTENZA")
                     .FontSize(9).Bold().FontColor(QuestPDF.Helpers.Colors.Red.Darken2);
            });

            if (impedimenti.Count > 0)
            {
                colonna.Item().Text(testo =>
                {
                    testo.Span($"{impedimenti.Count} ")
                         .FontSize(8).Bold().FontColor(QuestPDF.Helpers.Colors.Red.Darken2);
                    testo.Span(impedimenti.Count == 1
                            ? "persona non può partire: documento mancante o scaduto. "
                            : "persone non possono partire: documento mancante o scaduto. ")
                         .FontSize(8).FontColor(QuestPDF.Helpers.Colors.Red.Darken2);
                    testo.Span(estero
                            ? "Il viaggio è all'estero: senza documento valido non si parte."
                            : "In albergo i documenti di tutti gli occupanti si presentano per legge.")
                         .FontSize(8).FontColor(QuestPDF.Helpers.Colors.Red.Darken2);
                });
            }

            if (inScadenza.Count > 0)
            {
                colonna.Item().Text(testo =>
                {
                    testo.Span($"{inScadenza.Count} ").FontSize(8).Bold().FontColor(QuestPDF.Helpers.Colors.Orange.Darken3);
                    testo.Span(inScadenza.Count == 1
                            ? "persona ha il documento in scadenza durante il viaggio: parte, ma va avvisata di rinnovarlo."
                            : "persone hanno il documento in scadenza durante il viaggio: partono, ma vanno avvisate di rinnovarlo.")
                         .FontSize(8).FontColor(QuestPDF.Helpers.Colors.Orange.Darken3);
                });
            }

            colonna.Item().PaddingTop(4).Table(tabella =>
            {
                tabella.ColumnsDefinition(c =>
                {
                    c.RelativeColumn(2.2f);   // cognome e nome
                    c.RelativeColumn(2.6f);   // email
                    c.RelativeColumn(1.6f);   // telefono
                    c.RelativeColumn(3.6f);   // cosa c'è che non va
                });

                tabella.Header(intestazione =>
                {
                    foreach (var titolo in new[] { "Cognome e nome", "Email", "Telefono", "Documento" })
                    {
                        intestazione.Cell().BorderBottom(0.5f).BorderColor(QuestPDF.Helpers.Colors.Grey.Medium)
                                    .PaddingVertical(2)
                                    .Text(titolo).FontSize(7).Bold().FontColor(QuestPDF.Helpers.Colors.Grey.Darken2);
                    }
                });

                foreach (var p in daSistemare)
                {
                    var colore = p.Impedisce ? QuestPDF.Helpers.Colors.Red.Darken2 : QuestPDF.Helpers.Colors.Orange.Darken3;

                    tabella.Cell().PaddingVertical(1.5f)
                           .Text(p.Nominativo).FontSize(7.5f).Bold().FontColor(colore);
                    tabella.Cell().PaddingVertical(1.5f)
                           .Text(string.IsNullOrWhiteSpace(p.Email) ? "—" : p.Email!)
                           .FontSize(7.5f).FontColor(colore);
                    tabella.Cell().PaddingVertical(1.5f)
                           .Text(string.IsNullOrWhiteSpace(p.TelefonoCompleto) ? "—" : p.TelefonoCompleto)
                           .FontSize(7.5f).FontColor(colore);
                    tabella.Cell().PaddingVertical(1.5f)
                           .Text(p.Messaggio).FontSize(7.5f).FontColor(colore);
                }
            });
        });
    }
}
