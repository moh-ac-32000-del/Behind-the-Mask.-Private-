extends SceneTree
# Optional visual QA, run with a rendering driver; never writes to real campaign saves.
var output := "res://.preview"

func _initialize() -> void:
 call_deferred("_capture")

func _capture() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 var state = root.get_node("GameState")
 state.store = preload("res://scripts/save_store.gd").new(output + "/preview-save.json")
 state.begin("الزائر", state.world["names"], false)
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
 var scene = load("res://scenes/exploration.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 scene._interact("guard")
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output + "/dialogue.png")
 scene._close_action()
 state.acquire("board")
 scene._journal()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output + "/journal.png")
 scene.queue_free()
 await process_frame
 print("Visual QA saved in ", ProjectSettings.globalize_path(output))
 quit()
