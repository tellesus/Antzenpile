extends RefCounted
const Fixture=preload("res://tests/test_parent_supply.gd")
const Root=preload("res://src/core/game_root.gd")
const Inward=preload("res://src/presentation/inward/inward_view.gd")
const Outward=preload("res://src/presentation/outward/outward_view.gd")
const Pressure=preload("res://src/presentation/colony_pressure.gd")

func run(test: Object) -> bool:
 var colony:=Root.new();test.get_root().add_child(colony);colony.set_process(false)
 test.check(colony.outward_status("home").daughter_attention.is_empty(),"No daughter means no orphan attention")
 colony.simulation=Fixture.new().fixture()
 var home: PileState=colony.simulation.run.colony.piles.home
 var daughter: PileState=colony.simulation.run.colony.piles.satellite_1
 var inward:=Inward.new();colony.add_child(inward);colony._inward_view=inward
 inward.status_provider=colony.focused_inward_status;inward.pile_command=colony.inspect_pile;inward.pressure_command=colony.inspect_internal_pressure
 var outward:=Outward.new();colony.add_child(outward);colony._outward_view=outward
 outward.status_provider=colony.outward_status.bind("home");outward.signal_provider=colony.sensory_snapshot.bind("home");outward.pressure_command=colony.inspect_internal_pressure
 colony.simulation.toggle_pause()
 test.check(colony.outward_status("home").daughter_attention.is_empty(),"Steady daughter has no pressure badge")
 daughter.nursery_state="developed";daughter.humidity.moisture=350000
 var before: Dictionary=colony.simulation.run.to_dict()
 var known: Dictionary=colony.outward_status("home").daughter_attention
 test.check(known.pile_id=="satellite_1" and known.organ=="nursery" and known.title=="CHECK DAUGHTER NURSERY" and known.causes==["DRY"],"Known daughter climate is separately named at Home")
 known.causes.append("forged");test.check(colony.outward_status("home").daughter_attention.causes==["DRY"] and before==colony.simulation.run.to_dict(),"Attention is detached and never mutates gameplay")
 outward._process(0);outward.facing=1.8;outward.selected_id="retained"
 var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=outward._button_rect("daughter_pressure").get_center()
 outward._unhandled_input(touch)
 test.check(colony.mode=="inward" and colony.inward_pile_id=="satellite_1" and inward.selected_id=="nursery","Touch voluntarily opens the daughter function")
 test.check(before==colony.simulation.run.to_dict() and outward.facing==0 and outward.selected_id.is_empty(),"Paused navigation preserves clock/RNG/labor/resources and resets obsolete outward attention")
 colony.inspect_outward_pile("home");home.humidity.moisture=350000;outward._process(0)
 test.check(not outward._status.internal_attention.is_empty() and not outward._status.daughter_attention.is_empty() and not outward._button_rect("internal_pressure").intersects(outward._button_rect("daughter_pressure")),"Home and daughter pressure have distinct usable targets")
 outward.sources_open=true
 test.check(outward._button_at(outward._button_rect("daughter_pressure").get_center())!="daughter_pressure","Source browser shields an underlying daughter badge")
 outward.sources_open=false;outward.exploration_open=true
 test.check(outward._button_at(outward._button_rect("daughter_pressure").get_center())!="daughter_pressure","Exploration attention shields the extra pressure badge")
 outward.exploration_open=false
 colony.inspect_pile("home");inward._process(0);before=colony.simulation.run.to_dict()
 var mouse:=InputEventMouseButton.new();mouse.pressed=true;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=inward._pile_rect().get_center()
 inward._unhandled_input(mouse)
 test.check(colony.inward_pile_id=="satellite_1" and inward.selected_id=="nursery" and before==colony.simulation.run.to_dict(),"Home INWARD switch names and opens daughter strain through mouse")
 inward._process(0)
 test.check(inward._status.other_pile_attention.pile_id=="home","While attending daughter, Home pressure remains reachable")
 daughter.humidity.moisture=650000;home.humidity.moisture=650000
 colony.inspect_outward_pile("home");outward._status.daughter_attention={"organ":"nursery"}
 before=colony.simulation.run.to_dict();touch.position=outward._button_rect("daughter_pressure").get_center();outward._unhandled_input(touch)
 test.check(colony.mode=="outward" and colony.inward_pile_id=="home" and before==colony.simulation.run.to_dict(),"Stale daughter badge revalidates recovery before moving attention")
 outward._process(0);test.check(outward._status.daughter_attention.is_empty(),"Recovered daughter removes its warning")
 daughter.resources.carbohydrate=0;daughter.brood_intent="grow"
 known=colony.pile_internal_attention("satellite_1")
 test.check(known.organ=="queen" and known.causes==["GROW WAITING · CARB RESERVE"],"Conservative Grow reserve wait is distinguished from failed larval feeding")
 test.check(colony.inspect_internal_pressure("satellite_1").accepted and inward.selected_id=="queen","Reserve wait opens its existing Queen intent and reserve details")
 daughter.brood_intent="manual";test.check(colony.pile_internal_attention("satellite_1").is_empty(),"Manual laying has no invented growth-reserve alarm")
 colony.simulation.set_daughter_supply(true);colony.simulation.run.supply.phase="outbound"
 known=colony.pile_internal_attention("satellite_1");colony.simulation.run.supply.phase="returning"
 test.check(known==colony.pile_internal_attention("satellite_1"),"Private supply direction cannot create an internal attention forecast")
 colony.simulation.run.world.nodes.values()[0].quantity=0
 test.check(known==colony.pile_internal_attention("satellite_1"),"Hidden resource depletion cannot change daughter pressure")
 before=colony.simulation.run.to_dict()
 test.check(not colony.inspect_internal_pressure("unknown").accepted and before==colony.simulation.run.to_dict(),"Unknown pile attention rejects without simulation changes")
 test.check(Pressure.attention({"daughter":true,"food_sharing":{"recent":true}}).causes==["DAUGHTER LOSSES · CAUSE UNCERTAIN"],"Local food-sharing evidence cannot blame Home or a particular source")
 colony.free();return true
