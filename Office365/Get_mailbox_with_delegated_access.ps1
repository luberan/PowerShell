Get-Mailbox -RecipientType 'UserMailbox' -ResultSize Unlimited | Get-MailboxPermission | where {$_.user.tostring() -ne "NT AUTHORITY\SELF" -and $_.IsInherited -eq $false}
