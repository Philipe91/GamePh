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

## Field traps por posição (GDD 10). Direções usam defaults (esteira +X, lançador +Z).
@export var obstaculos: Array[Vector2i] = []     # Obstacle Box (solta item)
@export var bombas_caixa: Array[Vector2i] = []   # Bomb Box (explode)
@export var esteiras: Array[Vector2i] = []       # Conveyer Belt
@export var pontes: Array[Vector2i] = []         # passarela (evasão da Plasma)
@export var lancadores: Array[Vector2i] = []     # Laser/Rocket Launcher

## Câmera segue o player (mapas grandes estilo Trap Gunner). False = câmera fixa (mapas
## pequenos que cabem inteiros na tela).
@export var camera_segue: bool = false

## Mapa vertical (com altura): liga gravidade nos personagens e monta as estruturas 3D.
@export var vertical: bool = false
## Estruturas 3D (Fase 6+): lista de Dictionaries. Tipos: "chao", "parede", "pilar"
## (pos+tam), "ponte" (pos+tam, com oclusão), "rampa" (de+ate+larg). Coordenadas em mundo.
@export var estruturas: Array = []
