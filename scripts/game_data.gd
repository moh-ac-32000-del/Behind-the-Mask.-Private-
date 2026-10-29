extends RefCounted

static func load_world() -> Dictionary:
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
 assert(parsed is Dictionary and parsed.has("rooms") and parsed.has("items"), "Invalid world data")
 return parsed
