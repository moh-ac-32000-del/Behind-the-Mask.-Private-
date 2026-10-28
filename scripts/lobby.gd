extends Control
# Interactive illustrated lobby prototype. No external assets or network.
# The scene is drawn in normalized coordinates and scales to mobile viewports.
var detail: Label
var status: Label
var visited: Dictionary = {}
var scene_font: Font
var actor_position := Vector2(0.52, 0.77)
var actor_destination := Vector2(0.52, 0.77)
var pending_inspection := ""
var flags := {"guard": false, "board": false, "lift": false}
var choices := {}
var dialogue: PanelContainer
var dialogue_text: Label
var dialogue_actions: VBoxContainer
var notebook_panel: PanelContainer
var notebook_text: Label
var story_finished := false
const LOBBY_SAVE := "user://lobby_progress.json"
const WALK_SPEED := 0.32
const DESTINATIONS := {"guard": Vector2(0.31, 0.72), "board": Vector2(0.71, 0.71), "lift": Vector2(0.52, 0.69)}

func _process(delta: float) -> void:
    if actor_position.distance_to(actor_destination) < 0.003:
        return
    var step := WALK_SPEED * delta
    actor_position = actor_position.move_toward(actor_destination, step)
    queue_redraw()
    if actor_position.distance_to(actor_destination) < 0.003 and not pending_inspection.is_empty():
        var arrived := pending_inspection
        pending_inspection = ""
        _show_inspection(arrived)

var responses := {"guard": "الحارس ينظر إلى دفتر الزوار ثم يغلقه بسرعة. لا يقول لماذا.", "board": "هناك إعلان ممزق. يظهر الرقم 17 وتاريخ مُسح بالحبر.", "lift": "المصعد متوقف في طابق غير مذكور على اللوحة."}

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        _inspect_at(event.position)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _inspect_at(event.position)

func _inspect_at(pos: Vector2) -> void:
    var x := pos.x / maxf(size.x, 1.0)
    var y := pos.y / maxf(size.y, 1.0)
    if y >= 0.69 and y <= 0.81 and x >= 0.07 and x <= 0.93:
        pending_inspection = ""
        actor_destination = Vector2(clampf(x, 0.08, 0.92), clampf(y, 0.69, 0.80))
        status.text = "تتحرك الشخصية إلى الموضع المحدد."
    elif y >= 0.42 and y <= 0.67 and x <= 0.34:
        _inspect("guard")
    elif y >= 0.32 and y <= 0.54 and x >= 0.70:
        _inspect("board")
    elif y >= 0.26 and y <= 0.65 and x >= 0.34 and x <= 0.67:
        _inspect("lift")

func _inspect(key: String) -> void:
    pending_inspection = key
    actor_destination = DESTINATIONS[key] as Vector2
    status.text = "الشخصية تتحرك باتجاه العنصر..."
    detail.text = "انتظر الوصول."

func _show_inspection(key: String) -> void:
    visited[key] = true
    flags[key] = true
    detail.text = responses[key]
    status.text = "تم استكشاف %d من 3 عناصر" % visited.size()
    _open_dialogue(key)
    _save_lobby()

func _ready() -> void:
    var font_path := "res://assets/fonts/NotoSansArabic-Regular.ttf"
    if ResourceLoader.exists(font_path):
        scene_font = load(font_path) as Font
        theme = Theme.new()
        theme.default_font = scene_font
    _build_ui()
    _build_touch_targets()
    _build_story_panels()
    _load_lobby()
    resized.connect(queue_redraw)
    queue_redraw()

func _draw() -> void:
    var w := size.x
    var h := size.y
    draw_rect(Rect2(Vector2.ZERO, size), Color("#0b1019"))
    draw_rect(Rect2(0, h * 0.10, w, h * 0.63), Color("#192332"))
    # Walls and central perspective
    draw_colored_polygon(PackedVector2Array([Vector2(0,h*.72),Vector2(w*.27,h*.53),Vector2(w*.73,h*.53),Vector2(w,h*.72)]), Color("#303843"))
    draw_colored_polygon(PackedVector2Array([Vector2(0,h*.72),Vector2(w,h*.72),Vector2(w,h*.82),Vector2(0,h*.82)]), Color("#252b35"))
    # Ceiling lamp and illumination
    draw_circle(Vector2(w*.5,h*.14), w*.065, Color("#c2a477",.13))
    draw_circle(Vector2(w*.5,h*.14), w*.027, Color("#e6c79c",.65))
    # Door and frame
    draw_rect(Rect2(w*.35,h*.27,w*.3,h*.34),Color("#0b0f17"))
    draw_rect(Rect2(w*.375,h*.29,w*.25,h*.32),Color("#384652"))
    draw_rect(Rect2(w*.39,h*.31,w*.22,h*.28),Color("#172430"))
    draw_line(Vector2(w*.5,h*.31),Vector2(w*.5,h*.59),Color("#8b8b82"),2)
    # Reception desk
    draw_colored_polygon(PackedVector2Array([Vector2(w*.03,h*.56),Vector2(w*.31,h*.56),Vector2(w*.38,h*.66),Vector2(0,h*.66)]),Color("#55473f"))
    draw_rect(Rect2(w*.01,h*.65,w*.35,h*.11),Color("#302a2a"))
    # Guard silhouette
    draw_circle(Vector2(w*.18,h*.48),w*.037,Color("#121922"))
    draw_rect(Rect2(w*.135,h*.51,w*.09,h*.1),Color("#101720"))
    # Noticeboard and documents
    draw_rect(Rect2(w*.72,h*.34,w*.24,h*.18),Color("#5d5447"))
    draw_rect(Rect2(w*.74,h*.36,w*.2,h*.14),Color("#9d998c"))
    for i in range(3):
        draw_line(Vector2(w*.755,h*(.39+i*.035)),Vector2(w*.91,h*(.39+i*.035)),Color("#555b61"),2)
    # Player avatar: simple top-down figure for touch-to-walk testing.
    var p := Vector2(actor_position.x * w, actor_position.y * h)
    draw_ellipse_placeholder(p, w)
    # Wet reflection
    draw_line(Vector2(w*.36,h*.73),Vector2(w*.64,h*.73),Color("#a2a5ad",.22),3)

func draw_ellipse_placeholder(p: Vector2, w: float) -> void:
    draw_circle(p + Vector2(0, 7), w * 0.038, Color("#05080d", 0.55))
    draw_rect(Rect2(p.x - w * 0.025, p.y - w * 0.07, w * 0.05, w * 0.065), Color("#627788"))
    draw_circle(p + Vector2(0, -w * 0.065), w * 0.022, Color("#c7ab91"))

func _build_touch_targets() -> void:
    # Real Control buttons receive touch events reliably in mobile browsers.
    # Drawn scenery itself is not a GUI input target.
    _touch_target("guard", Vector2(0.08, 0.41), Vector2(0.30, 0.67))
    _touch_target("lift", Vector2(0.34, 0.25), Vector2(0.67, 0.65))
    _touch_target("board", Vector2(0.70, 0.32), Vector2(0.98, 0.55))

func _touch_target(key: String, start: Vector2, finish: Vector2) -> void:
    var target := Button.new()
    target.name = "Touch_" + key
    target.flat = true
    target.focus_mode = Control.FOCUS_NONE
    target.text = ""
    target.anchor_left = start.x
    target.anchor_top = start.y
    target.anchor_right = finish.x
    target.anchor_bottom = finish.y
    target.mouse_filter = Control.MOUSE_FILTER_STOP
    target.pressed.connect(func(): _inspect(key))
    add_child(target)

func _build_ui() -> void:
    var overlay := VBoxContainer.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_theme_constant_override("separation", 12)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(overlay)
    var top := PanelContainer.new()
    overlay.add_child(top)
    var top_label := Label.new()
    top_label.text = "المبنى رقم 17 - فصل الاستقبال"
    top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    top_label.add_theme_font_size_override("font_size",22)
    top.add_child(top_label)
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var gap := Control.new()
    gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
    gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(gap)
    var panel := PanelContainer.new()
    overlay.add_child(panel)
    var controls := VBoxContainer.new()
    controls.add_theme_constant_override("separation", 8)
    panel.add_child(controls)
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
    status = Label.new()
    status.text = "المس أحد العناصر لتتحرك الشخصية نحوه ثم تفحصه."
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    controls.add_child(status)
    detail = Label.new()
    detail.text = "المس العناصر التالية لاستكشاف المشهد."
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    controls.add_child(detail)
    _add_hotspot(controls, "التحدث مع الحارس", "guard", "")
    _add_hotspot(controls, "فحص لوحة الإعلانات", "board", "")
    _add_hotspot(controls, "فحص المصعد", "lift", "")
    var journal := Button.new()
    journal.text = "دفتر الأدلة والقرارات"
    journal.custom_minimum_size.y = 48
    journal.pressed.connect(_show_notebook)
    controls.add_child(journal)
    var back := Button.new()
    back.text = "العودة إلى القائمة"
    back.custom_minimum_size.y = 48
    back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
    controls.add_child(back)

func _add_hotspot(parent: VBoxContainer, caption: String, key: String, response: String) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size.y = 52
    button.pressed.connect(func(): _inspect(key))
    parent.add_child(button)

func _build_story_panels() -> void:
    dialogue = PanelContainer.new()
    dialogue.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    dialogue.anchor_left = 0.06
    dialogue.anchor_right = 0.94
    dialogue.anchor_top = 0.22
    dialogue.anchor_bottom = 0.62
    dialogue.offset_left = 0
    dialogue.offset_right = 0
    dialogue.offset_top = 0
    dialogue.offset_bottom = 0
    dialogue.visible = false
    dialogue.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dialogue)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    dialogue.add_child(column)
    dialogue_text = Label.new()
    dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    dialogue_text.add_theme_font_size_override("font_size", 21)
    column.add_child(dialogue_text)
    dialogue_actions = VBoxContainer.new()
    column.add_child(dialogue_actions)
    notebook_panel = PanelContainer.new()
    notebook_panel.anchor_left = 0.06
    notebook_panel.anchor_right = 0.94
    notebook_panel.anchor_top = 0.22
    notebook_panel.anchor_bottom = 0.62
    notebook_panel.visible = false
    add_child(notebook_panel)
    var notebook_column := VBoxContainer.new()
    notebook_panel.add_child(notebook_column)
    notebook_text = Label.new()
    notebook_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notebook_column.add_child(notebook_text)
    var close := Button.new()
    close.text = "إغلاق الدفتر"
    close.pressed.connect(func(): notebook_panel.hide())
    notebook_column.add_child(close)

func _open_dialogue(key: String) -> void:
    dialogue.show()
    for child in dialogue_actions.get_children():
        child.queue_free()
    match key:
        "guard":
            dialogue_text.text = "الحارس: تأخرت الليلة. لم أتوقع وصول ساكن جديد بعد منتصف الليل. هل تريد تسجيل اسمك؟"
            _dialogue_choice("أعطه اسمك الحقيقي", "guard_identity", "real", "يسجل الحارس الاسم ثم يخفي صفحة سابقة من الدفتر.")
            _dialogue_choice("استخدم اسمًا مستعارًا", "guard_identity", "alias", "يتردد الحارس، لكنه يقبل الاسم المستعار.")
        "board":
            dialogue_text.text = "تحت إعلان الصيانة ورقة قديمة. الرقم 17 مكتوب بجانب كلمة «مرآة». هل تحتفظ بصورة منها؟"
            _dialogue_choice("احتفظ بنسخة من الإعلان", "notice", "copied", "أضفت قصاصة الإعلان إلى دفتر الأدلة.")
            _dialogue_choice("أعد الورقة إلى مكانها", "notice", "left", "تركت الورقة كما كانت. قد تعود إليها لاحقًا.")
        "lift":
            if not flags["guard"] or not flags["board"]:
                dialogue_text.text = "المصعد لا يستجيب. ربما يجدر بك سؤال الحارس وفحص لوحة الإعلانات أولًا."
                _dialogue_close_button()
            else:
                dialogue_text.text = "أضاء زر الطابق السابع دون أن تلمسه. تسمع صوتًا يقول: «الاختبار بدأ». ماذا تفعل؟"
                _dialogue_choice("اصعد إلى الطابق السابع", "ending", "up", "انغلق باب المصعد. في الداخل انعكاسك يتأخر عن حركتك. نهاية فصل الاستقبال.")
                _dialogue_choice("ابتعد واطلب تفسيرًا", "ending", "wait", "ابتعدت عن المصعد. انطفأت الأضواء وظهر اسمك على شاشة الطابق. نهاية فصل الاستقبال.")

func _dialogue_choice(caption: String, key: String, value: String, result: String) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size.y = 48
    button.pressed.connect(func():
        choices[key] = value
        if key == "ending":
            story_finished = true
        dialogue_text.text = result
        for child in dialogue_actions.get_children():
            child.queue_free()
        _dialogue_close_button()
        _save_lobby()
    )
    dialogue_actions.add_child(button)

func _dialogue_close_button() -> void:
    var close := Button.new()
    close.text = "متابعة الاستكشاف"
    close.custom_minimum_size.y = 48
    close.pressed.connect(func(): dialogue.hide())
    dialogue_actions.add_child(close)

func _show_notebook() -> void:
    dialogue.hide()
    var lines := ["دفتر الأدلة", "العناصر المكتشفة: %d من 3" % visited.size()]
    if flags["board"] and choices.get("notice", "") == "copied":
        lines.append("دليل: إعلان قديم يذكر مشروع المرآة.")
    if flags["guard"]:
        lines.append("ملاحظة: الحارس يخفي صفحة من دفتر الزوار.")
    if flags["lift"]:
        lines.append("ملاحظة: المصعد يتوقف عند طابق غامض.")
    if not choices.is_empty():
        lines.append("قراراتك محفوظة محليًا: %d" % choices.size())
    if story_finished:
        lines.append("اكتمل فصل الاستقبال.")
    notebook_text.text = "\n".join(PackedStringArray(lines))
    notebook_panel.show()

func _save_lobby() -> void:
    var file := FileAccess.open(LOBBY_SAVE, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({"visited": visited, "flags": flags, "choices": choices, "finished": story_finished}))

func _load_lobby() -> void:
    if not FileAccess.file_exists(LOBBY_SAVE):
        return
    var file := FileAccess.open(LOBBY_SAVE, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return
    visited = parsed.get("visited", {})
    flags = parsed.get("flags", flags)
    choices = parsed.get("choices", {})
    story_finished = bool(parsed.get("finished", false))
    status.text = "استُعيد التقدم: %d عناصر مكتشفة" % visited.size()
