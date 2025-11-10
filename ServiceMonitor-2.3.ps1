param(
  [string]$Vendor = 'VENDOR'
)

$MaxAttempts       = 3
$RetryDelaySeconds = 2
$ExitCode          = 0
$FailedServices    = @()
$RestartedCount    = 0

$StaticExcluded = @(
  'TrustedInstaller','gupdate','edgeupdate','gpsvc',
  'AMD Log Utility','GoogleUpdaterService','GoogleUpdaterInternalService'
)

$RegPath = "HKLM:\SOFTWARE\$Vendor\Exceptions\General\StoppedServices"

function Get-DynamicExcluded([string]$Path){
  $list=@()
  if (Test-Path $Path){
    $props=(Get-ItemProperty -Path $Path).PSObject.Properties |
           Where-Object { $_.Name -notmatch '^PS' }
    foreach($p in $props){
      if ($p.Value) { $list += [string]$p.Value } else { $list += [string]$p.Name }
    }
  }
  return $list
}

function Test-Excluded($svc, $static, $dynamic){
  if ($static  -contains $svc.Name -or $static  -contains $svc.DisplayName) { return 'statischer' }
  if ($dynamic -contains $svc.Name -or $dynamic -contains $svc.DisplayName) { return 'dynamischer' }
  return ''
}

$DynamicExcluded = Get-DynamicExcluded -Path $RegPath

$services = Get-Service | Where-Object { $_.StartType -eq 'Automatic' } | Sort-Object Name
$TotalChecked = $services.Count
$ExcludedStaticTotal=0
$ExcludedDynamicTotal=0

foreach($s in $services){
  $svc = Get-Service -Name $s.Name -ErrorAction Stop

  $reason = Test-Excluded -svc $svc -static $StaticExcluded -dynamic $DynamicExcluded
  if ($reason -ne ''){
    Write-Host ("[SKIP] Dienst '{0}' wurde mittels {1} Ausnahme ausgeschlossen." -f $svc.Name,$reason)
    if ($reason -eq 'statischer'){ $ExcludedStaticTotal++ } else { $ExcludedDynamicTotal++ }
    continue
  }

  if ($svc.Status -eq 'Running'){ Write-Host ("[OK] Dienst '{0}' laeuft bereits." -f $svc.Name); continue }

  Write-Host ("[INFO] Dienst '{0}' laeuft nicht. Starte neu..." -f $svc.Name)
  $ok=$false
  for ($attempt=1; $attempt -le $MaxAttempts -and -not $ok; $attempt++){
    try{
      Start-Service -Name $svc.Name -ErrorAction Stop
      Start-Sleep -Seconds $RetryDelaySeconds
      $svc = Get-Service -Name $svc.Name -ErrorAction Stop
      if ($svc.Status -eq 'Running'){
        Write-Host ("[OK] Versuch {0}: erfolgreich (Dienst laeuft)." -f $attempt)
        $ok=$true
        $RestartedCount++
      } else {
        Write-Host ("[WARN] Versuch {0}: noch nicht gestartet (Status={1})." -f $attempt,$svc.Status)
      }
    } catch {
      Write-Host ("[ERROR] Versuch {0} fehlgeschlagen: {1}" -f $attempt, $_.Exception.Message)
      Start-Sleep -Seconds $RetryDelaySeconds
    }
  }

  if (-not $ok){
    Write-Host ("[FAIL] Dienst '{0}' konnte nicht gestartet werden." -f $svc.Name)
    $ExitCode=1
    $FailedServices += $svc.Name
  }
}

if ($FailedServices.Count -gt 0){
  Write-Host ""
  Write-Host "=== Zusammenfassung (Fehlgeschlagene Dienste) ==="
  foreach($f in $FailedServices){ Write-Host ("[FAIL] Dienst '{0}' konnte nicht gestartet werden." -f $f) }
  Write-Host "==========================================="
}

$Summary = ("{0} automatische Dienste, {1} statisch ausgeschlossen, {2} dynamisch ausgeschlossen, {3} neu gestartet, {4} fehlgeschlagen, Exit={5}" -f `
  $TotalChecked,$ExcludedStaticTotal,$ExcludedDynamicTotal,$RestartedCount,$FailedServices.Count,$ExitCode)
if ($Summary.Length -gt 200){ $Summary = $Summary.Substring(0,200) }

Write-Host "<-Start Result ->"
Write-Host (" Status ={0}" -f $Summary)
Write-Host "<-End Result ->"

Exit $ExitCode
