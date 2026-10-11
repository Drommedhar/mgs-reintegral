#ifndef MGS_VIDEO_H
#define MGS_VIDEO_H

typedef struct {
    unsigned width, height;
    int widescreen, fullscreen;
} MgsVideoOptions;

enum { MGS_VIDEO_HUD, MGS_VIDEO_WORLD, MGS_VIDEO_CANVAS, MGS_VIDEO_BACKGROUND };

int MgsVideoParseResolution(const char *text, MgsVideoOptions *options);
int MgsVideoConfigure(const MgsVideoOptions *options);
int MgsVideoCapturesOutput(void);
int MgsVideoHalfWidth(void);
float MgsVideoHorizontalScale(void);
int MgsVideoReferenceRequired(void);
void MgsVideoExpandClip(short *minimum, short *maximum);
void MgsVideoTagChannel(void *environment, int world);
void MgsVideoSetDrawMode(void *packet, int mode);
void MgsVideoBeginFrame(int which);
void MgsVideoEndFrame(void);
void MgsVideoMovie(int active);
void MgsVideoCodec(int active);
void MgsVideoStage(const char *name);

#endif
