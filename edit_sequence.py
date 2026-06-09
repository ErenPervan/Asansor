import sys

with open(sys.argv[1], 'r') as f:
    lines = f.readlines()

for i in range(len(lines)):
    if lines[i].startswith('pick'):
        lines[i] = lines[i].replace('pick', 'edit', 1)
        break

with open(sys.argv[1], 'w') as f:
    f.writelines(lines)
