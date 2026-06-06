<#
.SYNOPSIS
    Auditoria global del sistema.
.DESCRIPTION
    Realiza una auditoria completa del equipo sin instalar ni modificar nada.
    Cubre dos areas principales:

    1. Estado de componentes de software:
         Runtimes, navegadores, compresores, multimedia,
         comunicacion y productividad.

    2. Dispositivos conectados y su estado:
         Monitores, audio, red, USB y dispositivos con errores.

    3. Estado de Windows:
         Windows Defender y actualizaciones pendientes.

    Uso recomendado:
      - Pre-implementacion : auditar antes de trabajar para ver que necesita
      - Post-implementacion: auditar al finalizar para verificar el resultado
        y generar evidencia del trabajo realizado.

    No realiza cambios en el sistema.
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

$envInfo = Initialize-Environment -LogDir $LogDir -ModuleName "system_audit"
$LogFile = $envInfo.LogFile

#endregion

#region CATALOGOS DE SOFTWARE

$catalogoRuntimes = @(
    [PSCustomObject]@{ Id = "Microsoft.VCRedist.2015+.x64";      Nombre = "Visual C++ 2015-2022 (x64)" }
    [PSCustomObject]@{ Id = "Microsoft.VCRedist.2015+.x86";      Nombre = "Visual C++ 2015-2022 (x86)" }
    [PSCustomObject]@{ Id = "Microsoft.VCRedist.2013.x64";       Nombre = "Visual C++ 2013 (x64)"      }
    [PSCustomObject]@{ Id = "Microsoft.VCRedist.2013.x86";       Nombre = "Visual C++ 2013 (x86)"      }
    [PSCustomObject]@{ Id = "Microsoft.VCRedist.2010.x64";       Nombre = "Visual C++ 2010 (x64)"      }
    [PSCustomObject]@{ Id = "Microsoft.VCRedist.2010.x86";       Nombre = "Visual C++ 2010 (x86)"      }
    [PSCustomObject]@{ Id = "Microsoft.DotNet.DesktopRuntime.6"; Nombre = ".NET Desktop Runtime 6 LTS" }
    [PSCustomObject]@{ Id = "Microsoft.DotNet.DesktopRuntime.8"; Nombre = ".NET Desktop Runtime 8 LTS" }
    [PSCustomObject]@{ Id = "Microsoft.DirectX";                 Nombre = "DirectX End-User Runtime"   }
)

$catalogoNavegadores = @(
    [PSCustomObject]@{ Id = "Google.Chrome";  IdAlt = "Google.Chrome.EXE"; Nombre = "Chrome"  }
    [PSCustomObject]@{ Id = "Brave.Brave";    IdAlt = "";                  Nombre = "Brave"   }
    [PSCustomObject]@{ Id = "Mozilla.Firefox"; IdAlt = "";                 Nombre = "Firefox" }
    [PSCustomObject]@{ Id = "Microsoft.Edge"; IdAlt = "";                  Nombre = "Edge"    }
)

$catalogoCompresores = @(
    [PSCustomObject]@{ Id = "7zip.7zip";      Nombre = "7-Zip"   }
    [PSCustomObject]@{ Id = "RARLab.WinRAR";  Nombre = "WinRAR"  }
    [PSCustomObject]@{ Id = "M2Team.NanaZip"; Nombre = "NanaZip" }
)

$catalogoMultimedia = @(
    [PSCustomObject]@{ Id = "VideoLAN.VLC";         Nombre = "VLC"       }
    [PSCustomObject]@{ Id = "Spotify.Spotify";      Nombre = "Spotify"   }
    [PSCustomObject]@{ Id = "OBSProject.OBSStudio"; Nombre = "OBS Studio" }
)

$catalogoComunicacion = @(
    [PSCustomObject]@{ Id = "Microsoft.Teams";             IdAlt = "";              Nombre = "Teams"      }
    [PSCustomObject]@{ Id = "Zoom.Zoom";                   IdAlt = "Zoom.Zoom.EXE"; Nombre = "Zoom"       }
    [PSCustomObject]@{ Id = "SlackTechnologies.Slack";     IdAlt = "";              Nombre = "Slack"      }
    [PSCustomObject]@{ Id = "9NKSQGP7F2NH";               IdAlt = "";              Nombre = "WhatsApp"   }
    [PSCustomObject]@{ Id = "AnyDeskSoftwareGmbH.AnyDesk"; IdAlt = "";             Nombre = "AnyDesk"    }
    [PSCustomObject]@{ Id = "TeamViewer.TeamViewer";       IdAlt = "";              Nombre = "TeamViewer" }
)

$catalogoProductividad = @(
    [PSCustomObject]@{ Id = "Microsoft.Office";             Nombre = "Microsoft 365";         EsOffice = $true  }
    [PSCustomObject]@{ Id = "Microsoft.OfficeDeploymentTool"; Nombre = "Office ODT";          EsOffice = $true  }
    [PSCustomObject]@{ Id = "TheDocumentFoundation.LibreOffice"; Nombre = "LibreOffice";      EsOffice = $false }
    [PSCustomObject]@{ Id = "Adobe.Acrobat.Reader.64-bit";  Nombre = "Adobe Acrobat Reader";  EsAdobe  = $true  }
    [PSCustomObject]@{ Id = "Foxit.FoxitReader";            Nombre = "Foxit PDF Reader";      EsAdobe  = $false }
    [PSCustomObject]@{ Id = "SumatraPDF.SumatraPDF";        Nombre = "Sumatra PDF";           EsAdobe  = $false }
    [PSCustomObject]@{ Id = "Notepad++.Notepad++";          Nombre = "Notepad++";             EsAdobe  = $false }
)

#endregion

#region FUNCIONES DE AUDITORIA DE SOFTWARE

function Get-EstadoApp {
    param(
        [string]$Id,
        [string]$IdAlt = ""
    )

    $estado = Get-WingetPackageStatus -PackageId $Id

    if ($estado -eq "MISSING" -and $IdAlt -ne "") {
        $estadoAlt = Get-WingetPackageStatus -PackageId $IdAlt
        if ($estadoAlt -ne "MISSING") { return $estadoAlt }
    }

    return $estado
}

function Test-AdobeInstalado {
    $resultado = winget list --name "Adobe Acrobat" --accept-source-agreements 2>&1
    return ($resultado -join " ") -match "Adobe Acrobat"
}

function Test-OfficeInstalado {
    $resultado = winget list --name "Microsoft Office" --accept-source-agreements 2>&1
    return ($resultado -join " ") -match "Microsoft Office"
}

function Test-NetFx35 {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName "NetFx3" -ErrorAction SilentlyContinue
    if ($feature) { return $feature.State -eq "Enabled" }
    return $false
}

function Write-EstadoApp {
    param(
        [string]$Nombre,
        [string]$Estado
    )

    $label = "  [{0,-9}] {1}" -f $Estado, $Nombre

    switch ($Estado) {
        "INSTALLED" { Write-Log $label -Level SUCCESS -LogFile $LogFile }
        "OUTDATED"  { Write-Log $label -Level WARNING -LogFile $LogFile }
        "MISSING"   { Write-Log $label -Level WARNING -LogFile $LogFile }
        "UNKNOWN"   { Write-Log $label -Level WARNING -LogFile $LogFile }
    }
}

function Invoke-AuditoriaCategoria {
    param(
        [string]$Titulo,
        [array]$Catalogo
    )

    Write-Log "--- $Titulo ---" -LogFile $LogFile

    foreach ($app in $Catalogo) {
        $idAlt   = if ($app.PSObject.Properties["IdAlt"]) { $app.IdAlt } else { "" }
        $esOffice = if ($app.PSObject.Properties["EsOffice"]) { $app.EsOffice } else { $false }
        $esAdobe  = if ($app.PSObject.Properties["EsAdobe"])  { $app.EsAdobe  } else { $false }

        if ($esOffice -and (Test-OfficeInstalado)) {
            $estado = "INSTALLED"
        } elseif ($esAdobe -and (Test-AdobeInstalado)) {
            $estado = "INSTALLED"
        } else {
            $estado = Get-EstadoApp -Id $app.Id -IdAlt $idAlt
        }

        # .NET Framework 3.5 via Windows Features
        if ($app.Id -eq "NetFx3") {
            $estado = if (Test-NetFx35) { "INSTALLED" } else { "MISSING" }
        }

        Write-EstadoApp -Nombre $app.Nombre -Estado $estado
    }

    Write-Blank -LogFile $LogFile
}

#endregion

#region FUNCIONES DE AUDITORIA DE HARDWARE

function Invoke-AuditoriaMonitores {
    Write-Log "--- MONITORES ---" -LogFile $LogFile

    try {
        $monitores = Get-CimInstance -ClassName Win32_DesktopMonitor -ErrorAction Stop |
                Where-Object { $_.PNPDeviceID -ne $null }

        if (-not $monitores -or @($monitores).Count -eq 0) {
            Write-Log "  No se detectaron monitores via WMI." -Level WARNING -LogFile $LogFile
        } else {
            foreach ($m in $monitores) {
                $nombre = if ($m.Name) { $m.Name } else { "Monitor desconocido" }
                Write-Log "  [CONECTADO ] $nombre" -Level SUCCESS -LogFile $LogFile
            }
        }

        # Resolución activa via VideoController
        $video = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue |
                Where-Object { $_.CurrentHorizontalResolution -gt 0 }

        foreach ($v in $video) {
            $res = "$($v.CurrentHorizontalResolution) x $($v.CurrentVerticalResolution)"
            Write-Log "  [RESOLUCION] $($v.Name): $res" -LogFile $LogFile
        }

    } catch {
        Write-Log "  Error al auditar monitores: $_" -Level ERROR -LogFile $LogFile
    }

    Write-Blank -LogFile $LogFile
}

function Invoke-AuditoriaAudio {
    Write-Log "--- AUDIO ---" -LogFile $LogFile

    try {
        $dispositivos = Get-CimInstance -ClassName Win32_SoundDevice -ErrorAction Stop

        if (-not $dispositivos -or @($dispositivos).Count -eq 0) {
            Write-Log "  No se detectaron dispositivos de audio." -Level WARNING -LogFile $LogFile
        } else {
            foreach ($d in $dispositivos) {
                $nombre = if ($d.Name) { $d.Name } else { "Dispositivo desconocido" }
                $estado = switch ($d.Status) {
                    "OK"      { "FUNCIONANDO" }
                    default   { $d.Status }
                }
                $nivel  = if ($d.Status -eq "OK") { "SUCCESS" } else { "WARNING" }
                Write-Log "  [$estado] $nombre" -Level $nivel -LogFile $LogFile
            }
        }
    } catch {
        Write-Log "  Error al auditar audio: $_" -Level ERROR -LogFile $LogFile
    }

    Write-Blank -LogFile $LogFile
}

function Invoke-AuditoriaRed {
    Write-Log "--- RED ---" -LogFile $LogFile

    try {
        $adaptadores = Get-CimInstance -ClassName Win32_NetworkAdapter -ErrorAction Stop |
                Where-Object { $_.PhysicalAdapter -eq $true }

        if (-not $adaptadores -or @($adaptadores).Count -eq 0) {
            Write-Log "  No se detectaron adaptadores de red." -Level WARNING -LogFile $LogFile
        } else {
            foreach ($a in $adaptadores) {
                $nombre = if ($a.Name) { $a.Name } else { "Adaptador desconocido" }
                $estado = if ($a.NetEnabled) { "CONECTADO " } else { "DESCONECTADO" }
                $nivel  = if ($a.NetEnabled) { "SUCCESS" } else { "WARNING" }
                Write-Log "  [$estado] $nombre" -Level $nivel -LogFile $LogFile
            }
        }
    } catch {
        Write-Log "  Error al auditar red: $_" -Level ERROR -LogFile $LogFile
    }

    Write-Blank -LogFile $LogFile
}

function Invoke-AuditoriaUSB {
    Write-Log "--- DISPOSITIVOS USB ---" -LogFile $LogFile

    try {
        $dispositivos = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop |
                Where-Object {
                    $_.PNPDeviceID -like "USB\*" -and
                            $_.Name -notmatch "USB Root Hub|Host Controller|Generic USB Hub|Composite Device|Unknown Device" -and
                            $_.ConfigManagerErrorCode -eq 0
                } |
                Sort-Object Name -Unique

        if (-not $dispositivos -or @($dispositivos).Count -eq 0) {
            Write-Log "  No se detectaron dispositivos USB conectados." -Level WARNING -LogFile $LogFile
        } else {
            foreach ($d in $dispositivos) {
                $nombre = if ($d.Name) { $d.Name } else { "Dispositivo desconocido" }
                Write-Log "  [CONECTADO ] $nombre" -Level SUCCESS -LogFile $LogFile
            }
        }
    } catch {
        Write-Log "  Error al auditar USB: $_" -Level ERROR -LogFile $LogFile
    }

    Write-Blank -LogFile $LogFile
}

function Invoke-AuditoriaDispositivos {
    Write-Log "--- DISPOSITIVOS CON PROBLEMAS ---" -LogFile $LogFile

    try {
        $conProblemas = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop |
                Where-Object { $_.ConfigManagerErrorCode -ne 0 }

        if (-not $conProblemas -or @($conProblemas).Count -eq 0) {
            Write-Log "  Sin dispositivos con errores o advertencias." -Level SUCCESS -LogFile $LogFile
        } else {
            foreach ($d in $conProblemas) {
                $nombre = if ($d.Name) { $d.Name } else { "Dispositivo desconocido" }
                $codigo = $d.ConfigManagerErrorCode
                Write-Log "  [ERROR $codigo] $nombre" -Level ERROR -LogFile $LogFile
            }
        }
    } catch {
        Write-Log "  Error al auditar dispositivos: $_" -Level ERROR -LogFile $LogFile
    }

    Write-Blank -LogFile $LogFile
}

#endregion

#region FUNCIONES DE AUDITORIA DE WINDOWS

function Invoke-AuditoriaDefender {
    Write-Log "--- WINDOWS DEFENDER ---" -LogFile $LogFile

    try {
        $defender = Get-MpComputerStatus -ErrorAction Stop

        $activo      = $defender.AntivirusEnabled
        $diasFirmas  = $defender.AntivirusSignatureAge
        $actualizado = $diasFirmas -le 3

        Write-Log "  Antivirus activo    : $(if($activo){'Si'}else{'No - ATENCION'})" `
            -Level $(if($activo){'SUCCESS'}else{'ERROR'}) -LogFile $LogFile

        Write-Log "  Definiciones        : $(if($actualizado){"Al dia ($diasFirmas dias)"}else{"Desactualizadas ($diasFirmas dias)"})" `
            -Level $(if($actualizado){'SUCCESS'}else{'WARNING'}) -LogFile $LogFile

    } catch {
        Write-Log "  Error al verificar Defender: $_" -Level ERROR -LogFile $LogFile
    }

    Write-Blank -LogFile $LogFile
}

function Invoke-AuditoriaWindowsUpdate {
    Write-Log "--- WINDOWS UPDATE ---" -LogFile $LogFile

    try {
        $session  = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $result   = $searcher.Search("IsInstalled=0 and Type='Software'")
        $pending  = $result.Updates.Count

        if ($pending -eq 0) {
            Write-Log "  Sistema actualizado. Sin actualizaciones pendientes." -Level SUCCESS -LogFile $LogFile
        } else {
            Write-Log "  Actualizaciones pendientes: $pending" -Level WARNING -LogFile $LogFile
            Write-Log "  Instalar desde: Configuracion > Windows Update" -Level WARNING -LogFile $LogFile
        }
    } catch {
        Write-Log "  No se pudo consultar Windows Update: $_" -Level WARNING -LogFile $LogFile
        Write-Log "  Verificar manualmente desde Configuracion > Windows Update" -Level WARNING -LogFile $LogFile
    }

    Write-Blank -LogFile $LogFile
}

#endregion

#region EJECUCION DE AUDITORIA

$inicio = Get-Date
Write-Log "Auditoria iniciada: $($inicio.ToString('dd/MM/yyyy HH:mm:ss'))" -LogFile $LogFile
Write-Blank -LogFile $LogFile

# SOFTWARE
Write-Section "AUDITORIA DE SOFTWARE" -LogFile $LogFile
Write-Blank -LogFile $LogFile

Invoke-AuditoriaCategoria -Titulo "RUNTIMES"      -Catalogo $catalogoRuntimes
Invoke-AuditoriaCategoria -Titulo "NAVEGADORES"   -Catalogo $catalogoNavegadores
Invoke-AuditoriaCategoria -Titulo "COMPRESORES"   -Catalogo $catalogoCompresores
Invoke-AuditoriaCategoria -Titulo "MULTIMEDIA"    -Catalogo $catalogoMultimedia
Invoke-AuditoriaCategoria -Titulo "COMUNICACION"  -Catalogo $catalogoComunicacion
Invoke-AuditoriaCategoria -Titulo "PRODUCTIVIDAD" -Catalogo $catalogoProductividad

# HARDWARE
Write-Section "AUDITORIA DE HARDWARE" -LogFile $LogFile
Write-Blank -LogFile $LogFile

Invoke-AuditoriaMonitores
Invoke-AuditoriaAudio
Invoke-AuditoriaRed
Invoke-AuditoriaUSB
Invoke-AuditoriaDispositivos

# WINDOWS
Write-Section "ESTADO DE WINDOWS" -LogFile $LogFile
Write-Blank -LogFile $LogFile

Invoke-AuditoriaDefender
Invoke-AuditoriaWindowsUpdate

#endregion

#region RESUMEN FINAL

$fin      = Get-Date
$duracion = [math]::Round(($fin - $inicio).TotalSeconds, 1)

Write-Section "RESUMEN" -LogFile $LogFile
Write-Blank -LogFile $LogFile
Write-Log "Auditoria finalizada: $($fin.ToString('dd/MM/yyyy HH:mm:ss'))" -LogFile $LogFile
Write-Log "Duracion            : $duracion segundos" -LogFile $LogFile
Write-Blank -LogFile $LogFile
Write-Section -LogFile $LogFile
Write-Log "Log guardado en: $LogFile" -LogFile $LogFile
Write-Blank

Invoke-Pause

#endregion