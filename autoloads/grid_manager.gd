extends Node
## GridManager — autoload (singleton) do grid lógico da arena.
##
## Responsabilidades (GDD seção 5):
##  - Converter coordenadas grid <-> mundo (grid_to_world / world_to_grid).
##  - Guardar a ocupação de cada tile e a lista de armadilhas plantadas, com dono.
##  - Validar se um tile aceita armadilha.
##
## O movimento do personagem é LIVRE; o snap só acontece ao plantar a armadilha,
## que vai pro centro do tile mais próximo.

## Sinal emitido quando uma armadilha é registrada num tile.
signal armadilha_plantada(coord: Vector2i, dono: int, tipo: String)
## Sinal emitido quando uma armadilha é removida de um tile (explodiu, retomada, etc).
signal armadilha_removida(coord: Vector2i, dono: int, tipo: String)

## Dimensões lógicas da arena, em tiles. Começa 12x12 (GDD seção 5), ajustável por mapa.
const LARGURA: int = 12
const ALTURA: int = 12
## Tamanho de cada tile em unidades de mundo. Tiles de 2x2 dão espaço pra cápsula andar.
const TAMANHO_TILE: float = 2.0

## Tipos de tile que NÃO aceitam armadilha (GDD seção 5).
## Por enquanto só usamos LIVRE e ARMADILHA; os demais entram nas próximas fases.
enum TipoTile { LIVRE, VAULT, ESCADA, RAMPA, ESTEIRA }

## Ocupação de armadilha por tile: Vector2i -> Dictionary { "dono": int, "tipo": String, "no": Node }.
var _armadilhas: Dictionary = {}
## Tipo de cada tile (para regras de plantio). Vazio = LIVRE.
var _tipos_tile: Dictionary = {}


## Retorna true se a coordenada está dentro dos limites do grid.
func dentro_do_grid(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < LARGURA and coord.y >= 0 and coord.y < ALTURA


## Converte coordenada de grid (coluna x, linha y) para o centro do tile em mundo (Vector3, y=0).
## A arena fica centrada na origem, então o tile (0,0) é o canto inferior-esquerdo.
func grid_to_world(coord: Vector2i) -> Vector3:
	var mundo_x: float = (float(coord.x) + 0.5) * TAMANHO_TILE - (LARGURA * TAMANHO_TILE) * 0.5
	var mundo_z: float = (float(coord.y) + 0.5) * TAMANHO_TILE - (ALTURA * TAMANHO_TILE) * 0.5
	return Vector3(mundo_x, 0.0, mundo_z)


## Converte uma posição de mundo para a coordenada de grid do tile que a contém.
## Não faz clamp — use dentro_do_grid() para validar o resultado.
func world_to_grid(pos: Vector3) -> Vector2i:
	var col: int = int(floor((pos.x + (LARGURA * TAMANHO_TILE) * 0.5) / TAMANHO_TILE))
	var lin: int = int(floor((pos.z + (ALTURA * TAMANHO_TILE) * 0.5) / TAMANHO_TILE))
	return Vector2i(col, lin)


## Define o tipo de um tile (Vault, escada, etc). Tiles não definidos são LIVRE.
func definir_tipo_tile(coord: Vector2i, tipo: TipoTile) -> void:
	_tipos_tile[coord] = tipo


## Retorna o tipo de um tile (LIVRE por padrão).
func tipo_do_tile(coord: Vector2i) -> TipoTile:
	return _tipos_tile.get(coord, TipoTile.LIVRE)


## Retorna true se o tile já tem uma armadilha plantada.
func tem_armadilha(coord: Vector2i) -> bool:
	return _armadilhas.has(coord)


## Valida se um tile aceita uma nova armadilha (GDD seção 5):
## precisa estar dentro do grid, ser do tipo LIVRE e não ter armadilha.
func pode_plantar(coord: Vector2i) -> bool:
	if not dentro_do_grid(coord):
		return false
	if tipo_do_tile(coord) != TipoTile.LIVRE:
		return false
	return not tem_armadilha(coord)


## Registra uma armadilha num tile, com dono e nó associado. Emite armadilha_plantada.
## Retorna true se registrou; false se o tile não aceitava.
func registrar_armadilha(coord: Vector2i, dono: int, tipo: String, no: Node) -> bool:
	if not pode_plantar(coord):
		return false
	_armadilhas[coord] = { "dono": dono, "tipo": tipo, "no": no }
	armadilha_plantada.emit(coord, dono, tipo)
	return true


## Remove a armadilha de um tile. Emite armadilha_removida. Retorna o dict removido ou {}.
func remover_armadilha(coord: Vector2i) -> Dictionary:
	if not _armadilhas.has(coord):
		return {}
	var info: Dictionary = _armadilhas[coord]
	_armadilhas.erase(coord)
	armadilha_removida.emit(coord, info["dono"], info["tipo"])
	return info


## Retorna os dados da armadilha num tile, ou {} se não houver.
func armadilha_em(coord: Vector2i) -> Dictionary:
	return _armadilhas.get(coord, {})


## Faz snap de uma posição de mundo para o centro do tile mais próximo (em mundo).
## Usado no momento de plantar. Retorna também a coord via parâmetro de saída não é
## possível em GDScript, então use world_to_grid() + grid_to_world() quando precisar da coord.
func snap_para_tile(pos: Vector3) -> Vector3:
	return grid_to_world(world_to_grid(pos))
