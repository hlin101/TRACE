# Cross-Sectional Area Analysis Dashboard

A MATLAB GUI for computing per-slice cross-sectional area and total volume from 3D thickness scan data (e.g. washer or part surface scans exported as CSV point clouds).

---

## Features

- **CSV ingestion** — reads boustrophedon-ordered scan files with automatic delimiter detection (comma, tab, or space)
- **Noise floor thresholding** — suppresses sub-threshold readings before integration
- **Per-Y cross-sectional area** — computed via the trapezoidal rule (`trapz`) at each unique Y position
- **1-D cubic interpolation** — smooth area-vs-Y curve fitted through the discrete slice data
- **Total volume** — integrated over all Y slices using `trapz`
- **Interactive plot** — bar chart of per-slice area overlaid with the interpolated curve
- **Data table** — right-hand panel listing all non-zero (Y, Area) pairs
- **3D surface viewer** — separate figure with interpolated thickness surface, Gouraud shading, and `jet` colormap
- **Report export** — saves the (Y, Area) table to a plain-text `.txt` file

---

## Requirements

| Requirement | Version |
|---|---|
| MATLAB | R2019b or later (App Designer `uifigure` API) |
| Toolboxes | None required beyond base MATLAB |

> `griddata` (used in the 3D viewer) is part of base MATLAB. No additional toolboxes are needed.

---

## Input File Format

The input must be a **CSV or TXT file** with the following structure:

```
x_mm,y_mm,thickness_mm
12.50,0.00,0.0000
12.75,0.00,0.1823
...
```

| Column | Description |
|---|---|
| `x_mm` | X coordinate of the scan point (mm) |
| `y_mm` | Y coordinate / slice position (mm) |
| `thickness_mm` | Measured thickness at that point (mm) |

- The **header row is required** and is skipped automatically.
- Scan order within each Y-slice does not matter — points are sorted by X before integration.
- Trailing blank lines and NaN rows are dropped automatically.

---

## Getting Started

1. Clone or download this repository.
2. Open MATLAB and navigate to the project folder.
3. Run the GUI:
   ```matlab
   csa_gui
   ```
4. Click **Select Input File** and choose your `.csv` or `.txt` scan file.
5. The plot, table, and volume label populate automatically.

---

## Usage

### Main Dashboard

| Control | Action |
|---|---|
| **Select Input File** | Opens a file browser; loads and analyses the selected scan |
| **Show 3D Model** | Opens a separate figure with the reconstructed thickness surface |
| **Save Area Data...** | Prompts for a save location and writes the area report to `*_area.txt` |

### Area vs Y Plot

- **Blue bars** — trapezoidal area computed at each discrete Y slice
- **Red line** — 1-D cubic interpolant (falls back to linear if cubic fails)

### Stats Strip

Displays the mean cross-sectional area across all non-zero slices.

### 3D Surface Figure

Rendered with `griddata` (natural-neighbour interpolation) on a 120×120 grid. Zero and sub-threshold cells are masked to `NaN` so no flat zero-plane appears in the surface.

---

## Configuration

Two constants near the top of `cb_load` (inside `csa_gui.m`) control analysis behaviour:

| Constant | Default | Effect |
|---|---|---|
| `Nintp` | `50` | Number of interpolation points along Y |
| `THRESHOLD` | `0.5` | Thickness values ≤ this are set to zero before integration |

Adjust `THRESHOLD` to match the noise floor of your specific scanner.

---

## Output Report Format

Clicking **Save Area Data** writes a tab-delimited text file:

```
% Y-position(mm)  Area(mm2)
0.0000	14.231500
1.0000	15.874200
...
```

Only slices with non-zero area are included, matching the on-screen table.

---

## Project Structure

```
.
└── csa_gui.m          # Single-file MATLAB application
```

---

## License

MIT — see [LICENSE](LICENSE) for details.
