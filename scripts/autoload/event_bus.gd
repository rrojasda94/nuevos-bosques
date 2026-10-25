extends Node
## EventBus: solo señales. Sin lógica. Todos los sistemas se comunican por aquí.

# --- Tiempo / simulación (días: ADR 0002; tiempo real con pausa en Aventura: ADR 0012) ---
signal end_day_requested
signal day_ended(day: int)
signal day_started(day: int)
## Reloj de Aventura (ADR 0012, WorldClock). Orden en cada cambio de Momento: riutash_warning
## (60 y 15 s antes), riutash_passed y momento_changed. momento: &"gietos" o &"riumna".
signal riutash_warning(seconds_left: int)
## sheltered: el jugador estaba en un refugio (REFUGE o plaza de villa) al pasar el riutash.
signal riutash_passed(sheltered: bool)
signal momento_changed(momento: StringName)

# --- Mundo (ADR 0003) ---
signal chunk_generated(region_id: StringName, seed_value: int)
## El jugador entra en un chunk (al empezar, al cruzar un borde o al cambiar de seed).
signal chunk_entered(chunk_coord: Vector2i, bosque_id: int, bosque_size: int)
## Un Botarramas de un Bosque cerrado alcanza al jugador o, como red de seguridad, el jugador
## empuja contra el borde de un Bosque cerrado sin nadie que le persiga (abre el menú del borde,
## ADR 0009, monstruos.md).
## bosque_id = -1 si el borde es el límite de la región.
signal bosque_border_reached(bosque_id: int)
## El jugador lee un letrero de piedra. direction = "norte", "sureste"... hacia la villa.
## kind = ChunkData.SignKind: villa del Bosque actual o villa natal (camino principal).
signal signpost_read(direction: String, kind: int)

# --- Ciudad ---
signal build_requested(building_id: StringName, cell: Vector2i)
signal building_placed(building_id: StringName, cell: Vector2i)
signal building_completed(building_id: StringName, cell: Vector2i)
signal resource_changed(resource_id: StringName, amount: int)
signal citizen_arrived(citizen_id: StringName)

# --- RPG ---
signal expedition_started(bosque_id: int)
signal expedition_completed(bosque_id: int, loot: Dictionary, days_spent: int)
## Combate contra el Único de un Bosque (ADR 0009). result: &"victory", &"defeat", &"fled",
## &"appeased" (se fue con una ofrenda, ofrendas-v1.md) o &"game_over".
signal battle_started(bosque_id: int)
signal battle_ended(bosque_id: int, result: StringName)
## Fin del menú del borde de un Bosque. outcome: &"paid" (con Luz, con una ofrenda o con una
## ofrenda en combate) o &"won" (paso abierto: se cruza),
## &"retreated" o &"fled" (se vuelve atrás), &"defeated" (se despierta junto al Nujio aliado más
## cercano, AdventureRules.respawn_target),
## &"game_over" (derrota contra un monstruo fatal: partida nueva).
signal crossing_resolved(bosque_id: int, outcome: StringName)
signal luz_changed(luz: int)
signal hp_changed(hp: int, max_hp: int)
## Equipo del Adoc (roadmap-0.3.md #113). slot: &"main_hand", &"mask" o &"talisman".
signal item_equipped(slot: StringName, item_id: StringName)
signal item_unequipped(slot: StringName, item_id: StringName)
## El Adoc descansa en una villa (PV al máximo).
signal rested_in_villa
## El Adoc ha robado al Bosque (p. ej. un fruto sin permiso o un segundo fruto del mismo Bosque
## en el Momento, FruitRules). La exploración despierta a los Ofomni que le persiguen (OfomniGuard).
signal bosque_robbed(bosque_id: int)
## Combate directo contra un Único que va por dentro de su Bosque (Crossing): un Ofomni que
## persigue tras un robo, un cazador que envía el Bosque, uno que ronda, o uno al que el Adoc se
## enfrenta a voluntad (E). monster_id: id de datos (balance.json, monsters). offends: el Bosque
## tenía el paso abierto y atacar a su Único le ofende (si gana, el Bosque pasa a forzado).
signal unico_battle_requested(bosque_id: int, monster_id: StringName, offends: bool)
## Fin de ese combate. outcome: &"victory", &"appeased", &"defeat", &"fled" o &"game_over".
signal unico_battle_resolved(bosque_id: int, outcome: StringName)
## La relación con un Bosque ha cambiado (bosques-y-relacion.md). relation: el valor nuevo
## (-100 .. 100).
signal bosque_relation_changed(bosque_id: int, relation: int)
## El paso pagado de un Bosque ha caducado tras un riutash: vuelve a cerrado (o a forzado) y sus
## Botarramas vuelven a exigir el pago.
signal bosque_toll_expired(bosque_id: int)
## El estado de un Bosque cambia durante la partida (BosqueStates; p. ej. sano -> enojado al caer
## la relación). state: "sano", "enojado", "corrupto", "muerto" o "necesita_ayuda".
signal bosque_state_changed(bosque_id: int, state: String)
## El Adoc apaga el incendio del chunk de un Bosque que necesita ayuda (BosqueFires).
signal bosque_fire_extinguished(bosque_id: int, chunk_coord: Vector2i)
## El Adoc entra en un Bosque distinto del anterior (la exploración avisa de su estado).
signal bosque_entered(bosque_id: int, state: String)
## El Adoc deja una ofrenda ante el Nujio de un Bosque (sin pagar peaje con ella).
signal bosque_ofrenda_left(bosque_id: int, item_id: StringName)
## El jugador empieza a hablar con un NPC (E). Las misiones lo escuchan (PR 6).
signal npc_talked(npc_id: StringName)
signal quest_state_changed(quest_id: StringName, state: StringName)
## El jugador alcanza (o es alcanzado por) el monstruo de una misión: empieza su combate.
signal quest_battle_requested(quest_id: StringName)
## Fin del combate de misión. outcome: &"victory", &"defeat", &"fled" o &"game_over".
signal quest_battle_resolved(quest_id: StringName, outcome: StringName)
## Aviso temporal en el HUD (p. ej. "El Nujio vuelve a oír al Ofomni").
signal notice_requested(text: String)
## El personaje sube de nivel (progresion-adoc.md). Una vez por nivel; id &"adoc".
signal character_leveled_up(character_id: StringName, level: int)
signal game_ended(reason: StringName)

# --- Partida ---
signal game_saved(slot: int)
signal game_loaded(slot: int)
signal scene_change_requested(scene_path: String)
