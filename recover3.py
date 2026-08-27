import json

log_path = r'C:\Users\ley-a\.gemini\antigravity\brain\07938edb-a257-49cc-9db4-a671c85b3837\.system_generated\logs\transcript_full.jsonl'
with open(log_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line in reversed(lines):
    if 'scout.gd' in line and '_is_rotation_locked' in line:
        try:
            data = json.loads(line)
            content = data.get('content', '')
            if 'extends CharacterBody3D' in content:
                print('Found it!')
                with open('recovered_scout_final.txt', 'w', encoding='utf-8') as out:
                    out.write(content)
                break
        except:
            pass
print('Done')
