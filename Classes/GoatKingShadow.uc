class GoatKingShadow extends GGGoat;

var GGGoat king;
var StaticMeshComponent CrownMesh;
var vector pos;


simulated event PostBeginPlay()
{
	super.PostBeginPlay();

	king=GGGoat(Owner);
	CopyKingForm();

	CrownMesh.SetLightEnvironment( mesh.LightEnvironment );
	mesh.AttachComponentToSocket( CrownMesh, 'hairSocket' );

	CheatGhost();
	bCanBeDamaged=false;
	bBlockActors=false;

	mesh.SetNotifyRigidBodyCollision( false );
	mesh.SetHasPhysicsAssetInstance( false );

	SetPhysics(PHYS_None);
	pos=Location;
}

function CopyKingForm()
{
	if(king != none && king.mesh.SkeletalMesh != mesh.SkeletalMesh)
	{
		mesh.SetSkeletalMesh( king.mesh.SkeletalMesh );
		mesh.SetPhysicsAsset( king.mesh.PhysicsAsset );
		mesh.SetAnimTreeTemplate( king.mesh.AnimTreeTemplate );
		mesh.AnimSets = king.mesh.AnimSets;

		SetLocation( Location + vect( 0.0f, 0.0f, 1.0f ) * (king.GetCollisionHeight() - GetCollisionHeight()) );
	}

	SetNewMaterial(mTransparentMaterial);
}

function UpdateHeadLookAt();

/**
 * See super.
 */
event Tick( float deltaTime )
{
	super.Tick( deltaTime );

	Velocity=vect(0, 0, 0);
	mIsRagdollAllowed=false;

	if(pos != vect(0, 0, 0) && Location != pos)
	{
		SetLocation(pos);
		SetPhysics(PHYS_None);
	}
}

DefaultProperties
{
	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'Hats.Mesh.Crown'
	End Object
	CrownMesh=StaticMeshComp1

	pos=(X=0, Y=0, Z=0)
	CollisionType=COLLIDE_NoCollision
}