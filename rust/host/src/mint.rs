// THE RUST MINT EXECUTOR — the biggest, most consequential piece of
// ADR-0030-in-progress: Rust performs a real era mint itself, against
// real Postgres, using SQL Ruby's own `Translation::RuleCompiler`
// precompiled at build time (`ir.json`'s `translations` key — see
// `crate::storage_shape` and `Exporter.translation_aggregate`'s own
// header for why this crate never needs its own SQL compiler).
//
// A faithful, function-for-function port of `lib/hecksagain/adapters/
// driven/postgres_era/lineage/{provisioning,mint_transaction,
// head_compiler,resumable_backfill}.rb`'s combined behavior — every SQL
// string below is the SAME text those files issue, gathered verbatim,
// not re-derived from a description. Two DELIBERATE, DOCUMENTED
// narrowings from what Ruby does, both because this crate has no
// bluebook parser (that's `rust/parser`, never linked into `rust/
// host` — ADR 0012's own boundary):
//
//   1. Ruby's `hold_first!` leaves era 1 UNNAMED (hash/label NULL)
//      until something later needs to leave it — `ensure_named!` names
//      it lazily by re-parsing its own frozen held_text
//      (`shadow(era[:held_text])`). This crate names era 1 EAGERLY,
//      at hold time — it already has its own shape hash in hand (that's
//      WHY it's holding), so there's no lazy-naming benefit to chase,
//      and it sidesteps ever needing to re-parse held bluebook text.
//   2. If this crate ever finds an EXISTING held era with a NULL hash
//      (one Ruby minted and never named, because nothing has drifted
//      away from it yet), it refuses to mint forward from it — that
//      naming step genuinely needs the parser Ruby has and this crate
//      doesn't. Named explicitly in the refusal, not a silent stall.
//
// Always uses the FULL (non-layered) chain build — `head_compiler.rb`'s
// own `layered_chain_sql` optimization (era N built from era N-1's
// matview instead of the raw ancestor tail) is a performance shortcut
// over an ALREADY-CORRECT slower path (`compile_head!`'s own `full:`
// parameter already supports forcing it), never a distinct code path
// this crate's own correctness depends on. Deferred, not skipped —
// worth adding once a real deployment's era count makes the raw-tail
// scan expensive enough to matter.

use crate::journal::quote_ident;
use crate::storage_shape;
use serde_json::Value;
use sha2::{Digest, Sha256};
use tokio_postgres::GenericClient;

// ───────────────────────── naming ─────────────────────────

fn journal_table(domain: &str) -> String {
    format!("hecks_journal_{}", storage_shape_snake(domain))
}

fn sequence(domain: &str) -> String {
    format!("{}_ordinal", journal_table(domain))
}

fn partition(domain: &str, era: i32) -> String {
    format!("{}_era_{era}", journal_table(domain))
}

fn head_snapshot(storage_name: &str, era: i32) -> String {
    format!("{storage_name}_head_snapshot_{era}")
}

fn matview(storage_name: &str, era: i32, label: &str) -> String {
    format!("{storage_name}_lineage_{era}_{label}")
}

fn head_view(storage_name: &str) -> String {
    format!("{storage_name}_head")
}

// `Naming.snake` — same pure syntactic transform `crate::journal::snake`
// already ports; reused directly rather than duplicated a second time.
fn storage_shape_snake(name: &str) -> String {
    crate::journal::snake(name)
}

fn text_literal(text: &str) -> String {
    format!("'{}'", text.replace('\'', "''"))
}

// ───────────────────────── edge model ─────────────────────────

/// One aggregate's own bind, as `ensure_base!`'s caller (the boot gate)
/// already knows it — `{name, storage_name}`, the SAME pair `ir.json`'s
/// own `lineage.capable_aggregates` carries (`Exporter.lineage`).
#[derive(Debug, Clone)]
pub struct Aggregate {
    pub name: String,
    pub storage_name: String,
}

/// One aggregate's rules within one edge — mirrors `Exporter.
/// translation_aggregate`'s own exported shape, read back out of
/// `ir.json`'s `translations` key.
#[derive(Debug, Clone)]
pub struct EdgeAggregate {
    pub name: String,
    pub was: Option<String>,
    pub has_compute_or_rekey: bool,
    pub compiled_state_expression: String,
    pub compiled_id_expression: Option<String>,
}

/// One translation edge — mirrors `Translation`'s own shape
/// (`Exporter.translation_hash`).
#[derive(Debug, Clone)]
pub struct Edge {
    pub from: String,
    pub to: String,
    pub aggregates: Vec<EdgeAggregate>,
}

impl Edge {
    fn for_aggregate(&self, name: &str) -> Option<&EdgeAggregate> {
        self.aggregates.iter().find(|a| a.name == name)
    }
}

/// `ir.json`'s `translations` array, parsed and filtered to one
/// domain — the SAME JSON `Exporter.translations` writes, read back
/// generically (this crate links no kernel/codegen crate, per ADR
/// 0012 — `serde_json::Value` navigation, not a generated type, matches
/// how `crate::ir` already reads everything else in this sidecar).
pub fn parse_edges(ir: &Value, domain: &str) -> Vec<Edge> {
    ir.get("translations")
        .and_then(Value::as_array)
        .map(|list| {
            list.iter()
                .filter(|edge| edge.get("domain").and_then(Value::as_str) == Some(domain))
                .map(|edge| Edge {
                    from: edge.get("from").and_then(Value::as_str).unwrap_or_default().to_string(),
                    to: edge.get("to").and_then(Value::as_str).unwrap_or_default().to_string(),
                    aggregates: edge
                        .get("aggregates")
                        .and_then(Value::as_array)
                        .map(|aggs| {
                            aggs.iter()
                                .map(|agg| EdgeAggregate {
                                    name: agg.get("name").and_then(Value::as_str).unwrap_or_default().to_string(),
                                    was: agg.get("was").and_then(Value::as_str).map(str::to_string),
                                    has_compute_or_rekey: !agg.get("computes").and_then(Value::as_array).map(Vec::is_empty).unwrap_or(true)
                                        || !agg.get("rekeys").and_then(Value::as_array).map(Vec::is_empty).unwrap_or(true),
                                    compiled_state_expression: agg
                                        .get("compiled_state_expression")
                                        .and_then(Value::as_str)
                                        .unwrap_or("state")
                                        .to_string(),
                                    compiled_id_expression: agg.get("compiled_id_expression").and_then(Value::as_str).map(str::to_string),
                                })
                                .collect()
                        })
                        .unwrap_or_default(),
                })
                .collect()
        })
        .unwrap_or_default()
}

/// The one edge chain from era 1's label to `to_label`, in mint order —
/// `LineageManager#edge_chain`'s own logic, walked over the `edges`
/// list (`ir.json`'s full, unordered set for this domain) rather than
/// a live registry. Refuses (returns Err) exactly where Ruby's own
/// `edge_chain` does: a broken chain — some era's label has no edge
/// leaving it toward the next.
pub fn edge_chain<'a>(edges: &'a [Edge], labels: &[String]) -> anyhow::Result<Vec<&'a Edge>> {
    (0..labels.len() - 1)
        .map(|index| {
            edges
                .iter()
                .find(|edge| edge.from == labels[index] && edge.to == labels[index + 1])
                .ok_or_else(|| {
                    anyhow::anyhow!(
                        "the edge chain is broken at era {} — no translation leads {} to {}; restore bluebook/translations/",
                        index + 1,
                        labels[index],
                        labels[index + 1]
                    )
                })
        })
        .collect()
}

// ───────────────────────── provisioning ─────────────────────────

async fn provisioner<C: GenericClient>(client: &C, journal: &str) -> anyhow::Result<bool> {
    let row = client
        .query_opt(
            "SELECT pg_get_userbyid(relowner) = current_user AS owned FROM pg_class WHERE relname = $1 AND pg_table_is_visible(oid)",
            &[&journal],
        )
        .await?;
    Ok(match row {
        None => true,
        Some(row) => row.get::<_, bool>("owned"),
    })
}

async fn partition_attached<C: GenericClient>(client: &C, partition_name: &str, journal: &str) -> anyhow::Result<bool> {
    let row = client
        .query_opt(
            "SELECT 1 FROM pg_inherits i \
             JOIN pg_class child ON child.oid = i.inhrelid \
             JOIN pg_class parent ON parent.oid = i.inhparent \
             WHERE child.relname = $1 AND parent.relname = $2 \
             AND pg_table_is_visible(child.oid) AND pg_table_is_visible(parent.oid)",
            &[&partition_name, &journal],
        )
        .await?;
    Ok(row.is_some())
}

async fn ensure_partition<C: GenericClient>(client: &C, domain: &str, era: i32) -> anyhow::Result<()> {
    let journal = journal_table(domain);
    let part = partition(domain, era);
    if partition_attached(client, &part, &journal).await? {
        return Ok(());
    }
    client
        .batch_execute(&format!("CREATE TABLE IF NOT EXISTS {} (LIKE {} INCLUDING DEFAULTS)", quote_ident(&part), quote_ident(&journal)))
        .await?;
    client
        .batch_execute(&format!("ALTER TABLE {} ATTACH PARTITION {} FOR VALUES IN ({era})", quote_ident(&journal), quote_ident(&part)))
        .await?;
    Ok(())
}

async fn install_transforms<C: GenericClient>(client: &C) -> anyhow::Result<()> {
    const FUNCTIONS: &[&str] = &[
        r#"CREATE OR REPLACE FUNCTION hecks_tr_extract(state jsonb, path text[], OUT remaining jsonb, OUT value jsonb, OUT present boolean)
LANGUAGE plpgsql IMMUTABLE AS $fn$
DECLARE parent jsonb; leaf text;
BEGIN
  remaining := state;
  present := false;
  leaf := path[array_upper(path, 1)];
  IF array_length(path, 1) = 1 THEN
    IF state ? leaf THEN
      present := true;
      value := state -> leaf;
      remaining := state - leaf;
    END IF;
    RETURN;
  END IF;
  parent := state #> path[1:array_upper(path, 1) - 1];
  IF jsonb_typeof(parent) = 'object' AND parent ? leaf THEN
    present := true;
    value := parent -> leaf;
    parent := parent - leaf;
    IF parent = '{}'::jsonb THEN
      remaining := state - path[1];
    ELSE
      remaining := jsonb_set(state, path[1:array_upper(path, 1) - 1], parent);
    END IF;
  END IF;
END $fn$"#,
        r#"CREATE OR REPLACE FUNCTION hecks_tr_insert(state jsonb, path text[], value jsonb, rule_label text) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE AS $fn$
BEGIN
  IF array_length(path, 1) = 1 THEN
    RETURN state || jsonb_build_object(path[1], value);
  END IF;
  IF state ? path[1] AND jsonb_typeof(state -> path[1]) <> 'object' THEN
    RAISE EXCEPTION 'cannot %: % already holds %, not a value this can nest under — moving into it would discard that value silently. Rename or drop % first.',
      rule_label, path[1], state -> path[1], path[1];
  END IF;
  IF state -> path[1] IS NULL THEN
    state := state || jsonb_build_object(path[1], '{}'::jsonb);
  END IF;
  RETURN jsonb_set(state, path, value);
END $fn$"#,
        r#"CREATE OR REPLACE FUNCTION hecks_tr_rename(state jsonb, old_name text, new_name text) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $fn$
  SELECT CASE WHEN state ? old_name
    THEN (state - old_name) || jsonb_build_object(new_name, state -> old_name)
    ELSE state END
$fn$"#,
        r#"CREATE OR REPLACE FUNCTION hecks_tr_move(state jsonb, from_path text[], to_path text[], rule_label text) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE AS $fn$
DECLARE extracted record;
BEGIN
  SELECT * INTO extracted FROM hecks_tr_extract(state, from_path);
  IF NOT extracted.present THEN RETURN state; END IF;
  RETURN hecks_tr_insert(extracted.remaining, to_path, extracted.value, rule_label);
END $fn$"#,
        r#"CREATE OR REPLACE FUNCTION hecks_tr_convert(state jsonb, from_path text[], to_path text[], pairs jsonb, from_label text, rule_label text) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE AS $fn$
DECLARE extracted record; pair jsonb;
BEGIN
  SELECT * INTO extracted FROM hecks_tr_extract(state, from_path);
  IF NOT extracted.present THEN RETURN state; END IF;
  FOR pair IN SELECT * FROM jsonb_array_elements(pairs) LOOP
    IF pair -> 0 = extracted.value THEN
      RETURN hecks_tr_insert(extracted.remaining, to_path, pair -> 1, rule_label);
    END IF;
  END LOOP;
  RAISE EXCEPTION 'cannot translate %: % has no mapping in its convert''s values: table. Add % => ... to cover it.',
    from_label, extracted.value, extracted.value;
END $fn$"#,
        r#"CREATE OR REPLACE FUNCTION hecks_tr_drop(state jsonb, path text[]) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE AS $fn$
DECLARE extracted record;
BEGIN
  SELECT * INTO extracted FROM hecks_tr_extract(state, path);
  RETURN extracted.remaining;
END $fn$"#,
    ];
    for sql in FUNCTIONS {
        client.batch_execute(sql).await?;
    }
    Ok(())
}

/// `ensure_base!` — provisions everything a domain needs ONCE, ever:
/// the bookkeeping tables, the journal (partitioned, era 1 attached),
/// RLS enablement, the six `hecks_tr_*` functions. Idempotent (every
/// statement is `IF NOT EXISTS`/`ADD COLUMN IF NOT EXISTS`), gated by
/// `provisioner?` the same way Ruby's own is — a non-owner role that
/// merely READS through this crate's generic lineage functions has no
/// business running DDL, and `pg_class`'s own ownership fact is the
/// honest way to tell the two apart.
pub async fn ensure_base<C: GenericClient>(client: &C, domain: &str) -> anyhow::Result<()> {
    let journal = journal_table(domain);
    if !provisioner(client, &journal).await? {
        return Ok(());
    }

    client
        .batch_execute(
            "CREATE TABLE IF NOT EXISTS hecks_eras (\
             domain text NOT NULL, ordinal int NOT NULL, hash text, label text, \
             held_text text NOT NULL, watermark bigint, \
             PRIMARY KEY (domain, ordinal))",
        )
        .await?;
    client.batch_execute("ALTER TABLE hecks_eras ADD COLUMN IF NOT EXISTS held_digest text").await?;
    client.batch_execute("ALTER TABLE hecks_eras ADD COLUMN IF NOT EXISTS held_projection jsonb").await?;
    client.batch_execute("ALTER TABLE hecks_eras ADD COLUMN IF NOT EXISTS canon_form int").await?;
    client
        .batch_execute(
            "CREATE TABLE IF NOT EXISTS hecks_era_texts (\
             domain text NOT NULL, ordinal int NOT NULL, digest text NOT NULL, held_text text NOT NULL, \
             archived_at timestamptz NOT NULL DEFAULT now(), \
             PRIMARY KEY (domain, ordinal, digest))",
        )
        .await?;
    client
        .batch_execute(
            "CREATE TABLE IF NOT EXISTS hecks_approvals (\
             domain text NOT NULL, from_label text NOT NULL, to_label text NOT NULL, \
             edge_digest text NOT NULL, reviewed_ordinal bigint NOT NULL, \
             approved_at timestamptz NOT NULL DEFAULT now())",
        )
        .await?;
    client.batch_execute("CREATE TABLE IF NOT EXISTS hecks_backfill_progress (\
             target text PRIMARY KEY, cursor text, completed boolean NOT NULL DEFAULT false, \
             updated_at timestamptz NOT NULL DEFAULT now())").await?;

    let seq = sequence(domain);
    client.batch_execute(&format!("CREATE SEQUENCE IF NOT EXISTS {}", quote_ident(&seq))).await?;
    client
        .batch_execute(&format!(
            "CREATE TABLE IF NOT EXISTS {} (\
             ordinal bigint NOT NULL DEFAULT nextval('{seq}'), era int NOT NULL, \
             aggregate text NOT NULL, aggregate_id text NOT NULL, \
             operation text NOT NULL DEFAULT 'save', state jsonb, mirrors jsonb) \
             PARTITION BY LIST (era)",
            quote_ident(&journal)
        ))
        .await?;

    ensure_partition(client, domain, 1).await?;

    client.batch_execute(&format!("REVOKE UPDATE, DELETE ON {} FROM PUBLIC", quote_ident(&journal))).await?;

    let current = client
        .query_opt(
            "SELECT relrowsecurity, relforcerowsecurity FROM pg_class WHERE relname = $1 AND pg_table_is_visible(oid)",
            &[&journal],
        )
        .await?;
    let (rowsecurity, forcerowsecurity) = current.map(|row| (row.get::<_, bool>("relrowsecurity"), row.get::<_, bool>("relforcerowsecurity"))).unwrap_or((false, false));
    if !rowsecurity {
        client.batch_execute(&format!("ALTER TABLE {} ENABLE ROW LEVEL SECURITY", quote_ident(&journal))).await?;
    }
    if !forcerowsecurity {
        client.batch_execute(&format!("ALTER TABLE {} FORCE ROW LEVEL SECURITY", quote_ident(&journal))).await?;
    }

    install_transforms(client).await?;
    Ok(())
}

// ───────────────────────── resumable backfill ─────────────────────────

const CHUNK_SIZE: i64 = 5_000;

async fn backfill_progress<C: GenericClient>(client: &C, target: &str) -> anyhow::Result<(Option<String>, bool)> {
    let row = client.query_opt("SELECT cursor, completed FROM hecks_backfill_progress WHERE target = $1", &[&target]).await?;
    Ok(match row {
        None => (None, false),
        Some(row) => (row.get("cursor"), row.get("completed")),
    })
}

async fn upsert_backfill_progress<C: GenericClient>(client: &C, target: &str, cursor: Option<&str>, completed: bool) -> anyhow::Result<()> {
    client
        .execute(
            "INSERT INTO hecks_backfill_progress (target, cursor, completed, updated_at) VALUES ($1, $2, $3, now()) \
             ON CONFLICT (target) DO UPDATE SET cursor = EXCLUDED.cursor, completed = EXCLUDED.completed, updated_at = EXCLUDED.updated_at",
            &[&target, &cursor, &completed],
        )
        .await?;
    Ok(())
}

/// One chunk of `head_snapshot`'s own backfill — SAVEPOINT-nested,
/// since this always runs inside the mint transaction `mint_era`
/// already opened (never standalone; Ruby's own `nested_transaction`
/// branches on whether a transaction is already open, but this crate's
/// only caller always has one, so only the SAVEPOINT branch is needed).
async fn run_backfill_chunk<C: GenericClient>(client: &C, domain: &str, storage_name: &str, era: i32, target: &str) -> anyhow::Result<bool> {
    client.batch_execute("SAVEPOINT hecks_backfill_chunk").await?;
    let result: anyhow::Result<bool> = async {
        client.execute("SELECT pg_advisory_xact_lock(hashtext('hecks_field_cache:' || $1))", &[&target]).await?;
        let (cursor, completed) = backfill_progress(client, target).await?;
        if completed {
            return Ok(true);
        }

        let journal = journal_table(domain);
        let cursor_clause = cursor.as_deref().map(|c| format!(" AND aggregate_id > {}", text_literal(c))).unwrap_or_default();
        let source_sql = format!(
            "SELECT id, ordinal, state FROM (\
               SELECT DISTINCT ON (aggregate_id) aggregate_id AS id, ordinal, operation, state \
               FROM {} WHERE era = {era} AND aggregate = {}{cursor_clause} \
               ORDER BY aggregate_id, ordinal DESC\
             ) latest WHERE operation = 'save' ORDER BY id LIMIT {CHUNK_SIZE}",
            quote_ident(&journal),
            text_literal(storage_name)
        );
        let rows = client.query(&source_sql, &[]).await?;
        if rows.is_empty() {
            upsert_backfill_progress(client, target, cursor.as_deref(), true).await?;
            return Ok(true);
        }

        let quoted_target = quote_ident(target);
        for row in &rows {
            let id: String = row.get("id");
            let ordinal: i64 = row.get("ordinal");
            let state: serde_json::Value = row.get("state");
            client
                .execute(
                    &format!(
                        "INSERT INTO {quoted_target} (id, ordinal, state) VALUES ($1, $2, $3) \
                         ON CONFLICT (id) DO UPDATE SET ordinal = EXCLUDED.ordinal, state = EXCLUDED.state \
                         WHERE {quoted_target}.ordinal < EXCLUDED.ordinal"
                    ),
                    &[&id, &ordinal, &state],
                )
                .await?;
        }
        let done = (rows.len() as i64) < CHUNK_SIZE;
        let last_cursor: String = rows.last().unwrap().get("id");
        upsert_backfill_progress(client, target, Some(&last_cursor), done).await?;
        Ok(done)
    }
    .await;

    match &result {
        Ok(_) => client.batch_execute("RELEASE SAVEPOINT hecks_backfill_chunk").await?,
        Err(_) => client.batch_execute("ROLLBACK TO SAVEPOINT hecks_backfill_chunk").await?,
    }
    result
}

async fn backfill_head_snapshot<C: GenericClient>(client: &C, domain: &str, storage_name: &str, era: i32) -> anyhow::Result<()> {
    let target = head_snapshot(storage_name, era);
    loop {
        if run_backfill_chunk(client, domain, storage_name, era, &target).await? {
            break;
        }
    }
    Ok(())
}

// ───────────────────────── head compilation ─────────────────────────

async fn table_exists<C: GenericClient>(client: &C, name: &str) -> anyhow::Result<bool> {
    let row = client
        .query_opt("SELECT 1 FROM pg_class WHERE relname = $1 AND relkind = 'r' AND pg_table_is_visible(oid)", &[&name])
        .await?;
    Ok(row.is_some())
}

async fn ensure_head_snapshot<C: GenericClient>(client: &C, domain: &str, storage_name: &str, era: i32) -> anyhow::Result<()> {
    let name = head_snapshot(storage_name, era);
    if !table_exists(client, &name).await? {
        client.batch_execute("SAVEPOINT hecks_head_snapshot").await?;
        let result: anyhow::Result<()> = async {
            client.execute("SELECT pg_advisory_xact_lock(hashtext('hecks_head_snapshot:' || $1))", &[&name]).await?;
            if !table_exists(client, &name).await? {
                client
                    .batch_execute(&format!(
                        "CREATE TABLE {} (id text PRIMARY KEY, ordinal bigint NOT NULL, state jsonb NOT NULL)",
                        quote_ident(&name)
                    ))
                    .await?;
            }
            Ok(())
        }
        .await;
        match &result {
            Ok(_) => client.batch_execute("RELEASE SAVEPOINT hecks_head_snapshot").await?,
            Err(_) => client.batch_execute("ROLLBACK TO SAVEPOINT hecks_head_snapshot").await?,
        }
        result?;
    }
    backfill_head_snapshot(client, domain, storage_name, era).await
}

/// Which name/storage_name each aggregate carried at EACH era in the
/// chain, walked backward from the current (era N) name through every
/// edge's own `was:` — `head_compiler.rb`'s own `names_by_era`, pure
/// Ruby there, pure here too (no DB access).
fn names_by_era(current_name: &str, edges: &[&Edge]) -> (Vec<String>, Vec<String>) {
    let mut current = vec![String::new(); edges.len() + 1];
    current[edges.len()] = current_name.to_string();
    for index in (0..edges.len()).rev() {
        let declared = edges[index].for_aggregate(&current[index + 1]);
        current[index] = declared.and_then(|d| d.was.clone()).unwrap_or_else(|| current[index + 1].clone());
    }
    let storage = current.iter().map(|name| storage_shape_snake(name)).collect();
    (current, storage)
}

fn ancestor_tail_sql(domain: &str, era: i32, storage_names: &[String], watermarks: &std::collections::HashMap<i32, Option<i64>>) -> String {
    let journal = quote_ident(&journal_table(domain));
    (1..era)
        .map(|ancestor| {
            let cut = watermarks.get(&(ancestor + 1)).copied().flatten();
            let cut_clause = cut.map(|c| format!(" AND ordinal <= {c}")).unwrap_or_default();
            format!(
                "SELECT ordinal, era, aggregate, aggregate_id, operation, state FROM {journal} \
                 WHERE era = {ancestor} AND aggregate = {}{cut_clause}",
                text_literal(&storage_names[(ancestor - 1) as usize])
            )
        })
        .collect::<Vec<_>>()
        .join(" UNION ALL ")
}

fn latest_per_id(tail: &str) -> String {
    if tail.is_empty() {
        return tail.to_string();
    }
    format!("SELECT DISTINCT ON (aggregate_id) ordinal, era, aggregate, aggregate_id, operation, state FROM ({tail}) tail_entries ORDER BY aggregate_id, ordinal DESC")
}

fn chain_sql(domain: &str, current_name: &str, era: i32, edges: &[&Edge], watermarks: &std::collections::HashMap<i32, Option<i64>>) -> String {
    let (current_names, storage_names) = names_by_era(current_name, edges);
    let tail = latest_per_id(&ancestor_tail_sql(domain, era, &storage_names, watermarks));

    let chain: Vec<String> = edges
        .iter()
        .enumerate()
        .map(|(index, edge)| {
            let declared = edge.for_aggregate(&current_names[index + 1]);
            let expression = declared.map(|d| d.compiled_state_expression.clone()).unwrap_or_else(|| "state".to_string());
            let guard = format!("era <= {} AND operation = 'save'", index + 1);
            let id_column = match declared.filter(|d| d.compiled_id_expression.is_some()) {
                Some(d) => format!(
                    "CASE WHEN {guard} THEN {} ELSE aggregate_id END AS aggregate_id",
                    d.compiled_id_expression.as_deref().unwrap()
                ),
                None => "aggregate_id".to_string(),
            };
            let from = if index == 0 { "tail".to_string() } else { format!("edge_{index}") };
            format!(
                "edge_{} AS (SELECT ordinal, era, {id_column}, operation, CASE WHEN {guard} THEN {expression} ELSE state END AS state FROM {from})",
                index + 1
            )
        })
        .collect();

    format!("WITH tail AS ({tail}),\n{}\nSELECT ordinal, aggregate_id, operation, state FROM edge_{}", chain.join(",\n"), edges.len())
}

/// `compile_head!` — one aggregate's matview + head-snapshot + head
/// view, for one era, over the FULL (never layered) chain.
async fn compile_head<C: GenericClient>(
    client: &C,
    domain: &str,
    aggregate: &Aggregate,
    era: i32,
    label: &str,
    edges: &[&Edge],
    watermarks: &std::collections::HashMap<i32, Option<i64>>,
) -> anyhow::Result<()> {
    let storage_name = &aggregate.storage_name;
    let view = matview(storage_name, era, label);
    let body = chain_sql(domain, &aggregate.name, era, edges, watermarks);

    client.batch_execute(&format!("CREATE MATERIALIZED VIEW {} AS\n{body}", quote_ident(&view))).await?;
    client
        .batch_execute(&format!(
            "CREATE INDEX IF NOT EXISTS {} ON {} (aggregate_id, ordinal DESC)",
            quote_ident(&format!("{view}_reduce_idx")),
            quote_ident(&view)
        ))
        .await?;

    ensure_head_snapshot(client, domain, storage_name, era).await?;

    client.batch_execute(&format!("DROP VIEW IF EXISTS {}", quote_ident(&head_view(storage_name)))).await?;
    client
        .batch_execute(&format!(
            "CREATE VIEW {} AS \
             SELECT id, state FROM (\
               SELECT DISTINCT ON (aggregate_id) aggregate_id AS id, operation, state FROM (\
                 SELECT ordinal, aggregate_id, operation, state FROM {} \
                 UNION ALL \
                 SELECT ordinal, id AS aggregate_id, 'save' AS operation, state FROM {}\
               ) merged ORDER BY aggregate_id, ordinal DESC\
             ) latest WHERE operation = 'save'",
            quote_ident(&head_view(storage_name)),
            quote_ident(&view),
            quote_ident(&head_snapshot(storage_name, era))
        ))
        .await?;
    Ok(())
}

// ───────────────────────── mint transaction ─────────────────────────

/// `hold_first!`, eagerly named (see this file's own header). Fresh
/// domain, era 1, no edge — always safe, never needs the approval gate
/// (a first hold has nothing to migrate FROM). Also does what
/// `EraResolver#check!`'s hold-first PATH does as a separate step
/// right after Ruby's own `hold_first!` — `ensure_first_head!` per
/// aggregate — folded in here since this function's whole job is
/// "make era 1 ready to write into", and a `journal::
/// append_lineage_mutation` call needs `<storage>_head_snapshot_1` to
/// already exist.
pub async fn hold_first<C: GenericClient>(client: &C, domain: &str, held_text: &str, ir: &Value, aggregates: &[Aggregate], role: Option<&str>) -> anyhow::Result<()> {
    ensure_base(client, domain).await?;

    // Own transaction — `ensure_first_head`'s own `ensure_head_snapshot`
    // (and its backfill loop, a no-op for a brand-new era with nothing
    // yet to backfill, but still SAVEPOINT-shaped) needs one open.
    // Ruby's own `hold_first!` doesn't wrap itself this tightly (each
    // statement autocommits on its own), safe here as a strictly
    // SAFER simplification, not a behavior it depends on staying loose.
    client.batch_execute("BEGIN").await?;
    let result = hold_first_body(client, domain, held_text, ir, aggregates, role).await;
    match &result {
        Ok(_) => client.batch_execute("COMMIT").await?,
        Err(_) => {
            let _ = client.batch_execute("ROLLBACK").await;
        }
    }
    result
}

async fn hold_first_body<C: GenericClient>(client: &C, domain: &str, held_text: &str, ir: &Value, aggregates: &[Aggregate], role: Option<&str>) -> anyhow::Result<()> {
    let hash = storage_shape::mint_hash(ir);
    let label = storage_shape::mint_label(ir);
    let digest = format!("{:x}", Sha256::digest(held_text.as_bytes()));

    client
        .execute(
            "INSERT INTO hecks_eras (domain, ordinal, hash, label, held_text, watermark, held_digest, canon_form) \
             VALUES ($1, 1, $2, $3, $4, 0, $5, $6) ON CONFLICT DO NOTHING",
            &[&domain, &hash, &label, &held_text, &digest, &storage_shape::FORM_VERSION],
        )
        .await?;
    archive_text(client, domain, 1, held_text, &digest).await?;
    for aggregate in aggregates {
        ensure_first_head(client, domain, &aggregate.storage_name).await?;
    }
    advance_era(client, domain, 1).await?;
    if let Some(role) = role {
        grant_role(client, domain, role, &[], None).await?;
    }
    Ok(())
}

/// `ensure_first_head!` — era 1's head is a plain view over its own
/// (immediately-created) snapshot table, no chain to compile, no
/// translation possible from nothing.
async fn ensure_first_head<C: GenericClient>(client: &C, domain: &str, storage_name: &str) -> anyhow::Result<()> {
    ensure_head_snapshot(client, domain, storage_name, 1).await?;
    client
        .batch_execute(&format!(
            "CREATE OR REPLACE VIEW {} AS SELECT id, state FROM {}",
            quote_ident(&head_view(storage_name)),
            quote_ident(&head_snapshot(storage_name, 1))
        ))
        .await?;
    Ok(())
}

async fn archive_text<C: GenericClient>(client: &C, domain: &str, ordinal: i32, text: &str, digest: &str) -> anyhow::Result<()> {
    client
        .execute(
            "INSERT INTO hecks_era_texts (domain, ordinal, digest, held_text) VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING",
            &[&domain, &ordinal, &digest, &text],
        )
        .await?;
    Ok(())
}

pub(crate) async fn advance_era<C: GenericClient>(client: &C, domain: &str, ordinal: i32) -> anyhow::Result<()> {
    let journal = quote_ident(&journal_table(domain));
    client.batch_execute(&format!("DROP POLICY IF EXISTS hecks_current_era ON {journal}")).await?;
    client
        .batch_execute(&format!("CREATE POLICY hecks_current_era ON {journal} FOR INSERT TO PUBLIC WITH CHECK (era = {ordinal})"))
        .await?;
    client.batch_execute(&format!("DROP POLICY IF EXISTS hecks_read_all ON {journal}")).await?;
    client.batch_execute(&format!("CREATE POLICY hecks_read_all ON {journal} FOR SELECT TO PUBLIC USING (true)")).await?;
    Ok(())
}

async fn grant_role<C: GenericClient>(client: &C, domain: &str, role: &str, aggregates: &[Aggregate], era: Option<i32>) -> anyhow::Result<()> {
    let journal = journal_table(domain);
    if !provisioner(client, &journal).await? {
        return Ok(());
    }
    let quoted_role = quote_ident(role);
    client.batch_execute(&format!("GRANT INSERT, SELECT ON {} TO {quoted_role}", quote_ident(&journal))).await?;
    client.batch_execute(&format!("GRANT USAGE ON SEQUENCE {} TO {quoted_role}", quote_ident(&sequence(domain)))).await?;
    let Some(era) = era else { return Ok(()) };
    for aggregate in aggregates {
        let storage_name = &aggregate.storage_name;
        client
            .batch_execute(&format!(
                "GRANT SELECT, INSERT, UPDATE, DELETE ON {} TO {quoted_role}",
                quote_ident(&head_snapshot(storage_name, era))
            ))
            .await?;
        let view = head_view(storage_name);
        if table_or_view_exists(client, &view).await? {
            client.batch_execute(&format!("GRANT SELECT ON {} TO {quoted_role}", quote_ident(&view))).await?;
        }
    }
    Ok(())
}

async fn table_or_view_exists<C: GenericClient>(client: &C, name: &str) -> anyhow::Result<bool> {
    let row = client
        .query_opt("SELECT 1 FROM pg_class WHERE relname = $1 AND relkind IN ('v', 'm') AND pg_table_is_visible(oid)", &[&name])
        .await?;
    Ok(row.is_some())
}

/// `mint_era!` — the one transaction that makes era `ordinal` real:
/// advisory lock, idempotency check, watermark capture, the
/// `hecks_eras` row, every aggregate's compiled head, grants, the RLS
/// fence flip. Approval-gate checking (compute/rekey edges) is the
/// CALLER's job (`crate::main`'s boot gate) — this function mints once
/// asked to, the same separation `Minter#mint!` (checks, then calls
/// `Lineage#mint_era!`) already draws in Ruby.
#[allow(clippy::too_many_arguments)]
pub async fn mint_era<C: GenericClient>(
    client: &C,
    domain: &str,
    ordinal: i32,
    hash: &str,
    label: &str,
    held_text: &str,
    aggregates: &[Aggregate],
    edges: &[&Edge],
    role: Option<&str>,
) -> anyhow::Result<()> {
    client.batch_execute("BEGIN").await?;
    let result = mint_era_body(client, domain, ordinal, hash, label, held_text, aggregates, edges, role).await;
    match &result {
        Ok(_) => client.batch_execute("COMMIT").await?,
        Err(_) => {
            let _ = client.batch_execute("ROLLBACK").await;
        }
    }
    result
}

#[allow(clippy::too_many_arguments)]
async fn mint_era_body<C: GenericClient>(
    client: &C,
    domain: &str,
    ordinal: i32,
    hash: &str,
    label: &str,
    held_text: &str,
    aggregates: &[Aggregate],
    edges: &[&Edge],
    role: Option<&str>,
) -> anyhow::Result<()> {
    client.batch_execute("SET LOCAL lock_timeout = '10s'").await?;
    client
        .execute(&format!("SELECT pg_advisory_xact_lock(hashtext('hecks_eras:' || {}))", text_literal(domain)), &[])
        .await?;

    let already_minted = client.query_opt("SELECT 1 FROM hecks_eras WHERE domain = $1 AND ordinal = $2", &[&domain, &ordinal]).await?;
    if already_minted.is_some() {
        anyhow::bail!("era {ordinal} of {domain} is already minted — nothing to do");
    }

    let watermark = crate::journal::last_ordinal(client, domain).await?;
    let digest = format!("{:x}", Sha256::digest(held_text.as_bytes()));
    client
        .execute(
            "INSERT INTO hecks_eras (domain, ordinal, hash, label, held_text, watermark, held_digest, canon_form) \
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
            &[&domain, &ordinal, &hash, &label, &held_text, &watermark, &digest, &storage_shape::FORM_VERSION],
        )
        .await?;
    archive_text(client, domain, ordinal, held_text, &digest).await?;
    ensure_partition(client, domain, ordinal).await?;

    // Every held era's own watermark, for `ancestor_tail_sql`'s cut —
    // includes the row just inserted above (its own watermark is what
    // BOUNDS era `ordinal - 1`'s own tail read, same as every other
    // ancestor).
    let held = crate::journal::held_eras(client, domain).await?;
    let watermarks: std::collections::HashMap<i32, Option<i64>> = held.iter().map(|era| (era.ordinal, era.watermark)).collect();

    for aggregate in aggregates {
        compile_head(client, domain, aggregate, ordinal, label, edges, &watermarks).await?;
    }

    if let Some(role) = role {
        grant_role(client, domain, role, aggregates, Some(ordinal)).await?;
    }
    advance_era(client, domain, ordinal).await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::journal;
    use tokio_postgres::NoTls;

    fn rule(name: &str, was: Option<&str>, expression: &str) -> EdgeAggregate {
        EdgeAggregate { name: name.to_string(), was: was.map(str::to_string), has_compute_or_rekey: false, compiled_state_expression: expression.to_string(), compiled_id_expression: None }
    }

    // A REAL, multi-hop chain: era1 "Pizza" -> era2 rename to "Order"
    // (a rename, was: "Pizza") -> era3 an attribute-only edge on
    // "Order" (no was:). `names_by_era` has to walk this BACKWARD
    // correctly for chain_sql's per-ancestor storage-name filter to
    // read the right journal rows at each era — the one piece of
    // compile_head!'s own logic no single-edge test can exercise.
    #[test]
    fn names_by_era_walks_a_multi_hop_rename_chain_backward_correctly() {
        let edge_1_to_2 = Edge { from: "aaa".to_string(), to: "bbb".to_string(), aggregates: vec![rule("Order", Some("Pizza"), "hecks_tr_rename(state, 'x', 'y')")] };
        let edge_2_to_3 = Edge { from: "bbb".to_string(), to: "ccc".to_string(), aggregates: vec![rule("Order", None, "hecks_tr_rename(state, 'y', 'z')")] };
        let edges: Vec<&Edge> = vec![&edge_1_to_2, &edge_2_to_3];

        let (current, storage) = names_by_era("Order", &edges);

        // era 1 (index 0): the OLD name, "Pizza" -- read from edge_1_to_2's
        // own `was:`. era 2 (index 1) and era 3 (index 2): "Order",
        // unchanged since nothing renamed it again.
        assert_eq!(current, vec!["Pizza".to_string(), "Order".to_string(), "Order".to_string()]);
        assert_eq!(storage, vec!["pizza".to_string(), "order".to_string(), "order".to_string()]);
    }

    #[test]
    fn edge_chain_finds_the_real_path_and_refuses_a_broken_one() {
        let edge = Edge { from: "aaa".to_string(), to: "bbb".to_string(), aggregates: vec![] };
        let edges = vec![edge.clone()];

        let found = edge_chain(&edges, &["aaa".to_string(), "bbb".to_string()]).expect("a real edge connects aaa to bbb");
        assert_eq!(found.len(), 1);
        assert_eq!(found[0].to, "bbb");

        let broken = edge_chain(&edges, &["aaa".to_string(), "zzz".to_string()]);
        assert!(broken.is_err(), "no edge leads aaa to zzz -- must refuse, not silently skip");
    }

    // THE END-TO-END PROOF ADR-0030-in-progress exists for: Rust mints
    // BOTH eras itself, real Postgres, zero Ruby process anywhere in
    // this test — `hold_first` (era 1), real writes through the
    // already-proven generic `journal::append_lineage_mutation`, then
    // `mint_era` (era 2) via a hand-built rename edge, then a real read
    // back through `journal::read_lineage_head_all` proving the
    // translation actually ran. Every prior lineage test in this crate
    // (journal.rs's own) proves Rust reads/writes eras RUBY minted —
    // this is the one that proves Rust needs no Ruby to mint at all.
    #[tokio::test]
    async fn rust_mints_both_eras_itself_writes_and_reads_back_the_translated_data() {
        let db = "rust_host_self_mint_test";
        let owner = "rust_host_self_mint_owner";

        let admin = tokio_postgres::connect("host=localhost dbname=postgres", NoTls).await;
        let (admin_client, admin_connection) = admin.expect("connect to postgres as admin");
        tokio::spawn(async move {
            let _ = admin_connection.await;
        });
        let _ = admin_client.batch_execute(&format!("DROP DATABASE IF EXISTS {db} WITH (FORCE)")).await;
        admin_client.batch_execute(&format!("CREATE DATABASE {db}")).await.expect("create scratch db");
        let _ = admin_client.batch_execute(&format!("DROP ROLE IF EXISTS {owner}")).await;
        admin_client.batch_execute(&format!("CREATE ROLE {owner} LOGIN")).await.expect("create owner role");
        admin_client.batch_execute(&format!("GRANT CONNECT ON DATABASE {db} TO {owner}")).await.expect("grant connect");

        let grant = tokio_postgres::connect(&format!("host=localhost dbname={db}"), NoTls).await;
        let (grant_client, grant_connection) = grant.expect("connect to scratch db as superuser to grant schema rights");
        tokio::spawn(async move {
            let _ = grant_connection.await;
        });
        grant_client.batch_execute(&format!("GRANT USAGE, CREATE ON SCHEMA public TO {owner}")).await.expect("grant schema rights");
        grant_client.batch_execute(&format!("ALTER DATABASE {db} OWNER TO {owner}")).await.expect("make owner the db owner");

        let (client, connection) = tokio_postgres::connect(&format!("host=localhost dbname={db} user={owner}"), NoTls).await.expect("connect as owner");
        tokio::spawn(async move {
            let _ = connection.await;
        });

        let domain = "SelfMint";

        fn shape(attribute_name: &str) -> Value {
            serde_json::json!({
                "name": "SelfMint",
                "aggregates": [{
                    "name": "Widget",
                    "identified_by": ["kind"],
                    "attributes": [
                        {"name": attribute_name, "type": "Money", "list": false},
                        {"name": "kind", "type": "Kind", "list": false}
                    ],
                    "value_objects": [
                        {"name": "Money", "attributes": [{"name": "cents", "type": "Integer", "list": false}]},
                        {"name": "Kind", "attributes": [{"name": "label", "type": "String", "list": false}]}
                    ],
                    "entities": []
                }]
            })
        }
        let v1_ir = shape("cost");
        let v2_ir = shape("amount");

        // ── era 1: Rust mints it, no Ruby, no edge needed ──
        let aggregate = Aggregate { name: "Widget".to_string(), storage_name: "widget".to_string() };
        hold_first(&client, domain, "v1 source text (opaque to this crate)", &v1_ir, &[aggregate.clone()], None).await.expect("hold_first");

        let config = journal::LineageConfig { domain: domain.to_string(), era: 1 };
        journal::append_lineage_mutation(
            &client,
            &config,
            &journal::Mutation { aggregate: "Widget", id: "w1", operation: "save", state: &serde_json::json!({"cost": {"cents": 100}, "kind": {"label": "w1"}}) },
        )
        .await
        .expect("write w1 under era 1");
        journal::append_lineage_mutation(
            &client,
            &config,
            &journal::Mutation { aggregate: "Widget", id: "w2", operation: "save", state: &serde_json::json!({"cost": {"cents": 200}, "kind": {"label": "w2"}}) },
        )
        .await
        .expect("write w2 under era 1");

        // ── era 2: Rust mints it too, via a hand-built rename edge — the
        // SAME shape Exporter.translation_aggregate would export, just
        // constructed directly here rather than read from a real ir.json,
        // since this test's whole point is proving the MINT MECHANICS,
        // not the build-time export pipeline (that's storage_shape.rs's
        // own, separately-proven job). ──
        let from_label = storage_shape::mint_label(&v1_ir);
        let to_label = storage_shape::mint_label(&v2_ir);
        let edge = Edge {
            from: from_label,
            to: to_label.clone(),
            aggregates: vec![EdgeAggregate {
                name: "Widget".to_string(),
                was: None,
                has_compute_or_rekey: false,
                compiled_state_expression: "hecks_tr_rename(state, 'cost', 'amount')".to_string(),
                compiled_id_expression: None,
            }],
        };

        mint_era(&client, domain, 2, &storage_shape::mint_hash(&v2_ir), &to_label, "v2 source text", &[aggregate], &[&edge], None)
            .await
            .expect("mint_era");

        // ── read back through the SAME generic function real deployment
        // traffic uses — proving the whole chain, not just that SQL ran ──
        let mut rows = journal::read_lineage_head_all(&client, "widget").await.expect("read_lineage_head_all");
        rows.sort_by(|a, b| a.0.cmp(&b.0));
        assert_eq!(
            rows,
            vec![
                ("w1".to_string(), serde_json::json!({"amount": {"cents": 100}, "kind": {"label": "w1"}})),
                ("w2".to_string(), serde_json::json!({"amount": {"cents": 200}, "kind": {"label": "w2"}})),
            ]
        );
    }
}
