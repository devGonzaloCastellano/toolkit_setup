# Windows Setup Toolkit - Hallazgos de Arquitectura Inicial
## Revisión de Diseño v1.0.0

---

## Contexto

Durante el desarrollo de los primeros módulos de la Windows Setup Toolkit,
particularmente el módulo de instalación de runtimes, surgieron
problemáticas que no habían sido consideradas completamente durante la
fase de planificación inicial.

Estas observaciones generan ajustes en la arquitectura del proyecto y en
la forma en que la toolkit tomará decisiones durante la ejecución.

---

# Problemática 1: Entorno de desarrollo diferente al entorno objetivo

## Situación detectada

La toolkit está pensada principalmente para ejecutarse en equipos recién
formateados, donde la mayoría del software aún no está instalado.

Sin embargo, el desarrollo se realiza sobre un equipo personal que ya
posee:

- Navegadores instalados
- Runtimes instalados
- Herramientas de desarrollo instaladas
- Software multimedia instalado

Como consecuencia, resulta difícil validar el comportamiento real de los
módulos de instalación.

---

## Problema

El diseño inicial asumía implícitamente que la toolkit trabajaría sobre
equipos vacíos o recién instalados.

En la práctica también puede ejecutarse sobre:

- Equipos parcialmente configurados
- Equipos corporativos
- Equipos de clientes con software preexistente
- Equipos utilizados para pruebas y mantenimiento

Esto introduce escenarios donde una instalación directa puede resultar:

- Innecesaria
- Redundante
- Más lenta de lo necesario

---

## Conclusión

La toolkit no debe asumir que el sistema se encuentra vacío.

Debe ser capaz de analizar el estado actual del equipo antes de actuar.

---

# Problemática 2: Falta de una capa de auditoría previa

## Situación detectada

La arquitectura original se enfocaba en instalar software según la
selección del técnico.

Sin embargo, no existía un mecanismo para determinar previamente:

- Qué componentes ya están instalados
- Qué componentes faltan
- Qué componentes están desactualizados

---

## Impacto

El técnico trabaja parcialmente a ciegas.

No existe una visión clara del estado real del sistema antes de iniciar
la instalación.

---

## Nueva necesidad

Incorporar una etapa de auditoría previa al proceso de instalación.

Flujo propuesto:

[ Auditoría ]
        ↓
[ Instalación ]
        ↓
[ Validación ]

---

# Problemática 3: Diferenciar instalación de mantenimiento

## Situación detectada

Existen dos escenarios de uso distintos:

### Escenario A
Equipo recién formateado.

Objetivo:
Instalar todo lo necesario.

### Escenario B
Equipo ya configurado.

Objetivo:
Completar, actualizar o reparar componentes.

---

## Conclusión

La toolkit debe evolucionar desde una herramienta de instalación hacia
una herramienta de auditoría e implementación.

La instalación pasa a ser una acción derivada del diagnóstico previo.

---

# Problemática 4: Necesidad de clasificación de estados

## Situación detectada

Actualmente, solo existe una condición implícita:

- Instalar

No existe clasificación del estado de cada componente.

---

## Estados propuestos

### INSTALLED

El componente se encuentra presente y operativo.

### MISSING

El componente no está instalado.

### OUTDATED

Existe una versión instalada, pero no es la recomendada.

### UNKNOWN

No fue posible determinar el estado.

---

## Estados futuros (v2.x)

### CORRUPTED

Instalación dañada o incompleta.

### REPAIRABLE

Se detectó una instalación válida pero requiere reparación.

---

# Cambio de enfoque arquitectónico

## Diseño original

La toolkit instala software.

---

## Diseño actualizado

La toolkit audita el sistema, determina necesidades y posteriormente
instala, actualiza o repara según corresponda.

---

# Nueva visión del proyecto

Windows Setup Toolkit deja de ser únicamente una herramienta de
instalación post-formato.

Pasa a convertirse en una plataforma de auditoría, implementación y
validación para equipos Windows.

Objetivos:

- Detectar el estado actual del sistema.
- Identificar software faltante.
- Detectar versiones obsoletas.
- Guiar al técnico durante la implementación.
- Validar el resultado final.
- Generar evidencia mediante logs y reportes.

---

## Posibles módulos futuros

### system_audit.ps1

Responsable de analizar el estado completo del equipo.

### validate_installation.ps1

Responsable de verificar que todas las implementaciones finalizaron
correctamente.

### generate_report.ps1

Responsable de generar un resumen técnico exportable.

---

## Estado

Documento generado durante la fase inicial de desarrollo.

Fecha:
2026-06-02

Versión:
Review v1.0.0