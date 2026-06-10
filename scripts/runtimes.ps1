<#
.SYNOPSIS
    Auditoria e instalacion de runtimes y redistribuibles del sistema.
.DESCRIPTION
    Audita el estado de cada runtime antes de actuar. Segun el resultado:
      INSTALLED -> omite
      OUTDATED  -> informa al tecnico y pregunta si actualizar
      MISSING   -> instala
      UNKNOWN   -> intenta instalar con advertencia
    Al finalizar genera un mini reporte con el estado de cada componente.
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

$envInfo = Initialize-Environment -LogDir $LogDir -ModuleName "runtimes"
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

#region CATALOGO DE RUNTIMES

$runtimes = @(
    [PSCustomObject]@{ Id = "Microsoft.VCRedist.2015+.x64"; Nombre = "Visual C++ 2015-2022"; Nivel = "x64" }
    [PSCustomObject]@{ Id = "Microsoft.VCRedist.2015+.x86"; Nombre = "Visual C++ 2015-2022"; Nivel = "x86" }
    [PSCustomObject]@{ Id = "Microsoft.VCRedist.2013.x64";  Nombre = "Visual C++ 2013";      Nivel = "x64" }
    [PSCustomObject]@{ Id = "Microsoft.VCRedist.2013.x86";  Nombre = "Visual C++ 2013";      Nivel = "x86" }
    [PSCustomObject]@{ Id = "Microsoft.VCRedist.2010.x64";  Nombre = "Visual C++ 2010";      Nivel = "x64" }
    [PSCustomObject]@{ Id = "Microsoft.VCRedist.2010.x86";  Nombre = "Visual C++ 2010";      Nivel = "x86" }
    [PSCustomObject]@{ Id = "Microsoft.DotNet.DesktopRuntime.6"; Nombre = ".NET Desktop Runtime 6 LTS"; Nivel = "x64" }
    [PSCustomObject]@{ Id = "Microsoft.DotNet.DesktopRuntime.8"; Nombre = ".NET Desktop Runtime 8 LTS"; Nivel = "x64" }
    [PSCustomObject]@{ Id = "Microsoft.DirectX";            Nombre = "DirectX End-User Runtime"; Nivel = "-" }
)

#endregion

#region AUDITORIA

Write-Section "AUDITORIA DE RUNTIMES" -LogFile $LogFile
Write-Blank -LogFile $LogFile
Write-Log "Verificando estado de componentes..." -LogFile $LogFile
Write-Blank -LogFile $LogFile

foreach ($runtime in $runtimes) {
    $label = "{0} ({1})" -f $runtime.Nombre, $runtime.Nivel
    $estado = Get-WingetPackageStatus -PackageId $runtime.Id
    $runtime | Add-Member -NotePropertyName Estado -NotePropertyValue $estado

    $tag   = Get-CenteredTag -Text $estado -TotalWidth 11
    $level = if ($estado -eq "INSTALLED") { "SUCCESS" } else { "WARNING" }
    Write-Log "$tag $label" -Level $level -LogFile $LogFile
}

Write-Blank -LogFile $LogFile

#endregion

#region AUDITORIA .NET FRAMEWORK 3.5

$netfx35 = [PSCustomObject]@{ Id = "NetFx3"; Nombre = ".NET Framework 3.5"; Nivel = "-"; Estado = "UNKNOWN" }

$feature = Get-WindowsOptionalFeature -Online -FeatureName "NetFx3" -ErrorAction SilentlyContinue
if ($feature) {
    $netfx35.Estado = if ($feature.State -eq "Enabled") { "INSTALLED" } else { "MISSING" }
}

$label = "{0} ({1})" -f $netfx35.Nombre, $netfx35.Nivel
$tag   = Get-CenteredTag -Text $netfx35.Estado -TotalWidth 11
$level = if ($netfx35.Estado -eq "INSTALLED") { "SUCCESS" } else { "WARNING" }
Write-Log "$tag $label" -Level $level -LogFile $LogFile

Write-Blank -LogFile $LogFile

#endregion

#region INSTALACION Y ACTUALIZACION

Write-Section "INSTALACION / ACTUALIZACION" -LogFile $LogFile
Write-Blank -LogFile $LogFile

$resultados = @()

foreach ($runtime in $runtimes) {
    $label = "{0} ({1})" -f $runtime.Nombre, $runtime.Nivel
    $saltear = $false
    $accion  = "install"

    switch ($runtime.Estado) {
        "INSTALLED" {
            Write-Log "Omitiendo (ya instalado): $label" -LogFile $LogFile
            $resultados += [PSCustomObject]@{ Nombre = $label; Previo = "INSTALLED"; Final = "OK" }
            $saltear = $true
        }
        "OUTDATED" {
            Write-Blank -LogFile $LogFile
            Write-Log "Actualizacion disponible: $label" -Level WARNING -LogFile $LogFile
            $respuesta = Read-Host "  Actualizar? (S/N)"
            if ($respuesta -match "^[sS]$") {
                $accion = "upgrade"
            } else {
                Write-Log "Actualizacion omitida por el tecnico: $label" -Level WARNING -LogFile $LogFile
                $resultados += [PSCustomObject]@{ Nombre = $label; Previo = "OUTDATED"; Final = "OMITIDO" }
                $saltear = $true
            }
        }
        "MISSING" {
            Write-Log "Instalando: $label" -LogFile $LogFile
        }
        "UNKNOWN" {
            Write-Log "Estado desconocido, intentando instalar: $label" -Level WARNING -LogFile $LogFile
        }
    }

    if ($saltear) { continue }

    if ($accion -eq "upgrade") {
        $salida = winget upgrade --id $runtime.Id --silent --accept-package-agreements --accept-source-agreements 2>&1
    } else {
        $salida = winget install --id $runtime.Id --silent --accept-package-agreements --accept-source-agreements 2>&1
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Log "OK: $label" -Level SUCCESS -LogFile $LogFile
        $resultados += [PSCustomObject]@{ Nombre = $label; Previo = $runtime.Estado; Final = "OK" }
    } else {
        Write-Log "Error (codigo $LASTEXITCODE): $label" -Level ERROR -LogFile $LogFile
        $resultados += [PSCustomObject]@{ Nombre = $label; Previo = $runtime.Estado; Final = "ERROR" }
    }

    Write-Blank -LogFile $LogFile
}

# .NET Framework 3.5
$label35 = "{0} ({1})" -f $netfx35.Nombre, $netfx35.Nivel
switch ($netfx35.Estado) {

    "INSTALLED" {
        Write-Log "Omitiendo (ya instalado): $label35" -LogFile $LogFile
        $resultados += [PSCustomObject]@{ Nombre = $label35; Previo = "INSTALLED"; Final = "OK" }
    }

    { $_ -in "MISSING", "UNKNOWN" } {
        Write-Log "Habilitando: $label35" -LogFile $LogFile
        Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
        if ($?) {
            Write-Log "OK: $label35" -Level SUCCESS -LogFile $LogFile
            $resultados += [PSCustomObject]@{ Nombre = $label35; Previo = $netfx35.Estado; Final = "OK" }
        } else {
            Write-Log "Error al habilitar: $label35" -Level ERROR -LogFile $LogFile
            Write-Log "Alternativa: Panel de control > Programas > Activar caracteristicas de Windows > .NET Framework 3.5" -Level WARNING -LogFile $LogFile
            $resultados += [PSCustomObject]@{ Nombre = $label35; Previo = $netfx35.Estado; Final = "ERROR" }
        }
    }
}

Write-Blank -LogFile $LogFile

#endregion

#region MINI REPORTE

Write-Section "REPORTE DE RUNTIMES" -LogFile $LogFile
Write-Blank -LogFile $LogFile

$ok       = $resultados | Where-Object { $_.Final -eq "OK" }
$errores  = $resultados | Where-Object { $_.Final -eq "ERROR" }
$omitidos = $resultados | Where-Object { $_.Final -eq "OMITIDO" }

foreach ($r in $resultados) {
    $tag   = Get-CenteredTag -Text $r.Final -TotalWidth 7
    $linea = "  $tag $($r.Nombre)"
    switch ($r.Final) {
        "OK"      { Write-Log $linea -Level SUCCESS -LogFile $LogFile }
        "ERROR"   { Write-Log $linea -Level ERROR   -LogFile $LogFile }
        "OMITIDO" { Write-Log $linea -Level WARNING -LogFile $LogFile }
    }
}

Write-Blank -LogFile $LogFile
Write-Log "Total   : $($resultados.Count)" -LogFile $LogFile
Write-Log "OK      : $($ok.Count)"         -Level SUCCESS -LogFile $LogFile

if ($omitidos.Count -gt 0) {
    Write-Log "Omitidos: $($omitidos.Count)" -Level WARNING -LogFile $LogFile
}
if ($errores.Count -gt 0) {
    Write-Log "Errores : $($errores.Count)"  -Level ERROR   -LogFile $LogFile
}

Write-Blank -LogFile $LogFile
Write-Section -LogFile $LogFile
Write-Log "Log guardado en: $LogFile" -LogFile $LogFile
Write-Blank

Invoke-Pause

#endregion