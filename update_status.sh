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
squeue -h -u "${USER:?}" -o '%i|%j|%T|%M|%R|%c|%C|%Z|%D' > "$queue_file"

total=0
running=0
pending=0
other=0
rows=""

while IFS='|' read -r job_id job_name state runtime location requested_cores allocated_cores workdir nodes; do
  [ -n "${job_name:-}" ] || continue
  total=$((total + 1))
  case "$state" in
    RUNNING|COMPLETING) running=$((running + 1)) ;;
    PENDING|CONFIGURING) pending=$((pending + 1)) ;;
    *) other=$((other + 1)) ;;
  esac
  class="$(status_class "$state")"
  label="$(status_label "$state")"
  request_cores="$(printf '%s' "$requested_cores" | html_escape)"
  assigned_cores="$(printf '%s' "$allocated_cores" | html_escape)"
  escaped_workdir="$(printf '%s' "$workdir" | html_escape)"
  rows="$rows
    <article class=\"job-card\">
      <div class=\"job-main\"><div class=\"job-title\"><span class=\"job-dot $class\"></span><strong>$(printf '%s' "$job_name" | html_escape)</strong><small class=\"job-id\">#$(printf '%s' "$job_id" | html_escape)</small></div><span class=\"state $class\">$label</span></div>
      <div class=\"facts\"><span><em>运行时间</em><b>$(printf '%s' "$runtime" | html_escape)</b></span><span><em>核数</em><b>$request_cores / $assigned_cores</b><small>申请 / 已分配</small></span><span><em>节点</em><b>$(printf '%s' "$nodes" | html_escape)</b></span></div>
      <div class=\"location\"><span>节点 / 排队原因</span><b>$(printf '%s' "$location" | html_escape)</b></div>
      <div class=\"workdir\" title=\"$escaped_workdir\"><span>投递目录</span><b>$escaped_workdir</b></div>
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
    * { box-sizing:border-box; } body { margin:0; padding:28px 14px 40px; background:radial-gradient(circle at 8% 0%,#e8f1ff 0,transparent 32%),#f4f7fb; }
    .wrap { max-width:790px; margin:auto; } .header { display:flex; justify-content:space-between; gap:16px; align-items:end; margin-bottom:20px; }
    h1 { margin:0; font-size:28px; letter-spacing:-.03em; } .updated { color:#70809a; font-size:13px; white-space:nowrap; }
    .summary { display:grid; grid-template-columns:repeat(3,1fr); gap:10px; margin-bottom:16px; }
    .stat { background:#fff; border:1px solid #e3e9f2; border-radius:16px; padding:14px 16px; box-shadow:0 8px 22px #1a2b4a0a; }
    .stat span { display:block; color:#70809a; font-size:12px; margin-bottom:4px; } .stat b { font-size:24px; }
    .job-card { background:#fff; border:1px solid #e3e9f2; border-radius:18px; padding:17px 18px; margin:11px 0; box-shadow:0 8px 22px #1a2b4a0a; }
    .job-main,.facts,.location,.workdir { display:flex; justify-content:space-between; gap:12px; align-items:center; } .job-main strong { overflow-wrap:anywhere; }
    .job-title { display:flex; gap:9px; align-items:center; min-width:0; } .job-dot { width:9px; height:9px; border-radius:50%; flex:none; } .job-dot.running { background:#12a66a; box-shadow:0 0 0 4px #e6f7ee; } .job-dot.pending { background:#e2a100; box-shadow:0 0 0 4px #fff3d8; } .job-dot.failed { background:#d92d20; box-shadow:0 0 0 4px #feeceb; } .job-dot.other { background:#7b8aa3; box-shadow:0 0 0 4px #edf1f7; } .job-id { color:#9aa6b8; font:11px ui-monospace,SFMono-Regular,Consolas,monospace; }
    .state { border-radius:999px; padding:4px 9px; font-size:12px; white-space:nowrap; } .running { color:#087443; background:#e6f7ee; } .pending { color:#996300; background:#fff3d8; } .failed { color:#b42318; background:#feeceb; } .other { color:#44546f; background:#edf1f7; }
    .facts { justify-content:flex-start; flex-wrap:wrap; margin-top:16px; padding-top:13px; border-top:1px solid #edf1f6; } .facts span { min-width:112px; } .facts em,.location span,.workdir span { display:block; color:#8b98ac; font-size:11px; font-style:normal; margin-bottom:3px; } .facts b,.location b,.workdir b { color:#34435c; font-size:13px; font-weight:600; } .facts small { color:#9aa6b8; font-size:10px; margin-left:4px; }
    .location,.workdir { justify-content:flex-start; align-items:baseline; margin-top:11px; gap:10px; color:#34435c; font-size:13px; } .location span,.workdir span { min-width:80px; margin:0; } .location b { overflow-wrap:anywhere; } .workdir { padding:9px 10px; border-radius:10px; background:#f7f9fc; } .workdir b { overflow:hidden; text-overflow:ellipsis; white-space:nowrap; font-family:ui-monospace,SFMono-Regular,Consolas,monospace; font-size:12px; }
    .empty { background:#fff; border:1px dashed #c8d2e2; border-radius:16px; padding:28px; text-align:center; color:#70809a; }
    .foot { color:#8b98ac; font-size:12px; margin-top:18px; } @media (max-width:520px) { body { padding:20px 10px 30px; } .header { display:block; } .updated { display:block; margin-top:7px; } .summary { gap:7px; } .stat { padding:12px 10px; } .stat b { font-size:21px; } .job-card { padding:15px; } .facts { gap:10px 16px; } .facts span { min-width:98px; } .location,.workdir { display:block; } .location span,.workdir span { margin-bottom:4px; } .workdir b { display:block; } }
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

