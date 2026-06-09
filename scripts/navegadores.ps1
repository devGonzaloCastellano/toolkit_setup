<#
.SYNOPSIS
    Auditoria e instalacion de navegadores web.
.DESCRIPTION
    Audita el estado de cada navegador antes de actuar. Presenta un submenu
    interactivo donde el tecnico selecciona que instalar o actualizar.
    Permite instalar multiples navegadores en secuencia antes de finalizar.
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

$envInfo = Initialize-Environment -LogDir $LogDir -ModuleName "navegadores"
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

#region CATALOGO DE NAVEGADORES

$navegadores = @(
    [PSCustomObject]@{ Id = "Google.Chrome";   IdAlt = "Google.Chrome.EXE"; Nombre = "Chrome";  Estado = "UNKNOWN"; Version = "" }
    [PSCustomObject]@{ Id = "Brave.Brave";      IdAlt = "";                  Nombre = "Brave";   Estado = "UNKNOWN"; Version = "" }
    [PSCustomObject]@{ Id = "Mozilla.Firefox";  IdAlt = "";                  Nombre = "Firefox"; Estado = "UNKNOWN"; Version = "" }
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

    $resto    = $linea.Substring($versionIndex).Trim()
    $version  = ($resto -split '\s+')[0]
    return $version
}

function Invoke-Auditoria {
    Write-Section "AUDITORIA DE NAVEGADORES" -LogFile $LogFile
    Write-Blank -LogFile $LogFile
    Write-Log "Verificando estado de navegadores instalados..." -LogFile $LogFile
    Write-Blank -LogFile $LogFile

    $tagInstalado = Get-CenteredTag -Text "INSTALLED" -TotalWidth 11
    Write-Log "$tagInstalado Edge (INSTALLED) - $($edge.Version) [informativo]" -Level SUCCESS -LogFile $LogFile

    foreach ($nav in $navegadores) {
        $nav.Estado = Get-WingetPackageStatus -PackageId $nav.Id

        if ($nav.Estado -eq "MISSING" -and $nav.IdAlt -ne "") {
            $estadoAlt = Get-WingetPackageStatus -PackageId $nav.IdAlt
            if ($estadoAlt -ne "MISSING") { $nav.Estado = $estadoAlt }
        }

        $nav.Version = if ($nav.Estado -ne "MISSING") { Get-VersionInstalada -PackageId $nav.Id } else { "" }

        if ($nav.Version -eq "" -and $nav.IdAlt -ne "") {
            $nav.Version = Get-VersionInstalada -PackageId $nav.IdAlt
        }

        $label = switch ($nav.Estado) {
            "INSTALLED" { "{0} (INSTALLED) - {1}" -f $nav.Nombre, $nav.Version }
            "OUTDATED"  { "{0} (OUTDATED) - {1}"  -f $nav.Nombre, $nav.Version }
            "MISSING"   { "{0} (MISSING)"         -f $nav.Nombre }
            "UNKNOWN"   { "{0} (UNKNOWN)"         -f $nav.Nombre }
        }

        $tag   = Get-CenteredTag -Text $nav.Estado -TotalWidth 11
        $level = if ($nav.Estado -eq "INSTALLED") { "SUCCESS" } else { "WARNING" }
        Write-Log "$tag $label" -Level $level -LogFile $LogFile
    }

    Write-Blank -LogFile $LogFile
}

function Show-Submenu {
    Clear-Host
    Write-Host ""
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host "           NAVEGADORES"                    -ForegroundColor White
    Write-Host "  ========================================" -ForegroundColor Cyan
    Write-Host ""

    $opciones = @{}
    $contador = 1

    $tagOK = Get-CenteredTag -Text "OK" -TotalWidth 2
    Write-Host ("   $tagOK {0,-10} INSTALLED - {1} [sistema]" -f $edge.Nombre, $edge.Version) -ForegroundColor Green

    foreach ($nav in $navegadores) {
        switch ($nav.Estado) {
            "INSTALLED" {
                Write-Host ("   $tagOK {0,-10} INSTALLED - {1}" -f $nav.Nombre, $nav.Version) -ForegroundColor Green
            }
            "OUTDATED" {
                $tag = Get-CenteredTag -Text "$contador" -TotalWidth 2
                Write-Host ("   $tag {0,-10} OUTDATED  - {1}" -f $nav.Nombre, $nav.Version) -ForegroundColor Yellow
                $opciones[$contador.ToString()] = $nav
                $contador++
            }
            "MISSING" {
                $tag = Get-CenteredTag -Text "$contador" -TotalWidth 2
                Write-Host ("   $tag {0,-10} MISSING" -f $nav.Nombre) -ForegroundColor Gray
                $opciones[$contador.ToString()] = $nav
                $contador++
            }
            "UNKNOWN" {
                $tag = Get-CenteredTag -Text "$contador" -TotalWidth 2
                Write-Host ("   $tag {0,-10} UNKNOWN" -f $nav.Nombre) -ForegroundColor DarkYellow
                $opciones[$contador.ToString()] = $nav
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

function Invoke-InstalarNavegador {
    param($Navegador)

    # Si fue detectado via IdAlt, usar ese ID para la accion
    $idEfectivo = $Navegador.Id
    if ($Navegador.IdAlt -ne "") {
        $estadoPrincipal = Get-WingetPackageStatus -PackageId $Navegador.Id
        if ($estadoPrincipal -eq "MISSING") {
            $idEfectivo = $Navegador.IdAlt
        }
    }

    # Si fue detectado via IdAlt y esta desactualizado, consultar al tecnico
    $forzarReinstalar = $false
    if ($idEfectivo -eq $Navegador.IdAlt -and $Navegador.Estado -eq "OUTDATED") {
        Write-Blank -LogFile $LogFile
        Write-Log "$($Navegador.Nombre) fue detectado fuera del registro de winget." -Level WARNING -LogFile $LogFile
        Write-Host ""
        Write-Host "   [1] Actualizar version existente (conserva perfil del usuario)" -ForegroundColor Cyan
        Write-Host "   [2] Reinstalar limpiamente via winget (puede afectar el perfil)" -ForegroundColor Yellow
        Write-Host "   [0] Cancelar" -ForegroundColor DarkGray
        Write-Host ""
        $opcion = Read-Host "   Elegir opcion"

        switch ($opcion) {
            "1" { $forzarReinstalar = $false }
            "2" { $forzarReinstalar = $true  }
            default {
                Write-Log "Operacion cancelada: $($Navegador.Nombre)" -Level WARNING -LogFile $LogFile
                return $false
            }
        }
    }

    $accion = if ($Navegador.Estado -eq "OUTDATED" -and -not $forzarReinstalar) { "upgrade" } else { "install" }
    $verbo  = if ($accion -eq "upgrade") { "Actualizando" } else { "Instalando" }

    Write-Blank -LogFile $LogFile
    Write-Log "$verbo`: $($Navegador.Nombre)" -LogFile $LogFile

    if ($accion -eq "upgrade") {
        winget upgrade --id $idEfectivo --accept-package-agreements --accept-source-agreements
    } else {
        winget install --id $idEfectivo --accept-package-agreements --accept-source-agreements
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Log "OK: $($Navegador.Nombre)" -Level SUCCESS -LogFile $LogFile
        $Navegador.Estado  = "INSTALLED"
        $Navegador.Version = Get-VersionInstalada -PackageId $idEfectivo
        return $true
    } else {
        Write-Log "Error (codigo $LASTEXITCODE): $($Navegador.Nombre)" -Level ERROR -LogFile $LogFile
        return $false
    }
}

# Edge: siempre presente en Windows, se muestra como informativo pero no se toca
$edge = [PSCustomObject]@{ Nombre = "Edge"; Version = ""; Estado = "INSTALLED" }
$edgeVersion = Get-VersionInstalada -PackageId "Microsoft.Edge"
$edge.Version = if ($edgeVersion) { $edgeVersion } else { "pre-instalado" }

#endregion

#region AUDITORIA INICIAL

Invoke-Auditoria

# Guardar estado previo para el reporte final
$estadoPrevio = @{}
foreach ($nav in $navegadores) {
    $estadoPrevio[$nav.Id] = $nav.Estado
}

#endregion

#region LOOP DE SELECCION E INSTALACION

$resultados = @()

do {
    $opciones = Show-Submenu

    # Si no hay nada para instalar o actualizar, salir automaticamente
    if ($opciones.Count -eq 0) {
        Write-Host "  Todos los navegadores estan instalados y al dia." -ForegroundColor Green
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

    $navSeleccionado = $opciones[$seleccion]
    $exito = Invoke-InstalarNavegador -Navegador $navSeleccionado

    $resultados += [PSCustomObject]@{
        Nombre = $navSeleccionado.Nombre
        Previo = $estadoPrevio[$navSeleccionado.Id]
        Final  = if ($exito) { "OK" } else { "ERROR" }
    }

    Start-Sleep -Seconds 1

} while ($true)

# Agregar al reporte los navegadores que ya estaban instalados y no se tocaron
foreach ($nav in $navegadores) {
    $yaRegistrado = $resultados | Where-Object { $_.Nombre -eq $nav.Nombre }
    if (-not $yaRegistrado -and $estadoPrevio[$nav.Id] -eq "INSTALLED") {
        $resultados += [PSCustomObject]@{
            Nombre = $nav.Nombre
            Previo = "INSTALLED"
            Final  = "OK"
        }
    }
}

#endregion

#region REPORTE FINAL

Clear-Host
Write-Section "REPORTE DE NAVEGADORES" -LogFile $LogFile
Write-Blank -LogFile $LogFile

# Auditoria final
Write-Log "--- Estado final ---" -LogFile $LogFile
Write-Blank -LogFile $LogFile

foreach ($nav in $navegadores) {
    $estadoFinal = Get-WingetPackageStatus -PackageId $nav.Id

    if ($estadoFinal -eq "MISSING" -and $nav.IdAlt -ne "") {
        $estadoAlt = Get-WingetPackageStatus -PackageId $nav.IdAlt
        if ($estadoAlt -ne "MISSING") { $estadoFinal = $estadoAlt }
    }

    $version = if ($estadoFinal -ne "MISSING") { Get-VersionInstalada -PackageId $nav.Id } else { "" }
    if ($version -eq "" -and $nav.IdAlt -ne "") {
        $version = Get-VersionInstalada -PackageId $nav.IdAlt
    }

    $label = switch ($estadoFinal) {
        "INSTALLED" { "{0} (INSTALLED) - {1}" -f $nav.Nombre, $version }
        "OUTDATED"  { "{0} (OUTDATED) - {1}"  -f $nav.Nombre, $version }
        "MISSING"   { "{0} (MISSING)"         -f $nav.Nombre }
        "UNKNOWN"   { "{0} (UNKNOWN)"         -f $nav.Nombre }
    }

    $tag   = Get-CenteredTag -Text $estadoFinal -TotalWidth 11
    $level = if ($estadoFinal -eq "INSTALLED") { "SUCCESS" } else { "WARNING" }
    Write-Log "$tag $label" -Level $level -LogFile $LogFile
}

Write-Blank -LogFile $LogFile
Write-Log "--- Acciones realizadas ---" -LogFile $LogFile
Write-Blank -LogFile $LogFile

$ok      = $resultados | Where-Object { $_.Final -eq "OK"    -and $_.Previo -ne "INSTALLED" }
$errores = $resultados | Where-Object { $_.Final -eq "ERROR" }

if ($ok.Count -eq 0 -and $errores.Count -eq 0) {
    Write-Log "No se realizaron cambios." -LogFile $LogFile
} else {
    foreach ($r in $resultados | Where-Object { $_.Previo -ne "INSTALLED" }) {
        $tag   = Get-CenteredTag -Text $r.Final -TotalWidth 7
        $linea = "  $tag $($r.Nombre) (Antes: $($r.Previo))"
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