extends RefCounted

static func load_world() -> Dictionary:
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
 assert(parsed is Dictionary and parsed.has("rooms") and parsed.has("items"), "Invalid world data")
 var chapter: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_one.json"))
 assert(chapter is Dictionary and chapter.has("rooms") and chapter.has("items"), "Invalid chapter data")
 parsed["chapter_one"] = chapter
 return parsed
