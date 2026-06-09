# Windows Setup Toolkit - Revision v1.1.0

## Fecha de apertura
2026-06-09

## Propósito del documento

Registro de deudas técnicas y comportamientos a revisar detectados durante
el desarrollo de v1.1.0. Se completa de forma incremental a medida que se
trabaja sobre cada modúlo.

Se utiliza como referencia al momento de planificar v2.0.0 o versiones
de mantenimiento posteriores.

---

## Deudas técnicas encontradas

### 1. Distinción entre CANCELLED y ERROR en reporte de acciones

**Detectado en:** navegadores.ps1
**Verificar en:** todos los módulos con loop de selección

**Problema:**
Cuando el técnico cancela una operación desde el prompt (por ejemplo el
prompt de IdAlt en Chrome), `Invoke-InstalarNavegador` retorna `$false`.
El loop de selección interpreta ese `$false` como ERROR y lo registra
como tal en el reporte de acciones realizadas.

El reporte muestra `[ ERROR ]` para una operación que fue cancelada
deliberadamente, lo cual puede generar confusion al leer el log.

**Solución propuesta:**
Agregar un tercer valor de retorno o un estado `CANCELLED` al objeto
de resultados. Actualizar el loop de selección, el reporte final y
la lógica de filtrado para distinguir los tres casos: OK, ERROR, CANCELLED.

**Impacto estimado:** bajo — afecta el loop de selección y el bloque
de reporte final en cada modúlo que tenga prompt de cancelación.

**Destino:** a evaluar en v2.0.0 o version de mantenimiento v1.2.0
según la cantidad de módulos afectados.

---

## Módulos revisados

| Modúlo             | Revision completada |
|--------------------|---------------------|
| Utils.ps1          | ✓                   |
| navegadores.ps1    | ✓                   |
| compresores.ps1    | pendiente           |
| multimedia.ps1     | pendiente           |
| productividad.ps1  | pendiente           |
| comunicacion.ps1   | pendiente           |
| runtimes.ps1       | pendiente           |
| system_audit.ps1   | pendiente           |
| setup_completo.ps1 | pendiente           |