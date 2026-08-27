import json

log_path = r'C:\Users\ley-a\.gemini\antigravity\brain\07938edb-a257-49cc-9db4-a671c85b3837\.system_generated\logs\transcript_full.jsonl'
with open(log_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line in reversed(lines):
    if '_is_rotation_locked' in line and 'extends CharacterBody3D' in line:
        try:
            data = json.loads(line)
            # could be inside tool_calls or something
            content = str(data)
            with open('raw_dump.txt', 'a', encoding='utf-8') as out:
                out.write(content + '\n')
        except:
            pass
