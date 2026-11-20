"""Run a Godot measurement and sample the child process's resident memory."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


class Memory:
    def __init__(self, pid):
        self.pid = pid
        self.handle = None
        if os.name == "nt":
            from ctypes import wintypes

            class Counters(ctypes.Structure):
                _fields_ = [("size", wintypes.DWORD), ("faults", wintypes.DWORD),
                            *[(name, ctypes.c_size_t) for name in (
                                "peak_working", "working", "peak_paged", "paged",
                                "peak_nonpaged", "nonpaged", "pagefile", "peak_pagefile")]]

            kernel = ctypes.WinDLL("kernel32", use_last_error=True)
            kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
            kernel.OpenProcess.restype = wintypes.HANDLE
            kernel.CloseHandle.argtypes = [wintypes.HANDLE]
            psapi = ctypes.WinDLL("psapi", use_last_error=True)
            self.read = psapi.GetProcessMemoryInfo
            self.read.argtypes = [wintypes.HANDLE, ctypes.POINTER(Counters), wintypes.DWORD]
            self.counters = Counters()
            self.counters.size = ctypes.sizeof(Counters)
            self.handle = kernel.OpenProcess(0x0410, False, pid)
            self.close_handle = kernel.CloseHandle
            if not self.handle:
                raise ctypes.WinError(ctypes.get_last_error())

    def rss(self):
        if self.handle:
            if not self.read(self.handle, ctypes.byref(self.counters), self.counters.size):
                raise ctypes.WinError(ctypes.get_last_error())
            return self.counters.working / 1048576
        if sys.platform.startswith("linux"):
            with open(f"/proc/{self.pid}/statm", encoding="ascii") as status:
                return int(status.read().split()[1]) * os.sysconf("SC_PAGE_SIZE") / 1048576
        value = subprocess.check_output(["ps", "-o", "rss=", "-p", str(self.pid)], text=True)
        return int(value.strip()) / 1024

    def close(self):
        if self.handle:
            self.close_handle(self.handle)


def run(args):
    out = Path(args.out).resolve()
    executable = shutil.which(args.godot) or args.godot
    if os.name == "nt" and executable.lower().endswith("_console.exe"):
        # The Windows console launcher exits with Godot but has its own, tiny RSS.
        executable = executable[:-len("_console.exe")] + ".exe"
        if not Path(executable).is_file():
            raise RuntimeError("Select the Godot executable beside the Windows console launcher")
    with tempfile.TemporaryDirectory(prefix="dao-den-long-") as folder:
        handshake = Path(folder)
        render = ["--resolution", "1280x720", "--disable-vsync"] if args.mode == "bench" else ["--headless"]
        command = [executable, "--path", str(ROOT), *render, "--script", f"res://tools/{args.mode}.gd", "--",
                   str(args.seed), str(args.count), str(handshake)]
        command.append(str(time.time_ns() / 1e9))
        with subprocess.Popen(command, cwd=ROOT) as child:
            memory = None
            samples = {}
            peak = 0.0
            try:
                memory = Memory(child.pid)
                while child.poll() is None:
                    for mark in ("start", "end"):
                        if mark not in samples and (handshake / mark).exists():
                            samples[mark] = memory.rss()
                            (handshake / f"{mark}.ack").touch()
                    if args.mode == "bench" and "start" in samples and "end" not in samples:
                        peak = max(peak, memory.rss())
                    time.sleep(0.03 if args.mode == "bench" else 0.01)
                if child.returncode:
                    raise RuntimeError(f"Godot exited {child.returncode}")
                if set(samples) != {"start", "end"}:
                    raise RuntimeError("Measurement did not reach both checkpoints")
                data = json.loads((handshake / "result.json").read_text(encoding="utf-8"))
                if args.mode == "bench":
                    data["peak_mem_mb"] = round(max(peak, *samples.values()), 2)
                else:
                    data.update(mem_start_mb=round(samples["start"], 2), mem_end_mb=round(samples["end"], 2))
                out.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
            finally:
                if child.poll() is None:
                    child.terminate()
                if memory:
                    memory.close()


if __name__ == "__main__":
    mode = sys.argv[2] if len(sys.argv) > 2 else ""
    parser = argparse.ArgumentParser()
    parser.add_argument("godot")
    parser.add_argument("mode", choices=["bench", "soak"])
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--duration" if mode == "bench" else "--nights", dest="count", type=int, required=True)
    parser.add_argument("--out", required=True)
    settings = parser.parse_args()
    if settings.count < 1:
        parser.error("duration and nights must be positive")
    try:
        run(settings)
    except (OSError, RuntimeError, ValueError) as error:
        parser.exit(1, f"measurement: {error}\n")
