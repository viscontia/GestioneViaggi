# Architecture: Session & Database Persistence

## Overview

Implementazione **enterprise-grade** della persistenza della sessione utente e della connessione al database in GestioneViaggi, con supporto multi-tenant e security-first principles.

---

## 1. Session Management (`Services/Session/`)

### **ISessionManager** (Interface)
```csharp
public interface ISessionManager
{
    Task InitializeAsync();
    Task SaveSessionAsync(UserInfo user, string sessionToken);
    Task<SessionData?> GetSessionAsync();
    Task ClearSessionAsync();
    bool IsSessionValid();
    Task<bool> RefreshSessionAsync();
    string? GetCurrentTenantId();
}
```

**Responsabilità:**
- ✅ Salva token e UserInfo in **SecureStorage** (MAUI)
- ✅ Gestisce scadenza della sessione (24 ore default)
- ✅ Fornisce cache in-memory per performance
- ✅ Multi-tenant aware (isolamento per TenantId)
- ✅ Supporta refresh della sessione

### **SessionManager** (Implementation)
```csharp
public class SessionManager : ISessionManager
{
    private SessionData? _cachedSession;
}
```

**Flow:**
1. **Login** → `SaveSessionAsync()` 
   - Serializza UserInfo in JSON
   - Salva token, user, expiry, tenantId in SecureStorage
   - Cache in-memory per accesso veloce

2. **Durante la sessione** → `GetSessionAsync()`
   - Verifica cache in-memory
   - Se scaduto → ricarica da SecureStorage
   - Se ancora scaduto → ritorna null

3. **Logout** → `ClearSessionAsync()`
   - Rimuove tutti i dati da SecureStorage
   - Invalida cache in-memory

### **SessionConstants**
```csharp
SessionTokenKey = "gv_session_token"
UserInfoKey = "gv_user_info"
SessionExpiryKey = "gv_session_expiry"
TenantIdKey = "gv_tenant_id"
SessionExpiryHours = 24
```

---

## 2. Database Connection Management (`Services/Database/`)

### **IDatabaseConnectionManager** (Interface)
```csharp
public interface IDatabaseConnectionManager
{
    Task<NpgsqlConnection> GetConnectionAsync();
    Task InitializePoolAsync();
    Task DisposePoolAsync();
    bool IsConnectionAvailable { get; }
}
```

### **DatabaseConnectionManager** (Implementation)

**Ottimizzazioni:**
- ✅ **NpgsqlDataSource**: Centralizzato connection pool (Npgsql 8.0.5+)
- ✅ **MinPoolSize=1, MaxPoolSize=20**: Connessioni riutilizzabili
- ✅ **Timeout=30s, CommandTimeout=30s**: Protezione da deadlock
- ✅ **Lazy Initialization**: Pool creato on-demand

**Flow:**
```
App Start
  ↓
AppInitializer.OnInitializedAsync()
  ↓
DatabaseConnectionManager.InitializePoolAsync()
  ↓
NpgsqlDataSource pronto per riuso durante la sessione
```

---

## 3. Authentication Integration (`Services/Authentication/`)

### **AuthenticationService** (Modified)

**Integrazione SessionManager:**
```csharp
public class AuthenticationService : IAuthenticationService
{
    private readonly ISessionManager _sessionManager;

    public async Task<LoginResponse> LoginAsync(LoginRequest request)
    {
        // ... DB validation ...
        
        var sessionToken = GenerateSessionToken(user.UserId, user.TenantId);
        await _sessionManager.SaveSessionAsync(user, sessionToken); // ← NUOVO
        
        return new LoginResponse { Success = true, User = user };
    }

    public async Task<UserInfo?> GetCurrentUserAsync()
    {
        if (_currentUser != null) return _currentUser;
        
        var session = await _sessionManager.GetSessionAsync(); // ← RECOVERY
        if (session?.IsValid ?? false)
        {
            _currentUser = session.User;
            return _currentUser;
        }
        
        return null;
    }

    public async Task LogoutAsync()
    {
        _currentUser = null;
        await _sessionManager.ClearSessionAsync(); // ← CLEANUP
    }
}
```

### **CustomAuthStateProvider** (Enhanced)

```csharp
public async Task<bool> ValidateSessionAsync()
{
    var session = await _sessionManager.GetSessionAsync();
    
    if (session?.IsExpired ?? true)
    {
        await _sessionManager.ClearSessionAsync();
        NotifyAuthenticationStateChanged();
        return false;
    }
    
    return true;
}
```

---

## 4. Application Startup Orchestration

### **AppInitializer.razor** (New Component)

```razor
@implements IAsyncDisposable

@code {
    protected override async Task OnInitializedAsync()
    {
        // Sequenza di inizializzazione
        await DatabaseConnectionManager.InitializePoolAsync();
        await SessionManager.InitializeAsync();
        AuthStateProvider.NotifyAuthenticationStateChanged();
    }

    async ValueTask IAsyncDisposable.DisposeAsync()
    {
        await DatabaseConnectionManager.DisposePoolAsync();
    }
}
```

### **MauiProgram.cs** (DI Configuration)

```csharp
builder.Services.AddSingleton<IDatabaseConnectionManager, DatabaseConnectionManager>();
builder.Services.AddSingleton<IDatabaseService, PostgreSqlService>();
builder.Services.AddSingleton<ISessionManager, SessionManager>();

builder.Services.AddScoped<IAuthenticationService, AuthenticationService>();
builder.Services.AddScoped<AuthenticationStateProvider, CustomAuthStateProvider>();
```

---

## 5. Security Considerations

### **SecureStorage (MAUI Native)**
- ✅ Token salvato in **Keychain (iOS)**, **Keystore (Android)**, **Credential Manager (Windows)**
- ✅ Separato da Preferences (dati non-sensibili)
- ✅ Crittografia automatica per piattaforma

### **Session Token Generation**
```csharp
private string GenerateSessionToken(Guid userId, string tenantId)
{
    var timestamp = DateTime.UtcNow.Ticks;
    byte[] randomBytes = new byte[16];
    
    using (var rng = RandomNumberGenerator.Create())
        rng.GetBytes(randomBytes);
    
    // Format: {userId}:{tenantId}:{timestamp}:{randomData}
    var tokenData = $"{userId}:{tenantId}:{timestamp}:{Convert.ToBase64String(randomBytes)}";
    return Convert.ToBase64String(Encoding.UTF8.GetBytes(tokenData));
}
```

### **Expiration & Refresh**
- Sessione scade dopo **24 ore**
- `RefreshSessionAsync()` estende la scadenza
- Token scaduto → Logout automatico + Redirect /login

---

## 6. Multi-Tenant Isolation

Ogni sessione è vincolata al **TenantId**:

```csharp
public class SessionData
{
    public string TenantId { get; set; }  // ← Isolamento
    public UserInfo User { get; set; }
}
```

**Vantaggi:**
- ✅ Previene accesso cross-tenant
- ✅ Supporto simultaneo multi-tenant
- ✅ Audit trail per tenant

---

## 7. Data Flow Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                      App Startup                                   │
└──────────────────┬───────────────────────────────────────────────┘
                   │
                   ↓
        ┌─────────────────────┐
        │   AppInitializer    │
        └──────────┬──────────┘
                   │
      ┌────────────┴────────────┐
      ↓                         ↓
┌──────────────┐          ┌──────────────────┐
│ SessionMgr   │          │ DBConnMgr        │
│ Initialize   │          │ Initialize Pool  │
└──────┬───────┘          └──────┬───────────┘
       │                         │
       ↓                         ↓
┌──────────────────────────────────────┐
│     App Ready for User Login          │
└──────────────────────────────────────┘


┌──────────────────────────────────────────────────────────────────┐
│                      Login Flow                                    │
└──────────────────┬───────────────────────────────────────────────┘
                   │
        User enters credentials
                   │
                   ↓
        ┌─────────────────────┐
        │ AuthService.Login() │
        └──────────┬──────────┘
                   │
      ┌────────────┴────────────┐
      ↓                         ↓
 [DB Validation]      [Generate Token]
      │                         │
      └────────────┬────────────┘
                   │
                   ↓
      ┌─────────────────────────────┐
      │ SessionMgr.SaveSession()    │
      │ - UserInfo → JSON            │
      │ - Token → SecureStorage      │
      │ - Expiry, TenantId stored    │
      └──────────┬──────────────────┘
                 │
                 ↓
         ┌───────────────┐
         │ Login Success │
         │ Redirect /app │
         └───────────────┘


┌──────────────────────────────────────────────────────────────────┐
│                   During Session                                  │
└──────────────────┬───────────────────────────────────────────────┘
                   │
         API Request needed
                   │
                   ↓
      ┌─────────────────────────┐
      │ GetCurrentUserAsync()   │
      └──────────┬──────────────┘
                 │
      ┌──────────┴──────────┐
      ↓                     ↓
  [Check Cache]       [Not in Cache?]
      │                     │
      │                     ↓
      │          ┌──────────────────────┐
      │          │ SessionMgr.GetSession│
      │          │ - Load from Storage  │
      │          └──────────┬───────────┘
      │                     │
      └──────────┬──────────┘
                 │
                 ↓
      ┌──────────────────────┐
      │ Validate Expiration  │
      └──────────┬───────────┘
                 │
        ┌────────┴────────┐
        ↓                 ↓
    [Valid]          [Expired]
        │                 │
        ↓                 ↓
    [Use User]    ┌─────────────────┐
                  │ ClearSession()  │
                  │ Logout User     │
                  │ Redirect Login  │
                  └─────────────────┘
```

---

## 8. Usage Examples

### **Login & Persist Session**
```csharp
var response = await authService.LoginAsync(request);
// SessionManager.SaveSessionAsync() called automatically
// Token stored in SecureStorage
```

### **Recover Session After App Restart**
```csharp
var user = await authService.GetCurrentUserAsync();
// If session valid → user object
// If session expired → null (auto-cleanup)
// If no session → null
```

### **Validate Session Before API Call**
```csharp
if (await authStateProvider.ValidateSessionAsync())
{
    // Session valid, proceed with API
}
else
{
    // Session invalid, redirect to login
}
```

---

## 9. Configuration

### **Connection String** (MauiProgram.cs)
```csharp
"Host=127.0.0.1;Port=5432;Database=gestione_viaggi;
Username=postgres;Password=postgres;
Pooling=true;MinPoolSize=1;MaxPoolSize=20;
Timeout=30;CommandTimeout=30;"
```

### **Session Expiry** (SessionConstants.cs)
```csharp
SessionExpiryHours = 24  // Modifiable per requirement
```

---

## 10. Testing Checklist

- [ ] **Login** → Session saved in SecureStorage
- [ ] **App Restart** → Session recovered, user auto-authenticated
- [ ] **24h Expiry** → Session auto-cleared, redirected to login
- [ ] **Manual Logout** → SecureStorage cleaned, _cachedSession null
- [ ] **DB Connection** → Pool initialized, reused across requests
- [ ] **Multi-Tenant** → TenantId isolated per session
- [ ] **Concurrent Users** → Each session independent
- [ ] **Error Recovery** → Exceptions logged, session graceful failure

---

## 11. Future Enhancements

- [ ] Token refresh endpoint (extend 24h without re-login)
- [ ] biometric unlock (Face ID / Fingerprint)
- [ ] Session history & audit logging
- [ ] Redis cache layer for distributed sessions
- [ ] JWT token integration (if needed)
- [ ] Device fingerprinting for security
