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

## Usage

### Interactive Mode (Recommended)

```powershell
.\IROD.ps1
```

You'll be prompted to choose between single device or multi-device mode.

### Single Device Mode

```powershell
.\IROD.ps1 -DeviceName "DESKTOP-ABC123"
```

### Multi-Device Mode

```powershell
.\IROD.ps1 -MultiDevice
```

### Additional Parameters

| Parameter | Description |
|-----------|-------------|
| `-TenantId` | Specify a tenant ID for multi-tenant scenarios |
| `-UseDeviceCode` | Use device code authentication flow |

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
