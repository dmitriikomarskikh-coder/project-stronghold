extends Node

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _mix_rate := 22050.0

func _ready() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = _mix_rate
	stream.buffer_length = 0.25
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()

func play_select() -> void:
	_tone(660.0, 0.035, 0.11)

func play_command() -> void:
	_tone(440.0, 0.045, 0.13)

func play_under_attack() -> void:
	_tone(180.0, 0.08, 0.18)
	_tone(150.0, 0.08, 0.18)

func _tone(freq: float, duration: float, amp: float) -> void:
	if _playback == null:
		return
	var frames := int(_mix_rate * duration)
	for i in range(frames):
		if not _playback.can_push_buffer(1):
			return
		var t := float(i) / _mix_rate
		var envelope := 1.0 - (float(i) / float(max(1, frames)))
		var sample := sin(TAU * freq * t) * amp * envelope
		_playback.push_frame(Vector2(sample, sample))
