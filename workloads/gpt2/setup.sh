#!/usr/bin/env bash
# GPT-2: a Python venv in venv/ with PyTorch (CPU) + transformers, and the 4
# models downloaded into hf/ (gpt2.py then runs offline).
set -euo pipefail
WORKLOADS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKLOADS_DIR/common.sh"
source "$WORKLOADS_DIR/gpt2/workload.sh"

[[ -d $GPT2_VENV ]] || python3 -m venv "$GPT2_VENV"
"$GPT2_VENV/bin/pip" install -q torch --index-url https://download.pytorch.org/whl/cpu
"$GPT2_VENV/bin/pip" install -q transformers
HF_HOME="$GPT2_HF" "$GPT2_VENV/bin/python" -c "
from transformers import GPT2LMHeadModel
for m in ('gpt2', 'gpt2-medium', 'gpt2-large', 'gpt2-xl'):
    GPT2LMHeadModel.from_pretrained(m)
    print('cached', m)
"
