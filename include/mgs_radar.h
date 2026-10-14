#ifndef MGS_RADAR_H
#define MGS_RADAR_H

#include <stdint.h>

#define MGS_RADAR_CONTACT_LIMIT 96u
#define MGS_RADAR_WALL_LIMIT 4096u

enum MgsRadarMode {
    MGS_RADAR_MAP, MGS_RADAR_JAMMING, MGS_RADAR_EVASION, MGS_RADAR_ALERT,
    MGS_RADAR_CUSTOM, MGS_RADAR_COUNTDOWN
};
enum MgsRadarContactKind {
    MGS_RADAR_PLAYER, MGS_RADAR_NEAR_CONTACT, MGS_RADAR_OTHER_FLOOR, MGS_RADAR_NOISE
};
enum MgsRadarWallKind { MGS_RADAR_WALL, MGS_RADAR_OTHER_FLOOR_WALL, MGS_RADAR_SPECIAL_WALL };

typedef struct { int32_t x, y; } MgsRadarPoint;

typedef struct {
    MgsRadarPoint position;
    uint32_t kind, actor_index, attributes, color;
    MgsRadarPoint noise[16];
} MgsRadarContact;

typedef struct {
    MgsRadarPoint points[4];
    uint32_t color, fade_color;
} MgsRadarSight;

typedef struct {
    MgsRadarPoint points[2];
    uint32_t kind, dynamic;
} MgsRadarWall;

typedef struct {
    uint32_t active, mode, tick;
    int32_t x, y, scale, alert_level, recovery_counter, console_x, console_y;
    int32_t countdown;
    uint32_t map_visible, has_noise, noise_seed;
} MgsRadarFrame;

typedef struct {
    MgsRadarFrame frame;
    uint32_t contact_count, sight_count, wall_count;
    MgsRadarContact contacts[MGS_RADAR_CONTACT_LIMIT];
    MgsRadarSight sights[MGS_RADAR_CONTACT_LIMIT];
    MgsRadarWall walls[MGS_RADAR_WALL_LIMIT];
} MgsRadarView;

void MgsRadarBeginFrame(int enabled, int owns_drawing);
int MgsRadarOwnsDrawing(void);
void MgsRadarPresent(MgsRadarFrame frame);
void MgsRadarShowMap(void);
void MgsRadarSetNoise(uint32_t seed);
void MgsRadarSetCountdown(int ticks);
void MgsRadarAddContact(const MgsRadarContact *contact);
void MgsRadarAddSight(const MgsRadarSight *sight);
void MgsRadarAddWall(const MgsRadarWall *wall);
/* Coordinates are relative to the radar center (269+x, 42+y), in a 320x224 UI. */
const MgsRadarView *MgsRadarGetView(void);

#endif
