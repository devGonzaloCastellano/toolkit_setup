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

**Aplica en:** todos los módulos con loop de selección

**Problema:**
Cuando el técnico cancela una operación, la función `Invoke-Instalar*` retorna `$false`.
El loop de selección interpreta ese `$false` como ERROR y lo registra 
como tal en el reporte de acciones realizadas.

El reporte muestra `[ ERROR ]` para una operación que fue cancelada
deliberadamente, lo cual puede generar confusion al leer el log.

Si bien de momento solo el modúlo navegadores.ps1 tiene un prompt explicito de cancelación,
todos los módulos son susceptibles al mismo problema en cuanto se agreguen prompts similares.
El patrón se repite en todos.

**Solución propuesta:**
Abstraer el manejo de resultados en una función centralizada en
un nuevo modúlo que distinga tres estados: `OK, ERROR, CANCELLED`.
Actualizar el loop de selección y el reporte final en cada modúlo
para consumir esa función en lugar de manejar el retorno directamente.

**Impacto estimado:** medio — afecta el loop de selección y el bloque
de reporte final en todos los módulos, más la creación de la función
centralizada en un nuevo modúlo.

**Destino:** v2.0.0 

---

## Módulos revisados

| Modúlo             | Revision completada |
|--------------------|---------------------|
| Utils.ps1          | ✓                   |
| navegadores.ps1    | ✓                   |
| compresores.ps1    | ✓                   |
| multimedia.ps1     | ✓                   |
| productividad.ps1  | ✓                   |
| comunicacion.ps1   | pendiente           |
| runtimes.ps1       | pendiente           |
| system_audit.ps1   | pendiente           |
| setup_completo.ps1 | pendiente           |