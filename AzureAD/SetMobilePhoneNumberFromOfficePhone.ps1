$users = (Get-MsolUser -All).UserPrincipalName
foreach ($uzivatel in $users) {
    $cislo = (Get-MsolUser -UserPrincipalName $uzivatel).PhoneNumber
    $mobil = "+420 " + $cislo
    Set-MsolUser -UserPrincipalName $uzivatel -MobilePhone $mobil
}
