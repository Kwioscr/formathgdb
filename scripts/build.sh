#!/bin/bash
set -e

echo "=== ForMathGDB - Build script ==="

# 1. Activer opam
eval $(opam env)

# 2. Vérifier que coq-lsp 0.2.5 est installé
if ! opam list coq-lsp | grep -q "0.2.5"; then
  echo "Installation de coq-lsp 0.2.5+9.1..."
  opam install coq-lsp.0.2.5+9.1 -y
fi

# 3. Télécharger les sources opam dans un dossier temporaire
BUILD_DIR="$HOME/.formathgdb-build"
echo "Téléchargement des sources dans $BUILD_DIR..."
rm -rf "$BUILD_DIR"
opam source coq-lsp.0.2.5+9.1 --dir="$BUILD_DIR"

# 4. Copier notre main.ml en adaptant le nom du constructeur
echo "Copie du plugin..."
sed 's/| VernacAbbreviation (_, _, _, _) -> None/| VernacSyntacticDefinition (_, _, _) -> None/' \
  "$(dirname "$0")/../plugin/main.ml" \
  > "$BUILD_DIR/plugins/metanejo/main.ml"

cp "$(dirname "$0")/../plugin/dune" \
  "$BUILD_DIR/plugins/metanejo/dune"

# 5. Builder
echo "Compilation..."
cd "$BUILD_DIR"
dune build plugins/metanejo

# 6. Installer
echo "Installation du plugin..."
PLUGIN_DIR=$(opam var lib)/coq-lsp/plugin/metanejo
cp _build/default/plugins/metanejo/Metanejo_plugin.cmxs \
   "$PLUGIN_DIR/Metanejo_plugin.cmxs"

echo "=== Build terminé avec succès ! ==="
echo ""
echo "Pour générer le JSON sur un fichier .v :"
echo "  fcc --root=<dossier> --plugin=coq-lsp.plugin.metanejo <fichier.v>"
