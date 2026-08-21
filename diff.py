import difflib

with open('old_skillbar.gd', 'r', encoding='utf-8') as f:
    old = f.readlines()
with open('components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    new = f.readlines()

diff = difflib.unified_diff(old, new, fromfile='old', tofile='new', n=2)
for line in diff:
    print(line.rstrip())
