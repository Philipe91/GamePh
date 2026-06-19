extends StaticBody3D
## Lançador de mapa (GDD 10): Laser Launcher e Rocket Launcher. Dispara projéteis num
## intervalo fixo numa direção. Destrutível por projétil ou bomba (group "destrutiveis").
## Os tiros são de "ninguém" (dono_id 0), então acertam os DOIS jogadores.

const PROJETIL := preload("res://scenes/projeteis/projetil.tscn")

@export var tipo: String = "laser"          # "laser" | "foguete"
@export var direcao: Vector3 = Vector3(0, 0, 1)
@export var intervalo: float = 2.0

const VIDA: float = 15.0
var _vida: float = VIDA
var _t: float = 1.0


func _ready() -> void:
	add_to_group("destrutiveis")


func _physics_process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_disparar()


func _disparar() -> void:
	_t = intervalo
	var d := direcao
	d.y = 0.0
	if d.length() < 0.01:
		return
	d = d.normalized()
	var p := PROJETIL.instantiate()
	p.dono_id = 0                              # field trap: acerta os dois times
	p.dano = 8.0 if tipo == "laser" else 14.0  # foguete dói mais
	p.velocidade = d * (18.0 if tipo == "laser" else 12.0)
	get_parent().add_child(p)
	p.global_position = global_position + d * 1.2
	p.global_position.y = 1.0


func receber_dano(qtd: float, _tipo_dano: String = "normal") -> void:
	_vida -= qtd
	if _vida <= 0.0:
		queue_free()
