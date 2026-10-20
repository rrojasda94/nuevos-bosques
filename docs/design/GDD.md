# GDD — Nuevos Bosques

> Dueño: `game-designer`. Estado: borrador v0.1.

## Visión
Refundar un pueblo en un bosque arrasado. Exploras el bosque como aventurero (RPG por turnos) y gestionas el pueblo que crece con lo que traes (city management ligero). Pixel art 8-bit, sesiones cortas, progreso visible.

## Pilares
1. Dos capas, un mundo.
2. Sesiones cortas con progreso visible (15 min = algo nuevo).
3. Legibilidad 8-bit.

## Loop principal
```
Ciudad: construir / asignar ciudadanos / recoger producción
   ↓ (gastar comida y equipo)
Expedición: explorar mapa de bosque → combates → loot, supervivientes, conocimiento
   ↓ (volver)
Ciudad: nuevos edificios desbloqueados, más gente, mejor equipo
```

## Capa ciudad (MVP)
- Grid 16×16, mapa 40×24 tiles.
- Recursos: madera, piedra, comida, oro.
- Edificios iniciales: hoguera (centro), cabaña, aserradero, cantera, huerto, herrería.
- Ciudadanos: llegan por expediciones; necesitan cabaña y comida; trabajan en un edificio.
- Tick = 1 s. Producción por tick definida en `data/buildings/`.

## Capa RPG (MVP)
- Party de hasta 3. Stats: HP, ATK, DEF, SPD.
- Combate por turnos, menú simple (Atacar / Habilidad / Objeto / Huir).
- 1 zona de bosque con 3 subzonas y 1 jefe.
- Inventario 12 slots. Equipo: arma, armadura, accesorio.

## Fuera de alcance del MVP
Multijugador, mods, clima dinámico, más de una región, idiomas aparte del español (inglés en v1.0).

## Métricas de playtest
- Tiempo hasta el primer edificio construido: < 3 min.
- Tiempo hasta la primera expedición: < 8 min.
- Jugador describe el loop sin ayuda tras 15 min.

## Pendiente de decidir (ver preguntas abiertas en `docs/decisions/0000-preguntas-abiertas.md`)
