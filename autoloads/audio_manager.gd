extends Node
## AudioManager — autoload de efeitos sonoros (GDD 13 / Fase 7).
##
## Toca sons por NOME de evento, com um pool de players pra sobrepor. Os sons são
## PLACEHOLDERS procedurais (beeps gerados em código) — quando o humano colocar .wav/.ogg
## em `assets/audio/<evento>.wav`, eles têm prioridade. Comunicação: o gameplay chama
## `AudioManager.tocar("explodir")` etc. (autoload, sem acoplamento forte).

const TAXA: int = 22050
const N_PLAYERS: int = 8

## Evento -> frequência/duração do beep placeholder.
const EVENTOS := {
	"plantar": [330.0, 0.08],
	"tiro": [880.0, 0.06],
	"explodir": [120.0, 0.30],
	"soco": [200.0, 0.10],
	"desarme": [660.0, 0.20],
	"item": [990.0, 0.15],
	"vitoria": [520.0, 0.40],
}

var _sons: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _proximo: int = 0


var volume: float = 0.8   # 0..1 (master). Persistido em settings.


func _ready() -> void:
	for i in N_PLAYERS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for evento in EVENTOS:
		_sons[evento] = _carregar_ou_gerar(evento)
	# Volume salvo nos settings (Persistencia já carregou — ordem de autoload).
	aplicar_volume(float(Persistencia.get_config("audio", "volume", 0.8)))


## Ajusta o volume master (0..1). 0 = mudo. Não salva (quem salva é a tela de settings).
func aplicar_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	var db := -80.0 if volume <= 0.001 else linear_to_db(volume)
	AudioServer.set_bus_volume_db(0, db)


## Toca o som do evento. Retorna false se não houver som pra ele.
func tocar(evento: String) -> bool:
	if not _sons.has(evento):
		return false
	var p := _players[_proximo]
	_proximo = (_proximo + 1) % _players.size()
	p.stream = _sons[evento]
	p.play()
	return true


func tem_som(evento: String) -> bool:
	return _sons.has(evento)


## Usa o .wav do projeto se existir; senão gera um beep placeholder.
func _carregar_ou_gerar(evento: String) -> AudioStream:
	var caminho := "res://assets/audio/%s.wav" % evento
	if ResourceLoader.exists(caminho):
		return load(caminho)
	var freq: float = EVENTOS[evento][0]
	var dur: float = EVENTOS[evento][1]
	return _gerar_beep(freq, dur)


## Beep senoidal com decaimento, como AudioStreamWAV 16-bit mono.
func _gerar_beep(freq: float, dur: float) -> AudioStreamWAV:
	var n := int(TAXA * dur)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	for i in n:
		var t := float(i) / float(TAXA)
		var env := 1.0 - float(i) / float(n)        # decaimento linear
		var amostra := sin(TAU * freq * t) * env * 0.5
		dados.encode_s16(i * 2, int(clampf(amostra, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = dados
	return w
