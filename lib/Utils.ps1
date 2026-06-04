<#
.SYNOPSIS
    Modulo de utilidades compartidas para la Windows Setup Toolkit.
.DESCRIPTION
    Provee funciones auxiliares reutilizables para todos los modulos:
    logging con niveles, formateo de consola, inicializacion de entorno
    y helpers de uso general.
    Debe importarse via dot-sourcing al inicio de cada script:
        . "$PSScriptRoot\..\lib\Utils.ps1"
.NOTES
    Version : 1.0.0
    Proyecto: Windows Setup Toolkit

    NOTA: Este archivo es una copia deliberada e independiente del Utils.ps1
    de la Portable Windows Toolkit. Cada toolkit gestiona su propio Utils.ps1.
    Los cambios en una toolkit NO se propagan automaticamente a la otra.
#>

#region FUNCIONES DE LOGGING

<#
.SYNOPSIS
    Escribe un mensaje en consola y opcionalmente en archivo de log.
.PARAMETER Message
    Texto del mensaje a registrar.
.PARAMETER Level
    Nivel del mensaje: INFO, SUCCESS, WARNING o ERROR.
.PARAMETER LogFile
    Ruta completa al archivo de log. Si se omite, solo escribe en consola.
.EXAMPLE
    Write-Log "Proceso iniciado."
    Write-Log "Software instalado." -Level SUCCESS
    Write-Log "No se pudo conectar." -Level WARNING -LogFile $LogFile
    Write-Log "Error critico." -Level ERROR -LogFile $LogFile
#>
function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO",

        [string]$LogFile
    )

    $colorMap = @{
        INFO    = "White"
        SUCCESS = "Green"
        WARNING = "Yellow"
        ERROR   = "Red"
    }

    $timestamp = Get-Date -Format "HH:mm:ss"
    $line      = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message
    $color     = $colorMap[$Level]

    Write-Host $line -ForegroundColor $color

    if ($LogFile) {
        $line | Out-File -FilePath $LogFile -Append -Encoding utf8
    }
}

<#
.SYNOPSIS
    Escribe una linea en blanco en consola y opcionalmente en el log.
.PARAMETER LogFile
    Ruta al archivo de log. Opcional.
#>
function Write-Blank {
    param([string]$LogFile)

    Write-Host ""
    if ($LogFile) {
        "" | Out-File -FilePath $LogFile -Append -Encoding utf8
    }
}

<#
.SYNOPSIS
    Escribe un separador visual de seccion en consola y en el log.
.PARAMETER Title
    Titulo opcional para mostrar centrado dentro del separador.
.PARAMETER LogFile
    Ruta al archivo de log. Opcional.
.EXAMPLE
    Write-Section
    Write-Section "INSTALANDO NAVEGADORES"
    Write-Section "RESUMEN FINAL" -LogFile $LogFile
#>
function Write-Section {
    param(
        [string]$Title,
        [string]$LogFile
    )

    if ($Title) {
        $padTotal = 50 - $Title.Length - 2
        $padLeft  = [math]::Floor($padTotal / 2)
        $padRight = $padTotal - $padLeft
        $line     = "=" * $padLeft + " $Title " + "=" * $padRight
    } else {
        $line = "=" * 50
    }

    Write-Host $line -ForegroundColor Cyan
    if ($LogFile) {
        $line | Out-File -FilePath $LogFile -Append -Encoding utf8
    }
}

#endregion

#region INICIALIZACION DE ENTORNO

<#
.SYNOPSIS
    Inicializa el entorno de ejecucion de un modulo.
.DESCRIPTION
    Crea el directorio de logs si no existe, genera el path del archivo
    de log con timestamp y retorna un objeto con los valores inicializados.
.PARAMETER LogDir
    Ruta al directorio de logs.
.PARAMETER ModuleName
    Nombre del modulo, usado como prefijo del archivo de log.
.OUTPUTS
    PSCustomObject con LogDir, LogFile y Timestamp.
.EXAMPLE
    $env = Initialize-Environment -LogDir $LogDir -ModuleName "navegadores"
    $LogFile = $env.LogFile
#>
function Initialize-Environment {
    param(
        [Parameter(Mandatory)]
        [string]$LogDir,

        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $logFile   = Join-Path $LogDir "${ModuleName}_${timestamp}.txt"

    return [PSCustomObject]@{
        LogDir    = $LogDir
        LogFile   = $logFile
        Timestamp = $timestamp
    }
}

#endregion

#region AUTO-ELEVACION

<#
.SYNOPSIS
    Verifica si el proceso actual tiene privilegios de Administrador.
.OUTPUTS
    [bool]
#>
function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

<#
.SYNOPSIS
    Relanza el script actual con privilegios de Administrador via UAC.
.DESCRIPTION
    Si el script no esta elevado, lo relanza con Start-Process -Verb RunAs.
    Debe llamarse al inicio del script, antes de cualquier logica.
.PARAMETER ScriptPath
    Ruta completa al script. Usar $PSCommandPath.
.PARAMETER Parameters
    Parametros a pasar al proceso elevado.
.EXAMPLE
    Invoke-Elevate -ScriptPath $PSCommandPath
#>
function Invoke-Elevate {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [hashtable]$Parameters = @{}
    )

    if (Test-IsAdmin) { return }

    Write-Warning "Se requieren permisos de administrador. Solicitando elevacion..."

    $paramString = ($Parameters.GetEnumerator() |
            ForEach-Object { "-$($_.Key) `"$($_.Value)`"" }) -join " "

    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" $paramString"

    Start-Process powershell.exe -ArgumentList $argList -Verb RunAs
    exit
}

#endregion

#region HELPERS DE FORMATO

<#
.SYNOPSIS
    Convierte bytes a representacion legible (KB, MB, GB).
.PARAMETER Bytes
    Valor en bytes a convertir.
.OUTPUTS
    [string] con valor y unidad. Ejemplo: "1.23 GB"
.EXAMPLE
    Format-Bytes 1548576    # "1.48 MB"
    Format-Bytes 2147483648 # "2.00 GB"
#>
function Format-Bytes {
    param([long]$Bytes)

    switch ($Bytes) {
        { $_ -ge 1GB } { return "{0:N2} GB" -f ($_ / 1GB) }
        { $_ -ge 1MB } { return "{0:N2} MB" -f ($_ / 1MB) }
        { $_ -ge 1KB } { return "{0:N2} KB" -f ($_ / 1KB) }
        default        { return "$_ bytes" }
    }
}

<#
.SYNOPSIS
    Pausa la ejecucion hasta que el usuario presione Enter.
.PARAMETER Message
    Mensaje a mostrar. Por defecto: "Presiona Enter para continuar..."
#>
function Invoke-Pause {
    param([string]$Message = "Presiona Enter para continuar...")
    Write-Host "`n$Message" -ForegroundColor DarkGray
    Read-Host | Out-Null
}

<#
.SYNOPSIS
    Verifica si hay conexion a internet intentando resolver un host conocido.
.OUTPUTS
    [bool]
.EXAMPLE
    if (-not (Test-InternetConnection)) {
        Write-Log "Sin conexion a internet." -Level ERROR
    }
#>
function Test-InternetConnection {
    try {
        $null = [System.Net.Dns]::GetHostEntry("dns.google")
        return $true
    } catch {
        return $false
    }
}

<#
.SYNOPSIS
    Verifica si winget esta disponible en el sistema.
.OUTPUTS
    [bool]
.EXAMPLE
    if (-not (Test-Winget)) {
        Write-Log "winget no encontrado." -Level ERROR
    }
#>
function Test-Winget {
    return $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
}

<#
.SYNOPSIS
    Verifica el espacio libre disponible en un disco.
.PARAMETER Drive
    Letra de unidad a verificar. Ejemplo: "C"
.PARAMETER MinimumGB
    Espacio minimo requerido en GB.
.OUTPUTS
    [bool]
.EXAMPLE
    if (-not (Test-DiskSpace -Drive "C" -MinimumGB 5)) {
        Write-Log "Espacio insuficiente en disco C." -Level ERROR
    }
#>
function Test-DiskSpace {
    param(
        [Parameter(Mandatory)]
        [string]$Drive,

        [Parameter(Mandatory)]
        [double]$MinimumGB
    )

    $disk = Get-PSDrive -Name $Drive -ErrorAction SilentlyContinue
    if (-not $disk) { return $false }

    $freeGB = [math]::Round($disk.Free / 1GB, 2)
    return $freeGB -ge $MinimumGB
}

#endregion

<#
.SYNOPSIS
    Determina el estado de instalacion de un paquete winget.
.PARAMETER PackageId
    ID del paquete winget. Ejemplo: "Google.Chrome"
.OUTPUTS
    [string] INSTALLED | OUTDATED | MISSING | UNKNOWN
.EXAMPLE
    $estado = Get-WingetPackageStatus -PackageId "Google.Chrome"
#>
function Get-WingetPackageStatus {
    param(
        [Parameter(Mandatory)]
        [string]$PackageId
    )

    try {
        $resultado = winget list --id $PackageId --exact --accept-source-agreements 2>&1
    } catch {
        return "UNKNOWN"
    }

    if ($LASTEXITCODE -ne 0) {
        if ($LASTEXITCODE -eq 1 -or $LASTEXITCODE -eq -1978335212) { return "MISSING" }
        return "UNKNOWN"
    }

    $texto = $resultado -join " "
    if ($texto -notmatch [regex]::Escape($PackageId)) { return "MISSING" }

    # Buscar el indice de la columna "Disponible" en el header
    $headerLine = $resultado | Where-Object { $_ -match "^Nombre\s+Id\s+" }
    if (-not $headerLine) { return "INSTALLED" }

    $disponibleIndex = $headerLine.IndexOf("Disponible")
    if ($disponibleIndex -lt 0) { return "INSTALLED" }

    # Verificar si alguna linea del paquete tiene contenido en esa posicion
    $lineas = $resultado | Where-Object { $_ -match [regex]::Escape($PackageId) }
    foreach ($linea in $lineas) {
        if ($linea.Length -gt $disponibleIndex) {
            $valor = $linea.Substring($disponibleIndex).Trim()
            if ($valor -and $valor -notmatch "^\s*$") { return "OUTDATED" }
        }
    }

    return "INSTALLED"
}