# MiND structural connectome pipeline

This repository adapts the protocol code from
`martahedl/SC-construction-using-MSMT-CSD` for the MiND BIDS dataset
(`ds007857`) and similar local BIDS layouts.

The original protocol expects three MRtrix `.mif` inputs:

```text
raw/
  dwi.mif
  b0_pa.mif
  T1w.mif
```

The MiND dataset instead provides BIDS DWI files:

```text
sub-*/ses-placebo/dwi/*_dwi.nii.gz
sub-*/ses-placebo/dwi/*_dwi.bvec
sub-*/ses-placebo/dwi/*_dwi.bval
sub-*/ses-placebo/dwi/*_dwi.json
sub-*/ses-placebo/anat/*_T1w.nii.gz
```

MiND does not currently include reverse phase-encoding b=0 images or
fieldmaps. This adapted pipeline therefore uses `dwifslpreproc -rpe_none`
instead of the original `-rpe_pair` topup workflow.

## Requirements

- Linux machine with one of:
  - Docker, or
  - Apptainer/Singularity
- FreeSurfer license file
- Local BIDS copy of the MiND dataset, or the equivalent DWI/T1w files
- Container image:

Docker:
```bash
docker pull martah/sc-construction-using-msmt-csd
```

Apptainer/Singularity:
```bash
./scripts/build_apptainer_image.sh sc-construction-using-msmt-csd.sif
export SC_MSMT_CSD_SIF=$PWD/sc-construction-using-msmt-csd.sif
```

Set:

```bash
export FS_LICENSE=/path/to/license.txt
```

Optional settings:

```bash
export PE_DIR=AP
export TCK_SELECT=100k
export FS_OPENMP=4
```

Use `TCK_SELECT=100k` for smoke testing. Use `1m` or `10m` only after a
single subject runs successfully.

## Check Available Subjects

```bash
./scripts/list_mind_dwi_subjects.py /path/to/ds007857 > dwi_subjects.tsv
```

The output columns show whether each subject/session has DWI, T1w, bvec,
bval, and JSON sidecar files.

## Preflight

```bash
./scripts/preflight.sh /path/to/ds007857 sub-mindb107 ses-placebo
```

This checks that a supported container runtime, FreeSurfer license, DWI files,
and T1w input are available.

## Run One Subject

```bash
export FS_LICENSE=/path/to/license.txt
export PE_DIR=AP
export TCK_SELECT=100k

./scripts/run_mind_subject.sh \
  /path/to/ds007857 \
  sub-mindb107 \
  ses-placebo \
  /scratch/mind-sc
```

Outputs are written to:

```text
/scratch/mind-sc/raw/sub-mindb107_ses-placebo/
/scratch/mind-sc/derivatives/sub-mindb107_ses-placebo/
```

The main connectome matrix is:

```text
/scratch/mind-sc/derivatives/sub-mindb107_ses-placebo/dk.csv
```

## Run A Cohort

Create a subject list:

```bash
./scripts/list_mind_dwi_subjects.py /path/to/ds007857 \
  | awk -F '\t' 'NR > 1 && $3=="True" && $4=="True" && $5=="True" && $6=="True" {print $1}' \
  > subjects_with_dwi_t1.txt
```

Then run:

```bash
export FS_LICENSE=/path/to/license.txt
export PE_DIR=AP
export TCK_SELECT=100k

./scripts/run_mind_cohort.sh /path/to/ds007857 /scratch/mind-sc < subjects_with_dwi_t1.txt
```

## Important Caveats

- Confirm the true phase encoding direction for the DWI acquisition. The
  default is `PE_DIR=AP`, but the BIDS sidecars in `ds007857` do not currently
  contain `PhaseEncodingDirection`.
- Because no reverse PE b=0 or fieldmap image is available, this workflow does
  not perform topup-based susceptibility distortion correction.
- `TCK_SELECT=100k` is for testing. Full protocol-like tractography should use
  a larger number, such as `10m`, after validation.
- The original `run_protocol.sh` is preserved for reference but is not the
  recommended entry point for MiND.
