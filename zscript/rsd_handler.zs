// RS_Darkness -- the handler.
//
// Almost nothing happens here, and that is the point. DarkDoomZ needs ~110
// lines to walk every sector, rewrite Sector.LightLevel through a curve, keep
// a backup array so it can undo itself, and fire a network event every single
// UiTick to notice a slider moved. This pushes two calls.
//
// The reason it can be this small is that the four curves already live in the
// fragment shader (main.fp:1580), transcribed from the same ZScript with the
// same constants. Nothing is written to the map, so there is no state to
// restore, nothing to fight over, and turning it off is genuinely just
// stopping rather than undoing.

class RSD_Handler : EventHandler
{
	// A PRESET APPLIES WHEN IT CHANGES, NOT ON EVERY MAP. Apply is a batch of
	// CVar writes; re-running it on each WorldLoaded wiped whatever had been
	// tuned on the sliders since the preset was picked, every level. The
	// last-applied index lives in a CVar (rsd_preset_applied) because this
	// handler is rebuilt per map and would otherwise forget.
	//
	// AND FROM THE MENU. The playsim is paused while the options menu is up,
	// so a preset picked there was not applied until the menu closed, while
	// the sliders (read live by Push) moved the picture at once -- which read
	// as "the menu half works". UiTick runs under the menu; CVar writes are
	// not scope-bound. Both sides fire only on a change they have not seen.
	override void WorldLoaded(WorldEvent e)
	{
		SyncPreset();
		ResolveHeightRef();
		Push();
	}

	override void WorldTick()
	{
		SyncPreset();
		ResolveHeightRef();
		Push();
	}

	// The playsim stops while the menu is up, so WorldTick alone would freeze
	// the picture exactly while you are dragging the slider meant to change
	// it. SetDarkness is clearscope for this reason -- see doombase.zs.
	override void UiTick()
	{
		SyncPreset();
		Push();
	}

	clearscope static void SyncPreset()
	{
		int want = GetI("rsd_preset", 4);
		// CLAMPED BEFORE IT LATCHES. rsd_preset is reachable from the console,
		// and Apply's default case runs Horizon for anything out of range --
		// storing the out-of-range value as "applied" left the menu blank and
		// the latch pointing at a preset that does not exist.
		if (want < 0 || want >= RSD_Presets.COUNT) want = 1;
		if (want == GetI("rsd_preset_applied", -1)) return;
		RSD_Presets.Apply(want);
		RSD_Presets.I("rsd_preset_applied", want);
	}

	// Play scope: "where the player's feet are" reads the world, so it cannot
	// live in the clearscope push. It lands in a CVar instead, which keeps the
	// push reachable from UI scope and keeps follow mode from overwriting the
	// slider the user set.
	void ResolveHeightRef()
	{
		if (GetI("rsd_height_mode", 0) == 1)
		{
			let pmo = players[consoleplayer].mo;
			if (pmo)
			{
				// OFFSET, or follow mode does almost nothing. The shader
				// darkens only below the reference, and your feet sit ON the
				// floor -- so an unoffset reference leaves flat ground alone
				// entirely and only bites on geometry you are standing above.
				SetF("rsd_height_live", pmo.pos.z + GetF("rsd_height_offset", 0.0));
				return;
			}
		}
		SetF("rsd_height_live", GetF("rsd_height_z", 0.0));
	}

	clearscope void Push()
	{
		if (!Level) return;

		if (!GetB("rsd_enabled", true))
		{
			// Mode 0 is off in the shader, so this is a real stop rather than
			// a restore. Nothing was ever written to a sector to put back.
			Level.SetDarkness(0, 0, 0, 0, 0);
			Level.SetDarknessSpace(0, 0, 0, 0, 0);
			Level.SetDarknessActors(0);
			return;
		}

		Level.SetDarkness(
			GetI("rsd_mode", 1),
			GetF("rsd_adjust", 128.0),
			GetF("rsd_minlight", 0.0),
			GetF("rsd_pregain", 0.0),
			GetF("rsd_postgain", 0.0));

		// How much of the darkening actors are spared. The pass takes the
		// scene down as a whole, monsters included, so a room dark enough to
		// be worth lighting is a room you cannot see anything coming in.
		Level.SetDarknessActors(GetF("rsd_actor_spare", 0.4));

		Level.SetDarknessSpace(
			GetF("rsd_dist", 0.0),
			GetF("rsd_dist_range", 1024.0),
			GetF("rsd_height", 0.0),
			GetF("rsd_height_live", 0.0),
			GetF("rsd_height_range", 256.0));
	}

	// ---- cvar shorthand, clearscope so the push can reach it ---------------

	clearscope static double GetF(String n, double def = 0.0)
	{
		let c = CVar.FindCVar(n); return c ? c.GetFloat() : def;
	}

	clearscope static int GetI(String n, int def = 0)
	{
		let c = CVar.FindCVar(n); return c ? c.GetInt() : def;
	}

	clearscope static bool GetB(String n, bool def = false)
	{
		let c = CVar.FindCVar(n); return c ? c.GetBool() : def;
	}

	clearscope static void SetF(String n, double v)
	{
		let c = CVar.FindCVar(n); if (c) c.SetFloat(v);
	}
}
