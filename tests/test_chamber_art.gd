extends RefCounted
const Chambers = preload("res://src/presentation/inward/chamber_art.gd")
const View = preload("res://src/presentation/inward/inward_view.gd")
const Activity = preload("res://src/presentation/inward/colony_activity.gd")

func run(test: Object) -> bool:
	var status: Dictionary = {"nursery_state":"primitive","nursery_build_duration":120.0,"nursery_progress":0.0,
		"nursery_expansion":{"state":"latent"},"food_exchange_state":"primitive","midden":{"revealed":false}}
	var initial: Dictionary = status.duplicate(true)
	var primitive: Vector2 = Chambers.extent(status,"nursery")
	test.check(Chambers.maturity(status,"nursery") == 0.0 and Chambers.lobe_gain(status) == 0.0,"Primitive/latent Nursery has no developed capacity lobe")
	status.nursery_state = "developing"
	status.nursery_progress = 60.0
	var growing: Vector2 = Chambers.extent(status,"nursery")
	test.check(Chambers.maturity(status,"nursery") == 0.5 and growing.x > primitive.x,"Known construction progressively grows chamber art")
	status.nursery_state = "developed"
	var developed: Vector2 = Chambers.extent(status,"nursery")
	test.check(developed.x > growing.x and not Chambers.expanded(status),"Developed chamber does not imply expanded capacity")
	status.nursery_expansion = {"state":"developing","progress_seconds":90.0,"duration":180.0}
	test.check(Chambers.lobe_gain(status) == 0.5 and Chambers.extent(status,"nursery") == developed,"Expansion builds a separate lobe without shrinking the active Nursery")
	status.nursery_expansion.state = "developed"
	test.check(Chambers.expanded(status) and Chambers.lobe_gain(status) == 1.0,"Completed expansion retains the additional organ lobe")
	var copied: Dictionary = status.duplicate(true)
	Chambers.extent(status,"food_exchange")
	Chambers.maturity(status,"midden")
	test.check(status == copied and initial.nursery_state == "primitive","Art evaluation cannot mutate approved state or earlier summaries")
	test.check(Activity.brood_stages({}).is_empty() and Activity.jobs({}).is_empty(),"Empty organs invent no brood or working ants")
	for size: Vector2 in [Vector2(1280,720),Vector2(900,600)]:
		var centers: Dictionary = View.positions(size)
		test.check(View.node_at(centers.nursery+Chambers.lobe_offset()+Vector2(45,24),size,false,false,true) == "nursery" and View.node_at(centers.nursery+Chambers.lobe_offset()+Vector2(45,24),size) == "","Only visible Nursery extensions add a selectable lobe")
		for id: String in View.NODES:
			test.check(View.node_at(centers[id]+Vector2(48,0),size) == id,"Visible chamber edges remain selectable: "+id)
		test.check(View.node_at(centers.midden,size) == "" and View.node_at(centers.guest,size) == "","Unrevealed conditional functions retain no input target")
		test.check(View.node_at(centers.midden,size,false,true) == "midden" and View.node_at(centers.guest,size,true,false) == "guest","Observed local functions acquire their own input targets")
	return true
