<#
.SYNOPSIS
    Auditoria e instalacion de software multimedia.
.DESCRIPTION
    Audita el estado de cada aplicacion multimedia antes de actuar. Presenta
    un submenu interactivo donde el tecnico selecciona que instalar o actualizar.
    Permite instalar multiples aplicaciones en secuencia antes de finalizar.
    Genera un reporte con el estado previo y final de cada componente.
.NOTES
    Version : 1.1.0
    Proyecto: Windows Setup Toolkit
#>

#region PARAMETROS

param(
    [string]$LogDir = "$PSScriptRoot\..\logs",
    [switch]$NoElevation
)

#endregion

#region IMPORTS

. "$PSScriptRoot\..\lib\Utils.ps1"

#endregion

#region AUTO-ELEVACION

if (-not $NoElevation) {
    Invoke-Elevate -ScriptPath $PSCommandPath -Parameters $PSBoundParameters
}

#endregion

#region INICIALIZACION

$envInfo = Initialize-Environment -LogDir $LogDir -ModuleName "multimedia"
$LogFile = $envInfo.LogFile

#endregion

#region VERIFICACION DE DEPENDENCIAS

Write-Section "VERIFICACION DE DEPENDENCIAS" -LogFile $LogFile
Write-Blank -LogFile $LogFile

if (-not (Test-Winget)) {
    Write-Log "winget no encontrado. Requiere Windows 10 1809 o superior." -Level ERROR -LogFile $LogFile
    Write-Log "Descargalo desde: https://aka.ms/getwinget" -Level WARNING -LogFile $LogFile
    Write-Blank -LogFile $LogFile
    Invoke-Pause
    exit 1
}

Write-Log "winget disponible." -Level SUCCESS -LogFile $LogFile

if (-not (Test-InternetConnection)) {
    Write-Log "Sin conexion a internet. Este modulo requiere conexion activa." -Level ERROR -LogFile $LogFile
    Write-Blank -LogFile $LogFile
    Invoke-Pause
    exit 1
}

Write-Log "Conexion a internet verificada." -Level SUCCESS -LogFile $LogFile
Write-Blank -LogFile $LogFile

#endregion

#region CATALOGO DE MULTIMEDIA

# DaVinci Resolve se excluye: pesa ~3 GB y requiere descarga manual
# desde https://www.blackmagicdesign.com/products/davinciresolve
$multimedia = @(
    [PSCustomObject]@{ Id = "VideoLAN.VLC";        Nombre = "VLC";       Estado = "UNKNOWN"; Version = "" }
    [PSCustomObject]@{ Id = "Spotify.Spotify";     Nombre = "Spotify";   Estado = "UNKNOWN"; Version = "" }
    [PSCustomObject]@{ Id = "OBSProject.OBSStudio"; Nombre = "OBS Studio"; Estado = "UNKNOWN"; Version = "" }
)

#endregion

#region FUNCIONES DEL MODULO

function Get-VersionInstalada {
    param([string]$PackageId)

    $resultado = winget list --id $PackageId --exact --accept-source-agreements 2>&1

    $headerLine = $resultado | Where-Object { $_ -match "^Nombre\s+Id\s+" }
    if (-not $headerLine) { return "" }

    $versionIndex = $headerLine.IndexOf("Versi")
    if ($versionIndex -lt 0) { return "" }

    $linea = $resultado | Where-Object { $_ -match [regex]::Escape($PackageId) } | Select-Object -First 1
    if (-not $linea -or $linea.Length -le $versionIndex) { return "" }

    $resto   = $linea.Substring($versionIndex).Trim()
    $version = ($resto -split '\s+')[0]
    return $version
}

function Invoke-Auditoria {
    Write-Section "AUDITORIA DE MULTIMEDIA" -LogFile $LogFile
    Write-Blank -LogFile $LogFile
    Write-Log "Verificando estado de aplicaciones multimedia..." -LogFile $LogFile
    Write-Blank -LogFile $LogFile

    foreach ($app in $multimedia) {
        $app.Estado  = Get-WingetPackageStatus -PackageId $app.Id
        $app.Version = if ($app.Estado -ne "MISSING") { Get-VersionInstalada -PackageId $app.Id } else { "" }

        $label = switch ($app.Estado) {
            "INSTALLED" { "{0} (INSTALLED - {1})" -f $app.Nombre, $app.Version }
            "OUTDATED"  { "{0} (OUTDATED  - {1})" -f $app.Nombre, $app.Version }
            "MISSING"   { "{0} (MISSING)"          -f $app.Nombre }
            "UNKNOWN"   { "{0} (UNKNOWN)"           -f $app.Nombre }
        }

        $tag   = Get-CenteredTag -Text $app.Estado -TotalWidth 11
        $level = if ($app.Estado -eq "INSTALLED") { "SUCCESS" } else { "WARNING" }
        Write-Log "$tag $label" -Level $level -LogFile $LogFile
    }

    Write-Blank -LogFile $LogFile
}

function Show-Submenu {
    Clear-Host
    Write-Host ""
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host "           MULTIMEDIA"                     -ForegroundColor White
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host ""

    $opciones = @{}
    $contador = 1
    $tagOK = Get-CenteredTag -Text "OK" -TotalWidth 2

    foreach ($app in $multimedia) {
        switch ($app.Estado) {
            "INSTALLED" {
                Write-Host ("   $tagOK {0,-12} INSTALLED - {1}" -f $app.Nombre, $app.Version) -ForegroundColor Green
            }
            "OUTDATED" {
                $tag = Get-CenteredTag -Text "$contador" -TotalWidth 2
                Write-Host ("   $tag {0,-12} OUTDATED  - {1}" -f $app.Nombre, $app.Version) -ForegroundColor Yellow
                $opciones[$contador.ToString()] = $app
                $contador++
            }
            "MISSING" {
                $tag = Get-CenteredTag -Text "$contador" -TotalWidth 2
                Write-Host ("   $tag {0,-12} MISSING" -f $app.Nombre) -ForegroundColor Gray
                $opciones[$contador.ToString()] = $app
                $contador++
            }
            "UNKNOWN" {
                $tag = Get-CenteredTag -Text "$contador" -TotalWidth 2
                Write-Host ("   $tag {0,-12} UNKNOWN" -f $app.Nombre) -ForegroundColor DarkYellow
                $opciones[$contador.ToString()] = $app
                $contador++
            }
        }
    }

    Write-Host ""
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host "   [0] Finalizar"                          -ForegroundColor DarkGray
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host ""

    return $opciones
}

function Invoke-InstalarApp {
    param($App)

    $accion = if ($App.Estado -eq "OUTDATED") { "upgrade" } else { "install" }
    $verbo  = if ($accion -eq "upgrade") { "Actualizando" } else { "Instalando" }

    Write-Blank -LogFile $LogFile
    Write-Log "$verbo`: $($App.Nombre)" -LogFile $LogFile

    if ($accion -eq "upgrade") {
        winget upgrade --id $App.Id --accept-package-agreements --accept-source-agreements
    } else {
        winget install --id $App.Id --accept-package-agreements --accept-source-agreements
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Log "OK: $($App.Nombre)" -Level SUCCESS -LogFile $LogFile
        $App.Estado  = "INSTALLED"
        $App.Version = Get-VersionInstalada -PackageId $App.Id
        return $true
    } else {
        Write-Log "Error (codigo $LASTEXITCODE): $($App.Nombre)" -Level ERROR -LogFile $LogFile
        return $false
    }
}

#endregion

#region AUDITORIA INICIAL

Invoke-Auditoria

$estadoPrevio = @{}
foreach ($app in $multimedia) {
    $estadoPrevio[$app.Id] = $app.Estado
}

#endregion

#region LOOP DE SELECCION E INSTALACION

$resultados = @()

do {
    $opciones = Show-Submenu

    if ($opciones.Count -eq 0) {
        Write-Host "  Todas las aplicaciones estan instaladas y al dia." -ForegroundColor Green
        Write-Host ""
        Start-Sleep -Seconds 2
        break
    }

    $seleccion = Read-Host "   Elegir opcion"

    if ($seleccion -eq "0") { break }

    if (-not $opciones.ContainsKey($seleccion)) {
        Write-Host ""
        Write-Host "  Opcion invalida." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        continue
    }

    $appSeleccionada = $opciones[$seleccion]
    $exito = Invoke-InstalarApp -App $appSeleccionada

    $resultados += [PSCustomObject]@{
        Nombre = $appSeleccionada.Nombre
        Previo = $estadoPrevio[$appSeleccionada.Id]
        Final  = if ($exito) { "OK" } else { "ERROR" }
    }

    Start-Sleep -Seconds 1

} while ($true)

foreach ($app in $multimedia) {
    $yaRegistrado = $resultados | Where-Object { $_.Nombre -eq $app.Nombre }
    if (-not $yaRegistrado -and $estadoPrevio[$app.Id] -eq "INSTALLED") {
        $resultados += [PSCustomObject]@{
            Nombre = $app.Nombre
            Previo = "INSTALLED"
            Final  = "OK"
        }
    }
}

#endregion

#region REPORTE FINAL

Clear-Host
Write-Section "REPORTE DE MULTIMEDIA" -LogFile $LogFile
Write-Blank -LogFile $LogFile

Write-Log "--- Estado final ---" -LogFile $LogFile
Write-Blank -LogFile $LogFile

foreach ($app in $multimedia) {
    $estadoFinal = Get-WingetPackageStatus -PackageId $app.Id
    $version     = if ($estadoFinal -ne "MISSING") { Get-VersionInstalada -PackageId $app.Id } else { "" }

    $label = switch ($estadoFinal) {
        "INSTALLED" { "{0} (INSTALLED - {1})" -f $app.Nombre, $version }
        "OUTDATED"  { "{0} (OUTDATED  - {1})" -f $app.Nombre, $version }
        "MISSING"   { "{0} (MISSING)"          -f $app.Nombre }
        "UNKNOWN"   { "{0} (UNKNOWN)"           -f $app.Nombre }
    }

    $tag   = Get-CenteredTag -Text $estadoFinal -TotalWidth 11
    $level = if ($estadoFinal -eq "INSTALLED") { "SUCCESS" } else { "WARNING" }
    Write-Log "$tag $label" -Level $level -LogFile $LogFile
}

Write-Blank -LogFile $LogFile
Write-Log "--- Acciones realizadas ---" -LogFile $LogFile
Write-Blank -LogFile $LogFile

$acciones = $resultados | Where-Object { $_.Previo -ne "INSTALLED" }

if ($acciones.Count -eq 0) {
    Write-Log "No se realizaron cambios." -LogFile $LogFile
} else {
    foreach ($r in $acciones) {
        $tag   = Get-CenteredTag -Text $r.Final -TotalWidth 7
        $linea = "  $tag $($r.Nombre) (era: $($r.Previo))"
        switch ($r.Final) {
            "OK"    { Write-Log $linea -Level SUCCESS -LogFile $LogFile }
            "ERROR" { Write-Log $linea -Level ERROR   -LogFile $LogFile }
        }
    }
}

Write-Blank -LogFile $LogFile
Write-Section -LogFile $LogFile
Write-Log "Log guardado en: $LogFile" -LogFile $LogFile
Write-Blank

Invoke-Pause

#endregion