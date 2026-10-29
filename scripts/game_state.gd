extends Node
# Campaign progress is required for continuity. Optional report history is separate.
const World = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/investigation_rules.gd")
const Store = preload("res://scripts/save_store.gd")
const VERSION := 3
var world := World.load_world()
var store = Store.new()
var room := "lobby"
var player_name := "الزائر"
var names: Array = []
var evidence: Dictionary = {}
var decisions: Dictionary = {}
var deductions: Dictionary = {}
var finale := ""
var report_consent := false
var report_history: Array = []
var has_campaign := false
var save_blocked := false
var notice := ""
var purge_report_pending := false

func _ready() -> void:
 names = world["names"].duplicate()
 restore()

func begin(player: String, character_names: Array, consent: bool) -> bool:
 room = "lobby"
 player_name = player.strip_edges().left(40) if not player.strip_edges().is_empty() else "الزائر"
 names = world["names"].duplicate()
 for i in range(mini(character_names.size(), names.size())):
  var value := str(character_names[i]).strip_edges().left(40)
  if not value.is_empty():
   names[i] = value
 evidence = {}
 decisions = {}
 deductions = {}
 finale = ""
 report_consent = consent
 report_history = []
 has_campaign = true
 save_blocked = false
 return persist(true)

func character(role: int) -> String:
 return str(names[role]) if role >= 0 and role < names.size() else "ساكن"

func acquire(key: String) -> bool:
 if not finale.is_empty() or not world["items"].has(key):
  return false
 if not world["rooms"][room]["objects"].has(key):
  return false
 if key == "file" and not Rules.can_open_file(evidence):
  return false
 if not evidence.has(key):
  evidence[key] = true
  _record("evidence", key)
 return persist()

func choose(key: String, value: Variant) -> bool:
 if not finale.is_empty() or decisions.has(key):
  return false
 if key == "guard_trust":
  if room != "lobby" or not (value is int) or not value in [-1, 1]:
   return false
  evidence["guard"] = true
 elif key == "phone_secret":
  if room != "apartment" or not (value is bool):
   return false
  evidence["phone"] = true
 else:
  return false
 decisions[key] = value
 _record(key, value)
 return persist()

func enter(destination: String) -> String:
 if not world["rooms"][room]["exits"].has(destination):
  return "لا يوجد ممر من هنا إلى هذه المنطقة."
 var message := Rules.access_message(destination, evidence, decisions)
 if not message.is_empty():
  return message
 room = destination
 persist()
 return ""

func infer(key: String, selected: Array) -> bool:
 if not finale.is_empty() or not world["deductions"].has(key):
  return false
 var needed: Array = world["deductions"][key]["requires"]
 if selected.size() != needed.size():
  return false
 for clue in needed:
  if not evidence.has(clue) or not selected.has(clue):
   return false
 if deductions.has(key):
  return true
 deductions[key] = true
 _record("deduction", key)
 return persist()

func clue_count() -> int:
 var count := 0
 for key in world["required_clues"]:
  if evidence.has(key):
   count += 1
 return count

func stage() -> int:
 var count := clue_count()
 return 3 if count == 5 else (2 if count >= 3 else (1 if count >= 1 else 0))

func can_finish() -> bool:
 return clue_count() == world["required_clues"].size() and deductions.has("mirror_project")

func finish(choice: String) -> bool:
 if not can_finish() or not finale.is_empty() or not choice in ["كشف الحقيقة", "البحث عن النسخة"]:
  return false
 decisions["finale"] = choice
 finale = Rules.outcome(int(decisions.get("guard_trust", 0)), decisions.get("phone_secret"), choice)
 _record("finale", choice)
 return persist()

func set_report_consent(enabled: bool) -> bool:
 report_consent = enabled
 if not enabled:
  report_history.clear()
 return persist(not enabled)

func _record(kind: String, value: Variant) -> void:
 if report_consent:
  report_history.append({"kind": kind, "value": value, "room": room})

func snapshot() -> Dictionary:
 return {"version": VERSION, "room": room, "player": player_name, "names": names.duplicate(), "evidence": evidence.duplicate(), "decisions": decisions.duplicate(), "deductions": deductions.duplicate(), "finale": finale, "report_consent": report_consent, "report_history": report_history.duplicate(true)}

func persist(purge_report: bool = false) -> bool:
 if save_blocked:
  return false
 purge_report_pending = purge_report_pending or purge_report
 var success: bool = store.write(snapshot(), purge_report_pending)
 if not success:
  notice = store.error_message
 else:
  notice = ""
  purge_report_pending = false
 return success

func restore(legacy_path: String = "user://exploration_v1.json", identity_path: String = "user://behind_the_mask_save.json") -> bool:
 for candidate in store.candidates():
  if candidate["path"] == store.path and (candidate["data"].get("version") is int or candidate["data"].get("version") is float) and candidate["data"]["version"] > VERSION:
   save_blocked = true
   notice = "ملف الحفظ من إصدار أحدث. احتُفظ به دون تغيير."
   return false
  var normalized := _normalize(candidate["data"])
  if normalized.is_empty():
   continue
  _apply(normalized)
  store.selected_path = candidate["path"]
  has_campaign = true
  save_blocked = false
  if store.selected_path != store.path:
   notice = "استُعيد التقدم من نسخة احتياطية."
  return true
 if store.exists():
  save_blocked = true
  notice = "تعذر قراءة الحفظ أو أن إصداره أحدث. احتُفظ به؛ يمكنك بدء جولة جديدة."
  return false
 if not FileAccess.file_exists(legacy_path):
  return false
 var legacy: Variant = JSON.parse_string(FileAccess.get_file_as_string(legacy_path))
 if not (legacy is Dictionary) or not (legacy.get("discovered") is Dictionary) or not (legacy.get("decisions") is Dictionary):
  notice = "تعذر استيراد الحفظ القديم. احتُفظ بالملف الأصلي."
  return false
 var old_evidence: Dictionary = legacy["discovered"].duplicate()
 var old_decisions: Dictionary = legacy["decisions"].duplicate()
 # The old prototype counted merely inspecting a locked dossier as evidence.
 if not old_decisions.has("file") or not old_evidence.has("terminal"):
  old_evidence.erase("file")
 var migrated := {"version": VERSION, "room": legacy.get("room", "lobby"), "evidence": old_evidence, "decisions": old_decisions}
 var identity: Variant = JSON.parse_string(FileAccess.get_file_as_string(identity_path)) if FileAccess.file_exists(identity_path) else null
 if identity is Dictionary:
  migrated["player"] = identity.get("player", "الزائر")
  migrated["names"] = identity.get("names", world["names"])
 var normalized := _normalize(migrated)
 if normalized.is_empty():
  return false
 _apply(normalized)
 has_campaign = true
 if persist():
  notice = "استُورد الحفظ القديم. أكمل ربط الأدلة في دفتر التحقيق."
  return true
 return false

func _normalize(data: Dictionary) -> Dictionary:
 if data.get("version") != VERSION:
  return {}
 for field in ["evidence", "decisions", "deductions"]:
  if data.has(field) and not (data[field] is Dictionary):
   return {}
 if data.has("names") and not (data["names"] is Array):
  return {}
 if data.has("report_history") and not (data["report_history"] is Array):
  return {}
 if not (data.get("player", "الزائر") is String) or not (data.get("room", "lobby") is String):
  return {}
 if not (data.get("report_consent", false) is bool) or not (data.get("finale", "") is String):
  return {}
 var clean := {"version": VERSION, "room": data.get("room", "lobby"), "player": data.get("player", "الزائر").left(40), "names": world["names"].duplicate(), "evidence": {}, "decisions": {}, "deductions": {}, "report_consent": data.get("report_consent", false), "report_history": [], "finale": ""}
 if not world["rooms"].has(clean["room"]):
  clean["room"] = "lobby"
 var saved_names: Array = data.get("names", [])
 for i in range(mini(saved_names.size(), clean["names"].size())):
  if saved_names[i] is String and not saved_names[i].strip_edges().is_empty():
   clean["names"][i] = saved_names[i].strip_edges().left(40)
 var saved_evidence: Dictionary = data.get("evidence", {})
 for key in saved_evidence:
  if world["items"].has(key) and saved_evidence[key] == true:
   clean["evidence"][key] = true
 if not clean["evidence"].has("terminal"):
  clean["evidence"].erase("file")
 var saved_decisions: Dictionary = data.get("decisions", {})
 var trust: Variant = saved_decisions.get("guard_trust")
 if (trust is int or trust is float) and (trust == -1 or trust == 1):
  clean["decisions"]["guard_trust"] = int(trust)
 var secret: Variant = saved_decisions.get("phone_secret")
 if secret is bool:
  clean["decisions"]["phone_secret"] = secret
 var saved_deductions: Dictionary = data.get("deductions", {})
 for key in world["deductions"]:
  if saved_deductions.get(key) != true:
   continue
  var valid := true
  for clue in world["deductions"][key]["requires"]:
   if not clean["evidence"].has(clue):
    valid = false
  if valid:
   clean["deductions"][key] = true
 if clean["report_consent"]:
  clean["report_history"] = data.get("report_history", []).duplicate(true)
 var final_choice: Variant = saved_decisions.get("finale")
 var complete := true
 for clue in world["required_clues"]:
  if not clean["evidence"].has(clue):
   complete = false
 if complete and clean["deductions"].has("mirror_project") and final_choice in ["كشف الحقيقة", "البحث عن النسخة"]:
  clean["decisions"]["finale"] = final_choice
  clean["finale"] = Rules.outcome(int(clean["decisions"].get("guard_trust", 0)), clean["decisions"].get("phone_secret"), final_choice)
 return clean

func _apply(data: Dictionary) -> void:
 room = data["room"]
 player_name = data["player"]
 names = data["names"]
 evidence = data["evidence"]
 decisions = data["decisions"]
 deductions = data["deductions"]
 finale = data["finale"]
 report_consent = data["report_consent"]
 report_history = data["report_history"]
 purge_report_pending = not report_consent
