#!/usr/bin/env python3
from pathlib import Path
import re
import pandas as pd
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parent / "phase3_history"
OUT = ROOT / "plots"
OUT.mkdir(parents=True, exist_ok=True)

def parse_txt(path):
    d = {}
    with open(path) as f:
        for line in f:
            if "=" in line:
                k, v = line.strip().split("=", 1)
                d[k] = v
    return d

rows = []
for cfg_dir in sorted(ROOT.glob("cfg*")):
    cfg = cfg_dir.name
    for fill_dir in sorted(cfg_dir.glob("fill*")):
        m = re.match(r"fill(\d+)", fill_dir.name)
        if not m:
            continue
        fill_count = int(m.group(1))

        for path in sorted(fill_dir.glob("fill*_trial*.txt")):
            d = parse_txt(path)
            lat = d.get("reset_plus_write_latency_us")
            if lat is None:
                continue
            rows.append({
                "config": cfg,
                "fill_count": fill_count,
                "latency_us": float(lat),
                "trial_file": path.name,
            })

df = pd.DataFrame(rows)
if df.empty:
    raise RuntimeError("No phase3_history txt files found.")

df.to_csv(OUT / "phase3_history_raw.csv", index=False)

summary = (
    df.groupby(["config", "fill_count"], as_index=False)
      .agg(
          mean_latency_us=("latency_us", "mean"),
          std_latency_us=("latency_us", "std"),
          min_latency_us=("latency_us", "min"),
          max_latency_us=("latency_us", "max"),
          n=("latency_us", "count")
      )
)
summary.to_csv(OUT / "phase3_history_summary.csv", index=False)

# For cfg10 single-line plot
for cfg, g in summary.groupby("config"):
    g = g.sort_values("fill_count")

    plt.figure(figsize=(8, 5))
    plt.errorbar(
        g["fill_count"],
        g["mean_latency_us"],
        yerr=g["std_latency_us"].fillna(0),
        marker="o",
        capsize=4
    )
    plt.xlabel("Number of previously filled zones")
    plt.ylabel("Reset + first write latency (us)")
    plt.title(f"History-depth sensitivity for {cfg}")
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(OUT / f"{cfg}_history_depth_latency.png", dpi=200)
    plt.close()

# combined plot in case you later run more cfgs
plt.figure(figsize=(9, 6))
for cfg, g in summary.groupby("config"):
    g = g.sort_values("fill_count")
    plt.errorbar(
        g["fill_count"],
        g["mean_latency_us"],
        yerr=g["std_latency_us"].fillna(0),
        marker="o",
        capsize=4,
        label=cfg
    )

plt.xlabel("Number of previously filled zones")
plt.ylabel("Reset + first write latency (us)")
plt.title("History-depth sensitivity")
plt.grid(True, alpha=0.3)
plt.legend()
plt.tight_layout()
plt.savefig(OUT / "history_depth_latency_all.png", dpi=200)
plt.close()

print("Saved:")
print(OUT / "phase3_history_raw.csv")
print(OUT / "phase3_history_summary.csv")
print(OUT / "cfg10_history_depth_latency.png")
print(OUT / "history_depth_latency_all.png")