import json
import re
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


BS_ORDER = ["4k", "8k", "16k", "32k", "64k", "128k", "256k"]
CFG_ORDER = [0, 1, 10, 11, 18, 19]

CFG_LABELS = {
    "cfg0": "cfg0 (P=16)",
    "cfg10": "cfg10 (P=8)",
    "cfg18": "cfg18 (P=4)",
}

LINEWIDTH = 3
MARKERSIZE = 8
FONT_SIZE = 14
TITLE_SIZE = 17


def parse_size_to_kib(size_str: str) -> float:
    s = size_str.strip().lower()
    if s.endswith("k"):
        return float(s[:-1])
    if s.endswith("m"):
        return float(s[:-1]) * 1024
    if s.endswith("g"):
        return float(s[:-1]) * 1024 * 1024
    return float(s) / 1024.0


def parse_cfg_num(cfg_name: str):
    m = re.search(r"cfg(\d+)", cfg_name)
    return int(m.group(1)) if m else None


def extract_mean_latency_us(write_stats: dict):
    for key, scale in [
        ("lat_ns", 1 / 1000.0),
        ("clat_ns", 1 / 1000.0),
        ("lat_us", 1.0),
        ("clat_us", 1.0),
        ("lat_ms", 1000.0),
        ("clat_ms", 1000.0),
    ]:
        if key in write_stats and isinstance(write_stats[key], dict):
            mean_val = write_stats[key].get("mean")
            if mean_val is not None:
                return float(mean_val) * scale
    return None


def extract_bw_mib_s(write_stats: dict):
    if "bw_bytes" in write_stats:
        return float(write_stats["bw_bytes"]) / (1024 * 1024)
    if "bw" in write_stats:
        return float(write_stats["bw"]) / 1024.0
    return None


def extract_iops(write_stats: dict):
    val = write_stats.get("iops")
    return float(val) if val is not None else None


def load_fio_json(path: Path):
    try:
        with open(path, "r") as f:
            return json.load(f)
    except Exception as e:
        print(f"Could not read {path}: {e}")
        return None


def parse_intra_file(path: Path):
    data = load_fio_json(path)
    if not data or not data.get("jobs"):
        return None

    write_stats = data["jobs"][0].get("write", {})
    cfg_match = re.search(r"cfg(\d+)", str(path))
    bs_match = re.search(r"_bs([0-9]+[kKmMgG]?)_", path.name)

    if not cfg_match or not bs_match:
        return None

    return {
        "config": f"cfg{cfg_match.group(1)}",
        "config_num": int(cfg_match.group(1)),
        "experiment": "intra",
        "bs": bs_match.group(1).lower(),
        "bs_kib": parse_size_to_kib(bs_match.group(1)),
        "jobs": 1,
        "bandwidth_mib_s": extract_bw_mib_s(write_stats),
        "iops": extract_iops(write_stats),
        "latency_us": extract_mean_latency_us(write_stats),
        "file": str(path),
    }


def parse_inter_file(path: Path):
    data = load_fio_json(path)
    if not data or not data.get("jobs"):
        return None

    jobs = data["jobs"]
    write_stats_list = [j.get("write", {}) for j in jobs]

    cfg_match = re.search(r"cfg(\d+)", str(path))
    jobs_match = re.search(r"_jobs(\d+)", path.name)

    if not cfg_match or not jobs_match:
        return None

    if len(write_stats_list) == 1:
        bw = extract_bw_mib_s(write_stats_list[0])
        iops = extract_iops(write_stats_list[0])
        lat = extract_mean_latency_us(write_stats_list[0])
    else:
        bw_vals = [extract_bw_mib_s(ws) for ws in write_stats_list]
        iops_vals = [extract_iops(ws) for ws in write_stats_list]
        lat_vals = [extract_mean_latency_us(ws) for ws in write_stats_list]

        bw = sum(v for v in bw_vals if v is not None) if any(v is not None for v in bw_vals) else None
        iops = sum(v for v in iops_vals if v is not None) if any(v is not None for v in iops_vals) else None

        lat_clean = [v for v in lat_vals if v is not None]
        lat = sum(lat_clean) / len(lat_clean) if lat_clean else None

    return {
        "config": f"cfg{cfg_match.group(1)}",
        "config_num": int(cfg_match.group(1)),
        "experiment": "inter",
        "bs": "64k",
        "bs_kib": 64.0,
        "jobs": int(jobs_match.group(1)),
        "bandwidth_mib_s": bw,
        "iops": iops,
        "latency_us": lat,
        "file": str(path),
    }


def collect_results(results_root: Path) -> pd.DataFrame:
    rows = []

    for cfg_dir in sorted(results_root.glob("cfg*")):
        if not cfg_dir.is_dir():
            continue

        intra_dir = cfg_dir / "intra"
        inter_dir = cfg_dir / "inter"

        if intra_dir.exists():
            for path in sorted(intra_dir.glob("*.json")):
                row = parse_intra_file(path)
                if row:
                    rows.append(row)

        if inter_dir.exists():
            for path in sorted(inter_dir.glob("*.json")):
                row = parse_inter_file(path)
                if row:
                    rows.append(row)

    if not rows:
        raise FileNotFoundError(
            f"No matching JSON files found under {results_root}. "
            f"Expected cfg*/intra/*.json and/or cfg*/inter/*.json"
        )

    df = pd.DataFrame(rows)
    return df.sort_values(["config_num", "experiment", "bs_kib", "jobs"]).reset_index(drop=True)


def cfg_sort_key(cfg_label: str):
    num = parse_cfg_num(cfg_label)
    if num in CFG_ORDER:
        return CFG_ORDER.index(num)
    return 9999 if num is None else num


def prettify_axes():
    plt.xticks(fontsize=FONT_SIZE, fontweight="bold")
    plt.yticks(fontsize=FONT_SIZE, fontweight="bold")
    plt.grid(True, alpha=0.35)
    plt.legend(fontsize=FONT_SIZE)


def plot_intra(df: pd.DataFrame, out_dir: Path):
    intra = df[df["experiment"] == "intra"].copy()
    if intra.empty:
        print("No intra data found; skipping intra plots.")
        return

    intra["bs"] = pd.Categorical(intra["bs"], categories=BS_ORDER, ordered=True)
    intra = intra.sort_values(["config_num", "bs"])

    metrics = [
        ("bandwidth_mib_s", "Bandwidth (MiB/s)", "intra_bandwidth_vs_bs.png"),
        ("iops", "IOPS", "intra_iops_vs_bs.png"),
        ("latency_us", "Average latency (us)", "intra_latency_vs_bs.png"),
    ]

    for metric, ylabel, filename in metrics:
        plt.figure(figsize=(11, 7))

        for cfg, g in sorted(intra.groupby("config"), key=lambda x: cfg_sort_key(x[0])):
            g = g.sort_values("bs")
            plt.plot(
                g["bs"].astype(str),
                g[metric],
                marker="o",
                linewidth=LINEWIDTH,
                markersize=MARKERSIZE,
                label=CFG_LABELS.get(cfg, cfg),
            )

        plt.xlabel("Block size", fontsize=FONT_SIZE, fontweight="bold")
        plt.ylabel(ylabel, fontsize=FONT_SIZE, fontweight="bold")
        plt.title(f"Intra-zone: {ylabel} vs Block size", fontsize=TITLE_SIZE, fontweight="bold")
        plt.ylim(bottom=0)
        prettify_axes()
        plt.tight_layout()
        plt.savefig(out_dir / filename, dpi=250)
        plt.close()


def plot_inter(df: pd.DataFrame, out_dir: Path):
    inter = df[df["experiment"] == "inter"].copy()
    if inter.empty:
        print("No inter data found; skipping inter plots.")
        return

    inter = inter.sort_values(["config_num", "jobs"])

    metrics = [
        ("bandwidth_mib_s", "Bandwidth (MiB/s)", "inter_bandwidth_vs_jobs.png"),
        ("iops", "IOPS", "inter_iops_vs_jobs.png"),
        ("latency_us", "Average latency (us)", "inter_latency_vs_jobs.png"),
    ]

    for metric, ylabel, filename in metrics:
        # Linear version: starts from 0
        plt.figure(figsize=(11, 7))

        for cfg, g in sorted(inter.groupby("config"), key=lambda x: cfg_sort_key(x[0])):
            g = g.sort_values("jobs")
            plt.plot(
                g["jobs"],
                g[metric],
                marker="o",
                linewidth=LINEWIDTH,
                markersize=MARKERSIZE,
                label=CFG_LABELS.get(cfg, cfg),
            )

        plt.xlabel("Number of jobs", fontsize=FONT_SIZE, fontweight="bold")
        plt.ylabel(ylabel, fontsize=FONT_SIZE, fontweight="bold")
        plt.title(f"Inter-zone: {ylabel} vs Jobs", fontsize=TITLE_SIZE, fontweight="bold")
        plt.xlim(left=0)
        plt.ylim(bottom=0)
        plt.xticks(sorted(inter["jobs"].dropna().unique()))
        prettify_axes()
        plt.tight_layout()
        plt.savefig(out_dir / filename, dpi=250)
        plt.close()

        # Log-log version: cannot start from 0
        log_filename = filename.replace(".png", "_loglog.png")

        plt.figure(figsize=(11, 7))

        for cfg, g in sorted(inter.groupby("config"), key=lambda x: cfg_sort_key(x[0])):
            g = g.sort_values("jobs")
            g = g[(g["jobs"] > 0) & (g[metric] > 0)]
            plt.plot(
                g["jobs"],
                g[metric],
                marker="o",
                linewidth=LINEWIDTH,
                markersize=MARKERSIZE,
                label=CFG_LABELS.get(cfg, cfg),
            )

        plt.xlabel("Number of jobs", fontsize=FONT_SIZE, fontweight="bold")
        plt.ylabel(ylabel, fontsize=FONT_SIZE, fontweight="bold")
        plt.title(f"Inter-zone: {ylabel} vs Jobs (log-log)", fontsize=TITLE_SIZE, fontweight="bold")
        plt.xscale("log", base=2)
        plt.yscale("log")
        plt.xticks([1, 2, 4, 8, 16], [1, 2, 4, 8, 16])
        prettify_axes()
        plt.grid(True, which="both", alpha=0.35)
        plt.tight_layout()
        plt.savefig(out_dir / log_filename, dpi=250)
        plt.close()


def main():
    if len(sys.argv) > 1:
        results_root = Path(sys.argv[1]).resolve()
    else:
        results_root = Path(__file__).resolve().parent

    out_dir = results_root / "plots"
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"Scanning results under: {results_root}")
    df = collect_results(results_root)

    csv_path = out_dir / "summary.csv"
    df.to_csv(csv_path, index=False)
    print(f"Saved summary CSV: {csv_path}")

    plot_intra(df, out_dir)
    plot_inter(df, out_dir)

    print(f"Plots saved under: {out_dir}")
    print("Done.")


if __name__ == "__main__":
    main()