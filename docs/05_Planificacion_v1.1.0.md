# Windows Setup Toolkit - Review del Plan v1.1.0

## Fecha
2026-06-09

## Propósito del documento

El plan original de v1.1.0 (03_rediseño_v1.0.0.md) fue redactado
antes de completar v1.0.0. Con el desarrollo finalizado y las deudas técnicas
identificadas en el review de cierre (04_cierre_v1.0.0.md), se revisaron
y reasignaron los items antes de iniciar el desarrollo de v1.1.0.

Este documento reemplaza el scope de v1.1.0 definido en el plan original
y es la referencia de trabajo para esta versión.

---

## Criterio de corte

v1.1.0 es una version de estabilización.

Solo entran items que cumplan todas estas condiciones:
- No crean archivos nuevos en lib/
- No modifican el dot-sourcing de multiples módulos simultáneamente
- No agregan funcionalidad visible para el técnico (salvo el prompt de IdAlt)
- Cierran deuda técnica documentada en v1.0.0 o corrigen comportamiento menor

Todo lo que implique nueva arquitectura o nueva funcionalidad mayor va a v2.0.0.

---

## Scope confirmado para v1.1.0

### 1. Formato uniforme de etiquetas en logs

**Problema:**
Los niveles de log (INFO, WARNING, SUCCESS, ERROR) y los estados de auditoria
(INSTALLED, OUTDATED, MISSING, UNKNOWN) tienen distinta longitud de texto,
lo que rompe la alineación visual en consola y en los archivos de log.

**Solución:**
Agregar Get-CenteredTag a Utils.ps1. Recibe un texto y un ancho total,
distribuye espacios equitativamente a ambos lados y retorna el texto
encofrado entre delimitadores configurables.

Aplicar la función a los niveles de Write-Log y a los labels de estado
en todos los módulos.

**Nota técnica:**
La función fue diseñada y validada antes de iniciar el desarrollo.
El retorno usa 5 valores con formato "{0}{1}{2}{3}{4}" — confirmar que
el CloseDelimiter esté en la posición {4} antes de integrar.

**Archivos afectados:**
- lib/Utils.ps1 (agregar función)
- Todos los módulos que usan Write-Log con etiquetas de estado

---

### 2. Prompt de acción para apps detectadas fuera de winget

**Problema:**
Cuando Chrome o Zoom están instalados fuera de winget (detectados via IdAlt),
el módulo actualiza automáticamente usando el ID alternativo sin informar
al técnico. No se ofrece elección sobre como proceder.

**Solución:**
Cuando se detecta un paquete via IdAlt con estado OUTDATED, mostrar prompt:

```
[1] Actualizar version existente (conserva perfil del usuario)
[2] Reinstalar limpiamente via winget (advertencia: puede afectar perfil)
[0] Omitir
```

**Archivos afectados:**
- navegadores.ps1 (Chrome)
- comunicacion.ps1 (Zoom)

---

### 3. Activar FiltroWinget en presets de setup_completo

**Problema:**
La estructura FiltroWinget está definida en cada preset de setup_completo.ps1,
pero nunca se usa. Cuando el técnico corre un preset, cada módulo muestra
su catálogo completo en lugar de mostrar solo las apps del perfil elegido.

**Solución:**
Implementar el filtrado para que cada módulo invocado desde setup_completo
reciba el filtro del preset y presente únicamente las opciones correspondientes.

**Archivos afectados:**
- setup_completo.ps1
- Módulos invocados desde setup_completo (reciben parámetro de filtro)

---

### 4. Validación en máquinas virtuales

**Problema:**
v1.0.0 fue validada sobre el equipo de desarrollo con software preexistente.
No fue validada sobre entornos limpios.

**Criterio de cierre:**
Antes de taggear v1.1.0, validar el comportamiento completo de todos los
módulos sobre máquinas virtuales limpias en VirtualBox:
- Windows 10 (VM dedicada)
- Windows 11 (VM dedicada)

Esto no es un item de código sino un criterio de salida de la version.

---

## Scope descartado para v1.1.0

### Migración de Get-VersionInstalada a Utils.ps1

**Motivo del descarte:**
Get-VersionInstalada es idéntica en los 4 módulos que la contienen.
Moverla a Utils sería un paso intermedio válido, pero en v2.0.0 se crea
WingetUtils.ps1 y esa función va a ese modúlo. Migrarla primero a Utils
y luego a WingetUtils es doble trabajo sobre el mismo código.

**Destino:** v2.0.0 junto con la creación de WingetUtils.ps1.

---

### Migración de lógica duplicada de instalación

**Motivo del descarte:**
Invoke-InstalarApp y sus variantes por modúlo (Invoke-InstalarNavegador,
Invoke-InstalarCompresor, etc.) comparten la misma lógica con distinto
nombre de parámetro. Unificarlas requiere crear WingetUtils.ps1 y modificar
el dot-sourcing en todos los módulos simultáneamente.

Ese nivel de cambio arquitectural no corresponde a una version de estabilización.

**Destino:** v2.0.0 como parte de la refactorización completa de WingetUtils.ps1.

---

### Reporte exportable para el cliente

**Motivo del descarte:**
El reporte con delta de estados (antes/después por modúlo) requiere:
- Persistencia de estado por sesión en archivos JSON
- Un nuevo modulo ReportUtils.ps1
- Integración en system_audit.ps1
- Definición del formato de salida (HTML / JSON / TXT)

Es funcionalidad mayor que excede el criterio de estabilización.

**Destino:** v2.0.0. Ver 05_setup_toolkit_plan_v2.0.0.md para el diseño completo.

---

### Preset personalizable y guardable

**Motivo del descarte:**
Implica persistencia en disco, UI para armar el preset, lógica de
carga/guardado y validación. Es una feature nueva, no deuda técnica.

**Destino:** v3.0.0 o posterior según prioridades que surjan en v2.x.

---

## Resumen de scope

| Item                                    | Version  | Motivo                              |
|-----------------------------------------|----------|-------------------------------------|
| Get-CenteredTag en Utils.ps1            | v1.1.0   | Deuda técnica, un solo archivo      |
| Formato uniforme de etiquetas           | v1.1.0   | Deuda técnica, estético             |
| Prompt actualizar vs reinstalar (IdAlt) | v1.1.0   | Comportamiento menor, 2 módulos     |
| Activar FiltroWinget en presets         | v1.1.0   | Completar lo que ya estaba a medias |
| Validación en VMs limpias               | v1.1.0   | Criterio de salida, no es código    |
| Migración Get-VersionInstalada          | v2.0.0   | Doble trabajo si se hace antes      |
| Migración lógica de instalación         | v2.0.0   | Requiere WingetUtils.ps1            |
| Reporte exportable con delta            | v2.0.0   | Funcionalidad mayor                 |
| Preset personalizable y guardable       | v3.0.0   | Feature nueva, fuera de scope       |