# This script adds all users from a specified OU to a specified AD group
$users = Get-ADUser -SearchBase "OU=UsersComputers,DC=ad,DC=lukasbpfe,DC=eu" -Filter *
Add-ADGroupMember -Identity "CloudUsers" -Members $users
