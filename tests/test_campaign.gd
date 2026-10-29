extends SceneTree
const Campaign = preload("res://scripts/game_state.gd")
const Store = preload("res://scripts/save_store.gd")
var checks := 0
var failures := 0
var sequence := 0
var test_dir := "user://foundation-tests-" + str(Time.get_ticks_usec())

func _initialize() -> void:
 call_deferred("_run")

func check(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error(message)

func fresh():
 sequence += 1
 var campaign = Campaign.new()
 campaign.store = Store.new(test_dir + "/case-%d.json" % sequence)
 check(campaign.begin("محقق تجريبي", ["مدير", "حارس تجريبي"], false), "New campaign saves")
 return campaign

func write_json(path: String, value: Variant) -> void:
 var file := FileAccess.open(path, FileAccess.WRITE)
 file.store_string(JSON.stringify(value))
 file.close()

func _run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_dir))
 for trust in [-1, 0, 1]:
  for secrecy in [null, false, true]:
   for ending in ["كشف الحقيقة", "البحث عن النسخة"]:
    var campaign = fresh()
    if trust != 0:
     check(campaign.choose("guard_trust", trust), "Guard decision saves")
     check(not campaign.choose("guard_trust", -trust), "Guard decision cannot be farmed or overwritten")
    check(campaign.acquire("board"), "Document announcement")
    check(campaign.enter("lift").is_empty(), "Reach lift")
    check(campaign.enter("hall").is_empty(), "Reach hall")
    check(not campaign.enter("roof").is_empty(), "Cannot teleport between rooms")
    if trust <= 0:
     check(not campaign.enter("records").is_empty(), "No trust requires camera clue")
     check(campaign.acquire("camera"), "Camera provides alternate access")
    check(campaign.enter("records").is_empty(), "Both trust routes reach records")
    check(not campaign.acquire("file"), "Locked file never becomes evidence")
    check(not campaign.evidence.has("file"), "Locked dossier absent from notebook")
    check(campaign.acquire("terminal"), "Acquire terminal")
    check(campaign.acquire("file"), "Dossier opens after terminal")
    check(not campaign.infer("mirror_project", ["board", "file"]), "Partial deduction rejected")
    check(campaign.infer("mirror_project", ["board", "terminal", "file"]), "Player connects matching clues")
    check(campaign.enter("hall").is_empty(), "Leave records")
    check(campaign.enter("apartment").is_empty(), "Reach apartment")
    if secrecy != null:
     check(campaign.choose("phone_secret", secrecy), "Phone decision saves")
     check(not campaign.choose("phone_secret", not secrecy), "Phone decision remains consistent")
    else:
     check(campaign.acquire("phone"), "May document phone without deciding secrecy")
    check(campaign.enter("hall").is_empty(), "Leave apartment")
    check(campaign.enter("stairwell").is_empty(), "Reach stairwell")
    check(campaign.enter("roof").is_empty(), "Reach roof")
    if secrecy != false:
     check(not campaign.enter("maintenance").is_empty(), "No shared code requires antenna")
     check(campaign.acquire("antenna"), "Antenna provides alternate access")
    check(campaign.enter("maintenance").is_empty(), "Both secrecy routes reach maintenance")
    check(not campaign.can_finish(), "Cannot finish before documenting recorder")
    check(campaign.acquire("recorder"), "Document recorder")
    check(campaign.can_finish(), "All evidence and explicit deduction required")
    check(campaign.finish(ending), "Finish full route")
    var result: String = campaign.finale
    check(result.contains("يساعدك") if trust > 0 else (result.contains("يبلغ") if trust < 0 else result.contains("لا أحد")), "Ending remembers guard decision")
    check(result.contains("لم تحسم") if secrecy == null else (result.contains("سرية") if secrecy else result.contains("تصل الرسالة")), "Ending distinguishes three secrecy states")
    check(not campaign.choose("phone_secret", true), "Finished decisions frozen")
    check(not campaign.acquire("switch"), "Finished evidence frozen")
    var restored = Campaign.new()
    restored.store = Store.new(campaign.store.path)
    check(restored.restore("user://missing-legacy"), "Campaign restores after restart")
    check(restored.finale == result and restored.character(1) == "حارس تجريبي", "Identity and outcome survive restart")
    check(restored.report_history.is_empty(), "No optional report collected without consent")
    restored.free()
    campaign.free()
 _save_cases()
 await _scene_cases()
 print("Campaign regression: %d checks, %d failures" % [checks, failures])
 # Only files in this unique test-owned directory are removed.
 for file in DirAccess.get_files_at(test_dir):
  DirAccess.remove_absolute(ProjectSettings.globalize_path(test_dir.path_join(file)))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(test_dir))
 quit(1 if failures else 0)

func _save_cases() -> void:
 var campaign = fresh()
 check(campaign.set_report_consent(true), "Explicit report opt-in")
 check(campaign.acquire("board"), "Consent-enabled action saves")
 check(campaign.report_history.size() == 1, "Optional history recorded once")
 check(campaign.set_report_consent(false), "Consent can be revoked")
 for candidate in campaign.store.candidates():
  check(candidate["data"]["report_history"].is_empty(), "History removed from current and backup saves")
 var corrupt := FileAccess.open(campaign.store.path, FileAccess.WRITE)
 corrupt.store_string("{ interrupted")
 corrupt.close()
 var recovered = Campaign.new()
 recovered.store = Store.new(campaign.store.path)
 check(recovered.restore("user://missing-legacy"), "Corrupt primary falls back to backup")
 check(recovered.evidence.has("board"), "Recovered evidence intact")
 check(recovered.persist(), "Recovered campaign can save again")
 check(recovered.store.candidates()[0]["data"]["version"] == 3, "Recovery repairs primary")
 write_json(campaign.store.path, {"version": 999, "evidence": {}})
 var future = Campaign.new()
 future.store = Store.new(campaign.store.path)
 check(not future.restore("user://missing-legacy"), "Future save version is protected")
 check(future.save_blocked and not future.persist(), "Future save cannot be overwritten automatically")
 var migrated = Campaign.new()
 migrated.store = Store.new(test_dir + "/migrated.json")
 var legacy_path := test_dir + "/old.json"
 var names_path := test_dir + "/identity.json"
 write_json(legacy_path, {"room": "records", "discovered": {"file": true, "terminal": true, "board": true}, "decisions": {"guard_trust": -1, "phone_secret": true}, "finale": "old demo ending"})
 write_json(names_path, {"player": "زائر قديم", "names": ["مدير", "حارس قديم"]})
 check(migrated.restore(legacy_path, names_path), "Legacy progress and names migrate together")
 check(not migrated.evidence.has("file"), "Legacy inspection bug does not grant locked dossier")
 check(migrated.character(1) == "حارس قديم" and migrated.decisions["phone_secret"], "Migration retains names and choices")
 check(migrated.finale.is_empty() and not migrated.report_consent, "Migration allows replay and never assumes report consent")
 check(FileAccess.file_exists(legacy_path), "Original legacy save is retained")
 var bad = fresh()
 var invalid: Dictionary = bad.snapshot()
 invalid["evidence"] = "invalid shape"
 check(bad._normalize(invalid).is_empty(), "Wrong JSON field types rejected safely")
 invalid = bad.snapshot()
 invalid["room"] = "removed_room"
 check(bad._normalize(invalid)["room"] == "lobby", "Removed rooms fall back to lobby")
 bad.store = Store.new(test_dir + "/missing-directory/save.json")
 check(not bad.persist() and not bad.notice.is_empty(), "Write failures are visible")
 for node in [campaign, recovered, future, migrated, bad]:
  node.free()

func _scene_cases() -> void:
 var global_state = root.get_node("GameState")
 var original: Dictionary = global_state.snapshot()
 var original_store = global_state.store
 global_state.store = Store.new(test_dir + "/ui.json")
 global_state.begin("اسم الاختبار", ["مدير", "اسم الحارس"], false)
 var scene = load("res://scenes/exploration.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene._interact("board")
 check(not global_state.evidence.has("board"), "Opening item panel does not acquire evidence")
 check(scene.action_panel.visible and scene.modal_layer.visible, "Dialogue blocks background input")
 var original_target: Vector2 = scene.target
 scene._approach("guard", 0)
 check(scene.target == original_target, "Cannot walk through a modal")
 scene._close_action()
 scene._interact("guard")
 check(scene.action_text.text.contains("اسم الحارس"), "Customized guard name appears in exploration")
 scene._close_action()
 scene._journal()
 await process_frame
 check(scene.journal_panel.visible and scene.journal_col.get_child_count() > 1, "Notebook rebuilds and opens without runtime errors")
 scene.queue_free()
 await process_frame
 var menu = load("res://scenes/main.tscn").instantiate()
 root.add_child(menu)
 menu._setup()
 await process_frame
 check(menu.names_input.size() == 6, "Unified menu configures six characters")
 menu._privacy()
 await process_frame
 menu.queue_free()
 await process_frame
 global_state._apply(original)
 global_state.store = original_store
