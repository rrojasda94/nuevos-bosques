# Mapa del Sur Lenfi — descripción para datos

> Dueño: `game-designer` (contenido del mapa, ADR 0003). Fuente: `docs/design/world/Sur-Lenfi_02.jpg`, del dueño del proyecto. Es **preliminar**: el dueño lo irá puliendo.
> Este archivo describe solo lo que se ve en la imagen. Lo marcado como *(lectura)* es interpretación de `game-designer` y está pendiente de confirmar. Sirve de base para `data/world/` (`world-gen-dev`).

## Convenciones de la imagen
- **Norte arriba, sur abajo** (confirmado por el dueño, ADR 0008).
- Cada color de relleno es una región o un área. Las áreas de una misma región usan tonos distintos dentro del grupo.
- Los símbolos de montaña indican relieve montañoso.
- Las líneas negras gruesas y onduladas son *(lectura)* ríos. Algunas coinciden con límites entre áreas, así que no siempre es seguro si una línea es un río, un límite o ambas cosas (#97).
- La zona blanca del sur, con el rótulo "SUR", es *(lectura)* el mar o la zona fuera del mapa jugable. "SUR" parece el título del mapa, no una región.
- La imagen no tiene escala en km ni en tiles.

## Rasgos generales
- **Montañas**: una franja continua cubre todo el borde norte, de oeste a este. Hay además símbolos de montaña dentro de casi todas las regiones. Son densos en Balasu, en el norte de Ness, en el este de Alciss, en Vastie y en el norte de Dorias y Safis.
- **Costa**: todo el borde sur, desde Safis (oeste) hasta Alciss (este). Safis forma una península que se alarga hacia el sur en el extremo oeste.
- **Lago**: una gran masa blanca alargada al este, entre Naca (norte) y Balasu, Adess, Sass, Ness y Alciss (sur). *(lectura)* Podría ser el lago Ungol del glosario §8, porque el glosario sitúa Naca al norte del lago (#98).
- **Marca azul**: en la costa de Cassie, donde llega una línea de río. *(lectura)* Desembocadura del río Sara y posible Super Villa (el glosario §5 pone Super Villas en las desembocaduras del Sara, el Safis y el Gumna) (#96).

## Regiones (de oeste a este)
| Región | Posición | Áreas visibles | Notas |
|---|---|---|---|
| **Safis** | Extremo oeste; del norte (montañas) a la costa, con una península al sur | No se distinguen | Varios ríos bajan del norte y se unen hacia la costa *(lectura)*. |
| **Dorias** | Al este de Safis, del norte a la costa | No se distinguen | Red de ríos ramificada que converge en el centro y baja a la costa *(lectura)*. Al este limita con el Valle del Sara. |
| **Valle del Sara** | Al este de Dorias, del norte a la costa | 7 (tabla siguiente) | El mapa no rotula el nombre de la región. Se reconoce como grupo por los colores *(lectura)*. Región del MVP (ADR 0007). |
| **Nosie** | Al este del Valle del Sara, del norte hasta casi la costa; región grande (azul claro) | No se distinguen | Un río grande baja del norte y se ramifica: una rama va a la costa junto a Cabuta y otra al sureste, hacia Alcuss *(lectura)*. |
| **Naca** | Noreste, al norte del lago | No se distinguen | Ríos que bajan de las montañas hacia el lago *(lectura)*. |
| **Balasu** | Al este de Nosie, al sur del lago; región pequeña y muy montañosa | No se distinguen | Limita al sur con Adess. |
| **Cabuta** | Costa sur, al sur de Nosie y de Istil | No se distinguen | Al oeste toca a Cassie en la costa. |
| **Alcuss** | Sureste, al sur y sureste del lago | 5: Adess, Istil, Sass, Ness, Alciss | Alciss es la más oriental. |

## Valle del Sara: áreas
> Grafía: el mapa escribe **"Cassie"**; el dueño escribió "Casie" en el chat (#99). Aquí se usa la grafía del mapa.

| Área | Posición en la región | Vecinos (lectura del mapa) | Relieve y ríos (lectura) |
|---|---|---|---|
| **Lean** | Norte, oeste | Causie (E), Tossie (S), Dorias (O); al norte, la franja de montañas | Montañas en el norte. |
| **Causie** | Norte, este | Lean (O), Alss (S), Nosie (E); posible contacto con Tossie en la esquina SO | Montañas en el norte y el este. |
| **Tossie** | Norte-centro, oeste (bajo Lean) | Lean (N), Alss (E), Ostie (S y O); posible contacto con Dorias y Causie en las esquinas | Una línea de río bordea el área *(lectura)*. |
| **Alss** | Norte-centro, este (bajo Causie) | Causie (N), Tossie (O), Vastie (S), Nosie (E); posible contacto con Ostie en la esquina SO | Montañas. |
| **Ostie** | Centro, oeste | Tossie (N), Alss (NE, posible), Vastie (E), Cassie (S y O); posible contacto con Dorias en el NO | Ninguno destacado. |
| **Vastie** | Centro, este | Ostie (O), Alss (N), Nosie (E), Cassie (S) | Muy montañosa. Ríos en sus límites con Ostie y con Cassie *(lectura)*. |
| **Cassie** | Sur; llega a la costa. Tiene además una franja estrecha al oeste, entre Dorias y Ostie | Ostie (N), Vastie (N/NE), Dorias (O), Nosie (E), Cabuta (SE, en la costa); al sur, la costa | Un río la cruza de norte a sur hasta la marca azul de la costa *(lectura: el río Sara)*. Algunas montañas. |

**Norte y sur del Valle del Sara** (para "más agreste al norte; sur más plano con claros ribereños", ADR 0007):
- Norte: Lean, Causie, Tossie, Alss.
- Centro: Ostie, Vastie. Vastie es muy montañosa pese a estar en el centro.
- Sur: Cassie.

## Alcuss: áreas
| Área | Posición (lectura del mapa) |
|---|---|
| **Adess** | Noroeste de Alcuss; al sur de Balasu y al este de Nosie |
| **Istil** | Oeste-centro de Alcuss, al sur de Adess; limita con Nosie y Cabuta |
| **Sass** | Centro de Alcuss, entre Istil y Ness; se extiende del lago (norte) a la costa (sur) |
| **Ness** | Centro-este, entre Sass y Alciss; muy montañosa al norte; toca el lago |
| **Alciss** | Extremo este; del lago a la costa; montañas al este. Es "el área más alejada" (ADR 0008) |

## Frecuencia de Nuevos Bosques sobre el mapa (ADR 0007)
- Alta: Lean, Tossie, Ostie (noroeste del Valle del Sara, junto a Dorias).
- Muy rara: Nosie (región al este del Valle del Sara).
- Casi imposible: Alciss (extremo este del mapa).
- *(lectura)* La frecuencia baja de oeste a este, coherente con una expansión iniciada en el noroeste del Valle del Sara.

## Pendiente para pasar a `data/world/`
- Escala real: cuántos Bosques o chunks mide cada área (#95).
- Qué líneas son ríos y cuáles navegables (#74, #97).
- Nombre del lago (#98) y significado de la marca azul (#96).
- Áreas de las regiones que en el mapa no muestran subdivisiones (Safis, Dorias, Nosie, Naca, Balasu, Cabuta).
