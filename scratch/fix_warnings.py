import os

files_to_fix = [
    r"lib\features\arcade\games\slingshot\slingshot_game.dart",
    r"lib\features\arcade\games\slingshot\slingshot_screen.dart",
    r"lib\features\arcade\games\ttt\ttt_screen.dart",
    r"lib\features\arcade\presentation\retro_startup_screen.dart",
    r"lib\features\multiplayer\draw\draw_lobby.dart",
    r"lib\features\multiplayer\draw\drawing_canvas.dart",
    r"lib\main.dart"
]

for f in files_to_fix:
    try:
        with open(f, 'r', encoding='utf-8') as file:
            content = file.read()
        content = content.replace('.withOpacity(', '.withValues(alpha: ')
        with open(f, 'w', encoding='utf-8') as file:
            file.write(content)
        print(f"Fixed {f}")
    except Exception as e:
        print(f"Error fixing {f}: {e}")

tow = r"lib\features\arcade\games\tow\tow_screen.dart"
try:
    with open(tow, 'r', encoding='utf-8') as file:
        content = file.read()
    content = content.replace('final playerWidth =', 'const playerWidth =')
    content = content.replace('final playerHeight =', 'const playerHeight =')
    with open(tow, 'w', encoding='utf-8') as file:
        file.write(content)
    print("Fixed tow_screen")
except Exception as e:
    print(f"Error {e}")
