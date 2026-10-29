extends Control
# Rendering and touch input; story data and progress live in separate systems.
const World = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/investigation_rules.gd")
var world := World.load_world()
var player := Vector2(0.5,0.72)
var target := Vector2(0.5,0.72)
var pending := ""


var scene_buttons: Array[Button] = []
var title_label: Label
var info_label: Label
var action_panel: PanelContainer
var action_text: Label
var action_buttons: VBoxContainer
var journal_panel: PanelContainer
var journal_text: Label
var journal_col: VBoxContainer
var modal_layer: Control
var exit_box: VBoxContainer

func _ready() -> void:
 preload("res://scripts/ui_theme.gd").apply(self)
 _ui()
 _render_room()
 set_process(true)

func _process(delta: float) -> void:
 if action_panel.visible or journal_panel.visible:
  return
 if player.distance_to(target) > 0.002:
  player = player.move_toward(target, 0.33 * delta)
  queue_redraw()
 elif not pending.is_empty():
  var key := pending
  pending = ""
  _interact(key)

func _unhandled_input(event: InputEvent) -> void:
 var position := Vector2(-1,-1)
 if event is InputEventScreenTouch and event.pressed:
  position = event.position
 elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  position = event.position
 if position.x < 0 or action_panel.visible or journal_panel.visible:
  return
 var normalized := Vector2(position.x/maxf(size.x,1),position.y/maxf(size.y,1))
 if normalized.y >= 0.57 and normalized.y <= 0.78:
  pending = ""
  target = Vector2(clampf(normalized.x,0.12,0.88),clampf(normalized.y,0.60,0.76))

func _draw() -> void:
 var w := size.x
 var h := size.y
 draw_rect(Rect2(Vector2.ZERO,size),Color("#0a1018"))
 var shade := Color(str(world["rooms"][GameState.room]["color"]))
 draw_rect(Rect2(w*.04,h*.12,w*.92,h*.58),shade)
 draw_colored_polygon(PackedVector2Array([Vector2(w*.04,h*.7),Vector2(w*.32,h*.50),Vector2(w*.68,h*.50),Vector2(w*.96,h*.7)]),shade.lightened(.15))
 draw_colored_polygon(PackedVector2Array([Vector2(w*.04,h*.7),Vector2(w*.96,h*.7),Vector2(w*.96,h*.79),Vector2(w*.04,h*.79)]),shade.darkened(.22))
 draw_rect(Rect2(w*.37,h*.24,w*.26,h*.30),Color("#101820"))
 draw_rect(Rect2(w*.40,h*.27,w*.20,h*.27),shade.lightened(.26))
 draw_line(Vector2(w*.5,h*.27),Vector2(w*.5,h*.54),Color("#a8a5a0"),2)
 draw_circle(Vector2(w*.5,h*.18),w*.03,Color("#dfc7a0",.7))
 _draw_environment(w,h)
 for i in range(3):
  var px := w*(.17+.33*i)
  draw_rect(Rect2(px-w*.055,h*.39,w*.11,h*.11),Color("#8e806b"))
  draw_rect(Rect2(px-w*.045,h*.40,w*.09,h*.09),Color("#c6b9a0"))
 _draw_actor(w, h)

func _draw_actor(w: float, h: float) -> void:
 var p := Vector2(player.x*w,player.y*h)
 draw_circle(p+Vector2(0,12),w*.034,Color("#030609",.55))
 draw_rect(Rect2(p.x-w*.026,p.y-w*.075,w*.052,w*.075),Color("#78899a"))
 draw_circle(p+Vector2(0,-w*.07),w*.023,Color("#c9aa90"))

func _ui() -> void:
 var overlay := VBoxContainer.new()
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(overlay)
 title_label = Label.new()
 title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 title_label.add_theme_font_size_override("font_size",24)
 overlay.add_child(title_label)
 var gap := Control.new()
 gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
 gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
 overlay.add_child(gap)
 var panel := PanelContainer.new()
 overlay.add_child(panel)
 var controls := VBoxContainer.new()
 panel.add_child(controls)
 info_label = Label.new()
 info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 controls.add_child(info_label)
 var journal := Button.new()
 journal.text = "دفتر الأدلة"
 journal.custom_minimum_size.y = 46
 journal.pressed.connect(_journal)
 controls.add_child(journal)
 exit_box = VBoxContainer.new()
 controls.add_child(exit_box)
 var back := Button.new()
 back.text = "توقف مؤقت / القائمة"
 back.pressed.connect(_pause)
 controls.add_child(back)
 modal_layer = Control.new()
 modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
 modal_layer.hide()
 add_child(modal_layer)
 var scrim := ColorRect.new()
 scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scrim.color = Color(0, 0, 0, 0.65)
 scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
 modal_layer.add_child(scrim)
 action_panel = PanelContainer.new()
 action_panel.anchor_left = .06
 action_panel.anchor_right = .94
 action_panel.anchor_top = .12
 action_panel.anchor_bottom = .88
 action_panel.visible = false
 modal_layer.add_child(action_panel)
 var action_scroll := ScrollContainer.new()
 action_panel.add_child(action_scroll)
 var action_col := VBoxContainer.new()
 action_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 action_scroll.add_child(action_col)
 action_text = Label.new()
 action_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 action_text.add_theme_font_size_override("font_size",21)
 action_col.add_child(action_text)
 action_buttons = VBoxContainer.new()
 action_col.add_child(action_buttons)
 journal_panel = PanelContainer.new()
 journal_panel.anchor_left = .06
 journal_panel.anchor_right = .94
 journal_panel.anchor_top = .08
 journal_panel.anchor_bottom = .92
 journal_panel.visible = false
 modal_layer.add_child(journal_panel)
 var journal_scroll := ScrollContainer.new()
 journal_panel.add_child(journal_scroll)
 journal_col = VBoxContainer.new()
 journal_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 journal_scroll.add_child(journal_col)
 journal_text = Label.new()
 journal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 journal_col.add_child(journal_text)
 var close := Button.new()
 close.text = "إغلاق"
 close.pressed.connect(func(): journal_panel.hide(); modal_layer.hide())
 journal_col.add_child(close)

func _render_room() -> void:
 title_label.text = "المبنى 17 - " + str(world["rooms"][GameState.room]["title"])
 _update_stage()
 info_label.text += "\nالمس الأرض للمشي والعناصر للفحص. الفحص وحده لا يوثّق الدليل."
 for button in scene_buttons:
  remove_child(button)
  button.queue_free()
 scene_buttons.clear()
 for child in exit_box.get_children():
  child.get_parent().remove_child(child)
  child.queue_free()
 var objects: Dictionary = world["rooms"][GameState.room]["objects"]
 var keys := objects.keys()
 for i in range(keys.size()):
  var key: String = str(keys[i])
  var button := Button.new()
  button.flat = true
  button.text = str(objects[key])
  button.anchor_left = .07 + .32*i
  button.anchor_right = .32 + .32*i
  button.anchor_top = .35
  button.anchor_bottom = .56
  button.mouse_filter = Control.MOUSE_FILTER_STOP
  button.pressed.connect(_approach.bind(key,i))
  add_child(button)
  move_child(modal_layer, -1)
  scene_buttons.append(button)
 var exits: Dictionary = world["rooms"][GameState.room]["exits"]
 for exit_key in exits:
  var next_room := str(exit_key)
  var exit_button := Button.new()
  exit_button.text = str(exits[exit_key])
  exit_button.custom_minimum_size.y = 44
  exit_button.pressed.connect(_change_room.bind(next_room))
  exit_box.add_child(exit_button)
 queue_redraw()

func _pause() -> void:
 get_tree().change_scene_to_file("res://scenes/main.tscn")

func _approach(key: String, index: int) -> void:
 if action_panel.visible or journal_panel.visible:
  return
 action_panel.hide()
 modal_layer.hide()
 journal_panel.hide()
 pending = key
 target = Vector2(.20 + .29*index,.66)
 info_label.text = "تتحرك نحو " + str(world["rooms"][GameState.room]["objects"][key])

func _interact(key: String) -> void:
 if key == "lift":
  _change_room("lift")
  return
 if not world["items"].has(key):
  return
 var item: Dictionary = world["items"][key]
 action_text.text = str(item["title"]) + "\n" + str(item["text"])
 _clear_actions()
 if not GameState.finale.is_empty():
  action_text.text += "\nاكتمل التحقيق. يمكنك مراجعة الأدلة والنهاية في الدفتر."
  _action_button("إغلاق", _close_action)
  action_panel.show()
  modal_layer.show()
  return
 if key == "file" and not Rules.can_open_file(GameState.evidence):
  action_text.text += "\nالملف مقفل. وثّق سجل المشروع في الحاسوب أولًا."
  _action_button("إغلاق", _close_action)
  action_panel.show()
  modal_layer.show()
  return
 if key == "file":
  action_text.text += "\nالاسم داخل الملف: " + GameState.player_name + ". تاريخ الوصول لم يحدث بعد."
 if key == "guard":
  action_text.text = "الحارس " + GameState.character(1) + "\n" + str(item["text"])
  if not GameState.decisions.has("guard_trust"):
   _action_button("أطلب مساعدته وأثق به", func(): _guard_response(true))
   _action_button("أواجهه بشكوكي", func(): _guard_response(false))
  else:
   action_text.text += "\n" + _dialogue("guard")
 if key == "phone" and not GameState.decisions.has("phone_secret"):
  _action_button("أخفي الرسالة", func(): _phone_response(true))
  _action_button("أكشف الرسالة", func(): _phone_response(false))
 if key in ["terminal", "recorder"]:
  action_text.text += "\n" + _dialogue(key)
 if not GameState.evidence.has(key):
  _action_button(str(item["choice"]), func():
   if GameState.acquire(key):
    _update_stage()
    _interact(key)
   else:
    info_label.text = GameState.notice
  )
 else:
  action_text.text += "\nموثّق في دفتر التحقيق."
 if key == "recorder":
  if GameState.can_finish():
   _action_button("واجه الحقيقة", _ending_dialogue)
  else:
   action_text.text += "\nوثّق الأدلة الرئيسية الخمسة واربط الإعلان والحاسوب والملف في دفتر التحقيق."
 _action_button("إغلاق", _close_action)
 action_panel.show()
 modal_layer.show()

func _dialogue(key: String) -> String:
 for variant in world["dialogues"].get(key, []):
  var matches := true
  for decision in variant.get("when", {}):
   if GameState.decisions.get(decision) != variant["when"][decision]:
    matches = false
  if matches:
   return str(variant["text"])
 return ""

func _close_action() -> void:
 action_panel.hide()
 modal_layer.hide()
 if not GameState.notice.is_empty():
  info_label.text = GameState.notice
func _clear_actions() -> void:
 for child in action_buttons.get_children():
  child.get_parent().remove_child(child)
  child.queue_free()

func _action_button(caption: String, callback: Callable) -> void:
 var b := Button.new()
 b.text = caption
 b.custom_minimum_size.y = 48
 b.pressed.connect(callback)
 action_buttons.add_child(b)

func _change_room(next_room: String) -> void:
 if action_panel.visible or journal_panel.visible:
  return
 var message := GameState.enter(next_room)
 if not message.is_empty():
  info_label.text = message
  return
 pending = ""
 player = Vector2(.5,.73)
 target = player
 _render_room()
 if not GameState.notice.is_empty():
  info_label.text = GameState.notice
func _journal() -> void:
 pending = ""
 target = player
 action_panel.hide()
 modal_layer.hide()
 for child in journal_col.get_children():
  journal_col.remove_child(child)
  child.queue_free()
 var lines: Array[String] = ["دفتر التحقيق", "الأدلة الموثقة: %d من %d" % [GameState.evidence.size(), world["items"].size()]]
 for key in GameState.evidence:
  lines.append("• " + str(world["items"][key]["title"]) + "\n" + str(world["items"][key]["text"]))
 lines.append("التقدم: %d من 5 أدلة رئيسية — المرحلة %d من 3" % [GameState.clue_count(), GameState.stage()])
 lines.append("الشخصيات الرئيسية:")
 for i in range(world["roles"].size()):
  lines.append(str(world["roles"][i]) + ": " + GameState.character(i))
 lines.append("قرارات مهمة:")
 if GameState.decisions.has("guard_trust"):
  lines.append("طلبت مساعدة الحارس." if GameState.decisions["guard_trust"] > 0 else "واجهت الحارس بشكوكك.")
 if GameState.decisions.has("phone_secret"):
  lines.append("أبقيت الرسالة سرية." if GameState.decisions["phone_secret"] else "كشفت الرسالة.")
 if GameState.deductions.has("mirror_project"):
  lines.append("استنتاج: " + str(world["deductions"]["mirror_project"]["text"]))
 else:
  lines.append("سؤال مفتوح: ما العلاقة بين الإعلان وسجل الحاسوب والملف 17؟")
 if not GameState.finale.is_empty():
  lines.append("نهاية التحقيق:\n" + GameState.finale)
 journal_text = Label.new()
 journal_text.text = "\n\n".join(lines)
 journal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 journal_col.add_child(journal_text)
 var selected: Array = []
 if GameState.finale.is_empty() and not GameState.deductions.has("mirror_project"):
  for key in GameState.evidence:
   var check := CheckBox.new()
   check.text = str(world["items"][key]["title"])
   check.custom_minimum_size.y = 44
   check.toggled.connect(_select_clue.bind(str(key), selected))
   journal_col.add_child(check)
  var link := Button.new()
  link.text = "اربط الأدلة المحددة"
  link.custom_minimum_size.y = 48
  link.pressed.connect(func():
   if GameState.infer("mirror_project", selected):
    _journal()
   elif not GameState.notice.is_empty():
    journal_text.text += "\n" + GameState.notice
   else:
    journal_text.text += "\nلم يكتمل الاستنتاج. قارن الإعلان والحاسوب والملف، ويمكنك العودة لأي دليل."
  )
  journal_col.add_child(link)
 if not GameState.notice.is_empty():
  journal_text.text += "\n" + GameState.notice
  var retry := Button.new()
  retry.text = "إعادة محاولة الحفظ"
  retry.custom_minimum_size.y = 48
  retry.pressed.connect(func():
   GameState.persist()
   _journal()
  )
  journal_col.add_child(retry)
 var close := Button.new()
 close.text = "إغلاق الدفتر"
 close.custom_minimum_size.y = 48
 close.pressed.connect(func(): journal_panel.hide(); modal_layer.hide())
 journal_col.add_child(close)
 journal_panel.show()
 modal_layer.show()

func _select_clue(enabled: bool, key: String, selected: Array) -> void:
 if enabled:
  selected.append(key)
 else:
  selected.erase(key)

func _update_stage() -> void:
 info_label.text = "التحقيق: %d من 5 أدلة رئيسية. وثّق الأدلة واربطها في الدفتر." % GameState.clue_count()

func _ending_dialogue() -> void:
 if not GameState.can_finish():
  return
 action_text.text = "صوت التسجيل يقول: أنت لم تدخل المبنى للمرة الأولى. ماذا ستفعل بالحقيقة؟"
 _clear_actions()
 _action_button("أكشف المشروع للسكان", func(): _finish("كشف الحقيقة"))
 _action_button("أخفي الملف وأبحث عن النسخة الأخرى", func(): _finish("البحث عن النسخة"))
 _action_button("تراجع الآن", _close_action)

func _finish(result: String) -> void:
 if GameState.finish(result):
  action_text.text = "نهاية التحقيق التجريبي:\n" + GameState.finale + "\nلكن من الذي كان يراقب قراراتك؟"
 else:
  action_text.text = GameState.notice
 _clear_actions()
 _action_button("إغلاق", _close_action)
func _draw_environment(w: float, h: float) -> void:
 var accent := Color("#86939a")
 if GameState.room == "lobby":
  draw_rect(Rect2(w*.05,h*.55,w*.28,h*.12),Color("#56473e"))
  draw_circle(Vector2(w*.19,h*.48),w*.035,Color("#121922"))
 elif GameState.room == "lift":
  draw_rect(Rect2(w*.31,h*.25,w*.38,h*.35),accent)
  draw_line(Vector2(w*.50,h*.25),Vector2(w*.50,h*.60),Color("#d0d2d3"),3)
 elif GameState.room == "hall":
  draw_rect(Rect2(w*.07,h*.34,w*.22,h*.28),accent.darkened(.3))
  draw_rect(Rect2(w*.71,h*.34,w*.22,h*.28),accent.darkened(.2))
 elif GameState.room == "apartment":
  draw_rect(Rect2(w*.09,h*.33,w*.34,h*.19),Color("#536d7b"))
  draw_rect(Rect2(w*.58,h*.54,w*.30,h*.09),Color("#6a554a"))
 elif GameState.room == "records":
  for i in range(3):
   draw_rect(Rect2(w*(.08+i*.30),h*.30,w*.24,h*.30),Color("#656157"))
 elif GameState.room == "stairwell":
  for i in range(5):
   draw_rect(Rect2(w*(.10+i*.13),h*(.59-i*.05),w*.28,h*.045),accent.darkened(.2))
 elif GameState.room == "roof":
  for i in range(7):
   draw_rect(Rect2(w*(.05+i*.13),h*.46,w*.10,h*.17),Color("#14212c"))
  draw_line(Vector2(w*.69,h*.24),Vector2(w*.69,h*.54),accent,3)
 elif GameState.room == "maintenance":
  for i in range(4):
   draw_rect(Rect2(w*(.10+i*.20),h*.36,w*.14,h*.23),Color("#5d584f"))

func _guard_response(trust: bool) -> void:
 GameState.choose("guard_trust", 1 if trust else -1)
 action_text.text = _dialogue("guard")
 _clear_actions()
 _action_button("متابعة", _close_action)
 _update_stage()

func _phone_response(secret: bool) -> void:
 GameState.choose("phone_secret", secret)
 action_text.text = "تحتفظ بالرسالة. في نهايتها رمز لا يعرفه الآخرون." if secret else "تشارك الرسالة. يصلك رد: رمز باب الصيانة 1703. لقد رآك."
 _clear_actions()
 _action_button("متابعة", _close_action)
 _update_stage()
