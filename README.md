# Windows Setup Toolkit

Toolkit portable desarrollada en PowerShell para la configuración inicial
y mantenimiento de equipos Windows.

La toolkit no asume estado cero. Puede ejecutarse sobre equipos recién
formateados, equipos parcialmente configurados o equipos de clientes con
software preexistente. Su funcion principal es auditar el estado del sistema,
determinar que falta o esta desactualizado, y ejecutar las acciones necesarias
con evidencia registrada.

Actualmente el sistema se encuentra en su Version 1 (v1.0.0).

---

## ⚡ Uso rápido
1. Clonar o descargar el repositorio
2. Colocar el ejecutable de SDIO en `instaladores/drivers/` (opcional, para el modúlo de drivers)
3. Ejecutar `launcher.bat` como administrador
4. Seleccionar la opción deseada desde el menú

> El launcher solícita elevación UAC automáticamente
> Todos los módulos corren en la misma ventana de PowerShell.

---

## Funcionalidades

### 🔍 Auditoria del sistema
- Estado de todos los componentes de software por categoría
- Dispositivos conectados: monitores, audio, red, USB
- Detección de dispositivos con errores en el Administrador de dispositivos
- Estado de Windows Defender y definiciones
- Verificación de actualizaciones de Windows pendientes
- Timestamp de inicio, fin y duración de la auditoria
- Exportación automática a log con evidencia del estado del sistema

### ⚙️ Runtimes y redistribuibles
- Visual C++ Redistributable 2010, 2013 y 2015-2022 (x64 y x86)
- .NET Desktop Runtime 6 LTS y 8 LTS
- DirectX End-User Runtime
- .NET Framework 3.5 via características de Windows
- Auditoria previa con estados INSTALLED / OUTDATED / MISSING / UNKNOWN
- Instalación o actualización selectiva según resultado de auditoria

### 🌐 Navegadores
- Chrome, Brave, Firefox
- Edge mostrado como informativo (ya incluido en Windows, no se toca)
- Detección de instalaciones realizadas fuera de winget
- Submenu interactivo con estado visual de cada navegador
- Reporte con estado previo y final

### 🗜️ Compresores
- 7-Zip, WinRAR, NanaZip
- Submenu interactivo con estado visual
- Reporte con acciones realizadas

### 🎵 Multimedia
- VLC, Spotify, OBS Studio
- Submenu interactivo con estado visual
- Reporte con acciones realizadas

### 💬 Comunicación
- Teams, Zoom, Slack, WhatsApp Desktop, AnyDesk, TeamViewer
- Detección de instalaciones realizadas fuera de winget (Zoom)
- Perfil de uso visible en el submenu (Oficina / Hogar / Soporte remoto)
- Reporte con acciones realizadas

### 📄 Productividad
- Office: tres caminos de instalación
    - Microsoft 365 (requiere cuenta activa del cliente)
    - Office ODT con instrucciones de activación
    - LibreOffice (gratuito, con advertencia de compatibilidad)
- PDF: Adobe Acrobat Reader, Foxit PDF Reader, Sumatra PDF
- Utilidades: Notepad++
- Detección de Office y Adobe instalados fuera de winget
- Advertencias informativas antes de instalar Office

### 🔧 Drivers
- Lanzador de SDIO (Snappy Driver Installer Origin)
- Detección automática del ejecutable en `instaladores/drivers/`
- Registro de duración de la sesión de instalación de drivers
- Instrucciones claras si SDIO no esta disponible

### 🪟 Configuraciones de Windows
- Privacidad: telemetría, publicidad personalizada, sugerencias de inicio
- Energía: plan optimo según tipo de equipo (desktop / notebook)
- Sistema: zona horaria, nombre del equipo, extensiones de archivo, archivos ocultos
- Actualizaciones: apertura de Windows Update
- Seguridad: verificación de Windows Defender
- Opción para aplicar todas las recomendadas de una sola vez

### 🚀 Setup completo con presets
- Perfil Hogar: Chrome, Brave, 7-Zip, VLC, Spotify, LibreOffice, Adobe Reader, WhatsApp
- Perfil Oficina: Chrome, 7-Zip, VLC, Office, Adobe Reader, Teams, Zoom, AnyDesk
- Perfil Creativo: Chrome, Brave, 7-Zip, VLC, OBS Studio, LibreOffice, Adobe Reader
- Vista previa del preset antes de confirmar
- Ejecución en secuencia de los módulos correspondientes
- Resumen final con estado de cada modúlo y duración total

---

## Arquitectura del proyecto

### Estructura

```text
windows-setup-toolkit/
|-- launcher.bat
|-- menu.ps1
|-- lib/
|   `-- Utils.ps1
|-- scripts/
|   |-- system_audit.ps1
|   |-- runtimes.ps1
|   |-- navegadores.ps1
|   |-- compresores.ps1
|   |-- multimedia.ps1
|   |-- comunicacion.ps1
|   |-- productividad.ps1
|   |-- drivers.ps1
|   |-- configurar.ps1
|   `-- setup_completo.ps1
|-- instaladores/
|   |-- runtimes/
|   |-- office/
|   `-- drivers/
|-- docs/
|   |-- 01_setup_toolkit_plan_v1.0.0.md
|   |-- 02_revision_v1.md
|   |-- 03_setup_toolkit_plan_v1.1.0.md
|   `-- 04_review_v1.0.0.md
`-- logs/
```

La estructura está pensada para facilitar:
- mantenibilidad
- modularidad
- portabilidad
- escalabilidad futura

### lib/Utils.ps1
Modulo compartido importado via dot-sourcing por todos los scripts.
Provee: `Write-Log`, `Write-Blank`, `Write-Section`, `Initialize-Environment`,
`Test-IsAdmin`, `Invoke-Elevate`, `Format-Bytes`, `Invoke-Pause`,
`Test-InternetConnection`, `Test-Winget`, `Test-DiskSpace`,
`Get-WingetPackageStatus`.

> Utils.ps1 es una copia deliberada e independiente del Utils.ps1 de la
> Portable Windows Toolkit. Cada toolkit gestiona su propio modúlo.
> Los cambios en una toolkit no se propagan automáticamente a la otra.

### launcher.bat
Único archivo `.bat` del proyecto. Su único trabajo es elevar PowerShell
y lanzar `menu.ps1`. Toda la lógica vive en los scripts `.ps1`.

### Plantilla de modúlo
Cada script sigue la misma estructura:
```
SYNOPSIS / DESCRIPTION / NOTES
PARAMETROS      ($LogDir, $NoElevation)
IMPORTS         (dot-sourcing de Utils.ps1)
AUTO-ELEVACION
INICIALIZACION  (Initialize-Environment)
AUDITORIA       (Get-WingetPackageStatus por componente)
LOGICA PRINCIPAL (instalar / actualizar segun auditoria)
MINI REPORTE
RESUMEN
```

---

## Requisitos

- Windows 10 1809 o superior / Windows 11
- PowerShell 5.1 (incluido en Windows por defecto)
- winget (App Installer) — viene preinstalado en Windows 10 1809+ y Windows 11
- Conexión a internet para instalaciones online
- SDIO en `instaladores/drivers/` para el modúlo de drivers (opcional)

---

## Seguridad y elevacion de privilegios

El toolkit cuenta con un sistema de auto-elevación de privilegios.
Al ejecutarse, el script verifica si cuenta con permisos de administrador.
De no ser asi, solicita acceso mediante UAC utilizando PowerShell.

**¿Por que requiere permisos?**
- Instalación de software via winget
- Modificación de configuraciones del sistema (registro, energía, zona horaria)
- Habilitación de características de Windows (.NET Framework 3.5)
- Consulta de estado de Windows Defender y Windows Update
- Renombrado del equipo

---

## Logs

Cada modúlo genera un log automático en `/logs` con timestamp:
```
logs/
|-- system_audit_2026-06-06_10-20.txt
|-- runtimes_2026-06-04_10-08.txt
|-- navegadores_2026-06-04_15-25.txt
`-- ...
```

El log contiene el mismo output que la consola, sin colores ANSI.
Puede usarse como evidencia del trabajo realizado ante el cliente.

---

## Limitaciones conocidas

- La detección de estado via winget puede no funcionar correctamente
  con aplicaciones instaladas fuera de winget mediante sus instaladores
  nativos. Se implementaron mecanismos de fallback para los casos mas
  comunes (Chrome, Zoom, Adobe Acrobat, Microsoft Office).
- El modúlo de drivers depende de SDIO para la instalación de drivers.
  Los drivers de GPU (NVIDIA/AMD/Intel) y periféricos específicos quedan
  fuera del scope de SDIO y deben instalarse manualmente.
- Windows Update puede tardar hasta 15 segundos en responder durante
  la auditoria del sistema.
- La auditoria global (system_audit) puede tardar entre 60 y 90 segundos
  por las consultas a winget para cada componente del catálogo.

---

## Testing

Las pruebas fueron realizadas manualmente sobre el equipo de desarrollo
con Windows 10 Pro, validando:

- Ejecución y funcionamiento de cada modúlo
- Flujo de auditoria previa e instalación selectiva
- Detección de estados INSTALLED / OUTDATED / MISSING / UNKNOWN
- Manejo de aplicaciones instaladas fuera de winget
- Generación de logs
- Navegación entre menus
- Setup completo con presets

La validación sobre entornos limpios con Windows 10 y Windows 11
en máquinas virtuales VirtualBox queda pendiente para v1.1.0.

---

## Ecosistema

Este proyecto forma parte de un ecosistema de toolkits independientes:

```
|-- Portable Windows Toolkit  -> diagnostico, mantenimiento, reparacion
|-- Windows Setup Toolkit     -> auditoria, configuracion e implementacion
`-- Windows ISO Toolkit       -> creacion de medios e instalacion (futuro)
```

Cada toolkit es un ámbito separado e independiente con posibilidad de
integración futura en una aplicación unificada.

---

## Versionado

### Version 1.0.0 (Actual)
- Estructura base del proyecto
- lib/Utils.ps1 con funciones de auditoria (Get-WingetPackageStatus)
- Menu principal con navegación por categorías
- system_audit.ps1: auditoria global de software y hardware
- runtimes.ps1: runtimes y redistribuibles
- navegadores.ps1: Chrome, Brave, Firefox
- compresores.ps1: 7-Zip, WinRAR, NanaZip
- multimedia.ps1: VLC, Spotify, OBS Studio
- comunicación.ps1: Teams, Zoom, Slack, WhatsApp, AnyDesk, TeamViewer
- productividad.ps1: Office, PDF, Notepad++
- drivers.ps1: lanzador de SDIO
- configurar.ps1: configuraciones iniciales de Windows
- setup_completo.ps1: presets Hogar, Oficina, Creativo

### Version 1.1.0 (Planificada)
- Refactorización de código duplicado hacia Utils.ps1
- Formato uniforme de etiquetas en logs con ancho fijo
- Opción de reinstalar Chrome/Zoom limpiamente via winget
- FiltroWinget activo en presets de setup_completo
- Preset personalizable y guardable por el técnico
- Log exportable como resumen para el cliente
- Validación completa en VMs con Windows 10 y Windows 11

### Version 2.0.0 (Futuro)
- Estados CORRUPTED y REPAIRABLE
- A evaluar según necesidades que surjan en v1.x

---

## Objetivo del proyecto

Este proyecto fue desarrollado con fines:
- formativos
- prácticos
- profesionales

con el objetivo de consolidar conocimientos en:

- scripting Windows
- automatización
- administración básica de sistemas
- soporte técnico
- análisis y diágnostico de equipos Windows

---

## Estado actual

Version 1.0.0 finalizada.
El proyecto continúa evolucionando mediante mejoras progresivas,
refactorización y expansion de funcionalidades.