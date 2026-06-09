# Windows Setup Toolkit - Planificación v1.0.0

## Vision general

Toolkit portable desarrollada en PowerShell para la configuración inicial
de equipos Windows post-formato. Complementa la Portable Windows Toolkit:
una diagnostica y repara, esta configura desde cero.

Forma parte de un ecosistema de toolkits independientes y portables:

```
Ecosistema (futuro)
|-- Portable Windows Toolkit  -> diagnostico, mantenimiento, reparacion
|-- Windows Setup Toolkit     -> configuracion inicial post-formato
`-- Windows ISO Toolkit       -> creacion de medios e instalacion de Windows
```

Cada toolkit es un ámbito separado e independiente, con posibilidad de
integración futura. La idea a largo plazo es unificarlas en una aplicación
Python cuando las tres estén maduras.

---

## Nombre del proyecto

**Windows Setup Toolkit**

---

## Scope v1.0.0

### Incluido
- Instalación de software via winget (selección interactiva por categoría)
- Presets de perfil como punto de partida (Hogar, Oficina, Developer)
- Runtimes y redistribuibles offline (Visual C++, .NET, DirectX)
- Drivers via SDIO para detección automática
- Tres caminos para Office (Microsoft 365, ODT offline, LibreOffice)
- Configuraciones iniciales de Windows (privacidad, energía, actualizaciones)
- Sistema de logs con mismo formato que Portable Windows Toolkit

### Fuera de scope v1.0.0
- Instalación desatendida de Windows (toolkit separada futura)
- Activaciones de software no licenciadas
- Drivers de GPU (demasiado variables, se delega al cliente)
- Impresoras y periféricos específicos por cliente

---

## Estructura del proyecto

```
windows-setup-toolkit/
|-- launcher.bat
|-- menu.ps1
|-- lib/
|   `-- Utils.ps1
|-- scripts/
|   |-- runtimes.ps1
|   |-- navegadores.ps1
|   |-- compresores.ps1
|   |-- multimedia.ps1
|   |-- productividad.ps1
|   |-- drivers.ps1
|   |-- configurar.ps1
|   `-- setup_completo.ps1
|-- instaladores/
|   |-- runtimes/
|   |-- office/
|   `-- drivers/
`-- logs/
```

---

## Decisiones de arquitectura

### Utils.ps1
Se copia desde la Portable Windows Toolkit y se mantiene independiente.
Cada toolkit gestiona su propio Utils.ps1.
Razón: independencia de ámbitos, cada toolkit escala por separado.
Nota para el README: aclarar que Utils.ps1 es una copia deliberada
y que cambios en una toolkit no se propagan automáticamente a la otra.

### Verificación de dependencias
La toolkit verifica antes de ejecutar:
- Presencia de winget (viene en Windows 10 1809+ y Windows 11)
- Conexión a internet para instalaciones online
- Espacio disponible en disco para instalaciones offline
Si algo falla, informa claramente y ofrece alternativa cuando existe.
Nunca trabaja sobre suposiciones.

### Logs
Mismo sistema que la Portable Windows Toolkit:
- Mismo formato de Write-Log con niveles y colores
- Mismo Initialize-Environment para generación de archivos con timestamp
- Mismo Invoke-Pause al finalizar cada modulo
- Guardados en /logs con prefijo del modúlo

### Plantilla de modúlo
Igual que la Portable Windows Toolkit:
```
SYNOPSIS / DESCRIPTION / NOTES
PARAMETROS      ($LogDir, $NoElevation)
IMPORTS         (dot-sourcing de Utils.ps1)
AUTO-ELEVACION
INICIALIZACION  (Initialize-Environment)
LOGICA PRINCIPAL
RESUMEN
```

---

## Catalogo de software

### Runtimes y redistribuibles (siempre, sin pregunta)
Se instalan en todos los setups porque son dependencias de la mayoría
de las aplicaciones. Van offline en el pendrive.

| Componente                            | Arquitectura | Razón                                       |
|---------------------------------------|--------------|---------------------------------------------|
| Visual C++ Redistributable 2015-2022  | x64 + x86    | Dependencia de casi toda aplicación moderna |
| Visual C++ Redistributable 2013       | x64 + x86    | Aplicaciones y juegos legacy                |
| Visual C++ Redistributable 2010       | x64 + x86    | Software industrial y legacy                |
| .NET Runtime 6 LTS                    | x64          | Aplicaciones modernas                       |
| .NET Runtime 8 LTS                    | x64          | Aplicaciones modernas                       |
| .NET Framework 3.5                    | -            | Aplicaciones y juegos viejos                |
| DirectX End-User Runtime              | -            | Juegos y aplicaciones multimedia legacy     |

Nota sobre arquitectura: Windows 10/11 es 64 bits en la gran mayoría
de los equipos actuales. Se incluye x86 solo en Visual C++ porque
muchas aplicaciones de 32 bits corren sobre Windows 64 bits y necesitan
la version x86 del runtime igual.

---

### Navegadores

| Programa | Pros                                                                                   | Contras                                       | Instalación   | Default     |
|----------|----------------------------------------------------------------------------------------|-----------------------------------------------|---------------|-------------|
| Chrome   | Estándar de facto, compatibilidad maxima, sincronización Google                        | Alto consumo RAM/CPU, telemetría agresiva     | winget online | Si          |
| Brave    | Motor Chromium (misma compatibilidad), bajo consumo, bloqueador nativo, sin telemetría | Menos conocido para usuarios no técnicos      | winget online | Si          |
| Firefox  | Independiente de Chromium, muy personalizable, privacidad, bajo consumo                | Menor compatibilidad en sitios corporativos   | winget online | Opcional    |
| Edge     | Ya instalado en Windows                                                                | Telemetría Microsoft, se impone agresivamente | Ya presente   | No instalar |

Recomendación: ofrecer Chrome, Brave y Firefox como opciones seleccionables.
El técnico elige según el perfil del cliente. Edge ya esta, no se toca.

---

### Compresores

| Programa | Pros                                                   | Contras                                          | Instalación    | Default  |
|----------|--------------------------------------------------------|--------------------------------------------------|----------------|----------|
| 7-Zip    | Gratuito, open source, mejor compresión en 7z, liviano | Interfaz anticuada                               | winget/offline | Si       |
| WinRAR   | Formato RAR, mas funcionalidades, muy conocido         | De pago (trial sin vencimiento pero propietario) | winget/offline | Opcional |
| NanaZip  | Fork moderno de 7-Zip, UI integrada a Windows 11       | Mas nuevo, menos probado                         | winget online  | Opcional |

Recomendación: 7-Zip como default. WinRAR como opción para quien lo necesite.
No se incluyen activaciones ni licencias crackeadas.

---

### Multimedia

| Programa        | Pros                                           | Contras                           | Instalación     | Default            |
|-----------------|------------------------------------------------|-----------------------------------|-----------------|--------------------|
| VLC             | Reproduce cualquier formato, gratuito, liviano | UI algo anticuada                 | winget/offline  | Si                 |
| Spotify         | Estándar para musica streaming                 | Requiere cuenta, consume recursos | winget online   | Hogar              |
| OBS Studio      | Grabación y streaming profesional              | Complejo para usuarios básicos    | winget online   | Developer/Creativo |
| DaVinci Resolve | Edición de video profesional gratuita          | Muy pesado (~3 GB)                | Descarga manual | Creativo           |

---

### Productividad

| Programa               | Pros                                                  | Contras                                 | Instalación             | Default             |
|------------------------|-------------------------------------------------------|-----------------------------------------|-------------------------|---------------------|
| Microsoft 365          | Siempre actualizado, integración completa             | Requiere suscripción activa del cliente | Online (cuenta cliente) | Si el cliente tiene |
| Office 2021/2024 (ODT) | Licencia perpetua, offline                            | Requiere clave de producto del cliente  | Offline via ODT         | Si el cliente tiene |
| LibreOffice            | Gratuito, open source, compatible con formatos Office | Menos pulido que Office                 | winget/offline          | Hogar sin licencia  |
| Adobe Acrobat Reader   | Estándar para PDF                                     | Algo pesado, telemetría                 | winget online           | Si                  |
| Sumatra PDF            | Liviano, rápido, gratuito                             | Menos funcionalidades que Acrobat       | winget online           | Alternativa         |

Nota sobre Office: la toolkit no resuelve el tema de licencias.
Ofrece tres caminos de instalación y el cliente activa con sus credenciales.
No se incluyen activaciones KMS ni herramientas de crackeo.

---

### Comunicación y colaboración

| Programa         | Perfil            | Instalación   |
|------------------|-------------------|---------------|
| Teams            | Oficina           | winget online |
| Zoom             | Oficina/Hogar     | winget online |
| Slack            | Oficina/Developer | winget online |
| WhatsApp Desktop | Hogar             | winget online |
| Anydesk          | Soporte remoto    | winget online |
| TeamViewer       | Soporte remoto    | winget online |

---

### Developer

| Programa               | Notas                                       | Instalación   |
|------------------------|---------------------------------------------|---------------|
| Git                    | Incluir configuración inicial (user, email) | winget online |
| VSCode                 | Extensiones se configuran después           | winget online |
| Windows Terminal       | Ya viene en Win11, instalar en Win10        | winget online |
| JDK (Corretto/Temurin) | LTS mas reciente                            | winget online |
| Node.js LTS            | Incluir npm                                 | winget online |
| Docker Desktop         | Requiere WSL2 habilitado                    | winget online |
| Postman                |                                             | winget online |
| Python                 | Agregar al PATH automáticamente             | winget online |

---

### Drivers

Estrategia por tipo:

**Offline en el pendrive:**
- SDIO (Snappy Driver Installer Origin) - detecta hardware e instala
  chipset, red (Ethernet y WiFi) y audio automáticamente

**¿Por qué SDIO y no archivos estáticos?:**
Los drivers son altamente específicos por fabricante y modelo.
Realtek, Intel, Qualcomm, Broadcom, AMD - cada uno con versiones
distintas por hardware. SDIO resuelve esto con una base de datos
actualizable sin necesidad de llevar carpetas de drivers por separado.

**Drivers que NO incluye la toolkit:**
- GPU (NVIDIA/AMD/Intel) - pesan entre 500 MB y 1 GB, se actualizan
  cada pocas semanas. Se delegan a GeForce Experience / AMD Software
  post-setup o descarga directa desde el sitio del fabricante.
- Impresoras y periféricos específicos - demasiado variables por cliente.

---

## Presets de perfil

Los presets son puntos de partida, no configuraciones fijas.
El técnico puede ajustar la selección antes de instalar.

### Hogar
```
Navegadores  : Brave, Chrome
Compresores  : 7-Zip
Multimedia   : VLC, Spotify
Productividad: LibreOffice, Adobe Reader
Comunicacion : WhatsApp Desktop
```

### Oficina
```
Navegadores  : Chrome
Compresores  : 7-Zip
Multimedia   : VLC
Productividad: Office (segun licencia del cliente), Adobe Reader
Comunicacion : Teams, Zoom, Anydesk
```

### Developer
```
Navegadores  : Chrome, Firefox
Compresores  : 7-Zip
Multimedia   : VLC
Productividad: Adobe Reader
Dev          : Git, VSCode, Windows Terminal, JDK, Node, Docker, Postman
```

### Creativo
```
Navegadores  : Chrome, Brave
Compresores  : 7-Zip
Multimedia   : VLC, OBS Studio
Productividad: Adobe Reader, LibreOffice o Office
Diseno       : GIMP, Inkscape, DaVinci Resolve
```

---

## Configuraciones iniciales de Windows

Tweaks que se aplican en el modulo configurar.ps1:

**Privacidad:**
- Deshabilitar telemetría básica
- Deshabilitar publicidad personalizada
- Deshabilitar sugerencias en el menu inicio

**Energía:**
- Plan de energía: Alto rendimiento (desktop) / Balanceado (notebook)
- Deshabilitar suspension al cerrar tapa (opcional, preguntar)

**Sistema:**
- Zona horaria correcta
- Nombre del equipo (preguntar al técnico)
- Actualizaciones: verificar y dejar configuradas
- Mostrar extensiones de archivo
- Mostrar archivos ocultos (opcional)

**Windows Defender:**
- Verificar que este activo y actualizado

---

## Menu principal

```
==========================================
   WINDOWS SETUP TOOLKIT v1.0.0
==========================================

 -- SETUP RAPIDO --
  [1] Setup completo (seleccionar perfil)

 -- POR CATEGORIA --
  [2] Runtimes y redistribuibles
  [3] Navegadores
  [4] Compresores
  [5] Multimedia
  [6] Productividad y Office
  [7] Comunicacion
  [8] Developer
  [9] Drivers

 -- WINDOWS --
  [10] Configuraciones iniciales de Windows

  [0] Salir
==========================================
```

---

## Planificación de versiones

### v1.0.0 (inicial)
- Estructura base del proyecto
- lib/Utils.ps1 (copia de Portable Windows Toolkit)
- menu.ps1 con navegación por categorías
- launcher.bat
- runtimes.ps1 (offline)
- navegadores.ps1
- compresores.ps1
- multimedia.ps1
- productividad.ps1 (con los tres caminos de Office)
- drivers.ps1 (SDIO)
- configurar.ps1
- setup_completo.ps1 con presets

### v1.1.0 (planificada)
- Preset personalizable y guardable por el técnico
- Verificación de versiones instaladas antes de reinstalar
- Log de setup exportable como resumen para el cliente
- Soporte para agregar software custom a los presets

### v2.0.0 (futuro)
- A evaluar según necesidades que surjan en v1.x

---

## Notas de integración futura

Las tres toolkits del ecosistema son ámbitos separados e independientes.
Cada una escala por su cuenta. La integración futura en una aplicación
Python unificada es una decision de largo plazo que no condiciona el
desarrollo actual de ninguna de las tres.

Lo que si conviene mantener consistente entre toolkits para facilitar
esa futura integración:
- Mismo formato de logs
- Misma plantilla de modulo
- Mismo sistema de niveles (INFO, SUCCESS, WARNING, ERROR)
- Utils.ps1 sincronizado manualmente cuando haya mejoras relevantes