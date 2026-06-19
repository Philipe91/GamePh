# Ícones das armadilhas (menu radial / HUD)

Coloque aqui os PNG dos ícones das 6 armadilhas, **fundo transparente**, quadrados
(256–512 px). O menu radial carrega automaticamente o arquivo com o nome do tipo; se não
existir, usa a bolha colorida placeholder.

Nomes EXATOS esperados (tudo minúsculo, sem acento):

- `mina.png`
- `bomba.png`
- `detonador.png`
- `gas.png`
- `cova.png`
- `painel.png`

Como entregar (estando longe do PC):
- **GitHub web/app:** suba os PNG direto pra `assets/sprites/armadilhas/` no repo
  `Philipe91/GamePh` (branch main); depois o agente dá `git pull` e integra.
- **No PC de casa:** é só copiar os arquivos pra esta pasta.

Carregamento via `Image.load` (não depende de importar pelo editor) — basta o arquivo
existir aqui. Cores de referência em `docs/ARTE_PALETA_E_PROMPTS.md`.
