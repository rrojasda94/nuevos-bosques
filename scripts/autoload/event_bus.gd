extends Node
## EventBus: solo señales. Sin lógica. Todos los sistemas se comunican por aquí.

# --- Tiempo / simulación (por días, ver ADR 0002) ---
signal end_day_requested
signal day_ended(day: int)
signal day_started(day: int)

# --- Mundo (ADR 0003) ---
signal chunk_generated(region_id: StringName, seed_value: int)
## El jugador entra en un chunk (al empezar, al cruzar un borde o al cambiar de seed).
signal chunk_entered(chunk_coord: Vector2i, bosque_id: int, bosque_size: int)
## El jugador empuja contra el borde de un Bosque cerrado (abre el menú del borde, ADR 0009).
## bosque_id = -1 si el borde es el límite de la región.
signal bosque_border_reached(bosque_id: int)
## El jugador lee un letrero de piedra. direction = "norte", "sureste"... hacia la villa.
signal signpost_read(direction: String)

# --- Ciudad ---
signal build_requested(building_id: StringName, cell: Vector2i)
signal building_placed(building_id: StringName, cell: Vector2i)
signal building_completed(building_id: StringName, cell: Vector2i)
signal resource_changed(resource_id: StringName, amount: int)
signal citizen_arrived(citizen_id: StringName)

# --- RPG ---
signal expedition_started(zone_id: StringName)
signal expedition_completed(zone_id: StringName, loot: Dictionary, days_spent: int)
## Combate contra el Único de un Bosque (ADR 0009). result: &"victory", &"defeat" o &"fled".
signal battle_started(bosque_id: int)
signal battle_ended(bosque_id: int, result: StringName)
## Fin del menú del borde de un Bosque. outcome: &"paid" o &"won" (paso abierto: se cruza),
## &"retreated" o &"fled" (se vuelve atrás), &"defeated" (se despierta en el Nujio inicial).
signal crossing_resolved(bosque_id: int, outcome: StringName)
signal luz_changed(luz: int)
signal hp_changed(hp: int, max_hp: int)
## El Adoc descansa en una villa (PV al máximo).
signal rested_in_villa
signal quest_state_changed(quest_id: StringName, state: StringName)
signal character_leveled_up(character_id: StringName, level: int)
signal game_over(reason: StringName)

# --- Partida ---
signal game_saved(slot: int)
signal game_loaded(slot: int)
signal scene_change_requested(scene_path: String)
