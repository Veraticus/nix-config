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

# Face identity preservation (Stand-In)
install_node "Stand-In_Preprocessor_ComfyUI" "https://github.com/WeChatCV/Stand-In_Preprocessor_ComfyUI"

# IPAdapter for identity-preserving generation (SDXL FaceID)
install_node "ComfyUI_IPAdapter_plus" "https://github.com/cubiq/ComfyUI_IPAdapter_plus"

# Impact Pack (FaceDetailer for targeted face regeneration)
install_node "ComfyUI-Impact-Pack" "https://github.com/ltdrdata/ComfyUI-Impact-Pack"

# Qwen Edit Utils (fixes ghosting with to_ref control)
install_node "Comfyui-QwenEditUtils" "https://github.com/lrzjason/Comfyui-QwenEditUtils"

# LayerStyle (MaskGrow for mask-based face editing)
install_node "ComfyUI_LayerStyle" "https://github.com/chflame163/ComfyUI_LayerStyle"

# RMBG (FaceSegment for face masking)
install_node "ComfyUI-RMBG" "https://github.com/1038lab/ComfyUI-RMBG"

# AutoCropFaces (automatic face detection and cropping)
install_node "ComfyUI-AutoCropFaces" "https://github.com/liusida/ComfyUI-AutoCropFaces"

# ControlNet Auxiliary Preprocessors (depth, pose, canny, etc.)
install_node "comfyui_controlnet_aux" "https://github.com/Fannovel16/comfyui_controlnet_aux"

# Impact Pack submodule (UltralyticsDetectorProvider for face detection)
# Must be installed as a top-level custom node to be discovered
install_node "ComfyUI-Impact-Subpack" "https://github.com/ltdrdata/ComfyUI-Impact-Subpack"

# ============================================
# 3. NODE DEPENDENCIES
# ============================================

echo "[INFO] Installing node dependencies..."
pip install -q rotary_embedding_torch einops omegaconf diffusers peft gguf

# SeedVR2 specific deps
pip install -q accelerate safetensors

# Frame interpolation deps (RIFE)
pip install -q cupy-cuda12x

# Stand-In face identity deps
pip install -q insightface onnxruntime-gpu

# RES4LYF (ClownsharkSampler) deps
pip install -q pywavelets opencv-python matplotlib

# IPAdapter FaceID deps
pip install -q insightface onnxruntime-gpu

# Impact Pack deps (ultralytics for face detection)
pip install -q ultralytics segment-anything

# ============================================
# 4. MODEL DOWNLOADS
# ============================================

MODELS_DIR="/root/ComfyUI/models"

download_model() {
    local path="$1"
    local url="$2"
    local name="$3"

    if [ ! -f "${MODELS_DIR}/${path}" ]; then
        echo "[INFO] Downloading ${name}..."
        mkdir -p "$(dirname "${MODELS_DIR}/${path}")"
        curl -L -o "${MODELS_DIR}/${path}" "$url"
    fi
}

# Qwen Image Edit 2511 (photo identity correction)
download_model "diffusion_models/qwen-image-edit-2511-Q4_K_M.gguf" \
    "https://huggingface.co/Comfy-Org/Qwen-Image-Edit-2511_GGUF/resolve/main/qwen-image-edit-2511-Q4_K_M.gguf" \
    "Qwen Image Edit 2511 GGUF"

download_model "text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "https://huggingface.co/Comfy-Org/Qwen_VL_2.5-7B_Instruct_fp8_scaled/resolve/main/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
    "Qwen 2.5 VL 7B FP8 text encoder"

download_model "vae/qwen_image_vae.safetensors" \
    "https://huggingface.co/Comfy-Org/Qwen-Image-Edit-2511_GGUF/resolve/main/qwen_image_vae.safetensors" \
    "Qwen Image VAE"

download_model "loras/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors" \
    "https://huggingface.co/makisekurisu/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors" \
    "Qwen Lightning LoRA"

# Skin realism LoRA (adds pores, texture)
download_model "loras/qwen-edit-skin.safetensors" \
    "https://huggingface.co/tlennon-ie/qwen-edit-skin/resolve/main/qwen-edit-skin.safetensors" \
    "Qwen Skin Realism LoRA"

# Beauty LoRA (skin tone/lighting balance)
download_model "loras/Qwen_majic_beauty.safetensors" \
    "https://huggingface.co/Lingyuzhou/Qwen_majic_beauty/resolve/main/QWEN_%E9%BA%A6%E6%A9%98%E5%8D%83%E9%97%AE%E7%BE%8E%E4%BA%BA.safetensors" \
    "Qwen Beauty LoRA"

# ControlNet Union for Qwen (depth/structure preservation)
download_model "controlnet/Qwen-Image-InstantX-ControlNet-Union.safetensors" \
    "https://huggingface.co/Comfy-Org/Qwen-Image-InstantX-ControlNets/resolve/main/split_files/controlnet/Qwen-Image-InstantX-ControlNet-Union.safetensors" \
    "Qwen ControlNet Union"

# FaceDetailer models (Impact Pack)
download_model "ultralytics/bbox/face_yolov8m.pt" \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt" \
    "Face YOLO Detector"

download_model "sams/sam_vit_b_01ec64.pth" \
    "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth" \
    "SAM ViT-B Model"

# SeedVR2 upscaler model (FP8 version - smaller, fits in VRAM better)
download_model "diffusion_models/seedvr2_ema_7b_fp8_e4m3fn.safetensors" \
    "https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/seedvr2_ema_7b_fp8_e4m3fn.safetensors" \
    "SeedVR2 7B FP8"

# ============================================
# 5. CLI FLAGS
# ============================================

export CLI_ARGS="--use-pytorch-cross-attention"

echo "========================================"
echo "[INFO] Pre-start complete!"
echo "[INFO] CLI_ARGS: ${CLI_ARGS}"
echo "========================================"
