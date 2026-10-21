# GDD — Nardaram: Los Nuevos Bosques

> Dueño: `game-designer`. Estado: borrador v0.2 (incorpora ADR 0002 y 0003).

## Visión
Refundar un pueblo en un bosque arrasado de Nardaram y **sobrevivir**. Cada partida ocurre en un chunk del mundo generado con seed; el mapa mundial diseñado a mano dicta clima, geografía y contexto político. Exploras el bosque como aventurero (RPG por turnos) y gestionas el pueblo día a día. Pixel art 8-bit top-down, sesiones cortas, progreso visible. Solo español.

## Pilares
1. Dos capas, un mundo.
2. Sesiones cortas con progreso visible (15 min = algo nuevo).
3. Legibilidad 8-bit.
4. **Cada partida es distinta, cada región se reconoce**: la seed cambia la disposición, la región mantiene su identidad.

## Loop principal (por días)
```
Inicio del día: ver estado del pueblo (comida, gente, amenazas)
   ↓
Fase de ciudad: construir, asignar trabajos, gestionar almacén
   ↓
(opcional) Expedición: elegir destino en el chunk → explorar → combates por menú → loot/supervivientes
            Consume 1–3 días; el pueblo sigue simulándose mientras tanto.
   ↓
Fin del día: producción → consumo → necesidades → eventos → chequeo de derrota
```

## Supervivencia
- No hay final. La partida termina cuando se cumple una condición de derrota (pendiente #11).
- Presiones: comida, clima de la región, eventos de facción, enemigos del bosque.
- Progreso = más gente, mejores edificios, zonas del chunk desbloqueadas.

## Mundo (ADR 0003)
- Mapa mundial en `data/world/world_map.json` + arte de referencia en `docs/design/world/`.
- Región → bioma, clima, relieve, facción, recursos, peligro.
- Chunk = ciudad + bosque explorable. Propuesta: 64×64 tiles, ciudad central 24×16.

## Capa ciudad (MVP)
- Grid 16×16 top-down.
- Recursos: madera, piedra, comida, oro.
- Edificios iniciales: hoguera (centro), cabaña, aserradero, cantera, huerto, herrería.
- Ciudadanos: llegan por expediciones; necesitan cabaña y comida; trabajan en un edificio.
- Producción/consumo **por día** en `data/buildings/`.

## Capa RPG (MVP)
- Party de hasta 3. Stats: HP, ATK, DEF, SPD.
- Combate por turnos, menú: Atacar / Habilidad / Objeto / Huir.
- Exploración top-down del chunk; encuentros según bioma de la región.
- Inventario 12 slots. Equipo: arma, armadura, accesorio.

## Fuera de alcance del MVP
Multijugador, mods, más de una región jugable, localización (inglés en v1.x).

## Métricas de playtest
- Tiempo hasta el primer edificio construido: < 3 min.
- Tiempo hasta la primera expedición: < 8 min.
- Jugador describe el loop sin ayuda tras 15 min.
- Partida media antes de la primera derrota: 20–40 días.

## Pendiente
Ver `docs/decisions/0000-preguntas-abiertas.md`.
