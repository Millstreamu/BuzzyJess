extends Node

var resources: Dictionary = {
    "Comb": 40,
    "Honey": 30,
    "Pollen": 30,
    "NectarCommon": 25,
    "PetalRed": 10
}

func can_afford(cost: Dictionary) -> bool:
    for key in cost.keys():
        var amount: float = cost[key]
        if resources.get(key, 0) < amount:
            return false
    return true

func spend(cost: Dictionary) -> bool:
    if not can_afford(cost):
        return false
    for key in cost.keys():
        resources[key] = resources.get(key, 0) - cost[key]
    return true

func get_resources_snapshot() -> Dictionary:
    return resources.duplicate(true)
