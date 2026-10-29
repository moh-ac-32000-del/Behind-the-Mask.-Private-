extends RefCounted
# Write a complete temporary file before rotating a validated save to its backup.
var path: String
var selected_path := ""
var error_message := ""

func _init(save_path: String = "user://campaign_v3.json") -> void:
 path = save_path

func candidates() -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for candidate in [path, path + ".bak", path + ".tmp"]:
  if not FileAccess.file_exists(candidate):
   continue
  var parser := JSON.new()
  if parser.parse(FileAccess.get_file_as_string(candidate)) == OK and parser.data is Dictionary:
   result.append({"path": candidate, "data": parser.data})
 return result

func exists() -> bool:
 return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".tmp")

func write(data: Dictionary, purge_report: bool = false) -> bool:
 error_message = ""
 var temporary := path + ".tmp"
 var file := FileAccess.open(temporary, FileAccess.WRITE)
 if file == null:
  return _failed()
 file.store_string(JSON.stringify(data))
 file.flush()
 var write_error := file.get_error()
 file.close()
 if write_error != OK:
  return _failed()
 if FileAccess.file_exists(path):
  var destination := path + ".bak" if selected_path == path else path + ".rejected-" + str(Time.get_ticks_usec())
  if FileAccess.file_exists(destination):
   if DirAccess.remove_absolute(ProjectSettings.globalize_path(destination)) != OK:
    return _failed()
  if DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(destination)) != OK:
   return _failed()
 if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK:
  return _failed()
 selected_path = path
 if purge_report:
  # Revoking consent removes the optional history from the backup too.
  var backup := FileAccess.open(path + ".bak", FileAccess.WRITE)
  if backup == null:
   return _failed()
  backup.store_string(JSON.stringify(data))
  backup.flush()
  var backup_error := backup.get_error()
  backup.close()
  if backup_error != OK:
   return _failed()
 return true

func _failed() -> bool:
 error_message = "تعذر حفظ التقدم. أعد المحاولة قبل إغلاق اللعبة."
 return false
