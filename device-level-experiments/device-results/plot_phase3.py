#!/usr/bin/env python3
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parent / "phase3"
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
    for path in sorted(cfg_dir.glob("*_trial*.txt")):
        if "zone_report" in path.name:
            continue
        d = parse_txt(path)
        lat = d.get("reset_plus_write_latency_us")
        if lat is None:
            continue
        rows.append({
            "config": cfg,
            "mode": d.get("mode"),
            "latency_us": float(lat),
            "trial_file": path.name
        })

df = pd.DataFrame(rows)
if df.empty:
    raise RuntimeError("No phase3 latency txt files found.")

df.to_csv(OUT / "phase3_raw.csv", index=False)

summary = (
    df.groupby(["config", "mode"], as_index=False)
      .agg(
          mean_latency_us=("latency_us", "mean"),
          std_latency_us=("latency_us", "std"),
          min_latency_us=("latency_us", "min"),
          max_latency_us=("latency_us", "max"),
          n=("latency_us", "count")
      )
)

summary.to_csv(OUT / "phase3_summary.csv", index=False)

pivot_mean = summary.pivot(index="config", columns="mode", values="mean_latency_us").reset_index()
pivot_std  = summary.pivot(index="config", columns="mode", values="std_latency_us").reset_index()

if "fresh_reset" in pivot_mean.columns and "filled_then_reset" in pivot_mean.columns:
    pivot_mean["penalty_ratio"] = pivot_mean["filled_then_reset"] / pivot_mean["fresh_reset"]

pivot_mean.to_csv(OUT / "phase3_penalty_ratio.csv", index=False)

# nice config order
cfg_order = sorted(df["config"].unique(), key=lambda x: int(x.replace("cfg", "")))
modes = ["fresh_reset", "filled_then_reset"]

# Plot A: grouped bar chart with error bars
plt.figure(figsize=(9, 6))
x = list(range(len(cfg_order)))
width = 0.35

fresh_means = []
fresh_stds = []
filled_means = []
filled_stds = []

for cfg in cfg_order:
    s_fresh = summary[(summary["config"] == cfg) & (summary["mode"] == "fresh_reset")]
    s_fill  = summary[(summary["config"] == cfg) & (summary["mode"] == "filled_then_reset")]

    fresh_means.append(float(s_fresh["mean_latency_us"].iloc[0]) if len(s_fresh) else 0.0)
    fresh_stds.append(float(s_fresh["std_latency_us"].iloc[0]) if len(s_fresh) and pd.notna(s_fresh["std_latency_us"].iloc[0]) else 0.0)

    filled_means.append(float(s_fill["mean_latency_us"].iloc[0]) if len(s_fill) else 0.0)
    filled_stds.append(float(s_fill["std_latency_us"].iloc[0]) if len(s_fill) and pd.notna(s_fill["std_latency_us"].iloc[0]) else 0.0)

plt.bar([i - width/2 for i in x], fresh_means, width=width, yerr=fresh_stds, capsize=4, label="fresh_reset")
plt.bar([i + width/2 for i in x], filled_means, width=width, yerr=filled_stds, capsize=4, label="filled_then_reset")

plt.xticks(x, cfg_order)
plt.xlabel("Configuration")
plt.ylabel("Reset + first write latency (us)")
plt.title("Fresh reset vs filled-then-reset latency")
plt.grid(True, axis="y", alpha=0.3)
plt.legend()
plt.tight_layout()
plt.savefig(OUT / "phase3_bar_latency.png", dpi=200)
plt.close()

# Plot B: penalty ratio
if "penalty_ratio" in pivot_mean.columns:
    plt.figure(figsize=(8, 5))
    plt.bar(pivot_mean["config"], pivot_mean["penalty_ratio"])
    plt.xlabel("Configuration")
    plt.ylabel("Penalty ratio")
    plt.title("Filled-then-reset / fresh-reset latency ratio")
    plt.grid(True, axis="y", alpha=0.3)
    plt.tight_layout()
    plt.savefig(OUT / "phase3_penalty_ratio.png", dpi=200)
    plt.close()

# Plot C: raw scatter
plt.figure(figsize=(10, 6))
pos = []
labels = []
xpos = 0

for cfg in cfg_order:
    for mode in modes:
        vals = df[(df["config"] == cfg) & (df["mode"] == mode)]["latency_us"].tolist()
        xs = [xpos] * len(vals)
        plt.scatter(xs, vals)
        pos.append(xpos)
        labels.append(f"{cfg}\n{mode}")
        xpos += 1

plt.xticks(pos, labels)
plt.ylabel("Reset + first write latency (us)")
plt.title("Raw trial latencies")
plt.grid(True, axis="y", alpha=0.3)
plt.tight_layout()
plt.savefig(OUT / "phase3_raw_scatter.png", dpi=200)
plt.close()

print("Saved:")
print(OUT / "phase3_raw.csv")
print(OUT / "phase3_summary.csv")
print(OUT / "phase3_penalty_ratio.csv")
print(OUT / "phase3_bar_latency.png")
print(OUT / "phase3_penalty_ratio.png")
print(OUT / "phase3_raw_scatter.png")