# RT Fluid/Blood Rendering Investigation History

Status: postponed.

This document records the Linux/GZDoom RT fluid blood rendering investigation so it can be resumed later without relying on chat history. The goal was to make `rt_fluid` blood resemble the Windows version more closely. The current Linux result is improved compared with the starting point, but still does not look as good as the Windows version, so further investigation is deferred.

## Current State

The current normal-rendered result is mostly flat blood/splatter instead of the original severe spherical/circular artifacts. However, it still does not match the Windows version visually.

Known current behavior:

- Full-screen blood overlay is gone.
- Through-wall/flooding behavior is reduced compared with the initial state.
- The most obvious repeated spherical caps/rims were reduced by surface/depth rejection.
- Debug views still show that the underlying fluid mask is a large projected particle volume.
- The final look is still not satisfactory compared with Windows.

The latest runtime log marker should include:

```text
material=prelit-smooth-blood roughness=0.30 edge-erode=1px rim-cull=0.64 center-depth=1 surface-decal=1 tunable-depth-window=1 tunable-surface-normal-cull=1 history-normal=sky reactivity=1 debug-viz=1 reflrefr=off
```

## Runtime Debug Setup

`.vscode/launch.json` was modified so VS Code F5 launches with fluid debug logging:

```text
-rtfluiddebug
+logfile /tmp/gzdoom-rt-fluid.log
GZDOOM_RT_FLUID_DEBUG=1
```

Main log path:

```text
/tmp/gzdoom-rt-fluid.log
```

Active runtime shader directory:

```text
/home/rgrabowski/Games/gzdoom-rt/rt/shaders
```

Active runtime cache path:

```text
/home/rgrabowski/.cache/gzdoom-rt/runtime/current
```

## Build And Shader Install Commands Used

Shader compilation was done from:

```text
libraries/RTGL/Source/Shaders
```

Common commands:

```sh
wine ../../Source/VulkanSDK/1.3.280.0/Bin/glslc.exe --target-env=vulkan1.2 -I ../Generated/ Fluid_Visualize.frag -o ../../Build/shaders/Fluid_Visualize.frag.spv
wine ../../Source/VulkanSDK/1.3.280.0/Bin/glslc.exe --target-env=vulkan1.2 -I ../Generated/ RtRaygenPrimary.rgen -o ../../Build/shaders/RtRaygenPrimary.rgen.spv
cmake --build build/Debug/rt --parallel
```

Wine may print USB-related warnings such as `UDEV monitor creation failed`; those were harmless when the exit code was `0`.

Runtime shader copy:

```sh
cp libraries/RTGL/Build/shaders/Fluid_Visualize.frag.spv /home/rgrabowski/Games/gzdoom-rt/rt/shaders/Fluid_Visualize.frag.spv
cp libraries/RTGL/Build/shaders/RtRaygenPrimary.rgen.spv /home/rgrabowski/Games/gzdoom-rt/rt/shaders/RtRaygenPrimary.rgen.spv
```

Verification:

```sh
sha256sum libraries/RTGL/Build/shaders/RtRaygenPrimary.rgen.spv /home/rgrabowski/Games/gzdoom-rt/rt/shaders/RtRaygenPrimary.rgen.spv
```

Latest installed `RtRaygenPrimary.rgen.spv` hash from this session:

```text
99e14a1f48f4fae1e675e32c939e392d40ccb2a6974e0de3066aaa3de0d46f93
```

Earlier useful shader hashes recorded during the investigation:

```text
9b3cbb93f13f78c3ea318e21a90927697550b13cdd59519845c232c92977fc9e  Fluid_Visualize.frag.spv
ea0739b1c0d12bc48dda4b0e456e785ad1134299bb61d4285eec2261318be185  RtRaygenPrimary.rgen.spv
afb8de9c1f42bbc3a533704ccd7bc9d1a7beacbbed2d5f4a606e04c11633f93f  RtRaygenPrimary.rgen.spv
37ce2ac07cb2b3d305690e3efd4c9acb9604bd83a1ad8101836230cb01a12881  RtRaygenPrimary.rgen.spv
81e7e24ad851bb80dffad52208893d908aae6b728b7179225c7ccaced0e6e10b  RtRaygenPrimary.rgen.spv
99e14a1f48f4fae1e675e32c939e392d40ccb2a6974e0de3066aaa3de0d46f93  RtRaygenPrimary.rgen.spv
```

## Files Changed

Top-level:

- `.vscode/launch.json`
- `src/common/rendering/rt/rt_main.cpp`

RTGL submodule/worktree:

- `libraries/RTGL/Include/RTGL1/RTGL1.h`
- `libraries/RTGL/Source/DrawFrameInfo.h`
- `libraries/RTGL/Source/Fluid.cpp`
- `libraries/RTGL/Source/Fluid.h`
- `libraries/RTGL/Source/Generated/GenerateShaderCommon.py`
- `libraries/RTGL/Source/Generated/ShaderCommonC.h`
- `libraries/RTGL/Source/Generated/ShaderCommonGLSL.h`
- `libraries/RTGL/Source/Shaders/Fluid_DepthSmooth.comp`
- `libraries/RTGL/Source/Shaders/Fluid_Generate.comp`
- `libraries/RTGL/Source/Shaders/Fluid_Visualize.frag`
- `libraries/RTGL/Source/Shaders/RaygenPrimary.inl`
- `libraries/RTGL/Source/VulkanDevice.cpp`
- `libraries/RTGL/Source/VulkanDevice.h`

## Change History

### 1. Added Fluid Debug Logging

Added `RT_FluidDebugLogEnabled()` in `src/common/rendering/rt/rt_main.cpp`.

When enabled by `-rtfluiddebug` or `GZDOOM_RT_FLUID_DEBUG=1`, RTGL messages are mirrored into the GZDoom log. Fluid frame params are logged when changed, including enabled state, budget, radius, gravity, blood color, debug mode, smoothing settings, and material/debug tags.

`RT_SpawnFluid` also logs spawn attempts and skipped spawns:

- requested count
- clamped count
- Doom-space and meter-space positions
- velocity
- source radius
- dispersion velocity
- dispersion angle

### 2. Added RTGL Fluid Internal Logging

`libraries/RTGL/Source/Fluid.cpp` gained debug logs for:

- fluid creation/destruction
- source adds
- ignored sources
- reset
- source scheduling
- particles overwritten in the ring buffer
- simulate dispatches
- visualize dispatches
- smoothing skip/cap behavior

This confirmed that fluid sources were being spawned, active particle counts grew, and visualization/simulation continued every frame.

### 3. Added Memory Barriers Around Fluid Data

Additional barriers were added around simulation/visualization/depth smoothing paths to avoid stale particle or framebuffer data hazards.

This was a stability/correctness step during the early investigation. It did not fully solve the circular artifact problem.

### 4. Spread Spawn Positions

`libraries/RTGL/Source/Shaders/Fluid_Generate.comp` was changed so spawned particles are distributed around the source position:

```glsl
p.position = src.position + spawnDir * ( SmoothingRadius * 0.45 * rnd.x );
```

This reduced the initial compact "mushroom head" look somewhat, but did not fix the circular/rim artifacts.

### 5. Hardened Fluid Depth Smoothing

`libraries/RTGL/Source/Shaders/Fluid_DepthSmooth.comp` rejects invalid/sky depth values and writes neutral output for invalid pixels:

- invalid depth becomes `1.0`
- invalid normal becomes neutral

The smoothing pass was investigated because it uses a large bilateral radius and can expand/smear sparse particle masks. It amplifies the projected volume footprint, but later tests showed it was not the only cause: raw/no-smoothing mode still showed particle caps.

### 6. Changed Fluid Visualize Impostor Rules

`libraries/RTGL/Source/Shaders/Fluid_Visualize.frag` was modified several times:

- rejects invalid sphere center/depth
- discards outer impostor footprint
- applies rim/glancing normal cull
- writes conservative depth using the maximum of surface and center depth

The important current ideas are:

- avoid invalid/sentinel depth
- avoid projecting the front half of a sphere through nearby geometry
- reduce side/rim pixels

These changes reduced severe through-wall/flood behavior, but the visible circles remained because the renderer still generated sphere-like particle masks.

### 7. Removed No-Hit/Sky Fluid Path In Primary Raygen

`libraries/RTGL/Source/Shaders/RaygenPrimary.inl` was changed so fluid is only attempted after a real primary hit.

This fixed the earlier full-screen blood overlay/flooding problem. Previously, sky/no-hit pixels could accept fluid depth or invalid/sentinel depth and contaminate the frame.

Key checks added:

- invalid fluid depth rejection
- sky/no-hit primary rejection
- fluid vs primary depth checks
- neighbor erosion of the fluid mask
- invalid normal rejection

### 8. Changed Blood Material Handling

The blood path was changed away from earlier glass/lava/checker experiments and toward a prelit/synthetic surface:

- blood albedo based on `globalUniform.fluidColor`
- low-frequency smooth color variation
- no checker/floor hash procedural noise
- roughness around `0.30`
- no reflective/refractive real geometry path
- writes as a sky-like synthetic surface with invalid visibility
- history/reactivity handling adjusted

This fixed black/invalid-looking halos caused by visibility/lighting contamination, but did not solve the particle-circle silhouette itself.

### 9. Added Runtime Debug Modes

Added console variable:

```text
rt_fluid_debug_mode
```

Values:

```text
0 = normal rendering
1 = accepted fluid mask
2 = accepted fluid normal
3 = accepted fluid depth bands
4 = rejection reasons
```

Mode `4` paints rejected pixels too, so it intentionally looks much larger/noisier than final blood. Its purpose is to show why pixels were rejected.

Debug color meanings in the latest implementation:

```text
green  = accepted
yellow = rejected by depth window, fluid in front of target window
orange = rejected by depth window, fluid behind target window
cyan   = rejected by neighbor edge erosion
blue   = packed invalid normal path
purple = decoded invalid normal path
red    = rejected by surface normal alignment
```

### 10. Added Smoothing Control

Added console variable:

```text
rt_fluid_smooth_passes
```

Values:

```text
-1 = default smoothing
 0 = raw rasterized fluid output, no smoothing
positive values = cap smoothing iterations
```

Positive values are rounded to a completed ping-pong pair because smoothing alternates between `DepthFluid` and `DepthFluidTemp`, while raygen reads `DepthFluid`.

This proved:

- smoothing makes the debug footprint very large
- raw mode still shows circular particle caps
- therefore the root visible artifact is not smoothing alone; it is the particle/sphere mask itself

### 11. Converted Accepted Fluid To Surface Decal-Like Writes

Raygen was changed so accepted fluid writes at the primary hit surface:

- uses primary hit depth
- uses primary hit position
- uses primary hit motion vectors
- uses primary hit NDC depth

This avoids using the front sphere depth for the final G-buffer write.

This alone did not solve the artifact because the accepted mask was still based on the projected sphere footprint.

### 12. Added Surface/Depth Acceptance Gates

The accepted fluid mask now uses:

- a depth window around the real primary hit surface
- a surface normal alignment test between fluid sphere normal and real hit normal

This significantly reduced repeated spherical cap artifacts in normal rendering.

The current defaults are:

```text
rt_fluid_depth_window_scale 1.15
rt_fluid_min_depth_window 0.035
rt_fluid_surface_normal_cull 0.72
```

These are now live-tunable CVARs.

## Current CVARs Relevant To Fluid Blood

Existing/core:

```text
rt_fluid
rt_fluid_budget
rt_fluid_pradius
rt_fluid_gravity_x
rt_fluid_gravity_y
rt_fluid_gravity_z
rt_blood_color_r
rt_blood_color_g
rt_blood_color_b
```

Debug/tuning added during this investigation:

```text
rt_fluid_debug_mode
rt_fluid_smooth_passes
rt_fluid_depth_window_scale
rt_fluid_min_depth_window
rt_fluid_surface_normal_cull
```

Recommended normal testing baseline:

```text
rt_fluid_debug_mode 0
rt_fluid_smooth_passes -1
rt_fluid_depth_window_scale 1.15
rt_fluid_min_depth_window 0.035
rt_fluid_surface_normal_cull 0.72
```

Suggested "more blood, some risk of circles" test:

```text
rt_fluid_surface_normal_cull 0.66
rt_fluid_depth_window_scale 1.25
rt_fluid_min_depth_window 0.035
```

Suggested "cleaner, more sparse" test:

```text
rt_fluid_surface_normal_cull 0.78
rt_fluid_depth_window_scale 1.00
rt_fluid_min_depth_window 0.025
```

## How Tuning Values Affect The Result

### `rt_fluid_surface_normal_cull`

Default:

```text
0.72
```

Meaning: required alignment between the decoded fluid sphere normal and the real primary hit surface normal.

Effects:

- Higher values reject more sphere side/rim pixels.
- Higher values produce cleaner but thinner/sparser blood.
- Lower values keep more blood but can reintroduce circular particle silhouettes.

Useful range:

```text
0.60 to 0.80
```

### `rt_fluid_depth_window_scale`

Default:

```text
1.15
```

Meaning: multiplier for `rt_fluid_pradius`; controls how far from the primary hit surface fluid depth may be and still be accepted.

Effects:

- Higher values accept more projected fluid volume.
- Higher values create larger/thicker pools but can bring back blobs/rings.
- Lower values keep blood closer to the real surface and reduce sphere footprint.

Useful range:

```text
0.80 to 1.35
```

### `rt_fluid_min_depth_window`

Default:

```text
0.035
```

Meaning: minimum depth acceptance window in meters.

Effects:

- Higher values preserve more blood, especially with small particle radii.
- Lower values reject more aggressively and can make blood sparse or holey.

Useful range:

```text
0.02 to 0.05
```

## Key Conclusions

The early full-screen overlay was likely caused by accepting fluid on no-hit/sky pixels and/or accepting invalid/sentinel fluid depth. Removing the no-hit fluid path and adding invalid checks fixed that class of bug.

The black/dark halo behavior was likely invalid lighting/visibility contamination. Treating fluid as a synthetic prelit surface with invalid visibility made the material look more blood-like.

The remaining circular/spherical artifacts came from using camera-facing sphere impostors as the blood mask. Smoothing made the footprint larger, but was not the sole root cause.

The most effective current mitigation is not another material color tweak; it is rejection of sphere-side pixels using primary surface depth and primary surface normal.

## Why This Is Postponed

Even after the above improvements, the Linux result still does not visually match the Windows version. The current path is a set of mitigations around a particle/sphere-impostor mask. A better match may require understanding what the Windows version does differently rather than continuing to tune thresholds.

## Recommended Resume Plan

When this investigation resumes:

1. Compare against the Windows version directly.
2. Determine whether Windows uses a different fluid visualization path, shader version, particle radius, smoothing setup, or asset/mod behavior.
3. Capture equivalent debug views on both versions if possible.
4. Check whether the Linux path is loading different SPIR-V, different defaults, or different runtime assets.
5. Revisit `Fluid_Visualize.vert/frag`; the real fix may be a non-spherical splat/decal representation for settled blood, not further raygen rejection.
6. Consider adding settled/contact state to particles so floor blood becomes flattened splats while airborne fluid can remain volumetric.

## Useful Code Pointers

Fluid frame params and CVAR bridge:

```text
src/common/rendering/rt/rt_main.cpp
```

RTGL fluid simulation/visualization scheduling:

```text
libraries/RTGL/Source/Fluid.cpp
libraries/RTGL/Source/VulkanDevice.cpp
```

Fluid particle generation:

```text
libraries/RTGL/Source/Shaders/Fluid_Generate.comp
```

Fluid depth smoothing:

```text
libraries/RTGL/Source/Shaders/Fluid_DepthSmooth.comp
```

Fluid impostor rasterization:

```text
libraries/RTGL/Source/Shaders/Fluid_Visualize.vert
libraries/RTGL/Source/Shaders/Fluid_Visualize.frag
```

Primary raygen fluid acceptance and synthetic G-buffer writes:

```text
libraries/RTGL/Source/Shaders/RaygenPrimary.inl
```

