Connect-MsolService

$st = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
$st.RelyingParty = "*"
$st.State = "Enabled"
$sta = @($st)

Get-MsolGroupMember -GroupObjectId 2587bebc-7e31-46fd-ab3d-9e3e7e40de93 | Set-MsolUser -StrongAuthenticationRequirements $sta
