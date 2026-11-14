extends RefCounted

var t


func _food_in_world(w: SimWorld) -> float:
	var s := 0.0
	for v in w.food:
		s += v
	return s


func test_food_is_conserved_and_gathered() -> void:
	var w := SimWorld.new(20261113, 200, 200, 300)
	t.check(w.food_total_spawned > 0.0, "map starts with food")
	for i in 1500:
		w.step()
	var total: float = _food_in_world(w) + w.colony.total_carried() + w.colony.food_delivered_total
	t.check(absf(total - w.food_total_spawned) < 0.01,
		"food conserved: %s accounted for, %s spawned" % [total, w.food_total_spawned])
	t.check(w.colony.food_delivered_total > 20.0,
		"colony gathers food unaided, got %s" % w.colony.food_delivered_total)
	t.check(w.colony.count > 300, "colony grows from food, count %d" % w.colony.count)


func test_ants_stay_on_passable_ground() -> void:
	var w := SimWorld.new(5, 120, 120, 150)
	var bad := 0
	for i in 400:
		w.step()
		if i % 50 == 0:
			for a in w.colony.count:
				var x: float = w.colony.ax[a]
				var y: float = w.colony.ay[a]
				if x < 0.0 or y < 0.0 or x >= w.width or y >= w.height:
					bad += 1
				elif w.passable[int(y) * w.width + int(x)] == 0:
					bad += 1
	t.check_eq(bad, 0, "ants off the map or in water")


func test_knowledge_starts_local_and_spreads() -> void:
	var w := SimWorld.new(9, 160, 160, 120)
	var corner: int = w.index_of(Vector2i(2, 2))
	t.check(w.colony.known_tick[corner] < 0.0, "far corner starts unknown")
	t.check(w.colony.known_tick[w.index_of(w.nest_cell)] >= 0.0, "nest starts known")
	var before := 0
	for v in w.colony.known_tick:
		if v >= 0.0:
			before += 1
	for i in 600:
		w.step()
	var after := 0
	for v in w.colony.known_tick:
		if v >= 0.0:
			after += 1
	t.check(after > before * 4, "known area grows: %d to %d cells" % [before, after])


func test_paint_only_takes_on_known_ground() -> void:
	var w := SimWorld.new(9, 160, 160, 20)
	t.check_eq(w.colony.paint(Colony.Scent.ATTRACT, Vector2i(3, 3), 2, 0.5), 0, "unknown ground refuses scent")
	t.check(w.colony.paint(Colony.Scent.ATTRACT, w.nest_cell, 2, 0.5) > 0, "known ground takes scent")
	var i: int = w.index_of(w.nest_cell)
	t.check(w.colony.scents[Colony.Scent.ATTRACT][i] > 0.0, "scent present")
	w.colony.paint(Colony.ERASE, w.nest_cell, 2, 1.0)
	t.check_eq(w.colony.scents[Colony.Scent.ATTRACT][i], 0.0, "erase clears the centre")


func test_scent_fades() -> void:
	var w := SimWorld.new(9, 100, 100, 5)
	w.colony.paint(Colony.Scent.REPEL, w.nest_cell, 1, 1.0)
	var i: int = w.index_of(w.nest_cell)
	var start: float = w.colony.scents[Colony.Scent.REPEL][i]
	for k in 600:
		w.step()
	t.check(w.colony.scents[Colony.Scent.REPEL][i] < start * 0.6, "repel fades over a minute")


func test_attract_pulls_ants() -> void:
	# Same seed twice; one run paints attract well east of the nest.
	var plain := SimWorld.new(31, 140, 140, 200)
	var lured := SimWorld.new(31, 140, 140, 200)
	for i in 250:
		plain.step()
		lured.step()
	var spot := lured.nest_cell + Vector2i(1, 0)
	for d in range(30, 8, -1):   # farthest known passable cell due east
		var c := lured.nest_cell + Vector2i(d, 0)
		if lured.colony.known_tick[lured.index_of(c)] >= 0.0 and lured.passable[lured.index_of(c)] == 1:
			spot = c
			break
	t.check(spot.x - lured.nest_cell.x >= 12, "a known spot at least 12 cells east, got %d" % (spot.x - lured.nest_cell.x))
	for i in 400:
		if i % 20 == 0:
			lured.colony.paint(Colony.Scent.ATTRACT, spot, 4, 1.0)
		plain.step()
		lured.step()
	t.check(_near(lured, spot, 6.0) > _near(plain, spot, 6.0) + 20,
		"attract gathers ants: %d with, %d without" % [_near(lured, spot, 6.0), _near(plain, spot, 6.0)])


func test_alarm_masses_ants() -> void:
	var w := SimWorld.new(31, 140, 140, 200)
	for i in 250:
		w.step()
	var spot := w.nest_cell + Vector2i(0, 1)
	for d in range(30, 8, -1):   # farthest known passable cell due south
		var c := w.nest_cell + Vector2i(0, d)
		if w.colony.known_tick[w.index_of(c)] >= 0.0 and w.passable[w.index_of(c)] == 1:
			spot = c
			break
	var before: int = _near(w, spot, 6.0)
	for i in 400:
		if i % 20 == 0:
			w.colony.paint(Colony.Scent.ALARM, spot, 3, 1.0)
		w.step()
	t.check(_near(w, spot, 6.0) > before + 40,
		"alarm masses ants: %d before, %d after" % [before, _near(w, spot, 6.0)])


func _near(w: SimWorld, cell: Vector2i, radius: float) -> int:
	var n := 0
	var c := Vector2(cell) + Vector2(0.5, 0.5)
	for a in w.colony.count:
		if Vector2(w.colony.ax[a], w.colony.ay[a]).distance_to(c) <= radius:
			n += 1
	return n
