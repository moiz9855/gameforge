import os
import re

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
            except UnicodeDecodeError:
                with open(path, 'r', encoding='latin-1') as f:
                    content = f.read()
            
            modified = False
            if '.withOpacity(' in content:
                content = content.replace('.withOpacity(', '.withValues(alpha: ')
                modified = True
            
            # fix missing consts too for specific files if needed
            if 'ttt_screen.dart' in path:
                if 'Padding(' in content and 'const Padding(' not in content:
                    # just a dirty hack for ttt_screen 336
                    pass 
                    
            if modified:
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Fixed {path}")
