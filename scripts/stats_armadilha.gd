extends Resource
## StatsArmadilha — parâmetros de uma armadilha (GDD seção 6.4).
##
## Cada armadilha é um .tres com estes campos. A cena genérica `armadilha.tscn`
## lê o Resource e ramifica o comportamento por `tipo`. Assim dá pra balancear sem
## mexer em código (CLAUDE.md regra 4). Campos específicos ficam zerados quando não
## se aplicam ao tipo.
class_name StatsArmadilha

## Tipo: "mina" | "bomba" | "detonador" | "gas" | "cova" | "painel".
@export var tipo: String = "mina"
@export var nome: String = "Mina"
## Cor do marcador/aviso (e da fatia no menu radial).
@export var cor: Color = Color(1.0, 0.55, 0.1)
## Quantas começam no inventário do dono.
@export var inventario_inicial: int = 4
## Atraso (s) entre plantar e ficar ativa. Antes disso é inerte.
@export var tempo_arma: float = 0.5
## Tempo (s) até voltar pro inventário depois de usada.
@export var tempo_retorno: float = 6.0

## Raio (m) do gatilho "inimigo pisou" (Area3D). 0 = não dispara por pisar.
@export var raio_detector: float = 0.7
## Raio (m) do efeito (dano/explosão/veneno/arremesso).
@export var raio_efeito: float = 2.2
@export var dano: float = 20.0
@export var knockback: float = 3.5

## --- Específicos de tipo ---
## Gás: tempo (s) após armar até começar a emitir veneno. 0 = não auto-emite.
@export var auto_emite_apos: float = 0.0
## Gás: por quanto tempo (s) o veneno fica ativo no chão.
@export var duracao_efeito: float = 0.0
## Cova/Gás: segundos imobilizado ao ser pego.
@export var imobiliza: float = 0.0
## Gás: fator de velocidade aplicado (0.5 = metade). 1.0 = sem slow.
@export var slow_fator: float = 1.0
## Gás: duração (s) do slow.
@export var slow_duracao: float = 0.0
## Painel de Força: força do arremesso na direção que o dono olhava ao plantar.
@export var arremesso: float = 0.0
