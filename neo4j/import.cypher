// ForMathGDB - Import dans Neo4j
// Prerequis : placer le .meta.json dans le dossier import de Neo4j
// et avoir APOC installe avec apoc.import.file.enabled=true

// 0. Nettoyer la base
MATCH (n) DETACH DELETE n;

// 1. Creer les noeuds
CALL apoc.load.json("file:///Rtrigo1.v.meta.json")
YIELD value
UNWIND value.graph.nodes AS node
MERGE (n:Concept {id: node.id});

// 2. Ajouter le type (Lemma, Theorem, Definition...)
CALL apoc.load.json("file:///Rtrigo1.v.meta.json")
YIELD value
UNWIND keys(value.graph.node_labels) AS key
MATCH (n:Concept {id: key})
SET n.kind = value.graph.node_labels[key];

// 3. Creer les relations
CALL apoc.load.json("file:///Rtrigo1.v.meta.json")
YIELD value
UNWIND value.graph.edges AS edge
MATCH (a:Concept {id: edge.from})
MATCH (b:Concept {id: edge.to})
MERGE (a)-[:USES]->(b);
