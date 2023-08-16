Start-Transcript -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\RemoveOneDrivePersonalIcon.log"
$OneDriverPersonalIcon = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -ErrorAction SilentlyContinue
If ($OneDriverPersonalIcon){
    try {
        Get-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" | Remove-Item -Force -Verbose
        Write-Output "Remove OneDrive Personal Icon"
    }
    catch {
        Write-Error "Error: $($_.Exception.Message)"
    }
}
else {
    Write-Output "OneDrive Personal Icon not found"
}
Stop-Transcript