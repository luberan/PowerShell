# This script removes all disabled AD accounts from a specified AD group.
# Useful for AAD Group Based licensing so disabled accounts will be removed from licensed users in AAD/Office 365

$group = "Group Name"
$members = Get-AdGroupMember "$group"

foreach ($member in $members) {
    $user = Get-ADUser "$member"
    if ($user.Enabled -ne $true) {
        Remove-AdGroupMember "$group" "$member"
    }
}
