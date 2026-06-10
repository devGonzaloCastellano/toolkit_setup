# Windows Setup Toolkit - Cierre v1.1.0

## Fecha
2026-06-10

## Estado
v1.1.0 completada. Version de estabilización sobre v1.0.0.

---

## Objetivos de la version

v1.1.0 fue planificada como versión de estabilización con scope
deliberadamente acotada: cerrar deuda técnica estética y de comportamiento
menor sin introducir cambios arquitecturales.

Los objetivos se cumplieron en su totalidad a excepción de la validación
en VMs, que queda como criterio pendiente antes de considerar la versión
lista para uso en producción.

---

## Cambios implementados

### Get-CenteredTag en Utils.ps1
Nueva función agregada a lib/Utils.ps1 que genera texto centrado entre
delimitadores con relleno de espacios equitativo a ambos lados.

Parámetros: Text, TotalWidth (opcional), OpenDelimiter, CloseDelimiter.
Si TotalWidth se omite, se ajusta automáticamente al texto más 2 espacios.
Si el texto supera el ancho solicitado, retorna sin romper el contenido.

### Formato uniforme de etiquetas en logs
Write-Log actualizado para usar Get-CenteredTag en los niveles de log
con TotalWidth 9. El timestamp fue simplificado a HH:mm con espaciado
manual para mantener consistencia visual.

Todos los módulos actualizados para usar Get-CenteredTag en los estados
de auditoria (TotalWidth 11) y en los estados del reporte de acciones
realizadas (TotalWidth 7).

El submenu de cada modúlo fue actualizado para usar Get-CenteredTag
en las etiquetas [OK] y los numeradores [1], [2], etc. (TotalWidth 2),
eliminando el desplazamiento visual que existía entre ambos tipos.

### Prompt para apps detectadas fuera de winget
Cuando Chrome o Zoom son detectados via IdAlt con estado OUTDATED,
se presenta al técnico un prompt con tres opciones:
[1] Actualizar version existente (conserva perfil del usuario)
[2] Reinstalar limpiamente via winget (migra al registro de winget)
[0] Cancelar

Implementado en navegadores.ps1 (Chrome) y comunicacion.ps1 (Zoom).

---

## Módulos modificados

| Modulo             | Cambios                                 |
|--------------------|-----------------------------------------|
| lib/Utils.ps1      | Get-CenteredTag, Write-Log actualizado  |
| navegadores.ps1    | Get-CenteredTag, prompt IdAlt Chrome    |
| compresores.ps1    | Get-CenteredTag                         |
| multimedia.ps1     | Get-CenteredTag                         |
| productividad.ps1  | Get-CenteredTag                         |
| comunicacion.ps1   | Get-CenteredTag, prompt IdAlt Zoom      |
| runtimes.ps1       | Get-CenteredTag                         |
| system_audit.ps1   | Get-CenteredTag en Write-EstadoApp      |
| setup_completo.ps1 | Get-CenteredTag en resumen final        |
| configurar.ps1     | Bump version a 1.1.0                    |
| drivers.ps1        | Bump version a 1.1.0                    |

---

## Decisiones tomadas durante el desarrollo

### Get-VersionInstalada no migrada a Utils.ps1
La función Get-VersionInstalada está duplicada en cada modúlo y era
candidata a migrarse a Utils.ps1 en esta version. Se decidió no hacerlo
porque en v2.0.0 se crea un nuevo modúlo dedicado a gestión de paquetes
winget, y migrarla primero a Utils y luego a ese modúlo sería doble
trabajo sobre el mismo código.

### FiltroWinget descartado para v1.1.0
La activación de FiltroWinget en setup_completo requiere que cada modúlo
soporte un modo automático sin submenu interactivo. Eso implica agregar
parámetros y lógica nueva a todos los módulos, lo cual excede el criterio
de estabilización de esta version.

### Separación de Utils.ps1 en multiples módulos
Durante el análisis se evaluó separar Utils.ps1 en dos archivos:
infraestructura general y gestión de paquetes winget. Se decidió no
hacerlo en v1.1.0 porque la cantidad de funciones a migrar no justificaba
la complejidad adicional. La separación se realizará en v2.0.0 junto con
la creación del nuevo modúlo.

---

## Deudas técnicas identificadas

Documentadas en detalle en 06_revision_v1.1.0.md.

### CANCELLED vs ERROR en reporte de acciones
Cuando el técnico cancela una operación desde un prompt, la función
Invoke-Instalar* retorna $false y el loop lo registra como ERROR.
El estado CANCELLED debería distinguirse de ERROR en el reporte.
Aplica a todos los módulos. Se resolverá en v2.0.0 como parte de la
refactorización del manejo de resultados.

### FiltroWinget y modo automático
La estructura FiltroWinget existe en los presets, pero no se usa.
Requiere modo automático en cada modúlo. Destino: v2.0.0.

---

## Pendiente antes de producción

### Validación en máquinas virtuales y físicas
Validar el comportamiento completo sobre entornos limpios:
- Windows 10 Pro (VM VirtualBox y PC de Escritorio)
- Windows 11 (VM VirtualBox y Notebook)

Criterios de validación:
- Auditoria detecta correctamente MISSING en sistema limpio
- Instalación via winget completa sin errores
- Prompt de IdAlt funciona correctamente para Chrome y Zoom
- Logs generados correctamente
- Setup completo con los tres presets

---

## Apertura hacia v2.0.0

v1.1.0 deja el proyecto en estado estable y con arquitectura clara
para encarar los cambios de v2.0.0. Las decisiones tomadas en esta
version (no migrar Get-VersionInstalada, no activar FiltroWinget)
fueron deliberadas para no generar deuda adicional antes de la
refactorizacion arquitectural.

