# ForMathGDB

A Knowledge Graph of Formalized Mathematics built on top of Rocq and Neo4j.

## Prérequis

- opam avec le switch `formathgdb`
- coq-lsp 0.2.5+9.1
- rocq-stdlib
- Neo4j Desktop avec APOC

## Installation

```bash
# Installer les dépendances opam
opam install coq-lsp.0.2.5+9.1 rocq-stdlib -y

# Builder et installer le plugin
./scripts/build.sh
```

## Utilisation

```bash
# Générer le JSON pour Rtrigo1.v
./scripts/run.sh

# Ou sur n'importe quel fichier .v
fcc --root=<dossier_projet> \
    --plugin=coq-lsp.plugin.metanejo \
    <fichier.v>
```

## Import dans Neo4j

1. Copier le `.meta.json` dans le dossier `import` de Neo4j
2. Lancer les requêtes dans `neo4j/import.cypher`

## Structure

formathgdb/
├── plugin/
│   ├── main.ml        # Plugin OCaml metanejo amélioré
│   └── dune           # Fichier de build
├── neo4j/
│   └── import.cypher  # Requêtes d'import Neo4j
├── examples/
│   ├── _RocqProject
│   └── Rtrigo1.v
└── scripts/
├── build.sh       # Compile et installe le plugin
└── run.sh         # Lance le plugin sur Rtrigo1.v

