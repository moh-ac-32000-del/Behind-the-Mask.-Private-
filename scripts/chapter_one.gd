extends "res://scripts/exploration.gd"
const Chapter = preload("res://scripts/chapter_rules.gd")
var walker := preload("res://scripts/walk_grid.gd").new()
var route := PackedVector2Array()
var walk_phase := 0.0
var facing := 1.0
var digits := ""
var digits_label: Label
var sound = preload("res://scripts/soundscape.gd").new()
var step_time := 0.0

func _ready() -> void:
 world = GameState.active_data().duplicate(true)
 for location in world["rooms"].values():
  for key in location["objects"]:
   location["objects"][key] = _text(str(location["objects"][key]))
 super._ready()
 add_child(sound)
 if GameState.chapter_flags.get("finished", false):
  _show_end()
 elif not GameState.chapter_flags.get("arrived", false):
  action_text.text = _text(world["intro"])
  _clear_actions()
  _action_button("الدخول إلى البهو", func():
   GameState.chapter_event("intro")
   _close_action()
  )
  _open_modal()

func _render_room() -> void:
 super._render_room()
 walker.configure(world["floor"][GameState.room]["area"])
 route.clear()
 title_label.text = "الفصل الأول — " + str(world["rooms"][GameState.room]["title"])

func _update_stage() -> void:
 info_label.text = "الهدف: " + Chapter.objective(GameState)

func _text(value: String) -> String:
 return value.format({"player":GameState.player_name, "guard":GameState.character(1), "neighbor":GameState.character(2)})

func _process(delta: float) -> void:
 if action_panel.visible or journal_panel.visible:
  return
 if not route.is_empty():
  target = route[0]
  var direction := target - player
  if absf(direction.x) > .001:
   facing = signf(direction.x)
  player = player.move_toward(target, .33 * delta)
  walk_phase += delta * 10
  step_time += delta
  if step_time >= .38:
   sound.step(GameState.room == "lift")
   step_time = 0
  if player.distance_to(target) < .002:
   route.remove_at(0)
  queue_redraw()
 elif not pending.is_empty():
  var key := pending
  pending = ""
  _interact(key)

func _unhandled_input(event: InputEvent) -> void:
 if action_panel.visible or journal_panel.visible:
  return
 var point := Vector2(-1,-1)
 if event is InputEventScreenTouch and event.pressed:
  point = event.position
 elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  point = event.position
 if point.x < 0:
  return
 var normalized := Vector2(point.x/maxf(size.x,1),point.y/maxf(size.y,1))
 if normalized.y >= .60 and normalized.y <= .78:
  pending = ""
  route = walker.path(player, normalized)

func _approach(key: String, index: int) -> void:
 if action_panel.visible or journal_panel.visible:
  return
 var destination: Array = world["floor"][GameState.room]["targets"][index]
 route = walker.path(player, Vector2(destination[0],destination[1]))
 pending = key
 info_label.text = "تقترب من " + str(world["rooms"][GameState.room]["objects"][key])

func _interact(key: String) -> void:
 if not world["items"].has(key):
  return
 sound.tap()
 if GameState.chapter_flags.get("finished", false):
  _show_end()
  return
 var item: Dictionary = world["items"][key]
 action_text.text = _text(str(item["title"]) + "\n\n" + str(item["text"]))
 var response := _dialogue(key)
 if not response.is_empty():
  action_text.text += "\n\n" + response
 if key == "panel" and GameState.chapter_flags.get("lift_ready", false):
  action_text.text += "\n\nاستعادت اللوحة الخدمة. يمكنك الصعود إلى الطابق السابع."
 _clear_actions()
 for option in item.get("choices", []):
  if Chapter.matches(GameState, option.get("when", {})):
   _action_button(str(option["label"]), _take_action.bind(key, option))
 if not GameState.evidence.has(key):
  _action_button(str(item["choice"]), func():
   if GameState.acquire(key):
    _interact(key)
    _update_stage()
   else:
    action_text.text += "\n" + GameState.notice
  )
 else:
  action_text.text += "\n\nموثّق في الدفتر."
 _action_button("عودة إلى المكان", _close_action)
 _open_modal()

func _take_action(key: String, option: Dictionary) -> void:
 sound.tap()
 var action := str(option["action"])
 match action:
  "keypad":
   digits = ""
   _keypad()
  "guard", "phone":
   var decision := "guard_trust" if action == "guard" else "phone_secret"
   var value: Variant = (1 if option["value"] else -1) if action == "guard" else option["value"]
   GameState.choose(decision, value)
   _interact(key)
   _update_stage()
  "neighbor", "resolve":
   var message := GameState.chapter_event(action, option.get("value"))
   if GameState.chapter_flags.get("finished", false):
    _show_end()
   else:
    _interact(key)
    if not message.is_empty():
     action_text.text += "\n" + message
    _update_stage()

func _dialogue(key: String) -> String:
 for variant in world["dialogues"].get(key, []):
  if Chapter.matches(GameState, variant.get("when", {})):
   return _text(str(variant["text"]))
 return ""

func _open_modal() -> void:
 route.clear()
 pending = ""
 action_panel.show()
 modal_layer.show()

func _keypad(message: String = "") -> void:
 action_text.text = "لوحة تشغيل المصعد\nأدخل أربع خانات من توقيت بطاقة التسجيل، دون النقطتين.\n" + message
 _clear_actions()
 digits_label = Label.new()
 digits_label.text_direction = Control.TEXT_DIRECTION_LTR
 digits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 digits_label.add_theme_font_size_override("font_size", 30)
 digits_label.text = digits + "_".repeat(4 - digits.length())
 action_buttons.add_child(digits_label)
 var grid := GridContainer.new()
 grid.columns = 3
 grid.layout_direction = Control.LAYOUT_DIRECTION_LTR
 action_buttons.add_child(grid)
 for value in ["1","2","3","4","5","6","7","8","9","حذف","0","مسح"]:
  var button := Button.new()
  button.text = value
  button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  button.custom_minimum_size = Vector2(95,48)
  button.pressed.connect(_digit.bind(value))
  grid.add_child(button)
 _action_button("تأكيد الرمز", func():
  var result := GameState.chapter_event("code", digits)
  if GameState.chapter_flags.get("lift_ready", false):
   _interact("panel")
   _update_stage()
  else:
   digits = ""
   _keypad(result)
 )
 _action_button("تلميح من الأوراق", func():
  _keypad("البطاقة تحمل 23:17. حذف النقطتين يعطي 2317. يمكنك توثيق الورقتين من البهو إن فاتتك إحداهما.")
 )
 _action_button("العودة", func(): _interact("panel"))
 _open_modal()

func _digit(value: String) -> void:
 if value == "حذف":
  digits = digits.left(maxi(0, digits.length() - 1))
 elif value == "مسح":
  digits = ""
 elif digits.length() < 4:
  digits += value
 digits_label.text = digits + "_".repeat(4 - digits.length())

func _journal() -> void:
 route.clear()
 pending = ""
 action_panel.hide()
 for child in journal_col.get_children():
  journal_col.remove_child(child)
  child.queue_free()
 var lines: Array[String] = ["دفتر الفصل الأول", "الهدف الحالي: " + Chapter.objective(GameState), "الأدلة الموثقة:"]
 for key in GameState.evidence:
  if world["items"].has(key):
   lines.append(_text(str(world["items"][key]["title"]) + "\n" + str(world["items"][key]["text"])))
 lines.append("شخصيات التقيتها:\nالحارس: " + GameState.character(1))
 if GameState.evidence.has("neighbor"):
  lines.append("الجار: " + GameState.character(2))
 if GameState.decisions.has("guard_trust"):
  lines.append("طلبت مساعدة الحارس." if GameState.decisions["guard_trust"] > 0 else "واجهت الحارس بشكوكك.")
 if GameState.decisions.has("phone_secret"):
  lines.append("الرسالة سرية." if GameState.decisions["phone_secret"] else "أرسلت الرسالة إلى الإدارة.")
 if GameState.deductions.has("arrival_gap"):
  lines.append("استنتاج:\n" + str(world["deductions"]["arrival_gap"]["text"]))
 else:
  lines.append("سؤال مفتوح: هل يتطابق توقيت التسجيل مع توقيت تسليم المفتاح؟ حدد الورقتين واربطهما.")
 journal_text = Label.new()
 journal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 journal_text.text = "\n\n".join(lines)
 journal_col.add_child(journal_text)
 if not GameState.deductions.has("arrival_gap"):
  var selected: Array = []
  for key in GameState.evidence:
   var choice := CheckBox.new()
   choice.text = str(world["items"][key]["title"])
   choice.custom_minimum_size.y = 48
   choice.toggled.connect(_select_clue.bind(str(key), selected))
   journal_col.add_child(choice)
  _journal_button("اربط الدليلين المحددين", func():
   if GameState.infer("arrival_gap", selected):
    _journal()
    _update_stage()
   else:
    journal_text.text += "\n\nقارن بطاقة التسجيل بإيصال تسليم المفتاح. المحاولات لا تحذف أدلة ولا تمنع التقدم."
  )
 if GameState.chapter_flags.get("finished", false):
  _journal_button("عرض نهاية الفصل", func():
   journal_panel.hide()
   _show_end()
  )
 if not GameState.notice.is_empty():
  journal_text.text += "\n" + GameState.notice
  _journal_button("إعادة محاولة الحفظ", func():
   GameState.persist()
   _journal()
  )
 _journal_button("إغلاق الدفتر", func():
  journal_panel.hide()
  modal_layer.hide()
  _update_stage()
 )
 journal_panel.show()
 modal_layer.show()

func _journal_button(caption: String, callback: Callable) -> void:
 var button := Button.new()
 button.text = caption
 button.custom_minimum_size.y = 48
 button.pressed.connect(callback)
 journal_col.add_child(button)

func _show_end() -> void:
 action_text.text = GameState.chapter_result
 if not GameState.notice.is_empty():
  action_text.text += "\n" + GameState.notice
 _clear_actions()
 _action_button("مراجعة دفتر التحقيق", _journal)
 _action_button("القائمة الرئيسية", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
 _open_modal()
 _update_stage()

func _pause() -> void:
 route.clear()
 pending = ""
 action_text.text = "توقف مؤقت\nالتقدم محفوظ عند توثيق الأدلة واتخاذ القرارات والانتقال."
 _clear_actions()
 _action_button("متابعة اللعب", _close_action)
 _action_button("إيقاف الصوت" if GameState.sound_enabled else "تشغيل الصوت", func():
  GameState.set_sound(not GameState.sound_enabled, GameState.sound_volume)
  sound.refresh()
  _pause()
 )
 _action_button("القائمة الرئيسية", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
 _open_modal()

func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
  _pause()

func _draw_actor(w: float, h: float) -> void:
 var depth := lerpf(.85,1.06,clampf((player.y-.61)/.16,0,1))
 var moving := not route.is_empty()
 var step := sin(walk_phase) * w * .012 if moving else 0.0
 var p := Vector2(player.x*w, player.y*h)
 draw_set_transform(p,0,Vector2(depth,depth))
 draw_circle(Vector2(0,8),w*.032,Color("#04080e",.55))
 draw_line(Vector2(-w*.014,-w*.018),Vector2(-w*.018+step,3),Color("#263747"),w*.016)
 draw_line(Vector2(w*.014,-w*.018),Vector2(w*.018-step,3),Color("#263747"),w*.016)
 draw_colored_polygon(PackedVector2Array([Vector2(-w*.025,-w*.071),Vector2(w*.025,-w*.071),Vector2(w*.021,-w*.018),Vector2(-w*.021,-w*.018)]),Color("#748b9b"))
 draw_circle(Vector2(facing*w*.004,-w*.086),w*.021,Color("#c9aa90"))
 draw_line(Vector2(-w*.027,-w*.061),Vector2(-w*.033,-w*.027-step*.3),Color("#536c80"),w*.012)
 draw_line(Vector2(w*.027,-w*.061),Vector2(w*.033,-w*.027+step*.3),Color("#536c80"),w*.012)
 draw_set_transform(Vector2.ZERO)
