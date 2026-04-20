// ForMathGDB - Import dans Neo4j
// Prerequis : placer le .meta.json dans le dossier import de Neo4j
// et avoir APOC installe avec apoc.import.file.enabled=true

// 0. Nettoyer la base
MATCH (n) DETACH DELETE n;

// 1. Creer les noeuds avec leur label
CALL apoc.load.json("file:///Rtrigo1.v.meta.json")
YIELD value
UNWIND value.graph.nodes AS node
CALL apoc.create.node([node.kind], {id: node.id, kind: node.kind}) YIELD node AS n
RETURN count(n)

// 3. Creer les relations
CALL apoc.load.json("file:///Rtrigo1.v.meta.json")
YIELD value
UNWIND value.graph.edges AS edge
MATCH (a {id: edge.from})
MATCH (b {id: edge.to})
CALL apoc.create.relationship(a, edge.label, {}, b) YIELD rel
RETURN count(rel)
