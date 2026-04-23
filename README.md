# TRACE — Full Pipeline

TRACE is an end-to-end system for automated 2-D surface thickness scanning using a stepper-motor-driven XY stage, an analog displacement sensor, and MATLAB for data acquisition and cross-sectional area analysis.

---

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Host PC                              │
│                                                             │
│   ArduinoDataAcquisition.m  ──►  scan_data.txt             │
│          │  (serial)                    │                   │
│          │                             ▼                    │
│          │                        csa_gui.m                 │
│          │                   (area / volume / 3D)           │
└──────────┼──────────────────────────────────────────────────┘
           │ COM / USB
┌──────────▼──────────────────────────────────────────────────┐
│                        Arduino                              │
│                                                             │
│  StepperMotorFullMotion.ino   ◄──  'G' command             │
│  StepperMotorController.ino   ◄──  W / A / S / D (manual)  │
│                                                             │
│  X stepper ── Y stepper ── Analog sensor (A0)              │
└─────────────────────────────────────────────────────────────┘
```

The two Arduino sketches are **loaded separately** depending on the mode needed (automated scan vs. manual stage jogging). The two MATLAB files are run in sequence: acquisition first, then the GUI for analysis.

---

## Repository Structure

```
.
├── StepperMotorFullMotion.ino    # Arduino: automated boustrophedon raster scan
├── StepperMotorController.ino   # Arduino: manual toggle control (stage jogging / setup)
├── ArduinoDataAcquisition.m     # MATLAB: serial trigger + data capture to .txt
└── csa_gui.m                    # MATLAB: cross-sectional area & volume analysis GUI
```

---

## Hardware Requirements

| Component | Notes |
|---|---|
| Arduino (Uno / Mega) | Tested at 9600 baud |
| 2× Stepper motor + driver | A4988 or DRV8825 compatible; active-low EN pin |
| Analog displacement sensor | Outputs 0–5 V; wired to `A0` |
| XY linear stage | Belt or lead-screw driven |
| USB cable | Arduino ↔ host PC |

### Pin Assignments (both sketches)

| Signal | Pin |
|---|---|
| X Enable | 8 |
| X Step | 9 |
| X Direction | 10 |
| Y Enable | 5 |
| Y Step | 6 |
| Y Direction | 7 |
| Sensor (analog) | A0 |

---

## Software Requirements

| Tool | Version |
|---|---|
| Arduino IDE | 1.8+ or 2.x |
| MATLAB | R2019b or later |
| MATLAB toolboxes | None (base MATLAB only) |

---

## File Reference

### `StepperMotorFullMotion.ino` — Automated Scan

Flash this sketch when running a full acquisition. It waits for a `'G'` command over Serial, then performs a boustrophedon (snake-path) raster scan of the XY stage, sampling the analog sensor at each step and streaming `x_mm y_mm thickness_mm` triples back to the host.

**Key parameters (edit at top of file):**

| Constant | Default | Meaning |
|---|---|---|
| `X_STEP_SIZE` | `160` | Micro-steps per X increment |
| `Y_STEP_SIZE` | `3200` | Micro-steps per Y increment |
| `X_STEPS_TOTAL` | `300 × X_STEP_SIZE` | Total X travel |
| `Y_STEPS_TOTAL` | `15 × Y_STEP_SIZE` | Total Y travel |
| `STEP_DELAY` | `300 µs` | Pulse interval (controls speed) |
| `MM_PER_STEP` | `0.000625` | Stage calibration |
| `V_ZERO` | `2.49 V` | Sensor zero-offset voltage |
| `MM_PER_V` | `32.26` | Sensor sensitivity |
| `V_SATURATED` | `4.95 V` | Readings at or above this → `NaN` |

**Serial commands:**

| Command | Action |
|---|---|
| `G` | Start raster scan |
| `E` | Enable motors |
| `D` | Disable motors |

After the scan finishes, the stage returns to the origin automatically and the Arduino prints `FINISHED`.

---

### `StepperMotorController.ino` — Manual Toggle Control

Flash this sketch for stage setup, alignment, or sensor verification. Motors move continuously while a direction is active; sending the same key a second time stops that axis.

**Serial commands (case-insensitive):**

| Key | Action |
|---|---|
| `W` | Y axis — move down (toggle) |
| `S` | Y axis — move up (toggle) |
| `A` | X axis — move right (toggle) |
| `D` | X axis — move left (toggle) |
| `E` | Enable both motors |
| `H` | Disable both motors |

Speed is set by `stepDelay` (default `300 µs`). Open the Serial Monitor at **9600 baud** to send commands and read status messages.

---

### `ArduinoDataAcquisition.m` — MATLAB Data Capture

Connects to the Arduino over Serial, triggers a scan, captures all data lines, and writes them to `scan_data.txt`.

**Settings (edit at top of script):**

| Variable | Default | Meaning |
|---|---|---|
| `port` | `"COM5"` | Serial port of the Arduino |
| `baudRate` | `9600` | Must match the Arduino sketch |
| `fileName` | `"scan_data.txt"` | Output file path |

**Output file format:**
```
x_mm y_mm thickness_mm
0.0000 0.0000 0.0861
0.1000 0.0000 0.1042
...
```

The script ignores `STARTING_SCAN` status lines and stops recording when it receives `FINISHED`.

> **Note:** Change `"COM5"` to the correct port for your system (e.g. `"COM3"` on Windows, `"/dev/ttyUSB0"` on Linux, `"/dev/cu.usbmodem..."` on macOS).

---

### `csa_gui.m` — Cross-Sectional Area Analysis GUI

Loads the scan data file produced above and performs cross-sectional area and volume analysis via a graphical dashboard.

**Launch:**
```matlab
csa_gui
```

**Workflow:**
1. Click **Select Input File** and choose the `scan_data.txt` produced by `ArduinoDataAcquisition.m`.
2. The plot, stats strip, data table, and total volume label populate automatically.
3. Optionally click **Show 3D Model** for a rendered thickness surface.
4. Click **Save Area Data...** to export the per-slice area table as a `.txt` report.

**Key parameters (edit at top of `cb_load`):**

| Constant | Default | Effect |
|---|---|---|
| `Nintp` | `50` | Interpolation resolution along Y |
| `THRESHOLD` | `0.5` | Thickness ≤ this treated as zero (noise floor) |

---

## Typical Workflow

```
1. Flash StepperMotorController.ino
   └─ Use Serial Monitor to home / align the stage

2. Flash StepperMotorFullMotion.ino
   └─ Verify sensor reads correctly at rest

3. In MATLAB, run ArduinoDataAcquisition.m
   └─ Outputs: scan_data.txt

4. In MATLAB, run csa_gui
   └─ Load scan_data.txt → inspect area plot, 3D model, volume
   └─ Export area report if needed
```

---

## Calibration

All sensor calibration is contained in `StepperMotorFullMotion.ino`. To recalibrate for a different sensor or stage:

1. Measure the sensor output voltage at a known zero-thickness reference → update `V_ZERO`.
2. Measure at a known thickness target → recompute `MM_PER_V = thickness_mm / (V_measured - V_ZERO)`.
3. Measure stage travel per full step sequence → update `MM_PER_STEP`.
4. Adjust `THRESHOLD` in `csa_gui.m` to match the new noise floor.

---

## License

MIT — see [LICENSE](LICENSE) for details.
