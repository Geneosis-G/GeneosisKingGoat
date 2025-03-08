class GGAIControllerKnightGoat extends GGAIControllerPassiveGoat;

var float mDestinationOffset;

var kActorSpawnable destActor;
var bool cancelNextRagdoll;
var float totalTime;
var bool isArrived;
var bool isPossessing;

var GGGoat targetKing;
var GGGoat king;
var bool agressive;
var float mySpeed;
var float pushForce;
//var vector pushVector;

event PostBeginPlay()
{
	super.PostBeginPlay();

	king=GGGoat(Owner);
}

/**
 * Cache the NPC and mOriginalPosition
 */
event Possess(Pawn inPawn, bool bVehicleTransition)
{
	local ProtectInfo destination;

	super.Possess(inPawn, bVehicleTransition);

	isPossessing=true;
	if(mMyPawn == none)
		return;

	mMyPawn.mStandUpDelay=2.0f;
	mMyPawn.mTimesKnockedByGoat=0.f;
	mMyPawn.mTimesKnockedByGoatStayDownLimit=1000000.f;

	mMyPawn.mRunAnimationInfo=class'GGNpcAgressiveGoat'.default.mRunAnimationInfo;
	mMyPawn.mDefaultAnimationInfo=class'GGNpcAgressiveGoat'.default.mDefaultAnimationInfo;
	mMyPawn.mAttackAnimationInfo=class'GGNpcAgressiveGoat'.default.mAttackAnimationInfo;
	mMyPawn.mRunAnimationInfo.MovementSpeed=king.mSprintSpeed;
	mMyPawn.mPanicAnimationInfo=mMyPawn.mRunAnimationInfo;
	mMyPawn.mPanicAnimationInfo.AnimationNames[0]='Sprint';

	mMyPawn.GroundSpeed = king.mSprintSpeed;
	mMyPawn.AirSpeed = king.mSprintSpeed;
	mMyPawn.WaterSpeed = king.mSprintSpeed;
	mMyPawn.LadderSpeed = king.mSprintSpeed;
	mMyPawn.JumpZ = king.JumpZ;

	mMyPawn.mProtectItems.Length=0;
	if(destActor == none)
	{
		destActor = Spawn(class'kActorSpawnable', mMyPawn,,,,,true);
		destActor.SetHidden(true);
		destActor.SetPhysics(PHYS_None);
		destActor.CollisionComponent=none;
	}
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " destActor=" $ destActor);
	destActor.SetLocation(mMyPawn.Location);
	destination.ProtectItem = mMyPawn;
	destination.ProtectRadius = 1000000.f;
	mMyPawn.mProtectItems.AddItem(destination);
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " mMyPawn.mProtectItems[0].ProtectItem=" $ mMyPawn.mProtectItems[0].ProtectItem);
	StandUp();
}

event UnPossess()
{
	destActor.ShutDown();
	destActor.Destroy();

	isPossessing=false;
	super.UnPossess();
	mMyPawn=none;
}

//Kill AI if zombie is destroyed
function bool KillAIIfPawnDead()
{
	if(mMyPawn == none || mMyPawn.bPendingDelete || mMyPawn.Controller != self)
	{
		UnPossess();
		Destroy();
		return true;
	}

	return false;
}

event Tick( float deltaTime )
{
	local float speed, max_speed;

	//Kill destroyed knights
	if(isPossessing)
	{
		if(KillAIIfPawnDead())
		{
			return;
		}
	}

	// Optimisation
	if( mMyPawn.IsInState( 'UnrenderedState' ) )
	{
		return;
	}

	Super.Tick( deltaTime );

	// Fix dead attacked pawns
	if( mPawnToAttack != none )
	{
		if( mPawnToAttack.bPendingDelete )
		{
			mPawnToAttack = none;
		}
	}

	//WorldInfo.Game.Broadcast(self, mMyPawn $ " (1) isArrived=" $ isArrived $ ", Vel=" $ mMyPawn.Velocity);
	cancelNextRagdoll=false;

	if(targetKing == none || targetKing.bPendingDelete)
	{
		targetKing=king;
	}

	if(!mMyPawn.mIsRagdoll)
	{
		//Fix NPC with no collisions
		if(mMyPawn.CollisionComponent == none)
		{
			mMyPawn.CollisionComponent = mMyPawn.Mesh;
		}

		//Fix NPC rotation
		UnlockDesiredRotation();
		if(mPawnToAttack != none)
		{
			Pawn.SetDesiredRotation( rotator( Normal2D( mPawnToAttack.Location - Pawn.Location ) ) );
			mMyPawn.LockDesiredRotation( true );

			//Fix pawn stuck after attack
			if(!IsValidEnemy(mPawnToAttack) || !PawnInRange(mPawnToAttack))
			{
				EndAttack();
			}
			else if(mCurrentState == '')
			{
				GotoState( 'ChasePawn' );
			}
		}
		else
		{
			//Fix random movement state
			if(mCurrentState == '')
			{
				//WorldInfo.Game.Broadcast(self, mMyPawn $ " no state detected");
				GoToState('FollowKing');
			}

			UpdateFollowKing();
			//Force speed reduction when close to target
			speed=VSize(mMyPawn.Velocity);
			max_speed=VSize2D(GetPosition(mMyPawn)-destActor.Location)*2.f;
			if(speed > max_speed)
			{
				mMyPawn.Velocity.X*=max_speed/speed;
				mMyPawn.Velocity.Y*=max_speed/speed;
				mMyPawn.Velocity.Z*=max_speed/speed;
			}
			//WorldInfo.Game.Broadcast(self, mMyPawn $ "(" $ mMyPawn.Physics $ ")");
			//WorldInfo.Game.Broadcast(self, mMyPawn $ "(" $ mMyPawn.mCurrentAnimationInfo.AnimationNames[0] $ ")");
			//WorldInfo.Game.Broadcast(self, mMyPawn $ "(" $ mCurrentState $ ")");

		}
		//WorldInfo.Game.Broadcast(self, mMyPawn $ " (2) isArrived=" $ isArrived $ ", Vel=" $ mMyPawn.Velocity);
		if(IsZero(mMyPawn.Velocity))
		{
			if(isArrived && !mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mDefaultAnimationInfo ) )
			{
				mMyPawn.SetAnimationInfoStruct( mMyPawn.mDefaultAnimationInfo );//WorldInfo.Game.Broadcast(self, mMyPawn $ "DefaultAnim");
			}
		}
		else
		{
			if(VSize2D(mMyPawn.Velocity) < king.mWalkSpeed)
			{
				if( !mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mRunAnimationInfo ) )
				{
					mMyPawn.SetAnimationInfoStruct( mMyPawn.mRunAnimationInfo );//WorldInfo.Game.Broadcast(self, mMyPawn $ "RunAnim");
				}
			}
			else
			{
				if( !mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mPanicAnimationInfo ) )
				{
					mMyPawn.SetAnimationInfoStruct( mMyPawn.mPanicAnimationInfo );//WorldInfo.Game.Broadcast(self, mMyPawn $ "RunAnim");
				}
			}
		}
		// if waited too long to before reaching some place or some target, abandon
		totalTime = totalTime + deltaTime;
		if(totalTime > 11.f)
		{
			totalTime=0.f;
			mMyPawn.SetRagdoll(true);
		}
	}
	else
	{
		//Fix NPC not standing up
		if(!IsTimerActive( NameOf( StandUp ) ))
		{
			StartStandUpTimer();
		}

		//Make drowning goats follow king
		if(mMyPawn.mInWater)
		{
			totalTime = totalTime + deltaTime;
			if(totalTime > 1.f)
			{
				totalTime=0.f;
				DoRagdollJump();
			}
		}
	}
}

/**
 * Do ragdoll jump, e.g. for jumping out of water.
 */
function DoRagdollJump()
{
	local vector newVelocity;

	newVelocity = Normal2D(GetPosition(targetKing)-GetPosition(mMyPawn));
	newVelocity.Z = 1.f;
	newVelocity = Normal(newVelocity) * king.mRagdollJumpZ;

	mMyPawn.mesh.SetRBLinearVelocity( newVelocity );
}

function UpdateFollowKing()
{
	local vector dest, voffset;
	local GGNpc hitNpcGoat;
    local vector HitLoc, HitNorm, start, end;
    local TraceHitInfo hitInfo;
	local GGAIControllerKnightGoat knightController;
	local GGPawn target, target2;
	local float myRadius, targetRadius, offset;
	local rotator roffset;

	if(mPawnToAttack != none || mMyPawn.mIsRagdoll)
	{
		return;
	}

	target=targetKing;
	target2=targetKing;
	myRadius=mMyPawn.GetCollisionRadius();
	roffset=mMyPawn.Rotation;
	roffset.Yaw+=16384;
	start = GetPosition(mMyPawn) + Normal(vector(roffset))*myRadius;
    end = GetPosition(targetKing) + Normal(vector(roffset))*myRadius;
	end.Z=start.Z;
    foreach TraceActors(class'GGNpc', hitNpcGoat, HitLoc, HitNorm, end, start, ,hitInfo)
    {
        knightController=GGAIControllerKnightGoat(hitNpcGoat.Controller);
		if(knightController != none)
		{
			target=hitNpcGoat;
			break;
		}
    }
	roffset=mMyPawn.Rotation;
	roffset.Yaw-=16384;
	start = GetPosition(mMyPawn) + Normal(vector(roffset))*myRadius;
    end = GetPosition(targetKing) + Normal(vector(roffset))*myRadius;
	end.Z=start.Z;
    foreach TraceActors(class'GGNpc', hitNpcGoat, HitLoc, HitNorm, end, start, ,hitInfo)
    {
        knightController=GGAIControllerKnightGoat(hitNpcGoat.Controller);
		if(knightController != none)
		{
			target2=hitNpcGoat;
			break;
		}
    }

	//WorldInfo.Game.Broadcast(self, mMyPawn $ " start random movement");

	if(VSize(GetPosition(target2)-GetPosition(mMyPawn))<VSize(GetPosition(target)-GetPosition(mMyPawn)))
	{
		target=target2;
	}
	targetRadius=target.GetCollisionRadius();
	dest=GetPosition(target);
	offset=myRadius*2 + targetRadius;
	voffset=Normal2D(GetPosition(mMyPawn)-dest)*offset;
	dest+=voffset;
	dest.Z=GetPosition(mMyPawn).Z;

	if(VSize2D(GetPosition(mMyPawn)-dest) < offset)
	{
		dest=GetPosition(mMyPawn);
		if(!isArrived)
		{
			isArrived=true;//WorldInfo.Game.Broadcast(self, mMyPawn $ " (1) isArrived=true");
			mMyPawn.ZeroMovementVariables();
		}
		totalTime=0.f;
	}
	else
	{
		if(isArrived)
		{
			isArrived=false;//WorldInfo.Game.Broadcast(self, mMyPawn $ " (1) isArrived=false");
			totalTime=-10.f;
		}
	}

	//DrawDebugLine (mMyPawn.Location, dest, 0, 0, 0,);

	destActor.SetLocation(dest);
	if(!isArrived)
	{
		Pawn.SetDesiredRotation( rotator( Normal2D( destActor.Location - Pawn.Location ) ) );
	}
	mMyPawn.LockDesiredRotation( true );
}

function vector GetPosition(GGPawn gpawn)
{
	return gpawn.mIsRagdoll?gpawn.mesh.GetPosition():gpawn.Location;
}

function StartProtectingItem( ProtectInfo protectInformation, GGPawn threat )
{
	StopAllScheduledMovement();
	totalTime=0.f;

	mCurrentlyProtecting = protectInformation;

	mPawnToAttack = threat;

	StartLookAt( threat, 5.0f );

	GotoState( 'ChasePawn' );
}

/**
 * Attacks mPawnToAttack using mMyPawn.mAttackMomentum
 * called when our pawn needs to protect and item from a given pawn
 */
function AttackPawn()
{
	super.AttackPawn();

	if(GGNpc(mPawnToAttack) != none)
	{
		GGNpc(mPawnToAttack).SetRagdoll(true);
	}

	//Fix pawn stuck after attack
	if(IsValidEnemy(mPawnToAttack) && PawnInRange(mPawnToAttack))
	{
		GotoState( 'ChasePawn' );
	}
	else
	{
		EndAttack();
	}
}

/**
 * We have to disable the notifications for changing states, since there are so many npcs which all have hundreds of calls.
 */
state MasterState
{
	function BeginState( name prevStateName )
	{
		mCurrentState = GetStateName();
	}
}

state FollowKing extends MasterState
{
	event PawnFalling()
	{
		GoToState( 'WaitingForLanding',,,true );
	}
Begin:
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " FollowKing");
	mMyPawn.ZeroMovementVariables();
	while(mPawnToAttack == none && !KillAIIfPawnDead())
	{
		//WorldInfo.Game.Broadcast(self, mMyPawn $ " STATE OK!!!");
		if(!isArrived)
		{
			MoveToward (destActor);
		}
		else
		{
			MoveToward (mMyPawn,, mDestinationOffset);// Ugly hack to prevent "runnaway loop" error
		}
	}
	mMyPawn.ZeroMovementVariables();
}

state WaitingForLanding
{
	event LongFall()
	{
		mDidLongFall = true;
	}

	event NotifyPostLanded()
	{
		if( mDidLongFall || !CanReturnToOrginalPosition() )
		{
			if( mMyPawn.IsDefaultAnimationRestingOnSomething() )
			{
			    mMyPawn.mDefaultAnimationInfo =	mMyPawn.mIdleAnimationInfo;
			}

			mOriginalPosition = mMyPawn.Location;
		}

		mDidLongFall = false;

		StopLatentExecution();
		mMyPawn.ZeroMovementVariables();
		GoToState( 'FollowKing', 'Begin',,true );
	}

Begin:
	mMyPawn.ZeroMovementVariables();
	WaitForLanding( 1.0f );
}

state ChasePawn extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	mMyPawn.SetAnimationInfoStruct( mMyPawn.mRunAnimationInfo );

	while(mPawnToAttack != none && !KillAIIfPawnDead() && (VSize( mMyPawn.Location - mPawnToAttack.Location ) > mMyPawn.mAttackRange || !ReadyToAttack()))
	{
		MoveToward( mPawnToAttack,, mDestinationOffset );
	}

	if(mPawnToAttack == none)
	{
		ReturnToOriginalPosition();
	}
	else
	{
		FinishRotation();
		GotoState( 'Attack' );
	}
}

state Attack extends MasterState
{
	ignores SeePlayer;
 	ignores SeeMonster;
 	ignores HearNoise;
 	ignores OnManual;
 	ignores OnWallJump;
 	ignores OnWallRunning;

begin:
	Focus = mPawnToAttack;

	StartAttack( mPawnToAttack );
	FinishRotation();
}

/**
 * Helper function to determine if the last seen goat is near a given protect item
 * @param  protectInformation - The protectInfo to check against
 * @return true / false depending on if the goat is near or not
 */
function bool GoatNearProtectItem( ProtectInfo protectInformation )
{
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " mProtectItems[0]=" $ mMyPawn.mProtectItems[0].ProtectItem);
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " ProtectItem=" $ protectInformation.ProtectItem);

	if( protectInformation.ProtectItem == None || mVisibleEnemies.Length == 0 )
	{
		return false;
	}
	else
	{
		return true;
	}
}

/**
 * Helper function to determine if our pawn is close to a protect item, called when we arrive at a pathnode
 * @param currentlyAtNode - The pathNode our pawn just arrived at
 * @param out_ProctectInformation - The info about the protect item we are near if any
 * @return true / false depending on if the pawn is near or not
 */
function bool NearProtectItem( PathNode currentlyAtNode, out ProtectInfo out_ProctectInformation )
{
	out_ProctectInformation=mMyPawn.mProtectItems[0];
	return true;
}

function bool IsValidEnemy( Pawn newEnemy )
{
	local GGNpc npc;
	local GGPawn gpawn;
	local GGAIControllerKnightGoat knightController;

	gpawn=GGPawn(newEnemy);
	if(!agressive || gpawn.mIsRagdoll)
	{
		return false;
	}

	npc = GGNpc(gpawn);
	if(GGGoat(gpawn) != none && gpawn != king && gpawn.Controller != none)
	{
		return true;
	}

	//WorldInfo.Game.Broadcast(self, mMyPawn $ " canAttack(npc)=" $ npc);
	if(npc != none)
	{
		if(npc.mInWater)
		{
			return false;
		}

		//WorldInfo.Game.Broadcast(self, mMyPawn $ " canAttack(controller)=" $ npc.Controller);
		knightController=GGAIControllerKnightGoat(npc.Controller);
		if(knightController == none && GGAIController(npc.Controller) != none)
		{
			return true;
		}

		if(knightController != none && knightController.king != king)
		{
			return true;
		}
	}

	return false;
}

/**
 * Helper functioner for determining if the goat is in range of uur sightradius
 * if other is not specified mLastSeenGoat is checked against
 */
function bool PawnInRange( optional Pawn other )
{
	if(mMyPawn.mIsRagdoll || mPawnToAttack.Physics == PHYS_RigidBody)
	{
		return false;
	}
	else
	{
		return super.PawnInRange(other);
	}
}

/**
 * Called when an actor takes damage
 */
function OnTakeDamage( Actor damagedActor, Actor damageCauser, int damage, class< DamageType > dmgType, vector momentum )
{
	if(damagedActor == mMyPawn)
	{
		if(dmgType == class'GGDamageTypeCollision' && !mMyPawn.mIsRagdoll)
		{
			cancelNextRagdoll=true;
			//pushVector=pushForce*Normal(damagedActor.Location-damageCauser.Location);
		}
	}
}

function bool CanReturnToOrginalPosition()
{
	return false;
}

/**
 * Go back to where the position we spawned on
 */
function ReturnToOriginalPosition()
{
	GotoState( 'FollowKing' );
}

/**
 * Helper function for when we see the goat to determine if it is carrying a scary object
 */
function bool GoatCarryingDangerItem()
{
	return false;
}

function bool PawnUsesScriptedRoute()
{
	return false;
}

//--------------------------------------------------------------//
//			GGNotificationInterface								//
//--------------------------------------------------------------//

/**
 * Called when an actor begins to ragdoll
 */
function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	local GGNPc npc;

	npc = GGNPc( ragdolledActor );

	if(ragdolledActor == mMyPawn)
	{
		if(isRagdoll)
		{
			if(cancelNextRagdoll)
			{
				cancelNextRagdoll=false;
				StandUp();
				//mMyPawn.SetPhysics( PHYS_Falling);
				//mMyPawn.Velocity+=pushVector;
			}
			else
			{
				if( IsTimerActive( NameOf( StopPointing ) ) )
				{
					StopPointing();
					ClearTimer( NameOf( StopPointing ) );
				}

				if( IsTimerActive( NameOf( StopLookAt ) ) )
				{
					StopLookAt();
					ClearTimer( NameOf( StopLookAt ) );
				}

				if( mCurrentState == 'ProtectItem' )
				{
					ClearTimer( nameof( AttackPawn ) );
					ClearTimer( nameof( DelayedGoToProtect ) );
				}
				StopAllScheduledMovement();
				StartStandUpTimer();
				EndAttack();
			}

			if( npc != none && npc.LifeSpan > 0.0f )
			{
				if( npc == mPawnToAttack )
				{
					EndAttack();
				}

				if( npc == mLookAtActor )
				{
					StopLookAt();
				}
			}
		}
	}
}

DefaultProperties
{
	mDestinationOffset=100.0f

	bIsPlayer=true
	mIgnoreGoatMaus=true

	mAttackIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mCheckProtItemsThreatIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mVisibilityCheckIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)

	agressive=false
	cancelNextRagdoll=false
	pushForce=10.f
}