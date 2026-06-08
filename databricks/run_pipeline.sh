#!/usr/bin/env bash

set -uo pipefail

TARGET="dev"
PROFILE=""
JOB_KEY=""
BUNDLE_FILE=""
SKIP_DEPLOY="false"
STRICT_VALIDATE="true"
NO_WAIT="false"
INTEGRATION_TEST="true"

VALIDATION_STATUS="failed"
DEPLOY_STATUS="skipped"
RUN_ID="not found"
RUN_STATE="not found"
FAILURE_CLASS="UNKNOWN"
NOTEBOOK_OUTPUT="not available"
PARAM_VALIDATION_STATUS="skipped"
PARAM_VALIDATION_MISSING="none"
PARAM_VALIDATION_EXTRA="none"
PARAM_VALIDATION_INCORRECT="none"
NEXT_ACTION="none"

usage() {
  cat <<'EOF'
Usage:
  scripts/databricks/run_pipeline.sh --job <job_key> [options]

Options:
  --job <job_key>         Bundle job key to run (required)
  --target <target>       Bundle target (default: dev)
  --profile <profile>     Databricks CLI profile (default: same as target)
  --bundle-file <path>    Bundle file used for parameter validation (default: databricks.yml)
  --skip-deploy           Skip bundle deploy step
  --no-strict             Disable strict validation
  --no-wait               Do not wait for run completion
  --integration-test      Validate task parameters after run completion (default)
  --skip-integration-test Skip task parameter validation
  -h, --help              Show this help

Examples:
  scripts/databricks/run_pipeline.sh --job ruhaan_repo
  scripts/databricks/run_pipeline.sh --job ruhaan_repo_regression_tests --target stg --profile stg
  scripts/databricks/run_pipeline.sh --job ruhaan_repo --bundle-file configs/dab.yml
  scripts/databricks/run_pipeline.sh --job ruhaan_repo --integration-test
  scripts/databricks/run_pipeline.sh --job ruhaan_repo --skip-integration-test
EOF
}

print_summary() {
  echo "========================================"
  echo "Target:           $TARGET"
  echo "Profile:          $PROFILE"
  echo "Job:              $JOB_KEY"
  echo "Validation:       $VALIDATION_STATUS"
  echo "Deploy:           $DEPLOY_STATUS"
  echo "Run ID:           $RUN_ID"
  echo "Run State:        $RUN_STATE"
  echo "Failure Class:    $FAILURE_CLASS"
  echo "Notebook Output:  $NOTEBOOK_OUTPUT"
  echo "Parameter Validation: $PARAM_VALIDATION_STATUS"
  echo "Missing Parameters:   $PARAM_VALIDATION_MISSING"
  echo "Extra Parameters:     $PARAM_VALIDATION_EXTRA"
  echo "Incorrect Values:     $PARAM_VALIDATION_INCORRECT"
  echo "Next Action:      $NEXT_ACTION"
  echo "========================================"
}

run_capture() {
  local __result_var="$1"
  shift
  local output status
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
  printf -v "$__result_var" '%s' "$output"
  return "$status"
}

run_capture_stream() {
  local __result_var="$1"
  shift
  local output status
  local tmp_file

  tmp_file="$(mktemp)"
  set +e
  "$@" 2>&1 | tee "$tmp_file"
  status=${PIPESTATUS[0]}
  set -e
  output="$(cat "$tmp_file")"
  rm -f "$tmp_file"

  printf -v "$__result_var" '%s' "$output"
  return "$status"
}

classify_error() {
  local text="$1"
  if [[ "$text" =~ [Uu]nauthori[sz]ed ]] \
    || [[ "$text" =~ [Ii]nvalid[[:space:]]+(access[[:space:]]+token|token) ]] \
    || [[ "$text" =~ [Pp]rofile[[:space:]]+.*(not[[:space:]]+found|missing) ]] \
    || [[ "$text" =~ [Pp]ermission[[:space:]]+denied ]]; then
    echo "AUTH_OR_PERMISSIONS"
  elif [[ "$text" =~ [Cc]luster ]] \
    || [[ "$text" =~ [Ss]pot[[:space:]]+instance ]] \
    || [[ "$text" =~ [Nn]ode[[:space:]]+failure ]] \
    || [[ "$text" =~ [Dd]river[[:space:]]+.*died ]] \
    || [[ "$text" =~ CLOUD_PROVIDER ]]; then
    echo "INFRA_OR_CLUSTER"
  elif [[ "$text" =~ [Tt]ransient ]] \
    || [[ "$text" =~ [Rr]ate[[:space:]]+limit ]] \
    || [[ "$text" =~ 429 ]] \
    || [[ "$text" =~ [Tt]imeout ]] \
    || [[ "$text" =~ [Rr]un[[:space:]]+[0-9]+[[:space:]]+does[[:space:]]+not[[:space:]]+exist ]] \
    || [[ "$text" =~ [Tt]emporarily[[:space:]]+unavailable ]]; then
    echo "TRANSIENT_PLATFORM"
  elif [[ "$text" =~ [Ss]chema ]] \
    || [[ "$text" =~ [Tt]able[[:space:]]+not[[:space:]]+found ]] \
    || [[ "$text" =~ [Aa]nalysi[sz]Exception ]] \
    || [[ "$text" =~ [Dd]elta ]]; then
    echo "DATA_OR_SCHEMA"
  elif [[ "$text" =~ [Bb]undle ]] \
    || [[ "$text" =~ [Cc]onfig ]] \
    || [[ "$text" =~ spark_version ]] \
    || [[ "$text" =~ [Vv]alidation[[:space:]]+failed[[:space:]]+for ]] \
    || [[ "$text" =~ [Vv]alidat ]]; then
    echo "CONFIG_OR_BUNDLE"
  elif [[ "$text" =~ [Ee]xception ]] \
    || [[ "$text" =~ [Tt]raceback ]] \
    || [[ "$text" =~ [Ee]rror[[:space:]]+in[[:space:]]+notebook ]]; then
    echo "CODE_OR_NOTEBOOK"
  else
    echo "UNKNOWN"
  fi
}

expected_params_for_task() {
  local job_key="$1"
  local task_key="$2"

  if ! command -v python3 >/dev/null 2>&1; then
    echo ""
    return 0
  fi

  python3 - "$BUNDLE_FILE" "$job_key" "$task_key" <<'PYEOF'
import sys, re

bundle_file, job_key, task_key = sys.argv[1], sys.argv[2], sys.argv[3]

def keys_for_task(task):
  keys = []
  notebook = task.get("notebook_task", {})
  if isinstance(notebook.get("base_parameters"), dict):
    keys.extend(list(notebook["base_parameters"].keys()))

  wheel = task.get("python_wheel_task", {})
  if isinstance(wheel.get("named_parameters"), dict):
    keys.extend(list(wheel["named_parameters"].keys()))
  if isinstance(wheel.get("parameters"), list):
    keys.extend([f"__arg{idx+1}" for idx, _ in enumerate(wheel["parameters"])])

  spark_python = task.get("spark_python_task", {})
  if isinstance(spark_python.get("parameters"), list):
    keys.extend([f"__arg{idx+1}" for idx, _ in enumerate(spark_python["parameters"])])
  elif isinstance(spark_python.get("parameters"), dict):
    keys.extend(list(spark_python["parameters"].keys()))

  return keys

try:
  with open(bundle_file) as f:
        raw = f.read()
except FileNotFoundError:
    sys.exit(0)

try:
    import yaml
    # Replace ${...} interpolations with a safe placeholder before parsing
    content = re.sub(r'\$\{[^}]+\}', '"__placeholder__"', raw)
    d = yaml.safe_load(content)
    jobs = d.get("resources", {}).get("jobs", {})
    job = jobs.get(job_key, {})
    tasks = job.get("tasks", [])
    task = next((t for t in tasks if t.get("task_key") == task_key), None)
    if task:
      print(" ".join(keys_for_task(task)))
except Exception:
    pass
PYEOF
}

validate_task_parameters() {
  local run_meta_json="$1"
  local task_key expected_str expected_sorted actual_sorted
  local expected_file actual_file
  local missing extra
  local overall_failed="false"
  local missing_report=""
  local extra_report=""
  local compared_tasks=0
  local discovered_tasks=0

  if ! command -v python3 >/dev/null 2>&1; then
    PARAM_VALIDATION_STATUS="failed"
    PARAM_VALIDATION_INCORRECT="not checked"
    NEXT_ACTION="Install python3 to enable integration parameter validation."
    return 1
  fi

  if ! python3 -c 'import yaml' >/dev/null 2>&1; then
    PARAM_VALIDATION_STATUS="failed"
    PARAM_VALIDATION_INCORRECT="not checked"
    NEXT_ACTION="Install PyYAML in the runtime used by scripts/databricks/run_pipeline.sh."
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    PARAM_VALIDATION_STATUS="failed"
    PARAM_VALIDATION_INCORRECT="not checked (jq not installed)"
    NEXT_ACTION="Install jq to enable --integration-test parameter validation."
    return 1
  fi

  discovered_tasks="$(echo "$run_meta_json" | jq -r '.tasks | length // 0')"

  while IFS= read -r task_key; do
    [[ -z "$task_key" ]] && continue
    expected_str="$(expected_params_for_task "$JOB_KEY" "$task_key")"
    if [[ -z "$expected_str" ]]; then
      continue
    fi

    expected_file="$(mktemp)"
    actual_file="$(mktemp)"

    printf '%s\n' $expected_str | LC_ALL=C sort -u > "$expected_file"
    echo "$run_meta_json" | jq -r --arg k "$task_key" '
      .tasks[]
      | select(.task_key == $k)
      | (
          (.notebook_task.base_parameters // {} | keys[]?),
          (.python_wheel_task.named_parameters // {} | keys[]?),
          ((.python_wheel_task.parameters // []) | to_entries[]? | "__arg\(.key + 1)"),
          ((.spark_python_task.parameters // []) | if type == "array" then to_entries[]? | "__arg\(.key + 1)" elif type == "object" then keys[] else empty end)
        )
    ' | LC_ALL=C sort -u > "$actual_file"

    compared_tasks=$((compared_tasks + 1))

    missing="$(comm -23 "$expected_file" "$actual_file" | tr '\n' ',' | sed 's/,$//')"
    extra="$(comm -13 "$expected_file" "$actual_file" | tr '\n' ',' | sed 's/,$//')"

    if [[ -n "$missing" ]]; then
      overall_failed="true"
      if [[ -n "$missing_report" ]]; then
        missing_report+="; "
      fi
      missing_report+="$task_key:[$missing]"
    fi

    if [[ -n "$extra" ]]; then
      overall_failed="true"
      if [[ -n "$extra_report" ]]; then
        extra_report+="; "
      fi
      extra_report+="$task_key:[$extra]"
    fi

    rm -f "$expected_file" "$actual_file"
  done < <(echo "$run_meta_json" | jq -r '.tasks[].task_key // empty')

  if [[ "$discovered_tasks" -gt 0 && "$compared_tasks" -eq 0 ]]; then
    PARAM_VALIDATION_STATUS="failed"
    PARAM_VALIDATION_MISSING="none"
    PARAM_VALIDATION_EXTRA="none"
    PARAM_VALIDATION_INCORRECT="not checked"
    NEXT_ACTION="Could not derive expected parameters from $BUNDLE_FILE for job '$JOB_KEY'."
    return 1
  fi

  if [[ "$overall_failed" == "true" ]]; then
    PARAM_VALIDATION_STATUS="failed"
    PARAM_VALIDATION_MISSING="${missing_report:-none}"
    PARAM_VALIDATION_EXTRA="${extra_report:-none}"
    PARAM_VALIDATION_INCORRECT="not checked"
    NEXT_ACTION="Fix task base_parameters in databricks.yml and rerun with --integration-test."
    return 1
  fi

  PARAM_VALIDATION_STATUS="passed"
  PARAM_VALIDATION_MISSING="none"
  PARAM_VALIDATION_EXTRA="none"
  PARAM_VALIDATION_INCORRECT="none"
  return 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --job)        JOB_KEY="$2";  shift 2 ;;
    --target|-t)  TARGET="$2";   shift 2 ;;
    --profile|-p) PROFILE="$2";  shift 2 ;;
    --bundle-file) BUNDLE_FILE="$2"; shift 2 ;;
    --skip-deploy)    SKIP_DEPLOY="true";     shift ;;
    --no-strict)      STRICT_VALIDATE="false"; shift ;;
    --no-wait)        NO_WAIT="true";          shift ;;
    --integration-test) INTEGRATION_TEST="true"; shift ;;
    --skip-integration-test) INTEGRATION_TEST="false"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$JOB_KEY" ]]; then
  echo "Error: --job is required" >&2
  usage
  exit 1
fi

if [[ -z "$PROFILE" ]]; then
  PROFILE="$TARGET"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "$BUNDLE_FILE" ]]; then
  if [[ -n "${DATABRICKS_BUNDLE_FILE:-}" ]]; then
    BUNDLE_FILE="$DATABRICKS_BUNDLE_FILE"
  elif [[ -f "databricks.yml" ]]; then
    BUNDLE_FILE="databricks.yml"
  elif [[ -f "databricks.yaml" ]]; then
    BUNDLE_FILE="databricks.yaml"
  else
    echo "Error: bundle file not found. Set --bundle-file or DATABRICKS_BUNDLE_FILE." >&2
    exit 1
  fi
fi

if [[ "$BUNDLE_FILE" != /* ]]; then
  BUNDLE_FILE="$ROOT_DIR/$BUNDLE_FILE"
fi

if [[ ! -f "$BUNDLE_FILE" ]]; then
  echo "Error: bundle file does not exist: $BUNDLE_FILE" >&2
  exit 1
fi

set -e

CLI_BASE=(databricks)
COMMON_FLAGS=(--target "$TARGET" --profile "$PROFILE")

# ── Validate ──────────────────────────────────────────────────────────────────
VALIDATE_CMD=("${CLI_BASE[@]}" bundle validate "${COMMON_FLAGS[@]}")
if [[ "$STRICT_VALIDATE" == "true" ]]; then
  VALIDATE_CMD+=(--strict)
fi

echo "==> Validating bundle (target=$TARGET, profile=$PROFILE)"
if run_capture VALIDATE_OUT "${VALIDATE_CMD[@]}"; then
  VALIDATION_STATUS="passed"
  echo "$VALIDATE_OUT"
else
  VALIDATION_STATUS="failed"
  FAILURE_CLASS="$(classify_error "$VALIDATE_OUT")"
  case "$FAILURE_CLASS" in
    AUTH_OR_PERMISSIONS)
      NEXT_ACTION="Fix auth or profile — check ~/.databrickscfg and verify profile=$PROFILE exists." ;;
    CONFIG_OR_BUNDLE)
      NEXT_ACTION="Fix bundle config errors shown above and rerun validation." ;;
    *)
      NEXT_ACTION="Review validation errors above and fix before retrying." ;;
  esac
  echo "$VALIDATE_OUT" >&2
  print_summary
  exit 1
fi

# ── Deploy ────────────────────────────────────────────────────────────────────
if [[ "$SKIP_DEPLOY" == "true" ]]; then
  DEPLOY_STATUS="skipped"
  echo "==> Skipping deploy step"
else
  echo "==> Deploying bundle"
  if [[ ! -f ".databricksignore" ]]; then
    echo "==> WARNING: .databricksignore not found; bundle deploy may be slow due to large local folders syncing."
  fi
  if run_capture_stream DEPLOY_OUT "${CLI_BASE[@]}" bundle deploy "${COMMON_FLAGS[@]}"; then
    DEPLOY_STATUS="passed"
  else
    DEPLOY_STATUS="failed"
    FAILURE_CLASS="$(classify_error "$DEPLOY_OUT")"
    case "$FAILURE_CLASS" in
      AUTH_OR_PERMISSIONS)
        NEXT_ACTION="Fix auth or permissions — verify token and workspace access for profile=$PROFILE." ;;
      INFRA_OR_CLUSTER)
        NEXT_ACTION="Infra issue during deploy — retry deploy after a short wait." ;;
      *)
        NEXT_ACTION="Review deploy errors above and fix before retrying." ;;
    esac
    echo "$DEPLOY_OUT" >&2
    print_summary
    exit 1
  fi
fi

# ── Run ───────────────────────────────────────────────────────────────────────
echo "==> Running bundle job: $JOB_KEY"
RUN_ARGS=(bundle run "$JOB_KEY" "${COMMON_FLAGS[@]}" -o json)
if [[ "$NO_WAIT" == "true" ]]; then
  RUN_ARGS+=(--no-wait)
fi

extract_run_id_from_text() {
  local text="$1"
  local id=""
  if command -v jq >/dev/null 2>&1; then
    id="$(echo "$text" | jq -r '.. | .run_id? // empty' 2>/dev/null | head -n 1)"
  fi
  if [[ -z "$id" ]]; then
    id="$(echo "$text" | grep -Eo '"run_id"[[:space:]]*:[[:space:]]*[0-9]+' | head -n 1 | grep -Eo '[0-9]+')"
  fi
  if [[ -z "$id" ]]; then
    id="$(echo "$text" | grep -Eo '/run/[0-9]+' | head -n 1 | grep -Eo '[0-9]+')"
  fi
  echo "$id"
}

MAX_RETRIES=2
ATTEMPT=0
RUN_OUTPUT=""
RUN_LAUNCHED_WITH_FALLBACK="false"

until run_capture RUN_OUTPUT "${CLI_BASE[@]}" "${RUN_ARGS[@]}"; do
  FALLBACK_RUN_ID="$(extract_run_id_from_text "$RUN_OUTPUT")"
  if [[ -n "$FALLBACK_RUN_ID" ]]; then
    RUN_ID="$FALLBACK_RUN_ID"
    RUN_LAUNCHED_WITH_FALLBACK="true"
    FAILURE_CLASS="TRANSIENT_PLATFORM"
    echo "==> Databricks CLI returned an error but emitted run_id=$RUN_ID; continuing with run tracking."
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  FAILURE_CLASS="$(classify_error "$RUN_OUTPUT")"
  if [[ $ATTEMPT -ge $MAX_RETRIES ]]; then
    echo "ERROR: Job failed after $MAX_RETRIES attempts" >&2
    echo "$RUN_OUTPUT" >&2
    case "$FAILURE_CLASS" in
      AUTH_OR_PERMISSIONS)
        NEXT_ACTION="Fix auth — token may have expired. Check profile=$PROFILE." ;;
      INFRA_OR_CLUSTER)
        NEXT_ACTION="Cluster failure — retry after a few minutes or check instance pool availability." ;;
      TRANSIENT_PLATFORM)
        NEXT_ACTION="Transient Databricks issue — wait and retry. Check Databricks status page." ;;
      CONFIG_OR_BUNDLE)
        NEXT_ACTION="Bundle config issue — verify job key '$JOB_KEY' exists in $BUNDLE_FILE." ;;
      CODE_OR_NOTEBOOK)
        NEXT_ACTION="Notebook error — review error trace above and fix the failing notebook." ;;
      DATA_OR_SCHEMA)
        NEXT_ACTION="Data or schema error — review table/schema issues in the error trace above." ;;
      *)
        NEXT_ACTION="Unknown failure — review full output above and inspect Databricks UI." ;;
    esac
    RUN_STATE="FAILED"
    print_summary
    exit 1
  fi
  echo "==> Attempt $ATTEMPT failed (class: $FAILURE_CLASS), retrying in 60s..."
  sleep 60
done

if [[ -z "$RUN_OUTPUT" ]]; then
  echo "ERROR: Run returned no output" >&2
  RUN_STATE="no output"
  FAILURE_CLASS="UNKNOWN"
  NEXT_ACTION="Run returned no output — check Databricks UI for run status."
  print_summary
  exit 1
fi

echo "$RUN_OUTPUT"

# ── Extract Run ID ────────────────────────────────────────────────────────────
if [[ "$RUN_LAUNCHED_WITH_FALLBACK" != "true" ]]; then
  RUN_ID="$(extract_run_id_from_text "$RUN_OUTPUT" || true)"
fi
if [[ -z "$RUN_ID" ]]; then
  RUN_ID="not found"
  RUN_STATE="submitted"
  FAILURE_CLASS="UNKNOWN"
  NEXT_ACTION="Run submitted but run_id not found — inspect Databricks UI."
  print_summary
  exit 1
fi

echo "==> Databricks run_id: $RUN_ID"

# ── No-wait exit ──────────────────────────────────────────────────────────────
if [[ "$NO_WAIT" == "true" ]]; then
  RUN_STATE="submitted"
  FAILURE_CLASS="none"
  if [[ "$INTEGRATION_TEST" == "true" ]]; then
    PARAM_VALIDATION_STATUS="skipped"
    PARAM_VALIDATION_INCORRECT="not checked"
    NEXT_ACTION="Run completed asynchronously; rerun without --no-wait to perform integration validation."
  else
    PARAM_VALIDATION_STATUS="skipped"
    PARAM_VALIDATION_INCORRECT="not checked"
    NEXT_ACTION="Monitor run $RUN_ID in Databricks Jobs UI."
  fi
  print_summary
  exit 0
fi

# ── Fetch Run Metadata ────────────────────────────────────────────────────────
echo "==> Fetching run metadata"
GET_RUN_RETRIES=6
GET_RUN_ATTEMPT=0
RUN_META_OK="false"
while [[ $GET_RUN_ATTEMPT -lt $GET_RUN_RETRIES ]]; do
  if run_capture RUN_META_JSON "${CLI_BASE[@]}" jobs get-run "$RUN_ID" "${COMMON_FLAGS[@]}" -o json; then
    RUN_META_OK="true"
    break
  fi
  GET_RUN_ATTEMPT=$((GET_RUN_ATTEMPT + 1))
  if [[ "$RUN_META_JSON" =~ [Rr]un[[:space:]]+[0-9]+[[:space:]]+does[[:space:]]+not[[:space:]]+exist ]]; then
    echo "==> Run metadata not ready yet for run_id=$RUN_ID; retrying in 10s..."
    sleep 10
    continue
  fi
  break
done

if [[ "$RUN_META_OK" == "true" ]]; then
  echo "$RUN_META_JSON"
  if command -v jq >/dev/null 2>&1; then
    LIFECYCLE_STATE="$(echo "$RUN_META_JSON" | jq -r '.state.life_cycle_state // empty')"
    RESULT_STATE="$(echo "$RUN_META_JSON" | jq -r '.state.result_state // empty')"
    if [[ -n "$LIFECYCLE_STATE" && -n "$RESULT_STATE" ]]; then
      RUN_STATE="$LIFECYCLE_STATE/$RESULT_STATE"
    elif [[ -n "$LIFECYCLE_STATE" ]]; then
      RUN_STATE="$LIFECYCLE_STATE"
    elif [[ -n "$RESULT_STATE" ]]; then
      RUN_STATE="$RESULT_STATE"
    fi
  fi
else
  FAILURE_CLASS="$(classify_error "$RUN_META_JSON")"
  NEXT_ACTION="Failed to fetch run metadata — check auth and run_id=$RUN_ID."
  echo "WARNING: Could not fetch run metadata" >&2
fi

# ── Fetch Run Output ──────────────────────────────────────────────────────────
echo "==> Fetching run output"

TASK_RUN_IDS=""
if command -v jq >/dev/null 2>&1; then
  TASK_RUN_IDS="$(echo "$RUN_META_JSON" | jq -r '.tasks[].run_id // empty' 2>/dev/null || true)"
fi

if [[ -n "$TASK_RUN_IDS" ]]; then
  echo "==> Multi-task job detected, fetching output per task"
  while IFS= read -r TASK_RUN_ID; do
    [[ -z "$TASK_RUN_ID" ]] && continue
    TASK_KEY="$(echo "$RUN_META_JSON" | jq -r ".tasks[] | select(.run_id == $TASK_RUN_ID) | .task_key" 2>/dev/null || echo "unknown")"
    echo "==> Task: $TASK_KEY (run_id: $TASK_RUN_ID)"
    if run_capture TASK_OUTPUT_JSON "${CLI_BASE[@]}" jobs get-run-output "$TASK_RUN_ID" "${COMMON_FLAGS[@]}" -o json; then
      echo "$TASK_OUTPUT_JSON"
      if command -v jq >/dev/null 2>&1; then
        ERROR_MSG="$(echo "$TASK_OUTPUT_JSON" | jq -r '.error // empty')"
        ERROR_TRACE="$(echo "$TASK_OUTPUT_JSON" | jq -r '.error_trace // empty')"
        RAW_NOTEBOOK_OUT="$(echo "$TASK_OUTPUT_JSON" | jq -r '.notebook_output.result // empty')"
        if [[ -n "$ERROR_MSG" ]]; then
          echo "==> Task $TASK_KEY error: $ERROR_MSG" >&2
          if [[ "$FAILURE_CLASS" == "UNKNOWN" ]]; then
            FAILURE_CLASS="$(classify_error "$ERROR_MSG $ERROR_TRACE")"
          fi
        fi
        if [[ -n "$ERROR_TRACE" ]]; then
          echo "==> Task $TASK_KEY trace: $ERROR_TRACE" >&2
        fi
        if [[ -n "$RAW_NOTEBOOK_OUT" && "$NOTEBOOK_OUTPUT" == "not available" ]]; then
          NOTEBOOK_OUTPUT="$(echo "$RAW_NOTEBOOK_OUT" | tr '\n' ' ' | tr -s ' ' | cut -c1-220)"
        fi
      fi
    else
      echo "WARNING: Could not fetch output for task $TASK_KEY (run_id: $TASK_RUN_ID)" >&2
    fi
  done <<< "$TASK_RUN_IDS"
else
  if run_capture RUN_OUTPUT_JSON "${CLI_BASE[@]}" jobs get-run-output "$RUN_ID" "${COMMON_FLAGS[@]}" -o json; then
    echo "$RUN_OUTPUT_JSON"
    if command -v jq >/dev/null 2>&1; then
      ERROR_MSG="$(echo "$RUN_OUTPUT_JSON" | jq -r '.error // empty')"
      ERROR_TRACE="$(echo "$RUN_OUTPUT_JSON" | jq -r '.error_trace // empty')"
      RAW_NOTEBOOK_OUT="$(echo "$RUN_OUTPUT_JSON" | jq -r '.notebook_output.result // empty')"
      if [[ -n "$ERROR_MSG" ]]; then
        echo "==> Job error: $ERROR_MSG" >&2
        FAILURE_CLASS="$(classify_error "$ERROR_MSG $ERROR_TRACE")"
      fi
      if [[ -n "$ERROR_TRACE" ]]; then
        echo "==> Error trace: $ERROR_TRACE" >&2
      fi
      if [[ -n "$RAW_NOTEBOOK_OUT" ]]; then
        NOTEBOOK_OUTPUT="$(echo "$RAW_NOTEBOOK_OUT" | tr '\n' ' ' | tr -s ' ' | cut -c1-220)"
      fi
    fi
  else
    echo "WARNING: Could not fetch run output" >&2
  fi
fi

# ── Final Result Check ────────────────────────────────────────────────────────
if [[ "$RUN_STATE" == *"SUCCESS"* ]]; then
  if [[ "$INTEGRATION_TEST" == "true" ]]; then
    echo "==> Running integration parameter validation"
    if ! validate_task_parameters "$RUN_META_JSON"; then
      FAILURE_CLASS="CONFIG_OR_BUNDLE"
      print_summary
      exit 1
    fi
  else
    PARAM_VALIDATION_STATUS="skipped"
    PARAM_VALIDATION_INCORRECT="not checked"
  fi
  FAILURE_CLASS="none"
  NEXT_ACTION="none"
  print_summary
  exit 0
elif [[ "$RUN_STATE" == *"CANCELED"* ]]; then
  FAILURE_CLASS="UNKNOWN"
  NEXT_ACTION="Run was canceled — check Databricks UI for who or what canceled it."
  print_summary
  exit 1
elif [[ "$RUN_STATE" == *"TIMEDOUT"* ]]; then
  FAILURE_CLASS="TRANSIENT_PLATFORM"
  NEXT_ACTION="Run timed out — check timeout_seconds in databricks.yml and retry."
  print_summary
  exit 1
elif [[ "$RUN_STATE" == *"FAILED"* ]]; then
  if [[ "$NEXT_ACTION" == "none" ]]; then
    case "$FAILURE_CLASS" in
      AUTH_OR_PERMISSIONS)
        NEXT_ACTION="Fix auth or permissions and redeploy." ;;
      INFRA_OR_CLUSTER)
        NEXT_ACTION="Cluster failure — safe to redeploy and retry." ;;
      TRANSIENT_PLATFORM)
        NEXT_ACTION="Transient failure — safe to retry without redeploy." ;;
      DATA_OR_SCHEMA)
        NEXT_ACTION="Fix data or schema issue — not safe to auto-retry." ;;
      CODE_OR_NOTEBOOK)
        NEXT_ACTION="Fix notebook code — not safe to auto-retry." ;;
      *)
        NEXT_ACTION="Review error output above and inspect Databricks UI." ;;
    esac
  fi
  print_summary
  exit 1
else
  NEXT_ACTION="Could not determine final run state — inspect Databricks UI for run_id=$RUN_ID."
  print_summary
  exit 1
fi