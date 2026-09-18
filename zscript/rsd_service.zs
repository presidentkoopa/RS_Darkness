// RS_Darkness -- what the darkness does to a light level, for other mods.
//
// WHY THIS EXISTS. RS_Ballistics is building "shoot the lights out": a round
// into a light fixture lowers the room's light level. That needs a floor, or a
// room goes to black and the player cannot play -- and Doom's monsters do not
// care about light, so darkness only ever costs the player.
//
// "Sector light >= 64" is the wrong floor, because this mod does not subtract
// a fixed amount. Under Blackout every light level ends at zero; under Horizon
// almost nothing is taken. The only honest floor is "with the player's current
// darkness settings, this room still shows X", and the only thing that can
// answer that is this mod.
//
// A Service rather than a direct call: neither mod has to be loaded for the
// other to compile, and a missing answer means "no darkness mod is loaded, the
// raw sector number is the truth" (engine/service.zs; ServiceIterator.Find).
//
// THE CURVE ONLY, NEVER THE SPATIAL TERMS. The distance and height terms in
// DarknessAt depend on where the player is standing and how far away the
// surface is, so a floor built on them would be true in the doorway and false
// three steps into the room -- it would pass a test and fail in play. The
// answers here are the curve at the fragment's own light level, which is what
// the shader computes before distance and height touch it. Whoever shows the
// floor in a menu says the rest in words.

class RSD_DarknessService : Service
{
	// A real answer is never exactly 0, so a caller can treat 0.0 as "no
	// answer" -- an unknown request, or no darkness mod at all.
	const EPSILON = 0.0001;

	static double F(String n, double def)
	{
		let c = CVar.FindCVar(n); return c ? c.GetFloat() : def;
	}
	static int I(String n, int def)
	{
		let c = CVar.FindCVar(n); return c ? c.GetInt() : def;
	}
	static bool B(String n, bool def)
	{
		let c = CVar.FindCVar(n); return c ? c.GetBool() : def;
	}

	// The amount the SHADER is working with, not the menu's Amount: RS_Sweeps'
	// darkness effect adds rsd_sweep_offset while a band is crossing the level,
	// and RSD_Handler pushes the sum (rsd_handler.zs). A caller that cached an
	// answer per level would be wrong for the seconds a sweep is live, which is
	// exactly when a room is darkest.
	static double EffectiveAdjust()
	{
		return clamp(F("rsd_adjust", 128.0) + F("rsd_sweep_offset", 0.0), 0.0, 256.0);
	}

	static bool CurveActive()
	{
		return B("rsd_enabled", true) && I("rsd_mode", 1) > 0;
	}

	// The fraction of `lightLevel` (Doom's 0-255) that survives the curve.
	// Transcribed from DarknessAt in main.fp -- same order, same constants, so
	// the answer matches what the player is looking at.
	static double Surviving(double lightLevel)
	{
		if (!CurveActive()) return 1.0;

		double base = clamp(lightLevel, 0.0, 255.0);
		if (base <= 0.0) return 1.0;      // already black; nothing to scale

		int mode = I("rsd_mode", 1);
		double A = EffectiveAdjust();
		double minLight = F("rsd_minlight", 0.0);
		double postGain = F("rsd_postgain", 0.0);

		// Pre-gain lifts the input before the curve, floored at 0: the slider
		// reaches -128, and mode 4 raises L to a power.
		double L = max(base + F("rsd_pregain", 0.0), 0.0);

		double outL;
		if (mode == 1)                    // subtract
			outL = L - A;
		else if (mode == 2)               // compress
			outL = L * (1.0 - A / 256.0);
		else if (mode == 3)               // cap brightest
			outL = min(L, 256.0 - A);
		else                              // deepen shadows -- exponential gamma
		{
			if (A <= 0.0) outL = L;
			else outL = (256.0 - (A ** (A / 256.0)))
				* ((L / 256.0) ** (1.0 + (A / (33.0 - (A / 8.0)))));
		}

		outL = max(outL, minLight);       // min light, a floor
		outL += postGain;                 // post-gain, a lift

		return clamp(outL / base, 0.0, 1.0);
	}

	// The raw sector light needed for `want` units of light to survive, or -1
	// when no light level reaches it. Walked rather than solved: the four
	// curves invert differently, mode 3 stops rising once it caps, and 256
	// steps once when a room is shot is nothing.
	//
	// -1 IS A REAL ANSWER AND MEANS DO NOT DIM AT ALL. Under Blackout the curve
	// takes every light level to zero, so there is no sector value that keeps a
	// room visible. A caller that read that as "clamp to 0" would darken a room
	// to nothing in the one preset where it is already black.
	static double FloorLight(double want)
	{
		if (want <= 0.0) return 0.0;
		if (!CurveActive()) return clamp(want, 0.0, 255.0);

		for (int lv = 0; lv <= 255; lv++)
		{
			double l = double(lv);
			if (l * Surviving(l) >= want) return l;
		}
		return -1.0;
	}

	override double GetDouble(String request, String stringArg, int intArg,
		double doubleArg, Object objectArg, Name nameArg)
	{
		// Lower-cased so a caller's "Surviving" is not a silent no-answer.
		String r = request.MakeLower();

		if (r == "active")     return CurveActive() ? 1.0 : 0.0;
		if (r == "surviving")  return max(Surviving(doubleArg), EPSILON);
		if (r == "floorlight") return FloorLight(doubleArg);

		return 0.0;   // unknown request: no answer
	}
}
