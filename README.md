# Run Proactive Remediations On Demand

A PowerShell tool to trigger Intune Proactive Remediation scripts on demand. Supports single device mode or multi-device selection via a WPF GUI with pagination and search. Connects to Microsoft Graph using least-privileged permissions and provides real-time progress tracking for batch remediation operations.

## Features

- **Single Device Mode** - Run remediation on a specific device by name
- **Multi-Device Mode** - Select multiple devices via WPF GUI with:
  - Pagination for large device lists
  - Search/filter functionality
  - Checkbox selection with count display
  - Real-time progress tracking
- **Least-Privileged Permissions** - Uses only the minimum required Microsoft Graph scopes
- **Device Sync** - Automatically initiates device sync after triggering remediation

## Prerequisites

- PowerShell 5.1 or later
- Microsoft.Graph.Authentication module

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
.\RunRemediationOnDemand.ps1
```

You'll be prompted to choose between single device or multi-device mode.

### Single Device Mode

```powershell
.\RunRemediationOnDemand.ps1 -DeviceName "DESKTOP-ABC123"
```

### Multi-Device Mode

```powershell
.\RunRemediationOnDemand.ps1 -MultiDevice
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

## Screenshots

### Mode Selection
```
========================================
  SELECT EXECUTION MODE
========================================

  [1] Single Device  - Run remediation on one device
  [2] Multi-Device   - Select multiple devices via GUI
```

### Multi-Device WPF GUI
- Device grid with pagination
- Search functionality
- Checkbox selection
- Progress tracking window

## License

MIT License
