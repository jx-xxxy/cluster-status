#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-.}"
OUT_FILE="$OUT_DIR/index.html"
mkdir -p "$OUT_DIR"

html_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
      -e 's/"/\&quot;/g' -e "s/'/\&#39;/g"
}

status_class() {
  case "$1" in
    RUNNING|COMPLETING) printf 'running' ;;
    PENDING|CONFIGURING) printf 'pending' ;;
    FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY|NODE_FAIL) printf 'failed' ;;
    *) printf 'other' ;;
  esac
}

status_label() {
  case "$1" in
    RUNNING) printf '运行中' ;;
    PENDING) printf '排队中' ;;
    COMPLETING) printf '收尾中' ;;
    FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY|NODE_FAIL) printf '异常/结束' ;;
    *) printf '%s' "$1" ;;
  esac
}

now="$(date '+%Y-%m-%d %H:%M:%S')"
queue_file="$(mktemp)"
trap 'rm -f "$queue_file"' EXIT

# Only the authenticated user's jobs are collected. No other users' task data
# is sent to the public repository.
squeue -h -u "${USER:?}" -o '%j|%T|%M|%R' > "$queue_file"

total=0
running=0
pending=0
other=0
rows=""

while IFS='|' read -r job_name state runtime location; do
  [ -n "${job_name:-}" ] || continue
  total=$((total + 1))
  case "$state" in
    RUNNING|COMPLETING) running=$((running + 1)) ;;
    PENDING|CONFIGURING) pending=$((pending + 1)) ;;
    *) other=$((other + 1)) ;;
  esac
  class="$(status_class "$state")"
  label="$(status_label "$state")"
  rows="$rows
    <article class=\"job-card\">
      <div class=\"job-main\"><strong>$(printf '%s' "$job_name" | html_escape)</strong><span class=\"state $class\">$label</span></div>
      <div class=\"job-meta\"><span>运行时间 <b>$(printf '%s' "$runtime" | html_escape)</b></span><span>节点/原因 <b>$(printf '%s' "$location" | html_escape)</b></span></div>
    </article>"
done < "$queue_file"

if [ "$total" -eq 0 ]; then
  rows='<div class="empty">当前没有排队或运行中的任务</div>'
fi

cat > "$OUT_FILE" <<EOF
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="300">
  <title>集群任务状态</title>
  <style>
    :root { color-scheme: light; font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; background:#f4f7fb; color:#172033; }
    * { box-sizing:border-box; } body { margin:0; padding:24px 14px 36px; }
    .wrap { max-width:760px; margin:auto; } .header { display:flex; justify-content:space-between; gap:16px; align-items:end; margin-bottom:20px; }
    h1 { margin:0; font-size:26px; letter-spacing:-.02em; } .updated { color:#70809a; font-size:13px; white-space:nowrap; }
    .summary { display:grid; grid-template-columns:repeat(3,1fr); gap:10px; margin-bottom:16px; }
    .stat { background:#fff; border:1px solid #e3e9f2; border-radius:16px; padding:14px 16px; box-shadow:0 5px 18px #1a2b4a0a; }
    .stat span { display:block; color:#70809a; font-size:12px; margin-bottom:4px; } .stat b { font-size:24px; }
    .job-card { background:#fff; border:1px solid #e3e9f2; border-radius:16px; padding:16px; margin:10px 0; box-shadow:0 5px 18px #1a2b4a0a; }
    .job-main,.job-meta { display:flex; justify-content:space-between; gap:12px; align-items:center; } .job-main strong { overflow-wrap:anywhere; }
    .state { border-radius:999px; padding:4px 9px; font-size:12px; white-space:nowrap; } .running { color:#087443; background:#e6f7ee; } .pending { color:#996300; background:#fff3d8; } .failed { color:#b42318; background:#feeceb; } .other { color:#44546f; background:#edf1f7; }
    .job-meta { margin-top:12px; color:#70809a; font-size:13px; flex-wrap:wrap; } .job-meta b { color:#34435c; font-weight:600; }
    .empty { background:#fff; border:1px dashed #c8d2e2; border-radius:16px; padding:28px; text-align:center; color:#70809a; }
    .foot { color:#8b98ac; font-size:12px; margin-top:18px; } @media (max-width:520px) { .header { display:block; } .updated { display:block; margin-top:7px; } .summary { gap:7px; } .stat { padding:12px 10px; } .stat b { font-size:21px; } }
  </style>
</head>
<body><main class="wrap">
  <header class="header"><h1>集群任务状态</h1><div class="updated">更新于 $now</div></header>
  <section class="summary" aria-label="任务统计">
    <div class="stat"><span>全部任务</span><b>$total</b></div><div class="stat"><span>运行中</span><b>$running</b></div><div class="stat"><span>排队中</span><b>$pending</b></div>
  </section>
  <section aria-label="任务列表">$rows</section>
  <div class="foot">仅显示当前账号的 Slurm 任务 · 页面每 5 分钟自动刷新</div>
</main></body></html>
EOF

