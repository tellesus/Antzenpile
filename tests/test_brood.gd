extends RefCounted

const Controller = preload("res://src/core/simulation_controller.gd")
const Config = preload("res://data/resources/default_brood.tres")


func run(test: Object) -> bool:
	var game := Controller.new()
	var pile: PileState = game.run.colony.piles.home
	test.check(pile.brood_cohorts.size() == 1 and pile.brood_cohorts[0].count == 8 and pile.workers_total == 40, "Eight starting immature ants are outside the living-worker ledger")
	test.check(pile.deposit_resource("carbohydrate", 10.0), "Supported brood fixture gets enough food")
	game.advance(Config.egg_seconds)
	test.check(pile.brood_cohorts[0].stage == "larva" and pile.workers_total == 40, "Egg stage advances on simulated time without birth")
	game.advance(Config.larva_seconds)
	test.check(pile.brood_cohorts[0].stage == "pupa" and is_equal_approx(pile.resources.carbohydrate, 5.6) and is_equal_approx(pile.resources.protein, 0.68) and is_equal_approx(pile.resources.water, 2.8), "Larval food costs are accounted once per tick across all three pools")
	game.advance(Config.pupa_seconds)
	test.check(pile.brood_cohorts.is_empty() and pile.brood_matured_total == 8 and pile.workers_total == 48 and pile.workers_available == 48 and pile.workers.invariant_holds(), "Emergence removes brood and adds living workers through ledger exactly once")
	game.advance(100.0)
	test.check(pile.workers_total == 48 and pile.brood_matured_total == 8, "Repeated updates cannot duplicate emergence")
	var shortage := Controller.new()
	var short_pile: PileState = shortage.run.colony.piles.home
	shortage.advance(Config.egg_seconds + Config.larva_seconds)
	test.check(short_pile.brood_cohorts[0].stage == "larva" and short_pile.brood_cohorts[0].progress_seconds < Config.larva_seconds and short_pile.brood_cohorts[0].nutrition == 0.0 and short_pile.workers_total == 40, "Starting reserves run short and pause larval growth without loss")
	var stalled_resources: Dictionary = short_pile.resources.duplicate()
	var stalled_progress: float = short_pile.brood_cohorts[0].progress_seconds
	shortage.advance(10.0)
	test.check(short_pile.resources == stalled_resources and short_pile.brood_cohorts[0].progress_seconds == stalled_progress, "Shortage neither drains other pools nor advances progress")
	test.check(short_pile.deposit_resource("carbohydrate", 5.0), "Later foraging can resume stalled brood")
	shortage.advance(120.0)
	test.check(short_pile.brood_cohorts.is_empty() and short_pile.workers_total == 48 and short_pile.workers.invariant_holds(), "Nutrition resumption eventually matures the same cohort")
	var care := Controller.new()
	var care_pile: PileState = care.run.colony.piles.home
	test.check(care_pile.workers.create_commitment("test:busy", "other", "test") and care_pile.workers.allocate("test:busy", 39), "Care fixture leaves one available worker")
	care.advance(200.0)
	test.check(care_pile.brood_cohorts[0].stage == "egg" and care_pile.brood_cohorts[0].progress_seconds == 0.0 and care_pile.brood_cohorts[0].care == 0.5, "Low available care stalls egg development without inventing worker transfers")
	test.check(care_pile.workers.release("test:busy", 38), "Care capacity becomes available through ledger release")
	care.advance(Config.egg_seconds)
	test.check(care_pile.brood_cohorts[0].stage == "larva", "Restored care resumes stage progress")
	var continued := Controller.new()
	continued.run.colony.piles.home.deposit_resource("carbohydrate", 10.0)
	continued.advance(223.5)
	var saved: Dictionary = continued.run.to_dict()
	var restored := Controller.new()
	var restored_ok: bool = restored.run.restore(JSON.parse_string(JSON.stringify(saved, "", true, true)))
	test.check(saved.version == 4 and restored_ok and restored.run.to_dict() == saved, "Current mid-larva JSON round trip preserves food and progress")
	for index: int in 120:
		continued.advance(0.25)
		restored.advance(0.25)
		test.check(continued.run.to_dict() == restored.run.to_dict(), "Brood continuation matches tick %d" % index)
	var before: Dictionary = restored.run.to_dict()
	for mutation: String in ["bad_count", "bad_stage", "bad_progress", "bad_total", "old_version"]:
		var invalid: Dictionary = saved.duplicate(true)
		match mutation:
			"bad_count": invalid.colony.piles[0].brood_cohorts[0].count = 7
			"bad_stage": invalid.colony.piles[0].brood_cohorts[0].stage = "adult"
			"bad_progress": invalid.colony.piles[0].brood_cohorts[0].progress_seconds = 999.0
			"bad_total": invalid.colony.piles[0].brood_matured_total = 8
			"old_version": invalid.version = 1
		test.check(not restored.run.restore(invalid) and restored.run.to_dict() == before, "Malformed brood snapshot rejects atomically: " + mutation)
	return true
