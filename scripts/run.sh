#!/bin/bash
set -e

eval $(opam env)

SCRIPT_DIR="$(dirname "$0")"
EXAMPLES_DIR="$SCRIPT_DIR/../examples"

echo "=== Génération du JSON pour Rtrigo1.v ==="
fcc \
  --root="$EXAMPLES_DIR" \
  --plugin=coq-lsp.plugin.metanejo \
  "$EXAMPLES_DIR/Rtrigo1.v"

echo ""
echo "=== Résultat ==="
python3 -c "
import json
with open('$EXAMPLES_DIR/Rtrigo1.v.meta.json') as f:
    data = json.load(f)
edges = data['graph']['edges']
nodes = data['graph']['nodes']
print(f'Noeuds: {len(nodes)}')
print(f'Edges: {len(edges)}')
deps = sorted([e['to'] for e in edges if e['from'] == 'cos_incr_1'])
print(f'Deps de cos_incr_1: {deps}')
"
