# gpt2

GPT-2 text generation on CPU, 4 model sizes, the same 4 names as PACT's
(`gpt_2_<size>_unconditional`). Those match OpenAI's
`generate_unconditional_samples.py` (TensorFlow 1.x, no longer practical to
install); `gpt2.py` does the same task, sampling from the start token with
top-k 40, on PyTorch + HuggingFace transformers.

| | |
|---|---|
| workloads | `gpt2-124M`, `gpt2-355M`, `gpt2-774M`, `gpt2-1558M` (HF `gpt2`, `gpt2-medium`, `gpt2-large`, `gpt2-xl`) |
| per run | 4 sequences x 256 new tokens |
| threads | `THREADS` (`torch.set_num_threads`) |
| setup | `./setup.sh`: venv in `venv/`, models (~10 GB) in `hf/` |

`venv/` and `hf/` are not in git.
