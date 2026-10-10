/* Controlled external callbacks for camera/control/motion comparisons. */
DG_TEX *brf_800CABF4(BriefingGraphWork *work, int id) {
  Trace(3, 0x800cabf4u, Normalize((uintptr_t)work), id);
  return Texture();
}
void brf_800CAC7C(BriefingGraphWork *work, int id) {
  Trace(3, 0x800cac7cu, Normalize((uintptr_t)work), id);
}
void brf_800CADD4(BriefingGraphWork *work, void *a1, int a2) {
  Trace(4, 0x800cadd4u, Normalize((uintptr_t)work), Normalize((uintptr_t)a1),
        a2);
}
void brf_800CBB68(BriefingGraphWork *work, void *a1, int a2) {
  Trace(4, 0x800cbb68u, Normalize((uintptr_t)work), Normalize((uintptr_t)a1),
        a2);
}
int brf_800CC5E4(BriefingGraphWork *work, POLY_FT4 *a2, POLY_FT4 *a3) {
  Trace(4, 0x800cc5e4u, Normalize((uintptr_t)work), Normalize((uintptr_t)a2),
        Normalize((uintptr_t)a3));
  return variant % 3;
}
void brf_800CDAEC(POLY_FT4 *packets, int count, int *data, int x, int y,
                  int scale, int divisor) {
  Trace(8, 0x800cdaecu, Normalize((uintptr_t)packets), count,
        Normalize((uintptr_t)data), x, y, scale, divisor);
}
