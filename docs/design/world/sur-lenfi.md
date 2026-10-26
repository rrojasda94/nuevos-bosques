# Mapa del Sur Lenfi — descripción para datos

> Dueño: `game-designer` (contenido del mapa, ADR 0003). Fuente: `docs/design/world/Sur-Lenfi_02.jpg`, del dueño del proyecto. Es **preliminar**: el dueño lo irá puliendo.
> Este archivo describe solo lo que se ve en la imagen y lo que el dueño ha confirmado (ADR 0008, notas). Lo marcado como *(lectura)* es interpretación de `game-designer`, pendiente de confirmar. Sirve de base para `data/world/` (`world-gen-dev`).

## Escala (ADR 0007 y respuestas del dueño, ADR 0008)
**chunk < Bosque < área < subregión < región < Sur Lenfi**

- **Cada color del mapa es un grupo de áreas** (respuesta del dueño a la #95), no un área suelta.
- Para ese nivel se propone el nombre **"subregión"**, que el dueño usa en su respuesta a la #98 ("el resto de las subregiones como ness y alciss"). Nombre a confirmar (#100).
- Así, Lean, Tossie, Ostie, etc. son subregiones del Valle del Sara, cada una con varias áreas. Esto es coherente con que una región tenga "de decenas a un centenar de áreas".
- Las áreas de cada subregión todavía no están dibujadas (#101).

## Convenciones de la imagen
- **Norte arriba, sur abajo** (confirmado, ADR 0008).
- Cada color de relleno es una subregión (grupo de áreas). Las subregiones de una misma región usan tonos distintos dentro del grupo.
- Los símbolos de montaña indican relieve montañoso.
- Las líneas negras gruesas y onduladas son ríos. **Confirmado** para el sistema del Sara (ver más abajo). Para el resto es *(lectura)*.
- La zona blanca del sur, con el rótulo "SUR", es *(lectura)* el mar o la zona fuera del mapa jugable. "SUR" parece el título del mapa.
- La imagen no tiene escala en km ni en tiles.

## Rasgos generales
- **Montañas**: una franja continua cubre todo el borde norte, de oeste a este. Hay además símbolos de montaña en casi todas las zonas. Son densos en Balasu, en el norte de Ness, en el este de Alciss, en Vastie y en el norte de Dorias y Safis.
- **Costa**: todo el borde sur, desde Safis (oeste) hasta Alciss (este). Safis forma una península hacia el sur en el extremo oeste.
- **Lago Ungol** (confirmado): la gran masa blanca alargada del este, **al sur de Naca**.
- **Cordillera de Ungol** (confirmado): está al sur del lago Ungol. *(lectura)* Se corresponde con las montañas densas de Balasu y del norte de Ness y Sass, en la orilla sur del lago. En esa cordillera **no hay lenfi**. En el resto de subregiones, como Ness y Alciss, **sí hay lenfi en varios lugares** (dueño, #98).
- **Río Sara** (confirmado): la línea que cruza Cassie de norte a sur hasta la costa. **Las líneas que se le unen son sus afluentes.** *(lectura)* Los afluentes visibles bajan por los límites de Tossie, Ostie y Vastie y por el límite de Vastie con Cassie. Afluentes pintados en la autoría: ver [Afluentes del Sara](#afluentes-del-sara).
- **Urd Gumnavis** (confirmado, dueño 2026-10-25): las montañas y colinas **al oeste** del Valle del Sara. De ellas bajan afluentes del Sara.
- **Gumnada Gumnavis** (confirmado, dueño 2026-10-25): las montañas y colinas **al este** del Valle del Sara. De ellas bajan afluentes del Sara.
- **Marca azul**: en la costa de Cassie, en la desembocadura del río Sara. *(lectura)* Posible Super Villa del Sara (glosario §5) (#96).

## Zonas del mapa (de oeste a este)
> Si Safis, Dorias, Nosie, Naca, Balasu y Cabuta (un solo color cada una) son regiones o subregiones está pendiente (#102). Por eso se listan como "zonas del mapa".

| Zona | Nivel | Posición | Notas |
|---|---|---|---|
| **Safis** | ¿región o subregión? (#102) | Extremo oeste; del norte (montañas) a la costa, con península al sur | Varios ríos bajan del norte hacia la costa *(lectura)*. |
| **Dorias** | ¿región o subregión? (#102) | Al este de Safis, del norte a la costa | Red de ríos ramificada que baja a la costa *(lectura)*. Al este limita con el Valle del Sara. |
| **Valle del Sara** | Región (MVP, ADR 0007) | Al este de Dorias, del norte a la costa | 7 subregiones (tabla siguiente). El nombre no está rotulado en el mapa. |
| **Nosie** | ¿región o subregión? (#102) | Al este del Valle del Sara, del norte hasta casi la costa; grande (azul claro) | Un río grande baja del norte y se ramifica hacia la costa y hacia Alcuss *(lectura)*. |
| **Naca** | ¿región o subregión? (#102) | Noreste, al norte del lago Ungol | Ríos que bajan hacia el lago *(lectura)*. |
| **Balasu** | ¿región o subregión? (#102) | Al este de Nosie, al sur del lago Ungol; pequeña y muy montañosa | *(lectura)* Parte de la cordillera de Ungol (sin lenfi). |
| **Cabuta** | ¿región o subregión? (#102) | Costa sur, al sur de Nosie y de Istil | Al oeste toca a Cassie en la costa. |
| **Alcuss** | Región (ADR 0008) | Sureste, al sur y sureste del lago Ungol | 5 subregiones: Adess, Istil, Sass, Ness, Alciss. |

## Valle del Sara: subregiones
> Grafía confirmada: **"Cassie"** (la "ss" suena como una s sonora; dueño, #99).

| Subregión | Posición en la región | Vecinos (lectura del mapa) | Relieve y ríos |
|---|---|---|---|
| **Lean** | Norte, oeste | Causie (E), Tossie (S), Dorias (O); al norte, la franja de montañas | Montañas en el norte. |
| **Causie** | Norte, este | Lean (O), Alss (S), Nosie (E); posible contacto con Tossie en la esquina SO | Montañas en el norte y el este. |
| **Tossie** | Norte-centro, oeste (bajo Lean) | Lean (N), Alss (E), Ostie (S y O); posible contacto con Dorias y Causie en las esquinas | Bordeada por afluentes del Sara: el 7mo al norte y el 5to al sur (autoría). |
| **Alss** | Norte-centro, este (bajo Causie) | Causie (N), Tossie (O), Vastie (S), Nosie (E); posible contacto con Ostie en la esquina SO | Montañas. |
| **Ostie** | Centro, oeste | Tossie (N), Alss (NE, posible), Vastie (E), Cassie (S y O); posible contacto con Dorias en el NO | El Sara en su límite con Vastie; el 3ro del Sara en su límite con Cassie (autoría). |
| **Vastie** | Centro, este | Ostie (O), Alss (N), Nosie (E), Cassie (S) | Muy montañosa. Afluentes 4to del Sara (límite con Alss) y 2do del Sara (límite con Cassie) (autoría). |
| **Cassie** | Sur; llega a la costa. Tiene además una franja estrecha al oeste, entre Dorias y Ostie | Ostie (N), Vastie (N/NE), Dorias (O), Nosie (E), Cabuta (SE, en la costa); al sur, la costa | **El río Sara la cruza** de norte a sur hasta la desembocadura (marca azul). Algunas montañas. |

**Norte y sur del Valle del Sara** (para "más agreste al norte; sur más plano con claros ribereños", ADR 0007):
- Norte: Lean, Causie, Tossie, Alss.
- Centro: Ostie, Vastie. Vastie es muy montañosa pese a estar en el centro.
- Sur: Cassie.

## Afluentes del Sara
> Dueño, 2026-10-25: "tambien deberia tener algunos afluentes el río Sara. Estos bajan de las montañas y colinas que el vale del Sara tiene al oeste las Urd Gumnavis y al este las Gumnada Gumnavis. Pon tres afluentes al este y 4 al oeste. Que respeten un poco el mapa de las subregiones que tenemos en la imagen hecha a mano del mapa del sur lenfi."
>
> Y después: "pon tres donde aparecen y un pequeño afluente cerca de sur del lugar. todos los afluentes son navegables una vez que salen de la zona montañosa. de sur a norte se llaman "1ro del Sara", "2do del Sara" y asi sucesivamente a medida que van uniendose al rio Sara".

Confirmado por el dueño:
- **4 afluentes al oeste** (de las Urd Gumnavis): los 3 que dibuja el mapa y **uno pequeño cerca del sur**.
- **3 afluentes al este** (de las Gumnada Gumnavis).
- **Son navegables en cuanto salen de la zona montañosa.** Dentro de ella son río estrecho.
- **Nombres**: "1ro del Sara", "2do del Sara"… en el orden en que se unen al Sara, **de sur a norte**, contando las dos orillas.

Están pintados en `data/world/regions/valle_del_sara/agua.png` y salen de `tools/world/paint_afluentes.py` (puntos de control editables). Cada uno nace en una cumbre pequeña con colinas alrededor (`altura.png`). Donde cruza un camino lleva puente (`caminos.png`) y tiene algún vado. Su nombre está en `lugares.csv` como `lugar`, junto al río, y la vista previa lo rotula. El trazado sigue los límites del mapa a mano *(lectura)*, pasado a la escala de la autoría (el Valle del Sara del mapa → 12×16 chunks, 240×320 px).

**Estrecho o navegable** (regla del script): el afluente es estrecho desde el nacimiento y pasa a navegable en el primer píxel de nivel 0-1 a partir del cual ya no vuelve a cruzar 8 celdas seguidas de nivel 2 o más. Si lo navegable del final mide menos de 8 celdas, se queda todo estrecho. El norte del valle (Lean, Causie, Tossie, Alss) es casi todo nivel 2-3 y allí el propio Sara también es estrecho; por eso el 6to y el 7mo no llegan a salir de la montaña y son estrechos enteros.

| Nombre | Orilla | Baja de | Límite que sigue (mapa a mano) | Nace (px, chunk) | Llega al Sara (px, chunk) | Estrecho / navegable (celdas) |
|---|---|---|---|---|---|---|
| **1ro del Sara** | Oeste | Urd Gumnavis (colina del sur) | Ninguno: es el pequeño afluente del sur de Cassie, que el mapa no dibuja | (84, 303), chunk (4, 15) | (104, 300), chunk (5, 15) | 7 / 17 |
| **2do del Sara** | Este | Gumnada Gumnavis | Vastie–Cassie | (235, 160), chunk (11, 8) | (93, 194), chunk (4, 9) | 6 / 179 |
| **3ro del Sara** | Oeste | Urd Gumnavis | Ostie–Cassie (por la franja occidental de Cassie) | (4, 128), chunk (0, 6) | (91, 170), chunk (4, 8) | 9 / 121 |
| **4to del Sara** | Este | Gumnada Gumnavis | Alss–Vastie | (235, 104), chunk (11, 5) | (120, 125), chunk (6, 6) | 125 / 32 |
| **5to del Sara** | Oeste | Urd Gumnavis | Tossie–Ostie (borde sur de Tossie) | (4, 62), chunk (0, 3) | (99, 100), chunk (4, 5) | 49 / 89 |
| **6to del Sara** | Este | Gumnada Gumnavis | Causie–Alss | (235, 36), chunk (11, 1) | (117, 88), chunk (5, 4) | 179 / 0 |
| **7mo del Sara** | Oeste | Urd Gumnavis | Lean–Tossie (borde norte de Tossie) | (4, 30), chunk (0, 1) | (116, 56), chunk (5, 2) | 147 / 0 |

Notas:
- El tramo alto del Sara en el mapa baja por el límite Lean–Causie y después por Tossie–Alss y Ostie–Vastie. El Sara de la autoría ya iba por esa franja central y no se ha movido.
- *(lectura)* "Cerca de sur del lugar" se ha leído como el sur del Valle del Sara: el 1ro nace en una colina de Cassie, al oeste del Sara, en la última fila de chunks (la del borde sur).
- Pendiente de confirmar con el dueño: si el 6to y el 7mo deben tener tramo navegable aunque el norte sea montañoso y el Sara sea estrecho allí.

## Alcuss: subregiones
| Subregión | Posición (lectura del mapa) | Lenfi |
|---|---|---|
| **Adess** | Noroeste de Alcuss; al sur de Balasu y al este de Nosie | Sin dato |
| **Istil** | Oeste-centro, al sur de Adess; limita con Nosie y Cabuta | Sin dato |
| **Sass** | Centro, entre Istil y Ness; del lago Ungol (norte) a la costa (sur) | Sin dato. Su norte podría estar en la cordillera de Ungol *(lectura)* |
| **Ness** | Centro-este, entre Sass y Alciss; muy montañosa al norte; toca el lago | Sí, en varios lugares (dueño). Su norte montañoso podría ser cordillera de Ungol, sin lenfi *(lectura)* |
| **Alciss** | Extremo este; del lago a la costa; montañas al este. "La más alejada" | Sí, en varios lugares (dueño) |

## Mapa cultural lenfi (dueño, 2026-10-26)
Imagen: [`Sur-Lenfi_cultural.png`](Sur-Lenfi_cultural.png). El dueño la pasa "para cuando ampliemos más el mundo": no cambia nada de la 0.4 (solo se juega el Valle del Sara).

Cuatro regiones culturales lenfi, de oeste a este. **Equivalencias confirmadas por el dueño (2026-10-26)**: "si es así y Balasu es lenfi limaco culturalmente mas similar a la región de Alcuss".

| Cultura | Dónde *(lectura)* | Zona del mapa que parece cubrir |
|---|---|---|
| **Lenfi sáfico** | Extremo oeste, de las montañas a la península del sur | Safis |
| **Lenfi dórico** | Al este de Safis, del norte a la costa, con su red de ríos | Dorias |
| **Lenfi límaco** | La franja central más grande, del norte a la costa sur, con el río Sara y la red de ríos del este | Valle del Sara, Nosie y Balasu (Balasu, culturalmente más cercana a Alcuss); quizá el oeste de Alcuss |
| **Lenfi námco** | Noreste, alrededor del lago (Ungol) y los ríos que bajan a él | Naca |

- Las zonas sin color (la cordillera del norte, Balasu y el sur del lago) no tienen cultura lenfi marcada, coherente con "en la cordillera de Ungol no hay lenfi".
- Pendiente para cuando se amplíe el mundo: confirmar las equivalencias, qué distingue a cada cultura (lengua, nombres de villas, estilos de Bosque, oficios) y si cada una tiene su propia lista de nombres (`data/text/nombres_villas.json`). Lo ve `narrative-writer` con el dueño.

## Regiones del glosario
Las regiones del glosario §8 (Nan, Gumna, Ungol, Amuss, Hagat, Uta, Sanag, Sunasem, Ifa, Foss, etc.) son, según el dueño, **grupos de áreas dentro de las regiones del mapa** y "se integrarán en un futuro" (#94).

### Zonas lenfi por su nombre (dueño, 2026-10-26)
Imagen: [`Sur-Lenfi_zonas_lenfi.png`](Sur-Lenfi_zonas_lenfi.png). Dueño: "este es un mapa sobre las zonas más pobladas por lenfi y como ellos se reconocen por su región o como ellos llaman a esa zona". Ubica por primera vez varias regiones del glosario. Son los nombres **que usan los lenfi**; las zonas del mapa de arriba (Safis, Dorias, Valle del Sara…) siguen siendo los nombres del mapa.

De oeste a este (posiciones y equivalencias *(lectura)*, por confirmar):

| Zona lenfi | Dónde en la imagen | Corresponde a *(lectura)* |
|---|---|---|
| **Safio** | Oeste, bajo Larr | Norte de Safis |
| **Nan** | Al este de Safio, bajo Larr | Norte de Dorias (o entre Safis y Dorias) |
| **Dorias** | Sur de Nan, hacia la costa | Dorias (el mismo nombre) |
| **Sagra** | Franja de norte a sur al este de Dorias | Borde oeste del Valle del Sara y la cordillera occidental (Urd Gumnavis); quizá también el oeste de Lean, Tossie, Ostie |
| **Gumna** | La zona grande del centro, con forma de gancho, del norte a la costa sur | Valle del Sara (el resto) y Nosie; el nombre casa con las Urd Gumnavis y las Gumnada Gumnavis |
| **Calf** | Norte del lago Ungol, bajo Larr | Naca |
| **Ungol** | Alrededor del lago por el sur y el este | Orilla sur del lago: Balasu y el norte de Alcuss |
| **Amuss** | Noreste, al este de Ungol | Este de Naca o más allá del mapa del Sur Lenfi |
| **Uta** | Franja oscura al sureste | Este de Alcuss (Ness, Alciss) o más al este |
| **Larr** | Franja oscura de todo el norte | La cordillera norte: pared impenetrable (dueño, PR #68) |

- Las zonas blancas entre ellas están menos pobladas por lenfi, no vacías.
- **Límite entre Sagra y Gumna** (dueño, 2026-10-26): la línea roja de [`Sur-Lenfi_limite_sagra_gumna.png`](Sur-Lenfi_limite_sagra_gumna.png), de norte a sur desde Larr hasta la costa, al este de la franja verde clara de Sagra. Al oeste de la línea, Sagra; al este, Gumna.
- **Hagat, Sanag, Sunasem, Ifa y Foss** quedan **fuera del límite del juego** por ahora (dueño, 2026-10-26): son zonas de gentenueva, de otra parte del juego y de la historia. Fuera de la spec.

### Mapa de biomas (dueño, 2026-10-26)
Imagen: [`Sur-Lenfi_biomas.png`](Sur-Lenfi_biomas.png). Leyenda del dueño:

| Color | Bioma |
|---|---|
| Marrón | Alta montaña (Larr y los brazos que bajan de ella, el anillo alrededor del lago Ungol) |
| Verde oscuro | Bosque tupido con geografía de montañas y colinas |
| Verde claro | Zonas más llanas, con bosque menos tupido |
| Naranja | Zonas desérticas |

Lo que se lee *(lectura)*:
- Desierto en Dorias (casi entera), en la punta de la península de Safis y en una **franja costera** que va del sur de Sagra al sur de Gumna (la costa sur del Valle del Sara). Otra mancha desértica al este de Ungol.
- Verde oscuro (bosque tupido de montaña) bajo Larr en todo el norte, en la cordillera occidental entre Sagra y Gumna y alrededor del lago (Calf, Ungol).
- Verde claro en el interior de Safio, Nan, Sagra y el centro de Gumna (el valle del río).
- Uso: es la referencia para el **diseño de biomas** que va después de la 0.4 (paleta y formas fijas por bioma, transiciones suaves) y para retocar la autoría del Valle del Sara (`altura.png`, Bosques clave). Lo propone `game-designer`.

## Lugares con nombre (dueño)
- **Azhin** (dueño, 2026-10-25): "Azhin es una villa pequeña al noroeste del valle del Sara, es la villa mas septentrional y pegada a l cordillera occidental. Se supone que de ahi se originan los primeros nuevos bosques con la llegada de los ledai de la tarca de Trastas que está en la misma cordillera pero del lado de dorias, por la parte central de esta."
  - **Villa pequeña**, la **más septentrional** del Valle del Sara, en el **noroeste**, pegada a la **cordillera occidental**.
  - Tiene una **tarca** que es templo garelino (`docs/design/mechanics/lugares-e-interiores.md`).
  - De allí salieron los **primeros Nuevos Bosques**.
  - *(lectura)* Cae probablemente en la subregión **Lean** (norte-oeste). Por confirmar (#179).
- **Tarca de Trastas** (glosario §7: en Dorias): en la **misma cordillera occidental**, del **lado de Dorias**, hacia su **parte central** (dueño).
- **Cordillera occidental**: separa el Valle del Sara de Dorias. *(lectura)* En la imagen (`Sur-Lenfi_02.jpg`) no se ve una cordillera continua entre Dorias y el Valle del Sara: hay símbolos de montaña en el este de Dorias y en el oeste de Lean y Tossie, y la franja de montañas del norte. Conviene que el dueño la marque cuando pinte el mapa del Mundo 2.0 (#179).

## Frecuencia de Nuevos Bosques sobre el mapa (ADR 0007)
- Alta: Lean, Tossie, Ostie (noroeste del Valle del Sara, junto a Dorias).
- Muy rara: Nosie (al este del Valle del Sara).
- Casi imposible: Alciss (extremo este del mapa).
- *(lectura)* La frecuencia baja de oeste a este, coherente con una expansión iniciada en el noroeste del Valle del Sara.
- **Confirmado con Azhin** (dueño): la expansión empezó en **Azhin** (noroeste, junto a la cordillera occidental), con los ledai que cruzaron desde la Tarca de Trastas (Dorias). Encaja con la frecuencia alta en Lean, Tossie y Ostie, las subregiones del oeste que lindan con Dorias. No hay contradicción. Solo hace falta confirmar que Azhin está en Lean.

## Pendiente para pasar a `data/world/`
- Nombre del nivel "subregión" (#100).
- Cuántas áreas tiene cada subregión y cómo se dividen (#101).
- Nivel de Safis, Dorias, Nosie, Naca, Balasu y Cabuta (#102).
- Ríos grandes (navegables) y estrechos (#74). Pasos (#88). Afluentes del Sara: estrechos en la montaña y navegables fuera de ella (dueño, 2026-10-25).
- Significado de la marca azul (#96).
- Ubicación de las regiones del glosario como grupos de áreas (#94, "más adelante").
