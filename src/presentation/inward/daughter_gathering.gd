class_name DaughterGathering
extends RefCounted
## Disposable attention to shared memories, with daughter-owned receipt/labor facts.
const Copy=preload("res://src/presentation/interface_text.gd")
const Memory=preload("res://src/presentation/outward/source_memory.gd")
const Style=preload("res://src/presentation/organic_ui.gd")
const CATEGORIES: Array[String]=["carbohydrate","protein","water"]
var opened: bool=false
var category: String="carbohydrate"
var page: int=0
var selected: String=""
var draft:=preload("res://src/presentation/gathering_draft.gd").new()

func reset() -> void:
 opened=false;category="carbohydrate";page=0;selected="";draft.opened=false

func panel(size: Vector2) -> Rect2:
 return Rect2(size.x-316,144,292,456)

func rect(size: Vector2, action: String, index: int=0) -> Rect2:
 var x: float=size.x-300
 match action:
  "filter": return Rect2(x+index*88,206,84,44)
  "row": return Rect2(x,258+index*58,260,54)
  "page": return Rect2(x,374,260,44)
  "order": return Rect2(x,430,156,44)
  "stop": return Rect2(x+164,430,96,44)
  "scout": return Rect2(x,482,260,44)
  "back": return Rect2(x,538,260,44)
 return Rect2()

func entries(status: Dictionary) -> Array:
 return status.get("sources",{}).get(category,[])

func selected_entry(status: Dictionary) -> Dictionary:
 for entry: Dictionary in entries(status):
  if entry.knowledge_id==selected: return entry
 return {}

func activate(view: Node2D, at: Vector2, status: Dictionary, command: Callable) -> bool:
 var size: Vector2=view.get_viewport_rect().size
 if not opened or not panel(size).has_point(at): return false
 if draft.opened:
  var control: String=draft.command_at(at,size)
  if control=="gather_commit" and command.is_valid():
   var result: Dictionary=command.call(draft.source,"order_%d" % draft.amount)
   view.activation.outcome(result)
   if result.get("accepted",false): draft.opened=false
   view.show_feedback("Gathering order accepted · unsent ants wait" if result.get("accepted",false) else result.get("reason","Order unavailable"))
  else: draft.edit(control)
  return true
 if rect(size,"back").has_point(at): opened=false;return true
 for index: int in CATEGORIES.size():
  if rect(size,"filter",index).has_point(at): category=CATEGORIES[index];page=0;selected="";return true
 var list: Array=entries(status);var pages: int=maxi(1,ceili(list.size()/2.0))
 page=mini(page,pages-1)
 if rect(size,"page").has_point(at): page=(page+1)%pages;selected="";return true
 for index: int in 2:
  if page*2+index<list.size() and rect(size,"row",index).has_point(at): selected=list[page*2+index].knowledge_id;return true
 var entry: Dictionary=selected_entry(status)
 if entry.is_empty(): return true
 var action: String=""
 if rect(size,"stop").has_point(at) and not entry.route_id.is_empty() and (entry.workers>0 or entry.desired_workers>0): action="stop"
 elif rect(size,"scout").has_point(at): action="recall_scout" if entry.get("scout",{}).get("awaiting",false) else "scout"
 elif rect(size,"order").has_point(at):
  if order(entry)=="recheck": action="recheck"
  else:
   draft.begin(entry.knowledge_id,int(entry.desired_workers),int(status.get("workforce",1)));return true
 if not action.is_empty() and command.is_valid():
  var result: Dictionary=command.call(entry.knowledge_id,action)
  view.activation.outcome(result)
  var titles: Dictionary={"gather":"Daughter gatherers assigned","add":"Daughter gatherers added","stop":"Daughter gatherers recalled","recheck":"Local trail recheck started","scout":"Local scout dispatched · await return","recall_scout":"Scout return requested"}
  view.show_feedback(titles[action] if result.get("accepted",false) else result.get("reason","Gathering unavailable"))
 return true

func order(entry: Dictionary) -> String:
 return "recheck" if entry.route_status=="depleted" else "gather" if entry.route_status in ["none","inactive","recalling"] else "add"

func draw(view: Node2D, status: Dictionary) -> void:
 var size: Vector2=view.get_viewport_rect().size
 if draft.opened:
  var entry: Dictionary=selected_entry(status)
  draft.draw(view,size,Memory.display_name(entry),int(entry.get("workers",0)),int(status.get("available_workers",0)));return
 var box: Rect2=panel(size)
 Style.surface(view,box,Color("111921"));Style.surface(view,box,Color("41535a"),true)
 view._label(box.position+Vector2(16,31),"Daughter Gathering",Color("d9d3be"),20)
 view._label(box.position+Vector2(16,51),"Shared memories · availability uncertain",Color("a7b5b1"),12)
 for index: int in CATEGORIES.size():
  var at: Rect2=rect(size,"filter",index)
  Style.surface(view,at,Color("355059") if category==CATEGORIES[index] else Color("263038"))
  view._label(at.get_center()+Vector2(0,5),"CARBS" if index==0 else CATEGORIES[index].to_upper(),Color("dce5d9"),12,HORIZONTAL_ALIGNMENT_CENTER)
 var list: Array=entries(status);var pages: int=maxi(1,ceili(list.size()/2.0))
 page=mini(page,pages-1)
 for index: int in 2:
  if page*2+index>=list.size(): continue
  var entry: Dictionary=list[page*2+index];var at: Rect2=rect(size,"row",index)
  Style.surface(view,at,Color("355059") if selected==entry.knowledge_id else Color("263038"))
  view._label(at.position+Vector2(8,17),Memory.display_name(entry)+(" · ALARM" if entry.danger else ""),Color("dce5d9"),14)
  view._label(at.position+Vector2(8,33),Copy.fit_line("%s · %s ago · %d workers" % [entry.state,Copy.duration(entry.age),entry.workers],ThemeDB.fallback_font,11,244),Color("a7b5b1"),11)
  view._label(at.position+Vector2(8,48),Copy.fit_line(Memory.receipt_label(entry,status.get("time",0),"here"),ThemeDB.fallback_font,11,244),Color("a7b5b1"),11)
 if list.is_empty(): view._label(box.position+Vector2(16,135),"No returned " + Copy.resource(category)+" memories",Color("a7b5b1"),14)
 var at: Rect2=rect(size,"page");Style.surface(view,at,Color("263038"))
 view._label(at.get_center()+Vector2(0,5),"PAGE %d / %d · NEXT" % [page+1,pages],Color("dce5d9"),12,HORIZONTAL_ALIGNMENT_CENTER)
 var chosen: Dictionary=selected_entry(status)
 if not chosen.is_empty():
  at=rect(size,"order");Style.surface(view,at,Color("39302b"))
  var action: String=order(chosen);var count: int=status.get("workers",5)
  var title: String="RECHECK" if action=="recheck" else "CHOOSE WORKERS"
  view._label(at.get_center()+Vector2(0,-3),title,Color("e0c5b7"),12,HORIZONTAL_ALIGNMENT_CENTER)
  view._label(at.get_center()+Vector2(0,15),"Daughter + travel carbs" if action!="recheck" else "Same local gatherers",Color("c5b8b1"),11,HORIZONTAL_ALIGNMENT_CENTER)
  if chosen.workers>0 or chosen.desired_workers>0:
   at=rect(size,"stop");Style.surface(view,at,Color("39302b"))
   view._label(at.get_center()+Vector2(0,5),"RECALL",Color("e0c5b7"),12,HORIZONTAL_ALIGNMENT_CENTER)
  var scout: Dictionary=chosen.get("scout",{});var awaiting: bool=scout.get("awaiting",false)
  at=rect(size,"scout");Style.surface(view,at,Color("26383a"))
  view._label(at.get_center()+Vector2(0,-3),"RECALL LOCAL SCOUT" if awaiting else "SEND 1 LOCAL SCOUT",Color("dce5d9"),12,HORIZONTAL_ALIGNMENT_CENTER)
  var detail: String="1 daughter worker · shared scout cap"
  if awaiting: detail=("Overdue" if scout.overdue else "Awaiting") + " · away " + Copy.duration(scout.away_seconds)
  elif scout.get("missing_at",-1)>=0: detail="Did not return · cause unknown"
  elif scout.get("returned_at",-1)>=0: detail="Scout returned " + Copy.duration(status.get("time",0)-scout.returned_at) + " ago"
  view._label(at.get_center()+Vector2(0,15),detail,Color("a7b5b1"),11,HORIZONTAL_ALIGNMENT_CENTER)
 at=rect(size,"back");Style.surface(view,at,Color("263038"))
 view._label(at.get_center()+Vector2(0,5),"BACK TO FOOD EXCHANGE",Color("dce5d9"),12,HORIZONTAL_ALIGNMENT_CENTER)
