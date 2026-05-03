# ZNS Device-Level Experiments

This folder contains the scripts, results, and plotting code used to evaluate ZNS SSD behavior under different device configurations.

# 🔧 IMPORTANT SETUP NOTE (VERY IMPORTANT)

A custom `zns.c` file is included in this repository.

## 📍 Location in repo:
```
zns.c
```

## 📍 Where to place it in FEMU:
```
confznsplusplus/hw/femu/zns/zns.c
```

## 🔁 What to do:
Replace the existing file in FEMU:

```bash
cp zns.c ~/confznsplusplus/hw/femu/zns/zns.c
```

## 🔨 Then rebuild FEMU:

```bash
cd ~/confznsplusplus
make clean
make -j
```

# 📁 Folder Structure

```
device-level-experiments/
├── device-results/16core/
│   ├── cfg*/
│   ├── phase3/
│   ├── phase3_history/
│   ├── phase3_trace/
│   ├── plots/
│   ├── plot_phase3.py
│   ├── plot_phase3_history.py
│   └── plots_inter_intra.py
│
├── zns-scripts/
│   ├── SCC-scripts/
│   └── VM-scripts/
│       ├── inter-intra/
│       └── reset-experiments/
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

---

# ⚙️ EXPERIMENT 1: INTRA-ZONE

## Goal
Understand how performance scales *within a single zone*.

## Run (inside VM)

```bash
cd ~/zns-scripts

./run-intra.sh 0 128M
./run-intra.sh 10 64M
./run-intra.sh 18 32M
```

## Output
```
/home/femu/zns-results/cfg*/intra/
```

---

# ⚙️ EXPERIMENT 2: INTER-ZONE

## Goal
Understand how performance scales *across multiple zones*.

## Run

```bash
./run-inter.sh 0 128M
./run-inter.sh 10 64M
./run-inter.sh 18 32M
```

---

# ⚙️ EXPERIMENT 3: RESET LATENCY (HISTORY EFFECT)

## Goal
Compare:
- Fresh reset
- Filled → reset

## Compile

```bash
gcc phase3_reset_write.c -o phase3_reset_write   -I$HOME/libnvme/src   -L$HOME/libnvme/.build/src   -lnvme
```

## Run

```bash
./run_phase3.sh 0 134217728 5
./run_phase3.sh 10 67108864 5
./run_phase3.sh 18 33554432 5
```

---

# ⚙️ EXPERIMENT 4: TRANSIENT LATENCY TRACE

## Goal
Observe latency after reset spike.

## Compile

```bash
gcc phase3_trace_write.c -o phase3_trace_write   -I$HOME/libnvme/src   -L$HOME/libnvme/.build/src   -lnvme
```

## Run

```bash
./run_phase3_trace.sh 0 134217728 5
./run_phase3_trace.sh 10 67108864 5
./run_phase3_trace.sh 18 33554432 5
```

---

## Run plots

```bash
cd device-results/16core

python3 plots_inter_intra.py .
python3 plot_phase3.py
python3 plot_phase3_history.py
```

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

# ✨ NOTE

All experiments assume:
- FEMU configured correctly
- zns.c replaced before build
- VM running corresponding configuration

# Final Takeaway

ZNS performance is highly dependent on how zones map to internal SSD resources. Smaller zones provide stronger intra-zone performance, while larger zones rely more on inter-zone concurrency. Reset behavior is history-dependent, but the penalty is mostly transient.
