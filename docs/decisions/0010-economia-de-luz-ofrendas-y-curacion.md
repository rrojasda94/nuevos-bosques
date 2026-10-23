# ADR 0010 — Economía de Luz, ofrendas y curación (modo Aventura)

> Número 0009 reservado para `rpg-systems-dev`.

## Contexto
Respuesta del dueño del proyecto (2026-10-23) a la propuesta de ajuste 5 de `docs/design/mechanics/cruce-y-combate-v1.md` (economía de Luz cerrada) y a la #57. Palabras textuales:

> "un adoc gana luz ganando batallas contra únicos o ayudando a la gente de la villa con los peligros que tengan. Uno se puede curar en una villa o luego de un riutash (el cambio entre dia y noche). Esta bien que al principio irse lejos sea complicado. Tambien uno puede almacenar Luz cuando una villa le otorga ofrendas, estos artefactos pueden tener diferente valor en Luz y se usan de forma entera, es decir debes dejar el artículo entero en el bosque y pierdes su Luz total del valor. Así que es bueno saber administrar los recursos."

## Decisiones
| Tema | Decisión |
|---|---|
| Fuentes de Luz | 1) **Ganar batallas contra Únicos**. 2) **Ayudar a la gente de la villa con sus peligros** (misiones de villa; tipos y recompensa: #106). |
| Ofrendas | Una villa puede otorgar **ofrendas**: artefactos que **almacenan Luz**, con **valores distintos**. Se usan **enteras**: para pagar, se deja el artefacto completo en el Bosque y se pierde todo su valor, aunque el coste fuera menor. |
| Gestión de recursos | Es intencionado: "es bueno saber administrar los recursos". |
| Curación | **En una villa** o **tras un riutash** (el cambio entre día y noche; glosario §2). |
| Dificultad por distancia | Que al principio sea complicado ir lejos es **intencionado**. |

## Consecuencias
- **`cruce-y-combate-v1.md`**:
  - La regla de curación pasa de "junto a cualquier Nujio" a **"en la plaza o junto al Nujio de una villa"** (cambio que aplica el coordinador en el código).
  - La curación por riutash espera a que exista el ciclo día/noche (#75).
  - Se cierra la propuesta de ajuste 2 (d ≥ 4 muy difícil): es intencionado.
  - La propuesta 5 queda resuelta en parte.
- **Choque**: solo 1 de cada 5 Bosques tiene villa (ADR 0008). Si el Bosque inicial no tiene villa y aún no existe el riutash, el jugador no puede curarse salvo al ser derrotado. Ver #110.
- Las ofrendas se relacionan con el oficio **Sarua** del glosario §5 ("objetos para entregar Luz"). Es una relación de lore, no una regla.
- Las ofrendas son un recurso nuevo. Fuente: villas, por misiones de villa. Sumidero: pagos enteros en los bordes. Qué pasa al agotarse: hay que cruzar combatiendo o retroceder. Faltan los detalles (#107–#109).
- `engine-architect`: el estado guardado pasa a incluir el inventario de ofrendas (con su valor) además de la Luz.
