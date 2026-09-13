RS_Darkness
===========

Darkness as a shader term. Replaces the darkening half of DarkDoomZ.

Load it with DarkDoomZ UNLOADED, or set ddz_mode 0. Otherwise DarkDoomZ's
per-sector rewrite runs underneath this and you get both.


WHY NOT PER-SECTOR
------------------

DarkDoomZ walks every sector and overwrites Sector.LightLevel through a curve.
That is what a mod had to do when a sector's light level was the only lever
available. It costs:

* It is uniform per room. A 4096-unit hall is one flat dimness wall to wall,
  because a sector holds exactly one number.

* It is destructive playsim state. It keeps a backup array of every sector's
  original light so it can undo itself, and when its own lighting option is
  off it DESTROYS every Lighting thinker rather than fight them for the same
  field. Doom's blinking and flickering sectors are collateral.

* No spatial term is possible. Darkness cannot deepen with distance or pool at
  floor level, because one number per room cannot say where you are standing.

* Liveness costs a network event every single tic -- UiTick fires
  SendNetworkEvent("UpdateLights") forever, and the handler early-outs unless
  a CVar moved.

The engine already carries the replacement. Level.SetDarkness runs the SAME
four curves -- subtract, compress, cap brightest, deepen shadows -- transcribed
from this exact ZScript with the same constants (256, 33, /8), in the same
order, with the same pre-gain / min-light / post-gain arithmetic.

What changes is the INPUT: the fragment's own light instead of the room's.
Nothing is written to the map, so there is no backup to hold, nothing to undo,
and no fight with anything else that touches sector light -- including Doom's
own flickering sectors, which this composes with for free.


THE THREE THAT HAD TO BE THERE
------------------------------

  Light     subtract 96     (DarkDoom Lite)
  Classic   subtract 128    (DarkDoom Classic)
  Dark      subtract 256    (DarkDoom Black)

Dark is TRUE black, not "very dim". With mode 1 and amount 256 the shader
computes outL = L - 256, which is at or below zero for every possible input,
so the surviving light fraction clamps to exactly 0.

That only holds while Minimum light and Post-gain are 0. Both are light that
survives the curve, so either one above zero puts the floor back. Every preset
writes them explicitly rather than inheriting.


DARK PAIRS WITH THE GLOW LANES ON PURPOSE
-----------------------------------------

The engine applies darkness AFTER the lighting equation but BEFORE glow, sweep
and dynamic lights (DarknessAt in main.fp), because those are emissive --
light being added rather than light the room has.

So in Dark mode the glow lanes are the only thing left visible. That is the
intended pairing, not a side effect. DarkDoomZ could not do this: its darkness
and its flashlight are opposite operations on the same quantity, one
multiplying the room down and the other adding back up.


THE PRESETS
-----------

Two groups, and the split is the point.

COMPATIBILITY -- DarkDoom's exact numbers. These demonstrate nothing this
engine can do that the 2021 ACS mod could not, and are not meant to. They are
there so the look you already know is one menu pick away.

  Off
  Light      subtract 96
  Classic    subtract 128
  Dark       subtract 256, true black

SHOWCASE -- all but one use distance from the eye or height above the ground.
A sector holds ONE light number and cannot say where in it you are standing,
so none of those were possible per sector at any setting. Crush is the
exception: the gamma curve alone, for contrast.

                curve      amt   extra      dist  range   height  h-range  h-ref
  Horizon       subtract    32     -        0.90   1400      -        -       -
  Tunnel        subtract    48     -        0.95    380      -        -       -
  Abyss         subtract   200     -        1.00    850      -        -       -
  Undertow      subtract    72     -          -       -    0.95     144   feet +48
  Silt          subtract    40     -          -       -    0.90     224   feet +224
  Nightfall     compress   150     -        0.45   1600      -        -       -
  Overcast      cap        150     -        0.30   2000      -        -       -
  Crush         gamma      175     -          -       -      -        -       -
  Cavern        gamma      150     -        0.65   1300    0.55     320   feet +64
  Ember         subtract   256   post +18   0.55    896      -        -       -
  Gloaming      subtract   140   min 26     0.35   1792      -        -       -
  Vault         subtract    24     -          -       -    0.90     224   fixed 224
  Lantern       subtract     0     -        1.00    576      -        -       -
  Basement      cap        108     -          -       -    0.85     192   feet -32

  Horizon    distance alone: rooms lit about as the mapper left them, the
             world falling off with range
  Tunnel     the same lever at corridor scale, so you carry a small bubble
  Abyss      nearly black: only surfaces lit above 200 keep anything, and
             range takes that away too, so only the brightest light close to
             you survives. (It was subtract 256, which rendered exactly like
             Dark -- nothing was left for range to take.)
  Undertow   height tracking your feet, waist-deep wherever you walk
  Silt       height tracking your feet a storey deep: black at the floor you
             stand on, clearing by ceiling height, and it comes with you
  Nightfall  compress, so the gap between bright and dim rooms survives
  Overcast   cap brightest, leaving the mapper's own dark areas alone
  Crush      gamma: contrast rather than dimming
  Cavern     all three levers at once
  Ember      everything erased, then one faint uniform bounce put back
  Gloaming   a floor under the dark, so corners stay legible
  Vault      a fixed storey-high gradient you CAN climb out of
  Lantern    distance and nothing else: near untouched, far black
  Basement   bright rooms capped, and a pit that pools below your feet

Distance is the one that makes a dark room feel like it has depth rather than
like the brightness slider went down.

A preset writes Curve, Distance and Height; Things In The Dark is left alone.
Picking the preset that is already selected changes nothing, so the main page
has "Re-apply preset" to put its values back after tuning.


NOTHING NEEDS A MAP RESTART

All three calls are clearscope, pushed from UiTick as well as WorldTick, so
every slider moves the picture while the game is paused and while the menu is
open -- the height reference included, which is resolved inside the push. No
network event.

Curve set to Off still lets Distance and Height act: the push sends an
identity curve (subtract 0, no gains) whenever a spatial depth is above 0,
because the shader skips the spatial terms when the mode is 0.

RS_Sweeps' darkness effect writes rsd_sweep_offset (nosave, 0 when no sweep is
acting), which the push adds to Amount and clamps to 0-256. It never writes
rsd_adjust, so a sweep neither floods the network nor leaves your Amount
changed. The offset is reset to 0 when a map starts or a save is loaded.


STATE
-----

Loads and runs. Confirmed working 2026-08-30.

One thing still unverified by eye: whether "Follows your feet" should track
the player's Z directly or the view height. It uses pos.z, which puts the
reference at the floor you are standing on.

Follow mode steps at tic rate. pos.z is the raw 35 Hz position while the view
is drawn interpolated, so on lifts and stairs the pool edge can visibly step.
Smoothing it needs the renderer to resolve the reference per frame.

Savegames: the look settings are server cvars, so a save carries them and
loading it puts them back -- that save's preset and its tuned sliders, not
whatever was set before loading. The handler keeps the applied preset with the
save so loading does not re-apply the preset over those sliders.

Netplay: only a settings controller (the host) applies presets; other clients
latch silently rather than printing a refusal per cvar.

Nightfall and Overcast are the closest pair in the set -- both mid-strength
with light distance, differing mainly in curve. If any two of these collapse
into one on screen it will be those.


FILES
-----

  cvarinfo              17 CVars (15 settings, the preset latch, the sweep offset)
  menudef               main page plus Curve / Distance / Height /
                        Things In The Dark
  mapinfo               registers the handler (without this: nothing)
  zscript.txt           version guard and includes
  zscript/rsd_presets.zs   four compatibility presets, fourteen showcase
  zscript/rsd_handler.zs   pushes three engine calls

SetDarkness, SetDarknessSpace and SetDarknessActors are exported, clearscope,
by the engine -- the mod itself needs no engine change.

These engine fixes belong to this feature, and live in UZDXREMA rather than
here, because darkness reached things that were never room light, or state
that should not have outlived its map:

* The HUD was being darkened. 2D drawing arrives at the shader with the same
  -1 light sentinel the fog path uses, so it fell into the luminance fallback
  and every element was dimmed by its own brightness. Gated on uFogEnabled
  != -3, the engine's existing 2D marker. (main.fp)

* Fullbright sprites were being darkened, which killed the UI billboards --
  they are marked fullbright precisely so a panel stays readable in a dark
  room, but fullbright is implemented as lightlevel = 255 and so arrived
  indistinguishable from a brightly lit surface. New per-draw uDarknessExempt,
  set for fullbright sprites. (hw_renderstate.h, gl_shader.*, gl_renderstate.cpp,
  vk_shader.cpp, hw_sprites.cpp, main.fp)

* Fullbright weapon frames were still darkened on the psprite path -- a
  muzzle flash on screen was dimmed where the same flash as a world sprite was
  not. Bright psprite frames are now exempt too. (hw_weapon.cpp)

* Negative pre-gain with Deepen shadows fed pow() a negative base, which is
  undefined in GLSL. The curve input is now floored at 0. (main.fp)

* A map change now clears the level's darkness switches, so an old map's
  darkness is never drawn on the next one before a mod pushes. (p_setup.cpp)

The first three follow the rule the engine already applies to glow: darkness
scales the light a room HAS, and emissive light is not room light. Requires an
engine rebuild.
