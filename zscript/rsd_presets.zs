// RS_Darkness -- presets.
//
// TWO GROUPS, and the split matters.
//
// COMPATIBILITY (0-3) is DarkDoom's, reproduced exactly: subtract 96, 128 and
// 256. These demonstrate nothing this engine can do that the 2021 ACS mod
// could not, and they are not supposed to. They are there so the look you
// already know is still one menu pick away.
//
// SHOWCASE (4-12) is the reason this mod exists. Every one of them uses a
// term a sector fundamentally cannot express -- distance from the eye, or
// height above the ground -- because a sector holds ONE light number and
// cannot say where you are standing in it. Each is built around a different
// lever, so no two should read alike.
//
// Dark and Abyss reach TRUE black: mode 1 at amount 256 gives outL = L - 256,
// at or below zero for every input, so the surviving fraction clamps to 0.
// That only holds while min-light and post-gain are 0, which is why every
// preset writes them rather than inheriting.

class RSD_Presets
{
	// How many presets Apply knows. Kept beside them so adding one and
	// forgetting this is a compile-visible mistake rather than a silent one.
	const COUNT = 18;

	static void W(String n, double v) { let c = CVar.FindCVar(n); if (c) c.SetFloat(v); }
	static void I(String n, int v)    { let c = CVar.FindCVar(n); if (c) c.SetInt(v); }

	static void Curve(int mode, double adjust, double minLight = 0.0,
		double preGain = 0.0, double postGain = 0.0)
	{
		I("rsd_mode", mode);
		W("rsd_adjust", adjust);
		W("rsd_minlight", minLight);
		W("rsd_pregain", preGain);
		W("rsd_postgain", postGain);
	}

	static void Dist(double depth, double range)
	{
		W("rsd_dist", depth);
		W("rsd_dist_range", range);
	}

	static void Height(double depth, double range, int mode, double z = 0.0, double offset = 0.0)
	{
		W("rsd_height", depth);
		W("rsd_height_range", range);
		I("rsd_height_mode", mode);
		W("rsd_height_z", z);
		W("rsd_height_offset", offset);
	}

	// Neutral ground, so no preset inherits the last one's spatial terms.
	static void Base()
	{
		Dist(0.0, 1024.0);
		Height(0.0, 256.0, 0, 0.0);
	}

	// ---- five that use the curve's other three levers ------------------------
	//
	// minLight, preGain and postGain were ZERO in all thirteen presets above.
	// Three of the five curve parameters were dead across the whole set, so
	// these are built on them rather than being another arrangement of adjust.

	// 13 -- FLAT AMBIENT. The subtract takes every surface to nothing, then
	// post-gain puts back the same ABSOLUTE amount everywhere. The mapper's
	// lighting is not dimmed, it is erased and replaced by a uniform bounce:
	// a bright wall and a dim one end up equally faint. Only shape tells the
	// rooms apart.
	static void Ember()
	{
		Curve(1, 256.0, 0.0, 0.0, 18.0);
		Dist(0.55, 896.0);
	}

	// 14 -- DARK WITH A FLOOR UNDER IT. The first non-zero min-light in the
	// set, so the curve bites hardest in the MIDDLE of the range instead of at
	// the bottom: mid-lit surfaces lose most, while both the brightest and the
	// already-dark survive. Classic drives everything under half to hard zero;
	// this refuses to reach zero at all, so dark corners stay legible.
	static void Gloaming()
	{
		Curve(1, 140.0, 26.0);
		Dist(0.35, 1792.0);
	}

	// 15 -- THE VERTICAL GRADIENT, FIXED. Reference at a room height above the
	// world floor with the range to match, so the pool spans a storey: black
	// underfoot, clear overhead. Fixed rather than following, which is the
	// difference from Silt -- climbing genuinely gets you out of it, and going
	// up a tower leaves it behind entirely.
	static void Vault()
	{
		Curve(1, 24.0);
		Height(0.90, 224.0, 0, 224.0);
	}

	// 16 -- DISTANCE AND NOTHING ELSE. Adjust 0 makes the curve an identity --
	// every fragment keeps exactly the light the mapper gave it -- so range is
	// the only thing happening. Tunnel dims the room first and then adds a
	// bubble; this adds only the bubble, so near surfaces are untouched and
	// the far ones go to black.
	static void Lantern()
	{
		Curve(1, 0.0);
		Dist(1.00, 576.0);
	}

	// 17 -- CAP PLUS PIT. Cap the brightest surfaces so lit rooms stop
	// shouting, then pool dark BELOW you rather than around you. Eye level
	// reads evenly lit and only what you climb down into goes black, so lifts,
	// sewers and pits carry their own darkness. The only preset with a
	// negative offset.
	static void Basement()
	{
		Curve(3, 108.0);
		Height(0.85, 192.0, 1, 0.0, -32.0);
	}

	static void Apply(int idx)
	{
		Base();

		switch (idx)
		{
		// -- compatibility --
		case 0:  Off();       break;
		case 1:  Light();     break;
		case 2:  Classic();   break;
		case 3:  Dark();      break;
		// -- showcase --
		case 4:  Horizon();   break;
		case 5:  Tunnel();    break;
		case 6:  Abyss();     break;
		case 7:  Undertow();  break;
		case 8:  Silt();      break;
		case 9:  Nightfall(); break;
		case 10: Overcast();  break;
		case 11: Crush();     break;
		case 12: Cavern();    break;
		case 13: Ember();     break;
		case 14: Gloaming();  break;
		case 15: Vault();     break;
		case 16: Lantern();   break;
		case 17: Basement();  break;
		default: Horizon();   break;
		}
	}

	// ===== COMPATIBILITY -- DarkDoom's numbers, unchanged ====================

	static void Off()     { Curve(0,   0.0); }
	static void Light()   { Curve(1,  96.0); }   // DarkDoom Lite
	static void Classic() { Curve(1, 128.0); }   // DarkDoom Classic
	static void Dark()    { Curve(1, 256.0); }   // DarkDoom Black -- true zero

	// ===== SHOWCASE -- none of these are possible per sector =================

	// 4 -- DISTANCE, alone. The curve is barely doing anything: rooms are lit
	// about as the mapper left them, and the world falls off with range
	// instead. This is the one that answers "how is this different" -- a
	// sector has one light value and cannot be brighter at your feet than it
	// is across the hall.
	static void Horizon()
	{
		Curve(1, 32.0);
		Dist(0.90, 1400.0);
	}

	// 5 -- DISTANCE, short. Same lever as Horizon, opposite scale: the falloff
	// completes in about a corridor length, so you carry a small bubble of
	// visibility. Claustrophobic rather than atmospheric.
	static void Tunnel()
	{
		Curve(1, 48.0);
		Dist(0.95, 380.0);
	}

	// 6 -- TRUE BLACK plus range. The room is already at zero, so what the
	// distance term is eating is the emissive light on top -- glow, dynamic
	// lights, anything still burning. A glow across the room becomes a hint
	// rather than a landmark. Pair with the glow lanes.
	static void Abyss()
	{
		Curve(1, 256.0);
		Dist(1.00, 850.0);
	}

	// 7 -- HEIGHT, following you. The reference tracks your feet, so the dark
	// is always pooled at the floor you are standing on and rises to about
	// waist height wherever you walk. Stairs and ledges read as wading.
	static void Undertow()
	{
		Curve(1, 72.0);
		Height(0.95, 144.0, 1, 0.0, 48.0);
	}

	// 8 -- HEIGHT, fixed and deep. The reference sits low and the range is
	// long, so instead of a pool it is a gradient the full height of a room:
	// black at the floor, clear at the ceiling. Fixed rather than following,
	// so climbing genuinely gets you out of it.
	static void Silt()
	{
		Curve(1, 40.0);
		Height(0.90, 224.0, 1, 0.0, 224.0);
	}

	// 9 -- COMPRESS. Scales everything proportionally rather than subtracting
	// a constant, so the gap between a bright room and a dim one survives
	// instead of both bottoming out together. Gentle range on top for depth.
	static void Nightfall()
	{
		Curve(2, 150.0);
		Dist(0.45, 1600.0);
	}

	// 10 -- CAP BRIGHTEST. Only rooms above the cap come down; anywhere the
	// mapper already made dark is untouched. The one that respects the map's
	// own shadow design instead of flattening it.
	static void Overcast()
	{
		Curve(3, 150.0);
		Dist(0.30, 2000.0);
	}

	// 11 -- EXPONENTIAL GAMMA. Deepens shadows hard while leaving highlights
	// roughly alone, so lit areas stay lit and everything between them goes.
	// Contrast rather than dimming.
	static void Crush()
	{
		Curve(4, 175.0);
	}

	// 12 -- everything at once. Gamma for contrast, range for depth, height
	// for the ground. The full stack, and the one to look at if you want to
	// see what the spatial terms are doing.
	static void Cavern()
	{
		Curve(4, 150.0);
		Dist(0.65, 1300.0);
		Height(0.55, 320.0, 1, 0.0, 64.0);
	}
}
