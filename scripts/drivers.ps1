<#
.SYNOPSIS
    Instalacion de drivers via Snappy Driver Installer Origin (SDIO).
.DESCRIPTION
    Verifica la presencia de SDIO en la carpeta instaladores/drivers/.
    Si esta disponible, lo lanza y espera a que el tecnico finalice
    la instalacion de drivers. Si no esta disponible, informa al tecnico
    donde descargarlo manualmente.
    Genera un log con el resultado de la sesion.
.NOTES
    Version : 1.0.0
    Proyecto: Windows Setup Toolkit

    SDIO (Snappy Driver Installer Origin)
    Sitio oficial: https://www.snappy-driver-installer.org
    Detecta e instala automaticamente drivers de chipset, red y audio.
    No incluye drivers de GPU (NVIDIA/AMD/Intel) ni impresoras especificas.

    USO RECOMENDADO:
    1. Al abrir SDIO, activar "Expert mode" para ver el detalle
       de cada driver detectado por el sistema.
    2. SDIO mostrara que hardware necesita drivers y cuales estan
       desactualizados. Seleccionar solo los necesarios.
    3. Packs esenciales en la mayoria de los casos:
         - Chipset  : base del sistema
         - Network  : Ethernet y WiFi
         - Audio    : sonido
    4. Packs opcionales segun el equipo:
         - USB      : si hay problemas con puertos USB
         - Storage  : equipos con RAID o NVMe
    5. NO es necesario descargar los 73 packs disponibles.
       Expert mode permite ser preciso con lo que realmente falta.

    DRIVERS FUERA DEL SCOPE DE SDIO (instalar por separado):
    - GPU : NVIDIA GeForce Experience / AMD Software / Intel Arc
    - Impresoras y perifericos especificos por fabricante
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

$envInfo = Initialize-Environment -LogDir $LogDir -ModuleName "drivers"
$LogFile = $envInfo.LogFile

$instaladoresDir = Join-Path $PSScriptRoot "..\instaladores\drivers"
$sdioEncontrado  = $null

#endregion

#region BUSQUEDA DE SDIO

Write-Section "DRIVERS - SDIO" -LogFile $LogFile
Write-Blank -LogFile $LogFile
Write-Log "Buscando SDIO en: $instaladoresDir" -LogFile $LogFile
Write-Blank -LogFile $LogFile

# Buscar cualquier ejecutable de SDIO en la carpeta (acepta comodin de version)
$sdioArchivos = Get-ChildItem -Path $instaladoresDir -Filter "SDIO_x64*.exe" -Recurse -ErrorAction SilentlyContinue

if ($sdioArchivos -and $sdioArchivos.Count -gt 0) {
    # Si hay varios, usar el mas reciente
    $sdioEncontrado = ($sdioArchivos | Sort-Object Name -Descending | Select-Object -First 1).FullName
    Write-Log "SDIO encontrado: $($sdioEncontrado | Split-Path -Leaf)" -Level SUCCESS -LogFile $LogFile
} else {
    Write-Log "SDIO no encontrado en la carpeta de instaladores." -Level WARNING -LogFile $LogFile
}

Write-Blank -LogFile $LogFile

#endregion

#region EJECUCION O INSTRUCCIONES

if ($sdioEncontrado) {

    Write-Section "INSTALACION DE DRIVERS" -LogFile $LogFile
    Write-Blank -LogFile $LogFile
    Write-Log "Iniciando SDIO..." -LogFile $LogFile
    Write-Log "El programa detectara e instalara los drivers necesarios." -LogFile $LogFile
    Write-Log "Cuando finalices la instalacion en SDIO, cierra el programa para continuar." -Level WARNING -LogFile $LogFile
    Write-Blank -LogFile $LogFile

    Invoke-Pause "Presiona Enter para iniciar SDIO..."

    $inicio = Get-Date
    Write-Log "SDIO iniciado a las $($inicio.ToString('HH:mm:ss'))" -LogFile $LogFile

    try {
        $proceso = Start-Process -FilePath $sdioEncontrado -PassThru -ErrorAction Stop
        Write-Log "Esperando que el tecnico finalice la instalacion de drivers..." -LogFile $LogFile
        $proceso.WaitForExit()

        $fin      = Get-Date
        $duracion = [math]::Round(($fin - $inicio).TotalMinutes, 1)

        Write-Blank -LogFile $LogFile
        Write-Log "SDIO finalizado a las $($fin.ToString('HH:mm:ss'))" -Level SUCCESS -LogFile $LogFile
        Write-Log "Duracion de la sesion: $duracion minutos" -LogFile $LogFile

    } catch {
        Write-Blank -LogFile $LogFile
        Write-Log "Error al iniciar SDIO: $_" -Level ERROR -LogFile $LogFile
    }

} else {

    Write-Section "SDIO NO DISPONIBLE" -LogFile $LogFile
    Write-Blank -LogFile $LogFile
    Write-Log "SDIO debe descargarse manualmente antes de usar este modulo." -Level WARNING -LogFile $LogFile
    Write-Blank -LogFile $LogFile
    Write-Log "Sitio oficial:" -LogFile $LogFile
    Write-Log "  https://www.snappy-driver-installer.org" -LogFile $LogFile
    Write-Blank -LogFile $LogFile
    Write-Log "Instrucciones:" -LogFile $LogFile
    Write-Log "  1. Descargar SDIO_x64 desde el sitio oficial" -LogFile $LogFile
    Write-Log "  2. Colocar el ejecutable en:" -LogFile $LogFile
    Write-Log "     $instaladoresDir" -LogFile $LogFile
    Write-Log "  3. Volver a ejecutar este modulo" -LogFile $LogFile
    Write-Blank -LogFile $LogFile
    Write-Log "NOTA: SDIO no incluye drivers de GPU (NVIDIA/AMD/Intel) ni" -LogFile $LogFile
    Write-Log "      impresoras especificas. Esos se instalan por separado." -LogFile $LogFile

}

#endregion

#region REPORTE FINAL

Write-Blank -LogFile $LogFile
Write-Section "REPORTE DE DRIVERS" -LogFile $LogFile
Write-Blank -LogFile $LogFile

if ($sdioEncontrado) {
    Write-Log "SDIO ejecutado: $($sdioEncontrado | Split-Path -Leaf)" -Level SUCCESS -LogFile $LogFile
    Write-Log "Estado        : sesion finalizada por el tecnico" -Level SUCCESS -LogFile $LogFile
} else {
    Write-Log "SDIO no disponible. Descarga pendiente por el operador." -Level WARNING -LogFile $LogFile
    Write-Log "Referencia    : https://www.snappy-driver-installer.org" -LogFile $LogFile
}

Write-Blank -LogFile $LogFile
Write-Section -LogFile $LogFile
Write-Log "Log guardado en: $LogFile" -LogFile $LogFile
Write-Blank

Invoke-Pause

#endregion