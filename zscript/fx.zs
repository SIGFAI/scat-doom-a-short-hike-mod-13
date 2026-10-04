// Effects: block-break cubes, the mob "poof", the laser beams, the tuna splash.

// A little solid-colour cube that pops out, falls, bounces and shrinks away (Minecraft break particles).
class CubeShard : Actor
{
	int life;
	Default
	{
		Radius 2;
		Height 4;
		Gravity 0.8;
		Scale 0.32;
		RenderStyle "Stencil";
		BounceType "Doom";
		BounceFactor 0.35;
		WallBounceFactor 0.35;
		+NOBLOCKMAP +NOTELEPORT +DONTSPLASH +THRUACTORS +MISSILE +BOUNCEONACTORS +NODAMAGETHRUST
		+FORCEXYBILLBOARD
	}
	override void Tick()
	{
		Super.Tick();
		if (++life > 40) { scale *= 0.88; if (scale.x < 0.04) { Destroy(); return; } }
		let cam = players[consoleplayer].camera;     // a chip flying into the lens just vanishes
		if (cam && life % 2 == 0 && Distance3D(cam) < 44) Destroy();
	}
	States
	{
	Spawn:
		SHRD A -1;
		Stop;
	}

	// count cubes of colours a/b flying out of p at up to speed.
	static void Burst(Vector3 p, Color a, Color b, int count, double speed, double size = 0.32)
	{
		let cam = players[consoleplayer].camera;
		if (cam && (cam.pos + (0, 0, cam.player ? cam.player.viewheight : 0) - p).Length() < 72) return;   // not in the player's face
		for (int i = 0; i < count; i++)
		{
			let s = Actor.Spawn("CubeShard", p + (frandom(-8, 8), frandom(-8, 8), frandom(0, 12)));
			if (!s) continue;
			s.SetShade(random(0, 1) ? a : b);
			s.scale = (1, 1) * size * frandom(0.7, 1.3);
			s.vel = (frandom(-1, 1) * speed, frandom(-1, 1) * speed, frandom(0.4, 1.2) * speed);
		}
	}
}

// The puff of white smoke a mob leaves when it vanishes.
class MobPoof : Actor
{
	Default
	{
		Radius 1;
		Height 1;
		Scale 0.9;
		Alpha 0.85;
		RenderStyle "Stencil";
		StencilColor "EEEEEE";
		+NOBLOCKMAP +NOGRAVITY +NOTELEPORT +DONTSPLASH +NOINTERACTION +FORCEXYBILLBOARD
	}
	override void BeginPlay()
	{
		Super.BeginPlay();
		A_SetRenderStyle(0.85, STYLE_TranslucentStencil);
	}
	override void Tick()
	{
		Super.Tick();
		scale *= 1.04;
		alpha -= 0.03;
		vel *= 0.92;
		if (alpha <= 0) Destroy();
	}
	States
	{
	Spawn:
		SHRD A -1;
		Stop;
	}

	static void Cloud(Vector3 p, double r, double h)
	{
		let cam = players[consoleplayer].camera;
		for (int i = 0; i < 16; i++)
		{
			Vector3 at = p + (frandom(-r, r), frandom(-r, r), frandom(0, h));
			if (cam && (cam.pos.xy - at.xy).Length() < 56) continue;   // never a white wall in the player's face
			let s = Actor.Spawn("MobPoof", at);
			if (!s) continue;
			s.SetShade(random(0, 2) ? "F4F4F4" : "B8B8C0");
			s.scale *= frandom(0.6, 1.4);
			s.vel = (frandom(-1.2, 1.2), frandom(-1.2, 1.2), frandom(0.5, 2.0));
		}
	}
}

// Laser impact: hot sparks, a flash and a sizzle. Spawned by the cat's eye lasers (Weapon.LineAttack).
class LaserPuff : Actor
{
	Default
	{
		+NOBLOCKMAP +NOGRAVITY +PUFFONACTORS +ALWAYSPUFF +FORCEXYBILLBOARD +NOINTERACTION
		RenderStyle "AddStencil";
		StencilColor "FF5040";
		Scale 0.5;
		Alpha 1.0;
		DamageType "Laser";
		AttackSound "cat/laserhit";
		VSpeed 0;
	}
	// Doom never runs the first frame's action of a fresh actor: the effect starts here.
	override void PostBeginPlay() { Super.PostBeginPlay(); Sparks(); }
	States
	{
	Spawn:
		SHRD A 2 Bright Light("LASERHIT");
		SHRD A 2 Bright Light("LASERHIT") A_SetScale(0.8);
		SHRD A 2 Bright A_FadeOut(0.4);
		Wait;
	}
	void Sparks()
	{
		FSpawnParticleParams p;
		for (int i = 0; i < 10; i++)
		{
			p.color1 = random(0, 2) ? "FFB040" : "FFFFC0";
			p.flags = SPF_FULLBRIGHT;
			p.lifetime = random(8, 16);
			p.size = frandom(2.5, 4.5);
			p.sizestep = -0.15;
			p.pos = pos;
			p.vel = (frandom(-3, 3), frandom(-3, 3), frandom(0, 4));
			p.accel = (0, 0, -0.35);
			p.startalpha = 1;
			p.fadestep = -1;
			level.SpawnParticle(p);
		}
		// a wisp of smoke rising from the burn
		p.color1 = "505050";
		p.flags = 0;
		p.lifetime = 30;
		p.size = 6;
		p.sizestep = 0.3;
		p.vel = (0, 0, 0.8);
		p.accel = (0, 0, 0);
		p.startalpha = 0.5;
		level.SpawnParticle(p);
	}
}

// The two red beams from Professor Whiskers' eyes, drawn with particles from the eyes to the hit point.
class LaserBeam play
{
	// Particles keep their world size: the beam grows thicker with distance so it reads far away
	// without turning into a blob in front of the camera.
	static void Draw(Vector3 from, Vector3 to)
	{
		Vector3 d = to - from;
		double len = d.Length();
		if (len < 1) return;
		Vector3 dir = d / len;
		FSpawnParticleParams p;
		p.flags = SPF_FULLBRIGHT;
		p.startalpha = 1;
		p.accel = (0, 0, 0);
		p.vel = (0, 0, 0);
		p.lifetime = 7;
		p.fadestep = -1;
		double step = 2;
		for (double t = 0; t < len && t < 3000; t += step)
		{
			double sz = clamp(3.0 + t * 0.045, 3.0, 22.0);
			p.pos = from + dir * t;
			p.color1 = "FF2040";
			p.size = sz;
			p.sizestep = -sz / 7;
			level.SpawnParticle(p);
			p.color1 = "FFE8F0";
			p.size = sz * 0.4;
			p.sizestep = -sz * 0.4 / 7;
			level.SpawnParticle(p);
			step = sz * 0.45;
		}
	}
}

// Splash + boom of a tuna torpedo: spinning blocky water rings, a fountain of spray, foam cubes, a flash.
class TunaBoom : Actor
{
	Default
	{
		+NOBLOCKMAP +NOGRAVITY +NOINTERACTION
		RenderStyle "None";
	}
	override void PostBeginPlay() { Super.PostBeginPlay(); Spray(); }
	States
	{
	Spawn:
		TNT1 A 2 Light("TUNABOOM");
		TNT1 A 6 Light("TUNABOOM");
		TNT1 A 4;
		Stop;
	}
	void Spray()
	{
		A_StartSound("cat/boom", CHAN_AUTO, 0, 1.0, 0.6);
		A_StartSound("cat/splash", CHAN_AUTO, 0, 1.0, 0.8);
		// right next to the camera, a full fountain would just paint the screen white: a small one there
		let cam = players[consoleplayer].camera;
		bool close = cam && Distance3D(cam) < 140;
		for (int i = 0; i < (close ? 0 : 3); i++)
		{
			let r = Actor.Spawn("SplashRing", pos + (0, 0, 8 + i * 10));
			if (r) { r.scale *= 0.7 + i * 0.35; r.roll = i * 40; }
		}
		FSpawnParticleParams p;
		for (int i = 0; i < (close ? 24 : 110); i++)
		{
			p.color1 = random(0, 3) ? "7FD8F0" : "FFFFFF";
			p.flags = SPF_FULLBRIGHT;
			p.lifetime = random(22, 44);
			p.size = frandom(6, 13);
			p.sizestep = -0.2;
			p.pos = pos + (frandom(-10, 10), frandom(-10, 10), frandom(0, 12));
			double a = frandom(0, 360), s = frandom(1.0, 7.0);
			p.vel = (cos(a) * s, sin(a) * s, frandom(4, 13));
			p.accel = (0, 0, -0.5);
			p.startalpha = 1;
			p.fadestep = -1;
			level.SpawnParticle(p);
		}
		CubeShard.Burst(pos, "FFFFFF", "9FE4F8", 12, 7, 0.4);    // foam
		CubeShard.Burst(pos, "F0A060", "E06040", 6, 6, 0.4);     // bits of tuna, sorry
		MobPoof.Cloud(pos, 24, 30);
	}
}

// One spinning square ring of water.
class SplashRing : Actor
{
	Default
	{
		+NOBLOCKMAP +NOGRAVITY +NOINTERACTION +ROLLSPRITE +ROLLCENTER +BRIGHT +FORCEXYBILLBOARD
		RenderStyle "Translucent";
		Alpha 0.95;
		Scale 0.8;
	}
	override void Tick()
	{
		Super.Tick();
		scale *= 1.09;
		roll += 9;
		alpha -= 0.05;
		if (alpha <= 0) Destroy();
	}
	States
	{
	Spawn:
		SPLS A -1;
		Stop;
	}
}

// A golden feather drifting down after a flap (decoration only).
class GoldenFeatherFX : Actor
{
	Default
	{
		+NOBLOCKMAP +NOINTERACTION +NOTELEPORT +BRIGHT +FORCEYBILLBOARD
		Scale 0.4;
		Alpha 1;
		RenderStyle "Translucent";
	}
	override void Tick()
	{
		Super.Tick();
		SetOrigin(pos + (sin(GetAge() * 9) * 1.2, 0, -0.6), true);
		if (GetAge() > 40) { alpha -= 0.05; if (alpha <= 0) Destroy(); }
	}
	States
	{
	Spawn:
		GFEA ABCD 4;
		Loop;
	}
}
