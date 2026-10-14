/* Test-only readback of the archived backend's GPU presentation blit. */
#include MGS_LEGACY_BACKEND
#include <assert.h>

unsigned char *MgsLegacyGpuCapture(int *width, int *height)
{
    *width = requested_window_size.w;
    *height = requested_window_size.h;
    Draw_FlushBuffer();
    SDL_GPUTextureCreateInfo texture_info = {
        .type = SDL_GPU_TEXTURETYPE_2D,
        .format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
        .usage = SDL_GPU_TEXTUREUSAGE_COLOR_TARGET | SDL_GPU_TEXTUREUSAGE_SAMPLER,
        .width = (Uint32)*width, .height = (Uint32)*height,
        .layer_count_or_depth = 1, .num_levels = 1
    };
    SDL_GPUTexture *output = SDL_CreateGPUTexture(device, &texture_info);
    assert(output);
    SDL_GPUCommandBuffer *cmd = AcquireCmd();
    assert(cmd);
    SDL_Rect destination = FitGameToWindow(
        GetCurrentGameAspectRatio(display_size.x, display_size.y), requested_window_size);
    SDL_GPUBlitInfo blit = {
        .source = {.texture = GetRenderTarget(),
            .x = (Uint32)display_area.x * internal_res, .y = (Uint32)display_area.y * internal_res,
            .w = (Uint32)display_size.x * internal_res,
            .h = (presentation_source_height ? presentation_source_height : (Uint32)display_size.y) * internal_res},
        .destination = {.texture = output, .x = (Uint32)destination.x, .y = (Uint32)destination.y,
            .w = (Uint32)destination.w, .h = (Uint32)destination.h},
        .load_op = SDL_GPU_LOADOP_CLEAR, .clear_color = {0, 0, 0, 1},
        .filter = presentation_width ? SDL_GPU_FILTER_LINEAR : SDL_GPU_FILTER_NEAREST
    };
    SDL_BlitGPUTexture(cmd, &blit);
    SDL_GPUTransferBufferCreateInfo transfer_info = {
        .usage = SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD, .size = (Uint32)(*width * *height * 4)
    };
    SDL_GPUTransferBuffer *transfer = SDL_CreateGPUTransferBuffer(device, &transfer_info);
    assert(transfer);
    SDL_GPUCopyPass *copy = SDL_BeginGPUCopyPass(cmd);
    SDL_GPUTextureRegion region = {.texture = output, .w = (Uint32)*width, .h = (Uint32)*height, .d = 1};
    SDL_GPUTextureTransferInfo target = {.transfer_buffer = transfer};
    SDL_DownloadFromGPUTexture(copy, &region, &target);
    SDL_EndGPUCopyPass(copy);
    SubmitCmdAndWait();
    const unsigned char *rgba = SDL_MapGPUTransferBuffer(device, transfer, false);
    unsigned char *rgb = malloc((size_t)*width * *height * 3);
    assert(rgba && rgb);
    for (int pixel = 0; pixel < *width * *height; ++pixel)
        memcpy(rgb + pixel * 3, rgba + pixel * 4, 3);
    SDL_UnmapGPUTransferBuffer(device, transfer);
    SDL_ReleaseGPUTransferBuffer(device, transfer);
    SDL_ReleaseGPUTexture(device, output);
    return rgb;
}
