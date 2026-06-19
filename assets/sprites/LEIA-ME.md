# Texturas / ícones (2D)

Plug-and-play — é só largar o arquivo aqui com o nome certo que o jogo usa automático
(carregado via `Image.load`, não precisa importar pelo editor):

- **`chao.png`** — textura do CHÃO da arena (tileável, fundo opaco). A arena aplica e
  repete pelo piso. Fonte fácil/CC0: **Kenney "Prototype Textures"** (kenney.nl) ou uma
  textura tileável gerada por IA (prompt em `docs/ARTE.md`).
- **`armadilhas/<tipo>.png`** — ícones das 6 armadilhas (já em uso na roda/HUD).

Personagens 3D vão em `assets/models/personagens/<nome>/<nome>.glb` e plugam pelo campo
`cena_modelo` do `StatsPersonagem`. Ver `docs/CRIACAO_DE_ASSETS.md`.
