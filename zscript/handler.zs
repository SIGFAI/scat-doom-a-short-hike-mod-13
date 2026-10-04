// The island's rules: Professor Whiskers talks, golden feathers flap, tuna digs craters, the summit has signal.
// On any other map, the world is rebuilt in blocks (textures swapped to the block set, the sky to the island sky).
class CatHandler : EventHandler
{
	const GRID = 88;          // MAP01 (Whisker Peak) is a GRID x GRID field of 32-unit blocks, sector = cell
	const CELL = 32.;
	const SUMMIT_X = 46 * 32 + 16;
	const SUMMIT_Y = 56 * 32 + 16;
	const SUMMIT_Z = 480;

	bool island;
	// dialogue: what is on screen, and what waits
	String curWho, curText;
	int curStart, curEnd, curPrio;
	Array<String> qWho, qText;
	Array<int> qPrio;
	// quest
	int cubesBroken, feathersFound, lastQuip;
	int stage;                // 0 hiking, 1 phone ringing, 2 call over
	int stageAt;
	int bigAt;
	String bigText;
	int flaps[MAXPLAYERS];
	int flapAt[MAXPLAYERS];

	bool IsIsland() { return level.MapName ~== "MAP01" && level.sectors.Size() > GRID * GRID; }

	override void WorldLoaded(WorldEvent e)
	{
		island = IsIsland();
		if (!island) Blockify();
	}

	override void PlayerEntered(PlayerEvent e)
	{
		let mo = players[e.PlayerNumber].mo;
		if (!mo) return;
		mo.MaxStepHeight = 32;    // walk up one block without jumping, like auto-jump
		if (!mo.FindInventory("CatLaser")) mo.GiveInventory("CatLaser", 1);
		island = IsIsland();
		if (e.PlayerNumber != consoleplayer) return;
		if (island)
		{
			Say("Professor Whiskers", "Greetings, hiker. I am a superintelligent cat. You may carry me.", 2);
			Say("Professor Whiskers", "I optimized the universe into cubes. It renders 400% faster. You're welcome.", 2);
			Say("Professor Whiskers", "Side effect: the monsters are cubes too. Point me at them. My eyes are lasers.", 2);
			Say("Professor Whiskers", "Then we climb Whisker Peak. I am expecting a VERY important call up there.", 2);
		}
		else
		{
			Say("Professor Whiskers", "Another world? Hold still. Optimizing it into cubes...", 2);
			Say("Professor Whiskers", "Done. Much more efficient. Now laser everything that oinks.", 2);
		}
	}

	// ---------- dialogue ----------
	// prio 0: a quip (dropped when something is on screen), 1: a reaction (cuts a quip), 2: story (always queued).
	void Say(String who, String text, int prio = 0)
	{
		bool busy = level.maptime < curEnd;
		if (prio == 0 && (busy || qText.Size())) return;
		if (prio == 1 && busy && curPrio == 0) curEnd = level.maptime;
		if (prio == 1 && qText.Size() > 1) return;
		qWho.Push(who);
		qText.Push(text);
		qPrio.Push(prio);
	}

	void NextLine()
	{
		if (level.maptime < curEnd || !qText.Size()) return;
		curWho = qWho[0];
		curText = qText[0];
		curPrio = qPrio[0];
		qWho.Delete(0);
		qText.Delete(0);
		qPrio.Delete(0);
		curStart = level.maptime;
		curEnd = level.maptime + 60 + curText.Length() * 2;
		let mo = players[consoleplayer].mo;
		if (mo && curWho == "Professor Whiskers" && random(0, 2) == 0) mo.A_StartSound("cat/meow1", CHAN_AUTO, CHANF_UI | CHANF_OVERLAP, 0.6);
		if (mo && curWho != "Professor Whiskers" && curWho != "Phone") mo.A_StartSound("cat/xp", CHAN_AUTO, CHANF_UI | CHANF_OVERLAP, 0.4);
	}

	static const String QUIPS[] =
	{
		"Cube deleted. I calculated that.",
		"Physics says: ouch.",
		"That one had square feelings.",
		"My eyes are lasers. Long story. It involves a microwave.",
		"Efficient. Like a cat nap.",
		"I have 9 lives. That cube had 0.",
		"Collect the paw coins. I am investing in tuna.",
		"Do not tell my vet about the lasers."
	};

	override void WorldThingDied(WorldEvent e)
	{
		if (!(e.Thing is "CubeMob")) return;
		cubesBroken++;
		if (level.maptime - lastQuip > 35 * 6 && random(0, 99) < 60)
		{
			lastQuip = level.maptime;
			Say("Professor Whiskers", QUIPS[random(0, QUIPS.Size() - 1)], 0);
		}
	}

	void GotFeather(Actor who)
	{
		feathersFound++;
		int n = who.CountInv("GoldenFeather");
		if (who.player) flaps[who.PlayerNumber()] = n;
		if (n <= 3) { bigText = "You got a Golden Feather!"; bigAt = level.maptime; }
		if (n == 1) Say("Professor Whiskers", "A Golden Feather! Jump, then jump again in the air: flap. Like a bird. Ugh. Birds.", 1);
		else if (n == 3) Say("Professor Whiskers", "Three golden feathers: three flaps in the air. Cliffs fear us now.", 1);
	}

	// "netevent hike_shortcut": Professor Whiskers computes a shortcut to the summit (a console treat).
	override void NetworkProcess(ConsoleEvent e)
	{
		if (!(e.Name ~== "hike_shortcut") || !island) return;
		let mo = players[e.Player].mo;
		if (mo) GoSummit(mo);
	}

	// ---------- the stream demo (hike_demo 1): waves of cube mobs in front of the player, then the summit call ----------
	void Director()
	{
		int t = level.maptime;
		let mo = players[consoleplayer].mo;
		if (!mo) return;
		mo.player.cheats |= CF_GODMODE;
		switch (t)
		{
		case 20:        Ahead(mo, "CubeZombie", 420, -14); Ahead(mo, "CubeFox", 520, 12); break;
		case 35 * 4:    Ahead(mo, "CubeBee", 380, 8, 36); break;
		case 35 * 8:    Meadow(mo, "CubeHog"); break;
		case 35 * 14:   Meadow(mo, "CubeSkeleton"); Meadow(mo, "CubeZombie"); break;
		case 35 * 18:   Meadow(mo, "CubeFox"); Meadow(mo, "CubeFox"); break;
		case 35 * 20:   GoSummit(mo); break;
		case 35 * 26:   Ahead(mo, "CubeBee", 480, 18, 40); break;
		case 35 * 33:   Ahead(mo, "CubeHog", 420, -14); Ahead(mo, "CubeZombie", 380, 10); break;
		case 35 * 42:   Ahead(mo, "CubeFox", 440, 0); Ahead(mo, "CubeSkeleton", 520, -16); break;
		case 35 * 52:   Ahead(mo, "CubeBee", 460, -10, 40); Ahead(mo, "CubeZombie", 380, 14); break;
		case 35 * 62:   Ahead(mo, "CubeHog", 460, 10); Ahead(mo, "CubeFox", 420, -12); break;
		}
	}

	// A mob arrives on the start meadow, between the hiker and the mountain, so the fight stays off the beach.
	void Meadow(PlayerPawn mo, Class<Actor> cls, double up = 0)
	{
		Vector2 c = (44.5 * CELL, 30 * CELL);     // the north half of the meadow, below the trail
		for (int k = 0; k < 30; k++)
		{
			Vector2 xy = c + (frandom(-200, 200), frandom(-120, 160));
			if ((xy - mo.pos.xy).Length() < 260) continue;
			if (TrySpawn(mo, cls, xy, up)) return;
		}
		Ahead(mo, cls, 480, 0, up);
	}

	bool TrySpawn(PlayerPawn mo, Class<Actor> cls, Vector2 xy, double up)
	{
		Sector s = level.PointInSector(xy);
		if (s.GetTexture(Sector.floor) == TexMan.CheckForTexture("BWATER", TexMan.Type_Any)) return false;
		let m = Actor.Spawn(cls, (xy, s.floorplane.ZAtPoint(xy) + up), ALLOW_REPLACE);
		if (!m) return false;
		if (!m.TestMobjLocation() || !m.CheckSight(mo)) { m.Destroy(); return false; }
		MobPoof.Cloud(m.pos, 16, 30);
		m.A_StartSound("cat/blockbreak", CHAN_AUTO);
		m.target = mo;
		m.A_FaceTarget();
		if (m.SeeState) m.SetState(m.SeeState);
		return true;
	}

	// A mob arrives in front of the player (a puff of block dust), on solid ground it can see you from.
	void Ahead(PlayerPawn mo, Class<Actor> cls, double dist, double yaw, double up = 0)
	{
		TextureID water = TexMan.CheckForTexture("BWATER", TexMan.Type_Any);
		// in front first; facing the sea, swing around until there is land
		static const double SWING[] = { 0, 30, -30, 60, -60, 100, -100, 140, -140, 180 };
		for (int k = 0; k < 40; k++)
		{
			double d = dist - (k % 4) * 60;
			Vector2 xy = mo.Vec2Angle(d, mo.angle + yaw + SWING[(k / 4) % SWING.Size()]);
			Sector s = level.PointInSector(xy);
			double z = s.floorplane.ZAtPoint(xy) + up;
			let m = Actor.Spawn(cls, (xy, z), ALLOW_REPLACE);
			if (!m) continue;
			if (!m.TestMobjLocation() || !m.CheckSight(mo) || s.GetTexture(Sector.floor) == water)
			{
				m.Destroy();
				continue;
			}
			MobPoof.Cloud(m.pos, 16, 30);
			m.A_StartSound("cat/blockbreak", CHAN_AUTO);
			m.target = mo;
			m.A_FaceTarget();
			if (m.SeeState) m.SetState(m.SeeState);
			return;
		}
	}

	// The shortcut: a feather-powered launch into the sky, then the hiker lands on the summit lookout.
	int launchAt;
	void GoSummit(PlayerPawn mo)
	{
		if (stage != 0 || launchAt) return;
		Say("Professor Whiskers", "Shortcut! I computed a flight path. Flap, hiker, FLAP!", 1);
		launchAt = level.maptime;
	}

	void Launch()
	{
		let mo = players[consoleplayer].mo;
		int t = level.maptime - launchAt;
		if (!mo || t > 40) return;
		if (t < 28)
		{
			mo.vel.z = 16;
			if (t % 4 == 0) FlapFX(mo);
			return;
		}
		if (t == 28)
		{
			Vector3 to = (SUMMIT_X + 2, SUMMIT_Y - 40, SUMMIT_Z + 96);
			mo.Teleport(to, 270, 0);
			mo.vel = (0, 0, -2);
			FlapFX(mo);
		}
		if (t > 28 && t % 4 == 0) FlapFX(mo);
	}


	// ---------- every tic ----------
	override void WorldTick()
	{
		if (island && hike_demo == 1) Director();
		if (hike_demo == 2 && level.maptime % 35 == 0 && players[consoleplayer].mo)   // effect test bench
		{
			let mo = players[consoleplayer].mo;
			Vector2 xy = mo.Vec2Angle(220, mo.angle);
			Actor.Spawn("TunaBoom", (xy, level.PointInSector(xy).floorplane.ZAtPoint(xy) + 8));
		}
		if (launchAt) Launch();
		NextLine();
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!playeringame[i] || !players[i].mo || players[i].mo.health <= 0) continue;
			// Professor Whiskers in your hands from the first second (the starting pistol would take over otherwise)
			if (level.maptime < 10 && !(players[i].ReadyWeapon is "CatLaser")) players[i].mo.A_SelectWeapon("CatLaser");
			Feathers(i);
		}
		if (island) Summit();
	}

	// Golden feathers: each one is a flap in the air. Jump again in the air, or fly at a ledge, to flap.
	void Feathers(int i)
	{
		let p = players[i];
		let mo = p.mo;
		int n = mo.CountInv("GoldenFeather");
		bool ground = mo.pos.z <= mo.floorz + 0.5 || mo.bOnMobj;
		if (ground) { flaps[i] = n; return; }
		if (flaps[i] <= 0 || level.maptime - flapAt[i] < 8) return;
		bool press = (p.cmd.buttons & BT_JUMP) && !(p.oldbuttons & BT_JUMP);
		bool ledge = false;
		if (mo.vel.z < 1 && mo.vel.xy.Length() > 2)
		{
			double ahead = mo.GetZAt(mo.radius + 14, 0);
			ledge = ahead > mo.pos.z + 6 && ahead < mo.pos.z + 110;
		}
		if (!press && !ledge) return;
		flaps[i]--;
		flapAt[i] = level.maptime;
		mo.vel.z = 9;
		mo.vel.xy += Actor.AngleToVector(mo.angle, 2);
		FlapFX(mo);
	}

	// A flap: a burst of golden feather sparks under the hiker and a wing sound.
	void FlapFX(Actor mo)
	{
		mo.A_StartSound("cat/flap", CHAN_AUTO, CHANF_OVERLAP, 1.0);
		FSpawnParticleParams fp;
		for (int k = 0; k < 24; k++)
		{
			fp.color1 = random(0, 2) ? "FFD040" : "FFFFFF";
			fp.flags = SPF_FULLBRIGHT;
			fp.lifetime = random(16, 30);
			fp.size = frandom(3, 6);
			fp.sizestep = -0.12;
			double a = frandom(0, 360);
			fp.pos = mo.pos + (cos(a) * 16, sin(a) * 16, frandom(0, 12));
			fp.vel = (cos(a) * 1.5, sin(a) * 1.5, frandom(-2.5, -0.5));
			fp.accel = (0, 0, 0.05);
			fp.startalpha = 1;
			fp.fadestep = -1;
			level.SpawnParticle(fp);
		}
		let f = Actor.Spawn("GoldenFeatherFX", mo.pos + (frandom(-12, 12), frandom(-12, 12), 4));
	}

	// The peak has one bar of signal: the phone rings, the Professor finally takes his very important call.
	void Summit()
	{
		let mo = players[consoleplayer].mo;
		if (!mo) return;
		if (stage == 0 && mo.pos.z >= SUMMIT_Z - 8 && (mo.pos.xy - (SUMMIT_X, SUMMIT_Y)).Length() < 120)
		{
			stage = 1;
			stageAt = level.maptime;
			curEnd = level.maptime;
			qText.Clear(); qWho.Clear(); qPrio.Clear();
			Say("Phone", "RING RING! RING RING!", 2);
			Say("Professor Whiskers", "ONE BAR! I cubified the whole universe for this call.", 2);
			Say("Phone", "Hello! We've been trying to reach you about your car's extended warranty.", 2);
			Say("Professor Whiskers", "...I am a cat. I do not have a car.", 2);
			Say("Professor Whiskers", "Hike back down. Laser everything. We are blocking this number.", 2);
		}
		if (stage == 1)
		{
			int t = level.maptime - stageAt;
			if (t < 35 * 5 && t % 45 == 0) mo.A_StartSound("cat/phone", CHAN_AUTO, CHANF_UI | CHANF_OVERLAP, 1.0);
			if (!qText.Size() && level.maptime >= curEnd)
			{
				stage = 2;
				bigText = "Whisker Peak climbed! Thanks for hiking.";
				bigAt = level.maptime;
			}
		}
	}

	// ---------- digging: a tuna blast takes one block out of the ground around it ----------
	void Dig(Vector3 p, double radius)
	{
		if (!island) return;
		TextureID water = TexMan.CheckForTexture("BWATER", TexMan.Type_Any);
		TextureID brick = TexMan.CheckForTexture("BBRICK", TexMan.Type_Any);
		TextureID logtop = TexMan.CheckForTexture("BLOGTOP", TexMan.Type_Any);
		TextureID dirt = TexMan.CheckForTexture("BDIRT", TexMan.Type_Any);
		TextureID stone = TexMan.CheckForTexture("BSTONE", TexMan.Type_Any);
		TextureID sand = TexMan.CheckForTexture("BSAND", TexMan.Type_Any);
		TextureID snow = TexMan.CheckForTexture("BSNOW", TexMan.Type_Any);
		int ci = int(p.x / CELL), cj = int(p.y / CELL);
		int r = int(radius / CELL) + 1;
		int dug = 0;
		for (int i = ci - r; i <= ci + r; i++)
		{
			for (int j = cj - r; j <= cj + r; j++)
			{
				if (i < 0 || j < 0 || i >= GRID || j >= GRID) continue;
				Vector2 c = ((i + 0.5) * CELL, (j + 0.5) * CELL);
				if ((c - p.xy).Length() > radius) continue;
				Sector s = level.sectors[j * GRID + i];
				double fz = s.floorplane.ZAtPoint(c);
				if (abs(fz - p.z) > 48 || fz < 32) continue;      // only blocks near the blast; the bedrock stays
				TextureID t = s.GetTexture(Sector.floor);
				if (t == water || t == brick || t == logtop) continue;
				Color a = "8A5A34", b = "6A4428";
				if (t == stone) { a = "8A8A8A"; b = "6A6A70"; }
				else if (t == sand) { a = "E8D8A0"; b = "D0C080"; }
				else if (t == snow) { a = "F4F8FF"; b = "C8D8E8"; }
				else if (t != dirt) { a = "50C050"; b = "8A5A34"; }
				s.MoveFloor(CELL, fz - CELL, -1, -1, false, true);
				s.SetTexture(Sector.floor, fz - CELL < 96 ? stone : dirt);
				CubeShard.Burst((c, fz), a, b, 6, 5, 0.3);
				dug++;
			}
		}
		if (dug)
		{
			let poof = Actor.Spawn("MobPoof", p);
			if (poof) poof.A_StartSound("cat/blockbreak", CHAN_AUTO, 0, 1.0);
		}
	}

	// ---------- any other map: rebuild it in blocks ----------
	static const String WALLS[] = { "BCOBBLE", "BBRICK", "BGREYBR", "BPLANK", "BSTONE", "BMOSS", "BLOG", "BREDPLNK", "BCOBDIRT", "BGOLDORE", "BDIAORE", "BCOALORE" };
	static const String FLOORS[] = { "BPLANK", "BCOBBLE", "BSTONE", "BGRAVEL", "BGREYBR", "BREDPLNK" };

	TextureID Pick(TextureID old, bool flat, bool outdoor)
	{
		String n = TexMan.GetName(old);
		if (n == "" || n == "-") return old;
		String u = n.MakeUpper();
		if (u.IndexOf("SKY") >= 0 || u.Left(3) == "SW1" || u.Left(3) == "SW2") return old;
		if (u.IndexOf("NUKAGE") >= 0 || u.IndexOf("WATER") >= 0 || u.IndexOf("SLIME") >= 0 || u.IndexOf("BLOOD") >= 0)
			return TexMan.CheckForTexture("BWATER", TexMan.Type_Any);
		if (u.IndexOf("LAVA") >= 0) return TexMan.CheckForTexture("BLAVA", TexMan.Type_Any);
		int h = 0;
		for (int i = 0; i < int(u.Length()); i++) h = (h * 31 + u.ByteAt(i)) & 0xFFFF;
		if (flat) return TexMan.CheckForTexture(outdoor ? (h % 3 ? "BGRASS" : "BGRASS2") : FLOORS[h % FLOORS.Size()], TexMan.Type_Any);
		return TexMan.CheckForTexture(WALLS[h % WALLS.Size()], TexMan.Type_Any);
	}

	void Blockify()
	{
		TextureID sky = TexMan.CheckForTexture("F_SKY1", TexMan.Type_Any);
		for (int i = 0; i < level.sectors.Size(); i++)
		{
			Sector s = level.sectors[i];
			bool outdoor = s.GetTexture(Sector.ceiling) == sky;
			s.SetTexture(Sector.floor, Pick(s.GetTexture(Sector.floor), true, outdoor));
			if (!outdoor) s.SetTexture(Sector.ceiling, Pick(s.GetTexture(Sector.ceiling), true, false));
		}
		for (int i = 0; i < level.sides.Size(); i++)
		{
			Side sd = level.sides[i];
			for (int k = 0; k < 3; k++)
			{
				if (k == Side.mid && sd.linedef.sidedef[1]) continue;   // keep grates and fences see-through
				sd.SetTexture(k, Pick(sd.GetTexture(k), false, false));
			}
		}
		level.ChangeSky(TexMan.CheckForTexture("BSKY", TexMan.Type_Any), TexMan.CheckForTexture("BSKY", TexMan.Type_Any));
	}

	// ---------- the HUD: phone signal, feathers, coins, quest, dialogue box ----------
	// Laid out on a 640x360 grid scaled to the window height; ox shifts the centred parts on wide windows.
	ui double sc, ox;

	override void RenderOverlay(RenderEvent e)
	{
		let mo = players[consoleplayer].mo;
		if (!mo || automapactive) return;
		sc = Screen.GetHeight() / 360.;
		ox = (Screen.GetWidth() - 640 * sc) / 2;
		Font f = NewSmallFont;
		// phone with signal bars
		int bars = island ? (stage >= 1 ? 4 : clamp(int((mo.pos.z + 40) / 120), 0, 4)) : 1;   // the call holds the line
		Box(10, 10, 104, 44, "201828", 0.75);
		Box(16, 15, 20, 34, "F0F0F0", 1);
		Box(18, 18, 16, 24, bars ? "4AA8E0" : "5A6A78", 1);
		for (int b = 0; b < 4; b++)
		{
			int bh = 5 + b * 6;
			Box(42 + b * 8, 48 - bh, 6, bh, b < bars ? "FFFFFF" : "50485A", 1);
		}
		Text(f, 78, 16, bars ? "SIGNAL" : "NO", bars ? Font.CR_WHITE : Font.CR_RED, 0.7);
		Text(f, 78, 30, bars ? String.Format("%d/4", bars) : "SIGNAL", bars ? Font.CR_GREEN : Font.CR_RED, 0.7);
		// feathers and coins
		int n = mo.CountInv("GoldenFeather");
		int left = flaps[consoleplayer];
		Box(10, 58, 104, 28, "201828", 0.75);
		TextureID fe = TexMan.CheckForTexture("GFEAA0", TexMan.Type_Sprite);
		if (n == 0) Text(f, 16, 66, "no feathers yet", Font.CR_DARKGRAY, 0.7);
		for (int k = 0; k < n && k < 8; k++) Pic(fe, 15 + k * 12, 61, 11, 22, k < left ? 1.0 : 0.3);
		TextureID co = TexMan.CheckForTexture("PCOIA0", TexMan.Type_Sprite);
		Box(10, 90, 104, 20, "201828", 0.75);
		Pic(co, 15, 93, 14, 14, 1);
		Text(f, 34, 95, String.Format("%d paw coins", mo.CountInv("PawCoin")), Font.CR_GOLD, 0.75);
		// quest
		String q = stage == 0 ? (island ? "Goal: climb Whisker Peak for signal" : "Goal: laser the cubes") : (stage == 1 ? "Answer the phone!" : "Hike complete!");
		Box(10, 114, 170, 28, "201828", 0.6);
		Text(f, 15, 117, q, Font.CR_WHITE, 0.7);
		Text(f, 15, 129, String.Format("Cubes lasered: %d", cubesBroken), Font.CR_LIGHTBLUE, 0.7);
		// big message
		if (bigText != "" && level.maptime - bigAt < 35 * 3)
		{
			double a = min(1.0, (35 * 3 - (level.maptime - bigAt)) / 20.0);
			double w = BigFont.StringWidth(bigText) * sc;
			Screen.DrawText(BigFont, Font.CR_GOLD, (Screen.GetWidth() - w) / 2, 70 * sc, bigText, DTA_ScaleX, sc, DTA_ScaleY, sc, DTA_Alpha, a);
		}
		// dialogue box, A Short Hike style: a soft cream card with the speaker's name and a typed-out line
		if (level.maptime < curEnd && curText != "")
		{
			double bx = 150, by = 14, bw = 400, bhh = 70;
			Box(bx - 2, by - 2, bw + 4, bhh + 4, "3A2A30", 0.9, true);
			Box(bx, by, bw, bhh, "FFF6E0", 0.97, true);
			bool cat = curWho == "Professor Whiskers";
			bool phone = curWho == "Phone";
			double tx = bx + 12;
			if (cat)
			{
				bool hot = (players[consoleplayer].WeaponState & WF_WEAPONREADY) == 0;
				Box(bx + 6, by + 6, 58, 58, "BFE3F0", 1, true);
				Pic(TexMan.CheckForTexture(hot ? "CATPORT2" : "CATPORT1", TexMan.Type_Any), bx + 7, by + 7, 56, 56, 1, true);
				tx = bx + 72;
			}
			else if (phone)
			{
				// a ringing phone: it shakes while the call is on
				double sh = (level.maptime % 6 < 3) ? -1.5 : 1.5;
				Box(bx + 6, by + 6, 58, 58, "C8F0D0", 1, true);
				Box(bx + 22 + sh, by + 10, 26, 50, "302838", 1, true);
				Box(bx + 25 + sh, by + 15, 20, 34, "4AA8E0", 1, true);
				Box(bx + 31 + sh, by + 53, 8, 3, "F0F0F0", 1, true);
				for (int b = 0; b < 4; b++) Box(bx + 28 + b * 4 + sh, by + 44 - b * 4, 3, 3 + b * 4, "FFFFFF", 1, true);
				tx = bx + 72;
			}
			double nw = f.StringWidth(curWho) * 0.8 + 10;
			Box(tx - 4, by - 10, nw, 15, cat ? "E07040" : (phone ? "40A060" : "4A90C0"), 1, true);
			Text(f, tx + 1, by - 8, curWho, Font.CR_WHITE, 0.8, true);
			int shown = clamp(int((level.maptime - curStart) * 1.4), 0, curText.Length());
			BrokenLines lines = f.BreakLines(curText, int((bx + bw - 10 - tx) / 0.9));
			double ly = by + 12;
			int used = 0;
			for (int i = 0; i < lines.Count() && used < shown; i++)
			{
				String l = lines.StringAt(i);
				String part = l.Left(min(l.Length(), shown - used));
				used += l.Length() + 1;
				Text(f, tx, ly, part, Font.CR_BLACK, 0.9, true);
				ly += 13;
			}
		}
	}

	ui double X(double x, bool centred) { return (centred ? ox : 0) + x * sc; }

	ui void Box(double x, double y, double w, double h, Color c, double a, bool centred = false)
	{
		Screen.Dim(c, a, int(X(x, centred)), int(y * sc), int(ceil(w * sc)), int(ceil(h * sc)));
	}

	ui void Pic(TextureID t, double x, double y, double w, double h, double a, bool centred = false)
	{
		Screen.DrawTexture(t, false, X(x, centred), y * sc, DTA_DestWidthF, w * sc, DTA_DestHeightF, h * sc,
			DTA_LeftOffset, 0, DTA_TopOffset, 0, DTA_Alpha, a);
	}

	ui void Text(Font f, double x, double y, String s, int col, double scale, bool centred = false)
	{
		Screen.DrawText(f, col, X(x, centred), y * sc, s, DTA_ScaleX, sc * scale, DTA_ScaleY, sc * scale);
	}

}
