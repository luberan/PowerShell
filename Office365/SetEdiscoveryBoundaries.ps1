# Connect to Security & Compliance Center
$UserCredential = Get-Credential
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.compliance.protection.outlook.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection

# Create new roles
$RoleGroup = Get-RoleGroup "eDiscovery Managers"; New-RoleGroup "Local Compliance Managers - Czech" -Roles $RoleGroup.Roles -Members Lukas, Martin
$RoleGroup = Get-RoleGroup "eDiscovery Managers"; New-RoleGroup "Local Compliance Managers - USA" -Roles $RoleGroup.Roles -Members John, Freddie
$RoleGroup = Get-RoleGroup "eDiscovery Managers"; New-RoleGroup "Local Compliance Managers - Denmark" -Roles $RoleGroup.Roles -Members Abel, Knud

# Connect to Exchange Online
$UserCredential = Get-Credential
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection

# Create new role group
New-RoleGroup -Name "Local Compliance Managers" -Roles "Mailbox Search", "Legal Hold" -Members Lukas, Martin, John, Freddie, Abel, Knud

# Create new compliance filter
New-ComplianceSecurityFilter -FilterName "Local Compliance Managers Czech Filter" -Users "Local Compliance Managers - Czech" -Filters "Mailbox_CustomAttribute8 -eq 'czech'" -Action ALL
New-ComplianceSecurityFilter -FilterName "Local Compliance Managers USA Filter" -Users "Local Compliance Managers - USA" -Filters "Mailbox_CustomAttribute8 -eq 'usa'" -Action ALL
New-ComplianceSecurityFilter -FilterName "Local Compliance Managers Denmark Filter" -Users "Local Compliance Managers - Denmark" -Filters "Mailbox_CustomAttribute8 -eq 'denmark'" -Action ALL
