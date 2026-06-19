extends Node
## Persistência local (GDD 15 Fase 8). Guarda settings e progressão simples num
## ConfigFile em `user://`. Sem nuvem/online (isso é decisão do humano — ver docs/ONLINE.md).

const CAMINHO: String = "user://vaultbreaker.cfg"

var _cfg: ConfigFile = ConfigFile.new()


func _ready() -> void:
	carregar()


## Lê o arquivo do disco (se existir) pro objeto em memória.
func carregar() -> void:
	_cfg = ConfigFile.new()
	_cfg.load(CAMINHO)  # erro (arquivo ausente) é ok: começa vazio


## Grava o objeto em memória no disco.
func salvar() -> void:
	_cfg.save(CAMINHO)


func set_config(secao: String, chave: String, valor: Variant) -> void:
	_cfg.set_value(secao, chave, valor)


func get_config(secao: String, chave: String, padrao: Variant) -> Variant:
	return _cfg.get_value(secao, chave, padrao)


## Contabiliza o resultado de uma partida (vitórias/derrotas do jogador 1) e salva.
func registrar_resultado(vencedor_id: int) -> void:
	if vencedor_id == 1:
		set_config("estatisticas", "vitorias", int(get_config("estatisticas", "vitorias", 0)) + 1)
	elif vencedor_id == 2:
		set_config("estatisticas", "derrotas", int(get_config("estatisticas", "derrotas", 0)) + 1)
	salvar()
