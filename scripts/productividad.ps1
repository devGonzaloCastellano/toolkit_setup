<#
.SYNOPSIS
    Auditoria e instalacion de software de productividad.
.DESCRIPTION
    Audita el estado de cada aplicacion antes de actuar. Presenta un submenu
    interactivo organizado por categorias donde el tecnico selecciona que
    instalar o actualizar.

    Categorias:
      - Office    : Microsoft 365, Office ODT, LibreOffice (elegir uno)
      - PDF       : Adobe Acrobat Reader, Foxit PDF Reader, Sumatra PDF
      - Utilidades: Notepad++

    IMPORTANTE sobre Office:
      La toolkit solo realiza la instalacion. La activacion es responsabilidad
      del cliente con sus propias credenciales. No se incluyen activaciones
      KMS ni herramientas de crackeo.

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

$envInfo = Initialize-Environment -LogDir $LogDir -ModuleName "productividad"
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

#region CATALOGOS

# --- OFFICE ---
$catalogoOffice = @(
    [PSCustomObject]@{
        Id      = "Microsoft.Office"
        Nombre  = "Microsoft 365"
        Nota    = "requiere cuenta activa del cliente"
        Estado  = "UNKNOWN"
        Version = ""
    }
    [PSCustomObject]@{
        Id      = "Microsoft.OfficeDeploymentTool"
        Nombre  = "Office ODT"
        Nota    = "requiere clave de producto del cliente"
        Estado  = "UNKNOWN"
        Version = ""
    }
    [PSCustomObject]@{
        Id      = "TheDocumentFoundation.LibreOffice"
        Nombre  = "LibreOffice"
        Nota    = "gratuito, compatibilidad parcial con Office"
        Estado  = "UNKNOWN"
        Version = ""
    }
)

# --- PDF ---
$catalogoPDF = @(
    [PSCustomObject]@{
        Id      = "Adobe.Acrobat.Reader.64-bit"
        Nombre  = "Adobe Acrobat Reader"
        Nota    = "estandar de la industria, mas completo"
        Estado  = "UNKNOWN"
        Version = ""
    }
    [PSCustomObject]@{
        Id      = "Foxit.FoxitReader"
        Nombre  = "Foxit PDF Reader"
        Nota    = "mas liviano que Adobe, anotaciones gratis"
        Estado  = "UNKNOWN"
        Version = ""
    }
    [PSCustomObject]@{
        Id      = "SumatraPDF.SumatraPDF"
        Nombre  = "Sumatra PDF"
        Nota    = "ultra liviano, solo lectura"
        Estado  = "UNKNOWN"
        Version = ""
    }
)

# --- UTILIDADES ---
$catalogoUtilidades = @(
    [PSCustomObject]@{
        Id      = "Notepad++.Notepad++"
        Nombre  = "Notepad++"
        Nota    = ""
        Estado  = "UNKNOWN"
        Version = ""
    }
)

#endregion

#region FUNCIONES DEL MODULO

function Test-AdobeInstalado {
    $resultado = winget list --name "Adobe Acrobat" --accept-source-agreements 2>&1
    $texto = $resultado -join " "
    return $texto -match "Adobe Acrobat"
}

function Test-OfficeInstalado {
    $resultado = winget list --name "Microsoft Office" --accept-source-agreements 2>&1
    $texto = $resultado -join " "
    return $texto -match "Microsoft Office"
}

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

function Invoke-AuditoriaCategoria {
    param(
        [string]$Titulo,
        [array]$Catalogo
    )

    Write-Log "--- $Titulo ---" -LogFile $LogFile

    foreach ($app in $Catalogo) {

        if ($app.Nombre -in @("Microsoft 365", "Office ODT") -and (Test-OfficeInstalado)) {
            $app.Estado  = "INSTALLED"
            $app.Version = "instalado (fuera de winget)"
        }
        elseif ($app.Id -eq "Adobe.Acrobat.Reader.64-bit" -and (Test-AdobeInstalado)) {
            $app.Estado  = "INSTALLED"
            $app.Version = "instalado (fuera de winget)"
        } else {
            $app.Estado  = Get-WingetPackageStatus -PackageId $app.Id
            $app.Version = if ($app.Estado -ne "MISSING") { Get-VersionInstalada -PackageId $app.Id } else { "" }
        }

        $label = switch ($app.Estado) {
            "INSTALLED" { "{0} (INSTALLED - {1})" -f $app.Nombre, $app.Version }
            "OUTDATED"  { "{0} (OUTDATED  - {1})" -f $app.Nombre, $app.Version }
            "MISSING"   { "{0} (MISSING)"          -f $app.Nombre }
            "UNKNOWN"   { "{0} (UNKNOWN)"           -f $app.Nombre }
        }

        switch ($app.Estado) {
            "INSTALLED" { Write-Log "[INSTALLED] $label" -Level SUCCESS -LogFile $LogFile }
            "OUTDATED"  { Write-Log "[OUTDATED]  $label" -Level WARNING -LogFile $LogFile }
            "MISSING"   { Write-Log "[MISSING]   $label" -Level WARNING -LogFile $LogFile }
            "UNKNOWN"   { Write-Log "[UNKNOWN]   $label" -Level WARNING -LogFile $LogFile }
        }
    }

    Write-Blank -LogFile $LogFile
}

function Show-CategoriaSubmenu {
    param(
        [string]$Titulo,
        [array]$Catalogo,
        [ref]$Contador,
        [hashtable]$Opciones
    )

    Write-Host "   -- $Titulo --" -ForegroundColor DarkCyan

    foreach ($app in $Catalogo) {
        $nota = if ($app.Nota -ne "") { " ($($app.Nota))" } else { "" }

        switch ($app.Estado) {
            "INSTALLED" {
                Write-Host ("   [OK] {0,-22} INSTALLED - {1}" -f $app.Nombre, $app.Version) -ForegroundColor Green
            }
            "OUTDATED" {
                Write-Host ("   [{0,2}] {1,-22} OUTDATED  - {2}{3}" -f $Contador.Value, $app.Nombre, $app.Version, $nota) -ForegroundColor Yellow
                $Opciones[$Contador.Value.ToString()] = $app
                $Contador.Value++
            }
            "MISSING" {
                Write-Host ("   [{0,2}] {1,-22} MISSING{2}" -f $Contador.Value, $app.Nombre, $nota) -ForegroundColor Gray
                $Opciones[$Contador.Value.ToString()] = $app
                $Contador.Value++
            }
            "UNKNOWN" {
                Write-Host ("   [{0,2}] {1,-22} UNKNOWN{2}" -f $Contador.Value, $app.Nombre, $nota) -ForegroundColor DarkYellow
                $Opciones[$Contador.Value.ToString()] = $app
                $Contador.Value++
            }
        }
    }

    Write-Host ""
}

function Show-Submenu {
    Clear-Host
    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host "           PRODUCTIVIDAD"                           -ForegroundColor White
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host ""

    $opciones = @{}
    $contador = [ref]1

    Show-CategoriaSubmenu -Titulo "OFFICE"      -Catalogo $catalogoOffice     -Contador $contador -Opciones $opciones
    Show-CategoriaSubmenu -Titulo "PDF"         -Catalogo $catalogoPDF        -Contador $contador -Opciones $opciones
    Show-CategoriaSubmenu -Titulo "UTILIDADES"  -Catalogo $catalogoUtilidades -Contador $contador -Opciones $opciones

    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host "   [0] Finalizar"                                   -ForegroundColor DarkGray
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host ""

    return $opciones
}

function Show-AdvertenciaOffice {
    param([string]$Nombre)

    Write-Host ""
    Write-Host "  ATENCION: $Nombre" -ForegroundColor Yellow

    switch ($Nombre) {
        "Microsoft 365" {
            Write-Host "  La toolkit instala el cliente pero NO activa la licencia." -ForegroundColor Yellow
            Write-Host "  El cliente debe activar con su propia cuenta de Microsoft 365." -ForegroundColor Yellow
        }
        "Office ODT" {
            Write-Host "  La toolkit instala Office via ODT pero NO activa la licencia." -ForegroundColor Yellow
            Write-Host "  El cliente debe activar con su propia clave de producto." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  INSTRUCCIONES ODT:" -ForegroundColor Cyan
            Write-Host "  1. ODT descarga e instala Office directamente desde Microsoft." -ForegroundColor Gray
            Write-Host "  2. Al finalizar, abrir cualquier app de Office (Word, Excel)." -ForegroundColor Gray
            Write-Host "  3. Ingresar la clave de producto o iniciar sesion con cuenta." -ForegroundColor Gray
            Write-Host "  4. Para personalizar que apps instalar, editar configuration.xml" -ForegroundColor Gray
            Write-Host "     antes de ejecutar. Referencia: https://config.office.com" -ForegroundColor Gray
        }
        "LibreOffice" {
            Write-Host "  LibreOffice es compatible con formatos Office (.docx, .xlsx, .pptx)" -ForegroundColor Yellow
            Write-Host "  pero pueden aparecer diferencias en documentos complejos o macros." -ForegroundColor Yellow
            Write-Host "  Recomendado solo si el cliente no tiene licencia de Office." -ForegroundColor Yellow
        }
    }

    Write-Host ""
    $confirmar = Read-Host "  Continuar con la instalacion? (S/N)"
    return $confirmar -match "^[sS]$"
}

function Invoke-InstalarApp {
    param($App)

    # Mostrar advertencia para opciones de Office
    if ($App.Nombre -in @("Microsoft 365", "Office ODT", "LibreOffice")) {
        $confirmar = Show-AdvertenciaOffice -Nombre $App.Nombre
        if (-not $confirmar) {
            Write-Log "Instalacion cancelada por el tecnico: $($App.Nombre)" -Level WARNING -LogFile $LogFile
            return $false
        }
    }

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

Write-Section "AUDITORIA DE PRODUCTIVIDAD" -LogFile $LogFile
Write-Blank -LogFile $LogFile
Write-Log "Verificando estado de aplicaciones de productividad..." -LogFile $LogFile
Write-Blank -LogFile $LogFile

Invoke-AuditoriaCategoria -Titulo "OFFICE"     -Catalogo $catalogoOffice
Invoke-AuditoriaCategoria -Titulo "PDF"        -Catalogo $catalogoPDF
Invoke-AuditoriaCategoria -Titulo "UTILIDADES" -Catalogo $catalogoUtilidades

# Guardar estado previo
$estadoPrevio = @{}
foreach ($app in ($catalogoOffice + $catalogoPDF + $catalogoUtilidades)) {
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

# Agregar al reporte las que ya estaban instaladas y no se tocaron
foreach ($app in ($catalogoOffice + $catalogoPDF + $catalogoUtilidades)) {
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
Write-Section "REPORTE DE PRODUCTIVIDAD" -LogFile $LogFile
Write-Blank -LogFile $LogFile

Write-Log "--- Estado final ---" -LogFile $LogFile
Write-Blank -LogFile $LogFile

foreach ($app in ($catalogoOffice + $catalogoPDF + $catalogoUtilidades)) {

    if ($app.Nombre -in @("Microsoft 365", "Office ODT") -and (Test-OfficeInstalado)) {
        $estadoFinal  = "INSTALLED"
        $Version = "instalado (fuera de winget)"
    }
    elseif ($app.Id -eq "Adobe.Acrobat.Reader.64-bit" -and (Test-AdobeInstalado)) {
        $estadoFinal = "INSTALLED"
        $version     = "instalado (fuera de winget)"
    } else {
        $estadoFinal = Get-WingetPackageStatus -PackageId $app.Id
        $version     = if ($estadoFinal -ne "MISSING") { Get-VersionInstalada -PackageId $app.Id } else { "" }
    }

    $label = switch ($estadoFinal) {
        "INSTALLED" { "{0} (INSTALLED - {1})" -f $app.Nombre, $version }
        "OUTDATED"  { "{0} (OUTDATED  - {1})" -f $app.Nombre, $version }
        "MISSING"   { "{0} (MISSING)"          -f $app.Nombre }
        "UNKNOWN"   { "{0} (UNKNOWN)"           -f $app.Nombre }
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