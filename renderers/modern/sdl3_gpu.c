// SPDX-License-Identifier: MPL-2.0
// Derived from Xeeynamo/PsyZ; see README.md for the pinned source and patch baseline.
#include <psyz.h>
#include <psyz/overlay.h>
#include <psyz/overlay_sdl3_gpu.h>
#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <math.h>
#include "internal.h"
#include <SDL3/SDL.h>
#define PSYZ_CUSTOM_PRESENTATION
#define PSYZ_GPU_DEBUG_TEXT
#include "sdl3_common.h"
#include "sdl3_draw.h"
#include "sdl3_gpu_debug.h"

#if defined(_WIN32)
#include "shaders/psx_vert_dxil.h"
#include "shaders/psx_frag_dxil.h"
#include "shaders/clear_vert_dxil.h"
#include "shaders/clear_frag_dxil.h"
#define psx_vert psx_vert_dxil
#define psx_vert_len psx_vert_dxil_len
#define psx_frag psx_frag_dxil
#define psx_frag_len psx_frag_dxil_len
#define clear_vert clear_vert_dxil
#define clear_vert_len clear_vert_dxil_len
#define clear_frag clear_frag_dxil
#define clear_frag_len clear_frag_dxil_len
#elif defined(__APPLE__)
#include "shaders/psx_vert_msl.h"
#include "shaders/psx_frag_msl.h"
#include "shaders/clear_vert_msl.h"
#include "shaders/clear_frag_msl.h"
#define psx_vert psx_vert_msl
#define psx_vert_len psx_vert_msl_len
#define psx_frag psx_frag_msl
#define psx_frag_len psx_frag_msl_len
#define clear_vert clear_vert_msl
#define clear_vert_len clear_vert_msl_len
#define clear_frag clear_frag_msl
#define clear_frag_len clear_frag_msl_len
#else
#include "shaders/psx_vert_spv.h"
#include "shaders/psx_frag_spv.h"
#include "shaders/clear_vert_spv.h"
#include "shaders/clear_frag_spv.h"
#define psx_vert psx_vert_spv
#define psx_vert_len psx_vert_spv_len
#define psx_frag psx_frag_spv
#define psx_frag_len psx_frag_spv_len
#define clear_vert clear_vert_spv
#define clear_vert_len clear_vert_spv_len
#define clear_frag clear_frag_spv
#define clear_frag_len clear_frag_spv_len
#endif

typedef struct {
    int x, y;
} Posi;

#define VRAM_BYTES (VRAM_W * VRAM_H * 4)
#define STREAM_VERTEX_CAPACITY (MAX_VERTEX_COUNT * 16)
#define STREAM_INDEX_CAPACITY (MAX_INDEX_COUNT * 16)
#define STREAM_VERTEX_BYTES (STREAM_VERTEX_CAPACITY * sizeof(Vertex))

static SDL_GPUDevice* device = NULL;
static bool swapchain_ok = false;
static SDL_GPUTexture* vram_render = NULL;
static SDL_GPUTexture* vram_sample = NULL;
static SDL_GPUSampler* vram_sampler = NULL;
static SDL_GPUTexture* scaled_vram_render = NULL;
static SDL_GPUTexture* scaled_vram_sample = NULL;
static SDL_Rect scaled_vram_dirty;
static SDL_Rect native_resolve_dirty;
static bool framebuffer_sampling;
static bool texture_screen_aligned;
static PsyzGeometryCallback geometry_callback;
static bool correct_textures, precise_geometry, use_depth_buffer;
static bool clear_geometry_depth = true;
static unsigned geometry_depth_scale;
static SDL_GPUTexture *geometry_depth;
static int batch_depth_mode;

int Psyz_GpuConfigureGeometry(PsyzGeometryCallback callback, int textures, int precision, int depth) {
    Draw_FlushBuffer();
    geometry_callback = callback;
    correct_textures = textures != 0;
    precise_geometry = precision != 0;
    use_depth_buffer = depth != 0;
    clear_geometry_depth = true;
    return 0;
}

void Psyz_GpuResetGeometryDepth(void) {
    Draw_FlushBuffer();
    clear_geometry_depth = true;
}
static unsigned internal_res = 1;
static unsigned set_internal_res = 1;
static SDL_GPUBuffer* vbuf = NULL;
static SDL_GPUBuffer* ibuf = NULL;
static SDL_GPUBuffer* clear_vbuf = NULL;
static SDL_GPUTransferBuffer* vtx_transfer = NULL;
static SDL_GPUTransferBuffer* clear_transfer = NULL;
static unsigned stream_vertices;
static unsigned stream_indices;
static bool stream_cycle = true;
static SDL_GPUTransferBuffer* tex_upload_transfer = NULL;
static SDL_GPUTransferBuffer* tex_download_transfer = NULL;
static SDL_GPUGraphicsPipeline* pipe_tri;
static SDL_GPUGraphicsPipeline *pipe_depth_write, *pipe_depth_read;
static bool force_mask_bit;
static bool preserve_masked;
static SDL_GPUGraphicsPipeline* pipe_clear = NULL;
static SDL_GPUCommandBuffer* pending_cmd = NULL;
#include "depth_target.h"

static Posi display_area = {0, 0};
static Posi display_size = {256, 240};
static Posi cur_display_size = {-1, -1};
static Posi draw_offset = {0, 0};
static Posi draw_area_start = {0, 0};
static Posi draw_area_end = {0x10000, 0x10000};
static SDL_Rect scissor_rect = {0, 0, VRAM_W, VRAM_H};
static float frame_scale_x = 1.0f;
static int frame_centre_x;
static bool frame_transform_clip, frame_transform_bypass;

static PsyzOverlayInitCB_SDL3GPU overlay_init_cb;
PsyzOverlayInitCB_SDL3GPU Psyz_OverlayInit_SDL3GPU(
    PsyzOverlayInitCB_SDL3GPU cb) {
    const PsyzOverlayInitCB_SDL3GPU prev = overlay_init_cb;
    overlay_init_cb = cb;
    return prev;
}

static PsyzOverlayRenderCB_SDL3GPU overlay_render_cb;
PsyzOverlayRenderCB_SDL3GPU Psyz_OverlayRender_SDL3GPU(
    PsyzOverlayRenderCB_SDL3GPU cb) {
    const PsyzOverlayRenderCB_SDL3GPU prev = overlay_render_cb;
    overlay_render_cb = cb;
    return prev;
}

static SDL_GPUCommandBuffer* AcquireCmd(void) {
    if (!pending_cmd) {
        pending_cmd = SDL_AcquireGPUCommandBuffer(device);
        if (!pending_cmd) {
            ERRORF("SDL_AcquireGPUCommandBuffer: %s", SDL_GetError());
        }
    }
    return pending_cmd;
}

static void SubmitCmd(void) {
    if (pending_cmd) {
        SDL_SubmitGPUCommandBuffer(pending_cmd);
        pending_cmd = NULL;
    }
}

// FIX: the fence mechanic solves a out-of-memory on Windows when running a
// game with SDL_VIDEODRIVER=offscreen and PSYZ_VSYNC_LIMITLESS when the CPU
// accumulates graphics buffers to submit than what the GPU can process.
// This is especially relevant when running game replays on GH Actions.
#define MAX_FRAMES_IN_FLIGHT 2
static SDL_GPUFence* frame_fences[MAX_FRAMES_IN_FLIGHT];
static unsigned frame_fence_idx = 0;
static void SubmitFrame(void) {
    if (!pending_cmd) {
        return;
    }
    stream_vertices = stream_indices = 0;
    stream_cycle = true;
    if (swapchain_ok) {
        SubmitCmd();
        return;
    }
    SDL_GPUFence** fence = &frame_fences[frame_fence_idx];
    if (*fence) {
        SDL_WaitForGPUFences(device, true, fence, 1);
        SDL_ReleaseGPUFence(device, *fence);
    }
    *fence = SDL_SubmitGPUCommandBufferAndAcquireFence(pending_cmd);
    pending_cmd = NULL;
    frame_fence_idx = (frame_fence_idx + 1) % MAX_FRAMES_IN_FLIGHT;
}
static void ReleaseFrameFences(void) {
    for (int i = 0; i < MAX_FRAMES_IN_FLIGHT; i++) {
        if (frame_fences[i]) {
            SDL_ReleaseGPUFence(device, frame_fences[i]);
            frame_fences[i] = NULL;
        }
    }
}

static void SubmitCmdAndWait(void) {
    if (!pending_cmd) {
        return;
    }
    SDL_GPUFence* fence =
        SDL_SubmitGPUCommandBufferAndAcquireFence(pending_cmd);
    pending_cmd = NULL;
    if (fence) {
        SDL_WaitForGPUFences(device, true, &fence, 1);
        SDL_ReleaseGPUFence(device, fence);
    }
}

static SDL_GPUShader* CreateShader(
    const unsigned char* code, unsigned int code_len, SDL_GPUShaderStage stage,
    Uint32 num_samplers, Uint32 num_uniform_buffers) {
    const SDL_GPUShaderCreateInfo info = {
        .code = code,
        .code_size = code_len,
#if defined(_WIN32)
        .format = SDL_GPU_SHADERFORMAT_DXIL,
        .entrypoint = "main",
#elif defined(__APPLE__)
        .format = SDL_GPU_SHADERFORMAT_MSL,
        .entrypoint = "main0",
#else
        .format = SDL_GPU_SHADERFORMAT_SPIRV,
        .entrypoint = "main",
#endif
        .stage = stage,
        .num_samplers = num_samplers,
        .num_uniform_buffers = num_uniform_buffers,
    };
    SDL_GPUShader* shader = SDL_CreateGPUShader(device, &info);
    if (!shader) {
        ERRORF("SDL_CreateGPUShader: %s", SDL_GetError());
    }
    return shader;
}

static SDL_GPUGraphicsPipeline* CreatePsxPipeline(
    SDL_GPUShader* vs, SDL_GPUShader* fs, int depth_mode) {
    const SDL_GPUVertexBufferDescription vb_desc = {
        .slot = 0,
        .pitch = sizeof(Vertex),
        .input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX,
    };
    const SDL_GPUVertexAttribute attribs[] = {
        {.location = 0,
         .buffer_slot = 0,
         .format = SDL_GPU_VERTEXELEMENTFORMAT_SHORT2,
         .offset = offsetof(Vertex, x)},
        {.location = 1,
         .buffer_slot = 0,
         .format = SDL_GPU_VERTEXELEMENTFORMAT_USHORT4,
         .offset = offsetof(Vertex, u)},
        {.location = 2,
         .buffer_slot = 0,
         .format = SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4_NORM,
         .offset = offsetof(Vertex, r)},
        {.location = 3,
         .buffer_slot = 0,
         .format = SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4,
         .offset = offsetof(Vertex, twin)},
        {.location = 4,
         .buffer_slot = 0,
         .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
         .offset = offsetof(Vertex, delta_x)},
    };
    const SDL_GPUColorTargetDescription target = {
        .format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
    };
    const SDL_GPUGraphicsPipelineCreateInfo info = {
        .vertex_shader = vs,
        .fragment_shader = fs,
        .vertex_input_state =
            {
                .vertex_buffer_descriptions = &vb_desc,
                .num_vertex_buffers = 1,
                .vertex_attributes = attribs,
                .num_vertex_attributes = LENU(attribs),
            },
        .primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
        .depth_stencil_state = {
            .compare_op = SDL_GPU_COMPAREOP_GREATER_OR_EQUAL,
            .enable_depth_test = depth_mode != 0,
            .enable_depth_write = depth_mode == 1,
        },
        .target_info =
            {
                .color_target_descriptions = &target,
                .num_color_targets = 1,
                .has_depth_stencil_target = depth_mode != 0,
                .depth_stencil_format = depth_mode ? SDL_GPU_TEXTUREFORMAT_D32_FLOAT : SDL_GPU_TEXTUREFORMAT_INVALID,
            },
    };
    SDL_GPUGraphicsPipeline* pipe =
        SDL_CreateGPUGraphicsPipeline(device, &info);
    if (!pipe) {
        ERRORF("SDL_CreateGPUGraphicsPipeline: %s", SDL_GetError());
    }
    return pipe;
}

// used only for a fast hardware ClearImage
static SDL_GPUGraphicsPipeline* CreateClearPipeline(
    SDL_GPUShader* vs, SDL_GPUShader* fs) {
    const SDL_GPUVertexBufferDescription vb_desc = {
        .slot = 0,
        .pitch = sizeof(Vertex),
        .input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX,
    };
    const SDL_GPUVertexAttribute attribs[] = {
        {.location = 0,
         .buffer_slot = 0,
         .format = SDL_GPU_VERTEXELEMENTFORMAT_SHORT2,
         .offset = offsetof(Vertex, x)},
        {.location = 1,
         .buffer_slot = 0,
         .format = SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4_NORM,
         .offset = offsetof(Vertex, r)},
    };
    // blending disabled: the clear color (including alpha 0, the PS1 mask
    // bit) is written as-is, matching glClearColor(r, g, b, 0) + glClear
    const SDL_GPUColorTargetDescription target = {
        .format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
    };
    const SDL_GPUGraphicsPipelineCreateInfo info = {
        .vertex_shader = vs,
        .fragment_shader = fs,
        .vertex_input_state =
            {
                .vertex_buffer_descriptions = &vb_desc,
                .num_vertex_buffers = 1,
                .vertex_attributes = attribs,
                .num_vertex_attributes = LENU(attribs),
            },
        .primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLESTRIP,
        .target_info =
            {
                .color_target_descriptions = &target,
                .num_color_targets = 1,
            },
    };
    SDL_GPUGraphicsPipeline* pipe =
        SDL_CreateGPUGraphicsPipeline(device, &info);
    if (!pipe) {
        ERRORF("SDL_CreateGPUGraphicsPipeline: %s", SDL_GetError());
    }
    return pipe;
}

static bool CreateGpuResources(void) {
    const SDL_GPUTextureCreateInfo render_info = {
        .type = SDL_GPU_TEXTURETYPE_2D,
        .format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
        .usage =
            SDL_GPU_TEXTUREUSAGE_COLOR_TARGET | SDL_GPU_TEXTUREUSAGE_SAMPLER,
        .width = VRAM_W,
        .height = VRAM_H,
        .layer_count_or_depth = 1,
        .num_levels = 1,
    };
    vram_render = SDL_CreateGPUTexture(device, &render_info);
    SDL_GPUTextureCreateInfo sample_info = render_info;
    sample_info.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER;
    vram_sample = SDL_CreateGPUTexture(device, &sample_info);
    if (!vram_render || !vram_sample) {
        ERRORF("SDL_CreateGPUTexture: %s", SDL_GetError());
        return false;
    }

    const SDL_GPUSamplerCreateInfo sampler_info = {
        .min_filter = SDL_GPU_FILTER_NEAREST,
        .mag_filter = SDL_GPU_FILTER_NEAREST,
        .mipmap_mode = SDL_GPU_SAMPLERMIPMAPMODE_NEAREST,
        .address_mode_u = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
        .address_mode_v = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
        .address_mode_w = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE,
    };
    vram_sampler = SDL_CreateGPUSampler(device, &sampler_info);
    if (!vram_sampler) {
        ERRORF("SDL_CreateGPUSampler: %s", SDL_GetError());
        return false;
    }

    const SDL_GPUBufferCreateInfo vbuf_info = {
        .usage = SDL_GPU_BUFFERUSAGE_VERTEX,
        .size = STREAM_VERTEX_BYTES,
    };
    vbuf = SDL_CreateGPUBuffer(device, &vbuf_info);
    const SDL_GPUBufferCreateInfo ibuf_info = {
        .usage = SDL_GPU_BUFFERUSAGE_INDEX,
        .size = STREAM_INDEX_CAPACITY * sizeof(u16),
    };
    ibuf = SDL_CreateGPUBuffer(device, &ibuf_info);
    const SDL_GPUBufferCreateInfo clear_vbuf_info = {
        .usage = SDL_GPU_BUFFERUSAGE_VERTEX,
        .size = 4 * sizeof(Vertex),
    };
    clear_vbuf = SDL_CreateGPUBuffer(device, &clear_vbuf_info);
    if (!vbuf || !ibuf || !clear_vbuf) {
        ERRORF("SDL_CreateGPUBuffer: %s", SDL_GetError());
        return false;
    }

    const SDL_GPUTransferBufferCreateInfo vtx_transfer_info = {
        .usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
        .size =
            STREAM_VERTEX_BYTES + STREAM_INDEX_CAPACITY * sizeof(u16),
    };
    vtx_transfer = SDL_CreateGPUTransferBuffer(device, &vtx_transfer_info);
    const SDL_GPUTransferBufferCreateInfo clear_transfer_info = {
        .usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
        .size = 4 * sizeof(Vertex),
    };
    clear_transfer = SDL_CreateGPUTransferBuffer(device, &clear_transfer_info);
    const SDL_GPUTransferBufferCreateInfo upload_info = {
        .usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
        .size = VRAM_BYTES,
    };
    tex_upload_transfer = SDL_CreateGPUTransferBuffer(device, &upload_info);
    const SDL_GPUTransferBufferCreateInfo download_info = {
        .usage = SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD,
        .size = VRAM_BYTES,
    };
    tex_download_transfer = SDL_CreateGPUTransferBuffer(device, &download_info);
    if (!vtx_transfer || !clear_transfer || !tex_upload_transfer || !tex_download_transfer) {
        ERRORF("SDL_CreateGPUTransferBuffer: %s", SDL_GetError());
        return false;
    }

    SDL_GPUShader* psx_vs =
        CreateShader(psx_vert, psx_vert_len, SDL_GPU_SHADERSTAGE_VERTEX, 0, 1);
    SDL_GPUShader* psx_fs = CreateShader(
        psx_frag, psx_frag_len, SDL_GPU_SHADERSTAGE_FRAGMENT, 2, 1);
    SDL_GPUShader* clear_vs = CreateShader(
        clear_vert, clear_vert_len, SDL_GPU_SHADERSTAGE_VERTEX, 0, 0);
    SDL_GPUShader* clear_fs = CreateShader(
        clear_frag, clear_frag_len, SDL_GPU_SHADERSTAGE_FRAGMENT, 0, 0);
    bool shaders_ok = psx_vs && psx_fs && clear_vs && clear_fs;
    if (shaders_ok) {
        pipe_tri = CreatePsxPipeline(psx_vs, psx_fs, 0);
        pipe_depth_write = CreatePsxPipeline(psx_vs, psx_fs, 1);
        pipe_depth_read = CreatePsxPipeline(psx_vs, psx_fs, 2);
        pipe_clear = CreateClearPipeline(clear_vs, clear_fs);
    }
    if (psx_vs) {
        SDL_ReleaseGPUShader(device, psx_vs);
    }
    if (psx_fs) {
        SDL_ReleaseGPUShader(device, psx_fs);
    }
    if (clear_vs) {
        SDL_ReleaseGPUShader(device, clear_vs);
    }
    if (clear_fs) {
        SDL_ReleaseGPUShader(device, clear_fs);
    }
    return shaders_ok && pipe_tri && pipe_depth_write && pipe_depth_read && pipe_clear;
}

bool InitPlatform() {
    if (is_platform_initialized) {
        return is_platform_init_successful;
    }
    is_platform_initialized = true; // don't re-initialize on failures

    if (!SDL_Init(SDL_INIT_VIDEO)) {
        ERRORF("SDL_Init: %s", SDL_GetError());
        return false;
    }

    device = SDL_CreateGPUDevice(
#if defined(_WIN32)
        SDL_GPU_SHADERFORMAT_DXIL,
#elif defined(__APPLE__)
        SDL_GPU_SHADERFORMAT_MSL,
#else
        SDL_GPU_SHADERFORMAT_SPIRV,
#endif
        false, NULL);
    if (!device) {
        ERRORF("SDL_CreateGPUDevice: %s", SDL_GetError());
        return false;
    }
    INFOF("SDL_GPU with driver %s", SDL_GetGPUDeviceDriver(device));

#ifdef PLATFORM_IOS
    const SDL_WindowFlags window_flags =
        SDL_WINDOW_HIDDEN | SDL_WINDOW_HIGH_PIXEL_DENSITY;
#else
    const SDL_WindowFlags window_flags =
        SDL_WINDOW_HIDDEN | SDL_WINDOW_RESIZABLE |
        SDL_WINDOW_HIGH_PIXEL_DENSITY;
#endif
    sdl3_window = SDL_CreateWindow(
        window_title, requested_window_size.w, requested_window_size.h, window_flags);
    if (!sdl3_window) {
        ERRORF("SDL_CreateWindow: %s", SDL_GetError());
        return false;
    }

    // useful for offscreen rendering with SDL_VIDEODRIVER=offscreen
    swapchain_ok = SDL_ClaimWindowForGPUDevice(device, sdl3_window);
    if (!swapchain_ok) {
        WARNF("no swapchain, presentation disabled: %s", SDL_GetError());
    }

    if (!CreateGpuResources()) {
        return false;
    }

    cur_tpage = 0;
    Sdl3Common_TimingInit();

    is_platform_init_successful = true;
    if (overlay_init_cb) {
        overlay_init_cb(sdl3_window, device);
    }
    return true;
}

static bool PlatformBackend_SetDriverVsync(bool enable) {
    if (!device || !swapchain_ok) {
        return false;
    }
    SDL_GPUPresentMode mode = SDL_GPU_PRESENTMODE_VSYNC;
    if (!enable) {
        if (SDL_WindowSupportsGPUPresentMode(
                device, sdl3_window, SDL_GPU_PRESENTMODE_IMMEDIATE)) {
            mode = SDL_GPU_PRESENTMODE_IMMEDIATE;
        } else if (SDL_WindowSupportsGPUPresentMode(
                       device, sdl3_window, SDL_GPU_PRESENTMODE_MAILBOX)) {
            mode = SDL_GPU_PRESENTMODE_MAILBOX;
        }
    }
    return SDL_SetGPUSwapchainParameters(
               device, sdl3_window, SDL_GPU_SWAPCHAINCOMPOSITION_SDR, mode) &&
           enable;
}

static void UpdateScissor(void);

static SDL_GPUTexture* GetRenderTarget(void) {
    return internal_res <= 1 ? vram_render : scaled_vram_render;
}

static SDL_Rect vram_dirty = {0, 0, 0, 0};
static void MarkVramDirty(SDL_Rect r) {
    if (r.w <= 0 || r.h <= 0) {
        return;
    }
    int x0 = CLAMP(r.x, 0, VRAM_W);
    int y0 = CLAMP(r.y, 0, VRAM_H);
    int x1 = CLAMP(r.x + r.w, 0, VRAM_W);
    int y1 = CLAMP(r.y + r.h, 0, VRAM_H);
    if (x1 <= x0 || y1 <= y0) {
        return;
    }
    if (vram_dirty.w <= 0 || vram_dirty.h <= 0) {
        vram_dirty = (SDL_Rect){x0, y0, x1 - x0, y1 - y0};
        return;
    }
    int ux0 = x0 < vram_dirty.x ? x0 : vram_dirty.x;
    int uy0 = y0 < vram_dirty.y ? y0 : vram_dirty.y;
    int ux1 =
        x1 > vram_dirty.x + vram_dirty.w ? x1 : vram_dirty.x + vram_dirty.w;
    int uy1 =
        y1 > vram_dirty.y + vram_dirty.h ? y1 : vram_dirty.y + vram_dirty.h;
    vram_dirty = (SDL_Rect){ux0, uy0, ux1 - ux0, uy1 - uy0};
}
static void ResetVramDirty(void) { vram_dirty = (SDL_Rect){0, 0, 0, 0}; }

static void MarkScaledVramDirty(SDL_Rect rect) {
    SDL_Rect clipped;
    const SDL_Rect bounds = {0, 0, VRAM_W, VRAM_H};
    if (!SDL_GetRectIntersection(&rect, &bounds, &clipped)) return;
    if (scaled_vram_dirty.w > 0 && scaled_vram_dirty.h > 0) {
        SDL_GetRectUnion(&scaled_vram_dirty, &clipped, &scaled_vram_dirty);
    } else {
        scaled_vram_dirty = clipped;
    }
}

static void EnsureScaledSnapshot(void) {
    if (internal_res <= 1 || scaled_vram_sample) return;
    const SDL_GPUTextureCreateInfo info = {
        .type = SDL_GPU_TEXTURETYPE_2D,
        .format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
        .usage = SDL_GPU_TEXTUREUSAGE_SAMPLER,
        .width = VRAM_W * internal_res, .height = VRAM_H * internal_res,
        .layer_count_or_depth = 1, .num_levels = 1};
    scaled_vram_sample = SDL_CreateGPUTexture(device, &info);
    if (!scaled_vram_sample) {
        ERRORF("cannot allocate %ux framebuffer snapshot: %s", internal_res, SDL_GetError());
        exit(EXIT_FAILURE);
    }
    scaled_vram_dirty = (SDL_Rect){0, 0, VRAM_W, VRAM_H};
}

static void SnapshotScaledVram(SDL_GPUCopyPass* copy) {
    if (internal_res <= 1 || scaled_vram_dirty.w <= 0) return;
    const SDL_GPUTextureLocation source = {
        .texture = scaled_vram_render,
        .x = (Uint32)scaled_vram_dirty.x * internal_res,
        .y = (Uint32)scaled_vram_dirty.y * internal_res};
    SDL_GPUTextureLocation target = source;
    target.texture = scaled_vram_sample;
    SDL_CopyGPUTextureToTexture(copy, &source, &target,
        (Uint32)scaled_vram_dirty.w * internal_res,
        (Uint32)scaled_vram_dirty.h * internal_res, 1, false);
    scaled_vram_dirty = (SDL_Rect){0, 0, 0, 0};
}

// mirror a native VRAM region into the scaled render target
static void SyncNativeVramToScaled(int x, int y, int w, int h) {
    if (internal_res <= 1 || !scaled_vram_render || w <= 0 || h <= 0) {
        return;
    }
    SDL_GPUCommandBuffer* cmd = AcquireCmd();
    if (!cmd) {
        return;
    }
    const SDL_GPUBlitInfo blit = {
        .source = {.texture = vram_render,
                   .x = (Uint32)x,
                   .y = (Uint32)y,
                   .w = (Uint32)w,
                   .h = (Uint32)h},
        .destination = {.texture = scaled_vram_render,
                        .x = (Uint32)(x * internal_res),
                        .y = (Uint32)(y * internal_res),
                        .w = (Uint32)(w * internal_res),
                        .h = (Uint32)(h * internal_res)},
        .load_op = SDL_GPU_LOADOP_LOAD,
        .filter = SDL_GPU_FILTER_NEAREST,
    };
    SDL_BlitGPUTexture(cmd, &blit);
    MarkScaledVramDirty((SDL_Rect){x, y, w, h});
}

static void SyncScaledVramToNative(SDL_Rect dirty) {
    if (internal_res <= 1 || !scaled_vram_render) {
        return;
    }
    int x0 = CLAMP(dirty.x, 0, VRAM_W);
    int y0 = CLAMP(dirty.y, 0, VRAM_H);
    int x1 = CLAMP(dirty.x + dirty.w, 0, VRAM_W);
    int y1 = CLAMP(dirty.y + dirty.h, 0, VRAM_H);
    if (x1 <= x0 || y1 <= y0) {
        return;
    }
    SDL_GPUCommandBuffer* cmd = AcquireCmd();
    if (!cmd) {
        return;
    }
    const SDL_GPUBlitInfo blit = {
        .source = {.texture = scaled_vram_render,
                   .x = (Uint32)(x0 * internal_res),
                   .y = (Uint32)(y0 * internal_res),
                   .w = (Uint32)((x1 - x0) * internal_res),
                   .h = (Uint32)((y1 - y0) * internal_res)},
        .destination = {.texture = vram_render,
                        .x = (Uint32)x0,
                        .y = (Uint32)y0,
                        .w = (Uint32)(x1 - x0),
                        .h = (Uint32)(y1 - y0)},
        .load_op = SDL_GPU_LOADOP_LOAD,
        .filter = SDL_GPU_FILTER_NEAREST,
    };
    SDL_BlitGPUTexture(cmd, &blit);
    MarkVramDirty((SDL_Rect){x0, y0, x1 - x0, y1 - y0});
}

static void ResolveNativeVram(void) {
    if (native_resolve_dirty.w > 0) {
        SyncScaledVramToNative(native_resolve_dirty);
        native_resolve_dirty = (SDL_Rect){0};
    }
}

static void MarkNativeResolve(SDL_Rect dirty) {
    if (dirty.w <= 0 || dirty.h <= 0)
        return;
    if (native_resolve_dirty.w > 0)
        SDL_GetRectUnion(&native_resolve_dirty, &dirty, &native_resolve_dirty);
    else
        native_resolve_dirty = dirty;
}

static bool ReadsPendingNative(SDL_Rect region) {
    if (SDL_HasRectIntersection(&region, &native_resolve_dirty))
        return true;
    if (region.x + region.w > VRAM_W) {
        region.w -= VRAM_W - region.x;
        region.x = 0;
        return SDL_HasRectIntersection(&region, &native_resolve_dirty);
    }
    return false;
}

static bool BatchReadsPendingNative(void) {
    if (native_resolve_dirty.w <= 0)
        return false;
    for (int i = 0; i < n_vertices; ++i) {
        u16 page = vertex_buf[i].t, palette = vertex_buf[i].c;
        if (page & TPAGE_NOTEXTURE)
            continue;
        int depth = (page >> 7) & 3;
        if (depth == 2 && framebuffer_sampling)
            continue;
        SDL_Rect texture = {(page & 15) * 64, (page & 16) * 16,
                            64 << SDL_min(depth, 2), 256};
        SDL_Rect colors = {(palette & 63) * 16, (palette >> 6) & 511,
                           depth == 0 ? 16 : 256, 1};
        if (ReadsPendingNative(texture) || (depth < 2 && ReadsPendingNative(colors)))
            return true;
    }
    return false;
}

static bool CreateScaledVramTarget(unsigned n) {
    if (scaled_vram_sample) {
        SDL_ReleaseGPUTexture(device, scaled_vram_sample);
        scaled_vram_sample = NULL;
    }
    if (scaled_vram_render) {
        SDL_ReleaseGPUTexture(device, scaled_vram_render);
        scaled_vram_render = NULL;
    }
    const SDL_GPUTextureCreateInfo info = {
        .type = SDL_GPU_TEXTURETYPE_2D,
        .format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
        .usage =
            SDL_GPU_TEXTUREUSAGE_COLOR_TARGET | SDL_GPU_TEXTUREUSAGE_SAMPLER,
        .width = VRAM_W * n,
        .height = VRAM_H * n,
        .layer_count_or_depth = 1,
        .num_levels = 1,
    };
    scaled_vram_render = SDL_CreateGPUTexture(device, &info);
    if (!scaled_vram_render) {
        ERRORF(
            "scaled VRAM texture creation failed (%dx): %s", n, SDL_GetError());
        return false;
    }
    return true;
}

// ensure scaled VRAM does not exceed max allowed texture size
static unsigned AdjustInternalRes(unsigned scale) {
    unsigned n = scale;
    const unsigned max_dim = 16384; // max theoretical texture size
    unsigned vram_dim = VRAM_W > VRAM_H ? VRAM_W : VRAM_H;
    while (n > 1 && vram_dim * n > max_dim) {
        n--;
    }
    if (n != scale) {
        WARNF("internal resolution %dx exceeds max texture size, "
              "fallback to internal resolution %dx",
              scale, n);
    }
    return n;
}

static void ApplyPendingInternalRes(void) {
    if (set_internal_res == internal_res) {
        return;
    }
    if (!sdl3_window || !is_platform_init_successful) {
        return;
    }
    unsigned n = AdjustInternalRes(set_internal_res);
    if (window_configuration_requested && n != set_internal_res) {
        ERRORF("requested internal resolution %ux is unsupported", set_internal_res);
        exit(EXIT_FAILURE);
    }
    if (n == internal_res) {
        return;
    }
    Draw_FlushBuffer(); // render pending prims with the old multiplier
    ResolveNativeVram();
    if (n > 1 && !CreateScaledVramTarget(n)) {
        if (window_configuration_requested) {
            ERRORF("cannot allocate the requested %ux render target; refusing a lower resolution", n);
            exit(EXIT_FAILURE);
        }
        n = 1;
        set_internal_res = 1;
    }
    if (n > 1) {
        // upscale the whole native VRAM into the freshly created scaled target
        SDL_GPUCommandBuffer* cmd = AcquireCmd();
        if (cmd) {
            const SDL_GPUBlitInfo blit = {
                .source = {.texture = vram_render, .w = VRAM_W, .h = VRAM_H},
                .destination = {.texture = scaled_vram_render,
                                .w = VRAM_W * n,
                                .h = VRAM_H * n},
                .load_op = SDL_GPU_LOADOP_DONT_CARE,
                .filter = SDL_GPU_FILTER_NEAREST,
            };
            SDL_BlitGPUTexture(cmd, &blit);
        }
    } else if (scaled_vram_render) {
        SDL_ReleaseGPUTexture(device, scaled_vram_render);
        scaled_vram_render = NULL;
    }
    internal_res = n;
    UpdateScissor();
    INFOF("internal resolution set to %dx (%dx%d)", n, VRAM_W * n, VRAM_H * n);
}

static void PlatformBackend_Present(void) {
    if (!sdl3_window && !InitPlatform()) {
        return;
    }
    if (Sdl3Common_IsInBackground()) {
        finish_time = SDL_GetPerformanceCounter();
        return;
    }

    ApplyPendingInternalRes();

    SDL_GPUCommandBuffer* cmd = AcquireCmd();
    if (!cmd) {
        return;
    }
    if (swapchain_ok) {
        SDL_GPUTexture* swapchain = NULL;
        Uint32 sc_w = 0, sc_h = 0;
        if (!SDL_WaitAndAcquireGPUSwapchainTexture(
                cmd, sdl3_window, &swapchain, &sc_w, &sc_h)) {
            WARNF("SDL_WaitAndAcquireGPUSwapchainTexture: %s", SDL_GetError());
        }
        if (swapchain) {
            if (!disp_on) {
                const SDL_GPUColorTargetInfo blank_target = {
                    .texture = swapchain,
                    .clear_color = {0.0f, 0.0f, 0.0f, 1.0f},
                    .load_op = SDL_GPU_LOADOP_CLEAR,
                    .store_op = SDL_GPU_STOREOP_STORE,
                };
                SDL_GPURenderPass* blank_pass =
                    SDL_BeginGPURenderPass(cmd, &blank_target, 1, NULL);
                SDL_EndGPURenderPass(blank_pass);
            } else {
                const Uint32 n = internal_res;
                SDL_GPUBlitRegion src = {
                    .texture = GetRenderTarget(),
                    .x = (Uint32)display_area.x * n,
                    .y = (Uint32)display_area.y * n,
                    .w = (Uint32)display_size.x * n,
                    .h = (presentation_source_height ? presentation_source_height : (Uint32)display_size.y) * n,
                };
                float game_aspect =
                    GetCurrentGameAspectRatio(display_size.x, display_size.y);
                if (debug_show_vram) {
                    src.x = 0;
                    src.y = 0;
                    src.w = VRAM_W * n;
                    src.h = VRAM_H * n;
                    game_aspect = (float)VRAM_W / (float)VRAM_H;
                }

                WndSize win = {(int)sc_w, (int)sc_h};
                SDL_Rect dst = FitGameToWindow(game_aspect, win);

                const SDL_GPUBlitInfo blit = {
                    .source = src,
                    .destination =
                        {
                            .texture = swapchain,
                            .x = (Uint32)dst.x,
                            .y = (Uint32)dst.y,
                            .w = (Uint32)dst.w,
                            .h = (Uint32)dst.h,
                        },
                    // clear the swapchain to black first so the horizontal or
                    // vertical bars around the game output are black
                    .load_op = SDL_GPU_LOADOP_CLEAR,
                    .clear_color = {0.0f, 0.0f, 0.0f, 1.0f},
                    .filter = presentation_width ? SDL_GPU_FILTER_LINEAR : SDL_GPU_FILTER_NEAREST,
                };
                SDL_BlitGPUTexture(cmd, &blit);
            }
            if (overlay_frame_cb) {
                overlay_frame_cb();
            }
            if (!DebugPanelDraw(device, cmd, swapchain, sc_w, sc_h, debug_text)) {
                ERRORF("Cannot render debug panel: %s", SDL_GetError());
                abort();
            }
            if (overlay_render_cb) {
                SDL_GPUColorTargetInfo target = {
                    .texture = swapchain,
                    .load_op = SDL_GPU_LOADOP_LOAD,
                    .store_op = SDL_GPU_STOREOP_STORE,
                };
                SDL_GPURenderPass* pass =
                    SDL_BeginGPURenderPass(cmd, &target, 1, NULL);
                overlay_render_cb(cmd, pass);
                SDL_EndGPURenderPass(pass);
            }
        }
    } else if (overlay_frame_cb) {
        overlay_frame_cb();
    }
    finish_time = SDL_GetPerformanceCounter();
    SubmitFrame();
    gpu_stats.last_submit_time_us = GetElapsedMicroseconds(finish_time, SDL_GetPerformanceCounter());
}

static void QuitPlatform(void) {
    Sdl3Common_Shutdown();
    if (overlay_destroy_cb) {
        overlay_destroy_cb();
    }
    if (device) {
        SDL_WaitForGPUIdle(device);
        ReleaseGeometryDepth();
        if (pipe_depth_write) SDL_ReleaseGPUGraphicsPipeline(device, pipe_depth_write);
        if (pipe_depth_read) SDL_ReleaseGPUGraphicsPipeline(device, pipe_depth_read);
        pipe_depth_write = pipe_depth_read = NULL;
        DebugPanelDestroy(device);
        ReleaseFrameFences();
        if (pipe_tri) {
            SDL_ReleaseGPUGraphicsPipeline(device, pipe_tri);
            pipe_tri = NULL;
        }
        if (pipe_clear) {
            SDL_ReleaseGPUGraphicsPipeline(device, pipe_clear);
            pipe_clear = NULL;
        }
        if (vram_render) {
            SDL_ReleaseGPUTexture(device, vram_render);
            vram_render = NULL;
        }
        if (vram_sample) {
            SDL_ReleaseGPUTexture(device, vram_sample);
            vram_sample = NULL;
        }
        if (scaled_vram_render) {
            SDL_ReleaseGPUTexture(device, scaled_vram_render);
            scaled_vram_render = NULL;
        }
        if (scaled_vram_sample) {
            SDL_ReleaseGPUTexture(device, scaled_vram_sample);
            scaled_vram_sample = NULL;
        }
        if (vram_sampler) {
            SDL_ReleaseGPUSampler(device, vram_sampler);
            vram_sampler = NULL;
        }
        if (vbuf) {
            SDL_ReleaseGPUBuffer(device, vbuf);
            vbuf = NULL;
        }
        if (ibuf) {
            SDL_ReleaseGPUBuffer(device, ibuf);
            ibuf = NULL;
        }
        if (clear_vbuf) {
            SDL_ReleaseGPUBuffer(device, clear_vbuf);
            clear_vbuf = NULL;
        }
        if (vtx_transfer) {
            SDL_ReleaseGPUTransferBuffer(device, vtx_transfer);
            vtx_transfer = NULL;
        }
        if (clear_transfer) {
            SDL_ReleaseGPUTransferBuffer(device, clear_transfer);
            clear_transfer = NULL;
        }
        if (tex_upload_transfer) {
            SDL_ReleaseGPUTransferBuffer(device, tex_upload_transfer);
            tex_upload_transfer = NULL;
        }
        if (tex_download_transfer) {
            SDL_ReleaseGPUTransferBuffer(device, tex_download_transfer);
            tex_download_transfer = NULL;
        }
        if (swapchain_ok) {
            SDL_ReleaseWindowFromGPUDevice(device, sdl3_window);
            swapchain_ok = false;
        }
        SDL_DestroyGPUDevice(device);
        device = NULL;
    }
    if (sdl3_window) {
        SDL_DestroyWindow(sdl3_window);
        sdl3_window = NULL;
        is_window_visible = false;
    }
    SDL_Quit();
    is_platform_initialized = false;
    is_platform_init_successful = false;
}

void ResetPlatform(void) {
    cur_tpage = 0;
    internal_res = 1;
    frame_scale_x = 1.0f;
    frame_centre_x = 0;
    frame_transform_clip = frame_transform_bypass = false;
    framebuffer_sampling = false;
    texture_screen_aligned = false;
    native_resolve_dirty = (SDL_Rect){0};
    QuitPlatform();
}

static bool DownloadVramRegionAsRGBA8888(int x, int y, int w, int h, u8* out) {
    ResolveNativeVram();
    SDL_GPUCommandBuffer* cmd = AcquireCmd();
    if (!cmd) {
        return false;
    }
    SDL_GPUCopyPass* copy = SDL_BeginGPUCopyPass(cmd);
    const SDL_GPUTextureRegion region = {
        .texture = vram_render,
        .x = (Uint32)x,
        .y = (Uint32)y,
        .w = (Uint32)w,
        .h = (Uint32)h,
        .d = 1,
    };
    const SDL_GPUTextureTransferInfo transfer = {
        .transfer_buffer = tex_download_transfer,
    };
    SDL_DownloadFromGPUTexture(copy, &region, &transfer);
    SDL_EndGPUCopyPass(copy);
    SubmitCmdAndWait();

    const u8* map =
        SDL_MapGPUTransferBuffer(device, tex_download_transfer, false);
    if (!map) {
        ERRORF("SDL_MapGPUTransferBuffer: %s", SDL_GetError());
        return false;
    }
    memcpy(out, map, (size_t)w * h * 4);
    SDL_UnmapGPUTransferBuffer(device, tex_download_transfer);
    return true;
}

static unsigned char* AllocRgb888Region(int x, int y, int w, int h) {
    if (!device || !vram_render) {
        ERRORF("GPU device not initialized");
        return NULL;
    }

    unsigned char* pixels = malloc((size_t)w * h * 3);
    u8* rgba = malloc((size_t)w * h * 4);
    if (!pixels || !rgba) {
        free(pixels);
        free(rgba);
        return NULL;
    }

    if (!DownloadVramRegionAsRGBA8888(x, y, w, h, rgba)) {
        free(pixels);
        free(rgba);
        return NULL;
    }
    const u8* src = rgba;
    unsigned char* dst = pixels;
    for (int i = 0; i < w * h; i++) {
        dst[0] = src[0];
        dst[1] = src[1];
        dst[2] = src[2];
        dst += 3;
        src += 4;
    }
    free(rgba);
    return pixels;
}

unsigned char* Psyz_VideoAllocCapturedFrame(int* w, int* h) {
    *w = display_size.x;
    *h = display_size.y;
    return AllocRgb888Region(display_area.x, display_area.y, *w, *h);
}

static SDL_Surface* ReadPresentationSurface(void) {

    int source_height = presentation_source_height ? (int)presentation_source_height : display_size.y;
    if (!device || display_area.x < 0 || display_area.y < 0 ||
        display_area.x + display_size.x > VRAM_W || display_area.y + source_height > VRAM_H) {
        return NULL;
    }
    Draw_FlushBuffer();
    int width = display_size.x * (int)internal_res;
    int height = source_height * (int)internal_res;
    SDL_Surface* surface = SDL_CreateSurface(width, height, SDL_PIXELFORMAT_RGBA32);
    if (!surface) {
        return NULL;
    }
    const SDL_GPUTransferBufferCreateInfo info = {
        .usage = SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD, .size = (Uint32)(width * height * 4)};
    SDL_GPUTransferBuffer* transfer = SDL_CreateGPUTransferBuffer(device, &info);
    SDL_GPUCommandBuffer* cmd = transfer ? AcquireCmd() : NULL;
    if (!cmd) {
        if (transfer) SDL_ReleaseGPUTransferBuffer(device, transfer);
        SDL_DestroySurface(surface);
        return NULL;
    }
    SDL_GPUCopyPass* copy = SDL_BeginGPUCopyPass(cmd);
    const SDL_GPUTextureRegion region = {
        .texture = GetRenderTarget(), .x = (Uint32)display_area.x * internal_res,
        .y = (Uint32)display_area.y * internal_res, .w = (Uint32)width,
        .h = (Uint32)height, .d = 1};
    const SDL_GPUTextureTransferInfo target = {.transfer_buffer = transfer};
    SDL_DownloadFromGPUTexture(copy, &region, &target);
    SDL_EndGPUCopyPass(copy);
    SubmitCmdAndWait();
    const u8* data = SDL_MapGPUTransferBuffer(device, transfer, false);
    if (data) {
        for (int row = 0; row < height; ++row)
            memcpy((u8*)surface->pixels + row * surface->pitch, data + row * width * 4, width * 4);
        SDL_UnmapGPUTransferBuffer(device, transfer);
    }
    SDL_ReleaseGPUTransferBuffer(device, transfer);
    if (!data) {
        SDL_DestroySurface(surface);
        return NULL;
    }
    return surface;
}

unsigned char* Psyz_VideoAllocPresentedFrame(int* w, int* h) {
    if (!w || !h) {
        return NULL;
    }
    *w = *h = 0;
    if (!device) {
        return NULL;
    }
    WndSize output = requested_window_size;
    if (!disp_on) {
        unsigned char* blank = calloc((size_t)output.w * output.h, 3);
        if (blank) {
            *w = output.w;
            *h = output.h;
        }
        return blank;
    }
    SDL_Surface* source = ReadPresentationSurface();
    if (!source) {
        return NULL;
    }
    SDL_Surface* target = SDL_CreateSurface(output.w, output.h, SDL_PIXELFORMAT_RGB24);
    unsigned char* result = NULL;
    SDL_Rect destination = FitGameToWindow(GetCurrentGameAspectRatio(display_size.x, display_size.y), output);
    if (target) {
        SDL_FillSurfaceRect(target, NULL, 0);
        SDL_SetSurfaceBlendMode(source, SDL_BLENDMODE_NONE);
        if (SDL_BlitSurfaceScaled(source, NULL, target, &destination,
                                 presentation_width ? SDL_SCALEMODE_LINEAR : SDL_SCALEMODE_NEAREST)) {
            result = malloc((size_t)output.w * output.h * 3);
            if (result) {
                for (int row = 0; row < output.h; ++row)
                    memcpy(result + (size_t)row * output.w * 3,
                           (u8*)target->pixels + row * target->pitch, (size_t)output.w * 3);
                *w = output.w;
                *h = output.h;
            }
        }
        SDL_DestroySurface(target);
    }
    SDL_DestroySurface(source);
    return result;
}

unsigned char* Psyz_VideoAllocVramDump(int* w, int* h) {
    *w = VRAM_W;
    *h = VRAM_H;
    return AllocRgb888Region(0, 0, VRAM_W, VRAM_H);
}

static void UpdateScissor() {
    int width = draw_area_end.x - draw_area_start.x + 1;
    int height = draw_area_end.y - draw_area_start.y + 1;
    if (width <= 0 || height <= 0) {
        // Draw_SetAreaStart gets called before Draw_SetAreaEnd, it happens
        // that either width or height are zero. Just ignore the call.
        return;
    }

    if (!sdl3_window || !InitPlatform()) {
        return;
    }
    Draw_FlushBuffer();

    scissor_rect.x = draw_area_start.x;
    scissor_rect.y = draw_area_start.y;
    scissor_rect.w = width;
    scissor_rect.h = height;
    if (frame_transform_clip && !frame_transform_bypass) {
        int left = (int)floorf(frame_centre_x + (scissor_rect.x - frame_centre_x) * frame_scale_x + 0.5f);
        int right = (int)floorf(frame_centre_x + (scissor_rect.x + width - frame_centre_x) * frame_scale_x + 0.5f);
        scissor_rect.x = CLAMP(left, 0, VRAM_W);
        scissor_rect.w = CLAMP(right, 0, VRAM_W) - scissor_rect.x;
    }
}

int Psyz_GpuSetFrameTransform(unsigned numerator, unsigned denominator,
                             int centre_x, int transform_clip) {
    if (!numerator || !denominator || (transform_clip != 0 && transform_clip != 1)) {
        return -1;
    }
    float scale = (float)numerator / (float)denominator;
    if (scale < 0.0625f || scale > 16.0f) {
        return -1;
    }
    Draw_FlushBuffer();
    frame_scale_x = scale;
    frame_centre_x = centre_x;
    frame_transform_clip = transform_clip != 0;
    if (is_platform_init_successful) {
        UpdateScissor();
    }
    return 0;
}

int Psyz_GpuSetFramebufferSampling(int enabled) {
    if (enabled != 0 && enabled != 1) return -1;
    Draw_FlushBuffer();
    framebuffer_sampling = enabled != 0;
    return 0;
}

int Psyz_GpuSetTextureAlignment(int screen_aligned) {
    if (screen_aligned != 0 && screen_aligned != 1) return -1;
    Draw_FlushBuffer();
    texture_screen_aligned = screen_aligned != 0;
    return 0;
}

unsigned Psyz_VideoGetInternalResolution(void) { return internal_res; }

int Psyz_VideoSetInternalResolution(unsigned multiplier) {
    if (multiplier < 1) {
        return -1;
    }
    if (multiplier > PSYZ_INTERNAL_RES_MAX) {
        WARNF("internal resolution %dx exceeds maximum value of %dx",
              multiplier, PSYZ_INTERNAL_RES_MAX);
        return -1;
    }
    set_internal_res = multiplier;
    if (sdl3_window && is_platform_init_successful) {
        ApplyPendingInternalRes();
    }
    return 0;
}

static void ApplyDisplayPendingChanges() {
    if (!sdl3_window && !InitPlatform()) {
        return;
    }
    ApplyPendingInternalRes();
    if (cur_display_size.x != display_size.x ||
        cur_display_size.y != display_size.y || !is_window_visible) {
        if (!is_window_visible) {
#ifdef PLATFORM_IOS
            SDL_GetWindowSizeInPixels(
                sdl3_window, &wnd_size_in_pixels.w, &wnd_size_in_pixels.h);
#else
            SetWindowSizeInPixels(requested_window_size.w, requested_window_size.h);
#endif
        }
        cur_display_size = display_size;
    }
    if (!is_window_visible) {
        SDL_ShowWindow(sdl3_window);
        is_window_visible = true;
#ifndef PLATFORM_IOS
        ApplyRequestedFullscreen();
#endif
#ifdef PLATFORM_IOS
        SDL_GetWindowSizeInPixels(
            sdl3_window, &wnd_size_in_pixels.w, &wnd_size_in_pixels.h);
        Psyz_IosAttachWindow(sdl3_window);
#endif
    }
    if (cur_disp_horiz != set_disp_horiz || cur_disp_vert != set_disp_vert) {
        cur_disp_horiz = set_disp_horiz;
        cur_disp_vert = set_disp_vert;
    }
}

void Draw_Reset() { NOT_IMPLEMENTED; }

void Draw_DisplayEnable(unsigned int on) {
    disp_on = on;
    if (on) {
        ApplyDisplayPendingChanges();
    }
}

void Draw_DisplayArea(unsigned int x, unsigned int y) {
    display_area.x = (int)x;
    display_area.y = (int)y;

    Draw_FlushBuffer();
    ApplyDisplayPendingChanges();
}

void Draw_DisplayHorizontalRange(unsigned int start, unsigned int end) {
    set_disp_horiz = (int)(end - start) / 10;
    ApplyDisplayPendingChanges();
}

void Draw_DisplayVerticalRange(unsigned int start, int unsigned end) {
    set_disp_vert = (int)(end - start);
    ApplyDisplayPendingChanges();
}

void Draw_SetDisplayMode(DisplayMode* mode) {
    // TODO the interlace flag is ignored
    // TODO rgb24 is ignored, the color output will always max the color space
    if (mode->reversed) {
        WARNF("reverse mode not supported");
    }
    is_pal = mode->pal;
    if (mode->horizontal_resolution_368) {
        display_size.x = 368;
    } else {
        switch (mode->horizontal_resolution) {
        case 0:
            display_size.x = 256;
            break;
        case 1:
            display_size.x = 320;
            break;
        case 2:
            display_size.x = 512;
            break;
        case 3:
            display_size.x = 640;
            break;
        default:
            break;
        }
    }
    display_size.y = mode->vertical_resolution ? 480 : 240;
    ApplyDisplayPendingChanges();

    double new_target_fps = mode->pal ? VSYNC_PAL : VSYNC_NTSC;
    if (new_target_fps != target_frame_rate) {
        UpdateTargetFramerate(new_target_fps);
    }
}

int Draw_ExequeSync() { return 0; }

// optimization to avoid sampling the VRAM on an untextured batch draw
static bool batch_has_texture = false;
static bool batch_reads_destination = false;

static bool VramRegionReadsDrawArea(SDL_Rect region) {
    if (SDL_HasRectIntersection(&region, &scissor_rect)) {
        return true;
    }
    if (region.x + region.w > VRAM_W) {
        region.w -= VRAM_W - region.x;
        region.x = 0;
        return SDL_HasRectIntersection(&region, &scissor_rect);
    }
    return false;
}

static void FlushTextureFeedback(const u_long* packets, int len, int code) {
    if (n_vertices == 0 || !(code & TEXTURED) ||
        ((code & 0x40) && !(code & 0x20))) {
        return;
    }
    bool polygon = !(code & 0x40);
    int page_word = (code & GOURAUD) ? 5 : 4;
    if (len <= 2 || (polygon && len <= page_word)) {
        return;
    }
    u16 page = polygon ? (u16)(packets[page_word] >> 16) : cur_tpage;
    u16 palette = (u16)(packets[2] >> 16);
    int depth = (page >> 7) & 3;
    SDL_Rect texture = {(page & 15) * 64, (page & 16) * 16,
                        64 << (depth > 2 ? 2 : depth), 256};
    SDL_Rect colors = {(palette & 63) * 16, (palette >> 6) & 511,
                       depth == 0 ? 16 : 256, 1};
    if (VramRegionReadsDrawArea(texture) ||
        (depth < 2 && VramRegionReadsDrawArea(colors))) {
        // A textured draw must sample writes from earlier commands, including
        // palette writes. The next batch snapshots VRAM after this flush.
        Draw_FlushBuffer();
    }
}

static bool TriangleInRange(const Vertex* a, const Vertex* b, const Vertex* c) {
    int min_x = SDL_min(a->x, SDL_min(b->x, c->x));
    int max_x = SDL_max(a->x, SDL_max(b->x, c->x));
    int min_y = SDL_min(a->y, SDL_min(b->y, c->y));
    int max_y = SDL_max(a->y, SDL_max(b->y, c->y));
    return max_x - min_x < 1024 && max_y - min_y < 512;
}

static int PolygonIndices(int vertices)
{
    static const unsigned short triangles[2][3] = {{0, 1, 2}, {1, 3, 2}};
    int                         count = 0;
    for (int i = 0; i < vertices - 2; ++i)
    {
        const unsigned short *t = triangles[i];
        if (TriangleInRange(&vertex_cur[t[0]], &vertex_cur[t[1]], &vertex_cur[t[2]]))
        {
            for (int j = 0; j < 3; ++j)
            {
                index_cur[count++] = n_vertices + t[j];
            }
        }
    }
    return count;
}

static bool ReadPolygonGeometry(const u_long *packets, int length, int code,
                                PsyzProjectedVertex vertices[4]) {
    if (!geometry_callback || (code & 0x60) != 0x20 || texture_screen_aligned || framebuffer_sampling)
        return false;
    int count = code & EXTRA_VERTEX ? 4 : 3;
    int stride = 1 + ((code & TEXTURED) != 0) + ((code & GOURAUD) != 0);
    if (length < 2 + (count - 1) * stride) return false;
    for (int i = 0; i < count; ++i) {
        if (!geometry_callback(packets + 1 + i * stride, &vertices[i]) ||
            !isfinite(vertices[i].depth) || vertices[i].depth < 1 ||
            !isfinite(vertices[i].x) || !isfinite(vertices[i].y))
            return false;
    }
    return true;
}

static void SetPolygonGeometry(const PsyzProjectedVertex *vertices, int count, bool textured) {
    for (int i = 0; i < count; ++i) {
        vertex_cur[i].delta_x = precise_geometry ? vertices[i].x - vertex_cur[i].x : 0;
        vertex_cur[i].delta_y = precise_geometry ? vertices[i].y - vertex_cur[i].y : 0;
        vertex_cur[i].reciprocal_depth = 1.0f / vertices[i].depth;
        vertex_cur[i].texture_w = correct_textures && textured ? vertices[i].depth : 1.0f;
    }
}

static int DrawPrimitive(u_long *packets, int max_len)
{
    int     len = max_len;
    int     code = (int)(*packets >> 24) & 0xFF;
    bool    isPoly = !(code & 0x40);
    bool    isLine = (code & 0x40) && !(code & 0x20);
    bool    isTile = (code & 0x40) && (code & 0x20);
    bool    isTextured = (code & TEXTURED) != 0;
    bool    isGouraud = (code & GOURAUD) != 0;
    bool    isShadeTex = !((code & 1) && isTextured && !isLine);
    u16     tpage = -1, clut = -1, pad2, pad3;
    Vertex *v;
    PsyzProjectedVertex geometry[4];
    bool projected = ReadPolygonGeometry(packets, max_len, code, geometry);
    int depth_mode = projected && use_depth_buffer ? ((code & SEMITRANSP) ? 2 : 1) : 0;
    if (depth_mode != batch_depth_mode) Draw_FlushBuffer();
    batch_depth_mode = depth_mode;

    if (preserve_masked || (code & SEMITRANSP))
    {
        Draw_FlushBuffer();
    }
    FlushTextureFeedback(packets, max_len, code);
    // to ensure we always have space, we pretend we want to allocate a quad
    // Gouraud read-ahead can write a colour into a fifth vertex slot.
    Draw_EnsureBufferWillNotOverflow(5, 6);
    v = vertex_cur;
    for (int i = 0; i < 5; ++i)
        v[i].delta_x = v[i].delta_y = v[i].reciprocal_depth = 0, v[i].texture_w = 1;
    if (isShadeTex)
    {
        v->r = (unsigned char)(*packets >> 0);
        v->g = (unsigned char)(*packets >> 8);
        v->b = (unsigned char)(*packets >> 16);
    }
    else
    {
        v->r = v->g = v->b = 0x80;
    }
    v->a = code & SEMITRANSP ? 0x80 : 0xFF;
    packets++;
    len--;
    if (isPoly)
    {
        if (code & TRIANGLE)
        {
            int wr, nVertices, nIndices;
            wr = writePacket(v++, code, len, packets, &clut);
            packets += wr;
            len -= wr;
            wr = writePacket(v++, code, len, packets, &tpage);
            packets += wr;
            len -= wr;
            wr = writePacket(v++, code, len, packets, &pad2);
            packets += wr;
            len -= wr;

            if (code & EXTRA_VERTEX)
            {
                nVertices = 4;
                wr = writePacket(v, code, len, packets, &pad3);
                packets += wr;
                len -= wr;
            }
            else
            {
                nVertices = 3;
            }
            if (isGouraud && wr == 2 + isTextured)
            {
                packets--;
                len++;
            }

            nIndices = PolygonIndices(nVertices);
            if (nIndices == 0)
            {
                return max_len - len;
            }

            if (!isTextured)
            {
                clut = -1;
                tpage = cur_tpage | TPAGE_NOTEXTURE;
            }
            tpage |= TPAGE_POLYGON;
            if (CanPolyDither(isGouraud, isTextured, isShadeTex))
            {
                tpage |= TPAGE_DITHER;
            }
            if (!isGouraud || !isShadeTex)
            {
                VRGBA(vertex_cur[1]) = VRGBA(vertex_cur[2]) = VRGBA(vertex_cur[3]) = VRGBA(vertex_cur[0]);
            }

            SET_TC_ALL(vertex_cur, tpage, clut);
            if (projected) SetPolygonGeometry(geometry, nVertices, isTextured);
            Draw_EnqueueBuffer(nVertices, nIndices);
        }
        else
        {
            // shouldn't happen on a normal PSX application
            WARNF("code %02X not supported", code);
        }
    }
    else if (isLine)
    {
        bool padding = true;
        int  nPoints = ((code >> 2) & 3) + 1;
        if (nPoints == 1)
        {
            padding = false;
            nPoints++; // don't ask, have faith
        }

        // accumulate line points first, then convert them to triangles
        short         px[4], py[4];
        unsigned char cr[4], cg[4], cb[4], ca[4];
        int           parsed = 0;
        cr[0] = v->r;
        cg[0] = v->g;
        cb[0] = v->b;
        ca[0] = v->a;
        for (int i = 0; len > 0 && i < nPoints; i++)
        {
            px[i] = s11(((short *)packets)[0]);
            py[i] = s11(((short *)packets)[1]);
            packets++;
            len--;
            parsed = i + 1;
            if (len > 0 && i + 1 < nPoints && isGouraud) {
                cr[i + 1] = ((u8*)packets)[0];
                cg[i + 1] = ((u8*)packets)[1];
                cb[i + 1] = ((u8*)packets)[2];
                ca[i + 1] = code & SEMITRANSP ? 0x80 : 0xFF;
                packets++;
                len--;
            }
        }
        if (!isGouraud) {
            for (int i = 1; i < parsed; i++) {
                cr[i] = cr[0];
                cg[i] = cg[0];
                cb[i] = cb[0];
                ca[i] = ca[0];
            }
        }
        if (padding) {
            len--;
        }

        int nSegments = parsed - 1;
        if (nSegments >= 1) {
            // for LINE_*4: 12 verts, 18 indices
            Draw_EnsureBufferWillNotOverflow(nSegments * 4, nSegments * 6);
            for (int s = 0; s < nSegments; s++) {
                short x0 = px[s];
                short y0 = py[s];
                short x1 = px[s + 1];
                short y1 = py[s + 1];
                int dx = x1 - x0;
                int dy = y1 - y0;
                if (abs(dx) >= 1024 || abs(dy) >= 512) {
                    continue;
                }

                // decides to thicken horizontally or vertically
                short ox, oy, ex, ey;
                if ((dx < 0 ? -dx : dx) >= (dy < 0 ? -dy : dy)) {
                    ox = 0;
                    oy = 1;
                    ex = dx >= 0 ? 1 : -1;
                    ey = 0;
                } else {
                    ox = 1;
                    oy = 0;
                    ex = 0;
                    ey = dy >= 0 ? 1 : -1;
                }

                Vertex* q = vertex_cur;
                unsigned short base = n_vertices;
                q[0].x = x0;
                q[0].y = y0;
                q[1].x = (short)(x1 + ex);
                q[1].y = (short)(y1 + ey);
                q[2].x = (short)(x1 + ex + ox);
                q[2].y = (short)(y1 + ey + oy);
                q[3].x = (short)(x0 + ox);
                q[3].y = (short)(y0 + oy);
                q[0].r = cr[s];
                q[0].g = cg[s];
                q[0].b = cb[s];
                q[0].a = ca[s];
                q[3].r = cr[s];
                q[3].g = cg[s];
                q[3].b = cb[s];
                q[3].a = ca[s];
                q[1].r = cr[s + 1];
                q[1].g = cg[s + 1];
                q[1].b = cb[s + 1];
                q[1].a = ca[s + 1];
                q[2].r = cr[s + 1];
                q[2].g = cg[s + 1];
                q[2].b = cb[s + 1];
                q[2].a = ca[s + 1];
                u16 lt = cur_tpage | TPAGE_NOTEXTURE;
                if (CanLineDither()) {
                    lt |= TPAGE_DITHER;
                }
                for (int k = 0; k < 4; k++) {
                    SET_TC(&q[k], lt, -1);
                }
                index_cur[0] = base + 0;
                index_cur[1] = base + 1;
                index_cur[2] = base + 2;
                index_cur[3] = base + 0;
                index_cur[4] = base + 2;
                index_cur[5] = base + 3;
                Draw_EnqueueBuffer(4, 6);
                if (preserve_masked || (code & SEMITRANSP)) {
                    batch_reads_destination = true;
                    Draw_FlushBuffer();
                }
            }
        }
    }
    else if (isTile)
    {
        int x, y, w, h, tu, tv;
        x = s11(((short*)packets)[0]);
        y = s11(((short*)packets)[1]);
        packets++;
        len--;
        if (isTextured) {
            tu = ((u8*)packets)[0];
            tv = ((u8*)packets)[1];
            clut = ((s16*)packets)[1];
            tpage = cur_tpage;
            packets++;
            len--;
        } else {
            clut = -1;
            tpage = cur_tpage | TPAGE_NOTEXTURE;
        }
        switch (code & ~3) {
        case 0x60: // TILE
        case 0x64: // SPRT
            w = ((s16*)packets)[0];
            h = ((s16*)packets)[1];
            packets++;
            len--;
            break;
        case 0x68: // TILE_1
        case 0x6C:
            w = 1;
            h = 1;
            break;
        case 0x70: // TILE_8
        case 0x74: // SPRT_8
            w = 8;
            h = 8;
            break;
        case 0x78: // TILE_16
        case 0x7C: // SPRT_16
            w = 16;
            h = 16;
            break;
        default:
            // TODO warn about unrecognized code
            break;
        }
        vertex_cur[0].x = (short)(x);
        vertex_cur[0].y = (short)(y);
        vertex_cur[1].x = (short)(x + w);
        vertex_cur[1].y = (short)(y);
        vertex_cur[2].x = (short)(x);
        vertex_cur[2].y = (short)(y + h);
        vertex_cur[3].x = (short)(x + w);
        vertex_cur[3].y = (short)(y + h);
        if (isTextured) {
            vertex_cur[0].u = tu;
            vertex_cur[0].v = tv;
            vertex_cur[1].u = tu + w;
            vertex_cur[1].v = tv;
            vertex_cur[2].u = tu;
            vertex_cur[2].v = tv + h;
            vertex_cur[3].u = tu + w;
            vertex_cur[3].v = tv + h;
        }
        VRGBA(vertex_cur[1]) = VRGBA(vertex_cur[2]) = VRGBA(vertex_cur[3]) =
            VRGBA(vertex_cur[0]);
        index_cur[0] = n_vertices + 0;
        index_cur[1] = n_vertices + 1;
        index_cur[2] = n_vertices + 2;
        index_cur[3] = n_vertices + 1;
        index_cur[4] = n_vertices + 3;
        index_cur[5] = n_vertices + 2;
        SET_TC_ALL(vertex_cur, tpage, clut);
        Draw_EnqueueBuffer(4, 6);
    }
    batch_has_texture |= isTextured;
    batch_reads_destination |= preserve_masked || (code & SEMITRANSP);
    return max_len - len;
}

static bool IsFullWidthBand(const u_long* packets, int length) {
    if (frame_scale_x == 1.0f || length < 3) {
        return false;
    }
    unsigned code = packets[0] >> 24;
    bool tile = (code & 0xfd) == 0x60;
    bool quad = (code & 0xfd) == 0x28;
    bool shaded = (code & 0xfd) == 0x38;
    // Screen-wide TILEs can be queued with the world. Polygons there may be projected geometry.
    if (!tile && !frame_transform_clip) return false;
    if ((!tile && !quad && !shaded) || (quad && length < 5) || (shaded && length < 8)) {
        return false;
    }
    int left = frame_centre_x - display_size.x / 2;
    int right = left + display_size.x;
    if (draw_area_start.x != left || draw_area_end.x + 1 != right) {
        return false;
    }
    int ys[4], xs[4];
    int top = 0, bottom = 0;
    for (int index = 0; index < (tile ? 1 : 4); ++index) {
        u_long xy = packets[index * (shaded ? 2 : 1) + 1];
        int x = s11((short)(xy & 0xffff));
        int y = s11((short)(xy >> 16)) + draw_offset.y;
        float screen_x = x * GetDrawGridXScale() + draw_offset.x;
        if (tile) {
            return screen_x == left &&
                   screen_x + (packets[2] & 0xffff) * GetDrawGridXScale() == right &&
                   (packets[2] >> 16) > 0;
        }
        if (screen_x != left && screen_x != right) {
            return false;
        }
        xs[index] = screen_x == right;
        ys[index] = y;
        if (index == 0 || y < top) top = y;
        if (index == 0 || y > bottom) bottom = y;
    }
    if (top == bottom) return false;
    unsigned corners = 0, colors[2] = {0, 0};
    for (int index = 0; index < 4; ++index) {
        if (ys[index] != top && ys[index] != bottom) return false;
        unsigned row = ys[index] == bottom;
        unsigned color = shaded ? packets[index * 2] & 0xffffff : 0;
        if ((corners & (3u << (row * 2))) && colors[row] != color) return false;
        colors[row] = color;
        corners |= 1u << (xs[index] + 2 * row);
    }
    return corners == 15;
}

int Draw_PushPrim(u_long* packets, int max_len) {
    bool fill = IsFullWidthBand(packets, max_len);
    if (fill) {
        Draw_FlushBuffer();
        frame_transform_bypass = true;
        UpdateScissor();
    }
    int consumed = DrawPrimitive(packets, max_len);
    if (fill) {
        Draw_FlushBuffer();
        frame_transform_bypass = false;
        UpdateScissor();
    }
    return consumed;
}

void Draw_SetAreaStart(int x, int y) {
    Draw_FlushBuffer();
    draw_area_start.x = x;
    draw_area_start.y = y;
}
void Draw_SetAreaEnd(int x, int y) {
    Draw_FlushBuffer();
    draw_area_end.x = x;
    draw_area_end.y = y;
    UpdateScissor();
}
void Draw_SetOffset(int x, int y) {
    Draw_FlushBuffer();

    x = x % VRAM_W;
    y = y % VRAM_H;
    if (x < 0) {
        x += VRAM_W;
    }
    if (y < 0) {
        y += VRAM_H;
    }
    draw_offset.x = x;
    draw_offset.y = y;
}

void Draw_SetMask(int bit0, int bit1) {
    if (force_mask_bit != (bit0 != 0) || preserve_masked != (bit1 != 0)) {
        Draw_FlushBuffer();
        force_mask_bit = bit0 != 0;
        preserve_masked = bit1 != 0;
    }
}

void Draw_ClearImage(PS1_RECT* rect, u_char r, u_char g, u_char b) {
    Draw_FlushBuffer();
    ResolveNativeVram();
    if (rect->w == 0 || rect->h == 0) {
        return;
    }
    if (!sdl3_window && !InitPlatform()) {
        return;
    }
    SDL_GPUCommandBuffer* cmd = AcquireCmd();
    if (!cmd) {
        return;
    }

    Vertex quad[4] = {0};
    quad[0].x = rect->x;
    quad[0].y = rect->y;
    quad[1].x = (short)(rect->x + rect->w);
    quad[1].y = rect->y;
    quad[2].x = rect->x;
    quad[2].y = (short)(rect->y + rect->h);
    quad[3].x = (short)(rect->x + rect->w);
    quad[3].y = (short)(rect->y + rect->h);
    for (int i = 0; i < 4; i++) {
        quad[i].r = (u8)((r >> 3) * 255 / 31);
        quad[i].g = (u8)((g >> 3) * 255 / 31);
        quad[i].b = (u8)((b >> 3) * 255 / 31);
        quad[i].a = 0;
    }

    Vertex* map = SDL_MapGPUTransferBuffer(device, clear_transfer, true);
    if (!map) {
        ERRORF("SDL_MapGPUTransferBuffer: %s", SDL_GetError());
        return;
    }
    memcpy(map, quad, sizeof(quad));
    SDL_UnmapGPUTransferBuffer(device, clear_transfer);

    SDL_GPUCopyPass* copy = SDL_BeginGPUCopyPass(cmd);
    const SDL_GPUTransferBufferLocation src = {.transfer_buffer = clear_transfer};
    const SDL_GPUBufferRegion dst = {
        .buffer = clear_vbuf, .size = sizeof(quad)};
    SDL_UploadToGPUBuffer(copy, &src, &dst, true);
    SDL_EndGPUCopyPass(copy);

    const SDL_GPUColorTargetInfo target = {
        .texture = vram_render,
        .load_op = SDL_GPU_LOADOP_LOAD,
        .store_op = SDL_GPU_STOREOP_STORE,
    };
    SDL_GPURenderPass* pass = SDL_BeginGPURenderPass(cmd, &target, 1, NULL);
    SDL_BindGPUGraphicsPipeline(pass, pipe_clear);
    const SDL_GPUBufferBinding vb = {.buffer = clear_vbuf};
    SDL_BindGPUVertexBuffers(pass, 0, &vb, 1);
    SDL_DrawGPUPrimitives(pass, 4, 1, 0, 0);
    SDL_EndGPURenderPass(pass);
    MarkVramDirty((SDL_Rect){rect->x, rect->y, rect->w, rect->h});
    SyncNativeVramToScaled(rect->x, rect->y, rect->w, rect->h);
}

static bool PrepareImageUpload(PS1_RECT* rect, const u16* source, u8* output) {
    size_t pixels = (size_t)rect->w * rect->h;
    ConvertRgb5551ToRgba8888(source, output, pixels);
    u8* previous = NULL;
    if (preserve_masked) {
        previous = malloc(pixels * 4);
        if (!previous) {
            ERRORF("Cannot allocate masked image transfer");
            return false;
        }
        if (!DownloadVramRegionAsRGBA8888(rect->x, rect->y, rect->w, rect->h, previous)) {
            free(previous);
            return false;
        }
    }
    for (size_t i = 0; i < pixels; ++i) {
        if (previous && previous[i * 4 + 3] >= 128) {
            memcpy(output + i * 4, previous + i * 4, 4);
        } else if (force_mask_bit) {
            output[i * 4 + 3] = 255;
        }
    }
    free(previous);
    return true;
}

void Draw_LoadImage(PS1_RECT* rect, u_long* p) {
    if (rect->w == 0 || rect->h == 0) {
        return;
    }
    if (rect->x < 0 || rect->y < 0 || rect->w < 0 || rect->h < 0 ||
        rect->x + rect->w > VRAM_W || rect->y + rect->h > VRAM_H) {
        WARNF("rect (%d,%d %dx%d) is out of bound %dx%d, skipping upload",
              rect->x, rect->y, rect->w, rect->h, VRAM_W, VRAM_H);
        return;
    }
    if (!sdl3_window && !InitPlatform()) {
        return;
    }
    Draw_FlushBuffer();
    ResolveNativeVram();
    u8* map = SDL_MapGPUTransferBuffer(device, tex_upload_transfer, true);
    if (!map) {
        ERRORF("SDL_MapGPUTransferBuffer: %s", SDL_GetError());
        return;
    }
    bool prepared = PrepareImageUpload(rect, (const u16*)p, map);
    SDL_UnmapGPUTransferBuffer(device, tex_upload_transfer);
    if (!prepared) {
        return;
    }
    SDL_GPUCommandBuffer* cmd = AcquireCmd();
    if (!cmd) {
        return;
    }

    SDL_GPUCopyPass* copy = SDL_BeginGPUCopyPass(cmd);
    const SDL_GPUTextureTransferInfo src = {
        .transfer_buffer = tex_upload_transfer,
        .pixels_per_row = rect->w,
        .rows_per_layer = rect->h,
    };
    const SDL_GPUTextureRegion dst = {
        .texture = vram_render,
        .x = (Uint32)rect->x,
        .y = (Uint32)rect->y,
        .w = rect->w,
        .h = rect->h,
        .d = 1,
    };
    SDL_UploadToGPUTexture(copy, &src, &dst, false);
    SDL_EndGPUCopyPass(copy);
    MarkVramDirty((SDL_Rect){rect->x, rect->y, rect->w, rect->h});
    SyncNativeVramToScaled(rect->x, rect->y, rect->w, rect->h);
}

void Draw_StoreImage(PS1_RECT* rect, u_long* p) {
    if (rect->w == 0 || rect->h == 0) {
        return;
    }
    if (rect->x < 0 || rect->y < 0 || rect->w < 0 || rect->h < 0 ||
        rect->x + rect->w > VRAM_W || rect->y + rect->h > VRAM_H) {
        WARNF("rect (%d,%d %dx%d) is out of bound %dx%d, skipping download",
              rect->x, rect->y, rect->w, rect->h, VRAM_W, VRAM_H);
        return;
    }
    if (!device || !vram_render) {
        return;
    }
    Draw_FlushBuffer(); // flush primitives before operating with the VRAM

    const size_t pixels = (size_t)rect->w * rect->h;
    u8* rgba = malloc(pixels * 4);
    if (!rgba) {
        return;
    }
    if (DownloadVramRegionAsRGBA8888(
            rect->x, rect->y, rect->w, rect->h, rgba)) {
        ConvertRgba8888ToRgb5551(rgba, (u16*)p, pixels);
    }
    free(rgba);
}

void Draw_MoveImage(PS1_RECT* rect, unsigned int x, unsigned int y) {
    if (rect->x == x && rect->y == y && !force_mask_bit) {
        return;
    }
    Draw_FlushBuffer(); // flush primitives before operating with the VRAM
    ResolveNativeVram();

    int src_x = CLAMP(rect->x, 0, VRAM_W - 1);
    int src_y = CLAMP(rect->y, 0, VRAM_H - 1);
    int src_w = CLAMP(rect->w, 0, VRAM_W - src_x);
    int src_h = CLAMP(rect->h, 0, VRAM_H - src_y);
    int dst_x = CLAMP((int)x, 0, VRAM_W - 1);
    int dst_y = CLAMP((int)y, 0, VRAM_H - 1);
    int copy_w = CLAMP(src_w, 0, VRAM_W - dst_x);
    int copy_h = CLAMP(src_h, 0, VRAM_H - dst_y);

    if (src_x != rect->x || src_y != rect->y || src_w != rect->w ||
        src_h != rect->h || dst_x != (int)x || dst_y != (int)y ||
        copy_w != src_w || copy_h != src_h) {
        WARNF("params out of bounds: src=(%d,%d,%d,%d)->(%d,%d,%d,%d) "
              "dst=(%d,%d)->(%d,%d)",
              rect->x, rect->y, rect->w, rect->h, src_x, src_y, src_w, src_h,
              (int)x, (int)y, dst_x, dst_y);
    }

    if (copy_w <= 0 || copy_h <= 0) {
        WARNF("nothing to copy");
        return;
    }

    if (force_mask_bit || preserve_masked) {
        u_long row[VRAM_W / 2];
        for (int i = 0; i < copy_h; ++i) {
            PS1_RECT source = {(short)src_x, (short)(src_y + i), (short)copy_w, 1};
            PS1_RECT target = {(short)dst_x, (short)(dst_y + i), (short)copy_w, 1};
            Draw_StoreImage(&source, row);
            Draw_LoadImage(&target, row);
        }
        return;
    }

    SDL_GPUCommandBuffer* cmd = AcquireCmd();
    if (!cmd) {
        return;
    }
    SDL_GPUCopyPass* copy = SDL_BeginGPUCopyPass(cmd);
    if (!RectsOverlap(src_x, src_y, dst_x, dst_y, copy_w, copy_h)) {
        const SDL_GPUTextureLocation src = {
            .texture = vram_render, .x = (Uint32)src_x, .y = (Uint32)src_y};
        const SDL_GPUTextureLocation bounce = {
            .texture = vram_sample, .x = (Uint32)src_x, .y = (Uint32)src_y};
        const SDL_GPUTextureLocation dst = {
            .texture = vram_render, .x = (Uint32)dst_x, .y = (Uint32)dst_y};
        SDL_CopyGPUTextureToTexture(
            copy, &src, &bounce, (Uint32)copy_w, (Uint32)copy_h, 1, false);
        SDL_CopyGPUTextureToTexture(
            copy, &bounce, &dst, (Uint32)copy_w, (Uint32)copy_h, 1, false);
    } else {
        // Slow-path, simulating real hardware behaviour
        // This behaviour is tested via move_image_overlap
        for (int row = 0; row < copy_h; row++) {
            const SDL_GPUTextureLocation src = {.texture = vram_render,
                                                .x = (Uint32)src_x,
                                                .y = (Uint32)(src_y + row)};
            const SDL_GPUTextureLocation dst = {.texture = vram_render,
                                                .x = (Uint32)dst_x,
                                                .y = (Uint32)(dst_y + row)};
            SDL_CopyGPUTextureToTexture(
                copy, &src, &dst, (Uint32)copy_w, 1, 1, false);
        }
    }
    SDL_EndGPUCopyPass(copy);
    MarkVramDirty((SDL_Rect){dst_x, dst_y, copy_w, copy_h});
    MarkVramDirty((SDL_Rect){src_x, src_y, copy_w, copy_h});
    SyncNativeVramToScaled(dst_x, dst_y, copy_w, copy_h);
}

void Draw_ResetBuffer(void) {
    n_vertices = 0;
    n_indices = 0;
    vertex_cur = vertex_buf;
    index_cur = index_buf;
    batch_has_texture = false;
    batch_reads_destination = false;
}

static SDL_Rect ScaledBatchBounds(void) {
    float minimum_x = (float)VRAM_W, minimum_y = (float)VRAM_H;
    float maximum_x = 0, maximum_y = 0;
    float scale = frame_transform_bypass ? 1.0f : frame_scale_x;
    for (int i = 0; i < n_vertices; ++i) {
        float x = ((vertex_buf[i].x + vertex_buf[i].delta_x) * GetDrawGridXScale() + draw_offset.x - frame_centre_x) * scale + frame_centre_x;
        float y = vertex_buf[i].y + vertex_buf[i].delta_y + draw_offset.y;
        minimum_x = fminf(minimum_x, x);
        minimum_y = fminf(minimum_y, y);
        maximum_x = fmaxf(maximum_x, x);
        maximum_y = fmaxf(maximum_y, y);
    }
    SDL_Rect bounds = {(int)floorf(minimum_x) - 1, (int)floorf(minimum_y) - 1,
        (int)ceilf(maximum_x) - (int)floorf(minimum_x) + 2,
        (int)ceilf(maximum_y) - (int)floorf(minimum_y) + 2};
    SDL_Rect clipped = {0};
    SDL_GetRectIntersection(&bounds, &scissor_rect, &clipped);
    return clipped;
}

void Draw_FlushBuffer(void) {
    if (n_vertices == 0) {
        return;
    }
    const bool scaled_snapshot = internal_res > 1 &&
                                 (framebuffer_sampling || batch_reads_destination);
    if (scaled_snapshot) EnsureScaledSnapshot();
    if (BatchReadsPendingNative()) ResolveNativeVram();
    SDL_GPUCommandBuffer* cmd = AcquireCmd();
    if (!cmd) {
        return;
    }

    if (stream_vertices + n_vertices > STREAM_VERTEX_CAPACITY ||
        stream_indices + n_indices > STREAM_INDEX_CAPACITY) {
        stream_vertices = stream_indices = 0;
        stream_cycle = true;
    }
    u8* map = SDL_MapGPUTransferBuffer(device, vtx_transfer, stream_cycle);
    if (!map) {
        ERRORF("SDL_MapGPUTransferBuffer: %s", SDL_GetError());
        return;
    }
    const Uint32 vtx_size = (Uint32)(sizeof(Vertex) * n_vertices);
    const Uint32 idx_size = (Uint32)(sizeof(*index_buf) * n_indices);
    const Uint32 vtx_offset = stream_vertices * sizeof(Vertex);
    const Uint32 idx_offset = stream_indices * sizeof(*index_buf);
    memcpy(map + vtx_offset, vertex_buf, vtx_size);
    memcpy(map + STREAM_VERTEX_BYTES + idx_offset, index_buf, idx_size);
    SDL_UnmapGPUTransferBuffer(device, vtx_transfer);

    SDL_GPUCopyPass* copy = SDL_BeginGPUCopyPass(cmd);
    const SDL_GPUTransferBufferLocation vtx_src = {
        .transfer_buffer = vtx_transfer, .offset = vtx_offset};
    const SDL_GPUBufferRegion vtx_dst = {
        .buffer = vbuf, .offset = vtx_offset, .size = vtx_size};
    SDL_UploadToGPUBuffer(copy, &vtx_src, &vtx_dst, stream_cycle);
    const SDL_GPUTransferBufferLocation idx_src = {
        .transfer_buffer = vtx_transfer, .offset = STREAM_VERTEX_BYTES + idx_offset};
    const SDL_GPUBufferRegion idx_dst = {
        .buffer = ibuf, .offset = idx_offset, .size = idx_size};
    SDL_UploadToGPUBuffer(copy, &idx_src, &idx_dst, stream_cycle);
    stream_cycle = false;
    if ((batch_has_texture || batch_reads_destination) &&
        vram_dirty.w > 0 && vram_dirty.h > 0) {
        const SDL_GPUTextureLocation vram_src = {.texture = vram_render,
                                                 .x = (Uint32)vram_dirty.x,
                                                 .y = (Uint32)vram_dirty.y};
        const SDL_GPUTextureLocation vram_dst = {.texture = vram_sample,
                                                 .x = (Uint32)vram_dirty.x,
                                                 .y = (Uint32)vram_dirty.y};
        SDL_CopyGPUTextureToTexture(
            copy, &vram_src, &vram_dst, (Uint32)vram_dirty.w,
            (Uint32)vram_dirty.h, 1, false);
        ResetVramDirty();
    }
    if (scaled_snapshot) SnapshotScaledVram(copy);
    SDL_EndGPUCopyPass(copy);

    const SDL_GPUColorTargetInfo target = {
        .texture = GetRenderTarget(),
        .load_op = SDL_GPU_LOADOP_LOAD,
        .store_op = SDL_GPU_STOREOP_STORE,
    };
    SDL_GPUDepthStencilTargetInfo depth_target;
    if (batch_depth_mode) depth_target = GeometryDepthTarget();
    SDL_GPURenderPass* pass = SDL_BeginGPURenderPass(cmd, &target, 1,
        batch_depth_mode ? &depth_target : NULL);
    {
        const float render_scale = (float)internal_res;
        const SDL_GPUViewport grid_viewport = {
            .x = 0.0f,
            .y = 0.0f,
            .w = (float)VRAM_W * render_scale,
            .h = (float)VRAM_H * render_scale,
            .min_depth = 0.0f,
            .max_depth = 1.0f,
        };
        SDL_SetGPUViewport(pass, &grid_viewport);
    }
    SDL_Rect scaled_scissor = {
        scissor_rect.x * (int)internal_res, scissor_rect.y * (int)internal_res,
        scissor_rect.w * (int)internal_res, scissor_rect.h * (int)internal_res};
    SDL_SetGPUScissor(pass, &scaled_scissor);
    const SDL_GPUBufferBinding vb = {.buffer = vbuf, .offset = vtx_offset};
    SDL_BindGPUVertexBuffers(pass, 0, &vb, 1);
    const SDL_GPUBufferBinding ib = {.buffer = ibuf, .offset = idx_offset};
    SDL_BindGPUIndexBuffer(pass, &ib, SDL_GPU_INDEXELEMENTSIZE_16BIT);
    const SDL_GPUTextureSamplerBinding sampler_bindings[2] = {
        {.texture = vram_sample, .sampler = vram_sampler},
        {.texture = scaled_snapshot ? scaled_vram_sample : vram_sample,
         .sampler = vram_sampler}};
    SDL_BindGPUFragmentSamplers(pass, 0, sampler_bindings, 2);
    const float transform = frame_transform_bypass ? 1.0f : frame_scale_x;
    const float grid = GetDrawGridXScale();
    const float offset_ubo[8] = {
        (float)draw_offset.x, (float)draw_offset.y,
        0.5f / ((float)internal_res * grid * transform),
        0.5f / (float)internal_res,
        grid * transform,
        draw_offset.x * (1.0f - grid) * transform + frame_centre_x * (1.0f - transform),
        0.0f, 0.0f};
    SDL_PushGPUVertexUniformData(cmd, 0, offset_ubo, sizeof(offset_ubo));

    const struct {
        Uint32 force_mask, preserve;
        float scale;
        Uint32 framebuffer;
    } fragment_ubo = {force_mask_bit, preserve_masked, (float)internal_res,
                     framebuffer_sampling | (texture_screen_aligned << 1) |
                     (scaled_snapshot << 2)};
    SDL_PushGPUFragmentUniformData(cmd, 0, &fragment_ubo, sizeof(fragment_ubo));
    SDL_BindGPUGraphicsPipeline(pass, batch_depth_mode == 1 ? pipe_depth_write :
                                    batch_depth_mode == 2 ? pipe_depth_read : pipe_tri);
    SDL_DrawGPUIndexedPrimitives(pass, (Uint32)n_indices, 1, 0, 0, 0);
    SDL_EndGPURenderPass(pass);
    if (internal_res <= 1) {
        MarkVramDirty(scissor_rect);
    }
    if (internal_res > 1) {
        const SDL_Rect dirty = ScaledBatchBounds();
        MarkNativeResolve(dirty);
        MarkScaledVramDirty(dirty);
    }
    stream_vertices += n_vertices;
    stream_indices += n_indices;
    Draw_ResetBuffer();
}
