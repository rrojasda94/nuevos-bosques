# Cómo se trabaja en Nardaram

Proceso de versiones, ramas, commits, PR, tests y releases. Vale igual para personas y para agentes.
Las reglas de nombres están en [`docs/CONVENCIONES.md`](docs/CONVENCIONES.md). La decisión que fija este proceso es el [ADR 0011](docs/decisions/0011-proceso-de-desarrollo-y-convenciones.md).

## Roles
| Rol | Quién | Decide |
|---|---|---|
| Dueño del proyecto | rrojasda94 | Diseño, lore, jugabilidad, prioridades. Aprueba todo cambio de mecánica. |
| Responsable técnico | Claude (agente principal) | Código, arquitectura, GitHub, CI, versiones. |
| Agentes de dominio | `.claude/agents/*.md` | Cada uno es dueño de los archivos que lista en su "Dueño de". El router está en `CLAUDE.md`. |

Si entra gente al equipo, ocupa el rol de un agente de dominio: lee su `.md` y respeta sus límites.

## Versiones
- **Versionado semántico** `MAJOR.MINOR.PATCH`, sin `v` dentro del archivo y con `v` en el tag (`v0.2.0`).
- Fuente única: `application/config/version` en `project.godot`.
- Mientras el juego no esté publicado, la versión es `0.x`:
  - `MINOR` sube con cada hito jugable (algo nuevo que el dueño puede probar).
  - `PATCH` sube con correcciones sin contenido nuevo.
  - `1.0.0` = primera versión publicada en Steam.
- Cada versión tiene su entrada en [`CHANGELOG.md`](CHANGELOG.md), en español y con el formato [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

## Ramas
- `main`: siempre jugable y con los tests en verde. Protegida: no se hace push directo ni force-push, y solo se entra por PR con la CI aprobada.
- Ramas de trabajo: `<tipo>/<descripcion-en-kebab-case>`, con los mismos tipos que los commits. Ejemplos: `feat/combate-narrado`, `fix/tecla-pegada`, `docs/mapa-sur-lenfi`.
- Una rama = un tema. Se borra al hacer merge.

## Commits
Formato [Conventional Commits](https://www.conventionalcommits.org/es/v1.0.0/), con la descripción en español, en imperativo y sin punto final:

```
<tipo>(<ámbito>): <descripción>

<cuerpo opcional: qué y por qué, líneas de 72 columnas>

Co-Authored-By: ... (si lo escribió un agente)
```

| Tipo | Uso |
|---|---|
| `feat` | Funcionalidad nueva del juego |
| `fix` | Corrección de un bug |
| `design` | Documentos de diseño, ADR de diseño, fichas de mecánica |
| `docs` | Otra documentación (README, convenciones, guías) |
| `test` | Solo tests |
| `refactor` | Cambio de código sin cambio de comportamiento |
| `art` / `audio` | Assets |
| `ci` | Workflows, `tools/` |
| `chore` | Mantenimiento (dependencias, versión, `.gitignore`) |

**Ámbitos:** `world`, `rpg`, `city`, `ui`, `core`, `save`, `data`, `art`, `audio`, `ci`, `lore`. Se pueden omitir si el cambio es transversal.

Ejemplo: `feat(rpg): narrar el combate mensaje a mensaje`.

## Pull requests
1. Se abre desde la rama de trabajo contra `main` y se rellena la plantilla (`.github/pull_request_template.md`).
2. El título del PR sigue el formato de commit, porque es el mensaje que queda en `main`.
3. La CI (`Tests`) tiene que pasar.
4. Si el PR cambia una mecánica, debe enlazar la ficha o el ADR que la aprueba (regla 2 de `CLAUDE.md`).
5. Merge **squash**: un PR = un commit en `main`.
6. Mientras el equipo sea solo el dueño y los agentes, el responsable técnico puede aprobar y hacer el merge de sus propios PR con la CI en verde. Con más personas en el equipo, hará falta revisión de otra persona.

## Tests
- **Framework:** GUT. Para correrlos: `bash tools/test.sh`. El script instala GUT si falta.
- **Antes de abrir un PR:** tests en verde y arranque headless sin errores:
  `"$GODOT" --headless --path . --quit-after 120`.
- **Qué se testea:**
  - Toda lógica de reglas (combate, economía, generación, guardado) vive en clases puras con tests.
  - La UI no se testea con GUT; se verifica con capturas o en el playtest.
- **Bugs:** un bug cerrado = un test que lo reproduce y ahora pasa.
- **Determinismo:** misma seed y mismas entradas dan el mismo resultado; se testea en generación y en combate.
- **Playtest del dueño:** su feedback se registra en la tabla de feedback de la ficha correspondiente (`docs/design/mechanics/*.md`).

## Releases
1. Se sube la versión en `project.godot` y se cierra la sección `[Sin publicar]` del `CHANGELOG.md`. Commit: `chore: versión X.Y.Z`.
2. Merge a `main` y tag anotado `vX.Y.Z` sobre `main`.
3. Release en GitHub con las notas del CHANGELOG.
4. Los builds y Steam son de `release-manager`; la exportación automática por tag está pendiente.

## Decisiones (ADR)
- Toda decisión técnica o de diseño que afecte a más de un agente va en `docs/decisions/NNNN-titulo-en-kebab-case.md`, con el siguiente número libre.
- Los ADR no se borran. Si una decisión cambia, se añade una sección o un ADR nuevo que la sustituye, y se anota en el antiguo.
- Las preguntas pendientes del dueño viven en `docs/decisions/0000-preguntas-abiertas.md`.

## Permisos y secretos
- **GitHub:** el dueño es admin. Las personas que colaboren entran con rol `write` y trabajan por PR. Nadie hace push a `main`.
- **Secretos:** nunca se commitean (claves de Steamworks, `steam_appid.txt`, tokens). En CI van como *GitHub Secrets*.
- **Agentes:** solo editan los archivos de su "Dueño de". Si un cambio cruza áreas, se divide (regla 1 de `CLAUDE.md`) o se avisa al dueño del archivo.
