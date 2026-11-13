# shellcheck shell=bash disable=SC2034  # sets CMD/PRELOAD/ATTACH for the sourcer
# GPT-2 unconditional generation on CPU (interface: workloads/README.md).

GPT2_HOME="$WORKLOADS_DIR/gpt2"
GPT2_VENV="$GPT2_HOME/venv"
# HuggingFace cache (model weights) inside this folder.
GPT2_HF="$GPT2_HOME/hf"
declare -A GPT2_MODEL=([124M]=gpt2 [355M]=gpt2-medium [774M]=gpt2-large [1558M]=gpt2-xl)

list_gpt2() {
	local s
	for s in 124M 355M 774M 1558M; do echo "gpt2-$s"; done
}

cmd_gpt2() {
	local model=${GPT2_MODEL[${1#gpt2-}]:-}
	[[ -n $model ]] || return 1
	CMD=(env HF_HOME="$GPT2_HF" HF_HUB_OFFLINE=1 "$GPT2_VENV/bin/python" "$GPT2_HOME/gpt2.py"
		--model "$model" --threads "$THREADS" --samples 4 --tokens 256)
}
