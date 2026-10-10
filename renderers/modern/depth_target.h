#ifndef MGS_MODERN_DEPTH_TARGET_H
#define MGS_MODERN_DEPTH_TARGET_H

static void ReleaseGeometryDepth(void)
{
    if (geometry_depth) SDL_ReleaseGPUTexture(device, geometry_depth);
    geometry_depth = NULL;
    geometry_depth_scale = 0;
    clear_geometry_depth = true;
}

static SDL_GPUDepthStencilTargetInfo GeometryDepthTarget(void)
{
    if (!geometry_depth || geometry_depth_scale != internal_res) {
        ReleaseGeometryDepth();
        const SDL_GPUTextureCreateInfo info = {
            .type = SDL_GPU_TEXTURETYPE_2D,
            .format = SDL_GPU_TEXTUREFORMAT_D32_FLOAT,
            .usage = SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET,
            .width = VRAM_W * internal_res,
            .height = VRAM_H * internal_res,
            .layer_count_or_depth = 1,
            .num_levels = 1,
        };
        geometry_depth = SDL_CreateGPUTexture(device, &info);
        if (!geometry_depth) {
            ERRORF("Cannot allocate geometry depth buffer: %s", SDL_GetError());
            exit(EXIT_FAILURE);
        }
        geometry_depth_scale = internal_res;
    }
    SDL_GPUDepthStencilTargetInfo target = {
        .texture = geometry_depth,
        .clear_depth = 0,
        .load_op = clear_geometry_depth ? SDL_GPU_LOADOP_CLEAR : SDL_GPU_LOADOP_LOAD,
        .store_op = SDL_GPU_STOREOP_STORE,
        .stencil_load_op = SDL_GPU_LOADOP_DONT_CARE,
        .stencil_store_op = SDL_GPU_STOREOP_DONT_CARE,
    };
    clear_geometry_depth = false;
    return target;
}

#endif
