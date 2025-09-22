extends Node
class_name EggSystem

const BROOD_TYPE := StringName("Brood")
const DAMAGED_TYPE := StringName("Damaged")

func feed_queen(tier: StringName) -> bool:
    var cost: Dictionary = ConfigDB.eggs_get_feed_cost(tier)
    if cost.is_empty():
        UIFx.flash_deny()
        return false
    if not GameState.spend(cost):
        UIFx.flash_deny()
        return false
    var egg_id: StringName = _egg_id(tier)
    InventorySystem.add_item(egg_id, 1)
    if typeof(Events) == TYPE_OBJECT:
        Events.queen_fed.emit(tier)
        Events.egg_added.emit(tier, 1)
    return true

func insert_egg(cell_id: int, tier: StringName) -> bool:
    if HiveSystem.get_cell_type(cell_id) != String(BROOD_TYPE):
        UIFx.flash_deny()
        return false
    var meta: Dictionary = HiveSystem.get_cell_metadata(cell_id)
    if meta.has("hatch"):
        UIFx.flash_deny()
        return false
    var egg_id: StringName = _egg_id(tier)
    if not InventorySystem.has_item(egg_id, 1):
        UIFx.flash_deny()
        return false
    if not InventorySystem.remove_item(egg_id, 1):
        UIFx.flash_deny()
        return false
    var secs: float = ConfigDB.eggs_get_hatch_secs(tier)
    var ends_at: float = Time.get_unix_time_from_system() + secs
    HiveSystem.set_cell_metadata(cell_id, "hatch", {
        "tier": tier,
        "ends_at": ends_at
    })
    HiveSystem.attach_timer(cell_id, "hatch", secs, func() -> void:
        _on_hatch(cell_id, tier)
    )
    if typeof(Events) == TYPE_OBJECT:
        Events.egg_consumed.emit(tier, 1)
        Events.brood_egg_inserted.emit(cell_id, tier, ends_at)
    return true

func _on_hatch(cell_id: int, original_tier: StringName) -> void:
    var entry: Dictionary = HiveSystem.get_cell_entry(cell_id)
    if entry.get("type", "") != String(BROOD_TYPE):
        return
    var final_tier: StringName = _apply_bump(original_tier)
    var trait_count: int = ConfigDB.eggs_get_traits_per_rarity(final_tier)
    var traits: Array[StringName] = TraitsSystem.generate_for_rarity(final_tier, trait_count)
    var outline: Color = ConfigDB.eggs_get_rarity_outline_color(final_tier)
    var bee_id: int = GameState.add_bee({
        "rarity": final_tier,
        "traits": traits,
        "outline_color": outline
    })
    HiveSystem.set_cell_metadata(cell_id, "hatch", {})
    HiveSystem.set_cell_type(cell_id, DAMAGED_TYPE)
    if typeof(Events) == TYPE_OBJECT:
        Events.bee_hatched.emit(cell_id, bee_id, final_tier)

func _apply_bump(tier: StringName) -> StringName:
    if tier == StringName("Common"):
        var chance: float = ConfigDB.eggs_bump_prob("CommonToUnique")
        if randf() < chance:
            return StringName("Unique")
    elif tier == StringName("Unique"):
        var chance_unique: float = ConfigDB.eggs_bump_prob("UniqueToRare")
        if randf() < chance_unique:
            return StringName("Rare")
    return tier

func _egg_id(tier: StringName) -> StringName:
    return StringName("Egg" + String(tier))
