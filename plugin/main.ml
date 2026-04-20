module Lsp = Fleche_lsp
open Fleche

(** TODO:

    - new edge "defined_in" object file
    - new edge "uses" for Require
    - new attributes "uses" "in_body" / "in_type" *)

(* Put these in an utility function for plugins *)
(* Duplicated with rq_document *)
let _of_execution ~io ~what (v : (_, _) Coq.Protect.E.t) =
  match v with
  | { r; feedback = _ } -> (
    match r with
    | Coq.Protect.R.Completed (Ok goals) -> goals
    | Coq.Protect.R.Completed (Error (Anomaly { msg; _ }))
    | Coq.Protect.R.Completed (Error (User { msg; _ })) ->
      let lvl = Io.Level.Error in
      Io.Report.msg ~io ~lvl "error when retrieving %s: %a" what Pp.pp_with msg;
      None
    | Coq.Protect.R.Interrupted -> None)

module Kind = struct
  type t =
    | Notation
    | Definition
    | Theorem
    | Other of string
    | Unknown
    | Lemma
  [@@deriving to_yojson]

  let to_string = function
    | Notation -> "Notation"
    | Definition -> "Definition"
    | Theorem -> "Theorem"
    | Other s -> "Other(" ^ s ^ ")"
    | Unknown -> "Unknown"
    | Lemma -> "Lemma"

  let of_rocq_logic_kind = function
    | Decls.Theorem -> Theorem
    | Lemma -> Lemma
    | Fact -> Other "Fact"
    | Remark -> Other "Remark"
    | Property -> Other "Property"
    | Proposition -> Other "Proposition"
    | Corollary -> Other "Corollary"

  let of_rocq_decl_kind = function
    | Decls.Definition -> Definition
    | Coercion -> Other "Coercion"
    | SubClass -> Other "SubClass"
    | CanonicalStructure -> Other "CanonicalStructure"
    | Example -> Other "Example"
    | Fixpoint -> Other "Fixpoint"
    | CoFixpoint -> Other "CoFixpoint"
    | Scheme -> Other "Scheme"
    | StructureComponent -> Other "StructureComponent"
    | IdentityCoercion -> Other "IdentityCoercion"
    | Instance -> Other "Instance"
    | Method -> Other "Method"
    | Let -> Other "Let"
    | LetContext -> Other "LetContext"

  (* For Lang.Ast.Info.t *)
  let _of_detail = function
    | Some "Notation" -> Notation
    | Some "Definition" -> Definition
    | Some "Lemma" -> Lemma
    | Some "Theorem" -> Theorem
    | Some s -> Other s
    | None -> Unknown
end

(* Phase 1: extract refs from the statement (type) of a theorem *)
let rec analyze_constr_expr_acc () depl (e : Constrexpr.constr_expr) :
    string list =
  let open Constrexpr in
  (match e.v with
  | CRef (qid, _) -> [ Libnames.string_of_qualid qid ]
  | CFix (_, _) -> []
  | CCoFix (_, _) -> []
  | CProdN (_, _) -> []
  | CLambdaN (_, _) -> []
  | CLetIn (_, _, _, _) -> []
  | CAppExpl (_, _) -> []
  | CApp (_, _) -> []
  | CProj (_, _, _, _) -> []
  | CRecord _ -> []
  | CCases (_, _, _, _) -> []
  | CLetTuple (_, _, _, _) -> []
  | CIf (_, _, _, _) -> []
  | CHole _ -> []
  | CGenarg _ -> []
  | CGenargGlob _ -> []
  | CPatVar _ -> []
  | CEvar (_, _) -> []
  | CSort _ -> []
  | CCast (_, _, _) -> []
  | CNotation (_, (_, ntn_key), (l, ll, _, _)) ->
    let f =
      Constrexpr_ops.fold_constr_expr_with_binders
        (fun _ () -> ())
        analyze_constr_expr_acc () []
    in
    [ ntn_key ] @ List.concat_map f (l @ List.flatten ll)
  | CGeneralization (_, _) -> []
  | CPrim _ -> []
  | CDelimiters (_, _, _) -> []
  | CArray (_, _, _, _) -> [])
  |> List.append depl

let analyze_constr_expr (e : Constrexpr.constr_expr) =
  Constrexpr_ops.fold_constr_expr_with_binders
    (fun _ () -> ())
    analyze_constr_expr_acc () [] e

let analyze_definition_expr de =
  let open Vernacexpr in
  let ty =
    match de with
    | ProveBody (_bl, e) -> e
    | DefineBody (_bl, _rr, e, _) -> e
  in
  analyze_constr_expr ty

let name_to_string = function
  | Names.Anonymous -> None
  | Names.Name id -> Some (Names.Id.to_string id)

(* Phase 1: extract name, kind and statement deps from a vernac node *)
let analyze (CAst.{ loc = _; v } : Vernacexpr.vernac_control) : _ option =
  let open Vernacexpr in
  let { control = _; attrs = _; expr } = v in
  match expr with
  | VernacSynterp e -> (
    match e with
    | VernacLoad (_, _) -> None
    | VernacReservedNotation (_, _) -> None
    | VernacNotation (_, _) -> None
    | VernacDeclareCustomEntry _ -> None
    | VernacBeginSection _ -> None
    | VernacEndSegment _ -> None
    | VernacRequire (_, _, _) -> None
    | VernacImport (_, _) -> None
    | VernacDeclareModule (_, _, _, _) -> None
    | VernacDefineModule (_, _, _, _, _) -> None
    | VernacDeclareModuleType (_, _, _, _) -> None
    | VernacInclude _ -> None
    | VernacDeclareMLModule _ -> None
    | VernacChdir _ -> None
    | VernacExtraDependency (_, _, _) -> None
    | VernacSetOption (_, _, _) -> None
    | VernacProofMode _ -> None
    | VernacExtend (_, _) -> None)
  | VernacSynPure e -> (
    match e with
    | VernacOpenCloseScope (_, _) -> None
    | VernacDeclareScope _ -> None
    | VernacDelimiters (_, _) -> None
    | VernacBindScope (_, _) -> None
    | VernacEnableNotation (_, _, _, _, _) -> None
    | VernacDefinition ((_, kind), (name, _), expr) ->
      let name = name_to_string name.v in
      let kind = Kind.of_rocq_decl_kind kind in
      let deps = analyze_definition_expr expr in
      Some (name, kind, deps)
    | VernacStartTheoremProof (_, []) -> None
    | VernacStartTheoremProof (kind, ((name, _), (_, ty)) :: _) ->
      let name = Some (Names.Id.to_string name.v) in
      let kind = Kind.of_rocq_logic_kind kind in
      let deps = analyze_constr_expr ty in
      Some (name, kind, deps)
    | VernacEndProof _ -> None
    | VernacExactProof _ -> None
    | VernacAssumption (_, _, _) -> None
    | VernacSymbol _ -> None
    | VernacInductive (_, _) -> None
    | VernacFixpoint (_, _) -> None
    | VernacCoFixpoint (_, _) -> None
    | VernacScheme _ -> None
    | VernacSchemeEquality (_, _) -> None
    | VernacCombinedScheme (_, _) -> None
    | VernacUniverse _ -> None
    | VernacSort _ -> None
    | VernacConstraint _ -> None
    | VernacAddRewRule (_, _) -> None
    | VernacCanonical _ -> None
    | VernacCoercion (_, _) -> None
    | VernacIdentityCoercion (_, _, _) -> None
    | VernacNameSectionHypSet (_, _) -> None
    | VernacInstance (_, _, _, _, _) -> None
    | VernacDeclareInstance (_, _, _, _) -> None
    | VernacContext _ -> None
    | VernacExistingInstance _ -> None
    | VernacExistingClass _ -> None
    | VernacResetName _ -> None
    | VernacResetInitial -> None
    | VernacBack _ -> None
    | VernacCreateHintDb (_, _) -> None
    | VernacRemoveHints (_, _) -> None
    | VernacHints (_, _) -> None
    | VernacAbbreviation (_, _, _, _) -> None
    | VernacArguments (_, _, _, _) -> None
    | VernacReserve _ -> None
    | VernacGeneralizable _ -> None
    | VernacSetOpacity (_, _) -> None
    | VernacSetStrategy _ -> None
    | VernacMemOption (_, _) -> None
    | VernacPrintOption _ -> None
    | VernacCheckMayEval (_, _, _) -> None
    | VernacGlobalCheck _ -> None
    | VernacDeclareReduction (_, _) -> None
    | VernacPrint _ -> None
    | VernacSearch (_, _, _) -> None
    | VernacLocate _ -> None
    | VernacRegister (_, _) -> None
    | VernacPrimitive (_, _, _) -> None
    | VernacComments _ -> None
    | VernacAttributes _ -> None
    | VernacAbort -> None
    | VernacAbortAll -> None
    | VernacRestart -> None
    | VernacUndo _ -> None
    | VernacUndoTo _ -> None
    | VernacFocus _ -> None
    | VernacUnfocus -> None
    | VernacUnfocused -> None
    | VernacBullet _ -> None
    | VernacSubproof _ -> None
    | VernacEndSubproof -> None
    | VernacShow _ -> None
    | VernacCheckGuard -> None
    | VernacValidateProof -> None
    | VernacProof (_, _) -> None
    | VernacAddOption (_, _) -> None
    | VernacRemoveOption (_, _) -> None)

let analyze (node : Doc.Node.t) =
  match node.ast with
  | Some { v; _ } -> analyze (Coq.Ast.to_coq v)
  | _ -> None

(* We output a record for each object we can recognize in the document,
   in linear order. *)
module Node_info = struct
  (* Just to bring the serializers in scope *)
  module Lang = Lsp.JLang
  module Coq = Lsp.JCoq

  type t =
  { uri : Lang.LUri.File.t
  ; range : Lang.Range.t
  ; kind : Kind.t
  ; name : string
  ; raw : string
  ; deps_statement : string list
  ; deps_proof : string list
  }
  [@@deriving to_yojson]

  let of_node ~io:_ ~token:_ ~uri ~(contents : Contents.t) (node : Doc.Node.t) =
    match analyze node with
    | None -> None
    | Some (name, kind, deps) ->
      let range = node.range in
      let name =
        match name with
        | Some name -> name
        | None -> "anonymous"
      in
      let deps_statement = List.sort_uniq String.compare deps in
      let raw = Fleche.Contents.extract_raw ~contents ~range in
      Some { uri; range; kind; name; raw; deps_statement; deps_proof = [] }
end

module GDB = struct
  module Id = struct
    type t = string [@@deriving to_yojson]
  end

  module Attr = struct
    type t = string list [@@deriving to_yojson]
  end

  module Node = struct
  type t =
    { id : Id.t
    ; kind : string
    ; attrs : Attr.t
    }
  [@@deriving to_yojson]
end

  module Edge = struct
    type t =
      { from : Id.t
      ; to_ : Id.t [@key "to"]
      ; attrs : Attr.t
      ; label : string
      }
    [@@deriving to_yojson]
  end

  module Labels = struct
    type t = (Id.t * string) list

    let to_yojson l =
      let f (id, label) = (id, `String label) in
      let fields = List.map f l in
      `Assoc fields
  end
end

module Meta = struct
  open GDB

  type t = Node.t list * Edge.t list * Labels.t

  let rec to_graph_db (nl, el, ll) (l : Node_info.t list) : t =
    match l with
    | [] -> (List.rev nl, List.rev el, List.rev ll)
    | n :: l ->
      let { Node_info.uri = _; range = _; kind; name; raw = _
        ; deps_statement; deps_proof } = n in
      let attrs = [] in
      let nn = { Node.id = name; kind = Kind.to_string kind; attrs } in
      let ne_statement = List.map
        (fun to_ -> { Edge.from = name; to_; attrs; label = "USES_STATEMENT" })
        deps_statement in
      let ne_proof = List.map
        (fun to_ -> { Edge.from = name; to_; attrs; label = "USES_PROOF" })
        deps_proof in
      let ne = ne_statement @ ne_proof in
      let nll = (name, Kind.to_string kind) in
      to_graph_db (nn :: nl, ne @ el, nll :: ll) l

  let to_graph_db (l : Node_info.t list) : t = to_graph_db ([], [], []) l

  (* Create nodes for orphan deps in the graph *)
  let to_graph_db l =
    let nl, el, ll = to_graph_db l in
    (nl, el, ll)

  let pp fmt (nl, el, l) =
    let nl = `List (List.map Node.to_yojson nl) in
    let el = `List (List.map Edge.to_yojson el) in
    let l = Labels.to_yojson l in
    let obj = `Assoc [ ("edges", el); ("nodes", nl); ("node_labels", l) ] in
    let obj = `Assoc [ ("graph", obj) ] in
    Format.fprintf fmt "@[%a@]@\n" (Yojson.Safe.pretty_print ~std:true) obj
end

(* ===== Phase 2: extract deps from the proof body via the AST ===== *)

(* Basic tactics and short names to filter out as noise *)
let is_noise s =
  let noise =
    [ "left"; "right"; "assumption"; "reflexivity"; "trivial"
    ; "auto"; "tauto"; "simpl"; "ring"; "field"; "omega"; "lia"; "lra" ]
  in
  List.mem s noise || String.length s <= 2

(* Recursively extract all Ser_Qualid references from a JSON AST node.
   Ser_Qualid is the internal representation of named references in the
   Rocq AST, e.g. "apply cos_increasing_1" produces a Ser_Qualid for
   cos_increasing_1. *)
let rec extract_qualids_json (j : Yojson.Safe.t) : string list =
  match j with
  | `List [`String "Ser_Qualid"; dirpath; label] ->
    let parts =
      match dirpath with
      | `List [`String "DirPath"; `List ids] ->
        List.filter_map
          (function
            | `List [`String "Id"; `String s] -> Some s
            | _ -> None)
          ids
      | _ -> []
    in
    let label_str =
      match label with
      | `List [`String "Id"; `String s] -> [ s ]
      | _ -> []
    in
    [ String.concat "." (parts @ label_str) ]
  | `List items -> List.concat_map extract_qualids_json items
  | `Assoc fields ->
    List.concat_map (fun (_, v) -> extract_qualids_json v) fields
  | _ -> []

(* Second pass over doc nodes: collect proof body deps for each theorem.
   We track the current theorem between VernacStartTheoremProof and
   VernacEndProof, and extract named references from every tactic node
   in between by serializing the AST to JSON and scanning for Ser_Qualid. *)
let extract_body_deps (nodes : Doc.Node.t list)
    : (string, string list) Hashtbl.t =
  let current = ref None in
  let result : (string, string list) Hashtbl.t = Hashtbl.create 64 in
  List.iter
    (fun (node : Doc.Node.t) ->
      match node.ast with
      | None -> ()
      | Some { v; _ } ->
        let coq_ast = Coq.Ast.to_coq v in
        (match coq_ast.CAst.v with
        | { Vernacexpr.control = _; attrs = _
          ; expr =
              VernacSynPure
                (VernacStartTheoremProof (_, ((name, _), _) :: _)) } ->
          let name_str = Names.Id.to_string name.CAst.v in
          current := Some name_str;
          if not (Hashtbl.mem result name_str) then
            Hashtbl.replace result name_str []
        | { Vernacexpr.control = _; attrs = _
          ; expr = VernacSynPure (VernacDefinition (_, (name, _), _)) } ->
          let name_str =
            match name_to_string name.CAst.v with
            | Some s -> s
            | None -> "anonymous"
          in
          current := Some name_str;
          if not (Hashtbl.mem result name_str) then
            Hashtbl.replace result name_str []
        | { expr = VernacSynPure (VernacEndProof _); _ } ->
          current := None
        | _ ->
          (match !current with
          | None -> ()
          | Some thm ->
            let json = Lsp.JCoq.Ast.to_yojson v in
            let refs = extract_qualids_json json in
            let filtered = List.filter (fun s -> not (is_noise s)) refs in
            let existing =
              try Hashtbl.find result thm with Not_found -> []
            in
            Hashtbl.replace result thm (existing @ filtered))))
    nodes;
  result

let dump_meta ~io ~token ~out_file ~(doc : Doc.t) =
  let uri, contents = (doc.uri, doc.contents) in
  (* Phase 1: extract name, kind and statement deps from each node *)
  let ll =
    List.filter_map (Node_info.of_node ~io ~token ~uri ~contents) doc.nodes
  in
  (* Phase 2: enrich with proof body deps extracted from tactic AST nodes *)
  let body_deps_tbl = extract_body_deps doc.nodes in
  let ll =
    List.map
      (fun (ni : Node_info.t) ->
        match Hashtbl.find_opt body_deps_tbl ni.name with
        | None -> ni
        | Some new_deps ->
          let deps_proof =
            List.sort_uniq String.compare (ni.deps_proof @ new_deps)
          in
          { ni with deps_proof })
      ll
  in
  let ll = Meta.to_graph_db ll in
  let f fmt meta = Meta.pp fmt meta in
  Coq.Compat.format_to_file ~file:out_file ~f ll

let dump_meta ~io ~token ~(doc : Doc.t) =
  let uri = doc.uri in
  let uri_str = Lang.LUri.File.to_string_uri uri in
  let lvl = Io.Level.Info in
  Io.Report.msg ~io ~lvl "[metanejo plugin] dumping metadata for %s ..." uri_str;
  let out_file_j = Lang.LUri.File.to_string_file uri ^ ".meta.json" in
  let () = dump_meta ~io ~token ~out_file:out_file_j ~doc in
  Io.Report.msg ~io ~lvl
    "[metanejo plugin] dumping metadata for %s was completed!" uri_str;
  ()

let main () = Theory.Register.Completed.add dump_meta
let () = main ()