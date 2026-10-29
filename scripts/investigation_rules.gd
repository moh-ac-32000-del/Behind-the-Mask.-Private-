extends RefCounted
class_name InvestigationRules

static func can_open_file(evidence: Dictionary) -> bool:
 return evidence.has("terminal")

static func outcome(guard_trust: int, phone_secret: bool, choice: String) -> String:
 var lines: Array[String] = [choice]
 if guard_trust > 0:
  lines.append("الحارس يساعدك على الهرب.")
 elif guard_trust < 0:
  lines.append("الحارس يبلغ الإدارة عنك.")
 else:
  lines.append("لا أحد ينتظرك عند الباب.")
 if phone_secret:
  lines.append("تظل الرسالة سرية.")
 else:
  lines.append("تصل الرسالة إلى إدارة المبنى.")
 return "\n".join(lines)
