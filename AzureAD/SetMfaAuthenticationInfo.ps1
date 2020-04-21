$upn = "LynneR@lukasbpfe.eu"
	
$method1 = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationMethod
$method1.IsDefault = $true
$method1.MethodType = "OneWaySMS"
	
$method2 = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationMethod
$method2.IsDefault = $false
$method2.MethodType = "TwoWayVoiceMobile"
$methods = @($method1, $method2)
	
Set-MsolUser -UserPrincipalName $upn -StrongAuthenticationMethods $methods
