#!/bin/bash
set -e

export LANG=nl_NL.UTF-8
export LC_ALL=nl_NL.UTF-8

# ── Wait for the desktop / window manager to be ready ───────────────
sleep 3

# ── Launch GCompris in fullscreen ───────────────────────────────────
gcompris-qt --fullscreen &
