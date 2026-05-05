# plotPmtDataB3 Usage Guide

This MATLAB function analyzes Photomultiplier Tube (PMT) TIFF image data across different voltage/gain settings. It pairs signal and background images, applies a zero-point offset correction (using the darkest 1% of pixels), performs background subtraction, and generates statistical plots and histograms.

## Required Folder Structure
The script requires a main directory containing two subdirectories: `background` and `signal`. Files must be in TIFF format and named according to their voltage/gain (e.g., `40v.tif`). A background file and its corresponding signal file must have the **exact same name**.

    mainPath/
    ├── background/
    │   ├── 40v.tif
    │   ├── 45v.tif
    │   └── 50v.tif
    └── signal/
        ├── 40v.tif
        ├── 45v.tif
        └── 50v.tif

## Basic Usage
To run the script with default settings, simply provide the path to the main directory containing your `background` and `signal` folders:

    mainPath = 'C:\Path\To\Your\Data';
    plotPmtDataB3(mainPath);

## Advanced Usage
You can customize the analysis and plotting by passing optional Name-Value parameters:

    plotPmtDataB3('C:\Path\To\Your\Data', ...
        'GainRange', [40, 60], ...
        'ColorScheme', 'plasma', ...
        'ShowMode', true, ...
        'SamplingRate', 0.5, ...
        'CullZeros', true);

## Optional Parameters

* **GainRange** `[min, max]` : Restricts the analysis to a specific range of voltages (e.g., `[40, 50]`). Default: Analyzes all matched files found.
* **FrameRange** `[start, end]` : Frame indices to read from multi-page TIFFs. Default: Reads all frames.
* **SamplingRate** `(0.0 to 1.0)` : Fraction of pixels to randomly sample for histograms to save memory on massive datasets. Default: `1.0` (all pixels).
* **CullZeros** `(true/false)` : Removes exact zero values from the corrected data before plotting/stats. Default: `true`.
* **ColorScheme** : Colormap for histograms. Options: `'viridis'`, `'plasma'`, `'turbo'`, `'rainbow'`, `'hot'`, `'cool'`, `'default'`. Default: `'viridis'`.
* **Alpha** `(0.0 to 1.0)` : Transparency of histogram bars. Default: `0.3`.
* **ShowMode** `(true/false)` : Draws a vertical dashed line at the statistical mode of each histogram. Default: `false`.
* **LineWidth** : Thickness of the mode lines. Default: `1.5`.
* **FontSize** : Base font size for plots. Default: `12`.
* **FigureTitle** : Custom text prepended to the figure titles. Default: Auto-generated based on the path.

## Outputs
1. **Console Summary:** Prints the Mean, Standard Deviation, Minimum, and Maximum corrected pixel intensities for each processed gain.
2. **Figure 1 (Histograms):** A log-scale histogram overlaying the corrected pixel intensity distributions for all processed gains.
3. **Figure 2 (Gain Analysis):** A 2x2 grid plotting Mean vs. Gain, Standard Deviation vs. Gain, Mean/Std Ratio vs. Gain, and the number of processed pairs.
