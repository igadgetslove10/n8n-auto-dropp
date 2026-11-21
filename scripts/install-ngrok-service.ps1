#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Instala ngrok como servicio nativo de Windows para el proyecto DROPP.

.DESCRIPTION
  - Detiene procesos ngrok lanzados a mano (evita sesiones duplicadas del mismo dominio).
  - Registra el servicio "ngrok" con `ngrok service install --config <ngrok.yml>`.
  - Inicio automatico retrasado (espera a que haya red).
  - Recuperacion ante fallos: reinicia a los 5 s, 15 s y 60 s; contador se resetea cada 24 h.
  - Verifica servicio, API local 4040, URL publica y acceso a n8n; prueba un reinicio del servicio.

  No contiene secretos: el authtoken lo lee ngrok desde ngrok.yml (perfil del usuario).
  Log de esta instalacion: %LOCALAPPDATA%\ngrok\install-service.log
  Log operativo del agente: %LOCALAPPDATA%\ngrok\ngrok-service.log (definido en ngrok.yml)

.NOTES
  Ejecutar en PowerShell como Administrador:
    powershell -ExecutionPolicy Bypass -File ".\scripts\install-ngrok-service.ps1"
  Desinstalar:
    ngrok service stop; ngrok service uninstall
#>

$ErrorActionPreference = 'Stop'
$UserProfileDir = 'C:\Users\ceehv'
$NgrokExe  = Join-Path $UserProfileDir 'AppData\Local\Microsoft\WinGet\Packages\Ngrok.Ngrok_Microsoft.Winget.Source_8wekyb3d8bbwe\ngrok.exe'
$NgrokCfg  = Join-Path $UserProfileDir 'AppData\Local\ngrok\ngrok.yml'
$InstallLog = Join-Path $UserProfileDir 'AppData\Local\ngrok\install-service.log'
$PublicUrl = 'https://footing-cradling-human.ngrok-free.dev'

Start-Transcript -Path $InstallLog -Append | Out-Null
try {
    if (-not (Test-Path $NgrokExe)) { throw "No se encontro ngrok.exe en $NgrokExe" }
    if (-not (Test-Path $NgrokCfg)) { throw "No se encontro ngrok.yml en $NgrokCfg" }

    & $NgrokExe config check --config $NgrokCfg
    if ($LASTEXITCODE -ne 0) { throw 'ngrok.yml invalido' }

    $existing = Get-Service -Name ngrok -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Servicio ngrok ya existe (Status=$($existing.Status)). Se reutiliza, no se duplica."
    } else {
        # Detener procesos ngrok manuales para no duplicar la sesion del dominio
        Get-Process ngrok -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "Deteniendo ngrok manual PID $($_.Id)"
            Stop-Process -Id $_.Id -Force -Confirm:$false
        }
        Start-Sleep -Seconds 2
        & $NgrokExe service install --config $NgrokCfg
        if ($LASTEXITCODE -ne 0) { throw 'ngrok service install fallo' }
    }

    # Inicio automatico retrasado + recuperacion ante fallos
    sc.exe config ngrok start= delayed-auto | Out-Host
    sc.exe failure ngrok reset= 86400 actions= restart/5000/restart/15000/restart/60000 | Out-Host
    sc.exe failureflag ngrok 1 | Out-Host
    sc.exe description ngrok "DROPP: tunel ngrok publico hacia n8n (localhost:5678)" | Out-Host

    if ((Get-Service ngrok).Status -ne 'Running') { & $NgrokExe service start }

    function Test-Tunnel {
        for ($i = 0; $i -lt 30; $i++) {
            try {
                $t = Invoke-RestMethod -Uri 'http://127.0.0.1:4040/api/tunnels' -TimeoutSec 3
                if ($t.tunnels.public_url) { break }
            } catch {}
            Start-Sleep -Seconds 1
        }
        $svc = Get-Service ngrok
        $wmi = Get-CimInstance Win32_Service -Filter "Name='ngrok'"
        Write-Host "Servicio: Status=$($svc.Status) StartType=$($wmi.StartMode) DelayedAutoStart=$($wmi.DelayedAutoStart) Cuenta=$($wmi.StartName)"
        Write-Host "Procesos ngrok: $((Get-Process ngrok -ErrorAction SilentlyContinue | Measure-Object).Count)"
        Write-Host "URL publica: $($t.tunnels.public_url) -> $($t.tunnels.config.addr)"
        try {
            $r = Invoke-WebRequest -Uri "$PublicUrl/healthz" -Headers @{ 'ngrok-skip-browser-warning' = '1' } -UseBasicParsing -TimeoutSec 15
            Write-Host "Tunel -> n8n /healthz: HTTP $($r.StatusCode)"
        } catch { Write-Warning "Tunel -> n8n /healthz fallo: $($_.Exception.Message)" }
    }

    Write-Host '=== Verificacion inicial ==='
    Test-Tunnel
    Write-Host '=== Prueba de recuperacion: reinicio del servicio ==='
    Restart-Service ngrok -Force
    Test-Tunnel
    Write-Host 'Instalacion completada.'
}
finally {
    Stop-Transcript | Out-Null
}
