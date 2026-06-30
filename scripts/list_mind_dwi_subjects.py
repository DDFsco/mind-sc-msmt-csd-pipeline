#!/usr/bin/env python3
import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="List MiND/BIDS subject sessions with DWI and T1w inputs."
    )
    parser.add_argument("bids_dir", type=Path)
    parser.add_argument("--session", default="ses-placebo")
    args = parser.parse_args()

    def present(path: Path) -> bool:
        return path.exists() or path.is_symlink()

    print("subject\tsession\tdwi_path\tt1w_path\tbvec\tbval\tjson")
    for sub_dir in sorted(args.bids_dir.glob("sub-*")):
        ses_dir = sub_dir / args.session
        if not ses_dir.exists():
            continue
        subject = sub_dir.name
        session = args.session
        base = f"{subject}_{session}"
        dwi = ses_dir / "dwi" / f"{base}_dwi.nii.gz"
        bvec = ses_dir / "dwi" / f"{base}_dwi.bvec"
        bval = ses_dir / "dwi" / f"{base}_dwi.bval"
        dwi_json = ses_dir / "dwi" / f"{base}_dwi.json"
        t1w = ses_dir / "anat" / f"{base}_T1w.nii.gz"
        values = [
            subject,
            session,
            str(present(dwi)),
            str(present(t1w)),
            str(present(bvec)),
            str(present(bval)),
            str(present(dwi_json)),
        ]
        if present(dwi) or present(t1w):
            print("\t".join(values))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
