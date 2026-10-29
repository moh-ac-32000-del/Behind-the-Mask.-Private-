extends RefCounted

static func apply(control: Control) -> void:
 var theme := Theme.new()
 var font_path := "res://assets/fonts/NotoSansArabic-Regular.ttf"
 if ResourceLoader.exists(font_path):
  theme.default_font = load(font_path)
 theme.default_font_size = 20
 var panel := StyleBoxFlat.new()
 panel.bg_color = Color("#101b28")
 panel.border_color = Color("#526377")
 panel.set_border_width_all(1)
 panel.set_content_margin_all(12)
 theme.set_stylebox("panel", "PanelContainer", panel)
 for state in ["normal", "hover", "pressed", "focus"]:
  var button := StyleBoxFlat.new()
  button.bg_color = Color("#1b2c3e") if state == "normal" else Color("#304a63")
  button.set_content_margin_all(10)
  button.set_corner_radius_all(4)
  theme.set_stylebox(state, "Button", button)
 theme.set_color("font_color", "Label", Color("#e4e9ef"))
 theme.set_color("font_color", "Button", Color("#e4e9ef"))
 control.theme = theme
 control.layout_direction = Control.LAYOUT_DIRECTION_RTL
