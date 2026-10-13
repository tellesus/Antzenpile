class_name ReportCopy
extends RefCounted
const Copy=preload("res://src/presentation/interface_text.gd")
const Memory=preload("res://src/presentation/outward/source_memory.gd")

static func pile_name(id: String) -> String:
	return "Home" if id=="home" else "Daughter" if id=="satellite_1" else "Nest "+id.trim_prefix("satellite_") if id.begins_with("satellite_") else id.capitalize().replace("_"," ")

static func source_name(entry: Dictionary, status: Dictionary) -> String:
	var knowledge_id: String=entry.subject_id
	if entry.kind!="source":
		for route: Dictionary in status.get("trails",[]):
			if route.id==entry.subject_id: knowledge_id=route.destination_knowledge_id;break
	var memory: Dictionary=status.get("sources",{}).get(knowledge_id,{"category":"unknown"}).duplicate()
	if entry.kind=="source":
		memory.site_profile=entry.detail.trim_prefix("site:") if entry.detail.begins_with("site:") else ""
		memory.source_type="" if entry.detail.begins_with("site:") else entry.detail
	return Memory.display_name(memory)

static func title(entry: Dictionary, status: Dictionary) -> String:
	var name: String=source_name(entry,status)
	var text: String="Report"
	match entry.kind:
		"source": text="Source report: "+name+(" · EMPTY" if entry.amount==0 else "")
		"intake": text=Copy.resource(entry.detail).capitalize()+" returned: "+name
		"loss": text="Journey losses reported: "+name
		"ground":text="Strange residue on the journey: "+name
		"conflict": text={"contested":"Junction contested","holding":"Junction holding","resisted":"Strong foreign resistance","reinforced":"Foreign reinforcement reported","secured":"Foreign force withdrew","withdrew":"Our ants withdrew","dispersed":"Encounter dispersed"}.get(entry.detail,"Junction report")
		"survey": text=Memory.survey_label({"finding":entry.detail.get_slice(":",0),"predator_profile":entry.detail.get_slice(":",1)})
		"pressure": text="Holding against resistance" if entry.detail=="holding" else "Resistance remains strong"
		"defense": text=Memory.defense_label({"goal":entry.detail.get_slice(":",0),"outcome":entry.detail.get_slice(":",1)})
		"approach": text={"found":"Alternate course established","danger":"Danger on alternate course","unconfirmed":"Alternate course unconfirmed"}.get(entry.detail,"Approach returned")
		"brood": text="%d workers emerged" % entry.amount if entry.detail=="emerged" else "%d brood losses observed" % entry.amount
		"trait": text="Inherited trait established: "+TraitCatalog.DEFINITIONS[entry.subject_id].title
		"project": text="Reproductives ready" if entry.subject_id=="queen" else entry.subject_id.capitalize().replace("_"," ")+" "+entry.detail
		"camp": text="Founding camp "+entry.detail
		"brood_rescue": text="%d live brood delivered to %s" % [entry.amount,pile_name(entry.subject_id)] if entry.detail=="delivered" else "Brood party returned · recipient unsuitable" if entry.detail=="landing" else "Brood party returned · carers could not settle" if entry.detail=="escorts" else "Original brood returned home"
		"relocation": text="Queen delivered to %s · %d escorts settled" % [pile_name(entry.subject_id),entry.amount] if entry.detail=="delivered" else "Queen returned · recipient became unsuitable" if entry.detail=="landing" else "Queen returned · escorts could not settle" if entry.detail=="escorts" else "Queen party returned home · no relocation"
		"migration": text="Messenger returned: %d workers settled at %s" % [entry.amount,pile_name(entry.subject_id)]
		"departure": text="Final departure to %s · %d workers · nest relinquished" % [pile_name(entry.subject_id),entry.amount]
		"evacuation": text="%d evacuated workers arrived from %s" % [entry.amount,pile_name(entry.subject_id)] if entry.detail=="arrived" else "Final party physically returned · original nest active again"
		"producer": text="Attendant target: %d · gathering and defense remain separate" % entry.amount if entry.detail=="target" else "Attendants returned · remembered producer was unsuitable" if entry.detail=="not_found" else "Attendant party returned to the nest"
		"connection": text="Connection closed to new traffic · paid trips continue" if entry.detail=="closed" else "Connection reopened · place a new order"
		"royal_rescue": text="Young queen and males delivered to "+pile_name(entry.subject_id) if entry.detail=="delivered" else "Young queen party returned · recipient unsuitable" if entry.detail=="landing" else "Young queen party returned · nurses could not settle" if entry.detail=="escorts" else "Original young queen and males returned home"
		"store_rescue": text="%d %s %s" % [entry.amount,entry.detail.get_slice(":",1),"delivered to "+pile_name(entry.subject_id) if entry.detail.begins_with("delivered:") else "returned home · travel food spent"]
		"supplies": text="Supplies returned from trip to "+pile_name(entry.subject_id)
		"dispatch": text="%d ants dispatched: %s" % [entry.amount,"survey" if entry.detail=="investigate" else "defense"]
		"order": text="Force order: %d total" % entry.amount if entry.amount>0 else "Force order canceled"
		"gathering": text="Gathering target: %d total" % entry.amount if entry.amount>0 else "Gathering stopped · travelers return"
		"investment": text={"none":"No special investment pending","adaptation":"Adaptation next · %d queued" % entry.amount,"reproduction":"Reproduction next · %d queued" % entry.amount,"adaptation_laid":"Paid adaptation brood laid","reproduction_laid":"Paid reproductive brood laid"}.get(entry.detail,"Investment updated")
		"queen": text="Queen "+entry.detail+" · generation %d" % entry.amount
		"chamber": text=ChamberCatalog.DEFINITIONS[entry.subject_id].display_name+" · "+entry.detail
	return pile_name(entry.pile_id)+" · "+text

static func detail(entry: Dictionary, time: float) -> String:
	var text: String="Seen %s ago · arrived %s ago" % [Copy.duration(time-entry.observed_at),Copy.duration(time-entry.received_at)]
	if entry.kind=="intake": text="%d recorded returns · %.1f total · %s ago" % [entry.repeats,entry.total,Copy.duration(time-entry.received_at)]
	elif entry.kind=="loss": text="%d new · %d reported total · %s ago" % [entry.amount,entry.total,Copy.duration(time-entry.received_at)]
	elif entry.kind=="defense": text="%d returned / %d sent · %s ago" % [entry.total-entry.amount,entry.total,Copy.duration(time-entry.received_at)]
	return text
