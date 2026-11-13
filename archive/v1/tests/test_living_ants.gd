extends RefCounted
const Scent = preload("res://src/presentation/outward/trail_visual.gd")
const Art = preload("res://src/presentation/sensory_art.gd")
const Panorama = preload("res://src/presentation/outward/outward_projection.gd")

func run(test: Object) -> bool:
	var size := Vector2(1280,720)
	var signals: Array[Dictionary]=[{"id":"s","source_knowledge_id":"known:x","category":"water","bearing":0.7,"estimated_distance":10.0,"strength":0.8,"uncertainty_radius":1.0}]
	var routes: Array[Dictionary]=[{"id":"r","destination_knowledge_id":"known:x","pheromone_strength":0.8,"route_familiarity":0.8,"active_workers":100000}]
	var placed: Array[Dictionary]=Panorama.project(signals,0,size)
	var path: Dictionary=Scent.paths(routes,placed,size)[0]
	var frozen: Array[Dictionary]=routes.duplicate(true)
	var min_speed: float=INF
	var max_speed: float=0
	for i: int in range(10,91,10):
		var distance: float=path.length*i/100.0
		var a: Dictionary=Scent.sample(path,distance)
		var b: Dictionary=Scent.sample(path,distance+0.1)
		var traveled: float=a.position.distance_to(b.position)
		test.check(absf(traveled-0.1)<0.002,"Equal arc increments produce equal displacement even near the entrance curve")
		test.check(a.direction.is_finite() and a.direction.length()>0.99,"Arc sampling gives a finite unit heading")
	for time: float in [0.0,0.7,1.9,3.2,5.8]:
		var ants: Array[Dictionary]=Scent.representatives(routes,placed,size,time)
		var next: Array[Dictionary]=Scent.representatives(routes,placed,size,time+0.001)
		for i: int in ants.size():
			var speed: float=ants[i].position.distance_to(next[i].position)/0.001
			min_speed=minf(min_speed,speed);max_speed=maxf(max_speed,speed)
			test.check(ants[i].direction.dot(Scent.sample(path,ants[i].distance).direction)*(-1.0 if i%2 else 1.0)>0.99,"Returning ants face their actual visual travel direction")
			test.check(ants[i].visibility>=0 and ants[i].visibility<=1,"Endpoint fading remains a bounded presentation property")
			test.check(is_equal_approx(next[i].gait-ants[i].gait,0.001*Scent.TRAVEL_PIXELS_PER_SECOND/Scent.STRIDE_PIXELS),"Gait advances with traveled distance rather than synchronizing every worker")
		test.check(ants[0].gait!=ants[1].gait,"Opposing representatives have independent walk phases")
	test.check(min_speed>33 and max_speed<39,"Constant screen travel replaces curved-path acceleration and entrance stopping")
	test.check(routes==frozen,"Motion and arc lookup never change approved route data")
	test.check(Scent.sample(path,0).position==path.points[0] and Scent.sample(path,path.length).position==path.points[-1],"Distance lookup retains exact visual endpoints")
	routes[0].pheromone_strength=0
	test.check(Scent.representatives(routes,placed,size,1).is_empty(),"Familiarity alone cannot invent luminous moving workers")
	var image: Image=Art.WORKER.get_image()
	test.check(image.get_size()==Vector2i(Art.WALK_CELL*Art.WALK_COLUMNS,Art.WALK_CELL*3),"Production atlas contains all 24 distinct walk cells")
	var first: PackedByteArray=image.get_region(Rect2i(0,0,Art.WALK_CELL,Art.WALK_CELL)).get_data()
	var second: PackedByteArray=image.get_region(Rect2i(Art.WALK_CELL*3,0,Art.WALK_CELL,Art.WALK_CELL)).get_data()
	test.check(first!=second,"Walking and antenna poses produce actual changing texture content")
	return true
