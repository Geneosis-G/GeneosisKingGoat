class KingGoatComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;

var StaticMeshComponent CrownMesh;
var float controlRadius;

var ParticleSystem sheepKingHaloTemplate;
var ParticleSystemComponent sheepKingHalo;
var SoundCue sheepKingSound;
var array<GoatKingShadow> mShadows;

var bool kPressed;
var bool iPressed;
var bool nPressed;
var bool isSheepKing;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		CrownMesh.SetLightEnvironment( gMe.mesh.LightEnvironment );
		gMe.mesh.AttachComponentToSocket( CrownMesh, 'hairSocket' );
		sheepKingHalo = gMe.WorldInfo.MyEmitterPool.SpawnEmitterMeshAttachment( sheepKingHaloTemplate, gMe.mesh, 'hairSocket', true );
		sheepKingHalo.SetHidden(true);
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	if(PCOwner != gMe.Controller)
		return;

	if( keyState == KS_Down )
	{
		if(newKey == 'ONE' || newKey == 'XboxTypeS_RightShoulder')
		{
			EnrollKnights();
		}

		if(newKey == 'TWO' || newKey == 'XboxTypeS_LeftShoulder')
		{
			MakeKnightsAttack();
		}

		if(newKey == 'THREE' || newKey == 'XboxTypeS_LeftTrigger')
		{
			MakeShadowKing();
		}

		if(!isSheepKing)
		{
			if(newKey == 'K' || newKey == 'XboxTypeS_RightShoulder')
			{
				kPressed=true;
			}
			else if((newKey == 'I' || newKey == 'XboxTypeS_LeftTrigger') && kPressed)
			{
				iPressed=true;
			}
			else if((newKey == 'N' || newKey == 'XboxTypeS_RightTrigger') && iPressed)
			{
				nPressed=true;
			}
			else if((newKey == 'G' || newKey == 'XboxTypeS_LeftShoulder') && nPressed)
			{
				isSheepKing=true;
				gMe.PlaySound( sheepKingSound );
				sheepKingHalo.SetHidden(false);
			}
			else
			{
				kPressed=false;
				iPressed=false;
				nPressed=false;
			}
		}
	}
}

function bool IsValidClass(GGNpc npc)
{
	return GGNpcGoat(npc) != none || GGNPCMMOPlayerBot(npc) != none || (isSheepKing && (GGNPCSheepAbstract(npc) != none || GGNpcZombieGoat(npc) != none));
}

function EnrollKnights()
{
	local GGNpc npcGoat;
	local GGAIControllerKnightGoat knightController;

	if(gMe.mIsRagdoll)
		return;

	RemoveNearbyShadows();

	foreach myMut.CollidingActors(class'GGNpc', npcGoat, controlRadius, gMe.Location,,)
	{
		if(!IsValidClass(npcGoat))
		{
			continue;
		}

		//Take control of goats
		if((GGAIControllerKnightGoat(npcGoat.Controller) == none && GGAIController(npcGoat.Controller) != none) || npcGoat.Controller == none)
		{
			MakeItKnight(npcGoat);
		}
		//Stop agressivity of controlled goats
		knightController=GGAIControllerKnightGoat(npcGoat.Controller);
		if(knightController != none && knightController.king == gMe)
		{
			knightController.agressive=false;
		}
	}
}

function MakeKnightsAttack()
{
	local GGNpc npcGoat;
	local GGAIControllerKnightGoat knightController;

	if(gMe.mIsRagdoll)
		return;

	foreach myMut.CollidingActors (class'GGNpc', npcGoat, controlRadius, gMe.Location,,)
	{
		if(!IsValidClass(npcGoat))
		{
			continue;
		}

		//Make controlled goats agressive
		knightController=GGAIControllerKnightGoat(npcGoat.Controller);
		if(knightController != none && knightController.king == gMe)
		{
			knightController.agressive=true;
		}
	}
}

function MakeShadowKing()
{
	local GGNpc npcGoat;
	local GoatKingShadow shadowGoat;
	local GGAIControllerKnightGoat knightController;

	if(gMe.mIsRagdoll || gMe.mIsInAir)
		return;

	RemoveNearbyShadows();

	shadowGoat=myMut.Spawn(class'GoatKingShadow', gMe,, gMe.Location, gMe.Rotation,, true);
	mShadows.AddItem(shadowGoat);
	foreach myMut.CollidingActors (class'GGNpc', npcGoat, controlRadius, gMe.Location,,)
	{
		if(!IsValidClass(npcGoat))
		{
			continue;
		}

		//Make a shadow king that knights will follow
		knightController=GGAIControllerKnightGoat(npcGoat.Controller);
		if(knightController != none && knightController.king == gMe)
		{
			knightController.targetKing=shadowGoat;
		}
	}
}

function RemoveNearbyShadows()
{
	local int i;

	for(i=0 ; i<mShadows.Length ; i=i)
	{
		//Remove close shadows
		if(VSize(mShadows[i].Location - gMe.Location) < controlRadius)
		{
			mShadows[i].Destroy();
			mShadows.Remove(i, 1);
		}
		else
		{
			i++;
		}
	}
}

function MakeItKnight(GGNpc npcGoat)
{
	local Controller oldController;
	local GGAIControllerKnightGoat newController;

	oldController=npcGoat.Controller;
	//myMut.WorldInfo.Game.Broadcast(myMut, "oldController=" $ oldController);
	if(oldController != none)
	{
		oldController.Unpossess();
		if(PlayerController(oldController) == none)
		{
			oldController.Destroy();
		}
	}

	if(npcGoat.mIsRagdoll)
	{
		npcGoat.StandUp();
	}

	newController = myMut.Spawn(class'GGAIControllerKnightGoat', gMe);
	newController.Possess(npcGoat, false);
}

defaultproperties
{
	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'Hats.Mesh.Crown'
	End Object
	CrownMesh=StaticMeshComp1

	sheepKingHaloTemplate=ParticleSystem'MMO_Effects.Effects.Effects_Glow_01'
	sheepKingSound=SoundCue'Goat_Sounds.Cue.HolyGoat_Cue'

	controlRadius=1000.f
}