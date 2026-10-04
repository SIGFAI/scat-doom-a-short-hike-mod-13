// Professor Whiskers: a superintelligent cat you carry. Fire: eye lasers. Alt fire: a tuna torpedo that digs craters.
class CatLaser : Weapon
{
	Default
	{
		Weapon.SlotNumber 2;
		Weapon.SelectionOrder 50;
		Weapon.Kickback 80;
		Weapon.BobStyle "InverseSmooth";
		Weapon.BobSpeed 1.6;
		Weapon.BobRangeX 0.6;
		Weapon.UpSound "cat/meow2";
		Inventory.PickupMessage "Professor Whiskers joins you.";
		Tag "Professor Whiskers";
		Obituary "%o was out-thought by a cat.";
		+WEAPON.AMMO_OPTIONAL +WEAPON.ALT_AMMO_OPTIONAL +WEAPON.NOALERT
	}
	States
	{
	Spawn:
		PWCT A -1;
		Stop;
	Ready:
		PWEP AAAAAAAAAAAABBBBBBBBBBBB 1 A_WeaponReady;
		Loop;
	Deselect:
		PWEP A 1 A_Lower(12);
		Loop;
	Select:
		PWEP A 1 A_Raise(12);
		Loop;
	Fire:
		PWEP C 2 Bright A_EyeLasers;
		PWEP D 3;
		PWEP A 2 A_ReFire;
		Goto Ready;
	AltFire:
		PWEP C 3 Bright A_TunaTorpedo;
		PWEP D 8;
		PWEP A 10;
		Goto Ready;
	}

	// The eyes, in the world: in front of the view where the cat's glasses are on screen
	// (the lenses sit at 258,136 of the 320x200 weapon screen: 0.61 to the right and 0.27 down per unit ahead).
	action Vector3 EyePos(double side)
	{
		Vector3 fwd = (Actor.AngleToVector(angle, cos(pitch)), -sin(pitch));
		Vector3 right = (Actor.AngleToVector(angle - 90, 1), 0);
		Vector3 up = (Actor.AngleToVector(angle, sin(pitch)), cos(pitch));
		return (pos.xy, player.viewz) + fwd * 40 + right * (24 + side * 2) - up * 11;
	}

	action void A_EyeLasers()
	{
		A_StartSound("cat/laser", CHAN_WEAPON, CHANF_OVERLAP, 0.9);
		double slope = BulletSlope();     // Doom's vertical autoaim: mobs a block up or flying get hit too
		FTranslatedLineTarget t;
		let puff = LineAttack(angle, 3000, slope, random(14, 19), 'Laser', "LaserPuff", 0, t);
		Vector3 hit;
		if (puff) hit = puff.pos;
		else hit = (pos.xy, player.viewz) + (Actor.AngleToVector(angle, cos(slope)), -sin(slope)) * 3000;
		LaserBeam.Draw(EyePos(-2.5), hit);
		LaserBeam.Draw(EyePos(2.5), hit);
		if (t.linetarget && t.linetarget.bIsMonster)
		{
			// burning: embers on the target
			FSpawnParticleParams p;
			for (int i = 0; i < 6; i++)
			{
				p.color1 = random(0, 1) ? "FF8020" : "FFD040";
				p.flags = SPF_FULLBRIGHT;
				p.lifetime = random(14, 24);
				p.size = frandom(3, 5);
				p.sizestep = -0.15;
				p.pos = t.linetarget.pos + (frandom(-12, 12), frandom(-12, 12), frandom(8, t.linetarget.height));
				p.vel = (frandom(-0.5, 0.5), frandom(-0.5, 0.5), frandom(1, 2.5));
				p.startalpha = 1;
				p.fadestep = -1;
				level.SpawnParticle(p);
			}
		}
	}

	action void A_TunaTorpedo()
	{
		A_StartSound("cat/meow1", CHAN_WEAPON, CHANF_OVERLAP, 1.0);
		A_FireProjectile("TunaTorpedo", 0, false, 6, -6);
		A_Recoil(1.5);
	}
}

// A whole tuna, thrown hard. Bubbles and sparkles behind it, a splash and a crater where it lands.
class TunaTorpedo : Actor
{
	Default
	{
		Radius 8;
		Height 10;
		Speed 22;
		DamageFunction (random(16, 24));
		Scale 0.4;
		Projectile;
		DeathSound "";
		SeeSound "cat/flap";
		Obituary "%o was hit by a flying tuna.";
	}
	States
	{
	Spawn:
		FISH AB 3 Bright A_TunaTrail;
		Loop;
	Death:
		TNT1 A 0 A_TunaBlast;
		TNT1 A 10;
		Stop;
	}
	override void Tick()
	{
		Super.Tick();
		bInvisible = GetAge() < 3;     // leaving the cat's paws: not a giant fish across the screen
	}
	void A_TunaTrail()
	{
		FSpawnParticleParams p;
		for (int i = 0; i < 3; i++)
		{
			p.color1 = random(0, 2) ? "C0F0FF" : "FFE070";
			p.flags = SPF_FULLBRIGHT;
			p.lifetime = random(14, 26);
			p.size = frandom(3, 6);
			p.sizestep = -0.12;
			p.pos = pos + (frandom(-4, 4), frandom(-4, 4), frandom(0, 8)) - vel * 0.3;
			p.vel = (frandom(-0.4, 0.4), frandom(-0.4, 0.4), frandom(0.2, 1.0));
			p.startalpha = 0.9;
			p.fadestep = -1;
			level.SpawnParticle(p);
		}
	}
	void A_TunaBlast()
	{
		A_Explode(96, 128, 0);
		Spawn("TunaBoom", pos);
		let h = CatHandler(EventHandler.Find("CatHandler"));
		if (h) h.Dig(pos, 92);
	}
}

// The hiker: starts with Professor Whiskers in hand and walks up one block at a time.
class HikerPlayer : DoomPlayer
{
	Default
	{
		Player.StartItem "CatLaser";
		MaxStepHeight 32;
		Player.DisplayName "Hiker";
	}
}
