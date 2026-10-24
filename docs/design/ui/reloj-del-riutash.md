# UI: reloj del riutash

> Dueño: `ui-ux-dev`. Mecánica: `docs/design/mechanics/tiempo-y-riutash.md`. Código: `scripts/ui/riutash_clock.gd` (escena), `riutash_clock_logic.gd` (lógica, con tests) y `riutash_dial.gd` (dibujo).

Petición del dueño (2026-10-24): "que no sea un temporizador el indicador de riutash sino una suerte de 'brújula' como el reloj de Minecraft que esté en alguna de las esquinas y que tenga una animación de scale y shrink cuando el riutash está por llegar y un sonido swishhh para acentuar la alerta."

## Posición (320×180)
```
+--------------------------------------------------------------+
| Nv 1  PV 30/30  Luz 10/10                        Sfida  ->   |  <- HUD de texto | brújula
| Seed ...  Chunk (6, 13)  Día 1                               |
| Bosque #10 ...                                               |
|                                                              |
|                          (jugador)                           |
|                                                              |
|                                                       .--v-. |
|            ¡El riutash llega! Busca refugio ya.       | ☀|☾ | |  <- reloj, 23 px
+--------------------------------------------------------------+
```
- **Esquina inferior derecha.** Arriba a la izquierda están las líneas del HUD y arriba a la derecha la brújula. Abajo a la derecha no hay nada, así que el pulso puede crecer sin tapar texto, y queda junto a los avisos textuales (abajo en el centro): toda la alerta del riutash está en la misma franja.
- Los avisos se estrechan a 260 px (x 30–290) para no pisar el reloj; siguen centrados.
- Capa 2 (encima de la luz de luna): el reloj conserva sus colores de noche.

## Lectura
- Disco de 23 px con borde dorado. La esfera interior gira: la mitad de Gietos (cielo azul `0099db` y ojo dorado) y la de Riumna (ultramarino oscuro `262b44`, ojo plateado con el rostro roto y riumini blancos y opalinos).
- La línea blanca que separa las mitades es el riutash. La marca blanca fija de arriba es "ahora".
- Cada mitad dura lo que su Momento (8 y 5 min): el borde llega a la marca justo en el riutash. A mediodía el ojo de Gietos está bajo la marca y a medianoche el de Riumna.
- 64 pasos por vuelta, recalculados píxel a píxel (sin rotación con filtrado). Sin números.
- Con ratón, el tooltip dice el Momento ("Día de Gietos" / "Noche de Riumna").

## Alerta
| Tiempo hasta el riutash | Pulso (radio 10 → 13 px → 10, 0,36 s) | Swish |
|---|---|---|
| > 60 s | No | No |
| 60 s → 15 s | Cada 2 s, acelerando hasta cada 1 s | A los 60 s (con el aviso) |
| ≤ 15 s | Cada 0,5 s | A los 15 s (con el aviso), 10 s y 5 s |
| Riutash | Destello: la esfera parpadea en blanco 1,2 s | (suena `sfx_riutash`) |

- El pulso crece redibujando el disco con más radio, no escalando la imagen: no hay píxeles deformados y el centro no se mueve.
- El reloj se para con la pausa, igual que WorldClock.

## Pendiente
- Arte definitivo de `pixel-artist` (ahora es placeholder dibujado por código, en paleta).
- Opción de accesibilidad "reducir parpadeos": cuando exista, el destello y el pulso deben respetarla.
