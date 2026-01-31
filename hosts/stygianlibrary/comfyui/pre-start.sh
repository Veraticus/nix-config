#!/bin/bash
set -eu

CUSTOM_NODES_DIR="/root/ComfyUI/custom_nodes"

echo "========================================"
echo "[INFO] ComfyUI Pre-Start Configuration"
echo "========================================"

# ============================================
# 1. ATTENTION OPTIMIZATIONS (install first!)
# ============================================
# Must be installed BEFORE nodes load to be detected

echo "[INFO] Installing SageAttention..."
pip install -q sageattention

echo "[INFO] Installing Flash Attention (pre-built wheel)..."
pip install -q "https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.7.16/flash_attn-2.8.3+cu128torch2.10-cp312-cp312-linux_x86_64.whl"

# ============================================
# 2. CUSTOM NODE INSTALLATION
# ============================================

install_node() {
    local name="$1"
    local repo="$2"
    local dir="${CUSTOM_NODES_DIR}/${name}"

    if [ ! -d "$dir" ]; then
        echo "[INFO] Installing ${name}..."
        git clone --depth 1 "$repo" "$dir"

        # Install node requirements if they exist
        if [ -f "${dir}/requirements.txt" ]; then
            echo "[INFO] Installing ${name} requirements..."
            pip install -q -r "${dir}/requirements.txt"
        fi
    fi
}

# Core nodes for WAN 2.2 I2V workflow
install_node "ComfyUI-WanVideoWrapper" "https://github.com/kijai/ComfyUI-WanVideoWrapper"
install_node "ComfyUI-GGUF" "https://github.com/city96/ComfyUI-GGUF"
install_node "ComfyUI-VideoHelperSuite" "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"

# Upscaling nodes
install_node "ComfyUI-SeedVR2_VideoUpscaler" "https://github.com/AInVFX/ComfyUI-SeedVR2_VideoUpscaler"
install_node "ComfyUI_UltimateSDUpscale" "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
install_node "ComfyUI-VideoUpscale_WithModel" "https://github.com/gokayfem/ComfyUI-VideoUpscale_WithModel"

# Frame interpolation
install_node "ComfyUI-Frame-Interpolation" "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"

# Memory management
install_node "ComfyUI-Unload-Model" "https://github.com/Mircoxi/ComfyUI-Unload-Model"
install_node "Comfyui-Memory_Cleanup" "https://github.com/Haoming02/Comfyui-Memory_Cleanup"

# Advanced samplers (ClownsharkSampler for better prompt adherence)
install_node "RES4LYF" "https://github.com/ClownsharkBatwing/RES4LYF"

# ============================================
# 3. NODE DEPENDENCIES
# ============================================

echo "[INFO] Installing node dependencies..."
pip install -q rotary_embedding_torch einops omegaconf diffusers peft gguf

# SeedVR2 specific deps
pip install -q accelerate safetensors

# Frame interpolation deps (RIFE)
pip install -q cupy-cuda12x

# ============================================
# 4. CLI FLAGS
# ============================================

export CLI_ARGS="--use-sage-attention"

echo "========================================"
echo "[INFO] Pre-start complete!"
echo "[INFO] CLI_ARGS: ${CLI_ARGS}"
echo "========================================"
