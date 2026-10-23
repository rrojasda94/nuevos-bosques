# ADR 0001 — Motor: Godot 4.x con GDScript

## Contexto
Juego 2D pixel art 8-bit, RPG + gestión de ciudad, equipo pequeño, publicación en Steam.

## Decisión
Godot 4.5+ (build standard), GDScript, renderer GL Compatibility, viewport 320×180 con escala entera.

## Consecuencias
- Sin regalías ni licencias. Exporta a Windows/Linux/macOS.
- Steam vía GodotSteam (GDExtension), no nativo.
- C# queda como opción solo si un sistema concreto lo exige.
