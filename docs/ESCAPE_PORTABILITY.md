# Existing escape-stage C portability

Fourteen already recovered `s19b` translation units now pass native Windows x86 `-Wall -Wextra` syntax checks without warnings. This is a bounded source audit; the partial actors, shared data recovery and stage integration are separate work.

The substantive fix is in [jeep spark packet initialization](../vendor/mgs/source/overlays/s19b/takabe/jeep/jspark.c). Its original four-byte tag copy did not initialize the native packet's separate length field. The native branch now uses the typed FT4 initializer and preserves semitransparency, texture fields and later shading. Scratch storage continues through the existing native scratchpad interface.

`mgs_jeep_packets_test` exercises the actual initializer and shader with zero through eight packets. It verifies full length, command, texture coordinates/page/palette, color, untouched coordinates and allocation sentinels. An isolated executable using the original initializer fails with length `0xa5a5a5a5`; the fixed initializer passes. The old-code countercheck does not modify live vendor source.

The remaining edits explicitly initialize vector padding, mark unused original ABI parameters and remove one unused local. Shared JeepSystem offsets and external typed data remain compatible with the actor recovery. No gameplay behavior or missing constructor is replaced by a stub.

The source scan has no errors or fixable warnings. Seven nonfixable function-length findings remain in the existing recovered code; the test/helper scan has no findings. This audit does not establish a complete escape-stage build or runtime result. [The ledger](data/escape_portability.json) lists all fourteen audited files, actual modified paths and validation scope. [The incremental patch](../patches/mgs-escape-portability.patch) excludes the partial actors and shared overlay data.
