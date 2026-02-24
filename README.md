# IROD - Intune Remediation On Demand

A PowerShell tool to trigger Intune Proactive Remediation scripts on demand. Supports single device mode or multi-device selection via a WPF GUI with pagination and search. Connects to Microsoft Graph using least-privileged permissions and provides real-time progress tracking for batch remediation operations.

## Features

- **Single Device Mode** - Run remediation on a specific device by name
- **Multi-Device Mode** - Select multiple devices via WPF GUI with:
  - Pagination for large device lists (50 devices per page)
  - Search/filter functionality across device names and users
  - Checkbox selection with count display
  - Select all/deselect all options
  - Real-time progress tracking window
- **Automatic Module Installation** - Checks and installs required PowerShell modules automatically
- **Least-Privileged Permissions** - Uses only the minimum required Microsoft Graph scopes
- **Device Sync** - Automatically initiates device sync after triggering remediation
- **Windows Devices Only** - Filters to show only Windows devices (since remediation scripts only apply to Windows)
- **Dark Theme GUI** - Modern dark-themed WPF interface for better usability

## Prerequisites

- PowerShell 5.1 or later
- Microsoft.Graph.Authentication module (auto-installed if missing)

The tool will automatically check for and install required modules on first run. To manually install:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

## Required Permissions

| Permission | Purpose |
|------------|---------|
| `DeviceManagementConfiguration.Read.All` | Read remediation scripts |
| `DeviceManagementManagedDevices.Read.All` | List and search devices |
| `DeviceManagementManagedDevices.PrivilegedOperations.All` | Trigger remediation and sync |

## Installation

### Option 1: PowerShell Gallery (Recommended)

```powershell
Install-Module -Name IROD -Scope CurrentUser
Import-Module IROD
```

### Option 2: Manual Installation

1. Clone or download this repository
2. Import the module:
```powershell
Import-Module .\IROD\IROD.psd1
```

### Option 3: Use as Standalone Script (Backward Compatibility)

```powershell
.\IROD.ps1
```

## Usage

### Using the Module (Recommended)

**Interactive Mode:**
```powershell
Import-Module .\IROD\IROD.psd1
Invoke-IntuneRemediation
```

**Single Device Mode:**
```powershell
Invoke-IntuneRemediation -DeviceName "DESKTOP-ABC123"
```

**Multi-Device Mode:**
```powershell
Invoke-IntuneRemediation -MultiDevice
```

**With Tenant ID:**
```powershell
Invoke-IntuneRemediation -TenantId "your-tenant-id"
```

**Get Help:**
```powershell
Invoke-IntuneRemediation -Help
```

### Using as Standalone Script (Backward Compatibility)

**Interactive Mode:**
```powershell
.\IROD.ps1
```

**Single Device Mode:**
```powershell
.\IROD.ps1 -DeviceName "DESKTOP-ABC123"
```

**Multi-Device Mode:**
```powershell
.\IROD.ps1 -MultiDevice
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `-DeviceName` | Name of a specific device to run remediation on |
| `-MultiDevice` | Switch to enable multi-device selection GUI |
| `-ClientId` | Client ID of custom app registration (or set via `Configure-IROD`) |
| `-TenantId` | Tenant ID for custom app registration (or set via `Configure-IROD`) |
| `-Help` | Display detailed help information and exit |

## Configuration

### Custom App Registration

Instead of using parameters every time, you can configure IROD to use your custom app registration:

```powershell
Configure-IROD
```

**Example output:**
```
[ I R O D ]

This will configure your custom app registration for IROD.
These settings will be saved as user-level environment variables.

Enter your App Registration Client ID: abc123-def4-5678-90ab-cdef12345678
Enter your Tenant ID: xyz789-abc1-2345-67de-f89012345678

Configuration saved successfully!
You can now run Invoke-IntuneRemediation without parameters.
```

After configuration, just run:

```powershell
Invoke-IntuneRemediation
```

**To clear the configuration:**
```powershell
Clear-IRODConfig
```

### App Registration Requirements

Your custom app registration must have:
- **Platform**: Mobile and desktop applications
- **Redirect URI**: http://localhost
- **Allow public client flows**: Yes
- **API Permissions** (delegated):
  - `DeviceManagementConfiguration.Read.All`
  - `DeviceManagementManagedDevices.Read.All`
  - `DeviceManagementManagedDevices.PrivilegedOperations.All`

### Automatic Update Checking

IROD automatically checks for updates once every 24 hours when you run it. If an update is available, you'll be prompted to update.

**To disable update checks:**
```powershell
$env:IROD_DISABLE_UPDATE_CHECK = 'true'
```

## How It Works

1. Select execution mode (single or multi-device)
2. Authenticate to Microsoft Graph
3. Select a remediation script from your Intune tenant
4. Select target device(s)
5. Confirm and execute
6. View real-time progress (multi-device mode)

## Interface

### Mode Selection
When running without parameters, you'll see:
```
[ I R O D ]

  [1] Single Device
      Run remediation on one specific device

  [2] Multi-Device
      Select multiple devices via GUI

  [Q] Quit

Enter choice (1, 2, or Q):
```

### Multi-Device WPF GUI Features
- Device grid with pagination (50 devices per page)
- Live search/filter functionality
- Checkbox selection with counter
- Select All on Page / Deselect All buttons
- Exit Tool button for clean exit at any stage
- Real-time progress tracking window during execution

## License

MIT License
