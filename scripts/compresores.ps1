<#
.SYNOPSIS
    Auditoria e instalacion de compresores.
.DESCRIPTION
    Audita el estado de cada compresor antes de actuar. Presenta un submenu
    interactivo donde el tecnico selecciona que instalar o actualizar.
    Permite instalar multiples compresores en secuencia antes de finalizar.
    Genera un reporte con el estado previo y final de cada componente.
.NOTES
    Version : 1.0.0
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

$envInfo = Initialize-Environment -LogDir $LogDir -ModuleName "compresores"
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

#region CATALOGO DE COMPRESORES

$compresores = @(
    [PSCustomObject]@{ Id = "7zip.7zip";         Nombre = "7-Zip";   Estado = "UNKNOWN"; Version = "" }
    [PSCustomObject]@{ Id = "RARLab.WinRAR";     Nombre = "WinRAR";  Estado = "UNKNOWN"; Version = "" }
    [PSCustomObject]@{ Id = "M2Team.NanaZip";    Nombre = "NanaZip"; Estado = "UNKNOWN"; Version = "" }
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
    Write-Section "AUDITORIA DE COMPRESORES" -LogFile $LogFile
    Write-Blank -LogFile $LogFile
    Write-Log "Verificando estado de compresores instalados..." -LogFile $LogFile
    Write-Blank -LogFile $LogFile

    foreach ($comp in $compresores) {
        $comp.Estado  = Get-WingetPackageStatus -PackageId $comp.Id
        $comp.Version = if ($comp.Estado -ne "MISSING") { Get-VersionInstalada -PackageId $comp.Id } else { "" }

        $label = switch ($comp.Estado) {
            "INSTALLED" { "{0} (INSTALLED - {1})" -f $comp.Nombre, $comp.Version }
            "OUTDATED"  { "{0} (OUTDATED  - {1})" -f $comp.Nombre, $comp.Version }
            "MISSING"   { "{0} (MISSING)"          -f $comp.Nombre }
            "UNKNOWN"   { "{0} (UNKNOWN)"           -f $comp.Nombre }
        }

        switch ($comp.Estado) {
            "INSTALLED" { Write-Log "[INSTALLED] $label" -Level SUCCESS -LogFile $LogFile }
            "OUTDATED"  { Write-Log "[OUTDATED]  $label" -Level WARNING -LogFile $LogFile }
            "MISSING"   { Write-Log "[MISSING]   $label" -Level WARNING -LogFile $LogFile }
            "UNKNOWN"   { Write-Log "[UNKNOWN]   $label" -Level WARNING -LogFile $LogFile }
        }
    }

    Write-Blank -LogFile $LogFile
}

function Show-Submenu {
    Clear-Host
    Write-Host ""
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host "           COMPRESORES"                    -ForegroundColor White
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host ""

    $opciones = @{}
    $contador = 1

    foreach ($comp in $compresores) {
        switch ($comp.Estado) {
            "INSTALLED" {
                Write-Host ("   [OK] {0,-10} INSTALLED - {1}" -f $comp.Nombre, $comp.Version) -ForegroundColor Green
            }
            "OUTDATED" {
                Write-Host ("   [{0}] {1,-10} OUTDATED  - {2}" -f $contador, $comp.Nombre, $comp.Version) -ForegroundColor Yellow
                $opciones[$contador.ToString()] = $comp
                $contador++
            }
            "MISSING" {
                Write-Host ("   [{0}] {1,-10} MISSING" -f $contador, $comp.Nombre) -ForegroundColor Gray
                $opciones[$contador.ToString()] = $comp
                $contador++
            }
            "UNKNOWN" {
                Write-Host ("   [{0}] {1,-10} UNKNOWN" -f $contador, $comp.Nombre) -ForegroundColor DarkYellow
                $opciones[$contador.ToString()] = $comp
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

function Invoke-InstalarCompresor {
    param($Compresor)

    $accion = if ($Compresor.Estado -eq "OUTDATED") { "upgrade" } else { "install" }
    $verbo  = if ($accion -eq "upgrade") { "Actualizando" } else { "Instalando" }

    Write-Blank -LogFile $LogFile
    Write-Log "$verbo`: $($Compresor.Nombre)" -LogFile $LogFile

    if ($accion -eq "upgrade") {
        winget upgrade --id $Compresor.Id --accept-package-agreements --accept-source-agreements
    } else {
        winget install --id $Compresor.Id --accept-package-agreements --accept-source-agreements
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Log "OK: $($Compresor.Nombre)" -Level SUCCESS -LogFile $LogFile
        $Compresor.Estado  = "INSTALLED"
        $Compresor.Version = Get-VersionInstalada -PackageId $Compresor.Id
        return $true
    } else {
        Write-Log "Error (codigo $LASTEXITCODE): $($Compresor.Nombre)" -Level ERROR -LogFile $LogFile
        return $false
    }
}

#endregion

#region AUDITORIA INICIAL

Invoke-Auditoria

$estadoPrevio = @{}
foreach ($comp in $compresores) {
    $estadoPrevio[$comp.Id] = $comp.Estado
}

#endregion

#region LOOP DE SELECCION E INSTALACION

$resultados = @()

do {
    $opciones = Show-Submenu

    if ($opciones.Count -eq 0) {
        Write-Host "  Todos los compresores estan instalados y al dia." -ForegroundColor Green
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

    $compSeleccionado = $opciones[$seleccion]
    $exito = Invoke-InstalarCompresor -Compresor $compSeleccionado

    $resultados += [PSCustomObject]@{
        Nombre = $compSeleccionado.Nombre
        Previo = $estadoPrevio[$compSeleccionado.Id]
        Final  = if ($exito) { "OK" } else { "ERROR" }
    }

    Start-Sleep -Seconds 1

} while ($true)

foreach ($comp in $compresores) {
    $yaRegistrado = $resultados | Where-Object { $_.Nombre -eq $comp.Nombre }
    if (-not $yaRegistrado -and $estadoPrevio[$comp.Id] -eq "INSTALLED") {
        $resultados += [PSCustomObject]@{
            Nombre = $comp.Nombre
            Previo = "INSTALLED"
            Final  = "OK"
        }
    }
}

#endregion

#region REPORTE FINAL

Clear-Host
Write-Section "REPORTE DE COMPRESORES" -LogFile $LogFile
Write-Blank -LogFile $LogFile

Write-Log "--- Estado final ---" -LogFile $LogFile
Write-Blank -LogFile $LogFile

foreach ($comp in $compresores) {
    $estadoFinal = Get-WingetPackageStatus -PackageId $comp.Id
    $version     = if ($estadoFinal -ne "MISSING") { Get-VersionInstalada -PackageId $comp.Id } else { "" }

    $label = switch ($estadoFinal) {
        "INSTALLED" { "{0} (INSTALLED - {1})" -f $comp.Nombre, $version }
        "OUTDATED"  { "{0} (OUTDATED  - {1})" -f $comp.Nombre, $version }
        "MISSING"   { "{0} (MISSING)"          -f $comp.Nombre }
        "UNKNOWN"   { "{0} (UNKNOWN)"           -f $comp.Nombre }
    }

    switch ($estadoFinal) {
        "INSTALLED" { Write-Log "[INSTALLED] $label" -Level SUCCESS -LogFile $LogFile }
        "OUTDATED"  { Write-Log "[OUTDATED]  $label" -Level WARNING -LogFile $LogFile }
        "MISSING"   { Write-Log "[MISSING]   $label" -Level WARNING -LogFile $LogFile }
        "UNKNOWN"   { Write-Log "[UNKNOWN]   $label" -Level WARNING -LogFile $LogFile }
    }
}

Write-Blank -LogFile $LogFile
Write-Log "--- Acciones realizadas ---" -LogFile $LogFile
Write-Blank -LogFile $LogFile

$acciones = $resultados | Where-Object { $_.Previo -ne "INSTALLED" }

if ($acciones.Count -eq 0) {
    Write-Log "No se realizaron cambios." -LogFile $LogFile
} else {
    foreach ($r in $acciones) {
        $linea = "  [{0,-8}] {1} (era: {2})" -f $r.Final, $r.Nombre, $r.Previo
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