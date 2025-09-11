# Spinal Cord WFA and PV Analysis Project

## Project Overview

This project is an automated image analysis system for analyzing WFA (Wisteria Floribunda Agglutinin) and PV (Parvalbumin) markers in spinal cord regions. The system uses machine learning methods for cell detection, classification, and colocalization analysis of fluorescence microscopy images.

## Project Structure

```
matlab/
├── P1_prepareMouseFolder.m          # Data preprocessing: folder preparation and image flipping
├── P2_prepareMasks_Otsu.m           # Mask generation: automatic brain slice mask generation using Otsu method
├── P3_prepareXmlFiles.m             # Metadata creation: generate XML information files
├── P5_batchEditSliceMask.m          # Mask editing: batch edit slice masks
├── rf01_generateTrainingImages.m    # Training data generation: extract training images
├── rf02_trainRandomForestModel.m    # Model training: train random forest classifier
├── A1_batchQuantifyDots.m           # Dot fluorescence analysis: cell detection and quantification
├── A2_batchQuantifyDiffuse.m        # Diffuse fluorescence analysis: regional fluorescence intensity analysis
├── A3_colocalizationAnalysis.m      # Colocalization analysis: WFA and PV colocalization analysis
├── process_rawData.py               # Python data preprocessing script
└── utilities/                       # Utility function library
    ├── allSlicesFromXml.m           # XML file parsing
    ├── binarizeWFA.m                # WFA channel binarization
    ├── binarizePV.m                 # PV channel binarization
    ├── cellClassifier.m             # Cell classifier
    ├── cellLabeler.m                # Cell labeling tool
    ├── extractSubImage.m            # Sub-image extraction
    ├── listfiles.m                  # File list retrieval
    ├── simpleReconstruct.m          # Simple reconstruction
    └── Slice.m                      # Slice class definition
```

## Execution Workflow

### Phase 1: Data Preprocessing (P-series scripts)

#### 1. P1_prepareMouseFolder.m
**Function**: Prepare mouse data folder structure
- Create necessary directory structure (hiRes, thumbnails, masks, etc.)
- Handle image flipping (based on anatomical orientation)
- Separate multi-channel images
- Generate thumbnails

**Execution Order**: Run first
**Input**: Raw TIFF image files
**Output**: Organized folder structure and separated channel images

#### 2. P2_prepareMasks_Otsu.m
**Function**: Automatic brain slice mask generation
- Use Otsu thresholding method
- Automatically detect brain tissue boundaries
- Generate binary mask files

**Execution Order**: After P1
**Input**: Thumbnail files
**Output**: Mask files (PNG format)

#### 3. P3_prepareXmlFiles.m
**Function**: Create metadata files
- Generate miceData.xlsx (mouse information table)
- Create -info.xml files (slice metadata)

**Execution Order**: After P2
**Input**: Folder structure and image information
**Output**: XML metadata files

#### 4. P5_batchEditSliceMask.m
**Function**: Batch mask editing
- Preprocess masks (denoising, hole filling)
- Provide mask editing interface

**Execution Order**: After P3 (optional)
**Input**: Mask files
**Output**: Optimized mask files

### Phase 2: Model Training (RF-series scripts)

#### 5. rf01_generateTrainingImages.m
**Function**: Generate training data
- Randomly extract cell images from dataset
- Support multi-channel processing (WFA, PV)
- Generate labeling interface for manual annotation

**Execution Order**: After P5
**Input**: High-resolution images and cell count files
**Output**: Training images and annotation files

#### 6. rf02_trainRandomForestModel.m
**Function**: Train random forest classifier
- Train independent classifiers for each channel
- Use annotated training data
- Save trained models

**Execution Order**: After rf01
**Input**: Training images and annotations
**Output**: Trained model files (.mat)

### Phase 3: Data Analysis (A-series scripts)

#### 7. A1_batchQuantifyDots.m
**Function**: Dot fluorescence analysis
- Detect and quantify individual cells
- Calculate cell position, size, fluorescence intensity
- Generate cell count data

**Execution Order**: After rf02
**Input**: High-resolution images and trained models
**Output**: Cell quantification data (CSV files)

#### 8. A2_batchQuantifyDiffuse.m
**Function**: Diffuse fluorescence analysis
- Analyze regional fluorescence intensity
- Calculate average fluorescence density
- Quantify background fluorescence

**Execution Order**: After A1
**Input**: High-resolution images
**Output**: Regional fluorescence data (CSV files)

#### 9. A3_colocalizationAnalysis.m
**Function**: Colocalization analysis
- Analyze WFA and PV colocalization
- Calculate colocalization rates
- Classify cell types

**Execution Order**: After A1 and A2
**Input**: Cell quantification data
**Output**: Colocalization analysis results (CSV files)

## Statistics and Calculation Formulas

### A1_batchQuantifyDots.m Statistics

**Output CSV file contains the following statistics:**

1. **Cell Position** (x, y)
   - Calculation Formula: Cell centroid coordinates
   - Physical Meaning: Spatial position of cells in the image

2. **Cell Area** (areaPx)
   - Calculation Formula: `areaPx = sum(mask(:))`
   - Physical Meaning: Cell area in pixel units

3. **Mean Fluorescence Intensity** (fluoMean)
   - Calculation Formula: `fluoMean = mean(image(mask))`
   - Physical Meaning: Average fluorescence signal intensity in cell region

4. **Median Fluorescence Intensity** (fluoMedian)
   - Calculation Formula: `fluoMedian = median(image(mask))`
   - Physical Meaning: Median fluorescence intensity in cell region, more robust to outliers

5. **Maximum Fluorescence Intensity** (fluoMax)
   - Calculation Formula: `fluoMax = max(image(mask))`
   - Physical Meaning: Maximum fluorescence signal in cell region

6. **Fluorescence Intensity Standard Deviation** (fluoStd)
   - Calculation Formula: `fluoStd = std(image(mask))`
   - Physical Meaning: Variability of fluorescence signals within cells

### A2_batchQuantifyDiffuse.m Statistics

**Output CSV file contains the following statistics:**

1. **Regional Area** (areaPx, areaMm2)
   - Calculation Formula: `areaPx = sum(mask(:))`, `areaMm2 = areaPx * (pixelSize/1000)²`
   - Physical Meaning: Area of analysis region (pixels and square millimeters)

2. **Total Fluorescence Intensity** (diffFluo)
   - Calculation Formula: `diffFluo = sum(image(mask))`
   - Physical Meaning: Sum of fluorescence intensity of all pixels in the region

3. **Average Pixel Intensity** (avgPxIntensity)
   - Calculation Formula: `avgPxIntensity = diffFluo / areaPx`
   - Physical Meaning: Average fluorescence intensity per unit area

4. **Slice Average Fluorescence** (avgFluo)
   - Calculation Formula: `avgFluo = mean(sliceFluo)`
   - Physical Meaning: Average fluorescence intensity of the entire slice

### A3_colocalizationAnalysis.m Statistics

**Output CSV file contains the following statistics:**

1. **Colocalized Cell Count** (num_colocalized)
   - Calculation Formula: `num_colocalized = sum(distance < minDist)`
   - Physical Meaning: Number of WFA and PV cell pairs with distance below threshold

2. **Colocalization Rate** (colocalization_rate)
   - Calculation Formula: `colocalization_rate = num_colocalized / total_cells * 100`
   - Physical Meaning: Percentage of colocalized cells relative to total cell count

3. **Cell Classification Statistics**
   - WFA+PV+: Colocalized cells
   - WFA+PV-: WFA-positive only cells
   - WFA-PV+: PV-positive only cells

4. **Distance Analysis** (minDistances)
   - Calculation Formula: `minDistances = min(pdist2(coord_pv, coord_wfa))`
   - Physical Meaning: Euclidean distance between nearest neighbor cells

## Configuration

### Path Configuration
All scripts require configuration of the following paths:
- `base_path`: Project root directory
- `mouse`: Mouse ID
- `defaultFolder`: Dataset directory
- `outputFolder`: Results output directory

### Parameter Configuration
- `channels`: Channels to analyze (e.g., ["wfa", "pv"])
- `minDist`: Colocalization distance threshold (pixels)
- `cellSize`: Cell extraction size (pixels)
- `pixelSize`: Pixel size (micrometers)

## Dependencies

- MATLAB R2019b or higher
- Image Processing Toolbox
- Statistics and Machine Learning Toolbox
- Python 3.x (for process_rawData.py)

## Important Notes

1. Ensure all path configurations are correct
2. Run scripts in the specified order
3. Check intermediate output files
4. Adjust parameters according to actual data
5. Regularly backup important data

## Technical Support

If you encounter issues, please check:
1. Whether file paths are correct
2. Whether dependencies are installed
3. Whether data format meets requirements
4. Whether parameter settings are reasonable


