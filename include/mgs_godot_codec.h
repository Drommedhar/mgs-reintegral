#ifndef MGS_GODOT_CODEC_H
#define MGS_GODOT_CODEC_H

#include "mgs_godot_subtitles.h"

#define MGS_GODOT_CODEC_CAPABILITY 2097152u
#define MGS_CODEC_IMAGE_BYTES (64u * 96u + 512u)

typedef struct {
    uint32_t active, incoming, mode, frequency, action, signal, fade, scanline;
    uint32_t wait_mark, exit_hint, memory, memory_top, memory_selected;
    uint32_t memory_count, memory_animation, reserved;
} MgsCodecFrame;

typedef struct {
    int32_t x, y, width, height;
    uint32_t previous_weight;
    int32_t bracket, scanline;
    uint32_t visible;
} MgsCodecFace;

int MgsGodotOwnsCodec(void);
void MgsGodotResetCodec(void);
MgsCodecFrame *MgsGodotCodecFrame(void);
MgsCodecFace *MgsGodotCodecFace(unsigned side);
void MgsGodotCodecImage(unsigned side, unsigned x, unsigned y,
                       unsigned width, unsigned height, const void *pixels);
void MgsGodotCodecPalette(unsigned side, const void *palette);
void MgsGodotCodecBackup(unsigned side);
void MgsGodotCodecBeginText(const void *buffer);
void MgsGodotCodecText(MgsSubtitleFrame frame);
void MgsGodotCodecContact(unsigned index, unsigned frequency);
void MgsGodotPublishCodec(void);

#endif
