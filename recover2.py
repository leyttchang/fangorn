import json

log_path = r'C:\Users\ley-a\.gemini\antigravity\brain\07938edb-a257-49cc-9db4-a671c85b3837\.system_generated\logs\transcript_full.jsonl'
with open(log_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

found_count = 0
for line in reversed(lines):
    if 'scout.gd' in line and 'diff_block_start' not in line:
        try:
            data = json.loads(line)
            content = data.get('content', '')
            if 'extends CharacterBody3D' in content and 'scout.gd' in content:
                found_count += 1
                # Skip the first one we find because it's from 14:20:52
                if found_count > 1:
                    with open(f'recovered_scout_{found_count}.txt', 'w', encoding='utf-8') as out:
                        out.write(content)
        except:
            pass
print('Done')
