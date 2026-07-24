$path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
$name = 'DisableWpad'
try {
    $value = Get-ItemPropertyValue `
        -Path $path `
        -Name $name `
        -ErrorAction Stop
    if ($value -eq 1) {
        Write-Output 'Compliant: DisableWpad is set to 1.'
        exit 0
    }
    Write-Output "Not compliant: DisableWpad is set to '$value'."
    exit 1
}
catch {
    Write-Output 'Not compliant: DisableWpad is missing or cannot be read.'
    exit 1
}
