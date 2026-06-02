<#
.SYNOPSIS
    Menu principal de la Windows Setup Toolkit.
.DESCRIPTION
    Entry point del sistema. Configura el entorno visual, importa utilidades
    compartidas y presenta el menu de navegacion principal desde el que se
    invocan todos los modulos de instalacion y configuracion.
.NOTES
    Version : 1.0.0
    Proyecto: Windows Setup Toolkit
#>

#region PARAMETROS

param(
    [string]$LogDir = "$PSScriptRoot\logs",
    [switch]$NoElevation
)

#endregion

#region IMPORTS

. "$PSScriptRoot\lib\Utils.ps1"

#endregion

#region AUTO-ELEVACION

if (-not $NoElevation) {
    Invoke-Elevate -ScriptPath $PSCommandPath -Parameters $PSBoundParameters
}

#endregion

#region CONFIGURACION VISUAL

$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
Clear-Host

#endregion

#region CONSTANTES

$VERSION     = "1.0.0"
$SCRIPTS_DIR = Join-Path $PSScriptRoot "scripts"

#endregion

#region FUNCIONES DE MENU

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ==================================================" -ForegroundColor Cyan
    Write-Host "      WINDOWS SETUP TOOLKIT  v$VERSION"              -ForegroundColor White
    Write-Host "  ==================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Show-Header

    Write-Host "   -- SETUP RAPIDO --"              -ForegroundColor DarkCyan
    Write-Host "    [1]  Setup completo (elegir perfil)"
    Write-Host ""

    Write-Host "   -- POR CATEGORIA --"             -ForegroundColor DarkCyan
    Write-Host "    [2]  Runtimes y redistribuibles"
    Write-Host "    [3]  Navegadores"
    Write-Host "    [4]  Compresores"
    Write-Host "    [5]  Multimedia"
    Write-Host "    [6]  Productividad y Office"
    Write-Host "    [7]  Comunicacion"
    Write-Host "    [8]  Developer"
    Write-Host "    [9]  Drivers"
    Write-Host ""

    Write-Host "   -- WINDOWS --"                   -ForegroundColor DarkCyan
    Write-Host "   [10]  Configuraciones iniciales de Windows"
    Write-Host ""

    Write-Host "  ==================================================" -ForegroundColor Cyan
    Write-Host "    [0]  Salir"
    Write-Host "  ==================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-Module {
    param(
        [Parameter(Mandatory)]
        [string]$ModuleFile
    )

    $modulePath = Join-Path $SCRIPTS_DIR $ModuleFile

    if (-not (Test-Path $modulePath)) {
        Write-Log "Modulo no encontrado: $ModuleFile" -Level ERROR
        Invoke-Pause
        return
    }

    & $modulePath -LogDir $LogDir -NoElevation
}

#endregion

#region TABLA DE MODULOS

$ModuleMap = @{
    "1"  = "setup_completo.ps1"
    "2"  = "runtimes.ps1"
    "3"  = "navegadores.ps1"
    "4"  = "compresores.ps1"
    "5"  = "multimedia.ps1"
    "6"  = "productividad.ps1"
    "7"  = "comunicacion.ps1"
    "8"  = "developer.ps1"
    "9"  = "drivers.ps1"
    "10" = "configurar.ps1"
}

#endregion

#region LOOP PRINCIPAL

do {
    Show-Menu
    $opcion = Read-Host "   Elegir opcion"

    if ($opcion -eq "0") { break }

    if ($ModuleMap.ContainsKey($opcion)) {
        Invoke-Module -ModuleFile $ModuleMap[$opcion]
    } else {
        Write-Host ""
        Write-Host "  Opcion invalida. Intentalo de nuevo." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }

} while ($true)

#endregion

#region SALIDA

Clear-Host
Write-Host ""
Write-Host "  Hasta luego." -ForegroundColor Cyan
Write-Host ""

#endregion
