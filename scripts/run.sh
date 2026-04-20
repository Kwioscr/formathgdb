#!/bin/bash
set -e

eval $(opam env)

SCRIPT_DIR="$(dirname "$0")"
EXAMPLES_DIR="$SCRIPT_DIR/../examples"
NEO4J_IMPORT="/home/kiwi/.config/neo4j-desktop/Application/Data/dbmss/dbms-7a43a1ea-5746-48ba-b8ff-2da8357102a1/import"

echo "=== Génération du JSON pour Rtrigo1.v ==="
fcc \
  --root="$EXAMPLES_DIR" \
  --plugin=coq-lsp.plugin.metanejo \
  "$EXAMPLES_DIR/Rtrigo1.v"

echo "=== Copie vers Neo4j ==="
cp "$EXAMPLES_DIR/Rtrigo1.v.meta.json" "$NEO4J_IMPORT/"
echo "JSON copié dans le dossier import de Neo4j !"

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
"
echo ""
echo "Lance maintenant neo4j/import.cypher dans le browser Neo4j !"
