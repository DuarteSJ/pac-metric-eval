#!/usr/bin/env python3
"""GPT-2 unconditional text generation on CPU, for the Fig. 2 workload set.

PACT's names (gpt_2_<size>_unconditional) match OpenAI's
generate_unconditional_samples.py (TensorFlow 1.x); this is the same task
(sampling from the start token, top-k 40) with HuggingFace transformers on
PyTorch. Models must be in the local cache (setup.sh gpt2).

  gpt2.py --model gpt2-medium --threads 8 --samples 4 --tokens 256
"""
import argparse
import time

import torch
from transformers import GPT2LMHeadModel


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model", default="gpt2", help="gpt2 | gpt2-medium | gpt2-large | gpt2-xl")
    ap.add_argument("--threads", type=int, default=8)
    ap.add_argument("--samples", type=int, default=4, help="sequences generated in one batch")
    ap.add_argument("--tokens", type=int, default=256, help="new tokens per sequence")
    ap.add_argument("--seed", type=int, default=0)
    args = ap.parse_args()

    torch.set_num_threads(args.threads)
    torch.manual_seed(args.seed)
    model = GPT2LMHeadModel.from_pretrained(args.model, local_files_only=True).eval()
    start = torch.full((args.samples, 1), model.config.bos_token_id)
    t0 = time.time()
    with torch.inference_mode():
        out = model.generate(start, do_sample=True, top_k=40, max_new_tokens=args.tokens,
                             min_new_tokens=args.tokens, pad_token_id=model.config.eos_token_id)
    dt = time.time() - t0
    n = out.shape[0] * (out.shape[1] - 1)
    print(f"{args.model}: {n} tokens in {dt:.1f} s ({n / dt:.1f} tokens/s, {args.threads} threads)")


if __name__ == "__main__":
    main()
