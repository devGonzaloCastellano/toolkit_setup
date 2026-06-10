<#
.SYNOPSIS
    Configuraciones iniciales de Windows.
.DESCRIPTION
    Presenta un submenu interactivo donde el tecnico selecciona que
    configuraciones aplicar. Las opciones marcadas como [recomendado]
    representan el setup estandar para la mayoria de los equipos.
    La opcion [A] aplica todas las recomendadas de una sola vez.
    Genera un reporte con todas las acciones realizadas.
.NOTES
    Version : 1.1.0
    Proyecto: Windows Setup Toolkit

    Algunas configuraciones requieren reinicio para tomar efecto:
      - Nombre del equipo
    Otras tienen efecto inmediato:
      - Privacidad, energia, zona horaria, extensiones, Defender
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

$envInfo = Initialize-Environment -LogDir $LogDir -ModuleName "configurar"
$LogFile = $envInfo.LogFile

# Detectar tipo de equipo
$esNotebook  = (Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue) -ne $null
$tipoEquipo  = if ($esNotebook) { "Notebook" } else { "Desktop" }

#endregion

#region REGISTRO DE RESULTADOS

# Tabla de acciones realizadas para el reporte final
$resultados = @()

function Add-Resultado {
    param(
        [string]$Accion,
        [string]$Estado,   # OK, ERROR, OMITIDO
        [string]$Detalle = ""
    )
    $script:resultados += [PSCustomObject]@{
        Accion  = $Accion
        Estado  = $Estado
        Detalle = $Detalle
    }
}

#endregion

#region FUNCIONES DE CONFIGURACION

function Set-TelemetriaDeshabilitada {
    Write-Log "Deshabilitando telemetria basica..." -LogFile $LogFile
    try {
        $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "AllowTelemetry" -Value 0 -Type DWord -Force
        Write-Log "OK: Telemetria deshabilitada." -Level SUCCESS -LogFile $LogFile
        Add-Resultado -Accion "Deshabilitar telemetria" -Estado "OK"
    } catch {
        Write-Log "Error al deshabilitar telemetria: $_" -Level ERROR -LogFile $LogFile
        Add-Resultado -Accion "Deshabilitar telemetria" -Estado "ERROR" -Detalle $_
    }
}

function Set-PublicidadDeshabilitada {
    Write-Log "Deshabilitando publicidad personalizada..." -LogFile $LogFile
    try {
        $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "Enabled" -Value 0 -Type DWord -Force
        Write-Log "OK: Publicidad personalizada deshabilitada." -Level SUCCESS -LogFile $LogFile
        Add-Resultado -Accion "Deshabilitar publicidad" -Estado "OK"
    } catch {
        Write-Log "Error al deshabilitar publicidad: $_" -Level ERROR -LogFile $LogFile
        Add-Resultado -Accion "Deshabilitar publicidad" -Estado "ERROR" -Detalle $_
    }
}

function Set-SugerenciasDeshabilitadas {
    Write-Log "Deshabilitando sugerencias en el menu inicio..." -LogFile $LogFile
    try {
        $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $path -Name "SystemPaneSuggestionsEnabled"    -Value 0 -Type DWord -Force
        Write-Log "OK: Sugerencias de inicio deshabilitadas." -Level SUCCESS -LogFile $LogFile
        Add-Resultado -Accion "Deshabilitar sugerencias inicio" -Estado "OK"
    } catch {
        Write-Log "Error al deshabilitar sugerencias: $_" -Level ERROR -LogFile $LogFile
        Add-Resultado -Accion "Deshabilitar sugerencias inicio" -Estado "ERROR" -Detalle $_
    }
}

function Set-PlanEnergia {
    Write-Log "Configurando plan de energia para $tipoEquipo..." -LogFile $LogFile
    try {
        if ($esNotebook) {
            # Balanceado para notebook
            powercfg /setactive SCHEME_BALANCED 2>&1 | Out-Null
            Write-Log "OK: Plan Balanceado aplicado (notebook)." -Level SUCCESS -LogFile $LogFile
            Add-Resultado -Accion "Plan de energia" -Estado "OK" -Detalle "Balanceado (notebook)"
        } else {
            # Alto rendimiento para desktop
            powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
            Write-Log "OK: Plan Alto rendimiento aplicado (desktop)." -Level SUCCESS -LogFile $LogFile
            Add-Resultado -Accion "Plan de energia" -Estado "OK" -Detalle "Alto rendimiento (desktop)"
        }
    } catch {
        Write-Log "Error al configurar plan de energia: $_" -Level ERROR -LogFile $LogFile
        Add-Resultado -Accion "Plan de energia" -Estado "ERROR" -Detalle $_
    }
}

function Set-SuspensionTapa {
    if (-not $esNotebook) {
        Write-Log "Esta opcion solo aplica a notebooks. Equipo detectado: Desktop." -Level WARNING -LogFile $LogFile
        Add-Resultado -Accion "Suspension al cerrar tapa" -Estado "OMITIDO" -Detalle "No es notebook"
        return
    }

    Write-Host ""
    Write-Host "  Que debe hacer el equipo al cerrar la tapa?" -ForegroundColor Cyan
    Write-Host "   [1] Suspender              (recomendado para uso movil)" -ForegroundColor Gray
    Write-Host "   [2] Hibernar               (ahorra mas bateria)"         -ForegroundColor Gray
    Write-Host "   [3] No hacer nada          (recomendado si se usa de escritorio)" -ForegroundColor Gray
    Write-Host "   [0] Cancelar"                                             -ForegroundColor DarkGray
    Write-Host ""

    $opcion = Read-Host "   Elegir opcion"

    $accionTapa = switch ($opcion) {
        "1" { 1 }  # Sleep
        "2" { 2 }  # Hibernate
        "3" { 0 }  # Do nothing
        default { $null }
    }

    if ($null -eq $accionTapa) {
        Write-Log "Configuracion de tapa cancelada." -Level WARNING -LogFile $LogFile
        Add-Resultado -Accion "Suspension al cerrar tapa" -Estado "OMITIDO" -Detalle "Cancelado por el tecnico"
        return
    }

    try {
        powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION $accionTapa 2>&1 | Out-Null
        powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION $accionTapa 2>&1 | Out-Null
        powercfg /apply 2>&1 | Out-Null
        $descripcion = @{ 0 = "No hacer nada"; 1 = "Suspender"; 2 = "Hibernar" }[$accionTapa]
        Write-Log "OK: Accion al cerrar tapa configurada: $descripcion" -Level SUCCESS -LogFile $LogFile
        Add-Resultado -Accion "Suspension al cerrar tapa" -Estado "OK" -Detalle $descripcion
    } catch {
        Write-Log "Error al configurar tapa: $_" -Level ERROR -LogFile $LogFile
        Add-Resultado -Accion "Suspension al cerrar tapa" -Estado "ERROR" -Detalle $_
    }
}

function Set-ZonaHorariaArgentina {
    Write-Log "Configurando zona horaria: Argentina Standard Time..." -LogFile $LogFile
    try {
        Set-TimeZone -Id "Argentina Standard Time" -ErrorAction Stop
        Write-Log "OK: Zona horaria configurada (UTC-3 Argentina)." -Level SUCCESS -LogFile $LogFile
        Add-Resultado -Accion "Zona horaria" -Estado "OK" -Detalle "Argentina Standard Time (UTC-3)"
    } catch {
        Write-Log "Error al configurar zona horaria: $_" -Level ERROR -LogFile $LogFile
        Add-Resultado -Accion "Zona horaria" -Estado "ERROR" -Detalle $_
    }
}

function Set-ZonaHorariaPersonalizada {
    Write-Host ""
    Write-Log "Zonas horarias disponibles (principales):" -LogFile $LogFile
    Write-Host ""

    $zonas = @(
        [PSCustomObject]@{ Num = "1";  Id = "Argentina Standard Time";       Nombre = "Argentina (UTC-3)"          }
        [PSCustomObject]@{ Num = "2";  Id = "SA Eastern Standard Time";      Nombre = "Brasil - Sao Paulo (UTC-3)" }
        [PSCustomObject]@{ Num = "3";  Id = "Pacific SA Standard Time";      Nombre = "Chile (UTC-4)"              }
        [PSCustomObject]@{ Num = "4";  Id = "SA Western Standard Time";      Nombre = "Bolivia/Paraguay (UTC-4)"   }
        [PSCustomObject]@{ Num = "5";  Id = "Venezuela Standard Time";       Nombre = "Venezuela (UTC-4:30)"       }
        [PSCustomObject]@{ Num = "6";  Id = "SA Pacific Standard Time";      Nombre = "Colombia/Peru (UTC-5)"      }
        [PSCustomObject]@{ Num = "7";  Id = "Central America Standard Time"; Nombre = "Mexico Centro (UTC-6)"      }
        [PSCustomObject]@{ Num = "8";  Id = "Eastern Standard Time";         Nombre = "USA Este (UTC-5)"           }
        [PSCustomObject]@{ Num = "9";  Id = "Central Standard Time";         Nombre = "USA Centro (UTC-6)"         }
        [PSCustomObject]@{ Num = "10"; Id = "Mountain Standard Time";        Nombre = "USA Montana (UTC-7)"        }
        [PSCustomObject]@{ Num = "11"; Id = "Pacific Standard Time";         Nombre = "USA Pacifico (UTC-8)"       }
        [PSCustomObject]@{ Num = "12"; Id = "GMT Standard Time";             Nombre = "Reino Unido (UTC+0)"        }
        [PSCustomObject]@{ Num = "13"; Id = "Central Europe Standard Time";  Nombre = "Europa Central (UTC+1)"     }
        [PSCustomObject]@{ Num = "14"; Id = "Spain Standard Time";           Nombre = "Espana (UTC+1)"             }
    )

    foreach ($z in $zonas) {
        Write-Host ("   [{0,-2}] {1}" -f $z.Num, $z.Nombre) -ForegroundColor Gray
    }

    Write-Host "   [0]  Cancelar" -ForegroundColor DarkGray
    Write-Host ""

    $opcion = Read-Host "   Elegir zona horaria"

    if ($opcion -eq "0") {
        Add-Resultado -Accion "Zona horaria personalizada" -Estado "OMITIDO" -Detalle "Cancelado por el tecnico"
        return
    }

    $zonaSeleccionada = $zonas | Where-Object { $_.Num -eq $opcion }

    if (-not $zonaSeleccionada) {
        Write-Log "Opcion invalida. Zona horaria no configurada." -Level WARNING -LogFile $LogFile
        Add-Resultado -Accion "Zona horaria personalizada" -Estado "OMITIDO" -Detalle "Opcion invalida"
        return
    }

    try {
        Set-TimeZone -Id $zonaSeleccionada.Id -ErrorAction Stop
        Write-Log "OK: Zona horaria configurada: $($zonaSeleccionada.Nombre)" -Level SUCCESS -LogFile $LogFile
        Add-Resultado -Accion "Zona horaria" -Estado "OK" -Detalle $zonaSeleccionada.Nombre
    } catch {
        Write-Log "Error al configurar zona horaria: $_" -Level ERROR -LogFile $LogFile
        Add-Resultado -Accion "Zona horaria" -Estado "ERROR" -Detalle $_
    }
}

function Set-NombreEquipo {
    Write-Host ""
    $nombreActual = $env:COMPUTERNAME
    Write-Log "Nombre actual del equipo: $nombreActual" -LogFile $LogFile
    Write-Host ""

    $nuevoNombre = Read-Host "   Ingresar nuevo nombre (Enter para cancelar)"

    if ([string]::IsNullOrWhiteSpace($nuevoNombre)) {
        Write-Log "Cambio de nombre cancelado." -Level WARNING -LogFile $LogFile
        Add-Resultado -Accion "Nombre del equipo" -Estado "OMITIDO" -Detalle "Cancelado por el tecnico"
        return
    }

    # Validar nombre: solo letras, numeros y guiones, max 15 caracteres
    if ($nuevoNombre -notmatch '^[a-zA-Z0-9\-]{1,15}$') {
        Write-Log "Nombre invalido. Solo letras, numeros y guiones. Maximo 15 caracteres." -Level ERROR -LogFile $LogFile
        Add-Resultado -Accion "Nombre del equipo" -Estado "ERROR" -Detalle "Nombre invalido: $nuevoNombre"
        return
    }

    try {
        Rename-Computer -NewName $nuevoNombre -Force -ErrorAction Stop
        Write-Log "OK: Equipo renombrado a '$nuevoNombre'. Requiere reinicio." -Level SUCCESS -LogFile $LogFile
        Write-Log "    ATENCION: El cambio tomara efecto al reiniciar el equipo." -Level WARNING -LogFile $LogFile
        Add-Resultado -Accion "Nombre del equipo" -Estado "OK" -Detalle "$nombreActual -> $nuevoNombre (requiere reinicio)"
    } catch {
        Write-Log "Error al renombrar equipo: $_" -Level ERROR -LogFile $LogFile
        Add-Resultado -Accion "Nombre del equipo" -Estado "ERROR" -Detalle $_
    }
}

function Invoke-VerificarActualizaciones {
    Write-Log "Iniciando verificacion de actualizaciones de Windows..." -LogFile $LogFile
    try {
        Start-Process "ms-settings:windowsupdate" -ErrorAction Stop
        Write-Log "OK: Windows Update abierto. Verificar e instalar actualizaciones manualmente." -Level SUCCESS -LogFile $LogFile
        Add-Resultado -Accion "Actualizaciones de Windows" -Estado "OK" -Detalle "Windows Update abierto"
    } catch {
        Write-Log "Error al abrir Windows Update: $_" -Level ERROR -LogFile $LogFile
        Add-Resultado -Accion "Actualizaciones de Windows" -Estado "ERROR" -Detalle $_
    }
}

function Set-ExtensionesVisibles {
    Write-Log "Habilitando visualizacion de extensiones de archivo..." -LogFile $LogFile
    try {
        $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $path -Name "HideFileExt" -Value 0 -Type DWord -Force
        Write-Log "OK: Extensiones de archivo visibles." -Level SUCCESS -LogFile $LogFile
        Add-Resultado -Accion "Mostrar extensiones" -Estado "OK"
    } catch {
        Write-Log "Error al configurar extensiones: $_" -Level ERROR -LogFile $LogFile
        Add-Resultado -Accion "Mostrar extensiones" -Estado "ERROR" -Detalle $_
    }
}

function Set-ArchivosOcultos {
    Write-Log "Habilitando visualizacion de archivos ocultos..." -LogFile $LogFile
    try {
        $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $path -Name "Hidden" -Value 1 -Type DWord -Force
        Write-Log "OK: Archivos ocultos visibles." -Level SUCCESS -LogFile $LogFile
        Add-Resultado -Accion "Mostrar archivos ocultos" -Estado "OK"
    } catch {
        Write-Log "Error al configurar archivos ocultos: $_" -Level ERROR -LogFile $LogFile
        Add-Resultado -Accion "Mostrar archivos ocultos" -Estado "ERROR" -Detalle $_
    }
}

function Invoke-VerificarDefender {
    Write-Log "Verificando Windows Defender..." -LogFile $LogFile
    try {
        $defender = Get-MpComputerStatus -ErrorAction Stop

        $activo      = $defender.AntivirusEnabled
        $actualizado = $defender.AntivirusSignatureAge -le 3  # menos de 3 dias

        if ($activo) {
            Write-Log "OK: Windows Defender activo." -Level SUCCESS -LogFile $LogFile
        } else {
            Write-Log "ATENCION: Windows Defender no esta activo." -Level ERROR -LogFile $LogFile
        }

        if ($actualizado) {
            Write-Log "OK: Definiciones actualizadas (hace $($defender.AntivirusSignatureAge) dias)." -Level SUCCESS -LogFile $LogFile
        } else {
            Write-Log "ATENCION: Definiciones desactualizadas (hace $($defender.AntivirusSignatureAge) dias)." -Level WARNING -LogFile $LogFile
            Write-Log "          Actualizar desde Windows Security > Virus & threat protection." -Level WARNING -LogFile $LogFile
        }

        $estadoFinal = if ($activo -and $actualizado) { "OK" } elseif ($activo) { "OK" } else { "ERROR" }
        $detalle     = "Activo: $(if($activo){'Si'}else{'No'}) | Definiciones: $(if($actualizado){'Al dia'}else{"$($defender.AntivirusSignatureAge) dias sin actualizar"})"
        Add-Resultado -Accion "Windows Defender" -Estado $estadoFinal -Detalle $detalle

    } catch {
        Write-Log "Error al verificar Windows Defender: $_" -Level ERROR -LogFile $LogFile
        Add-Resultado -Accion "Windows Defender" -Estado "ERROR" -Detalle $_
    }
}

#endregion

#region SUBMENU

function Show-Submenu {
    Clear-Host
    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host "       CONFIGURACIONES INICIALES DE WINDOWS"       -ForegroundColor White
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   Equipo detectado: $tipoEquipo"                   -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "   -- PRIVACIDAD --"                                -ForegroundColor DarkCyan
    Write-Host "   [1]  Deshabilitar telemetria basica        [recomendado]" -ForegroundColor Gray
    Write-Host "   [2]  Deshabilitar publicidad personalizada  [recomendado]" -ForegroundColor Gray
    Write-Host "   [3]  Deshabilitar sugerencias inicio        [recomendado]" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   -- ENERGIA --"                                   -ForegroundColor DarkCyan
    Write-Host "   [4]  Plan de energia optimo                 [recomendado]" -ForegroundColor Gray
    Write-Host "   [5]  Configurar suspension al cerrar tapa" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   -- SISTEMA --"                                   -ForegroundColor DarkCyan
    Write-Host "   [6]  Zona horaria Argentina                 [recomendado]" -ForegroundColor Gray
    Write-Host "   [7]  Seleccionar otra zona horaria" -ForegroundColor Gray
    Write-Host "   [8]  Nombre del equipo" -ForegroundColor Gray
    Write-Host "   [9]  Verificar actualizaciones de Windows   [recomendado]" -ForegroundColor Gray
    Write-Host "   [10] Mostrar extensiones de archivo         [recomendado]" -ForegroundColor Gray
    Write-Host "   [11] Mostrar archivos ocultos" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   -- SEGURIDAD --"                                 -ForegroundColor DarkCyan
    Write-Host "   [12] Verificar Windows Defender             [recomendado]" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host "   [A]  Aplicar todas las recomendadas" -ForegroundColor Yellow
    Write-Host "   [0]  Finalizar" -ForegroundColor DarkGray
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host ""
}

#endregion

#region LOOP PRINCIPAL

do {
    Show-Submenu
    $opcion = Read-Host "   Elegir opcion"

    Write-Blank -LogFile $LogFile

    switch ($opcion) {
        "1"  { Set-TelemetriaDeshabilitada }
        "2"  { Set-PublicidadDeshabilitada }
        "3"  { Set-SugerenciasDeshabilitadas }
        "4"  { Set-PlanEnergia }
        "5"  { Set-SuspensionTapa }
        "6"  { Set-ZonaHorariaArgentina }
        "7"  { Set-ZonaHorariaPersonalizada }
        "8"  { Set-NombreEquipo }
        "9"  { Invoke-VerificarActualizaciones }
        "10" { Set-ExtensionesVisibles }
        "11" { Set-ArchivosOcultos }
        "12" { Invoke-VerificarDefender }
        "A"  {
            Write-Log "Aplicando todas las configuraciones recomendadas..." -LogFile $LogFile
            Write-Blank -LogFile $LogFile
            Set-TelemetriaDeshabilitada
            Set-PublicidadDeshabilitada
            Set-SugerenciasDeshabilitadas
            Set-PlanEnergia
            Set-ZonaHorariaArgentina
            Invoke-VerificarActualizaciones
            Set-ExtensionesVisibles
            Invoke-VerificarDefender
        }
        "a"  {
            Write-Log "Aplicando todas las configuraciones recomendadas..." -LogFile $LogFile
            Write-Blank -LogFile $LogFile
            Set-TelemetriaDeshabilitada
            Set-PublicidadDeshabilitada
            Set-SugerenciasDeshabilitadas
            Set-PlanEnergia
            Set-ZonaHorariaArgentina
            Invoke-VerificarActualizaciones
            Set-ExtensionesVisibles
            Invoke-VerificarDefender
        }
        "0"  { break }
        default {
            Write-Host ""
            Write-Host "  Opcion invalida." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
            continue
        }
    }

    if ($opcion -ne "0") {
        Write-Blank
        Invoke-Pause "Presiona Enter para volver al menu..."
    }

} while ($opcion -ne "0")

#endregion

#region REPORTE FINAL

Clear-Host
Write-Section "REPORTE DE CONFIGURACIONES" -LogFile $LogFile
Write-Blank -LogFile $LogFile

if ($resultados.Count -eq 0) {
    Write-Log "No se realizaron configuraciones." -LogFile $LogFile
} else {
    foreach ($r in $resultados) {
        $detalle = if ($r.Detalle -ne "") { " - $($r.Detalle)" } else { "" }
        $linea   = "  [{0,-7}] {1}{2}" -f $r.Estado, $r.Accion, $detalle

        switch ($r.Estado) {
            "OK"      { Write-Log $linea -Level SUCCESS -LogFile $LogFile }
            "ERROR"   { Write-Log $linea -Level ERROR   -LogFile $LogFile }
            "OMITIDO" { Write-Log $linea -Level WARNING -LogFile $LogFile }
        }
    }

    Write-Blank -LogFile $LogFile
    $ok      = ($resultados | Where-Object { $_.Estado -eq "OK" }).Count
    $errores = ($resultados | Where-Object { $_.Estado -eq "ERROR" }).Count
    $omitidos = ($resultados | Where-Object { $_.Estado -eq "OMITIDO" }).Count

    Write-Log "Total   : $($resultados.Count)" -LogFile $LogFile
    Write-Log "OK      : $ok"      -Level SUCCESS -LogFile $LogFile
    if ($omitidos -gt 0) { Write-Log "Omitidos: $omitidos" -Level WARNING -LogFile $LogFile }
    if ($errores  -gt 0) { Write-Log "Errores : $errores"  -Level ERROR   -LogFile $LogFile }
}

Write-Blank -LogFile $LogFile
Write-Section -LogFile $LogFile
Write-Log "Log guardado en: $LogFile" -LogFile $LogFile
Write-Blank

Invoke-Pause

#endregion