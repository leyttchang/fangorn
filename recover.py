import json

log_path = r'C:\Users\ley-a\.gemini\antigravity\brain\07938edb-a257-49cc-9db4-a671c85b3837\.system_generated\logs\transcript_full.jsonl'
with open(log_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line in reversed(lines):
    if 'scout.gd' in line and 'diff_block_start' not in line:
        try:
            data = json.loads(line)
            content = data.get('content', '')
            if 'extends CharacterBody3D' in content and 'scout.gd' in content:
                print('Found full file in transcript!')
                with open('recovered_scout.txt', 'w', encoding='utf-8') as out:
                    out.write(content)
                break
        except:
            pass
print('Done')
