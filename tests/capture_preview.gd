extends SceneTree
# Optional visual QA, run with a rendering driver; never writes to real campaign saves.
var output := "res://.preview"

func _initialize() -> void:
 call_deferred("_capture")

func _capture() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 var state = root.get_node("GameState")
 state.store = preload("res://scripts/save_store.gd").new(output + "/preview-save.json")
 state.begin("الزائر", state.world["names"], false, "chapter_one")
 root.size = Vector2i(540, 960)
 var menu = load("res://scenes/main.tscn").instantiate()
 root.add_child(menu)
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output + "/menu.png")
 menu._setup()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output + "/setup.png")
 menu.queue_free()
 await process_frame
 var scene = load("res://scenes/chapter_one.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene._close_action()
 scene._interact("guard")
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output + "/dialogue.png")
 scene._close_action()
 state.acquire("notice")
 scene._journal()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output + "/journal.png")
 scene.journal_panel.hide()
 scene.modal_layer.hide()
 state.choose("guard_trust", 1)
 state.acquire("visitor_log")
 scene._change_room("lift")
 scene._interact("panel")
 scene._take_action("panel", {"action":"keypad"})
 scene._digit("2")
 scene._digit("3")
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output + "/code.png")
 scene._close_action()
 state.chapter_event("code", "2317")
 scene._change_room("hall")
 scene._change_room("apartment")
 state.choose("phone_secret", false)
 state.acquire("receipt")
 state.infer("arrival_gap", ["receipt","visitor_log"])
 state.chapter_event("resolve", "private")
 scene._show_end()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output + "/ending.png")
 scene.queue_free()
 await process_frame
 await create_timer(.1).timeout
 print("Visual QA saved in ", ProjectSettings.globalize_path(output))
 quit()
