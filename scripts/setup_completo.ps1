<#
.SYNOPSIS
    Setup completo con presets de perfil.
.DESCRIPTION
    Presenta al tecnico tres perfiles predefinidos como punto de partida.
    El tecnico selecciona un perfil, revisa que incluye y confirma antes
    de que el script ejecute la instalacion en secuencia.

    Perfiles disponibles:
      - Hogar   : navegadores, compresor, multimedia, productividad basica
      - Oficina : navegadores, compresor, multimedia, Office, comunicacion
      - Creativo: navegadores, compresor, multimedia extendida, productividad

    Los presets son puntos de partida. El tecnico puede cancelar en cualquier
    momento y usar los modulos individuales para ajustar la seleccion.

    NOTA: Este modulo llama a los modulos individuales en secuencia.
    Cada modulo realiza su propia auditoria antes de instalar.
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

$envInfo     = Initialize-Environment -LogDir $LogDir -ModuleName "setup_completo"
$LogFile     = $envInfo.LogFile
$ScriptsDir  = $PSScriptRoot

#endregion

#region DEFINICION DE PRESETS

$presets = @{

    "1" = [PSCustomObject]@{
        Nombre      = "Hogar"
        Descripcion = "Configuracion estandar para uso domestico."
        Incluye     = @(
            "Navegadores : Chrome, Brave"
            "Compresores : 7-Zip"
            "Multimedia  : VLC, Spotify"
            "Productividad: LibreOffice, Adobe Acrobat Reader"
            "Comunicacion: WhatsApp Desktop"
        )
        Modulos     = @("runtimes", "navegadores", "compresores", "multimedia", "productividad", "comunicacion", "configurar")
        FiltroWinget = @{
            navegadores   = @("Google.Chrome", "Brave.Brave")
            compresores   = @("7zip.7zip")
            multimedia    = @("VideoLAN.VLC", "Spotify.Spotify")
            productividad = @("TheDocumentFoundation.LibreOffice", "Adobe.Acrobat.Reader.64-bit")
            comunicacion  = @("9NKSQGP7F2NH")
        }
    }

    "2" = [PSCustomObject]@{
        Nombre      = "Oficina"
        Descripcion = "Configuracion para entorno de trabajo y oficina."
        Incluye     = @(
            "Navegadores : Chrome"
            "Compresores : 7-Zip"
            "Multimedia  : VLC"
            "Productividad: Office (segun licencia del cliente), Adobe Acrobat Reader"
            "Comunicacion: Teams, Zoom, AnyDesk"
        )
        Modulos     = @("runtimes", "navegadores", "compresores", "multimedia", "productividad", "comunicacion", "configurar")
        FiltroWinget = @{
            navegadores   = @("Google.Chrome")
            compresores   = @("7zip.7zip")
            multimedia    = @("VideoLAN.VLC")
            productividad = @("Microsoft.Office", "Adobe.Acrobat.Reader.64-bit")
            comunicacion  = @("Microsoft.Teams", "Zoom.Zoom", "AnyDeskSoftwareGmbH.AnyDesk")
        }
    }

    "3" = [PSCustomObject]@{
        Nombre      = "Creativo"
        Descripcion = "Configuracion para trabajo creativo y multimedia."
        Incluye     = @(
            "Navegadores : Chrome, Brave"
            "Compresores : 7-Zip"
            "Multimedia  : VLC, OBS Studio"
            "Productividad: LibreOffice, Adobe Acrobat Reader"
        )
        Modulos     = @("runtimes", "navegadores", "compresores", "multimedia", "productividad", "configurar")
        FiltroWinget = @{
            navegadores   = @("Google.Chrome", "Brave.Brave")
            compresores   = @("7zip.7zip")
            multimedia    = @("VideoLAN.VLC", "OBSProject.OBSStudio")
            productividad = @("TheDocumentFoundation.LibreOffice", "Adobe.Acrobat.Reader.64-bit")
        }
    }
}

#endregion

#region FUNCIONES DEL MODULO

function Show-MenuPresets {
    Clear-Host
    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host "           SETUP COMPLETO"                         -ForegroundColor White
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Selecciona un perfil como punto de partida."     -ForegroundColor DarkGray
    Write-Host "  Podras revisar el contenido antes de confirmar." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [1]  Hogar"    -ForegroundColor Gray
    Write-Host "        Uso domestico general."                    -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [2]  Oficina"  -ForegroundColor Gray
    Write-Host "        Entorno de trabajo y productividad."       -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   [3]  Creativo" -ForegroundColor Gray
    Write-Host "        Produccion multimedia y contenido."        -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host "   [0]  Volver al menu principal"                  -ForegroundColor DarkGray
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-DetallePreset {
    param($Preset)

    Clear-Host
    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host "   PERFIL: $($Preset.Nombre.ToUpper())"            -ForegroundColor White
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  $($Preset.Descripcion)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Incluye:" -ForegroundColor Cyan

    foreach ($item in $Preset.Incluye) {
        Write-Host "    - $item" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "  Modulos que se ejecutaran en secuencia:" -ForegroundColor Cyan
    $modulosStr = ($Preset.Modulos | ForEach-Object { $_ }) -join " -> "
    Write-Host "    $modulosStr" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  NOTA: Cada modulo auditara el sistema antes de instalar." -ForegroundColor DarkGray
    Write-Host "        Solo se instalara lo que falte o este desactualizado." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host "   [S]  Confirmar e iniciar setup"                 -ForegroundColor Yellow
    Write-Host "   [0]  Volver a seleccion de perfil"             -ForegroundColor DarkGray
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-ModuloEnSecuencia {
    param(
        [string]$NombreModulo,
        [string]$LogDir
    )

    $rutaModulo = Join-Path $ScriptsDir "$NombreModulo.ps1"

    if (-not (Test-Path $rutaModulo)) {
        Write-Log "Modulo no encontrado: $NombreModulo" -Level ERROR -LogFile $LogFile
        return $false
    }

    Write-Log "Ejecutando modulo: $NombreModulo" -LogFile $LogFile

    try {
        & $rutaModulo -LogDir $LogDir -NoElevation
        Write-Log "Modulo completado: $NombreModulo" -Level SUCCESS -LogFile $LogFile
        return $true
    } catch {
        Write-Log "Error en modulo $NombreModulo`: $_" -Level ERROR -LogFile $LogFile
        return $false
    }
}

#endregion

#region LOOP PRINCIPAL

do {
    Show-MenuPresets
    $seleccionPerfil = Read-Host "   Elegir perfil"

    if ($seleccionPerfil -eq "0") { break }

    if (-not $presets.ContainsKey($seleccionPerfil)) {
        Write-Host ""
        Write-Host "  Opcion invalida." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        continue
    }

    $presetElegido = $presets[$seleccionPerfil]

    # Mostrar detalle y pedir confirmacion
    Show-DetallePreset -Preset $presetElegido
    $confirmacion = Read-Host "   Confirmar"

    if ($confirmacion -notmatch "^[sS]$") {
        continue
    }

    # Ejecutar modulos en secuencia
    Clear-Host
    Write-Section "SETUP COMPLETO - $($presetElegido.Nombre.ToUpper())" -LogFile $LogFile
    Write-Blank -LogFile $LogFile
    Write-Log "Iniciando setup con perfil: $($presetElegido.Nombre)" -LogFile $LogFile
    Write-Log "Modulos a ejecutar: $($presetElegido.Modulos -join ', ')" -LogFile $LogFile
    Write-Blank -LogFile $LogFile

    $inicio    = Get-Date
    $resultados = @()

    foreach ($modulo in $presetElegido.Modulos) {
        Write-Section "MODULO: $($modulo.ToUpper())" -LogFile $LogFile
        Write-Blank -LogFile $LogFile

        $exito = Invoke-ModuloEnSecuencia -NombreModulo $modulo -LogDir $LogDir

        $resultados += [PSCustomObject]@{
            Modulo = $modulo
            Estado = if ($exito) { "OK" } else { "ERROR" }
        }

        Write-Blank -LogFile $LogFile
    }

    # Reporte final del setup
    $fin      = Get-Date
    $duracion = [math]::Round(($fin - $inicio).TotalMinutes, 1)

    Write-Section "RESUMEN DEL SETUP" -LogFile $LogFile
    Write-Blank -LogFile $LogFile
    Write-Log "Perfil    : $($presetElegido.Nombre)" -LogFile $LogFile
    Write-Log "Inicio    : $($inicio.ToString('HH:mm:ss'))" -LogFile $LogFile
    Write-Log "Fin       : $($fin.ToString('HH:mm:ss'))" -LogFile $LogFile
    Write-Log "Duracion  : $duracion minutos" -LogFile $LogFile
    Write-Blank -LogFile $LogFile

    foreach ($r in $resultados) {
        $tag   = Get-CenteredTag -Text $r.Estado -TotalWidth 5
        $linea = "  $tag $($r.Modulo)"
        switch ($r.Estado) {
            "OK"    { Write-Log $linea -Level SUCCESS -LogFile $LogFile }
            "ERROR" { Write-Log $linea -Level ERROR   -LogFile $LogFile }
        }
    }

    Write-Blank -LogFile $LogFile
    Write-Section -LogFile $LogFile
    Write-Log "Log guardado en: $LogFile" -LogFile $LogFile
    Write-Blank

    Invoke-Pause
    break

} while ($true)

#endregion