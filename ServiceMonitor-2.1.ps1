#2.1
$MaxAttempts       = 3
# Maximal 3 start versuche 
$RetryDelaySeconds = 2
# 2 sekunden pause zwischen den Versuhen
# Warum 2 Sekunden warten?: Manche Dienste brauchen Zeit, um auf Running zu gehen

$ExitCode       = 0
# exitcode 0 (erfolg); Bei fehler wird es 1
$FailedServices = @()
# Leere Liste für fehlgeschlagene Dienste 

$services = Get-Service | Where-Object { $_.StartType -eq 'Automatic' } | Sort-Object Name
# Holt ALLE Windows-Dienste als Objekte / mit | (pipe) weiterleitet 
# Where-Objekt {...} : Filtert die objekte 
# -eq ´Automatic´: Behalte nur Dienste mit Starttyp Automatic 
# Sort Objekt Name  : alphabetisch / sortiere nach name 
# ergebnis : $services enthält alle automatischen Dienste, alphabetisch   

foreach ($s in $services) {
    #Jeden Dienst nacheinader in $s bearbeiten / Der aktuelle Dienst heißt $s
    
    $serviceName = $s.Name
    # Speichere den Namen des Dienstes in $serviceName (Lesbarkeit)
    
    try {
        # fehler abfangen mit try/catch block
        $svc = Get-Service -Name $serviceName -ErrorAction Stop
        #  Hole den Dienst mit diesem Namen / Bei Fehler stoppen und catch ausführen
       
       if ($svc.Status -eq 'Running') {
            Write-Host ("[OK] Dienst '{0}' laeuft bereits." -f  $serviceName)
            continue
        }
           # Wenn der Dienst schon läuft, also der Status ist Running. 
           # Schreibe eine kurze Info auf den Bildschirm:
           # [OK] Dienst 'Name' läuft bereits
           #([OK] ist nur ein Text, kein Befehl Es zeigt: alles ist in Ordnung)

        Write-Host ("[INFO] Dienst '{0}' laeuft nicht. Starte neu..." -f  $serviceName)
          #{0} ist ein Platzhalter / -f -Name $serviceName bedeutet: Setze den Namen des Dienstes an die Stelle von {0}
          
        $ok = $false
          # Bis jetzt kein Erfolg / Später, wenn der Dienst startet, machen wir $ok = $true

        for ($attempt = 1; $attempt -le $MaxAttempts -and -not $ok; $attempt++) {
        #Start bei 1; solange $ok = false und $attempt ≤ $MaxAttempts, weiterlaufen und $attempt jedes Mal um 1 erhöhen

            try {
                Start-Service -Name $serviceName -ErrorAction Stop
                Start-Sleep -Seconds $RetryDelaySeconds

                $svc = Get-Service -Name $serviceName -ErrorAction Stop
                if ($svc.Status -eq 'Running') {
                    Write-Host ("[OK] Versuch {0}: erfolgreich (Dienst laeuft)." -f $attempt)
                    $ok = $true
                } else {
                    Write-Host ("[WARN] Versuch {0}: noch nicht gestartet (Status={1})." -f $attempt, $svc.Status)
                 # WARN: Warnung: Versuch gemacht, aber noch nicht Running
                 # WARN: Kein Fehler/Exception, aber Ergebnis noch nicht erreicht
                }
            } catch {
                Write-Host ("[ERROR] Versuch {0} fehlgeschlagen: {1}" -f $attempt, $_.Exception.Message)
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }

        if (-not $ok) {
            Write-Host ("[FAIL] Dienst '{0}' konnte nicht gestartet werden." -f  $serviceName)
            $ExitCode = 1
            $FailedServices += $serviceName
        }

    } catch {
        Write-Host ("[EXCEPTION] Unerwarteter Fehler bei Dienst '{0}': {1}" -f $serviceName, $_.Exception.Message)
        # Nur Unerwartete Fehler z. B. falscher Dienstname, keine Rechte
        $ExitCode = 1
        $FailedServices += $serviceName
        # 
    }
}

if ($FailedServices.Count -gt 0) {
        # count ist anzahl / Wenn die anzahl größer als 0 ist, führe den Block aus
    Write-Host "" # leere zeile 
    Write-Host "=== Zusammenfassung (Fehlgeschlagene Dienste) ==="
    foreach ($f in $FailedServices) {
        Write-Host ("[FAIL] Dienst '{0}' konnte nicht gestartet werden." -f $f)
    }
    Write-Host "==========================================="
}

if ($ExitCode -eq 0) {
    Write-Host "[END] Alle automatischen Dienste sind in Ordnung. (Exit 0)"
} else {
    Write-Host "[END] Mindestens ein Dienst konnte nicht gestartet werden. (Exit 1)"
}

Exit $ExitCode
