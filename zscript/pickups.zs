// Island loot. Coins fly to you like experience orbs; golden feathers give you one more flap in the air each.

mixin class Magnet
{
	int age;
	// Flies to the closest player once it has popped out; touching picks it up.
	void Pull(double range, double speed)
	{
		age++;
		if (age < 18) return;
		PlayerPawn best = null;
		double bd = range;
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!playeringame[i] || !players[i].mo || players[i].mo.health <= 0) continue;
			double d = Distance3D(players[i].mo);
			if (d < bd) { bd = d; best = players[i].mo; }
		}
		if (!best) return;
		Vector3 to = best.pos + (0, 0, 6) - pos;    // into the hiker's pockets, below the view
		double l = to.Length();
		if (l < 36) { Touch(best); return; }
		bInvisible = l < 80;     // the last few frames before the pocket: not a giant sprite on the lens
		bNoGravity = true;
		bNoClip = true;
		vel = to / l * min(speed, 4 + age * 0.4);
	}
}

class PawCoin : Inventory
{
	mixin Magnet;
	Default
	{
		Inventory.Amount 1;
		Inventory.MaxAmount 9999;
		Inventory.PickupSound "cat/xp";
		Inventory.PickupMessage "";
		Radius 8;
		Height 12;
		Scale 0.38;
		+INVENTORY.ALWAYSPICKUP +INVENTORY.NOSCREENFLASH
		+BRIGHT
	}
	override void Tick()
	{
		Super.Tick();
		if (!owner && !bDestroyed) Pull(320, 14);
	}
	States
	{
	Spawn:
		PCOI ABCD 4;
		Loop;
	}
}

class GoldenFeather : Inventory
{
	mixin Magnet;
	bool dropped;
	Default
	{
		Inventory.Amount 1;
		Inventory.MaxAmount 10;
		Inventory.PickupSound "cat/feather";
		Inventory.PickupMessage "";
		Radius 12;
		Height 28;
		Scale 0.62;
		+INVENTORY.ALWAYSPICKUP
		+FLOATBOB +BRIGHT +NOGRAVITY
		FloatBobStrength 0.6;
	}
	override void Tick()
	{
		Super.Tick();
		if (owner || bDestroyed) return;
		if (dropped) { if (!bNoClip) vel *= 0.9; Pull(900, 12); }   // a bee's feather finds its hiker
		if (level.maptime % 4 == 0)
		{
			FSpawnParticleParams p;
			p.color1 = random(0, 1) ? "FFE060" : "FFFFFF";
			p.flags = SPF_FULLBRIGHT;
			p.lifetime = 24;
			p.size = frandom(2, 4);
			p.sizestep = -0.08;
			p.pos = pos + (frandom(-12, 12), frandom(-12, 12), frandom(0, 30));
			p.vel = (0, 0, 0.5);
			p.startalpha = 1;
			p.fadestep = -1;
			level.SpawnParticle(p);
		}
	}
	override void DoPickupSpecial(Actor toucher)
	{
		Super.DoPickupSpecial(toucher);
		let h = CatHandler(EventHandler.Find("CatHandler"));
		if (h) h.GotFeather(toucher);
	}
	States
	{
	Spawn:
		GFEA ABCD 5;
		Loop;
	}
}

// Island hikers (cube pets): friendly, solid. Shoot them and they hop and complain, but they never die.
class IslandHiker : Actor
{
	String who;
	Array<String> lines;
	int lineAt, lastTalk;
	Default
	{
		Radius 18;
		Height 44;
		Mass 200;
		Health 1000;
		PainChance 255;
		Scale 0.5;
		+SOLID +SHOOTABLE +NOBLOOD +INVULNERABLE +NODAMAGE +FRIENDLY +DONTTHRUST +NOTAUTOAIMED
		PainSound "cat/hurtmob";
	}
	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (vel.z == 0 && pos.z <= floorz) vel.z = 5;     // a startled hop
		CubeShard.Burst(pos + (0, 0, height * 0.6), "FFFFFF", "FFD0D0", 2, 2, 0.18);
		A_StartSound("cat/hurtmob", CHAN_VOICE);
		if (source && source.player && level.maptime - lastTalk > 70)
		{
			let h = CatHandler(EventHandler.Find("CatHandler"));
			if (h) h.Say(who, ShotLine(), 1);
			lastTalk = level.maptime;
		}
		return 0;
	}
	virtual String ShotLine() { return "Hey! I'm hiking here!"; }
	override void Tick()
	{
		Super.Tick();
		if (level.maptime % 10) return;
		let p = players[consoleplayer].mo;
		if (!p || lines.Size() == 0) return;
		if (Distance2D(p) < 150 && abs(p.pos.z - pos.z) < 80 && level.maptime - lastTalk > 35 * 12)
		{
			A_Face(p);
			let h = CatHandler(EventHandler.Find("CatHandler"));
			if (h) h.Say(who, lines[lineAt % lines.Size()], 2);
			lineAt++;
			lastTalk = level.maptime;
		}
	}
}

class HikerPenguin : IslandHiker
{
	Default { Tag "Pengu"; Height 44; }
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		who = "Pengu";
		lines.Push("I came to this island for the snow. Now the snow is cubes.");
		lines.Push("Climb the peak! Up there your phone gets one whole bar.");
		lines.Push("The cat says the cubes are 'more efficient'. My corners hurt.");
	}
	override String ShotLine() { return "Ow! I'm a penguin, not a target!"; }
	States
	{
	Spawn:
		NPEN AB 20;
		Loop;
	}
}

class HikerBunny : IslandHiker
{
	Default { Tag "Bun"; Height 42; }
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		who = "Bun";
		lines.Push("Bees hoard golden feathers. Laser one and see!");
		lines.Push("Each golden feather is one more flap in the air. Jump twice!");
		lines.Push("I sold my carrots for paw coins. The cat takes paw coins.");
	}
	override String ShotLine() { return "Rude! Laser the cubes, not the bunnies!"; }
	States
	{
	Spawn:
		NBUN AB 16;
		Loop;
	}
}

// Tall grass, flowers and mushrooms. You walk through them like in a block game; a laser breaks them into cubes.
class IslandPlant : Actor
{
	static const int LOOKS[] = { 0, 1, 2, 3, 0, 1, 2, 3, 4, 5, 6, 7 };
	Default
	{
		Radius 6;
		Height 16;
		Health 1;
		+SHOOTABLE +NOBLOOD +DONTTHRUST +NOTAUTOAIMED +FORCEYBILLBOARD
		-SOLID
	}
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		frame = LOOKS[(int(pos.x / 32) * 7 + int(pos.y / 32) * 3) % LOOKS.Size()];
	}
	States
	{
	Spawn:
		PLNT A -1;
		Stop;
	Death:
		TNT1 A 0 { A_StartSound("cat/step", CHAN_AUTO); CubeShard.Burst(pos + (0, 0, 6), "50C050", "3A8A3A", 5, 2.5, 0.2); }
		Stop;
	}
}
