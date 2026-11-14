extends RefCounted

var t  # the runner; provides check() and check_eq()


func test_same_seed_gives_same_world() -> void:
	var a := SimWorld.new(42, 100, 100, 80)
	var b := SimWorld.new(42, 100, 100, 80)
	t.check_eq(a.state_hash(), b.state_hash(), "same seed")
	for i in 300:
		if i == 50:
			a.colony.paint(Colony.Scent.ATTRACT, a.nest_cell + Vector2i(3, 0), 3, 0.5)
			b.colony.paint(Colony.Scent.ATTRACT, b.nest_cell + Vector2i(3, 0), 3, 0.5)
		a.step()
		b.step()
	t.check_eq(a.state_hash(), b.state_hash(), "same seed and commands after 300 ticks")


func test_different_seed_gives_different_world() -> void:
	t.check(SimWorld.new(1, 80, 80, 10).terrain != SimWorld.new(2, 80, 80, 10).terrain, "seeds 1 and 2 differ")


func test_step_advances_tick() -> void:
	var w := SimWorld.new(7, 60, 60, 10)
	w.step()
	w.step()
	t.check_eq(w.tick, 2, "tick count")


func test_grid_shape_and_nest() -> void:
	var w := SimWorld.new(7, 120, 80, 10)
	t.check_eq(w.terrain.size(), 120 * 80, "terrain size")
	t.check(w.in_bounds(w.nest_cell), "nest in bounds")
	t.check_eq(w.terrain_at(w.nest_cell), SimWorld.Terrain.SOIL, "nest on soil")
	t.check(not w.in_bounds(Vector2i(120, 0)), "x edge out of bounds")
	t.check_eq(w.nest_dist[w.index_of(w.nest_cell)], 0.0, "nest distance is zero")


func test_map_has_varied_terrain() -> void:
	var w := SimWorld.new(20261113, 200, 200, 10)
	var seen := {}
	for v in w.terrain:
		seen[v] = true
	t.check(seen.size() >= 3, "at least three terrain types, got %d" % seen.size())
