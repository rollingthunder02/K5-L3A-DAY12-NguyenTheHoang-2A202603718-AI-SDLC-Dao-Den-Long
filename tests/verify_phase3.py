"""Black-box scenarios for Ticket-03 and Test Contract 1.2."""

import math
import unittest

from verify_phase1 import EMPTY, HeadlessCase, events, snapshots


def lamp_at(records, tick, lamp_id="L1"):
    return next(lamp for lamp in snapshots(records)[tick]["lanterns"] if lamp["id"] == lamp_id)


def shade_at(records, tick, shade_id="S1"):
    return next(shade for shade in snapshots(records)[tick]["shades"] if shade["id"] == shade_id)


class Ticket03Tests(HeadlessCase):
    def test_natural_decay_exact_outage_and_no_phase_change_during_pause(self):
        scenario = {**EMPTY, "lanterns": [{"id": "L1", "lit": True}]}
        records, _ = self.simulate(scenario=scenario, ticks=6000, interval=60)
        self.assertEqual(lamp_at(records, 0)["fuel"], 100.0)
        self.assertEqual(lamp_at(records, 60)["fuel"], 99.0)
        self.assertEqual(lamp_at(records, 5940)["fuel"], 1.0)
        lamp = lamp_at(records, 6000)
        self.assertEqual((lamp["fuel"], lamp["lit"], lamp["deposited"], lamp["ever_lit"]), (0.0, False, 0, True))
        self.assertEqual([(e["tick"], e["data"]) for e in events(records, "lantern_out")], [(6000, {"lantern_id": "L1"})])
        scenario["lanterns"][0]["fuel"] = 1 / 60
        records, _ = self.simulate(scenario=scenario, frames=[{"tick": 0, "pause": True}, {"tick": 1, "pause": False},
                                                              {"tick": 4, "pause": True}], ticks=6)
        self.assertTrue(lamp_at(records, 4)["lit"])
        self.assertEqual(events(records, "lantern_out")[0]["tick"], 5)

    def test_refuel_uses_ceil_after_decay_and_resolves_equal_distance_by_id(self):
        scenario = {**EMPTY, "player": {"carried": 5}, "lanterns": [
            {"id": "L1", "pos": [1, 0, 0], "lit": True, "fuel": 90}, {"id": "L2", "pos": [-1, 0, 0]}]}
        records, _ = self.simulate(scenario=scenario, frames=[{"tick": 0, "interact": True}], ticks=5)
        refuel, = events(records, "refuel")
        self.assertEqual(refuel["data"], {"lantern_id": "L1", "amount": 2, "fuel": 100.0})
        self.assertEqual(snapshots(records)[1]["player"]["carried"], 3)
        self.assertEqual(snapshots(records)[1]["player"]["capacity"], 10)
        self.assertEqual(records[-1]["score"], 10)
        self.assertFalse(events(records, "deposit"))
        scenario["player"]["carried"] = 1
        scenario["lanterns"][0]["fuel"] = 20
        records, _ = self.simulate(scenario=scenario, frames=[{"tick": 0, "interact": True}], ticks=1)
        self.assertEqual(events(records, "refuel")[0]["data"]["fuel"], 30.0)
        self.assertEqual(snapshots(records)[1]["player"]["carried"], 0)

    def test_relight_after_outage_counts_once_and_cap_applies_to_pickup(self):
        scenario = {**EMPTY, "player": {"carried": 7}, "lanterns": [{"id": "L1", "pos": [0, 0, 0],
                                                                       "lit": True, "fuel": 1 / 60}]}
        records, _ = self.simulate(scenario=scenario, frames=[{"tick": 0, "interact": True}], ticks=2)
        self.assertEqual([r["name"] for r in records if r["type"] == "event"],
                         ["night_start", "lantern_out", "deposit", "lantern_lit"])
        self.assertEqual(events(records, "deposit")[0]["data"]["amount"], 5)
        self.assertEqual(events(records, "lantern_lit")[0]["data"], {"lantern_id": "L1", "relight": True})
        self.assertEqual(lamp_at(records, 1)["fuel"], 100.0)
        self.assertEqual(lamp_at(records, 1)["relit_count"], 1)
        self.assertEqual(snapshots(records)[0]["player"]["capacity"], 10)
        self.assertEqual(snapshots(records)[1]["player"]["capacity"], 12)
        self.assertEqual(records[-1]["score"], 65)
        scenario = {**EMPTY, "player": {"carried": 19, "successful_lights": 15}, "motes": [[0, 0, 0], [0, 0, 0]]}
        records, _ = self.simulate(scenario=scenario, ticks=1)
        self.assertEqual(snapshots(records)[1]["player"]["capacity"], 20)
        self.assertEqual(snapshots(records)[1]["player"]["carried"], 20)
        self.assertEqual(snapshots(records)[1]["motes_active"], 1)

    def test_safe_radius_uses_unrounded_fuel_at_exact_30(self):
        scenario = {**EMPTY, "player": {"pos": [20, 0, 0]}, "lanterns": [{"id": "L1", "pos": [0, 0, 0],
            "lit": True, "fuel": 30 + 1 / 60}], "shades": [{"state": "wander", "pos": [1, 0.8, 0]}]}
        records, _ = self.simulate(scenario=scenario, ticks=1)
        self.assertEqual(lamp_at(records, 1)["fuel"], 30.0)
        self.assertGreater(shade_at(records, 1)["pos"][0], 6.0)
        scenario["lanterns"][0]["fuel"] = 30
        records, _ = self.simulate(scenario=scenario, ticks=1)
        self.assertEqual(lamp_at(records, 1)["fuel"], 30.0)
        self.assertEqual(shade_at(records, 1)["state"], "drain")

    def test_wander_targets_weak_lamps_and_drains_stack_each_second(self):
        scenario = {**EMPTY, "player": {"pos": [20, 0, 0]}, "lanterns": [{"id": "L1", "pos": [0, 0, 0],
            "lit": True, "fuel": 29}], "shades": [{"state": "wander", "pos": [0, 0.8, 1]},
                                                   {"state": "wander", "pos": [0, 0.8, -1]}]}
        records, raw = self.simulate(scenario=scenario, ticks=161)
        self.assertEqual(shade_at(records, 1)["state"], "drain")
        self.assertEqual(shade_at(records, 61)["pos"], [0, 0.8, 1])
        self.assertEqual([(e["tick"], e["data"]["shade_id"], e["data"]["fuel"]) for e in events(records, "fuel_drain")],
                         [(61, "S1", 18.0), (61, "S2", 18.0), (121, "S1", 7.0), (121, "S2", 7.0)])
        self.assertEqual(events(records, "lantern_out")[0]["tick"], 160)
        self.assertEqual(shade_at(records, 160)["state"], "wander")
        self.assertEqual(raw, self.simulate(scenario=scenario, ticks=161)[1])
        scenario["lanterns"].append({"id": "L2", "pos": [0, 0, 0], "lit": True, "fuel": 10})
        records, _ = self.simulate(scenario=scenario, ticks=61, interval=61)
        self.assertTrue(all(e["data"]["lantern_id"] == "L1" for e in events(records, "fuel_drain")))
        scenario["shades"][0]["state"] = "chase"
        scenario["player"]["pos"] = [17, 0, 0]
        records, _ = self.simulate(scenario=scenario, ticks=1)
        self.assertEqual(shade_at(records, 1)["state"], "chase")
        self.assertGreater(shade_at(records, 1)["pos"][0], 0)

    def test_drain_ends_on_player_approach_refuel_and_pulse_scores_total_15(self):
        base = {**EMPTY, "lanterns": [{"id": "L1", "pos": [0, 0, 0], "lit": True, "fuel": 25}],
                "shades": [{"state": "drain", "pos": [1, 0.8, 0], "target_lantern_id": "L1"}]}
        records, _ = self.simulate(scenario={**base, "player": {"pos": [7, 0, 0]}}, ticks=2)
        self.assertEqual(shade_at(records, 1)["state"], "chase")
        records, _ = self.simulate(scenario={**base, "player": {"carried": 1}},
                                   frames=[{"tick": 0, "interact": True}], ticks=30)
        self.assertEqual(lamp_at(records, 1)["fuel"], 34.9)
        self.assertEqual(shade_at(records, 1)["state"], "wander")
        self.assertGreater(shade_at(records, 30)["pos"][0], 6.0)
        self.assertFalse(events(records, "player_hit"))
        self.assertFalse(events(records, "fuel_drain"))
        scenario = {**base, "player": {"carried": 3}, "shades": base["shades"] + [{"pos": [4, 0.8, 0]}]}
        records, _ = self.simulate(scenario=scenario, frames=[{"tick": 0, "pulse": True}], ticks=122)
        self.assertEqual(events(records, "pulse")[0]["data"]["stunned_ids"], ["S1", "S2"])
        self.assertEqual(snapshots(records)[1]["score"], 20)
        self.assertEqual(shade_at(records, 121)["state"], "wander")

    def test_dawn_threshold_and_scores_use_raw_fuel_on_last_tick(self):
        for night in range(1, 4):
            with self.subTest(night=night):
                required = math.ceil(0.6 * (night + 4))
                scenario = {**EMPTY, "random_drifters": False, "time_left_s": 2 / 60,
                            "lanterns": [{"id": f"L{i}", "lit": True, "fuel": 50} for i in range(1, required + 1)]}
                records, _ = self.simulate(night=night, scenario=scenario, ticks=4)
                self.assertEqual(snapshots(records)[1]["state"], "playing")
                self.assertEqual(lamp_at(records, 2)["fuel"], 50.0)
                self.assertEqual(records[-1]["score"], 150 + 99 * required)
                self.assertEqual(events(records, "game_over")[0]["data"]["reason"], "dawn_survived")
                scenario["lanterns"][-1]["fuel"] = 2 / 60
                records, _ = self.simulate(night=night, scenario=scenario, ticks=4)
                self.assertEqual(events(records, "lantern_out")[0]["tick"], 2)
                self.assertEqual(events(records, "game_over")[0]["data"]["reason"], "dawn")
                self.assertEqual(records[-1]["score"], 0)
                scenario["lanterns"][-1]["pos"] = [0, 0, 0]
                scenario["player"] = {"carried": 5}
                records, _ = self.simulate(night=night, scenario=scenario,
                                           frames=[{"tick": 1, "interact": True}], ticks=4)
                self.assertEqual([e["name"] for e in records if e["type"] == "event" and e["tick"] == 2],
                                 ["lantern_out", "deposit", "lantern_lit", "game_over"])
                self.assertTrue(events(records, "lantern_lit")[0]["data"]["relight"])
                self.assertEqual(events(records, "game_over")[0]["data"]["reason"], "dawn_survived")

    def test_invalid_new_scenario_fields_return_two(self):
        for scenario in [{"player": {"successful_lights": -1}}, {"lanterns": [{"id": "L1", "ever_lit": 1}]},
                         {"lanterns": [{"id": "L1", "fuel": 100.1}]},
                         {"shades": [{"pos": [0, 0, 0], "state": "drain", "target_lantern_id": "L7"}]}]:
            self.simulate(scenario=scenario, error=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
