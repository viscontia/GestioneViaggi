using Xunit;
using GestioneViaggi.Models;
using GestioneViaggi.Repositories;
using GestioneViaggi.Repositories.Interfaces;
using GestioneViaggi.Services.Database;
using GestioneViaggi.Services.Session;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;

namespace GestioneViaggi.Unit_Tests
{
    /// <summary>
    /// Integration tests for ClienteRepository
    /// These tests verify CRUD operations work correctly before and after DB-First refactoring
    /// </summary>
    public class ClienteRepositoryIntegrationTests : IDisposable
    {
        private readonly IClienteRepository _repository;
        private readonly IDatabaseService _databaseService;
        private readonly int _testAziendaId = 1; // Assuming test company exists
        private readonly List<int> _createdClienteIds = new();

        public ClienteRepositoryIntegrationTests()
        {
            // Setup configuration
            var configuration = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("appsettings.Development.json", optional: false)
                .Build();

            // Setup database services
            var loggerConnectionManager = new Mock<ILogger<DatabaseConnectionManager>>().Object;
            var connectionManager = new DatabaseConnectionManager(configuration, loggerConnectionManager);
            connectionManager.InitializePoolAsync().Wait();

            var loggerDbService = new Mock<ILogger<PostgreSqlService>>().Object;
            var sessionManager = new Mock<ISessionManager>();
            sessionManager.Setup(s => s.UserEmail).Returns("test@test.com");
            sessionManager.Setup(s => s.IsUserLoggedIn).Returns(true);

            _databaseService = new PostgreSqlService(connectionManager, sessionManager.Object, loggerDbService);

            // Setup repository
            var loggerRepo = new Mock<ILogger<ClienteRepository>>().Object;
            _repository = new ClienteRepository(_databaseService, loggerRepo, sessionManager.Object);
        }

        #region GetByIdAsync Tests

        [Fact]
        public async Task GetByIdAsync_WithValidId_ShouldReturnCliente()
        {
            // Arrange
            var cliente = await CreateTestClienteAsync();

            // Act
            var result = await _repository.GetByIdAsync(cliente.ClienteId, _testAziendaId);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(cliente.ClienteId, result.ClienteId);
            Assert.Equal(cliente.Cognome, result.Cognome);
            Assert.Equal(cliente.Nome, result.Nome);
            Assert.Equal(cliente.Email, result.Email);
        }

        [Fact]
        public async Task GetByIdAsync_WithInvalidId_ShouldReturnNull()
        {
            // Act
            var result = await _repository.GetByIdAsync(999999, _testAziendaId);

            // Assert
            Assert.Null(result);
        }

        [Fact]
        public async Task GetByIdAsync_WithWrongAzienda_ShouldReturnNull()
        {
            // Arrange
            var cliente = await CreateTestClienteAsync();

            // Act - try to get with different azienda
            var result = await _repository.GetByIdAsync(cliente.ClienteId, 99999);

            // Assert
            Assert.Null(result);
        }

        #endregion

        #region GetAllAsync Tests

        [Fact]
        public async Task GetAllAsync_ShouldReturnClientiForAzienda()
        {
            // Arrange
            var cliente1 = await CreateTestClienteAsync();
            var cliente2 = await CreateTestClienteAsync();

            // Act
            var result = await _repository.GetAllAsync(_testAziendaId, null);

            // Assert
            Assert.NotNull(result);
            Assert.True(result.Count >= 2);
            Assert.Contains(result, c => c.ClienteId == cliente1.ClienteId);
            Assert.Contains(result, c => c.ClienteId == cliente2.ClienteId);
        }

        [Fact]
        public async Task GetAllAsync_WithNullAzienda_ShouldReturnAllClienti()
        {
            // Act
            var result = await _repository.GetAllAsync(null, null);

            // Assert
            Assert.NotNull(result);
            // Should return all clienti across all companies (SuperAdmin view)
        }

        #endregion

        #region InsertAsync Tests

        [Fact]
        public async Task InsertAsync_WithValidData_ShouldCreateCliente()
        {
            // Arrange
            var cliente = new Cliente
            {
                Cognome = "ROSSI",
                Nome = "MARIO",
                Email = $"test.{Guid.NewGuid()}@example.com",
                Sesso = "M",
                DataNascita = new DateTime(1980, 1, 1),
                AziendaFk = _testAziendaId,
                CodiceFiscale = $"RSSMRA80A01H501{GenerateRandomChar()}"
            };

            // Act
            var result = await _repository.InsertAsync(cliente);

            // Assert
            Assert.NotNull(result);
            Assert.True(result.ClienteId > 0);
            Assert.Equal(cliente.Cognome, result.Cognome);
            Assert.Equal(cliente.Nome, result.Nome);
            Assert.Equal(cliente.Email, result.Email);
            Assert.NotNull(result.Created);
            Assert.NotNull(result.CreatedBy);

            // Cleanup
            _createdClienteIds.Add(result.ClienteId);
        }

        [Fact]
        public async Task InsertAsync_WithNullRequiredFields_ShouldThrowException()
        {
            // Arrange
            var cliente = new Cliente
            {
                // Missing required fields: Cognome, Nome
                Email = $"test.{Guid.NewGuid()}@example.com",
                AziendaFk = _testAziendaId
            };

            // Act & Assert
            await Assert.ThrowsAsync<Exception>(async () => await _repository.InsertAsync(cliente));
        }

        #endregion

        #region UpdateAsync Tests

        [Fact]
        public async Task UpdateAsync_WithValidData_ShouldUpdateCliente()
        {
            // Arrange
            var cliente = await CreateTestClienteAsync();
            var originalEmail = cliente.Email;
            var newEmail = $"updated.{Guid.NewGuid()}@example.com";

            // Update email
            cliente.Email = newEmail;
            cliente.Note = "Updated note";

            // Act
            var result = await _repository.UpdateAsync(cliente);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(newEmail, result.Email);
            Assert.Equal("Updated note", result.Note);
            Assert.NotNull(result.Updated);
            Assert.NotNull(result.UpdatedBy);
        }

        [Fact]
        public async Task UpdateAsync_WithNonExistentId_ShouldThrowException()
        {
            // Arrange
            var cliente = new Cliente
            {
                ClienteId = 999999,
                Cognome = "TEST",
                Nome = "TEST",
                Email = "test@example.com",
                AziendaFk = _testAziendaId
            };

            // Act & Assert
            await Assert.ThrowsAsync<Exception>(async () => await _repository.UpdateAsync(cliente));
        }

        #endregion

        #region DeleteAsync Tests

        [Fact]
        public async Task DeleteAsync_WithValidId_ShouldDeleteCliente()
        {
            // Arrange
            var cliente = await CreateTestClienteAsync();
            var clienteId = cliente.ClienteId;

            // Act
            await _repository.DeleteAsync(clienteId, _testAziendaId);

            // Assert - verify cliente no longer exists
            var deletedCliente = await _repository.GetByIdAsync(clienteId, _testAziendaId);
            Assert.Null(deletedCliente);

            // Remove from cleanup list since already deleted
            _createdClienteIds.Remove(clienteId);
        }

        [Fact]
        public async Task DeleteAsync_WithNonExistentId_ShouldNotThrowException()
        {
            // Act & Assert - should not throw
            await _repository.DeleteAsync(999999, _testAziendaId);
        }

        #endregion

        #region Existence Check Tests

        [Fact]
        public async Task ExistsByEmailAsync_WithExistingEmail_ShouldReturnTrue()
        {
            // Arrange
            var cliente = await CreateTestClienteAsync();

            // Act
            var exists = await _repository.ExistsByEmailAsync(cliente.Email!, cliente.ClienteId, _testAziendaId);

            // Assert
            Assert.False(exists); // Should be false because we exclude the same cliente_id

            // Test with different ID
            var existsForOther = await _repository.ExistsByEmailAsync(cliente.Email!, 0, _testAziendaId);
            Assert.True(existsForOther);
        }

        [Fact]
        public async Task ExistsByCodiceFiscaleAsync_WithExistingCF_ShouldReturnTrue()
        {
            // Arrange
            var cliente = await CreateTestClienteAsync();

            // Act
            var exists = await _repository.ExistsByCodiceFiscaleAsync(cliente.CodiceFiscale!, cliente.ClienteId, _testAziendaId);

            // Assert
            Assert.False(exists); // Should be false because we exclude the same cliente_id

            // Test with different ID
            var existsForOther = await _repository.ExistsByCodiceFiscaleAsync(cliente.CodiceFiscale!, 0, _testAziendaId);
            Assert.True(existsForOther);
        }

        #endregion

        #region Search Tests

        [Fact]
        public async Task SearchAsync_WithMatchingText_ShouldReturnResults()
        {
            // Arrange
            var uniqueName = $"SEARCHTEST{Guid.NewGuid().ToString().Substring(0, 8)}";
            var cliente = new Cliente
            {
                Cognome = uniqueName,
                Nome = "MARIO",
                Email = $"search.{Guid.NewGuid()}@example.com",
                Sesso = "M",
                DataNascita = new DateTime(1980, 1, 1),
                AziendaFk = _testAziendaId,
                CodiceFiscale = $"SRCHTS80A01H501{GenerateRandomChar()}"
            };
            var created = await _repository.InsertAsync(cliente);
            _createdClienteIds.Add(created.ClienteId);

            // Act
            var results = await _repository.SearchAsync(_testAziendaId, uniqueName);

            // Assert
            Assert.NotNull(results);
            Assert.NotEmpty(results);
            Assert.Contains(results, c => c.ClienteId == created.ClienteId);
        }

        [Fact]
        public async Task SearchAsync_WithNoMatch_ShouldReturnEmpty()
        {
            // Act
            var results = await _repository.SearchAsync(_testAziendaId, "NONEXISTENTSEARCHTERM123456");

            // Assert
            Assert.NotNull(results);
            Assert.Empty(results);
        }

        #endregion

        #region Helper Methods

        private async Task<Cliente> CreateTestClienteAsync()
        {
            var uniqueId = Guid.NewGuid().ToString().Substring(0, 8);
            var cliente = new Cliente
            {
                Cognome = $"TEST{uniqueId}",
                Nome = "MARIO",
                Email = $"test.{uniqueId}@example.com",
                Sesso = "M",
                DataNascita = new DateTime(1980, 1, 1),
                Telefono = "1234567890",
                AziendaFk = _testAziendaId,
                CodiceFiscale = $"TST{uniqueId}80A01H501{GenerateRandomChar()}"
            };

            var result = await _repository.InsertAsync(cliente);
            _createdClienteIds.Add(result.ClienteId);
            return result;
        }

        private static char GenerateRandomChar()
        {
            var random = new Random();
            return (char)('A' + random.Next(0, 26));
        }

        #endregion

        #region Cleanup

        public void Dispose()
        {
            // Cleanup test data
            foreach (var clienteId in _createdClienteIds)
            {
                try
                {
                    _repository.DeleteAsync(clienteId, _testAziendaId).Wait();
                }
                catch
                {
                    // Ignore cleanup errors
                }
            }
        }

        #endregion
    }
}
