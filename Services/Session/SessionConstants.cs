namespace GestioneViaggi.Services.Session;

public static class SessionConstants
{
    public const string SessionTokenKey = "gv_session_token";
    public const string UserInfoKey = "gv_user_info";
    public const string SessionExpiryKey = "gv_session_expiry";
    public const string TenantIdKey = "gv_tenant_id";
    public const int SessionExpiryHours = 24;
}
