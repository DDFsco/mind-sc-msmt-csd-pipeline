# Linux quickstart

```bash
git clone <your-github-url>/mind-sc-msmt-csd-pipeline.git
cd mind-sc-msmt-csd-pipeline

docker pull martah/sc-construction-using-msmt-csd

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
