"""Black-box checks of Test Contract v1.0. Run from the project root."""

import json
import math
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CONTRACT = json.loads((ROOT / "game.contract.json").read_text(encoding="utf-8"))
TUNING = CONTRACT["tuning"]
EMPTY = {"random_motes": False, "random_shades": False}


def headless_command():
    bash_bin = os.environ.get("DAO_BEN_TEST_BASH")
    if os.name == "nt" and not bash_bin:
        return [os.environ.get("GODOT_BIN", "godot"), "--headless", "--path", str(ROOT),
                "--script", "res://src/headless.gd", "--"]
    command = shlex.split(CONTRACT["headless_cmd"])
    if bash_bin:
        command[0] = bash_bin
    return command


def events(records, name):
    return [record for record in records if record.get("name") == name]


def snapshots(records):
    return {record["tick"]: record for record in records if record["type"] == "snapshot"}


class HeadlessCase(unittest.TestCase):
    def simulate(self, *, scenario=None, frames=None, ticks=10, interval=1, seed=42, error=False, night=1):
        with tempfile.TemporaryDirectory(prefix="dao-ben-") as temporary:
            dest = Path(temporary)
            output = dest / "run.jsonl"
            args = ["--seed", str(seed), "--night", str(night), "--ticks", str(ticks), "--out", str(output)]
            if interval is not None:
                args += ["--snapshot-every", str(interval)]
            for option, data in [("scenario", scenario), ("inputs", {"frames": frames} if isinstance(frames, list) else frames)]:
                if data is not None:
                    path = dest / f"{option}.json"
                    path.write_text(data if isinstance(data, str) else json.dumps(data), encoding="utf-8")
                    args += [f"--{option}", str(path)]
            process = subprocess.run(headless_command() + args, cwd=ROOT, capture_output=True,
                                     text=True, encoding="utf-8", errors="replace", timeout=20)
            if error:
                self.assertEqual(process.returncode, 2, process.stderr)
                self.assertIn("headless:", process.stderr)
                self.assertFalse(output.exists())
                return None, None
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertEqual(process.stderr, "")
            raw = output.read_bytes()
            records = [json.loads(line) for line in raw.splitlines()]
            self.assertEqual(records[0]["tick"], 0)
            self.assertEqual(records[-1]["type"], "end")
            self.assertTrue(all(item["sim_tick"] <= item["tick"] for item in snapshots(records).values()))
            return records, raw


class ContractTests(HeadlessCase):
    def test_tick_zero_default_cadence_and_idle(self):
        records, _ = self.simulate(scenario=EMPTY, ticks=24, interval=None)
        self.assertEqual(list(snapshots(records)), [0, 10, 20])
        self.assertEqual(snapshots(records)[20]["player"]["pos"], [0, 0, 0])
        self.assertAlmostEqual(snapshots(records)[20]["time_left_s"], TUNING["night1_duration_s"] - 20 / 60)
        self.assertEqual(records[-1], {"type": "end", "ticks": 24, "state": "playing", "score": 0})
        records, _ = self.simulate(scenario={**EMPTY, "motes": [[0, 0, 0]]}, ticks=0)
        self.assertEqual(len(records), 3)
        self.assertEqual(records[0]["motes_active"], 1)
        self.assertEqual(events(records, "night_start")[0]["data"], {"night": 1})

    def test_movement_rotation_normalization_and_jump_edge(self):
        frames = [{"tick": 0, "move": [0, 1], "cam_yaw_deg": 90, "jump": True},
                  {"tick": 60, "move": [1, 1], "cam_yaw_deg": 0}, {"tick": 120, "move": [0, 0]}]
        records, _ = self.simulate(scenario=EMPTY, frames=frames, ticks=121)
        samples = snapshots(records)
        speed = TUNING["player_speed"]
        self.assertGreater(samples[1]["player"]["pos"][1], 0)
        self.assertEqual(samples[60]["player"]["pos"], [speed, 0, 0])
        self.assertEqual(samples[120]["player"]["pos"], [round(speed + speed / math.sqrt(2), 3), 0,
                                                         round(speed / math.sqrt(2), 3)])
        self.assertEqual(samples[121]["player"]["pos"], samples[120]["player"]["pos"])
        self.assertEqual(samples[121]["player"]["vel"], [0, 0, 0])

    def test_pickup_cap_horizontal_radius_and_partial_deposit(self):
        radius = TUNING["pickup_radius"]
        scenario = {**EMPTY, "player": {"carried": 1}, "motes": [[0, 0, 4], [radius * 0.5, 1.5, 4]],
                    "lanterns": [{"id": "L1", "pos": [TUNING["interact_radius"], 5, 0], "deposited": 1},
                                 {"id": "L2", "pos": [0, 0, 4]}]}
        frames = [{"tick": 0, "interact": True}, {"tick": 1, "move": [0, 1]},
                  {"tick": 41, "move": [0, 0]}, {"tick": 42, "interact": False},
                  {"tick": 43, "interact": True}]
        records, _ = self.simulate(scenario=scenario, frames=frames, ticks=45)
        first, second = events(records, "deposit")
        self.assertEqual(first["data"], {"lantern_id": "L1", "amount": 1, "deposited": 2})
        self.assertEqual(first["tick"], 1)
        self.assertEqual(second["data"], {"lantern_id": "L2", "amount": 2, "deposited": 2})
        self.assertEqual(second["tick"], 44)
        self.assertEqual([item["data"]["carried"] for item in events(records, "mote_picked")], [1, 2])
        self.assertEqual(records[-1]["score"], 3 * TUNING["score"]["per_mote"])
        cap = TUNING["carry_capacity"]
        records, _ = self.simulate(scenario={**EMPTY, "player": {"carried": cap - 1},
                                             "motes": [[radius, 1.5, 0], [0, 0, 0]]}, ticks=1)
        self.assertEqual(snapshots(records)[1]["player"]["carried"], cap)
        self.assertEqual(snapshots(records)[1]["motes_active"], 1)
        self.assertEqual(snapshots(records)[1]["motes"][0]["pos"], [0, 0, 0])

    def test_pulse_range_push_duration_cost_and_cooldown(self):
        radius = TUNING["pulse_radius"]
        scenario = {**EMPTY, "player": {"carried": 10, "invuln_ticks": 500},
                    "shades": [{"id": "near", "pos": [radius, 0.8, 0]}, {"id": "far", "pos": [-radius - 1, 0.8, 0]}]}
        frames = [{"tick": 0, "pulse": True}, {"tick": 7, "pulse": False}, {"tick": 8, "pulse": True}]
        resume = 1 + round(TUNING["pulse_stun_s"] * 60)
        records, _ = self.simulate(scenario=scenario, frames=frames, ticks=resume, interval=1)
        pulse, = events(records, "pulse")
        self.assertEqual(pulse["tick"], 1)
        self.assertEqual(pulse["data"], {"stunned_ids": ["near"]})
        samples = snapshots(records)
        self.assertEqual(samples[1]["player"]["carried"], 10 - TUNING["pulse_cost"])
        near = lambda tick: next(shade for shade in samples[tick]["shades"] if shade["id"] == "near")
        self.assertEqual(near(1)["pos"], [round(radius + TUNING["pulse_push_m"] / 15, 3), 0.8, 0])
        self.assertEqual(near(15)["pos"], [radius + TUNING["pulse_push_m"], 0.8, 0])
        self.assertEqual(near(resume - 1)["state"], "stunned")
        self.assertEqual(near(resume)["state"], "wander")
        cooldown = round(TUNING["pulse_cooldown_s"] * 60)
        frames = [{"tick": 0, "pulse": True}, {"tick": 1, "pulse": False}, {"tick": cooldown, "pulse": True}]
        records, _ = self.simulate(scenario=scenario, frames=frames, ticks=cooldown + 1)
        self.assertEqual([item["tick"] for item in events(records, "pulse")], [1, 1 + cooldown])
        scenario["player"]["carried"] = TUNING["pulse_cost"] - 1
        records, _ = self.simulate(scenario=scenario, frames=frames, ticks=1)
        self.assertEqual(events(records, "pulse"), [])

    def test_safe_zone_blocks_shades_at_exact_boundary(self):
        radius = TUNING["safe_radius"]
        scenario = {**EMPTY, "player": {"pos": [radius, 0, 0]},
                    "lanterns": [{"id": "L1", "pos": [0, 3, 0], "lit": True}],
                    "shades": [{"pos": [radius + 0.3, 1, 0]}]}
        records, _ = self.simulate(scenario=scenario, ticks=60)
        self.assertEqual(events(records, "player_hit"), [])
        self.assertGreater(snapshots(records)[60]["shades"][0]["pos"][0], radius)
        self.assertEqual(records[-1]["score"], 0)

    def test_hit_drop_invulnerability_and_early_loss(self):
        scenario = {**EMPTY, "player": {"carried": 10, "flames": 2},
                    "shades": [{"pos": [0, 0.8, 0]}, {"pos": [0, 0, 0]}]}
        records, _ = self.simulate(scenario=scenario, ticks=500, interval=5)
        first, last = events(records, "player_hit")
        self.assertEqual(last["tick"], 1 + round(TUNING["invuln_s"] * 60))
        self.assertEqual(first["data"], {"by": "shade", "flames": 1, "dropped": 5})
        self.assertEqual(last["data"], {"by": "shade", "flames": 0, "dropped": 2})
        self.assertEqual(events(records, "game_over")[0]["data"], {"reason": "no_flames", "result": "lost"})
        self.assertEqual(records[-1]["ticks"], last["tick"])

    def test_winning_order_and_score(self):
        cost = TUNING["lantern_cost"]
        scenario = {**EMPTY, "time_left_s": 2 / 60, "player": {"carried": cost, "flames": 2},
                    "lanterns": [{"id": "L1", "pos": [0, 0, 0]}] +
                                [{"id": f"L{i}", "lit": True} for i in range(2, 6)]}
        records, _ = self.simulate(scenario=scenario, frames=[{"tick": 0, "interact": True}], ticks=80)
        self.assertEqual(records[0]["score"], 0)
        self.assertEqual([item["name"] for item in records if item["type"] == "event"],
                         ["night_start", "deposit", "lantern_lit", "game_over"])
        self.assertEqual(events(records, "game_over")[0]["data"], {"reason": "dawn_survived", "result": "won"})
        self.assertTrue(all(lamp["lit"] for lamp in snapshots(records)[1]["lanterns"]))
        self.assertEqual(snapshots(records)[1]["state"], "playing")
        score = TUNING["score"]
        self.assertEqual(records[-1], {"type": "end", "ticks": 2, "state": "won",
                                      "score": cost * score["per_mote"] + score["per_lantern"]
                                      + 5 * (score["per_dawn_lantern"] + 99) + 2 * score["per_flame_left"]})

    def test_dawn_and_empty_overrides(self):
        records, _ = self.simulate(scenario={"time_left_s": 0.05, "motes": [], "shades": []}, ticks=100)
        self.assertEqual(snapshots(records)[0]["motes"], [])
        self.assertEqual(snapshots(records)[0]["shades"], [])
        self.assertEqual(snapshots(records)[3]["time_left_s"], 0)
        self.assertEqual(events(records, "game_over")[0]["data"], {"reason": "dawn", "result": "lost"})
        self.assertEqual(records[-1]["ticks"], 3)

    def test_deterministic_jsonl_and_generated_ids(self):
        first, raw_first = self.simulate(ticks=350, interval=37, seed=-12)
        _, raw_second = self.simulate(ticks=350, interval=37, seed=-12)
        _, raw_other = self.simulate(ticks=350, interval=37, seed=31)
        self.assertEqual(raw_first, raw_second)
        self.assertNotEqual(raw_first, raw_other)
        self.assertEqual(events(first, "shade_spawned")[0]["data"], {"id": "S1"})
        scenario = {**EMPTY, "shades": [{"pos": [24, 0, 24]}, {"id": "S1", "pos": [28, 0, 0]}]}
        records, _ = self.simulate(ticks=1, scenario=scenario)
        self.assertEqual([shade["id"] for shade in records[0]["shades"]], ["S1", "S2"])

    def test_invalid_inputs_and_scenario_return_two(self):
        invalid_inputs = ["{unclosed", '{"frames":[],}', '{"frames":[{"tick":01}]}',
                          {"frames": True}, [{"tick": 1}, {"tick": 1}],
                          [{"tick": 0, "move": [1.2, 0]}], [{"tick": 2, "jump": 1}], [{"tick": 0.5}]]
        for data in invalid_inputs:
            with self.subTest(inputs=data):
                self.simulate(frames=data, error=True)
        invalid_scenarios = [{"random_motes": 0}, {"player": {"pos": [0, 0]}},
                             {"motes": [{}]}, {"lanterns": [{"id": "L6"}]}, {"shades": [{}]}]
        for data in invalid_scenarios:
            with self.subTest(scenario=data):
                self.simulate(scenario=data, error=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
