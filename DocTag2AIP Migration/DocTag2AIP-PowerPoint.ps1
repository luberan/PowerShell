$ErrorActionPreference = 'Stop'

# Vytvarim adresar, do ktereho budu ukladat logy
New-Item -ItemType Directory -Force -Path C:\reklasifikace

# Zobrazim uzivateli okno, ze klasifikace dokumentu zacina + ulozim informaci o zacatku klasifikace do logu
msg * "Reklasifikace PowerPoint dokumentů začala."
$time=Get-Date
"$time Reklasifikace PowerPoint dokumentů začala." | Out-File C:\reklasifikace\statusPowerPoint.txt -Append

# Otviram PowerPoint na pozadi
$powerpoint = New-Object -comobject PowerPoint.Application

# Nacitam vsechny soubory v danem adresari + vsech podadresarich krome systemovych adresaru
$files = @()
$folders = Get-ChildItem -Path C:\
foreach ($folder in $folders) {
    if (($folder.Name -ne "Program Files") -and ($folder.Name -ne "Program Files (x86)") -and ($folder.Name -ne "PerfLogs") -and ($folder.Name -ne "ProgramData") -and ($folder.Name -ne "Windows")) {
        Write-Host $folder
        Try {
            $files += Get-ChildItem -Path $folder.Fullname -Include @("*.ppt", "*.pptx") -Recurse
        }
        Catch {
            $time=Get-Date
            "$time $file $PSItem" | Out-File C:\reklasifikace\errorPowerPoint.txt -Append
        }
    }
}
if (Test-Path D:) {
    $files += Get-ChildItem -Path D:\ -Include @("*.ppt", "*.pptx") -Recurse
}

# Inicializace pocitadla souboru
$i = 1

# Prochazim vsechny nactene soubory
foreach ($file in $files) {
    $i++
    "$file" | Out-File C:\reklasifikace\statusPowerPoint.txt -Append
    
    # Vypisuji kazdy 500. soubor do logu - slouzi jako informace o stavu, ze skript stale bezi pripadne kdy a kde cca havaroval
    if ($i -eq 500) {
        $time=Get-Date
        "$time $file" | Out-File C:\reklasifikace\statusPowerPoint.txt -Append
        $i = 1
    }


    Try {

    # Testuji, jestli je soubor již oklasifikovany nebo chraneny - pokud ano, preskakuji ho
    $protected = Get-AIPFileStatus -Path $file.Fullname
    if (($protected.IsLabeled -eq $false) -and ($protected.IsRMSProtected -eq $false)) {

        # Nacitam properties dokumentu a ctu z nich informaci o DocTag klasifikaci, nactene hodnoty ukladam do labels
        $doc = $powerpoint.presentations.open("$file.Fullname",$False,$False,$False,"NeplatneHeslo","",$False,"","",$wdOpenFormat,$msoEncoding,$False,$False,$False)
        $labels = @()
        foreach($property in $doc.CustomDocumentProperties) {
            $vl = [System.__ComObject].InvokeMember('value',[System.Reflection.BindingFlags]::GetProperty,$null,$property,$null)
            switch ($vl){
                'PU - For Personal Usage' { $labels+='f74878b7-c0ff-44a4-82ff-8ce29f7fccb5' }
                'C1 - Vodafone External' { $labels+='c179f820-d535-4b2f-b252-8a9c4ac14ec6' }
                'C2 - Vodafone Internal' { $labels+='d9f23ae3-a239-45ea-bf23-f515f824c57b' }
                'C3 - Vodafone Confidential' { $labels+='9fbde396-1a24-4c79-8edf-9254a0f35055' }
                'C4 - Vodafone Secret' { $labels+='9fbde396-1a24-4c79-8edf-9254a0f35055' }
                default {}
            }
        }
        $doc.Close()

        # Prochazim labels a aplikuji AIP labely dle nactenych DocTag klasifikaci
        foreach($lbl in $labels) {
            Set-AIPFileLabel -Path $file.Fullname -LabelId $lbl -PreserveFileDetails | Out-File C:\reklasifikace\aipPowerPoint.txt
        }
        $doc = $powerpoint.presentations.open($file.Fullname)
        $doc.Save()
        $doc.Close()
        }
    }
    Catch {
        $time=Get-Date
        "$time $file $PSItem" | Out-File C:\reklasifikace\errorPowerPoint.txt -Append
    }
}
Try {
    $powerpoint.Quit()
}
Catch {
    $time=Get-Date
    "$time $file Soubor se nepodařilo uložit." | Out-File C:\reklasifikace\errorWord.txt -Append
}

# Zobrazim uzivateli informaci o dokonceni klasifikace a informaci zapisu i do logu
msg * "Reklasifikace PowerPoint dokumentů byla dokončena."
$time=Get-Date
"$time Reklasifikace PowerPoint dokumentů byla dokončena." | Out-File C:\reklasifikace\statusPowerPoint.txt -Append
