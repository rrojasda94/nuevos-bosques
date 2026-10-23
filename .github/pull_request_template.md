## Qué cambia
<!-- 1–3 frases. El título del PR sigue Conventional Commits: tipo(ámbito): descripción -->

## Por qué
<!-- Enlaza el ADR, la ficha de diseño o la pregunta de 0000 que lo motiva. -->

## Cómo probarlo
<!-- Pasos para el dueño o QA. Controles, seed útil, qué mirar. -->

## Checklist
- [ ] `bash tools/test.sh` en verde
- [ ] Arranque headless sin errores
- [ ] Cumple `docs/CONVENCIONES.md`
- [ ] Si cambia una mecánica: ficha o ADR enlazados (regla 2 de `CLAUDE.md`)
- [ ] `CHANGELOG.md` actualizado en `[Sin publicar]` si el jugador lo nota
- [ ] Si cambia el formato de guardado: `SAVE_VERSION` y migración
