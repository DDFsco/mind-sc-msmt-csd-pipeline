# Linux quickstart

```bash
git clone https://github.com/DDFsco/mind-sc-msmt-csd-pipeline.git
cd mind-sc-msmt-csd-pipeline

# If Docker is available:
# docker pull martah/sc-construction-using-msmt-csd

# If Docker is not available but Apptainer/Singularity is:
./scripts/build_apptainer_image.sh sc-construction-using-msmt-csd.sif
export SC_MSMT_CSD_SIF=$PWD/sc-construction-using-msmt-csd.sif

export FS_LICENSE=/path/to/freesurfer/license.txt
export PE_DIR=AP
export TCK_SELECT=100k

./scripts/preflight.sh /path/to/ds007857 sub-mindb107 ses-placebo

./scripts/run_mind_subject.sh \
  /path/to/ds007857 \
  sub-mindb107 \
  ses-placebo \
  /scratch/mind-sc
```

Expected final output:

```text
/scratch/mind-sc/derivatives/sub-mindb107_ses-placebo/dk.csv
```
