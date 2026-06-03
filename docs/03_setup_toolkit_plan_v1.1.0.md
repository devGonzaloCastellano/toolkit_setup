# Windows Setup Toolkit - Planificacion v1.1.0

## Historial de versiones del plan

| Version | Fecha      | Descripcion                                      |
|---------|------------|--------------------------------------------------|
| v1.0.0  | 2026-05-xx | Plan inicial                                     |
| v1.1.0  | 2026-06-02 | Revision arquitectonica post hallazgos iniciales |

---

## Vision general

Toolkit portable desarrollada en PowerShell para la configuracion inicial
y mantenimiento de equipos Windows.

La toolkit no asume estado cero. Puede ejecutarse sobre equipos recien
formateados, equipos parcialmente configurados o equipos de clientes con
software preexistente.

Su funcion principal es auditar el estado del sistema, determinar que
falta o esta desactualizado, y ejecutar las acciones necesarias con
evidencia registrada.

Complementa la Portable Windows Toolkit dentro de un ecosistema de
toolkits independientes:

```
Ecosistema (futuro)
|-- Portable Windows Toolkit  -> diagnostico, mantenimiento, reparacion
|-- Windows Setup Toolkit     -> auditoria, configuracion e implementacion
`-- Windows ISO Toolkit       -> creacion de medios e instalacion de Windows
```

---

## Nombre del proyecto

**Windows Setup Toolkit**

---

## Cambio de enfoque arquitectonico (v1.1.0)

### Diseno original (v1.0.0)
La toolkit instala software post-formato.

### Diseno actualizado (v1.1.0)
La toolkit audita el sistema, determina necesidades y ejecuta
instalaciones, actualizaciones o configuraciones segun corresponda.

La instalacion pasa a ser una accion derivada del diagnostico previo.

### Flujo general por modulo
```
[ Auditoria del modulo ]
         |
         v
[ Clasificacion de estados ]
  INSTALLED -> omitir
  OUTDATED  -> informar + preguntar si actualizar
  MISSING   -> instalar
  UNKNOWN   -> intentar instalar + advertencia
         |
         v
[ Ejecucion segun estados ]
         |
         v
[ Mini reporte del modulo ]
```

---

## Entorno de pruebas

El desarrollo se valida sobre maquinas virtuales en VirtualBox:
- Windows 10 (VM dedicada)
- Windows 11 (VM dedicada)

Razon: el equipo de desarrollo tiene software preexistente que impide
validar el comportamiento real de los modulos de instalacion.
Las VMs proveen un entorno limpio y reproducible para cada prueba.

---

## Estados de componentes

### Estados v1.x

| Estado    | Descripcion                                              |
|-----------|----------------------------------------------------------|
| INSTALLED | Componente presente y en version recomendada             |
| MISSING   | Componente no instalado                                  |
| OUTDATED  | Version instalada inferior a la recomendada              |
| UNKNOWN   | No fue posible determinar el estado con certeza          |

### Estados futuros (v2.x)

| Estado     | Descripcion                                             |
|------------|---------------------------------------------------------|
| CORRUPTED  | Instalacion danada o incompleta                         |
| REPAIRABLE | Instalacion valida que requiere reparacion              |

---

## Scope v1.0.0

### Incluido
- Auditoria global del sistema (system_audit.ps1)
- Instalacion de software via winget (seleccion interactiva por categoria)
- Presets de perfil como punto de partida (Hogar, Oficina, Developer)
- Runtimes y redistribuibles offline (Visual C++, .NET, DirectX)
- Drivers via SDIO para deteccion automatica
- Tres caminos para Office (Microsoft 365, ODT offline, LibreOffice)
- Configuraciones iniciales de Windows (privacidad, energia, actualizaciones)
- Sistema de logs con mismo formato que Portable Windows Toolkit
- Mini reporte por modulo al finalizar cada instalacion
- Reporte global exportable (pre y post implementacion)

### Fuera de scope v1.0.0
- Instalacion desatendida de Windows (toolkit separada futura)
- Activaciones de software no licenciadas
- Drivers de GPU (demasiado variables, se delega al cliente)
- Impresoras y perifericos especificos por cliente
- Estados CORRUPTED / REPAIRABLE (v2.x)

---

## Estructura del proyecto

```
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
|   |-- productividad.ps1
|   |-- comunicacion.ps1
|   |-- developer.ps1
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

## Menu principal

```
==========================================
   WINDOWS SETUP TOOLKIT v1.0.0
==========================================

 -- AUDITORIA --
  [1] Auditoria del sistema

 -- SETUP RAPIDO --
  [2] Setup completo (seleccionar perfil)

 -- POR CATEGORIA --
  [3] Runtimes y redistribuibles
  [4] Navegadores
  [5] Compresores
  [6] Multimedia
  [7] Productividad y Office
  [8] Comunicacion
  [9] Developer
  [10] Drivers

 -- WINDOWS --
  [11] Configuraciones iniciales de Windows

  [0] Salir
==========================================
```

Razon del orden: la auditoria es la primera accion que realiza el
tecnico al llegar a un equipo. Debe estar en la opcion mas accesible
del menu y ser el punto de partida natural del flujo de trabajo.

---

## Arquitectura de auditoria

### system_audit.ps1

Modulo de auditoria global. No instala nada.

Responsabilidades:
- Recorrer el catalogo completo de componentes de todos los modulos
- Determinar el estado de cada componente (INSTALLED/MISSING/OUTDATED/UNKNOWN)
- Mostrar reporte en consola con colores por estado
- Exportar reporte a archivo en /logs

Casos de uso:
1. Pre-implementacion: el tecnico audita antes de trabajar para ver
   que necesita el equipo
2. Post-implementacion: el tecnico audita al finalizar para verificar
   que todo quedo correctamente instalado y generar evidencia

### Auditoria por modulo

Cada modulo de instalacion (runtimes.ps1, navegadores.ps1, etc.)
realiza su propia auditoria antes de actuar:

- Consulta el estado de sus componentes especificos
- Omite los INSTALLED
- Informa los OUTDATED y pregunta si actualizar
- Instala los MISSING
- Advierte sobre los UNKNOWN e intenta instalar

Al finalizar genera un mini reporte con el resultado de cada componente.

### Get-WingetPackageStatus (Utils.ps1)

Funcion compartida que todos los modulos usan para auditar.
Recibe un package ID de winget y devuelve el estado del componente.

```
Get-WingetPackageStatus -PackageId "Google.Chrome"
-> INSTALLED | OUTDATED | MISSING | UNKNOWN
```

---

## Catalogo de software

### Runtimes y redistribuibles (siempre, sin pregunta)

| Componente                        | Arquitectura | Razon                                    |
|-----------------------------------|--------------|------------------------------------------|
| Visual C++ Redistributable 2015-2022 | x64 + x86 | Dependencia de casi toda aplicacion moderna |
| Visual C++ Redistributable 2013   | x64 + x86    | Aplicaciones y juegos legacy             |
| Visual C++ Redistributable 2010   | x64 + x86    | Software industrial y legacy             |
| .NET Runtime 6 LTS                | x64          | Aplicaciones modernas                    |
| .NET Runtime 8 LTS                | x64          | Aplicaciones modernas                    |
| .NET Framework 3.5                | -            | Aplicaciones y juegos viejos             |
| DirectX End-User Runtime          | -            | Juegos y aplicaciones multimedia legacy  |

Nota sobre arquitectura: Windows 10/11 es 64 bits en la gran mayoria
de los equipos actuales. Se incluye x86 solo en Visual C++ porque
muchas aplicaciones de 32 bits corren sobre Windows 64 bits y necesitan
la version x86 del runtime igual.

---

### Navegadores

| Programa | Pros                                                        | Contras                              | Default |
|----------|-------------------------------------------------------------|--------------------------------------|---------|
| Chrome   | Estandar de facto, compatibilidad maxima, sincronizacion Google | Alto consumo RAM/CPU, telemetria | Si      |
| Brave    | Motor Chromium, bajo consumo, bloqueador nativo, sin telemetria | Menos conocido para no tecnicos  | Si      |
| Firefox  | Independiente de Chromium, privacidad, bajo consumo        | Menor compatibilidad corporativa     | Opcional|
| Edge     | Ya instalado en Windows                                     | Telemetria Microsoft agresiva        | No tocar|

---

### Compresores

| Programa | Pros                                      | Contras              | Default  |
|----------|-------------------------------------------|----------------------|----------|
| 7-Zip    | Gratuito, open source, mejor compresion   | Interfaz anticuada   | Si       |
| WinRAR   | Formato RAR, muy conocido                 | Propietario (trial)  | Opcional |
| NanaZip  | Fork moderno de 7-Zip, UI Windows 11      | Mas nuevo            | Opcional |

---

### Multimedia

| Programa      | Perfil           | Default  |
|---------------|------------------|----------|
| VLC           | Todos            | Si       |
| Spotify       | Hogar            | Hogar    |
| OBS Studio    | Developer/Creativo | Opcional |
| DaVinci Resolve | Creativo       | Opcional |

---

### Productividad

| Programa          | Notas                                   | Default            |
|-------------------|-----------------------------------------|--------------------|
| Microsoft 365     | Requiere cuenta activa del cliente      | Si el cliente tiene|
| Office 2021/2024  | Requiere clave del cliente (ODT)        | Si el cliente tiene|
| LibreOffice       | Gratuito, para equipos sin licencia     | Hogar sin licencia |
| Adobe Acrobat Reader | Estandar PDF                         | Si                 |
| Sumatra PDF       | Liviano, alternativa a Acrobat          | Alternativa        |

Nota: la toolkit no resuelve licencias. Ofrece los tres caminos de
instalacion y el cliente activa con sus credenciales. No se incluyen
activaciones KMS ni herramientas de crackeo.

---

### Comunicacion

| Programa         | Perfil              |
|------------------|---------------------|
| Teams            | Oficina             |
| Zoom             | Oficina / Hogar     |
| Slack            | Oficina / Developer |
| WhatsApp Desktop | Hogar               |
| Anydesk          | Soporte remoto      |
| TeamViewer       | Soporte remoto      |

---

### Developer

| Programa        | Notas                              |
|-----------------|------------------------------------|
| Git             | Incluir configuracion inicial      |
| VSCode          | Extensiones se configuran despues  |
| Windows Terminal | Ya viene en Win11, instalar Win10 |
| JDK (Corretto/Temurin) | LTS mas reciente            |
| Node.js LTS     | Incluir npm                        |
| Docker Desktop  | Requiere WSL2 habilitado           |
| Postman         |                                    |
| Python          | Agregar al PATH automaticamente    |

---

## Presets de perfil

Los presets son puntos de partida, no configuraciones fijas.
El tecnico puede ajustar la seleccion antes de instalar.

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

### Privacidad
- Deshabilitar telemetria basica
- Deshabilitar publicidad personalizada
- Deshabilitar sugerencias en el menu inicio

### Energia
- Plan de energia: Alto rendimiento (desktop) / Balanceado (notebook)
- Deshabilitar suspension al cerrar tapa (opcional, preguntar)

### Sistema
- Zona horaria correcta
- Nombre del equipo (preguntar al tecnico)
- Actualizaciones: verificar y dejar configuradas
- Mostrar extensiones de archivo
- Mostrar archivos ocultos (opcional)

### Windows Defender
- Verificar que este activo y actualizado

---

## Decisiones de arquitectura

### Utils.ps1
Se copia desde la Portable Windows Toolkit y se mantiene independiente.
Cada toolkit gestiona su propio Utils.ps1.
Razon: independencia de ambitos, cada toolkit escala por separado.
Nota para el README: aclarar que Utils.ps1 es una copia deliberada
y que cambios en una toolkit no se propagan automaticamente a la otra.

### Funciones nuevas en Utils.ps1 (v1.1.0)
- Test-InternetConnection : verifica conexion antes de instalar online
- Test-Winget             : verifica disponibilidad de winget
- Test-DiskSpace          : verifica espacio antes de instalaciones offline
- Get-WingetPackageStatus : audita el estado de un paquete winget
                            (INSTALLED / OUTDATED / MISSING / UNKNOWN)

### Verificacion de dependencias
La toolkit verifica antes de ejecutar:
- Presencia de winget (viene en Windows 10 1809+ y Windows 11)
- Conexion a internet para instalaciones online
- Espacio disponible en disco para instalaciones offline
Si algo falla, informa claramente y ofrece alternativa cuando existe.
Nunca trabaja sobre suposiciones.

### Logs
Mismo sistema que la Portable Windows Toolkit:
- Mismo formato de Write-Log con niveles y colores
- Mismo Initialize-Environment para generacion de archivos con timestamp
- Mismo Invoke-Pause al finalizar cada modulo
- Guardados en /logs con prefijo del modulo

### Plantilla de modulo
Igual que la Portable Windows Toolkit:
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

## Planificacion de versiones

### v1.0.0 (en desarrollo)
- Estructura base del proyecto
- lib/Utils.ps1 con funciones de auditoria
- menu.ps1 con navegacion por categorias (auditoria en opcion 1)
- launcher.bat
- system_audit.ps1 (auditoria global)
- runtimes.ps1
- navegadores.ps1
- compresores.ps1
- multimedia.ps1
- productividad.ps1 (con los tres caminos de Office)
- comunicacion.ps1
- developer.ps1
- drivers.ps1 (SDIO)
- configurar.ps1
- setup_completo.ps1 con presets

### v1.1.0 (planificada)
- Preset personalizable y guardable por el tecnico
- Log de setup exportable como resumen para el cliente
- Soporte para agregar software custom a los presets
- Verificacion de versiones instaladas antes de reinstalar

### v2.0.0 (futuro)
- Estados CORRUPTED y REPAIRABLE
- A evaluar segun necesidades que surjan en v1.x

---

## Notas de integracion futura

Las tres toolkits del ecosistema son ambitos separados e independientes.
Cada una escala por su cuenta. La integracion futura en una aplicacion
Python unificada es una decision de largo plazo que no condiciona el
desarrollo actual de ninguna de las tres.

Lo que conviene mantener consistente entre toolkits para facilitar
esa futura integracion:
- Mismo formato de logs
- Misma plantilla de modulo
- Mismo sistema de niveles (INFO, SUCCESS, WARNING, ERROR)
- Utils.ps1 sincronizado manualmente cuando haya mejoras relevantes