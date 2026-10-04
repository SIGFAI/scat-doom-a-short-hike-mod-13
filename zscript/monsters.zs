// The cube mobs. Doom's own monsters are replaced, so every map (and every Doom weapon) meets them.

class CubeMob : Actor
{
	Color bitA, bitB;     // the colours of the cubes it breaks into
	int coins;            // paw coins it drops
	int featherOdds;      // percent chance to drop a golden feather
	property Bits: bitA, bitB;
	property Coins: coins;
	property FeatherOdds: featherOdds;

	Default
	{
		Monster;
		+FLOORCLIP +NOBLOOD
		MaxStepHeight 32;
		Scale 0.5;
		PainSound "cat/hurtmob";
		DeathSound "cat/hurtmob";
		CubeMob.Bits "60A040", "3A6A2A";
		CubeMob.Coins 2;
		CubeMob.FeatherOdds 0;
	}

	// Every hit shows: a red flash over the sprite (like a Minecraft mob), a few cube chips, a thud.
	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		int d = Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
		if (d > 0)
		{
			HitFlash.Make(self);
			CubeShard.Burst(pos + (0, 0, height * 0.55), bitA, bitB, 3, 3.5, 0.22);
			if (health > 0) A_StartSound("cat/hurtmob", CHAN_AUTO, CHANF_OVERLAP, 0.6);
		}
		return d;
	}

	// The end of a death: a puff of smoke, the body breaks into cubes, coins (and maybe a feather) pop out.
	void A_CubePoof()
	{
		A_StartSound("cat/poof", CHAN_AUTO, 0, 1.0);
		A_StartSound("cat/blockbreak", CHAN_AUTO, CHANF_OVERLAP, 0.8);
		MobPoof.Cloud(pos, radius * 0.8, height * 0.7);
		CubeShard.Burst(pos + (0, 0, height * 0.3), bitA, bitB, 14, 5, 0.34);
		for (int i = 0; i < coins; i++)
		{
			let c = Spawn("PawCoin", pos + (0, 0, height * 0.4));
			if (c) c.vel = (frandom(-3, 3), frandom(-3, 3), frandom(4, 7));
		}
		if (random(1, 100) <= featherOdds)
		{
			let f = Spawn("GoldenFeather", pos + (0, 0, height * 0.5));
			if (f) { f.vel = (0, 0, 6); GoldenFeather(f).dropped = true; }
		}
	}
}

// The red damage flash: a copy of the mob's current frame drawn in red on top of it, for a few tics.
class HitFlash : Actor
{
	Actor host;
	int t;
	Default
	{
		+NOBLOCKMAP +NOGRAVITY +NOINTERACTION +NOTELEPORT
		RenderStyle "AddStencil";
		StencilColor "FF2828";
		Alpha 0.75;
	}
	static void Make(Actor m)
	{
		let f = HitFlash(Spawn("HitFlash", m.pos));
		if (!f) return;
		f.host = m;
		f.Follow();
	}
	void Follow()
	{
		if (!host) { Destroy(); return; }
		sprite = host.sprite;
		frame = host.frame;
		angle = host.angle;
		scale = host.scale;
		Vector3 p = host.pos;
		let cam = players[consoleplayer].camera;
		if (cam) { Vector2 d = cam.pos.xy - p.xy; double l = d.Length(); if (l > 1) p.xy += d / l * 2; }
		SetOrigin(p, true);
	}
	override void Tick()
	{
		if (++t > 5) { Destroy(); return; }
		alpha -= 0.12;
		Follow();
	}
	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}
}

// ---------- Cube Zombie: shambles with its arms out, spits slime cubes ----------
class CubeZombie : CubeMob replaces ZombieMan
{
	Default
	{
		Health 50;
		Radius 18;
		Height 56;
		Mass 100;
		Speed 6;
		PainChance 200;
		SeeSound "grunt/sight";
		ActiveSound "grunt/active";
		Obituary "%o was hugged by a cube zombie.";
		Tag "Cube Zombie";
		CubeMob.Bits "5AA04A", "2E8C8C";
		CubeMob.Coins 2;
	}
	States
	{
	Spawn:
		CZOM AB 10 A_Look;
		Loop;
	See:
		CZOM AABBCCDD 3 A_Chase;
		Loop;
	Melee:
		CZOM E 6 A_FaceTarget;
		CZOM F 6 A_CustomMeleeAttack(random(3, 10), "cat/hurtmob");
		Goto See;
	Missile:
		CZOM E 10 A_FaceTarget;
		CZOM F 8 A_SpawnProjectile("SlimeCube", 36);
		CZOM E 6;
		Goto See;
	Pain:
		CZOM G 3;
		CZOM G 3 A_Pain;
		Goto See;
	Death:
	XDeath:
		CZOM H 4 A_Scream;
		CZOM I 4 A_NoBlocking;
		CZOM JK 4;
		CZOM L 6;
		TNT1 A 0 A_CubePoof;
		Stop;
	}
}

// ---------- Cube Skeleton: shoots arrows from a bow ----------
class CubeSkeleton : CubeMob replaces ShotgunGuy
{
	Default
	{
		Health 60;
		Radius 18;
		Height 56;
		Mass 100;
		Speed 8;
		PainChance 170;
		SeeSound "shotguy/sight";
		ActiveSound "shotguy/active";
		Obituary "%o took an arrow from a cube skeleton.";
		Tag "Cube Skeleton";
		CubeMob.Bits "E8E4D8", "8A8A90";
		CubeMob.Coins 3;
	}
	States
	{
	Spawn:
		CSKL AB 10 A_Look;
		Loop;
	See:
		CSKL AABBCCDD 3 A_Chase;
		Loop;
	Missile:
		CSKL E 12 A_FaceTarget;
		CSKL F 6 A_SpawnProjectile("CubeArrow", 38);
		CSKL E 8;
		Goto See;
	Pain:
		CSKL G 3;
		CSKL G 3 A_Pain;
		Goto See;
	Death:
	XDeath:
		CSKL H 4 A_Scream;
		CSKL I 4 A_NoBlocking;
		CSKL JK 4;
		CSKL L 6;
		TNT1 A 0 A_CubePoof;
		Stop;
	}
}

class CubeSkeletonGunner : CubeSkeleton replaces ChaingunGuy
{
	Default
	{
		Health 70;
		Tag "Cube Skeleton Archer";
	}
	States
	{
	Missile:
		CSKL E 8 A_FaceTarget;
		CSKL F 4 A_SpawnProjectile("CubeArrow", 38);
		CSKL E 4 A_FaceTarget;
		CSKL F 4 A_SpawnProjectile("CubeArrow", 38, 0, frandom(-6, 6));
		CSKL E 6;
		Goto See;
	}
}

// ---------- Cube Fox: spits magma cubes (the Imp of the island) ----------
class CubeFox : CubeMob replaces DoomImp
{
	Default
	{
		Health 60;
		Radius 20;
		Height 50;
		Mass 100;
		Speed 8;
		PainChance 200;
		SeeSound "imp/sight";
		ActiveSound "imp/active";
		Obituary "%o was toasted by a cube fox.";
		Tag "Cube Fox";
		CubeMob.Bits "F08A30", "FFFFFF";
		CubeMob.Coins 3;
	}
	States
	{
	Spawn:
		CFOX AB 10 A_Look;
		Loop;
	See:
		CFOX AABBCCDD 3 A_Chase;
		Loop;
	Melee:
	Missile:
		CFOX E 8 A_FaceTarget;
		CFOX F 6 A_SpawnProjectile("MagmaCube", 30);
		CFOX E 6;
		Goto See;
	Pain:
		CFOX G 3;
		CFOX G 3 A_Pain;
		Goto See;
	Death:
	XDeath:
		CFOX H 4 A_Scream;
		CFOX I 4 A_NoBlocking;
		CFOX JK 4;
		CFOX L 6;
		TNT1 A 0 A_CubePoof;
		Stop;
	}
}

// ---------- Cube Hog: charges and headbutts (the Demon) ----------
class CubeHog : CubeMob replaces Demon
{
	Default
	{
		Health 150;
		Radius 28;
		Height 52;
		Mass 400;
		Speed 11;
		PainChance 180;
		SeeSound "demon/sight";
		ActiveSound "demon/active";
		AttackSound "demon/melee";
		Obituary "%o was flattened by a cube hog.";
		Tag "Cube Hog";
		CubeMob.Bits "F0A0B0", "C06070";
		CubeMob.Coins 4;
		CubeMob.FeatherOdds 20;
	}
	States
	{
	Spawn:
		CHOG AB 10 A_Look;
		Loop;
	See:
		CHOG AABBCCDD 2 A_Chase;
		Loop;
	Melee:
		CHOG E 6 A_FaceTarget;
		CHOG F 5 A_FaceTarget;
		CHOG G 6 A_HogButt;
		Goto See;
	Pain:
		CHOG H 3;
		CHOG H 3 A_Pain;
		Goto See;
	Death:
	XDeath:
		CHOG I 4 A_Scream;
		CHOG J 4 A_NoBlocking;
		CHOG KL 4;
		CHOG M 6;
		TNT1 A 0 A_CubePoof;
		Stop;
	}
	void A_HogButt()
	{
		if (!target || !CheckMeleeRange()) return;
		A_StartSound(AttackSound, CHAN_WEAPON);
		int d = random(6, 24);
		target.DamageMobj(self, self, d, 'Melee');
		target.Thrust(6, AngleTo(target));   // a headbutt sends you flying a little
		target.vel.z += 3;
	}
}

class CubeGhostHog : CubeHog replaces Spectre
{
	Default
	{
		RenderStyle "Translucent";
		Alpha 0.45;
		Tag "Ghost Hog";
	}
	States
	{
	Spawn:
		CHOG AB 10 A_Look;
		Loop;
	See:
		CHOG AABBCCDD 2 A_Chase;
		Loop;
	Melee:
		CHOG E 6 A_FaceTarget;
		CHOG F 5 A_FaceTarget;
		CHOG G 6 A_HogButt;
		Goto See;
	Pain:
		CHOG H 3;
		CHOG H 3 A_Pain;
		Goto See;
	Death:
	XDeath:
		CHOG I 4 A_Scream;
		CHOG J 4 A_NoBlocking;
		CHOG KL 4;
		CHOG M 6;
		TNT1 A 0 A_CubePoof;
		Stop;
	}
}

// ---------- Giant Cube Bee: floats and fires stingers (the Cacodemon). Bees hoard golden feathers. ----------
class CubeBee : CubeMob replaces Cacodemon
{
	Default
	{
		Health 220;
		Radius 30;
		Height 60;
		Mass 400;
		Speed 8;
		PainChance 128;
		+FLOAT +NOGRAVITY
		SeeSound "caco/sight";
		ActiveSound "caco/active";
		Obituary "%o was stung by a giant cube bee.";
		Tag "Giant Cube Bee";
		CubeMob.Bits "F8D030", "302830";
		CubeMob.Coins 6;
		CubeMob.FeatherOdds 100;
	}
	States
	{
	Spawn:
		CBEE AB 4 A_Look;
		Loop;
	See:
		CBEE ABAB 3 A_Chase;
		Loop;
	Missile:
		CBEE C 6 A_FaceTarget;
		CBEE D 4 A_SpawnProjectile("BeeStinger", 26);
		CBEE C 4 A_FaceTarget;
		CBEE D 4 A_SpawnProjectile("BeeStinger", 26);
		Goto See;
	Pain:
		CBEE E 3;
		CBEE E 3 A_Pain;
		Goto See;
	Death:
	XDeath:
		CBEE F 4 A_Scream;
		CBEE G 4 { bNoGravity = false; A_NoBlocking(); }
		CBEE HI 4;
		CBEE J 6;
		TNT1 A 0 A_CubePoof;
		Stop;
	}
}

// ---------- their projectiles: cubes too ----------
class CubeBall : Actor
{
	Color c1, c2;
	property Colors: c1, c2;
	Default
	{
		Projectile;
		Radius 6;
		Height 8;
		Scale 0.75;
		+FORCEXYBILLBOARD +ROLLSPRITE
		CubeBall.Colors "60D040", "308020";
	}
	override void Tick()
	{
		Super.Tick();
		if (InStateSequence(CurState, SpawnState)) roll += 12;
	}
	void Trail()
	{
		FSpawnParticleParams p;
		p.color1 = random(0, 1) ? c1 : c2;
		p.flags = SPF_FULLBRIGHT;
		p.lifetime = 14;
		p.size = 5;
		p.sizestep = -0.3;
		p.pos = pos + (frandom(-3, 3), frandom(-3, 3), frandom(0, 6));
		p.vel = (0, 0, 0.3);
		p.startalpha = 0.9;
		p.fadestep = -1;
		level.SpawnParticle(p);
	}
	States
	{
	Spawn:
		SLMB A 2 Trail();
		Loop;
	Death:
		SLMB A 0 { CubeShard.Burst(pos, c1, c2, 6, 3, 0.25); }
		Stop;
	}
}

class SlimeCube : CubeBall
{
	Default
	{
		Speed 11;
		DamageFunction (random(3, 12));
		SeeSound "cat/splash";
		DeathSound "cat/hurtmob";
		CubeBall.Colors "70E050", "38A030";
	}
}

class MagmaCube : CubeBall
{
	Default
	{
		Speed 12;
		DamageFunction (3 * random(1, 8));
		SeeSound "imp/attack";
		DeathSound "cat/laserhit";
		CubeBall.Colors "FF7020", "FFD040";
		+BRIGHT
	}
	States
	{
	Spawn:
		MGMB A 2 Light("MAGMA") Trail();
		Loop;
	Death:
		MGMB A 0 { CubeShard.Burst(pos, c1, c2, 6, 3, 0.25); }
		Stop;
	}
}

class BeeStinger : CubeBall
{
	Default
	{
		Speed 16;
		Scale 0.45;
		DamageFunction (random(5, 25));
		SeeSound "caco/attack";
		DeathSound "cat/hurtmob";
		CubeBall.Colors "FFE040", "302830";
	}
	States
	{
	Spawn:
		HNYB A 2 Trail();
		Loop;
	Death:
		HNYB A 0 { CubeShard.Burst(pos, c1, c2, 6, 3, 0.25); }
		Stop;
	}
}

class CubeArrow : Actor
{
	Default
	{
		Projectile;
		-NOGRAVITY
		Gravity 0.1;
		Radius 4;
		Height 6;
		Speed 24;
		Scale 0.5;
		DamageFunction (random(4, 16));
		SeeSound "cat/flap";
		DeathSound "cat/hurtmob";
	}
	States
	{
	Spawn:
		ARRO A -1;
		Stop;
	Death:
		ARRO A 0 { CubeShard.Burst(pos, "8A6038", "D0D0D0", 4, 2, 0.18); }
		Stop;
	}
}
