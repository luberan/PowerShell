$path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp'
try {
    if (-not (Test-Path -Path $path)) {
        New-Item -Path $path -Force -ErrorAction Stop | Out-Null
    }
    New-ItemProperty `
        -Path $path `
        -Name 'DisableWpad' `
        -PropertyType DWord `
        -Value 1 `
        -Force `
        -ErrorAction Stop | Out-Null
    Write-Output 'DisableWpad is configured as DWORD 1.'
    exit 0
}
catch {
    Write-Error "Failed to configure DisableWpad: $($_.Exception.Message)"
    exit 1
}
