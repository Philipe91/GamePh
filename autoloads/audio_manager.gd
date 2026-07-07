extends Node
## AudioManager — autoload de efeitos sonoros (GDD 13 / Fase 7).
##
## Toca sons por NOME de evento, com um pool de players pra sobrepor. Os sons são
## PLACEHOLDERS procedurais (beeps gerados em código) — quando o humano colocar .wav/.ogg
## em `assets/audio/<evento>.wav`, eles têm prioridade. Comunicação: o gameplay chama
## `AudioManager.tocar("explodir")` etc. (autoload, sem acoplamento forte).

const TAXA: int = 22050
const N_PLAYERS: int = 8

## Evento -> parâmetros da síntese procedural:
## [duração s, freq inicial Hz, freq final Hz, quantidade de ruído 0..1, curva do decay].
## Ruído alto + queda de frequência = impacto; ruído zero + frequência subindo = "chime".
const EVENTOS := {
	"plantar": [0.07, 500.0, 660.0, 0.1, 1.0],
	"tiro": [0.09, 900.0, 220.0, 0.5, 1.5],
	"explodir": [0.5, 100.0, 38.0, 0.7, 2.0],
	"soco": [0.12, 120.0, 60.0, 0.2, 1.5],
	"dano": [0.1, 500.0, 300.0, 0.6, 1.2],
	"derrubado": [0.25, 300.0, 80.0, 0.15, 1.0],
	"desarme": [0.25, 400.0, 900.0, 0.0, 0.8],
	"item": [0.18, 700.0, 1200.0, 0.0, 0.8],
	"vitoria": [0.5, 400.0, 800.0, 0.0, 0.5],
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
## Pequena variação aleatória de pitch a cada disparo: quebra a repetição de ouvir o
## MESMO sample dezenas de vezes por partida (identidade sonora — GDD 13).
func tocar(evento: String) -> bool:
	if not _sons.has(evento):
		return false
	var p := _players[_proximo]
	_proximo = (_proximo + 1) % _players.size()
	p.stream = _sons[evento]
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()
	return true


func tem_som(evento: String) -> bool:
	return _sons.has(evento)


## Usa o .wav do projeto se existir; senão SINTETIZA o efeito (bem melhor que beep:
## mistura seno+ruído com varredura de frequência e envelope — explosão soa grave e
## "cheia", tiro soa seco, chimes sobem). Ainda é placeholder até termos áudio final.
func _carregar_ou_gerar(evento: String) -> AudioStream:
	var caminho := "res://assets/audio/%s.wav" % evento
	if ResourceLoader.exists(caminho):
		return load(caminho)
	var p: Array = EVENTOS[evento]
	return _sintetizar(float(p[0]), float(p[1]), float(p[2]), float(p[3]), float(p[4]))


## Gera um AudioStreamWAV 16-bit mono: seno com varredura f_ini->f_fim misturado a
## ruído branco (proporção `ruido`), com envelope (1-t)^decai.
func _sintetizar(dur: float, f_ini: float, f_fim: float, ruido: float, decai: float) -> AudioStreamWAV:
	var n := int(TAXA * dur)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var fase := 0.0
	for i in n:
		var frac := float(i) / float(n)
		var env := pow(1.0 - frac, decai)
		var f := lerpf(f_ini, f_fim, frac)
		fase += TAU * f / float(TAXA)
		var s := sin(fase) * (1.0 - ruido) + (randf() * 2.0 - 1.0) * ruido
		dados.encode_s16(i * 2, int(clampf(s * env * 0.6, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = dados
	return w
