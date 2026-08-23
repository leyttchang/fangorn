import os

def fix_directory(root_dir):
    fixed_count = 0
    for dirpath, _, filenames in os.walk(root_dir):
        if '.godot' in dirpath:
            continue
            
        for filename in filenames:
            if not filename.endswith('.gd'):
                continue
                
            filepath = os.path.join(dirpath, filename)
            
            # Read raw bytes
            with open(filepath, 'rb') as f:
                raw = f.read()
                
            needs_fix = False
            
            # Check for UTF-16 BOM
            if raw.startswith(b'\xff\xfe') or raw.startswith(b'\xfe\xff'):
                needs_fix = True
            
            # Check if it's valid UTF-8
            try:
                raw.decode('utf-8')
            except UnicodeDecodeError:
                needs_fix = True
                
            if needs_fix:
                print(f"Fixing encoding for: {filepath}")
                try:
                    # Try reading as utf-16
                    with open(filepath, 'r', encoding='utf-16') as f:
                        content = f.read()
                except Exception:
                    # Fallback to cp1252
                    with open(filepath, 'r', encoding='cp1252', errors='ignore') as f:
                        content = f.read()
                        
                # Strip all non-ascii characters (accents) just to be absolutely safe
                clean_content = "".join(c if ord(c) < 128 else "" for c in content)

                # Write back as pure UTF-8 without BOM
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(clean_content)
                
                fixed_count += 1
                
    print(f"Total files fixed: {fixed_count}")

fix_directory('Y:/Fangorn/fangorn')
