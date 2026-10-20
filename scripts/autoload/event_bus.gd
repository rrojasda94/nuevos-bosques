extends Node
## EventBus: solo señales. Sin lógica. Todos los sistemas se comunican por aquí.

# --- Tiempo / simulación ---
signal tick(ticks: int)

# --- Ciudad ---
signal build_requested(building_id: StringName, cell: Vector2i)
signal building_placed(building_id: StringName, cell: Vector2i)
signal building_completed(building_id: StringName, cell: Vector2i)
signal resource_changed(resource_id: StringName, amount: int)
signal citizen_arrived(citizen_id: StringName)

# --- RPG ---
signal expedition_started(zone_id: StringName)
signal expedition_completed(zone_id: StringName, loot: Dictionary)
signal combat_started(encounter_id: StringName)
signal combat_ended(victory: bool)
signal quest_state_changed(quest_id: StringName, state: StringName)
signal character_leveled_up(character_id: StringName, level: int)

# --- Partida ---
signal game_saved(slot: int)
signal game_loaded(slot: int)
signal scene_change_requested(scene_path: String)
