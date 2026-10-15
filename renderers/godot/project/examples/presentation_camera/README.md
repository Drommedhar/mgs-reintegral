# Presentation camera

Copy this folder into your mod workspace and instance `camera.tscn` in a map overlay.
Position the Camera3D using the ordinary editor camera preview. Parent it to an
authored rig or native actor binding if it should follow that object. Export includes
only the camera, script and your authored resources; this example contains no game data.

The script exposes three selection scopes:

- `gameplay`: yields while a native cinematic is active.
- `clip`: applies only to `clip_id`, using the prepared disc/stream identity shown in
  the scene browser. Missing or unprepared IDs report an error.
- `always`: controls presentation throughout the stage, including cinematics.

Disable `enabled`, hide the camera/parent, or remove the node to return to the native
camera or edited original clip. Two simultaneously eligible cameras are an error;
enable only the intended shot. The renderer copies the camera's world transform,
perspective lens, clipping, offsets, cull mask, Environment and CameraAttributes.
Use ordinary Camera3D FOV/Keep Aspect semantics. The internal metadata layer is
always excluded. Orthographic/frustum projection is currently rejected explicitly.

The script controls selection through the SDK, not Camera3D's `current` property.
Call `cut()` after an abrupt scripted change to reset temporal history. Ownership
changes already request a reset. Smooth movement does not repeatedly reset it.

For procedural rigs, the visual API's `camera_update_requested` signal runs after
native world poses and the native/edited clip camera are ready, before selection,
billboard sorting and depth rendering. `get_camera()` then exposes that base view.
Update your own Camera3D during this signal; do not overwrite the returned camera.
Native gameplay, perception, animation and story time remain unchanged.

For a custom shot synchronized to a native cinematic, instance
`native_timeline.tscn` instead. Its root selects the Camera3D, AnimationPlayer,
animation and exact clip ID. The included pan/zoom targets the docks introduction;
use normal camera preview and Animation tracks to author your shot. Native frames
drive the player at 30 source frames per second. Pauses hold, skipped frames seek,
markers reset camera history, and native completion releases the view. Shorter
animations hold their final pose; longer animations are rejected.

Animate descendant pivots and cameras; keep the root transform fixed so map
coordinate conversion remains intact. Missing prepared clip IDs report an error
before native playback. Method/audio/playback tracks,
capture, looping and root-motion extraction are rejected. Runtime autoplay is
disabled; editor scrubbing remains normal. The example contains only authored
keys and its original clip reference, never original camera animation data.
