extends Node
# Original procedural ambience and footsteps: no external assets or network.
var ambience := AudioStreamPlayer.new()
var effect := AudioStreamPlayer.new()
var random := RandomNumberGenerator.new()

func _ready() -> void:
 random.seed = 17
 add_child(ambience)
 add_child(effect)
 var stream := _sound(1.0, 50.0, .08)
 stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
 stream.loop_end = 11025
 ambience.stream = stream
 ambience.volume_db = -23
 ambience.play()
 refresh()

func refresh() -> void:
 var enabled: bool = GameState.sound_enabled and GameState.sound_volume > 0
 ambience.stream_paused = not enabled
 effect.volume_db = linear_to_db(maxf(GameState.sound_volume, .001)) - 13
 ambience.volume_db = linear_to_db(maxf(GameState.sound_volume, .001)) - 23

func _exit_tree() -> void:
 ambience.stop()
 effect.stop()
 ambience.stream = null
 effect.stream = null

func step(metal: bool) -> void:
 if not GameState.sound_enabled or GameState.sound_volume <= 0:
  return
 effect.stream = _sound(.085, 145.0 if metal else 72.0, .25)
 effect.play()

func tap() -> void:
 if GameState.sound_enabled and GameState.sound_volume > 0:
  effect.stream = _sound(.05, 460.0, .02)
  effect.play()

func _sound(duration: float, frequency: float, noise: float) -> AudioStreamWAV:
 var count := int(11025 * duration)
 var bytes := PackedByteArray()
 bytes.resize(count * 2)
 for i in range(count):
  var envelope := 1.0 if duration >= 1 else pow(1.0 - float(i)/count, 2)
  var sample := (sin(TAU*frequency*float(i)/11025.0)*.3 + random.randf_range(-noise,noise)) * envelope
  bytes.encode_s16(i*2, int(clampf(sample,-1,1)*32767))
 var stream := AudioStreamWAV.new()
 stream.format = AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate = 11025
 stream.data = bytes
 return stream
