using Xunit;
using GestioneViaggi.Validation.Syntax;
using GestioneViaggi.Validation.Core;

namespace GestioneViaggi.Unit_Tests
{
    public class VatValidationTests
    {
        [Theory]
        [InlineData("MA12345678")] // Marocco: 8 cifre
        [InlineData("TN1234567A")] // Tunisia: 7 cifre + 1 lettera
        [InlineData("DZ123456789012345")] // Algeria: 15 cifre
        [InlineData("DZ12345678901234567890")] // Algeria: 20 cifre
        [InlineData("LY123456")] // Libia: 6 cifre
        [InlineData("EG123456789")] // Egitto: 9 cifre
        [InlineData("IT12345678901")] // Regressione: Italia
        [InlineData("CHE123456789IVA")] // Regressione: Svizzera
        public void VatValidation_PositiveCases_ShouldReturnSuccess(string vat)
        {
            // Act
            var result = EuropeanVatValidator.CheckVatNumber(vat);

            // Assert
            Assert.True(result.IsValid, $"La P.IVA {vat} dovrebbe essere valida. Errore: {result.ErrorMessage}");
        }

        [Theory]
        [InlineData("MA1234567")] // Marocco: troppo corta (7 cifre)
        [InlineData("MA123456789")] // Marocco: troppo lunga (9 cifre)
        [InlineData("TN12345678")] // Tunisia: 8 cifre (manca lettera finale)
        [InlineData("TN123456A8")] // Tunisia: lettera in posizione errata
        [InlineData("DZ12345678901234")] // Algeria: troppo corta (14 cifre)
        [InlineData("DZ1234567890123456789")] // Algeria: lunghezza intermedia (19 cifre) non ammessa
        [InlineData("LY12345")] // Libia: troppo corta (5 cifre)
        [InlineData("LY1234567")] // Libia: troppo lunga (7 cifre)
        [InlineData("EG12345678")] // Egitto: troppo corta (8 cifre)
        [InlineData("EG1234567890")] // Egitto: troppo lunga (10 cifre)
        [InlineData("")] // Vuota
        [InlineData(null)] // Null
        public void VatValidation_NegativeCases_ShouldReturnFailure(string? vat)
        {
            // Act
            var result = EuropeanVatValidator.CheckVatNumber(vat);

            // Assert
            Assert.False(result.IsValid, $"La P.IVA {vat ?? "null"} NON dovrebbe essere valida.");
        }

        [Theory]
        [InlineData("MA12345678", "MA")]
        [InlineData("TN1234567A", "TN")]
        [InlineData("DZ123456789012345", "DZ")]
        [InlineData("LY123456", "LY")]
        [InlineData("EG123456789", "EG")]
        [InlineData("CHE123456789IVA", "CHE")]
        public void ExtractCountryCode_ShouldReturnCorrectCode(string vat, string expectedCode)
        {
            // Act
            var code = EuropeanVatValidator.ExtractCountryCode(vat);

            // Assert
            Assert.Equal(expectedCode, code);
        }
    }
}
