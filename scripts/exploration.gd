extends Control
# Data-driven mobile exploration: five connected locations, persistent evidence and choices.
const SAVE := "user://exploration_v1.json"
const ROOMS := {
 "lobby": {"title":"بهو الاستقبال", "color":"#273447", "exits":{"lift":"المصعد"}, "objects":{"guard":"الحارس", "board":"لوحة الإعلانات", "lift":"باب المصعد"}},
 "lift": {"title":"المصعد", "color":"#343b45", "exits":{"lobby":"العودة إلى الاستقبال", "hall":"الطابق السابع"}, "objects":{"panel":"لوحة الطوابق", "mirror":"المرآة"}},
 "hall": {"title":"ممر الطابق السابع", "color":"#29353a", "exits":{"lift":"المصعد", "apartment":"الشقة 703", "records":"غرفة السجلات"}, "objects":{"door":"باب مخدوش", "camera":"كاميرا المراقبة"}},
 "apartment": {"title":"الشقة 703", "color":"#40383d", "exits":{"hall":"العودة إلى الممر"}, "objects":{"phone":"هاتف مجهول", "letter":"رسالة مطوية", "window":"النافذة"}},
 "records": {"title":"غرفة السجلات", "color":"#34342d", "exits":{"hall":"العودة إلى الممر"}, "objects":{"cabinet":"خزانة الملفات", "terminal":"الحاسوب", "file":"الملف 17"}}
}
const ITEMS := {
 "board":{"title":"قصاصة الإعلان", "text":"تاريخ ممحو، ورمز صغير: مرآة 17.", "choice":"نسخ الإعلان"},
 "mirror":{"title":"انعكاس متأخر", "text":"انعكاسك يتأخر لحظة واحدة. ربما خلل في الإضاءة.", "choice":"تسجيل الملاحظة"},
 "door":{"title":"خدش على الباب", "text":"الرقم 703 محفور فوق طبقة الطلاء.", "choice":"تصوير الخدش"},
 "camera":{"title":"كاميرا مراقبة", "text":"عدستها تتبعك ببطء، رغم انقطاع ضوء المؤشر.", "choice":"تسجيل موقع الكاميرا"},
 "phone":{"title":"هاتف مجهول", "text":"رسالة بلا مرسل: لا تثق بنسختك الأخرى.", "choice":"الاحتفاظ بالهاتف"},
 "letter":{"title":"رسالة مطوية", "text":"إذا وصلت إلى السجلات، لا تفتح الملف وحدك.", "choice":"حفظ الرسالة"},
 "window":{"title":"النافذة", "text":"في الزجاج ترى شخصًا خلفك، لكن الغرفة فارغة.", "choice":"تسجيل المشاهدة"},
 "cabinet":{"title":"خزانة الملفات", "text":"أوراق قديمة تصنف السكان بأرقام لا بأسماء.", "choice":"نسخ قائمة السكان"},
 "terminal":{"title":"الحاسوب", "text":"شاشة تعرض مشروع المرآة وحالة التجربة: نشطة.", "choice":"حفظ سجل التجربة"},
 "file":{"title":"الملف 17", "text":"يحمل الملف اسم الزائر وتاريخ وصول لم يحدث بعد.", "choice":"فتح الملف"},
 "panel":{"title":"لوحة الطوابق", "text":"زر الطابق السابع مضاء دون أن تضغطه.", "choice":"فحص اللوحة"},
 "guard":{"title":"الحارس", "text":"الحارس: لا أذكر أنني رأيتك من قبل. ثم يهمس: لا تعد إلى الطابق السابع.", "choice":"سؤاله عن المشروع"}
}
var room := "lobby"
var player := Vector2(0.5,0.72)
var target := Vector2(0.5,0.72)
var pending := ""
var discovered: Dictionary = {}
var decisions: Dictionary = {}
var scene_buttons: Array[Button] = []
var title_label: Label
var info_label: Label
var action_panel: PanelContainer
var action_text: Label
var action_buttons: VBoxContainer
var journal_panel: PanelContainer
var journal_text: Label
var exit_box: VBoxContainer

func _ready() -> void:
 var font_path := "res://assets/fonts/NotoSansArabic-Regular.ttf"
 if ResourceLoader.exists(font_path):
  theme = Theme.new()
  theme.default_font = load(font_path)
 _load()
 _ui()
 _render_room()
 set_process(true)

func _process(delta: float) -> void:
 if player.distance_to(target) > 0.002:
  player = player.move_toward(target, 0.33 * delta)
  queue_redraw()
 elif not pending.is_empty():
  var key := pending
  pending = ""
  _interact(key)

func _input(event: InputEvent) -> void:
 var position := Vector2(-1,-1)
 if event is InputEventScreenTouch and event.pressed:
  position = event.position
 elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  position = event.position
 if position.x < 0:
  return
 var normalized := Vector2(position.x/maxf(size.x,1),position.y/maxf(size.y,1))
 if normalized.y >= 0.57 and normalized.y <= 0.78:
  pending = ""
  target = Vector2(clampf(normalized.x,0.12,0.88),clampf(normalized.y,0.60,0.76))

func _draw() -> void:
 var w := size.x
 var h := size.y
 draw_rect(Rect2(Vector2.ZERO,size),Color("#0a1018"))
 var shade := Color(str(ROOMS[room]["color"]))
 draw_rect(Rect2(w*.04,h*.12,w*.92,h*.58),shade)
 draw_colored_polygon(PackedVector2Array([Vector2(w*.04,h*.7),Vector2(w*.32,h*.50),Vector2(w*.68,h*.50),Vector2(w*.96,h*.7)]),shade.lightened(.15))
 draw_colored_polygon(PackedVector2Array([Vector2(w*.04,h*.7),Vector2(w*.96,h*.7),Vector2(w*.96,h*.79),Vector2(w*.04,h*.79)]),shade.darkened(.22))
 draw_rect(Rect2(w*.37,h*.24,w*.26,h*.30),Color("#101820"))
 draw_rect(Rect2(w*.40,h*.27,w*.20,h*.27),shade.lightened(.26))
 draw_line(Vector2(w*.5,h*.27),Vector2(w*.5,h*.54),Color("#a8a5a0"),2)
 draw_circle(Vector2(w*.5,h*.18),w*.03,Color("#dfc7a0",.7))
 for i in range(3):
  var px := w*(.17+.33*i)
  draw_rect(Rect2(px-w*.055,h*.39,w*.11,h*.11),Color("#8e806b"))
  draw_rect(Rect2(px-w*.045,h*.40,w*.09,h*.09),Color("#c6b9a0"))
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
 back.text = "القائمة الرئيسية"
 back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
 controls.add_child(back)
 action_panel = PanelContainer.new()
 action_panel.anchor_left = .06
 action_panel.anchor_right = .94
 action_panel.anchor_top = .23
 action_panel.anchor_bottom = .55
 action_panel.visible = false
 add_child(action_panel)
 var action_col := VBoxContainer.new()
 action_panel.add_child(action_col)
 action_text = Label.new()
 action_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 action_text.add_theme_font_size_override("font_size",21)
 action_col.add_child(action_text)
 action_buttons = VBoxContainer.new()
 action_col.add_child(action_buttons)
 journal_panel = PanelContainer.new()
 journal_panel.anchor_left = .06
 journal_panel.anchor_right = .94
 journal_panel.anchor_top = .20
 journal_panel.anchor_bottom = .57
 journal_panel.visible = false
 add_child(journal_panel)
 var journal_col := VBoxContainer.new()
 journal_panel.add_child(journal_col)
 journal_text = Label.new()
 journal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 journal_col.add_child(journal_text)
 var close := Button.new()
 close.text = "إغلاق"
 close.pressed.connect(func(): journal_panel.hide())
 journal_col.add_child(close)

func _render_room() -> void:
 title_label.text = "المبنى 17 - " + str(ROOMS[room]["title"])
 info_label.text = "المس العناصر لفحصها أو المس الأرض للتحرك."
 for button in scene_buttons:
  button.queue_free()
 scene_buttons.clear()
 for child in exit_box.get_children():
  child.queue_free()
 var objects: Dictionary = ROOMS[room]["objects"]
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
  scene_buttons.append(button)
 var exits: Dictionary = ROOMS[room]["exits"]
 for exit_key in exits:
  var next_room := str(exit_key)
  var exit_button := Button.new()
  exit_button.text = str(exits[exit_key])
  exit_button.custom_minimum_size.y = 44
  exit_button.pressed.connect(_change_room.bind(next_room))
  exit_box.add_child(exit_button)
 queue_redraw()

func _approach(key: String, index: int) -> void:
 action_panel.hide()
 journal_panel.hide()
 pending = key
 target = Vector2(.20 + .29*index,.66)
 info_label.text = "تتحرك نحو " + str(ROOMS[room]["objects"][key])

func _interact(key: String) -> void:
 if not ITEMS.has(key):
  return
 discovered[key] = true
 var item: Dictionary = ITEMS[key]
 action_text.text = str(item["title"]) + "\n" + str(item["text"])
 _clear_actions()
 _action_button(str(item["choice"]),func():
  decisions[key] = str(item["choice"])
  info_label.text = "تم تسجيل القرار في دفتر الأدلة."
  _save()
  action_panel.hide()
 )
 _action_button("إغلاق",func(): action_panel.hide())
 action_panel.show()
 _save()

func _clear_actions() -> void:
 for child in action_buttons.get_children():
  child.queue_free()

func _action_button(caption: String, callback: Callable) -> void:
 var b := Button.new()
 b.text = caption
 b.custom_minimum_size.y = 48
 b.pressed.connect(callback)
 action_buttons.add_child(b)

func _change_room(next_room: String) -> void:
 if not ROOMS.has(next_room):
  return
 room = next_room
 pending = ""
 player = Vector2(.5,.73)
 target = player
 action_panel.hide()
 journal_panel.hide()
 _render_room()
 _save()

func _journal() -> void:
 action_panel.hide()
 var lines: Array[String] = ["الأدلة: %d من %d" % [discovered.size(),ITEMS.size()]]
 for key in discovered:
  if ITEMS.has(key):
   lines.append("• " + str(ITEMS[key]["title"]))
 lines.append("القرارات المحفوظة: %d" % decisions.size())
 if discovered.has("file") and discovered.has("terminal"):
  lines.append("اكتشاف: بيانات الملف 17 مرتبطة بمشروع المرآة.")
 journal_text.text = "\n".join(lines)
 journal_panel.show()

func _save() -> void:
 var file := FileAccess.open(SAVE,FileAccess.WRITE)
 if file != null:
  file.store_string(JSON.stringify({"room":room,"discovered":discovered,"decisions":decisions}))

func _load() -> void:
 if not FileAccess.file_exists(SAVE):
  return
 var file := FileAccess.open(SAVE,FileAccess.READ)
 if file == null:
  return
 var parsed: Variant = JSON.parse_string(file.get_as_text())
 if parsed is Dictionary:
  room = str(parsed.get("room","lobby"))
  if not ROOMS.has(room):
   room = "lobby"
  discovered = parsed.get("discovered",{})
  decisions = parsed.get("decisions",{})
