extends Resource
## StatsPersonagem — parâmetros de um personagem do roster (GDD seção 4 / Fase 5).
##
## Cada personagem é um .tres com estes campos. O Combatente aplica no _ready: vida,
## velocidade, munição e o loadout de armadilhas. Balanceia sem mexer em código
## (CLAUDE.md regra 4), no mesmo espírito do [[stats_armadilha]].
class_name StatsPersonagem

@export var nome: String = "Sem Nome"
## Cor de time / tinta base (placeholder até os modelos da Fase 5+).
@export var cor_time: Color = Color(0.2, 0.6, 1.0)
@export var vida_max: float = 100.0
@export var velocidade: float = 7.0       # m/s
@export var municao_max: int = 6
## Identificador da arma (afeta o feel; specs detalhadas viram .tres próprio depois).
@export var arma: String = "pistola"
## Loadout de armadilhas: tipo -> quantidade inicial. Ex.: {"mina": 4, "bomba": 4}.
## Tipos fora do dicionário começam (e recarregam até) zero pra esse personagem.
@export var loadout: Dictionary = {}
