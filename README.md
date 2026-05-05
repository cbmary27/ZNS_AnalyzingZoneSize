# ZNS: Analyzing Zone Size in ZNS SSDs

This project studies how **zone size impacts performance in Zoned Namespace (ZNS) SSDs**, across both device-level and application-level workloads.

We evaluate how different configurations affect:
- Throughput and latency
- Intra-zone and inter-zone parallelism
- Zone reset behavior
- Write amplification and space amplification (via RocksDB + ZenFS)

---

# Project Overview

ZNS SSDs expose internal storage structure (zones) to the host. The size of these zones directly impacts how efficiently the SSD can utilize its internal parallelism.

This project analyzes these effects using:
- **FEMU + ConfZNS++** → for device-level experiments
- **RocksDB + ZenFS** → for application-level experiments

We evaluate three configurations:

| Config | Parallelism | Zone Size |
|-------|------------|----------|
| cfg0  | P=16       | 128 MiB  |
| cfg10 | P=8        | 64 MiB   |
| cfg18 | P=4        | 32 MiB   |

---

# Setup Instructions
## 1. Clone ConfZNS++ (FEMU-based ZNS Emulator)

Clone: https://github.com/stonet-research/confznsplusplus

Follow the installation steps: https://github.com/MoatLab/FEMU  

---

# Experiments

This project is divided into two main components:

---

## Device-Level Experiments

We use **FEMU + FIO** to analyze raw ZNS device behavior under different configurations.

These experiments evaluate:
- Intra-zone performance (block size scaling)
- Inter-zone performance (concurrency scaling)
- Zone reset cost (history-dependent latency)
- Transient latency behavior after reset

👉 Detailed setup, scripts, and instructions:  
➡️ [Device-Level Experiments](device-level-experiments/Device-Level-Experiments.md)

---

## Application-Level Experiments

We use **RocksDB with ZenFS** to evaluate system-level impact of zone size.

These experiments analyze:
- Write Amplification (WA)
- Space Amplification (SA)
- End-to-end latency and throughput

👉 Detailed setup, scripts, and instructions:  
➡️ [Application-Level Experiments](application-level-experiments/Application-Level-Experiments.md)

---
