# PowerShell

A collection of PowerShell scripts, examples, and utilities for common administration and automation tasks.

## Overview

This repository contains PowerShell resources organized by technology area. The scripts are intended to help with day-to-day administration, automation, reporting, and configuration tasks across Microsoft and Windows environments.

## Repository Structure

- `AD/` - Scripts and resources related to Active Directory administration.
- `AzureAD/` - Scripts and resources for Azure Active Directory / Microsoft Entra ID scenarios.
- `DocTag2AIP Migration/` - Resources related to document tagging and Azure Information Protection migration tasks.
- `Intune/` - Scripts and utilities for Microsoft Intune management.
- `Office365/` - Scripts for Microsoft 365 and Office 365 administration.
- `Windows/` - Windows administration and automation scripts.
- `infra/` - Infrastructure-related automation resources.

## Requirements

Requirements may vary by script. In general, you may need:

- PowerShell 5.1 or PowerShell 7+
- Appropriate PowerShell modules for the target service
- Administrative permissions for the environment being managed
- Network access to the relevant Microsoft cloud or on-premises services

Before running any script, review its contents and confirm the required permissions, modules, and parameters.

## Usage

1. Clone the repository:

   ```powershell
   git clone https://github.com/luberan/PowerShell.git
   ```

2. Open the relevant folder for your scenario.
3. Review the script before execution.
4. Run the script in a test environment first whenever possible.

Example:

```powershell
cd PowerShell
Get-ChildItem -Recurse -Filter *.ps1
```

## Notes

- Scripts are provided as general examples and may need to be adapted for your environment.
- Always validate scripts in a non-production environment before using them in production.
- Use appropriate change management and backup procedures when modifying systems or cloud services.

## Contributing

Contributions, improvements, and suggestions are welcome. When adding scripts, please include clear naming, comments, and any required usage notes.

## License

No license information is currently provided. Before reusing or redistributing content from this repository, confirm the applicable permissions with the repository owner.
