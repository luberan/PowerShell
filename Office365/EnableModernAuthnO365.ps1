# Connect to Exchange Online
$UserCredential = Get-Credential
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
Import-PSSession $Session

# Enable modern authentication for Exchange Online
Set-OrganizationConfig -OAuth2ClientProfileEnabled $true

# Disconnect from EXO Management Shell
Remove-PSSession $Session

# Connect to Skype for Business Online
$credential = Get-Credential
$session = New-CsOnlineSession -Credential $credential -Verbose
Import-PSSession $session

# Enable modern authentication for Skype for Business Online
Set-CsOAuthConfiguration -ClientAdalAuthOverride Allowed

# Disconnet from Skype for Business Online shell
Remove-PSSession $session
