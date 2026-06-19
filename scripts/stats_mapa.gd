extends Resource
## StatsMapa — define um mapa/arena por dados (GDD seção 5 / Fase 6).
##
## O GridManager lê as dimensões e a arena posiciona spawns e Vaults a partir daqui.
## Balanceia/cria mapas sem mexer em código (no espírito do [[stats_armadilha]]).
class_name StatsMapa

@export var nome: String = "Padrão"
@export var largura: int = 12
@export var altura: int = 12
@export var tamanho_tile: float = 2.0
@export var spawn_jogador: Vector2i = Vector2i(3, 8)
@export var spawn_bot: Vector2i = Vector2i(9, 3)
## Tiles que recebem uma Vault (P.O.D.S.).
@export var vaults: Array[Vector2i] = [Vector2i(6, 6)]
