# Helix for monome norns

**Helix** is a 3-layer DNA-inspired generative sequencer and ambient drone engine designed for **monome norns** (and norns shield). It visualizes sequence data as a 3D double-helix structure on the screen, sending MIDI notes and synchronized CC data to external hardware synthesizers (such as the SONICWARE LIVEN Ambient Ø) while running a lush internal ambient drone engine simultaneously.

---

## Features

* **3-Layer DNA Sequencer**: Inspired by genetic base pairs (A, T, G, C) with automatic complement pairing and mutation features.
* **Internal Ambient Drone Engine (`Engine_Helix`)**: A built-in SuperCollider engine featuring detuned oscillators, Moog-style filtering, and a dynamic drone buildup linked to sequence activity.
* **Multi-Channel MIDI Output**: Routes Helix 1, 2, and 3 to MIDI channels 1, 2, and 3 respectively.
* **Configurable MIDI CC Sync**: Automatically modulates external hardware parameters (Filter Cutoff, Release, Shimmer, etc.) based on the internal drone buildup. CC numbers are fully customizable via the PARAMS menu.
* **3D Spatial Visualization**: Real-time wireframe ribbon rendering with reactive particles and a central read head.

---

## Hardware & Software Requirements

* **monome norns** (or norns shield) running a recent OS version.
* **External MIDI Synth / Sound Module** (Optional, e.g., LIVEN Ambient Ø, Arturia MicroFreak, etc.) connected via USB or TRS MIDI.

---

## Installation

You can install Helix directly from Maiden using the `;install` command:

1. Open Maiden in your browser (`http://norns.local` or via your norns' IP address).
2. Run the following command in the Maiden console:
   ```text
   ;install [https://github.com/sumik-svg/helix](https://github.com/sumik-svg/helix)
   ```
3. Once the installation finishes, restart your norns (or run `;restart` in the console) to compile the SuperCollider engine (`Engine_Helix.sc`).

---

## Controls & Navigation

### Encoders
* **E1**: Continuous Master Tempo / Base Speed (Helixes 2 & 3 follow Helix 1 proportionally).
* **E2**: Harmonic Scale Shift (Selects root notes within the Pentatonic scale).
* **E3**: Phase Drift (Introduces individual timing drift/swing per layer).

### Keys
* **K3**: Select active Helix layer (`Helix 1` -> `Helix 2` -> `Helix 3`).
* **K2**: Start / Stop the selected Helix layer. (Starting Helix 1 triggers the ambient drone buildup).
* **K1 (Hold) + E2**: Change Root Key (`C` ~ `B`).
* **K1 (Hold) + K2**: Smooth phase synchronization back to Helix 1.
* **K1 (Hold) + K3**: Mutation (Shuffles DNA sequence data across all layers).

---

## PARAMS Menu Configuration

Under the norns **PARAMS** menu, you can customize:
* **MIDI Device**: Select your MIDI output port.
* **Drone CC Sync**: Toggle automatic CC transmission (`Off` / `On`).
* **CC 1 / 2 / 3 Number**: Remap MIDI CC numbers to match your external synthesizer's architecture (Default: CC 38, 41, 55 for LIVEN Ambient Ø).
* **Internal Pluck Voice**: Toggle internal SuperCollider pluck voices alongside MIDI output (`Off (MIDI Only)` / `On (Dual)`).
* **Root Key**: Select global root key.

---

## License

This project is open-source and available under the [MIT License](LICENSE).
