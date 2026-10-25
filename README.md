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
