# Equipped-camera encoder memory correction

The camera item still assigned its compression workspace and output to literal
PlayStation addresses `0x801b1000` and `0x801a1000`. Those addresses are not mapped
by this native process. Taking a photograph would reach writes through them.

For native builds, `JpegTryCompressFrame` now uses `PACK_ADDR1` and the region
64 KiB before it. These are the original packet-memory locations translated to
the native backing array. The existing actor already stops drawing and switches
packet allocation before compression, then restores it after the save dialog.
The encoder, quantization retry loop and original photo format are preserved.

`mgs_camera_capture_test` executes the actual recovered encoder on four synthetic
288 × 176 images: black, white, a color gradient and deterministic noise. Expected
stream hashes, encoded lengths, decoded lengths and framebuffer-read counts come
from executing the original Integral MIPS functions. The gradient requires 14
quantization attempts; noise requires 11. All four native results match exactly,
and checks verify writes stay within the native workspace/output region.

The fixture supplies pixel readback at the `StoreImage` boundary. It does not
establish controller-driven photography, GPU readback fidelity, or the photo-save
UI round trip. The separate album tests validate its recovered reader and editing
code. Original title/menu formatting in this touched file also uses the caller's
64-byte title and 32-byte menu limits.

Scoped Aislop reports no errors or fixable findings. Two inherited long actor
functions remain nonfixable complexity warnings.
