#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/traffic-tests.XXXXXX")
printf 'Build and log directory: %s\n' "$build_dir"
verilator --lint-only --top-module top hardware/rtl/*.sv
for bench in tb_crossing tb_updates; do
    if ! verilator --binary --timing --top-module "$bench" \
        --Mdir "$build_dir/$bench" \
        hardware/rtl/crossing_fsm.sv hardware/rtl/sensor_input.sv \
        "hardware/sim/$bench.sv" > "$build_dir/$bench.log" 2>&1; then
        cat "$build_dir/$bench.log"
        exit 1
    fi
    "$build_dir/$bench/V$bench"
done
