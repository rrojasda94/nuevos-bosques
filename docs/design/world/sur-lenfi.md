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
- **Río Sara** (confirmado): la línea que cruza Cassie de norte a sur hasta la costa. **Las líneas que se le unen son sus afluentes.** *(lectura)* Los afluentes visibles bajan por los límites de Tossie, Ostie y Vastie y por el límite de Vastie con Cassie.
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
| **Tossie** | Norte-centro, oeste (bajo Lean) | Lean (N), Alss (E), Ostie (S y O); posible contacto con Dorias y Causie en las esquinas | Bordeada por un afluente del Sara *(lectura)*. |
| **Alss** | Norte-centro, este (bajo Causie) | Causie (N), Tossie (O), Vastie (S), Nosie (E); posible contacto con Ostie en la esquina SO | Montañas. |
| **Ostie** | Centro, oeste | Tossie (N), Alss (NE, posible), Vastie (E), Cassie (S y O); posible contacto con Dorias en el NO | Afluente en su límite con Vastie *(lectura)*. |
| **Vastie** | Centro, este | Ostie (O), Alss (N), Nosie (E), Cassie (S) | Muy montañosa. Afluentes en sus límites con Ostie y con Cassie *(lectura)*. |
| **Cassie** | Sur; llega a la costa. Tiene además una franja estrecha al oeste, entre Dorias y Ostie | Ostie (N), Vastie (N/NE), Dorias (O), Nosie (E), Cabuta (SE, en la costa); al sur, la costa | **El río Sara la cruza** de norte a sur hasta la desembocadura (marca azul). Algunas montañas. |

**Norte y sur del Valle del Sara** (para "más agreste al norte; sur más plano con claros ribereños", ADR 0007):
- Norte: Lean, Causie, Tossie, Alss.
- Centro: Ostie, Vastie. Vastie es muy montañosa pese a estar en el centro.
- Sur: Cassie.

## Alcuss: subregiones
| Subregión | Posición (lectura del mapa) | Lenfi |
|---|---|---|
| **Adess** | Noroeste de Alcuss; al sur de Balasu y al este de Nosie | Sin dato |
| **Istil** | Oeste-centro, al sur de Adess; limita con Nosie y Cabuta | Sin dato |
| **Sass** | Centro, entre Istil y Ness; del lago Ungol (norte) a la costa (sur) | Sin dato. Su norte podría estar en la cordillera de Ungol *(lectura)* |
| **Ness** | Centro-este, entre Sass y Alciss; muy montañosa al norte; toca el lago | Sí, en varios lugares (dueño). Su norte montañoso podría ser cordillera de Ungol, sin lenfi *(lectura)* |
| **Alciss** | Extremo este; del lago a la costa; montañas al este. "La más alejada" | Sí, en varios lugares (dueño) |

## Regiones del glosario
Las regiones del glosario §8 (Nan, Gumna, Ungol, Amuss, Hagat, Uta, Sanag, Sunasem, Ifa, Foss, etc.) son, según el dueño, **grupos de áreas dentro de las regiones del mapa** y "se integrarán en un futuro" (#94). Todavía no están ubicadas.

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
- Ríos grandes (navegables) y estrechos (#74). Pasos (#88).
- Significado de la marca azul (#96).
- Ubicación de las regiones del glosario como grupos de áreas (#94, "más adelante").
