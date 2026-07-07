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
	"passos": [0.05, 220.0, 160.0, 0.5, 1.5],
	"caution": [0.2, 600.0, 800.0, 0.1, 0.8],
	"gas": [0.4, 200.0, 150.0, 0.9, 1.0],
	"ui_click": [0.04, 800.0, 900.0, 0.0, 1.0],
	"ui_back": [0.06, 600.0, 400.0, 0.0, 1.0],
	"ui_confirm": [0.12, 700.0, 1000.0, 0.0, 0.8],
}

var _sons: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _proximo: int = 0
var _musica: AudioStreamPlayer = null   # trilha de fundo (loop)


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
	_musica = AudioStreamPlayer.new()
	_musica.volume_db = -14.0   # trilha bem atrás dos SFX
	add_child(_musica)


## Liga a trilha de fundo (loop). Usa `assets/audio/musica.ogg|wav` se existir; senão
## SINTETIZA um loop retrô (kick + baixo em Lá menor + hat) — placeholder digno.
func tocar_musica() -> void:
	if _musica.playing:
		return
	var stream: AudioStream = null
	for caminho in ["res://assets/audio/musica.ogg", "res://assets/audio/musica.wav"]:
		if ResourceLoader.exists(caminho):
			stream = load(caminho)
			break
	if stream == null:
		stream = _gerar_loop_musica()
	_musica.stream = stream
	_musica.play()


func parar_musica() -> void:
	_musica.stop()


# ─────────────── Ambiência do complexo (o galpão nunca está em silêncio) ───────────────

var _ambiencia: AudioStreamPlayer = null
var _t_eco: float = 0.0
const ECOS: Array[String] = ["eco_porta", "eco_maquina", "eco_vapor"]


## Liga a CAMA sonora industrial (hum de máquina em loop, bem baixo) + ecos esparsos
## aleatórios (porta ao longe, máquina, vapor). Chamada pela arena.
func tocar_ambiencia() -> void:
	if _ambiencia != null and _ambiencia.playing:
		return
	if _ambiencia == null:
		_ambiencia = AudioStreamPlayer.new()
		_ambiencia.volume_db = -22.0
		add_child(_ambiencia)
	if not ResourceLoader.exists("res://assets/audio/ambiente.ogg"):
		return
	var stream: AudioStream = load("res://assets/audio/ambiente.ogg")
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_ambiencia.stream = stream
	_ambiencia.play()
	_t_eco = randf_range(6.0, 14.0)


func parar_ambiencia() -> void:
	if _ambiencia != null:
		_ambiencia.stop()


## Relógio dos ECOS: de tempos em tempos, um som distante do complexo (volume baixo,
## pitch levemente variado) lembra que o prédio está vivo.
func _process(delta: float) -> void:
	if _ambiencia == null or not _ambiencia.playing:
		return
	_t_eco -= delta
	if _t_eco > 0.0:
		return
	_t_eco = randf_range(7.0, 18.0)
	var evento: String = ECOS[randi() % ECOS.size()]
	if not _sons.has(evento):
		_sons[evento] = _carregar_ou_gerar_eco(evento)
	var variacoes: Array = _sons[evento]
	if variacoes.is_empty():
		return
	var p := _players[_proximo]
	_proximo = (_proximo + 1) % _players.size()
	p.stream = variacoes[0]
	p.volume_db = -16.0
	p.pitch_scale = randf_range(0.85, 1.05)
	p.play()
	# Devolve o volume normal do player pro próximo SFX de gameplay.
	p.finished.connect(func(): p.volume_db = 0.0, CONNECT_ONE_SHOT)


## Ecos não têm entrada na tabela EVENTOS (nada de fallback sintetizado — sem arquivo,
## sem eco).
func _carregar_ou_gerar_eco(evento: String) -> Array:
	var caminho := "res://assets/audio/%s.ogg" % evento
	if ResourceLoader.exists(caminho):
		return [load(caminho)]
	return []


## Loop de 6.4s @ 22050Hz: kick 4x4, baixo (Lá menor: A2 C3 E3 G3) em colcheias com
## leve saturação, hat de ruído no contratempo. LOOP_FORWARD pra tocar sem emenda.
func _gerar_loop_musica() -> AudioStreamWAV:
	var bpm := 100.0
	var batida := 60.0 / bpm                  # 0.6s por batida
	var n_batidas := 8                        # 2 compassos
	var dur := batida * float(n_batidas)      # ~4.8s... usa exato pro loop fechar
	var n := int(TAXA * dur)
	var dados := PackedByteArray()
	dados.resize(n * 2)
	var notas := [110.0, 130.81, 164.81, 196.0, 164.81, 130.81, 110.0, 98.0]  # A2 C3 E3 G3...
	var fase_baixo := 0.0
	for i in n:
		var t := float(i) / float(TAXA)
		var pos_batida := fmod(t, batida) / batida        # 0..1 dentro da batida
		var idx_batida := int(t / batida) % n_batidas
		# Kick no início de cada batida: seno grave com pitch caindo rápido.
		var kick := 0.0
		if pos_batida < 0.18:
			var kt := pos_batida / 0.18
			kick = sin(TAU * lerpf(120.0, 45.0, kt) * pos_batida * batida) * (1.0 - kt) * 0.9
		# Baixo: uma nota por batida, colcheia com envelope.
		var f_baixo: float = notas[idx_batida]
		fase_baixo += TAU * f_baixo / float(TAXA)
		var env_baixo := 0.5 * (1.0 - pos_batida)
		var baixo := clampf(sin(fase_baixo) * 1.6, -1.0, 1.0) * env_baixo  # saturação leve
		# Hat: ruído curtinho no contratempo.
		var hat := 0.0
		if pos_batida > 0.5 and pos_batida < 0.56:
			hat = (randf() * 2.0 - 1.0) * 0.12
		var s := clampf(kick * 0.8 + baixo * 0.45 + hat, -1.0, 1.0)
		dados.encode_s16(i * 2, int(s * 32767.0 * 0.7))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = dados
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w


## Ajusta o volume master (0..1). 0 = mudo. Não salva (quem salva é a tela de settings).
func aplicar_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	var db := -80.0 if volume <= 0.001 else linear_to_db(volume)
	AudioServer.set_bus_volume_db(0, db)


## Toca o som do evento (sorteia entre as VARIAÇÕES do evento, se houver). Retorna
## false se não houver som pra ele. Variação de arquivo + pitch ±8% a cada disparo:
## quebra a repetição de ouvir o MESMO sample dezenas de vezes (identidade — GDD 13).
func tocar(evento: String) -> bool:
	if not _sons.has(evento):
		return false
	var p := _players[_proximo]
	_proximo = (_proximo + 1) % _players.size()
	var variacoes: Array = _sons[evento]
	p.stream = variacoes[randi() % variacoes.size()]
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()
	return true


func tem_som(evento: String) -> bool:
	return _sons.has(evento)


## Carrega TODAS as variações do evento (`<evento>.ogg|wav`, `<evento>_2.ogg`, ...) —
## SFX reais (Kenney CC0) em assets/audio. Sem arquivo nenhum, SINTETIZA o efeito
## (fallback dos tempos de placeholder). Retorna sempre um Array de streams.
func _carregar_ou_gerar(evento: String) -> Array:
	var achados: Array = []
	for ext in ["ogg", "wav"]:
		var base := "res://assets/audio/%s.%s" % [evento, ext]
		if ResourceLoader.exists(base):
			achados.append(load(base))
		for i in range(2, 7):
			var variacao := "res://assets/audio/%s_%d.%s" % [evento, i, ext]
			if ResourceLoader.exists(variacao):
				achados.append(load(variacao))
	if not achados.is_empty():
		return achados
	var p: Array = EVENTOS[evento]
	return [_sintetizar(float(p[0]), float(p[1]), float(p[2]), float(p[3]), float(p[4]))]


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
