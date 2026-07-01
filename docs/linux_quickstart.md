# Linux quickstart

```bash
git clone https://github.com/DDFsco/mind-sc-msmt-csd-pipeline.git
cd mind-sc-msmt-csd-pipeline

# If Docker is available:
# docker pull martah/sc-construction-using-msmt-csd

# If Docker is not available but Apptainer/Singularity is:
./scripts/build_apptainer_image.sh sc-construction-using-msmt-csd.sif
export SC_MSMT_CSD_SIF=$PWD/sc-construction-using-msmt-csd.sif

# If no container runtime is available, use native mode only if MRtrix3,
# FSL, FreeSurfer, and either ANTs or the FSL bias-correction fallback
# are already installed:
# export CONTAINER_RUNTIME=native
# source scripts/setup_env.sh

export FS_LICENSE=/usr/local/freesurfer-6.0.0/license.txt
export PE_DIR=AP
export TCK_SELECT=100k
export BIAS_BACKEND=ants

# If ANTs is unavailable but FSL is installed:
# export BIAS_BACKEND=fsl

./scripts/preflight.sh /nfs/tpolk/mind/Echo/openneuro/bids sub-mindb107 ses-placebo

./scripts/run_mind_subject.sh \
  /nfs/tpolk/mind/Echo/openneuro/bids \
  sub-mindb107 \
  ses-placebo \
  /scratch/mind-sc
```

Expected final output:

```text
/scratch/mind-sc/derivatives/sub-mindb107_ses-placebo/dk.csv
```
