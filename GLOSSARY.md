# RE:INTEGRAL presentation and modding

Language for preserving native gameplay while authoring the game's presentation.

## Language

**Prepared content**:
Original disc content converted into local authoring resources with verified source identity. Preparation establishes availability, not complete scene assembly or playability.
_Avoid_: Supported scene, completed stage

**Native test**:
A session of the recovered game exercising real gameplay and presentation together. Its results establish only the behavior actually observed.
_Avoid_: Editor preview, campaign playthrough

**Presentation acceptance**:
Evidence that a specified scene or visual category meets its appearance, behavior and timing requirements. Resource presence and successful compilation are separate milestones.
_Avoid_: Prepared content, source present

**Authored visibility**:
A modder's choice to show or hide their visual content. It remains independent of whether the corresponding native actor currently exists or is visible.
_Avoid_: Native availability

**Native availability**:
Whether a current native actor instance resolves to an authored target. An available actor may still be natively invisible.
_Avoid_: Authored visibility

**Declaration**:
An original scene instruction identifying how an actor is created. It exists independently of whether that actor is currently active, and distinguishes actors that share a model or message name.
_Avoid_: Live actor, model asset

**Runtime actor**:
One live incarnation of a native actor in a particular game session and scene. A declaration may produce no runtime actor, one actor, or multiple actors.
_Avoid_: Declaration, model asset

**Part anchor**:
An attachment target following the native pose of an original model part. It remains meaningful when the original part's visual is hidden or replaced.
_Avoid_: Replacement mesh, whole actor position

**Cinematic clip**:
An original timed sequence identified by its source disc and stream identity. Presentation edits change its shots while preserving its native story and audio timing.
_Avoid_: Map, gameplay stage

**Legacy**:
The preserved0.2 renderer and its original presentation behavior, used as the reference for the compatibility mode.
_Avoid_: Godot scene rendering

**Legacy through Godot**:
The compatibility mode that presents Legacy visuals through Godot. Matching inputs and display settings must produce the same appearance and controls as Legacy.
_Avoid_: Godot scene rendering, enhanced graphics

**Native audio authority**:
The original game's control over which sounds start, stop, fade and finish. A renderer's scene preparation is separate from these audio decisions.
_Avoid_: Renderer-owned audio lifetime

**Presentation wait**:
Extra real time spent waiting for the renderer to prepare a scene, beyond the original game's own scene transition.
_Avoid_: Native scene transition, scripted pause

**Water region**:
An authored water surface and its bounded underwater appearance. Its visual settings do not change native swimming, oxygen or collision.
_Avoid_: Native water actor, gameplay volume

**Snow volume**:
An authored region of falling snow that is blocked by scene surfaces, including their reverse sides. Flakes may settle and fade; the volume does not build up a snow layer or change native collision.
_Avoid_: Snow accumulation, gameplay weather
