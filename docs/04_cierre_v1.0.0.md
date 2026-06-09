# Windows Setup Toolkit - Review de Cierre v1.0.0

## Fecha
2026-06-06

## Estado
v1.0.0 completada y funcional.

---

## Módulos implementados

| Modulo             | Estado      | Notas                                   |
|--------------------|-------------|-----------------------------------------|
| launcher.bat       | Completo    |                                         |
| menu.ps1           | Completo    |                                         |
| lib/Utils.ps1      | Completo    |                                         |
| system_audit.ps1   | Completo    | Auditoria global de software y hardware |
| runtimes.ps1       | Completo    |                                         |
| navegadores.ps1    | Completo    |                                         |
| compresores.ps1    | Completo    |                                         |
| multimedia.ps1     | Completo    |                                         |
| comunicación.ps1   | Completo    |                                         |
| productividad.ps1  | Completo    | Incluye tres caminos de Office          |
| drivers.ps1        | Completo    | Lanzador de SDIO                        |
| configurar.ps1     | Completo    | Configuraciones iniciales de Windows    |
| setup_completo.ps1 | Completo    | Presets: Hogar, Oficina, Creativo       |
| developer.ps1      | Eliminado   | Fuera de scope, ver decision más abajo  |

---

## Decisiones tomadas durante el desarrollo

### Cambio de enfoque arquitectónico
El plan original contemplaba una toolkit de instalación directa post-formato.
Durante el desarrollo se identificó que la toolkit podía ejecutarse sobre
equipos con software preexistente, lo que requirió incorporar una etapa de
auditoria previa antes de cualquier acción.

El flujo paso de:
```
Instalar
```
A:
```
Auditar -> Clasificar estado -> Instalar/Actualizar/Omitir -> Reportar
```

Los estados implementados fueron: INSTALLED, OUTDATED, MISSING, UNKNOWN.

### developer.ps1 eliminado del scope
El modúlo de herramientas de desarrollo fue eliminado de v1.0.0 porque
las herramientas de desarrollo son demasiado especifícas para el objetivo
de la toolkit, que es la configuración inicial general de equipos Windows.

Se evalúa la creación de una toolkit dedicada para entornos de desarrollo
como proyecto futuro independiente dentro del ecosistema.

### Manejo de aplicaciones instaladas fuera de winget
Durante las pruebas se detectó que aplicaciones como Chrome, Zoom y Adobe
Acrobat instaladas mediante sus instaladores nativos no son detectadas por
winget con su ID estándar.

Se implementaron dos estrategias:
- IdAlt: ID alternativo para paquetes con dos variantes (Chrome.EXE, Zoom.EXE)
- Detección por nombre: para aplicaciones sin ID alternativo confiable
  (Adobe Acrobat, Microsoft Office)

### SDIO en modo informativo
El modúlo de drivers no descarga SDIO automáticamente. Si el ejecutable
no está presente en instaladores/drivers/, el script informa al técnico
donde descargarlo manualmente y como usarlo correctamente.

Se documentó el uso recomendado de Expert Mode para instalar solo los
drivers necesarios en lugar de los 73 packs disponibles.

### DaVinci Resolve fuera de scope
DaVinci Resolve fue excluido del modúlo multimedia porque pesa ~3GB
y requiere descarga manual desde el sitio de Blackmagic Design.
Se documenta en el plan, pero no se implementa instalación automática.

### Entorno de pruebas
El desarrollo se validó sobre el equipo de desarrollo con software
preexistente. Se planifica validación completa sobre máquinas virtuales
con Windows 10 y Windows 11 en VirtualBox para v1.1.0.

---

## Hallazgos técnicos relevantes

### continue dentro de switch anidado en foreach
En PowerShell, `continue` dentro de un `switch` que está dentro de un
`foreach` no salta al siguiente elemento del loop — sale del `switch`.
Se resolvió usando una variable bandera(flag) `$saltear` fuera del switch para
controlar el flujo correctamente.

### Exit codes no estándar de winget
winget no usa exit codes convencionales. Los principales detectados:
- 0            : éxito
- -1978335212  : paquete no encontrado (MISSING)
- -1978335189  : paquete ya instalado (al intentar instalar sobre existente)

La función Get-WingetPackageStatus fue ajustada para manejar estos
códigos correctamente.

### Encoding Unicode en PowerShell
Caracteres como tildes en nombres de variables (`$problemáticos`) y
símbolos como `✓` en strings generan errores de parseo cuando el archivo
se guarda con encoding incorrecto. Se resolvió evitando caracteres
especiales en nombres de variables y reemplazando símbolos Unicode
por equivalentes ASCII en los strings de consola.

### Detección de OUTDATED via posición de columna en header
El output de winget list no tiene un separador de columnas confiable.
La detección de si hay actualización disponible se ímplemento buscando
el índice de la columna "Disponible" en el header y verificando si hay
contenido en esa posición en la línea del paquete.

### Get-VersionInstalada via posición de columna
Por el mismo motivo, la extracción de la version instalada se implementó
buscando el índice de la columna "Versi" en el header (truncado para
evitar problema de encoding con la o acentuada) y extrayendo el valor
por posición.

---

## Deudas técnicas para v1.1.0

### Refactorización de código duplicado
Las funciones Get-VersionInstalada, la lógica de auditoria por catalógo
y la lógica de instalación/actualización se repiten en cada modúlo con
mínimas variaciones. Se debe migrar estas funciones a Utils.ps1 o a un
modúlo auxiliar compartido para eliminar el código duplicado y facilitar
el mantenimiento.

### Formato uniforme de etiquetas en logs
Los niveles de log (INFO, WARNING, SUCCESS, ERROR) tienen distinta cantidad
de caracteres lo que rompe la alineación en los reportes. Se implementará
una función de centrado con ancho fijo que se aplicara tanto a los niveles
de log como a los estados de auditoria (INSTALLED, OUTDATED, MISSING, UNKNOWN).

### Manejo de aplicaciones instaladas fuera de winget
Cuando se detecta Chrome o Zoom instalado fuera de winget (via IdAlt),
actualmente se actualiza usando el ID alternativo. Se debe ofrecer al
técnico la opción de:
[1] Actualizar la version existente (conserva perfil del usuario)
[2] Reinstalar limpiamente via winget (con advertencia de perdida de datos)

### FiltroWinget en presets de setup_completo
La estructura FiltroWinget está definida en cada preset, pero aún no se usa.
Implementar el filtrado para que cada modúlo instalado desde setup_completo
solo presente las opciones del preset elegido, sin mostrar todo el catálogo.

### Preset personalizable y guardable
Permitir al técnico crear y guardar sus propios presets con selección
personalizada de software.

### Log exportable como resumen para el cliente
Generar un reporte final consolidado del setup realizado, exportable
en formato legible para entregar al cliente como evidencia del trabajo.

### Validación en máquinas virtuales
Validar el comportamiento completo de todos los módulos sobre maquínas
virtuales limpias con Windows 10 y Windows 11 en VirtualBox antes de
considerar v1.1.0 lista para uso en producción.

### developer.ps1 como toolkit separada
Evaluar el desarrollo de una Windows Developer Toolkit como proyecto
independiente dentro del ecosistema, con soporte para gestión de versiones
de JDK, Node, Python, IDEs, Git, Docker y WSL2.

---

## Notas finales

La toolkit cubre el objetivo principal de v1.0.0: configuración inicial
general de equipos Windows con auditoria previa, instalación selectiva
y evidencia del trabajo realizado mediante logs.

Los módulos individuales están probados funcionalmente sobre el equipo
de desarrollo. La validación completa sobre entornos limpios queda
pendiente para v1.1.0.