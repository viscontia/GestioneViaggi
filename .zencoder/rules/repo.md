---
description: Repository Information Overview
alwaysApply: true
---

# GestioneViaggi - Travel Management Application

## Summary

GestioneViaggi is a cross-platform travel management application built with **.NET 9 MAUI** and **Blazor**. It provides a modern interface for managing travel-related operations with multi-platform deployment capabilities (Android, iOS, macOS, Windows). The application uses PostgreSQL for data persistence and MudBlazor for enterprise-grade UI components.

## Structure

- **Components/** - Razor components for pages and shared UI elements
  - **Pages/** - Application pages (Login, Home, Admin dashboards, demo pages)
  - **Layout/** - Main layout templates (NavMenu, MainLayout, LoginLayout)
  - **Shared/** - Reusable shared components (grid, pager, breadcrumbs, status badges)
- **Services/** - Business logic and data services
  - **Authentication/** - Authentication and authorization services
  - **Database/** - PostgreSQL database service
- **Models/** - Data models (LoginRequest, LoginResponse, UserInfo)
- **Resources/** - App resources (AppIcon, Fonts, Images, Splash screen, Raw assets)
- **Platforms/** - Platform-specific code (Android, iOS, MacCatalyst, Windows)
- **Properties/** - Project launch settings
- **Documents/** - Project documentation and design files

## Language & Runtime

**Language**: C#  
**Framework**: .NET 9  
**UI Framework**: MAUI (Microsoft.Maui.Controls) with Blazor components  
**Component Library**: MudBlazor 8.15.0  
**Build System**: MSBuild (.csproj)  
**Package Manager**: NuGet

## Target Platforms

- **Android**: API 24+
- **iOS**: 14.2+
- **macOS (Catalyst)**: 15.0+
- **Windows**: 10.0.17763.0+

## Dependencies

**Core Frameworks**:
- Microsoft.Maui.Controls (MAUI version)
- Microsoft.AspNetCore.Components.WebView.Maui (MAUI version)
- MudBlazor 8.15.0

**Database**:
- Npgsql 8.0.5 (PostgreSQL provider)

**Authentication**:
- Microsoft.AspNetCore.Components.Authorization 9.0.0

**Development**:
- Microsoft.Extensions.Logging.Debug 9.0.0

## Build & Installation

The project uses a single-project MAUI structure with multi-platform targeting. Build commands vary by platform:

```bash
# Build for Android
dotnet build -f net9.0-android

# Build for iOS (macOS only)
dotnet build -f net9.0-ios

# Build for macOS Catalyst
dotnet build -f net9.0-maccatalyst

# Build for Windows (Windows only)
dotnet build -f net9.0-windows10.0.19041.0

# Build all platforms
dotnet build
```

**Configuration**: Connection strings and settings are currently configured in `MauiProgram.cs` with hardcoded PostgreSQL connection (host: 127.0.0.1, database: gestione_viaggi). This should be moved to `appsettings.json` for production.

## Main Entry Points

- **App.xaml / App.xaml.cs** - Application root (creates main window with 1200x800 on desktop platforms)
- **MauiProgram.cs** - Application configuration and DI setup
- **MainPage.xaml** - Initial page displayed at startup
- **Components/Pages/Home.razor** - Home page component
- **Components/Pages/Login.razor** - Login page for authentication

## Authentication & Services

**Authentication**:
- Custom `IAuthenticationService` implementation in `Services/Authentication/`
- `CustomAuthStateProvider` for managing authentication state
- Bearer token-based authentication with authorization core

**Database**:
- `IDatabaseService` abstraction with PostgreSQL implementation
- Connection pooling (1-20 connections)
- Timeout: 30 seconds, CommandTimeout: 30 seconds

## Logging & Debugging

- Debug logging enabled via `Microsoft.Extensions.Logging.Debug`
- Blazor WebView developer tools available in DEBUG builds
- Inspector element (right-click) enabled in DEBUG configuration

## Version Information

**Application Version**: 1.0  
**Application ID**: com.companyname.gestioneviaggi  
**Display Name**: GestioneViaggi
