# VAULTBREAKER — Export PC (Fase 9)

Preset de export pra **Windows Desktop** já versionado em `export_presets.cfg`
(saída em `build/vaultbreaker.exe`). O binário (`build/`) é ignorado no git.

## Pré-requisito (humano, uma vez)

O export precisa dos **Export Templates** da MESMA versão do Godot (4.6.3). Eles são um
download à parte (~centenas de MB), não vêm no editor:

- No editor: **Editor → Manage Export Templates → Download and Install**.
- Ou baixar o `.tpz` em godotengine.org/download e instalar pelo mesmo menu.

Sem os templates, o export falha com "No export template found".

## Exportar (linha de comando, não trava)

```bash
# release
godot --headless --path "D:/PROJETOS CLAUDE/GAME" --export-release "Windows Desktop" build/vaultbreaker.exe
# debug (com console)
godot --headless --path "D:/PROJETOS CLAUDE/GAME" --export-debug "Windows Desktop" build/vaultbreaker.exe
```

O nome do preset (`"Windows Desktop"`) tem que bater com `export_presets.cfg`.

## Notas

- **Ícone:** `application/icon` está vazio (usa o do Godot). Coloque um `.ico` quando tiver
  arte e aponte o caminho no preset.
- **Mobile (depois):** o GDD prevê PC primeiro, mobile depois (Fase 9). Pra Android, criar
  um preset "Android" + SDK/keystore — outra rodada, fora do escopo noturno.
- **Cena principal:** `scenes/ui/titulo.tscn` (Título → Seleção → Arena).

Roadmap: `GDD.md` seção 15. Estado: `PROGRESSO.md`.
