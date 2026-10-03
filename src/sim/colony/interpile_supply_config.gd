class_name InterpileSupplyConfig
extends Resource
@export var workers: int=8
@export var carbohydrate: float=4.0
@export var protein: float=2.0
@export var water: float=2.0
func pack(multiplier: float=1.0) -> Dictionary[String,float]:
 return {"carbohydrate":snappedf(carbohydrate*multiplier,0.00001),"protein":snappedf(protein*multiplier,0.00001),"water":snappedf(water*multiplier,0.00001)}
