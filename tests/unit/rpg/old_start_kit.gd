extends RefCounted
## Ayuda de tests (no es un test: no empieza por test_). Deja GameState con el equipo de una partida
## nueva de antes de P4: nada equipado, nada en la mano y la bolsa de prueba (la lanza, 3 máscaras y
## 2 talismanes). Los tests escritos antes del equipo inicial (ajustes-playtest-0.5.md 5c) cuentan
## con ese punto de partida; el equipo inicial nuevo se prueba en test_tactical_weapons_items.gd.

const BAG: Array[StringName] = [&"lanza_de_adoc", &"mascara_de_corteza", &"talisman_de_semillas",
	&"mascara_de_musgo", &"mascara_de_ceniza", &"talisman_de_pluma"]


static func apply() -> void:
	GameState.equipped = InventoryLogic.new_equipped()
	GameState.weapon_drawn = false
	GameState.bag = InventoryLogic.new_bag(Items.bag_size())
	for id: StringName in BAG:
		InventoryLogic.add(GameState.bag, id)
