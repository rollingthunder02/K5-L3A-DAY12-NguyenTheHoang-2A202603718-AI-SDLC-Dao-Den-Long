"""Black-box scenarios for Ticket-02 and Test Contract 1.1."""

import math
import time
import unittest

from verify_phase1 import CONTRACT, EMPTY, HeadlessCase, events, snapshots


def horizontal(a, b=(0, 0, 0)):
    return math.hypot(a[0] - b[0], a[2] - b[2])


class Ticket02Tests(HeadlessCase):
    def test_nights_maps_and_initial_stock(self):
        self.assertEqual(CONTRACT["contract_version"], "1.2")
        maps = [
            [[0, 0, 25], [23.8, 0, 7.7], [14.7, 0, -20.2], [-14.7, 0, -20.2], [-23.8, 0, 7.7]],
            [[0, 0, 20], [17, 0, -10], [-17, 0, -10], [70, 0, 20], [87, 0, -10], [53, 0, -10]],
            [[0, 6, 6], [18, 3, 10], [-18, 3, 10], [35, 0, -10], [-35, 0, -10], [20, 0, -35], [-20, 0, -35]],
        ]
        for night, expected in enumerate(maps, start=1):
            with self.subTest(night=night):
                records, _ = self.simulate(night=night, ticks=0)
                first = records[0]
                self.assertEqual(first["night"], night)
                self.assertEqual(first["time_left_s"], 210 + 30 * night)
                self.assertEqual([lamp["pos"] for lamp in first["lanterns"]], expected)
                self.assertEqual(len(first["motes"]), 20)
                self.assertEqual(len({tuple(m["pos"]) for m in first["motes"]}), 20)
                self.assertTrue(all(m["kind"] == "random" and m["ttl_s"] is None for m in first["motes"]))
                self.assertEqual(first["player"]["vel"], [0, 0, 0])
                self.assertTrue(first["player"]["grounded"])
                self.assertEqual(len(first["charms"]), night - 1)
                for mote in first["motes"]:
                    point = mote["pos"]
                    if night == 1:
                        self.assertIn(round(horizontal(point)), [12, 33])
                    elif night == 2:
                        self.assertIn(round(horizontal(point, (0 if point[0] < 35 else 70, 0, 0))), [10, 22])
                    else:
                        self.assertEqual(round(horizontal(point)), {0: 34, 3: 18, 6: 5}[point[1]])

    def test_spawn_timing_caps_and_seeded_ids(self):
        scenario = {"player": {"invuln_ticks": 10000}, "wind_enabled": False}
        for night, period, cap, stock in [(1, 480, 6, 24), (2, 420, 8, 24), (3, 360, 10, 30)]:
            with self.subTest(night=night):
                records, _ = self.simulate(night=night, scenario=scenario, ticks=4200, interval=60)
                samples = snapshots(records)
                self.assertEqual(samples[180]["motes_active"], 20)
                self.assertEqual(samples[240]["motes_active"], 21)
                self.assertEqual(samples[4200]["motes_active"], stock)
                born = events(records, "shade_spawned")
                self.assertEqual([item["tick"] for item in born[:3]], [300, 300, 300 + period])
                self.assertEqual(len(born), cap)
                self.assertEqual([s["id"] for s in samples[300]["shades"]], ["S1", "S2"])
                for shade in samples[300]["shades"]:
                    self.assertEqual(shade["state"], "spawning")
                    self.assertGreaterEqual(horizontal(shade["pos"]), 15)
                self.assertEqual(len(samples[1140]["drifters"]), 0)
                self.assertEqual(len(samples[1200]["drifters"]), 0 if night == 1 else 1)
                self.assertEqual(len(samples[2400]["drifters"]), 0 if night == 1 else 2)

    def test_dash_duration_direction_cooldown_and_air_height(self):
        frames = [{"tick": 0, "dash": True}, {"tick": 1, "dash": False},
                  {"tick": 20, "dash": True}, {"tick": 21, "dash": False}, {"tick": 90, "dash": True}]
        records, _ = self.simulate(scenario=EMPTY, frames=frames, ticks=110)
        self.assertEqual([e["tick"] for e in events(records, "dash")], [1, 91])
        samples = snapshots(records)
        self.assertEqual(samples[1]["player"]["vel"], [0, 0, 14])
        self.assertEqual(samples[12]["player"]["pos"], [0, 0, 2.8])
        self.assertEqual(samples[13]["player"]["vel"], [0, 0, 0])
        frames = [{"tick": 0, "jump": True}, {"tick": 6, "dash": True, "move": [1, 0]}]
        records, _ = self.simulate(scenario=EMPTY, frames=frames, ticks=25)
        samples = snapshots(records)
        height = samples[6]["player"]["pos"][1]
        self.assertTrue(all(samples[t]["player"]["pos"][1] == height for t in range(7, 19)))
        self.assertEqual(samples[18]["player"]["pos"][0], 2.8)
        self.assertGreater(samples[19]["player"]["pos"][1], height)
        scenario = {**EMPTY, "shades": [{"pos": [0, 0, 0.5]}]}
        records, _ = self.simulate(scenario=scenario, frames=[{"tick": 0, "dash": True}], ticks=1)
        self.assertEqual(events(records, "player_hit")[0]["data"]["flames"], 2)

    def test_pause_freezes_time_cooldowns_spawn_ttl_and_movement(self):
        scenario = {**EMPTY, "player": {"dash_cd_ticks": 50, "pulse_cd_ticks": 60, "charm_ticks": 200},
                    "motes": [{"pos": [9, 0, 9], "kind": "dropped", "ttl_ticks": 4}]}
        frames = [{"tick": 0, "move": [1, 0]}, {"tick": 3, "pause": True}, {"tick": 6, "pause": False},
                  {"tick": 7, "pause": True}]
        records, _ = self.simulate(scenario=scenario, frames=frames, ticks=8)
        samples = snapshots(records)
        for tick in range(4, 8):
            self.assertEqual(samples[tick]["sim_tick"], 3)
            self.assertEqual(samples[tick]["state"], "paused")
            for label in ["player", "time_left_s", "motes"]:
                self.assertEqual(samples[tick][label], samples[3][label])
        self.assertEqual(samples[8]["sim_tick"], 4)
        self.assertEqual(samples[8]["motes"], [])
        self.assertEqual([events(records, name)[0]["tick"] for name in ["paused", "resumed"]], [4, 8])
        records, _ = self.simulate(scenario=EMPTY, frames=frames[:2], ticks=1000, interval=100)
        self.assertEqual(records[-1]["state"], "paused")
        self.assertEqual(snapshots(records)[1000]["sim_tick"], 3)

    def test_fall_bypasses_invulnerability_and_waits_to_respawn(self):
        base = {**EMPTY, "player": {"pos": [41, -9.95, 0], "vel": [0, -5, 0],
                                  "carried": 7, "invuln_ticks": 200}, "motes": [[0, 0, 0]]}
        records, _ = self.simulate(scenario=base, ticks=62)
        hit, = events(records, "player_hit")
        self.assertEqual(hit["tick"], 1)
        self.assertEqual(hit["data"], {"by": "fall", "flames": 2, "dropped": 0, "lost": 7})
        samples = snapshots(records)
        self.assertLess(samples[60]["player"]["pos"][1], -10)
        self.assertEqual(samples[61]["player"]["pos"], [0, 0, 0])
        self.assertEqual(samples[61]["player"]["vel"], [0, 0, 0])
        self.assertTrue(samples[61]["player"]["invuln"])
        self.assertEqual(events(records, "mote_picked")[0]["tick"], 62)
        base["player"]["flames"] = 1
        base["time_left_s"] = 1 / 60
        base["lanterns"] = [{"id": f"L{i}", "lit": True} for i in range(1, 6)]
        records, _ = self.simulate(scenario=base, ticks=300)
        self.assertEqual(records[-1]["ticks"], 1)
        self.assertEqual(events(records, "game_over")[0]["data"]["reason"], "no_flames")
        base["player"] = {"carried": 10}
        base["lanterns"][0] = {"id": "L1", "pos": [0, 0, 0]}
        records, _ = self.simulate(scenario=base, frames=[{"tick": 0, "interact": True}], ticks=300)
        self.assertEqual(events(records, "game_over")[0]["data"]["reason"], "dawn_survived")
        self.assertEqual(events(records, "lantern_lit")[0]["tick"], 1)

    def test_bridge_and_jump_pad_between_the_islands(self):
        scenario = {**EMPTY, "random_drifters": False, "charms": [], "player": {"pos": [26, 0, 0]}}
        records, _ = self.simulate(night=2, scenario=scenario, frames=[{"tick": 0, "move": [1, 0]}], ticks=420, interval=60)
        endpoint = snapshots(records)[420]["player"]["pos"]
        self.assertAlmostEqual(endpoint[0], 68, places=2)
        self.assertEqual(endpoint[1:], [0, 0])
        self.assertFalse(events(records, "player_hit"))
        scenario["player"]["pos"] = [20, 0, 18]
        records, _ = self.simulate(night=2, scenario=scenario, frames=[{"tick": 0, "move": [-1, 0]}], ticks=84)
        samples = snapshots(records)
        self.assertAlmostEqual(horizontal(samples[1]["player"]["vel"]), 24, places=2)
        self.assertGreater(samples[40]["player"]["pos"][1], 4.8)
        self.assertGreater(samples[84]["player"]["pos"][0], 49.0)
        self.assertTrue(samples[84]["player"]["grounded"])
        scenario["player"] = {"pos": [20, 0.06, 18], "vel": [0, -1, 0]}
        records, _ = self.simulate(night=2, scenario=scenario, ticks=8)
        self.assertGreater(snapshots(records)[8]["player"]["pos"][1], 0.5)
        self.assertAlmostEqual(horizontal(snapshots(records)[8]["player"]["vel"]), 24, places=2)

    def test_terrace_ramp_wall_tower_and_high_pad(self):
        scenario = {**EMPTY, "random_drifters": False, "wind_enabled": False, "player": {"pos": [26.024, 0, 15.025]}}
        frames = [{"tick": 0, "move": [-math.sqrt(3) / 2, -0.5]}]
        records, _ = self.simulate(night=3, scenario=scenario, frames=frames, ticks=70)
        self.assertAlmostEqual(snapshots(records)[35]["player"]["pos"][1], 1.725, places=2)
        self.assertEqual(snapshots(records)[70]["player"]["pos"][1], 3)
        scenario["player"]["pos"] = [math.sqrt(3) / 2 * 24, 3, 12]
        frames = [{"tick": 0, "move": [math.sqrt(3) / 2, 0.5]}]
        records, _ = self.simulate(night=3, scenario=scenario, frames=frames, ticks=62)
        self.assertAlmostEqual(snapshots(records)[30]["player"]["pos"][1], 1.5, places=2)
        self.assertTrue(snapshots(records)[30]["player"]["grounded"])
        self.assertEqual(snapshots(records)[62]["player"]["pos"][1], 0)
        scenario["player"]["pos"] = [0, 0, 24.2]
        frames = [{"tick": 0, "move": [0, -1]}]
        records, _ = self.simulate(night=3, scenario=scenario, frames=frames, ticks=20)
        self.assertGreater(snapshots(records)[20]["player"]["pos"][2], 24.0)
        scenario["player"]["pos"] = [0, 3, 13]
        records, _ = self.simulate(night=3, scenario=scenario, frames=[{"tick": 0, "move": [1, 0]}], ticks=53)
        samples = snapshots(records)
        self.assertEqual(samples[1]["player"]["vel"][2], -8)
        self.assertAlmostEqual(samples[53]["player"]["pos"][1], 6)
        self.assertTrue(samples[53]["player"]["grounded"])
        scenario["player"]["pos"] = [0, 6, 3]
        records, _ = self.simulate(night=3, scenario=scenario, frames=frames, ticks=20)
        self.assertGreaterEqual(snapshots(records)[20]["player"]["pos"][2], 2.0)
        scenario["player"]["pos"] = [0, 6, 7.9]
        records, _ = self.simulate(night=3, scenario=scenario, frames=[{"tick": 0, "move": [0, 1]}], ticks=30)
        self.assertLess(snapshots(records)[30]["player"]["pos"][1], 6)

    def test_drifters_steal_first_pulse_recovers_and_ttl_expires(self):
        scenario = {**EMPTY, "player": {"carried": 10}, "shades": [{"pos": [0, 0, 1]}],
                    "drifters": [{"id": "D1", "pos": [0, 0, 1]}]}
        records, _ = self.simulate(night=2, scenario=scenario, frames=[{"tick": 1, "pulse": True}], ticks=126)
        steal, = events(records, "drifter_steal")
        self.assertEqual(steal["data"], {"drifter_id": "D1", "amount": 3, "carried": 7})
        self.assertEqual(events(records, "player_hit")[0]["data"]["dropped"], 3)
        self.assertLess(records.index(steal), records.index(events(records, "player_hit")[0]))
        self.assertEqual(events(records, "drifter_drop")[0]["data"], {"drifter_id": "D1", "amount": 3})
        samples = snapshots(records)
        self.assertEqual(samples[2]["motes_active"], 6)
        self.assertEqual(samples[122]["drifters"], [])
        records, _ = self.simulate(scenario={**EMPTY, "motes": [{"pos": [20, 0, 0], "kind": "dropped"}]}, ticks=480)
        samples = snapshots(records)
        self.assertEqual(len(samples[479]["motes"]), 1)
        self.assertEqual(samples[480]["motes"], [])
        scenario["player"] = {"carried": 9, "invuln_ticks": 900}
        scenario["shades"] = []
        scenario["drifters"][0]["state"] = "chase"
        records, _ = self.simulate(night=2, scenario=scenario, frames=[{"tick": 0, "pulse": True}], ticks=4)
        self.assertEqual(snapshots(records)[1]["drifters"][0]["state"], "flee")
        self.assertFalse(events(records, "drifter_steal"))
        records, _ = self.simulate(night=2, scenario=scenario, ticks=4)
        self.assertTrue(events(records, "drifter_steal"))

    def test_charm_duration_dash_override_and_respawn(self):
        scenario = {**EMPTY, "player": {"pos": [35, 0, 0], "dash_cd_ticks": 200}, "random_drifters": False}
        frames = [{"tick": 1, "dash": True, "move": [1, 0]}, {"tick": 2, "dash": False},
                  {"tick": 3, "dash": True}, {"tick": 4, "dash": False}, {"tick": 13, "dash": True}]
        records, _ = self.simulate(night=2, scenario=scenario, frames=frames, ticks=30)
        self.assertEqual(events(records, "charm_picked")[0]["data"], {"charm_id": "C1", "charm_ticks": 600})
        self.assertEqual([item["tick"] for item in events(records, "dash")], [2, 14])
        samples = snapshots(records)
        self.assertEqual(samples[1]["player"]["charm_s"], 10)
        self.assertEqual(samples[1]["charms"][0]["respawn_s"], 45)
        self.assertEqual(samples[14]["player"]["dash_cd_s"], 0)
        self.assertEqual(samples[26]["player"]["vel"][0], 7.2)
        scenario["charms"] = [{"id": "C1", "pos": [0, 0, 0], "available": False, "respawn_ticks": 2}]
        records, _ = self.simulate(night=2, scenario=scenario, ticks=2702, interval=1)
        samples = snapshots(records)
        self.assertTrue(samples[2]["charms"][0]["available"])
        records, _ = self.simulate(night=2, scenario={**EMPTY, "player": {"pos": [35, 0, 0]}, "random_drifters": False}, ticks=2701)
        self.assertEqual([item["tick"] for item in events(records, "charm_picked")], [1, 2701])
        self.assertEqual(snapshots(records)[601]["player"]["charm_s"], 0)

    def test_safe_zone_eviction_does_not_damage_and_knockback_stops_at_edge(self):
        scenario = {**EMPTY, "player": {"carried": 10}, "lanterns": [{"id": "L1", "pos": [0, 0, 0]}],
                    "shades": [{"pos": [0.6, 0, 0]}]}
        records, _ = self.simulate(scenario=scenario, frames=[{"tick": 0, "interact": True}], ticks=45)
        samples = snapshots(records)
        self.assertFalse(events(records, "player_hit"))
        self.assertGreater(horizontal(samples[30]["shades"][0]["pos"]), 6)
        overlapping = {**EMPTY, "lanterns": [{"id": "L1", "pos": [-5, 0, 0], "lit": True},
                                             {"id": "L2", "pos": [5, 0, 0], "lit": True}],
                       "shades": [{"pos": [0, 0.8, 0]}]}
        records, _ = self.simulate(scenario=overlapping, ticks=1)
        position = snapshots(records)[1]["shades"][0]["pos"]
        self.assertGreater(horizontal(position, (-5, 0, 0)), 6)
        self.assertGreater(horizontal(position, (5, 0, 0)), 6)
        scenario = {**EMPTY, "player": {"carried": 3, "pos": [34, 0, 0]}, "shades": [{"pos": [39, 0.8, 0]}]}
        records, _ = self.simulate(scenario=scenario, frames=[{"tick": 0, "pulse": True}], ticks=18)
        self.assertAlmostEqual(horizontal(snapshots(records)[18]["shades"][0]["pos"]), 40, places=2)

    def test_wind_runs_exactly_300_ticks_and_can_be_disabled(self):
        scenario = {**EMPTY, "random_drifters": False}
        records, raw = self.simulate(night=3, scenario=scenario, ticks=2100)
        samples = snapshots(records)
        self.assertFalse(samples[1799]["wind"]["active"])
        self.assertTrue(samples[1800]["wind"]["active"])
        self.assertAlmostEqual(horizontal(samples[1800]["player"]["pos"]), 2 / 60, delta=0.001)
        self.assertTrue(samples[2099]["wind"]["active"])
        self.assertFalse(samples[2100]["wind"]["active"])
        self.assertAlmostEqual(horizontal(samples[2100]["player"]["pos"]), 10, places=2)
        self.assertEqual(raw, self.simulate(night=3, scenario=scenario, ticks=2100)[1])
        records, _ = self.simulate(night=3, scenario={**scenario, "wind_enabled": False}, ticks=2100, interval=60)
        self.assertEqual(snapshots(records)[2100]["player"]["pos"], [0, 0, 0])

    def test_full_18000_tick_night_with_entities_within_budget(self):
        start = time.perf_counter()
        scenario = {"player": {"invuln_ticks": 22000}, "wind_enabled": False}
        records, _ = self.simulate(night=3, scenario=scenario, ticks=21600, interval=10)
        elapsed = time.perf_counter() - start
        print(f"\nFull Night 3 (18,000 ticks including output): {elapsed:.3f} s", flush=True)
        self.assertLessEqual(elapsed, 30)
        self.assertEqual(records[-1]["ticks"], 18000)
        self.assertEqual(events(records, "game_over")[0]["data"]["reason"], "dawn")


if __name__ == "__main__":
    unittest.main(verbosity=2)
