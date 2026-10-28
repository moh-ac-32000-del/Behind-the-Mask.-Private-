extends Control
# Interactive illustrated lobby prototype. No external assets or network.
# The scene is drawn in normalized coordinates and scales to mobile viewports.
var detail: Label
var status: Label
var visited: Dictionary = {}
var scene_font: Font
var responses := {"guard": "الحارس ينظر إلى دفتر الزوار ثم يغلقه بسرعة. لا يقول لماذا.", "board": "هناك إعلان ممزق. يظهر الرقم 17 وتاريخ مُسح بالحبر.", "lift": "المصعد متوقف في طابق غير مذكور على اللوحة."}

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        _inspect_at(event.position)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _inspect_at(event.position)

func _inspect_at(pos: Vector2) -> void:
    var x := pos.x / maxf(size.x, 1.0)
    var y := pos.y / maxf(size.y, 1.0)
    if y >= 0.42 and y <= 0.67 and x <= 0.34:
        _inspect("guard")
    elif y >= 0.32 and y <= 0.54 and x >= 0.70:
        _inspect("board")
    elif y >= 0.26 and y <= 0.65 and x >= 0.34 and x <= 0.67:
        _inspect("lift")

func _inspect(key: String) -> void:
    visited[key] = true
    detail.text = responses[key]
    status.text = "مواضع تم فحصها: %d من 3" % visited.size()

func _ready() -> void:
    var font_path := "res://assets/fonts/NotoSansArabic-Regular.ttf"
    if ResourceLoader.exists(font_path):
        scene_font = load(font_path) as Font
        theme = Theme.new()
        theme.default_font = scene_font
    _build_ui()
    _build_touch_targets()
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
    # Wet reflection
    draw_line(Vector2(w*.36,h*.73),Vector2(w*.64,h*.73),Color("#a2a5ad",.22),3)

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
    top_label.text = "المبنى رقم 17 - بهو الاستقبال | TOUCH V3"
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
    status.text = "المطر بالخارج. المس الحارس أو المصعد أو اللوحة داخل المشهد."
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    controls.add_child(status)
    detail = Label.new()
    detail.text = "المس العناصر التالية لاستكشاف المشهد."
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    controls.add_child(detail)
    _add_hotspot(controls, "الحارس عند المكتب", "guard", "الحارس ينظر إلى دفتر الزوار ثم يغلقه بسرعة. لا يقول لماذا.")
    _add_hotspot(controls, "لوحة الإعلانات", "board", "هناك إعلان ممزق. يظهر الرقم 17 وتاريخ مُسح بالحبر.")
    _add_hotspot(controls, "باب المصعد", "lift", "المصعد متوقف في طابق غير مذكور على اللوحة.")
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
