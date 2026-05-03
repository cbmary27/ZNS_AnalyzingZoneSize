# ZNS Device-Level Experiments

This repository contains the scripts, results, and plotting code used to evaluate ZNS SSD behavior under different device configurations.

## Folder Structure

```
device-level-experiments/
├── device-results/
│   └── 16core/
│       ├── cfg0/
│       ├── cfg1/
│       ├── cfg10/
│       ├── cfg11/
│       ├── cfg18/
│       ├── cfg19/
│       ├── phase3/
│       ├── phase3_history/
│       ├── phase3_trace/
│       ├── plots/
│       ├── plot_phase3.py
│       ├── plot_phase3_history.py
│       └── plots_inter_intra.py
│
├── zns-scripts/
│   ├── SCC-scripts/
│   │   └── run-zns-configs.sh
│   └── VM-scripts/
│       ├── inter-intra/
│       │   ├── run-inter.sh
│       │   └── run-intra.sh
│       └── reset-experiments/
│           ├── phase3_reset_write.c
│           ├── phase3_trace_write.c
│           ├── run_phase3.sh
│           ├── run_phase3_history.sh
│           └── run_phase3_trace.sh
│
└── zns.c
```

---

# Overview

The experiments study how ZNS SSD performance changes with different zone configurations.

The main configurations used were:

| Config | Parallelism Label | Description |
|---|---:|---|
| cfg0 | P=16 | Highest internal parallelism |
| cfg10 | P=8 | Medium internal parallelism |
| cfg18 | P=4 | Lowest internal parallelism |

---

# Key Findings

## Intra-zone
Performance within a zone improves as block size increases until the stripe size is utilized. Higher-parallelism configurations achieve higher throughput.

## Inter-zone
Adding more jobs improves performance only until zone-level parallelism is saturated.

## Reset cost
Reset plus first write latency is significantly higher after prior zone writes.

## Transient behavior
The post-reset penalty is short-lived. The first write after reset is slower, but later writes stabilize quickly.

---

# Final Takeaway

ZNS performance is highly dependent on how zones map to internal SSD resources. Smaller zones provide stronger intra-zone performance, while larger zones rely more on inter-zone concurrency. Reset behavior is history-dependent, but the penalty is mostly transient.
