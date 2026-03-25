using Godot;
using Godot.Collections;
using System.Collections.Generic;

public partial class ProjectileSystem2D : Node2D
{
	[Export] public int Capacite = 4096;
	[Export] public uint MasqueParDefaut = 0;

	// Visu simple (cercles)
	[Export] public bool VisuPoints = true;
	[Export] public float VisuRayon = 5f;
	[Export] public Color VisuCouleur = new Color(1, 1, 1, 0.95f);

	// Optionnel: MultiMesh (désactive si tu n’as pas de sprite)
	[Export] public bool RenderBalles = false;
	[Export] public Texture2D Sprite = null;

	struct P
	{
		public Vector2 pos, prev, vel;
		public float vie;
		public int degats, pierce;
		public float recul;
		public uint masque;
		public Node source;
		public bool actif;
	}

	P[] _ps;
	Stack<int> _libres;
	PhysicsDirectSpaceState2D _space;
	MultiMeshInstance2D _mmi;
	MultiMesh _mm;

	public override void _Ready()
	{
		_ps = new P[Capacite];
		_libres = new Stack<int>(Capacite);
		for (int i = Capacite - 1; i >= 0; --i) _libres.Push(i);
		_space = GetWorld2D().DirectSpaceState;

		if (RenderBalles && Sprite != null)
		{
			_mmi = new MultiMeshInstance2D();
			_mm = new MultiMesh();
			_mm.TransformFormat = MultiMesh.TransformFormatEnum.Transform2D;
			_mm.InstanceCount = Capacite;
			_mmi.Multimesh = _mm;
			_mmi.Texture = Sprite;
			AddChild(_mmi);
			for (int i = 0; i < Capacite; i++)
				_mm.SetInstanceTransform2D(i, new Transform2D(0, new Vector2(999999, 999999)));
		}

		AddToGroup("projectile_system");
	}

	public int Spawn(Vector2 pos, Vector2 dir, float vitesse, float duree, int degats, float recul, uint masque, int pierce, Node source)
	{
		if (_libres.Count == 0) return -1;

		int i = _libres.Pop();
		_ps[i].pos = pos;
		_ps[i].prev = pos;
		_ps[i].vel = dir.Normalized() * vitesse;
		_ps[i].vie = duree;
		_ps[i].degats = degats;
		_ps[i].recul = recul;
		_ps[i].masque = masque;
		_ps[i].pierce = pierce;
		_ps[i].source = source;
		_ps[i].actif = true;

		if (RenderBalles && _mm != null)
			_mm.SetInstanceTransform2D(i, new Transform2D(_ps[i].vel.Angle(), pos));

		return i;
	}

	void Despawn(int i)
	{
		_ps[i].actif = false;
		_libres.Push(i);
		if (RenderBalles && _mm != null)
			_mm.SetInstanceTransform2D(i, new Transform2D(0, new Vector2(999999, 999999)));
	}

	static Rid RidFromNode(Node n)
	{
		while (n != null)
		{
			if (n is CollisionObject2D co) return co.GetRid();
			n = n.GetParent();
		}
		return new Rid();
	}

	public override void _PhysicsProcess(double dt)
	{
		float t = (float)dt;

		for (int i = 0; i < _ps.Length; ++i)
		{
			if (!_ps[i].actif) continue;

			_ps[i].vie -= t;
			if (_ps[i].vie <= 0f) { Despawn(i); continue; }

			_ps[i].prev = _ps[i].pos;
			_ps[i].pos += _ps[i].vel * t;

			var q = PhysicsRayQueryParameters2D.Create(_ps[i].prev, _ps[i].pos);
			uint masque = _ps[i].masque != 0 ? _ps[i].masque : MasqueParDefaut;
			q.CollisionMask = masque;
			q.CollideWithAreas = true;
			q.CollideWithBodies = true;

			var ridSrc = RidFromNode(_ps[i].source);
			if (ridSrc.IsValid) q.Exclude = new Array<Rid> { ridSrc };

			Dictionary hit = _space.IntersectRay(q);
			if (hit.Count > 0)
			{
				var colliderObj = (GodotObject)hit["collider"];
				var collider = colliderObj as Node;
				var hitPos = (Vector2)hit["position"];
				var dir = _ps[i].vel.Normalized();

				if (IsInstanceValid(collider))
				{
					if (collider.HasMethod("tek_it"))
						collider.CallDeferred("tek_it", _ps[i].degats, _ps[i].source);
					else
					{
						var hb = collider.GetNodeOrNull<Node>("HurtBox");
						if (hb != null && hb.HasMethod("tek_it"))
							hb.CallDeferred("tek_it", _ps[i].degats, _ps[i].source);
					}

					var n = collider;
					while (IsInstanceValid(n))
					{
						if (n.HasMethod("appliquer_recul_depuis"))
						{
							n.CallDeferred("appliquer_recul_depuis", _ps[i].source as Node2D, _ps[i].recul);
							break;
						}
						n = n.GetParent();
					}
				}

				_ps[i].pierce--;
				if (_ps[i].pierce < 0) { Despawn(i); continue; }
				_ps[i].pos = hitPos + dir * 0.5f;
			}

			if (RenderBalles && _mm != null)
			{
				float a = _ps[i].vel.Angle();
				_mm.SetInstanceTransform2D(i, new Transform2D(a, _ps[i].pos));
			}
		}
	}

	public override void _Process(double delta)
	{
		if (VisuPoints) QueueRedraw();
	}

	public override void _Draw()
	{
		if (!VisuPoints) return;
		for (int i = 0; i < _ps.Length; ++i)
			if (_ps[i].actif) DrawCircle(_ps[i].pos, VisuRayon, VisuCouleur);
	}
}
