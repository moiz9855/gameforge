import os

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                if '.withOpacity(' in content:
                    content = content.replace('.withOpacity(', '.withValues(alpha: ')
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"Fixed {path}")
            except Exception as e:
                print(f"Error reading {path}: {e}")
