#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  echo "Usage: run_protocol_no_reverse_pe.sh <raw_dir> <derivatives_dir> <subject_id>" >&2
  echo "Environment: PE_DIR=AP|PA|LR|RL|IS|SI, TCK_SELECT=100k|1m|10m, FS_OPENMP=4" >&2
  exit 1
fi

RAWDIR=$1
DERIVDIR=$2
SUBJECTID=$3
PE_DIR="${PE_DIR:-AP}"
TCK_SELECT="${TCK_SELECT:-100k}"
FS_OPENMP="${FS_OPENMP:-4}"
BIAS_BACKEND="${BIAS_BACKEND:-ants}"
EDDY_OPTIONS="${EDDY_OPTIONS:- --repol --slm=linear --data_is_shelled}"

progress() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1/14] $2"
}

find_mrtrix_fs_default() {
  local candidate
  for candidate in \
    "${MRTRIX_FS_DEFAULT:-}" \
    /opt/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt \
    /usr/local/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt \
    /usr/share/mrtrix3/labelconvert/fs_default.txt; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  if command -v labelconvert >/dev/null 2>&1; then
    local prefix
    prefix="$(cd "$(dirname "$(command -v labelconvert)")/.." && pwd)"
    candidate="${prefix}/share/mrtrix3/labelconvert/fs_default.txt"
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  fi

  return 1
}

if [[ ! -f "${RAWDIR}/dwi.mif" || ! -f "${RAWDIR}/T1w.mif" ]]; then
  echo "Required raw inputs not found. Expected ${RAWDIR}/dwi.mif and ${RAWDIR}/T1w.mif" >&2
  exit 1
fi

mkdir -p "$DERIVDIR"
export SUBJECTS_DIR="${MIND_SUBJECTS_DIR:-${DERIVDIR}/subjects}"
mkdir -p "$SUBJECTS_DIR"
MRTRIX_FS_DEFAULT="$(find_mrtrix_fs_default)" || {
  echo "MRtrix fs_default.txt was not found. Set MRTRIX_FS_DEFAULT to its full path." >&2
  exit 1
}

progress 2 "FreeSurfer recon-all"
echo "Using SUBJECTS_DIR=${SUBJECTS_DIR}"
mrconvert "${RAWDIR}/T1w.mif" "${DERIVDIR}/T1w.nii" -force

if [[ -f "${SUBJECTS_DIR}/${SUBJECTID}/scripts/recon-all.done" ]]; then
  echo "Reusing completed FreeSurfer subject: ${SUBJECTS_DIR}/${SUBJECTID}"
else
  recon-all -s "${SUBJECTID}" -i "${DERIVDIR}/T1w.nii" -all -openmp "$FS_OPENMP"
fi
rm -rf "${DERIVDIR}/freesurfer"
cp -r "${SUBJECTS_DIR}/${SUBJECTID}" "${DERIVDIR}/freesurfer"

progress 3 "DWI denoise"
dwidenoise "${RAWDIR}/dwi.mif" "${DERIVDIR}/dwi_den.mif" \
  -noise "${DERIVDIR}/noise.mif" -force

progress 4 "Remove Gibbs ringing"
mrdegibbs "${DERIVDIR}/dwi_den.mif" "${DERIVDIR}/dwi_den_unr.mif" -force

# The MiND BIDS release does not include reverse phase-encoding b=0 images
# or fieldmaps. This uses eddy without topup-based susceptibility correction.
progress 5 "DWI eddy preprocessing without reverse PE"
dwifslpreproc "${DERIVDIR}/dwi_den_unr.mif" "${DERIVDIR}/dwi_den_unr_preproc.mif" \
  -pe_dir "$PE_DIR" -rpe_none \
  -eddy_options "$EDDY_OPTIONS" -force

progress 6 "DWI bias correction (${BIAS_BACKEND})"
dwibiascorrect "$BIAS_BACKEND" "${DERIVDIR}/dwi_den_unr_preproc.mif" "${DERIVDIR}/dwi_den_unr_preproc_bc.mif" \
  -bias "${DERIVDIR}/bias.mif" -force

progress 7 "Extract mean b0"
dwiextract "${DERIVDIR}/dwi_den_unr_preproc_bc.mif" - -bzero | \
  mrmath - mean "${DERIVDIR}/mean_b0_preproc.nii" -axis 3 -force

progress 8 "T1 bias correction"
T1_BC="${DERIVDIR}/T1w_bc.nii"
if command -v N4BiasFieldCorrection >/dev/null 2>&1; then
  N4BiasFieldCorrection -d 3 -i "${DERIVDIR}/T1w.nii" -s 2 -o "$T1_BC"
elif command -v fast >/dev/null 2>&1; then
  fast -B -o "${DERIVDIR}/T1w_fast" "${DERIVDIR}/T1w.nii"
  T1_BC="${DERIVDIR}/T1w_fast_restore.nii.gz"
else
  echo "Neither N4BiasFieldCorrection nor FSL fast was found for T1 bias correction." >&2
  exit 1
fi

progress 9 "Register DWI to T1"
flirt -in "${DERIVDIR}/mean_b0_preproc.nii" -ref "$T1_BC" \
  -dof 6 -cost normmi \
  -omat "${DERIVDIR}/diff2struct_fsl.mat"

transformconvert "${DERIVDIR}/diff2struct_fsl.mat" "${DERIVDIR}/mean_b0_preproc.nii" \
  "$T1_BC" flirt_import "${DERIVDIR}/diff2struct_mrtrix.txt" -force

mrtransform "${DERIVDIR}/dwi_den_unr_preproc_bc.mif" "${DERIVDIR}/dwi_den_unr_preproc_bc_coreg.mif" \
  -linear "${DERIVDIR}/diff2struct_mrtrix.txt" -force

progress 10 "Create DWI mask"
dwi2mask "${DERIVDIR}/dwi_den_unr_preproc_bc_coreg.mif" "${DERIVDIR}/dwi_mask.mif" -force

progress 11 "Estimate response functions"
dwi2response dhollander "${DERIVDIR}/dwi_den_unr_preproc_bc_coreg.mif" \
  "${DERIVDIR}/wm.txt" "${DERIVDIR}/gm.txt" "${DERIVDIR}/csf.txt" \
  -voxels "${DERIVDIR}/voxels.mif" -force

progress 12 "MSMT-CSD and intensity normalisation"
dwi2fod msmt_csd "${DERIVDIR}/dwi_den_unr_preproc_bc_coreg.mif" \
  -mask "${DERIVDIR}/dwi_mask.mif" \
  "${DERIVDIR}/wm.txt" "${DERIVDIR}/wmfod.mif" \
  "${DERIVDIR}/gm.txt" "${DERIVDIR}/gm.mif" \
  "${DERIVDIR}/csf.txt" "${DERIVDIR}/csf.mif" -force

mtnormalise -mask "${DERIVDIR}/dwi_mask.mif" \
  "${DERIVDIR}/wmfod.mif" "${DERIVDIR}/wmfod_norm.mif" \
  "${DERIVDIR}/gm.mif" "${DERIVDIR}/gm_norm.mif" \
  "${DERIVDIR}/csf.mif" "${DERIVDIR}/csf_norm.mif" \
  -check_factors "${DERIVDIR}/check_factors.txt" \
  -check_norm "${DERIVDIR}/check_norm.mif" \
  -check_mask "${DERIVDIR}/check_mask.mif" -force

progress 13 "5TT, tractography, and SIFT2"
5ttgen hsvs "${DERIVDIR}/freesurfer" "${DERIVDIR}/5tt.mif" -force

tckgen "${DERIVDIR}/wmfod_norm.mif" "${DERIVDIR}/tracks_${TCK_SELECT}.tck" \
  -algorithm ifod2 -select "$TCK_SELECT" \
  -act "${DERIVDIR}/5tt.mif" -backtrack \
  -seed_dynamic "${DERIVDIR}/wmfod_norm.mif" -force

tcksift2 "${DERIVDIR}/tracks_${TCK_SELECT}.tck" "${DERIVDIR}/wmfod_norm.mif" "${DERIVDIR}/sift2_weights.txt" \
  -act "${DERIVDIR}/5tt.mif" \
  -out_mu "${DERIVDIR}/sift2_mu.txt" -force

progress 14 "Build connectome"
labelconvert "${DERIVDIR}/freesurfer/mri/aparc+aseg.mgz" \
  "${FREESURFER_HOME}/FreeSurferColorLUT.txt" \
  "$MRTRIX_FS_DEFAULT" \
  "${DERIVDIR}/DK_parcels.mif" -force

tck2connectome "${DERIVDIR}/tracks_${TCK_SELECT}.tck" "${DERIVDIR}/DK_parcels.mif" "${DERIVDIR}/dk.csv" \
  -symmetric -zero_diagonal \
  -tck_weights_in "${DERIVDIR}/sift2_weights.txt" \
  -out_assignments "${DERIVDIR}/dk_assignments.txt" -force

echo "Finished ${SUBJECTID}; connectome written to ${DERIVDIR}/dk.csv"
