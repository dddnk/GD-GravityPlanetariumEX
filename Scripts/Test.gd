extends Node2D


@export var DebugDraw:bool
@export_enum('Naïve','Barnes - Hut') var Mode:int = 1
@export var Theta:float = 0.5
@export var Softening:float = 0
@export var RootNode:Node2D
@export var Bodies:Array[Node2D]
@export var IndependentDeltatime:float = 0.01
#@export var G:float = 1
@export var BodiesList:Array[PackedScene]
@export var Quantities:Array[int]

# Tree Dimensions
static var GlobalDistance:float
static var GlobalMinBound:Vector2
static var GlobalMaxBound:Vector2

var EraseList:Array[Sprite2D]
var EraseSize:int

const RandVel:float = 2
const SpawnRange:float = 200
const NodePrefab:PackedScene = preload('res://bh_node.tscn')
const SpriteSizes:Dictionary = { 30: 8,65:16,250:24,8000:32 }

#Helper Functions
func FastAbs(A:float) -> float:
	return A if A >= 0 else -A

func Vector2Abs(V:Vector2) -> Vector2:
	return Vector2(FastAbs(V.x),FastAbs(V.y))

func DstSqr(Delta:Vector2) -> float:
	return Delta.x * Delta.x + Delta.y * Delta.y

func VecPow(V:Vector2,F:float):
	return Vector2(pow(V.x,F),pow(V.y,F))

func RawForceCalcuation(d:Vector2,BMass:float) -> Vector2:
	var MGT:float = ((d.y ** 2) + (d.x ** 2) + (Softening ** 2)) ** -1.5
	return Vector2(d.x * MGT * BMass,d.y * MGT * BMass)

func SpriteUpdate(A:Sprite2D) -> void:
	var MS:float = A.Mass
	var NewOffset:int = 0
	for K in SpriteSizes.keys():
		if K < MS:
			NewOffset = SpriteSizes[K]
	A.region_rect.position.y = NewOffset
	
func FlushTree() -> void:
	var children:Array = RootNode.get_children()
	for b in Bodies:
		b.reparent(self)
	for c in children:
		c.queue_free()

func PopulateRandom() -> void:
	if len(Quantities) == len(BodiesList) and len(Quantities) > 0:
		for B in range(len(BodiesList)):
			if Quantities[B] == 0:
				continue
			for q in range(Quantities[B]):
				var F:Sprite2D = BodiesList[B].instantiate()
				F.position = Vector2(randf_range(-SpawnRange,SpawnRange),randf_range(-SpawnRange,SpawnRange))
				F.Velocity = Vector2(randf_range(-RandVel,RandVel),randf_range(-RandVel,RandVel))
				add_child(F)
				Bodies.append(F)
		Bodies.sort_custom(func(a,b): return a.Mass * a.Radius < b.Mass * b.Radius)

func SplitBasis(A:float,B:float,D:float) -> Vector2:
	return Vector2((A+B)/2,B) if D == 1 else Vector2(A,(A+B)/2)
	
func CalculateBounds() -> void:
	for B in Bodies:
		var Pos:Vector2 = B.position
		# X Component
		if GlobalMaxBound.x < Pos.x:
			GlobalMaxBound.x = Pos.x + 1
		elif Pos.x < GlobalMinBound.x:
			GlobalMinBound.x = Pos.x - 1
		# Y Component
		if GlobalMaxBound.y < Pos.y:
			GlobalMaxBound.y = Pos.y + 1
		elif Pos.y < GlobalMinBound.y:
			GlobalMinBound.y = Pos.y - 1
	# Calculate Distance
	#var HF := Vector2(GlobalMinBound.x + GlobalMaxBound.x,GlobalMinBound.y + GlobalMaxBound.y) / 2
	#var SSize:Vector2 = GlobalMaxBound - GlobalMinBound
	GlobalDistance = GlobalMaxBound.distance_to(GlobalMinBound)
	#RootNode.NDArea = Rect2(-HF.x * 16,-HF.y * 16,SSize.x * 16,SSize.y * 16)

# Split tree
func SplitTree(AncestorNode:Node2D,LocalBodies:Array,MinBound:Vector2,MaxBound:Vector2,PreLength:int,Depth:int):
	if PreLength == 1:
		var OnlyChild:Node2D = LocalBodies[0]
		OnlyChild.reparent(AncestorNode)
		AncestorNode.COM = OnlyChild.position
		AncestorNode.Mass = OnlyChild.Mass
		AncestorNode.Quantity = 1
		AncestorNode.Depth = Depth + 1
	else:
		var QuadrantsPart:Array = [[],[],[],[]]
		var Length:PackedInt32Array = [0,0,0,0]
		for L:Node2D in LocalBodies:
			var Q:int = 0
			if MaxBound.x - L.position.x < L.position.x - MinBound.x:
				Q += 1
			if MaxBound.y - L.position.y < L.position.y - MinBound.y:
				Q += 2
			QuadrantsPart[Q].append(L)
			Length[Q] += 1
		for Q in range(4):
			if Length[Q] > 0:
				var NewNode:Node2D = NodePrefab.instantiate()
				AncestorNode.add_child(NewNode)
				var Center:Vector2 = Vector2.ZERO
				var NMass:float = 0
				for L:Node2D in QuadrantsPart[Q]:
					L.reparent(NewNode)
					NMass += L.Mass
					Center += L.position
				NewNode.COM = Center / Length[Q]
				NewNode.Mass = NMass
				NewNode.Quantity = Length[Q]
				NewNode.Depth = Depth + 1
				NewNode.Ancestor = AncestorNode
				var FX:Vector2 = SplitBasis(MinBound.x,MaxBound.x,Q & 1)
				var FY:Vector2 = SplitBasis(MinBound.y,MaxBound.y,Q >> 1)
				NewNode.NDArea = Rect2(FX.x,FY.x,(FX.y - FX.x),(FY.y - FY.x))
				SplitTree(NewNode,QuadrantsPart[Q],Vector2(FX.x,FY.x),Vector2(FX.y,FY.y),Length[Q],Depth + 1)

func _ready():
	PopulateRandom()
	#CalculateBounds()
	#SplitTree(RootNode,Bodies,GlobalMinBound,GlobalMaxBound,len(Bodies),0)
	#FlushTree()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Mode == 0:
		LegacyCalculate(delta * IndependentDeltatime)
	elif Mode == 1:
		CalculateBounds()
		FlushTree()
		SplitTree(RootNode,Bodies,GlobalMinBound,GlobalMaxBound,len(Bodies),0)
		Calculate(delta * IndependentDeltatime)
		if DebugDraw:
			queue_redraw()

func DrawTree(ND:Node2D):
	if (not ND is Sprite2D):
		draw_rect(ND.NDArea,Color.ORANGE,false,1)
		if ND.get_child_count() > 0:
			for x in ND.get_children():
				DrawTree(x)

func CalculateParForce(A:Sprite2D,B:Node2D,D:float,DeltaPos:Vector2,R:float) -> Vector2:
	if B.Mass <= A.Mass and B.Quantity == 1:
		var CH:Sprite2D = B.get_child(0)
		if CH == null:
			return Vector2.ZERO
		#Arranged so more expensive checks are used less often.
		if sqrt(R) <= (A.Radius + CH.Radius) and B.Active:
			Bodies.erase(CH)
			EraseList.append(CH)
			A.Mass += CH.Mass
			SpriteUpdate(A)
			B.Active = false
			CH.visible = false
			EraseSize += 1
			return (A.Velocity * A.Mass + CH.Velocity * CH.Mass) / A.Mass
	return RawForceCalcuation(DeltaPos,B.Mass)

func CalculateTreeForce(A,B) -> Vector2:
	var DeltaPos:Vector2 = B.COM - A.position
	var d:float = GlobalDistance / (2 << B.Depth)
	if B.Quantity == 1:
		return CalculateParForce(A,B,d,DeltaPos,DstSqr(DeltaPos))
	else:
		var r:float = DstSqr(DeltaPos)
		if d/r < Theta:
			return CalculateParForce(A,B,d,DeltaPos,r)
		else:
			var TotalForce:Vector2 = Vector2.ZERO
			for C:Node in B.get_children():
				if C.Active:
					TotalForce += CalculateTreeForce(A,C)
			return TotalForce


func Calculate(Dt) -> void:
	#Calculate force and update position and velocity accordingly
	for BD:Node2D in Bodies:
		if BD in EraseList:
			continue
		var F:Vector2 = Vector2.ZERO 
		for C in RootNode.get_children():
			F += CalculateTreeForce(BD,C)
		BD.Velocity += F * Dt
		BD.position += BD.Velocity * Dt
	#Remove assimilated bodies
	if EraseSize > 0:
		for ER:int in range(EraseSize):
			var P:Sprite2D = EraseList.pop_front()
			P.queue_free()
		EraseSize = 0
	
func LegacyCalculate(Dt) -> void:
	var EraseList:Array[Sprite2D]
	for body in Bodies:
		if body == null:
			pass
		var a := Vector2.ZERO
		for other_body in Bodies:
			if not (other_body == body or other_body in EraseList):
				var d:Vector2 = other_body.position - body.position
				var PSQ:float = sqrt(DstSqr(d))
				if PSQ <= body.Radius + other_body.Radius and body.Mass >= other_body.Mass:
					body.Mass += other_body.Mass
					body.Velocity = (body.Velocity * body.Mass + other_body.Velocity * other_body.Mass) / body.Mass
					other_body.visible = false
					SpriteUpdate(body)
					EraseList.append(other_body)
				else:
					a += RawForceCalcuation(d,other_body.Mass) 
		body.Velocity += a*Dt
		body.position += body.Velocity * Dt
	for v in EraseList:
		Bodies.erase(v)
		v.queue_free()

func _draw():
	if DebugDraw:
		for C in RootNode.get_children():
			DrawTree(C)
