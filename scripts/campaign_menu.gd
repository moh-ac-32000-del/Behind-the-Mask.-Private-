extends Control
var content: VBoxContainer
var names_input: Array[LineEdit] = []

func _ready() -> void:
 get_tree().quit_on_go_back = false
 preload("res://scripts/ui_theme.gd").apply(self)
 _menu()

func _layout(title: String) -> void:
 for child in get_children():
  remove_child(child)
  child.queue_free()
 var margin := MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left", "right", "top", "bottom"]:
  margin.add_theme_constant_override("margin_" + side, 24)
 add_child(margin)
 var scroll := ScrollContainer.new()
 margin.add_child(scroll)
 content = VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation", 14)
 scroll.add_child(content)
 _label(title, 28)

func _label(value: String, font_size: int = 20) -> void:
 var item := Label.new()
 item.text = value
 item.text_direction = Control.TEXT_DIRECTION_RTL
 item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 item.add_theme_font_size_override("font_size", font_size)
 content.add_child(item)

func _button(caption: String, callback: Callable) -> void:
 var button := Button.new()
 button.text = caption
 button.custom_minimum_size.y = 54
 button.pressed.connect(callback)
 content.add_child(button)

func _menu() -> void:
 _layout("ما وراء القناع")
 _label("المبنى رقم 17 — فصل الوصول", 19)
 _label("تحرّك بلمس الأرض، واقترب من العناصر لفحصها. وثّق الأدلة واربطها لتكشف ما يخفيه المبنى.", 18)
 if not GameState.notice.is_empty():
  _label(GameState.notice, 17)
 if GameState.has_campaign:
  _button("متابعة الفصل الأول" if GameState.mode == "chapter_one" else "متابعة نموذج التحقيق المستورد", _play)
  _label("الموقع: " + str(GameState.active_data()["rooms"][GameState.room]["title"]), 16)
 _button("بدء لعبة جديدة", _new_game)
 _button("إعدادات الصوت", _sound_settings)
 if GameState.has_campaign:
  _button("خصوصية سجل القرارات", _privacy)

func _new_game() -> void:
 if not GameState.has_campaign and not GameState.save_blocked:
  _setup()
  return
 _layout("بدء جولة جديدة")
 _label("ستستبدل الجولة الحالية وتبدأ التحقيق من البهو. لن يبدأ الاستبدال حتى تضغط «الدخول إلى المبنى».")
 _button("إعداد الجولة الجديدة", _setup)
 _button("العودة", _menu)

func _setup() -> void:
 _layout("أسماء الشخصيات")
 _label("الأسماء اختيارية وتبقى على جهازك. اختيار الاسم لا يحدد أخلاق الشخصية أو دورها.", 17)
 _label("اسمك أو اسم مستعار", 17)
 var player_field := LineEdit.new()
 player_field.max_length = 40
 player_field.custom_minimum_size.y = 48
 player_field.placeholder_text = "الزائر"
 content.add_child(player_field)
 names_input.clear()
 for i in range(GameState.world["roles"].size()):
  _label(str(GameState.world["roles"][i]), 16)
  var field := LineEdit.new()
  field.max_length = 40
  field.custom_minimum_size.y = 48
  field.text = str(GameState.world["names"][i])
  content.add_child(field)
  names_input.append(field)
 _label("يُحفظ التقدم والأسماء والقرارات الضرورية للقصة تلقائيًا على الجهاز. لا تُرسل إلى خادم.", 16)
 var consent := CheckBox.new()
 consent.text = "سجل إضافي لتقرير سلوكي وصفي (اختياري)"
 content.add_child(consent)
 _label("التقرير نفسه لم يُطوَّر بعد. يمكنك إيقاف السجل الإضافي وحذفه من قائمة الخصوصية؛ وهو ليس تشخيصًا نفسيًا.", 16)
 _button("الدخول إلى المبنى", func():
  var assigned: Array = []
  for field in names_input:
   assigned.append(field.text)
  if GameState.begin(player_field.text, assigned, consent.button_pressed, "chapter_one"):
   _play()
  else:
   _menu()
 )
 _button("إلغاء", _menu)

func _privacy() -> void:
 _layout("خصوصية سجل القرارات")
 _label("حفظ التقدم ضروري لاستمرار القصة. السجل الإضافي للتقرير الوصفي اختياري، ولا يُرسل أي منهما إلى خادم.", 18)
 _label("السجل الإضافي: " + ("مفعّل" if GameState.report_consent else "متوقف"))
 _label("عدد أحداث السجل الإضافي: %d" % GameState.report_history.size(), 17)
 if GameState.report_consent:
  _button("إيقاف السجل الإضافي وحذف بياناته", func():
   GameState.set_report_consent(false)
   _privacy()
  )
 else:
  _button("الموافقة على التسجيل من الآن", func():
   GameState.set_report_consent(true)
   _privacy()
  )
 if not GameState.notice.is_empty():
  _label(GameState.notice, 17)
 _button("العودة", _menu)

func _sound_settings() -> void:
 _layout("إعدادات الصوت")
 var enabled := CheckBox.new()
 enabled.text = "تشغيل الأصوات المحيطية والخطوات"
 enabled.button_pressed = GameState.sound_enabled
 content.add_child(enabled)
 _label("مستوى الصوت", 18)
 var slider := HSlider.new()
 slider.min_value = 0
 slider.max_value = 1
 slider.step = .1
 slider.value = GameState.sound_volume
 slider.custom_minimum_size.y = 48
 content.add_child(slider)
 _button("تطبيق والعودة", func():
  GameState.set_sound(enabled.button_pressed, slider.value)
  _menu()
 )

func _play() -> void:
 var path := "res://scenes/chapter_one.tscn" if GameState.mode == "chapter_one" else "res://scenes/exploration.tscn"
 get_tree().change_scene_to_file(path)
