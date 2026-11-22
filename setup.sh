#!/usr/bin/env bash
# One-step setup of the UCEA "cea" environment on Linux.
# Run from the repo root:  bash setup.sh
set -euo pipefail

ENV_NAME="cea"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONSTRAINTS="$REPO_DIR/constraints.txt"
GPKG="$REPO_DIR/cea/resources/radiation/INE_com_NPAV_norm0.gpkg"
WEIGHTS="$REPO_DIR/ultralytics/best.pt"

step() { echo; echo "==> $*"; }
in_env() { conda run -n "$ENV_NAME" --no-capture-output "$@"; }

command -v conda >/dev/null || { echo "conda not found. Install Miniforge first."; exit 1; }

step "Checking conda-lock"
if ! conda run -n base conda-lock --version >/dev/null 2>&1; then
    conda install -y -n base -c conda-forge conda-lock
fi

step "Creating the '$ENV_NAME' environment from conda-lock.yml"
if conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
    echo "Environment '$ENV_NAME' already exists, skipping. Remove it with: conda env remove -n $ENV_NAME"
else
    conda run -n base --no-capture-output conda-lock install --name "$ENV_NAME" "$REPO_DIR/conda-lock.yml"
fi

step "Installing PyTorch"
if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
    echo "NVIDIA GPU found: installing CUDA build from PyPI"
    in_env python -m pip install torch torchvision -c "$CONSTRAINTS"
else
    echo "No NVIDIA GPU found: installing CPU build"
    in_env python -m pip install torch torchvision -c "$CONSTRAINTS" \
        --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple
fi

step "Installing UCEA and its bundled ultralytics copy"
in_env python -m pip uninstall -y ultralytics >/dev/null 2>&1 || true
in_env python -m pip install -e "$REPO_DIR" -c "$CONSTRAINTS"
# compat mode puts the folder on sys.path via a .pth file. The default editable mode loses to
# the outer ultralytics/ folder (seen as a namespace package) when Python runs from the repo root.
in_env python -m pip install -e "$REPO_DIR/ultralytics" -c "$CONSTRAINTS" --config-settings editable_mode=compat

step "Checking data files"
missing=0
[ -f "$WEIGHTS" ] || { echo "MISSING: $WEIGHTS (YOLO roof weights)"; missing=1; }
[ -f "$GPKG" ] || { echo "MISSING: $GPKG (download from the SharePoint link in the README)"; missing=1; }

step "Verifying"
in_env python -c "import numpy, cv2, torch, torchvision, ultralytics; print('numpy', numpy.__version__, '| opencv', cv2.__version__, '| torch', torch.__version__, '| torchvision', torchvision.__version__); print('ultralytics from', ultralytics.__file__)"
if [ -f "$WEIGHTS" ]; then
    in_env python -c "from ultralytics import YOLO; print('model task:', YOLO(r'$WEIGHTS').task)"
fi

echo
if [ "$missing" -eq 0 ]; then
    echo "Done. Run: conda activate $ENV_NAME && cea ucea --scenario ~/ucea_runs/<name>"
else
    echo "Environment ready, but add the missing files above before running cea ucea."
fi
