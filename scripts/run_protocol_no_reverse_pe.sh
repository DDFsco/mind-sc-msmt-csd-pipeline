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

if [[ ! -f "${RAWDIR}/dwi.mif" || ! -f "${RAWDIR}/T1w.mif" ]]; then
  echo "Required raw inputs not found. Expected ${RAWDIR}/dwi.mif and ${RAWDIR}/T1w.mif" >&2
  exit 1
fi

mkdir -p "$DERIVDIR"

mrconvert "${RAWDIR}/T1w.mif" "${DERIVDIR}/T1w.nii" -force

recon-all -s "${SUBJECTID}" -i "${DERIVDIR}/T1w.nii" -all -openmp "$FS_OPENMP"
rm -rf "${DERIVDIR}/freesurfer"
cp -r "${SUBJECTS_DIR}/${SUBJECTID}" "${DERIVDIR}/freesurfer"

dwidenoise "${RAWDIR}/dwi.mif" "${DERIVDIR}/dwi_den.mif" \
  -noise "${DERIVDIR}/noise.mif" -force

mrdegibbs "${DERIVDIR}/dwi_den.mif" "${DERIVDIR}/dwi_den_unr.mif" -force

# The MiND BIDS release does not include reverse phase-encoding b=0 images
# or fieldmaps. This uses eddy without topup-based susceptibility correction.
dwifslpreproc "${DERIVDIR}/dwi_den_unr.mif" "${DERIVDIR}/dwi_den_unr_preproc.mif" \
  -pe_dir "$PE_DIR" -rpe_none \
  -eddy_options " --repol" -force

dwibiascorrect ants "${DERIVDIR}/dwi_den_unr_preproc.mif" "${DERIVDIR}/dwi_den_unr_preproc_bc.mif" \
  -bias "${DERIVDIR}/bias.mif" -force

dwiextract "${DERIVDIR}/dwi_den_unr_preproc_bc.mif" - -bzero | \
  mrmath - mean "${DERIVDIR}/mean_b0_preproc.nii" -axis 3 -force

N4BiasFieldCorrection -d 3 -i "${DERIVDIR}/T1w.nii" -s 2 -o "${DERIVDIR}/T1w_bc.nii"

flirt -in "${DERIVDIR}/mean_b0_preproc.nii" -ref "${DERIVDIR}/T1w_bc.nii" \
  -dof 6 -cost normmi \
  -omat "${DERIVDIR}/diff2struct_fsl.mat"

transformconvert "${DERIVDIR}/diff2struct_fsl.mat" "${DERIVDIR}/mean_b0_preproc.nii" \
  "${DERIVDIR}/T1w_bc.nii" flirt_import "${DERIVDIR}/diff2struct_mrtrix.txt" -force

mrtransform "${DERIVDIR}/dwi_den_unr_preproc_bc.mif" "${DERIVDIR}/dwi_den_unr_preproc_bc_coreg.mif" \
  -linear "${DERIVDIR}/diff2struct_mrtrix.txt" -force

dwi2mask "${DERIVDIR}/dwi_den_unr_preproc_bc_coreg.mif" "${DERIVDIR}/dwi_mask.mif" -force

dwi2response dhollander "${DERIVDIR}/dwi_den_unr_preproc_bc_coreg.mif" \
  "${DERIVDIR}/wm.txt" "${DERIVDIR}/gm.txt" "${DERIVDIR}/csf.txt" \
  -voxels "${DERIVDIR}/voxels.mif" -force

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

5ttgen hsvs "${DERIVDIR}/freesurfer" "${DERIVDIR}/5tt.mif" -force

tckgen "${DERIVDIR}/wmfod_norm.mif" "${DERIVDIR}/tracks_${TCK_SELECT}.tck" \
  -algorithm ifod2 -select "$TCK_SELECT" \
  -act "${DERIVDIR}/5tt.mif" -backtrack \
  -seed_dynamic "${DERIVDIR}/wmfod_norm.mif" -force

tcksift2 "${DERIVDIR}/tracks_${TCK_SELECT}.tck" "${DERIVDIR}/wmfod_norm.mif" "${DERIVDIR}/sift2_weights.txt" \
  -act "${DERIVDIR}/5tt.mif" \
  -out_mu "${DERIVDIR}/sift2_mu.txt" -force

labelconvert "${DERIVDIR}/freesurfer/mri/aparc+aseg.mgz" \
  "${FREESURFER_HOME}/FreeSurferColorLUT.txt" \
  /opt/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt \
  "${DERIVDIR}/DK_parcels.mif" -force

tck2connectome "${DERIVDIR}/tracks_${TCK_SELECT}.tck" "${DERIVDIR}/DK_parcels.mif" "${DERIVDIR}/dk.csv" \
  -symmetric -zero_diagonal \
  -tck_weights_in "${DERIVDIR}/sift2_weights.txt" \
  -out_assignments "${DERIVDIR}/dk_assignments.txt" -force

echo "Finished ${SUBJECTID}; connectome written to ${DERIVDIR}/dk.csv"
