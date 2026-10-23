# ADR 0011: Proceso de desarrollo y convenciones

## Contexto
El dueño del proyecto (2026-10-23): "me interesa es que tengas un sistema definido de versiones del juego, de commits, pr y testeo. Todas las nomenclaturas de funciones, objetos, permisos, archivos y demas. No quiero incoherencias, si algun día paso esto aun grupo humano deben poder saber lo que ocurre."

Hasta ahora todo se commiteaba directamente en una sola rama (`claude/nuevos-bosques-game-setup-q2fdid`, PR #1 en borrador), con mensajes libres, sin versión y con convenciones de nombres repartidas entre `STACK.md` y la práctica.

## Decisión
- Proceso (versiones, ramas, commits, PR, tests, releases, permisos): [`CONTRIBUTING.md`](../../CONTRIBUTING.md).
- Nombres y estilo de código: [`docs/CONVENCIONES.md`](../CONVENCIONES.md).
- **Versión:** SemVer en `application/config/version`. El trabajo acumulado hasta hoy (exploración, Bosques y combate v1) es **0.1.0**.
- **Git:** `main` protegida, ramas `<tipo>/<tema>`, Conventional Commits en español, merge squash.
- **Idioma del código:** identificadores en inglés y términos del lore en español sin tildes, que es lo que ya hacía el código.
- `*.import` pasa a commitearse, como recomienda Godot 4: guarda los ajustes de importación de cada asset.

## Consecuencias
- El PR #1 se cierra con merge a `main` y se crea el tag `v0.1.0`. A partir de ahí, cada tema va en su propia rama y su propio PR.
- La protección de `main` exige que pase el check `Tests`.
- Antes de 0.2.0 se hace una pasada `refactor` para alinear el código existente con `CONVENCIONES.md`. Ejemplos ya detectados: las señales `expedition_*` usan `zone_id`, y el nombre de archivo del ADR 0006 todavía dice "zonas".
