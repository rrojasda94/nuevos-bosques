# ADR 0017 — Ajustes de playtest de la 0.5: huida con suerte, colarse si nadie te ve, armas, trueque e IA

> Ficha de mecánica: `docs/design/mechanics/ajustes-playtest-0.5.md`. Plan de PR: bloque **P** de `docs/design/roadmap-0.5.md`.

## Contexto
- ADR 0016 y la #184 fijaron que en el combate táctico se huye "desde cualquier borde, seguro".
- La 0.3 (`sigilo-y-robo.md`) fijó que solo se puede colarse con una máscara o un artefacto que camufle la Luz, con un umbral fijo de visión.
- La #131 dejó a medias cómo se equipa y se desequipa el arma.
- Los favores, los artesanos y el trueque estaban en la 0.6.

El dueño jugó con el combate táctico activado (2026-10-27):

> "es muy facil huir de los combates. Deberia ser más complicado quizas a la suerte.
> comer un fruto en otro bosque aun lo reconoce como segundo fruto y manda ofomni. No permite ingresar a los bosques libremente sin enfrentamiento. debería poderse entrar como sneaking pero los botarramas u otros unicos si te ven te pillan. Si estas muy bien equipado no deberían notarte a menos que pases por su lado.
> Las armas no afectan el combate
> los item no tienen ningun valor real aun en la jugabilidad
> la ia de los enemigos es muy basica."

## Respuestas del dueño
| # | Respuesta | Decisión |
|---|---|---|
| #191 | Confirmada con sus palabras del playtest ("Deberia ser más complicado quizas a la suerte") | Huida con suerte |
| #192 | Confirmada con sus palabras del playtest ("debería poderse entrar como sneaking...") | Colarse si nadie te ve, también sin máscara |
| #193 | "Sí, y sicabi prohíbe aun enfundada" | Arma enfundada o en la mano; en una sicabi, ni enfundada |
| #194 | "Sí, con esos nombres" | Cuchillo y Honda |
| #195 | "Sí, encaja" | Perfiles guardián, látigo y emboscadora |
| #197 | "Sí, adelante" | Trueque mínimo y equipo inicial |

Siguen abiertas la #190 (¿un Bosque forzado da algún permiso para el fruto?) y la #196 (consumibles de combate; hace falta lore).

## Decisión
1. **Huida con suerte (sustituye a la #184)**
   - En el táctico se huye desde una casilla del borde con probabilidad P = 70 + 5 × (tu AGI − la AGI más alta de los enemigos cercanos) − 35 por enemigo adyacente − 10 por enemigo cercano (distancia ≤ su Mov + 1) + 10 por intento fallido, entre 5% y 95%.
   - La probabilidad se muestra antes de confirmar. Si falla, pierdes el turno.
   - En el combate por menú, `flee_chance` pasa de 0,75 a 0,6.
   - En el mundo, tras huir, el monstruo queda calmado 1,5 s (Retroceder sigue con 3 s).
   - Ofomni, Aledra y reparep esprintan un momento si están cerca. El Botarramas no, porque renquea.
   - Correr anula el camuflaje.
2. **Colarse si nadie te ve (sustituye a "sin máscara no se puede colarse")**
   - La frontera cerrada se cruza sin menú si, al tocarla, ningún Botarramas ni Único del Bosque destino te ve.
   - Te ven siempre a 2 casillas o menos. Más lejos, según su visión menos tu camuflaje; sin nada que oculte, o corriendo, al doble de su visión.
   - El menú del borde solo sale si te ve un Botarramas o si hablas con E. Si te ve otro Único, te persigue.
   - Se retira el umbral `sneak_max_vision`.
3. **Arma enfundada o en la mano (cierra la #131)**
   - Se cambia con la tecla Q, gratis fuera de combate.
   - **Enfundada**: no cierra Bosques y resta al camuflaje lo que diga el arma (la lanza, 2).
   - **En la mano**: como el "armado" de la 0.3. No deja colarse.
   - En combate se desenfunda sola, salvo en una emboscada del enemigo (entonces desenfundar es tu primera acción).
   - En una **sicabi** no se entra con un arma equipada, aunque esté enfundada.
4. **Armas con efecto propio**
   - Lanza: +2 ATQ, alcance 1–2 en línea.
   - **Cuchillo**: +1 ATQ, +2 de daño extra por la espalda, sin penalización de camuflaje.
   - **Honda**: +1 ATQ, alcance 2–3, no ataca a 1 casilla.
   - La escena táctica muestra el ATQ con el arma.
5. **Objetos**
   - Acción **Objeto** en el táctico; en la 0.5, el fruto.
   - **Trueque mínimo adelantado de la 0.6**: el Sarua cambia ofrendas o Luz por máscaras y talismanes (4–6) y el Paruas, por el Cuchillo (5) y la Honda (6). 3 objetos al día por artesano; sin materiales ni mejoras.
   - **Equipo inicial**: lanza enfundada y máscara de corteza puestas, y una trenza votiva en la bolsa.
6. **IA del táctico**
   - Perfiles: Botarramas **guardián**, Ofomni **látigo** con alcance 2 (el descarriado sigue berserk, con alcance 2) y Aledra **emboscadora**.
   - Reglas comunes: Defender y Esperar, cortar la huida, preferir la altura y azar top-2 ponderado con la seed del combate.
7. **Fruto**: la regla no cambia. Se añaden un icono de permiso en el HUD, avisos y una confirmación más clara.

## Consecuencias
- Se anotan:
  - `combate-tactico.md`, `ia-de-combate.md`, `sigilo-y-robo.md`, `cruce-y-combate-v2.md`, `monstruos.md`, `npcs-y-villas.md` y `bosques-y-relacion.md`;
  - la #184 y la #131 de `0000-preguntas-abiertas.md`.
- Bloque P de PR pequeños (`rpg-systems-dev`, `ui-ux-dev`, `engine-architect` para la tecla y el guardado, `narrative-writer` para los textos):
  - P1 huida; P2 IA; P3 arma enfundada, colarse y fruto; P4 armas y objetos; P5 trueque; P6 sprint.
  - Lo que toca la exploración va en reglas puras con un gancho mínimo, coordinado con la sesión del Mundo 2.0 (M17a).
- El guardado añade el estado del arma (`weapon_drawn`) y las existencias del trueque por villa y día.
- Valores provisionales, en `data/combat/balance.json` y `data/items/items.json`.
