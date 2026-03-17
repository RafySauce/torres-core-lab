"""
Torres-Core Mesh — Bulk Node Flasher (RNode Edition)
Automatically detects Heltec LoRa32 V3 boards and flashes them with
RNode firmware using rnodeconf --autoinstall. Supports up to 10 devices
in parallel via powered USB hub.

Requirements:
    py -m pip install rns pyserial esptool

Usage:
    py flash_nodes.py              # flash all detected boards
    py flash_nodes.py --list       # list detected boards only
    py flash_nodes.py --port COM3  # flash a single specific port
    py flash_nodes.py --dry-run    # detect boards only, don't flash

Windows notes:
    - rnodeconf --yes is not supported in rns v1.x — we pipe stdin answers instead
    - rnodeconf uses which() to find esptool.py, which fails on Windows; we patch
      that check in rnodeconf.py on first run (replaces which() with os.path.isfile)
    - Prompt sequence for Heltec V3 @ 915MHz: "8", "", "3", "y"
"""

import sys
import os
import re
import time
import shutil
import argparse
import threading
import subprocess
from pathlib import Path
from datetime import datetime

# ── Config ────────────────────────────────────────────────────────────────────

# CP2102 USB IDs — both Heltec V3 and Sonoff ZBDongle share this chip.
# We distinguish them by checking product description strings.
CP2102_VID = "10C4"
CP2102_PID = "EA60"
SONOFF_STRINGS = ["sonoff", "zigbee", "zbdongle", "itead"]

# Stdin answers for rnodeconf --autoinstall on Heltec V3 @ 915 MHz:
#   8  = Heltec LoRa32 v3
#   "" = dismiss experimental firmware warning (blank enter)
#   3  = 915 MHz band
#   y  = confirm flash
RNODECONF_STDIN = "8\n\n3\ny\n"

# ── Colours (Windows-safe) ────────────────────────────────────────────────────

GREEN  = "\033[92m"
YELLOW = "\033[93m"
RED    = "\033[91m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

def log(port, msg, colour=RESET):
    ts = datetime.now().strftime("%H:%M:%S")
    prefix = f"[{port}]" if port else "[  *  ]"
    print(f"{colour}{ts} {prefix} {msg}{RESET}", flush=True)

def log_info(msg, port=""):   log(port, msg, CYAN)
def log_ok(msg, port=""):     log(port, msg, GREEN)
def log_warn(msg, port=""):   log(port, msg, YELLOW)
def log_err(msg, port=""):    log(port, msg, RED)

# ── Board detection ───────────────────────────────────────────────────────────

def find_heltec_ports():
    """
    Returns list of COM port names that look like Heltec LoRa32 V3 boards.
    Filters out the Sonoff ZBDongle which shares the same CP2102 chip ID.
    """
    try:
        import serial.tools.list_ports
    except ImportError:
        log_err("pyserial not installed. Run: py -m pip install pyserial")
        sys.exit(1)

    found = []
    all_ports = serial.tools.list_ports.comports()

    for port in all_ports:
        vid = f"{port.vid:04X}" if port.vid else ""
        pid = f"{port.pid:04X}" if port.pid else ""

        if vid != CP2102_VID or pid != CP2102_PID:
            continue

        # Check description/product string for Sonoff identifiers
        desc = (port.description or "").lower()
        prod = (port.product or "").lower()
        mfr  = (port.manufacturer or "").lower()
        combined = desc + prod + mfr

        if any(s in combined for s in SONOFF_STRINGS):
            log_warn(f"Skipping {port.device} — looks like Sonoff ZBDongle ({port.description})")
            continue

        found.append(port.device)
        log_ok(f"Found Heltec V3 on {port.device} — {port.description}")

    return found

# ── Dependency check + Windows patch ─────────────────────────────────────────

def find_rnodeconf_exe():
    """
    Locate rnodeconf executable. On Windows, pip installs it to the Python
    Scripts directory which may not be on PATH. Returns full path or None.
    """
    # Try PATH first
    from shutil import which as shutil_which
    found = shutil_which("rnodeconf")
    if found:
        return found

    # Fall back to Scripts dir next to this Python executable
    scripts_dir = Path(sys.executable).parent / "Scripts"
    for name in ["rnodeconf.exe", "rnodeconf"]:
        candidate = scripts_dir / name
        if candidate.exists():
            return str(candidate)

    return None


def patch_rnodeconf_windows(rnodeconf_path):
    """
    rnodeconf uses which() to verify esptool.py is executable before flashing.
    On Windows, which() won't find .py files, so the check always fails even
    when the file exists. We patch that one line to use os.path.isfile instead.
    This is a genuine Windows bug in rnodeconf — patch is idempotent.
    """
    # Find rnodeconf.py source
    rns_util = Path(sys.executable).parent.parent / "Lib" / "site-packages" / "RNS" / "Utilities" / "rnodeconf.py"
    if not rns_util.exists():
        log_warn("Could not find rnodeconf.py source to apply Windows patch — will try anyway")
        return

    content = rns_util.read_text(encoding="utf-8")
    old = "if which(flasher) is not None:"
    new = "if os.path.isfile(flasher):"

    if new in content:
        log_ok("Windows esptool patch already applied")
        return

    if old not in content:
        log_warn("Windows patch target not found in rnodeconf.py — may already be fixed upstream")
        return

    patched = content.replace(old, new)
    rns_util.write_text(patched, encoding="utf-8")
    log_ok("Applied Windows esptool patch to rnodeconf.py (which() → os.path.isfile)")


def check_rnodeconf():
    """
    Verify rnodeconf is available, apply Windows patch, return command list.
    """
    exe = find_rnodeconf_exe()

    if not exe:
        log_err("rnodeconf not found.")
        log_err("Install it with: py -m pip install rns")
        log_err("Then re-run this script.")
        sys.exit(1)

    # Verify it runs
    try:
        result = subprocess.run(
            [exe, "--version"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            log_ok(f"rnodeconf found: {exe}")
            log_ok(f"Version: {result.stdout.strip()}")
        else:
            log_warn(f"rnodeconf found but --version returned non-zero: {exe}")
    except Exception as e:
        log_err(f"rnodeconf found at {exe} but failed to run: {e}")
        sys.exit(1)

    # Apply Windows patch so esptool.py is found correctly
    if sys.platform == "win32":
        patch_rnodeconf_windows(exe)

    return [exe]

# ── Flashing ──────────────────────────────────────────────────────────────────

def flash_device(port, rnodeconf_cmd, results, idx):
    """
    Flash a single device with RNode firmware via rnodeconf --autoinstall.
    Runs in a thread. Writes result to results[idx].

    Pipes stdin answers to handle rnodeconf's interactive prompts:
      8  = Heltec LoRa32 v3
      "" = dismiss experimental warning
      3  = 915 MHz
      y  = confirm
    """
    log_info(f"Starting RNode flash (rnodeconf --autoinstall)...", port=port)

    cmd = rnodeconf_cmd + [port, "--autoinstall"]

    # Spinner runs in a separate thread while flash is in progress
    spinner_frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    spinner_stop   = threading.Event()

    def spin():
        i = 0
        while not spinner_stop.is_set():
            frame  = spinner_frames[i % len(spinner_frames)]
            elapsed = int(time.time() - spin_start)
            # \r returns to start of line, \033[K clears to end
            print(f"\r{CYAN}{frame} [{port}] Flashing... {elapsed}s{RESET}\033[K", end="", flush=True)
            time.sleep(0.1)
            i += 1
        # Clear spinner line when done
        print(f"\r\033[K", end="", flush=True)

    spin_start   = time.time()
    spin_thread  = threading.Thread(target=spin, daemon=True)
    spin_thread.start()

    try:
        proc = subprocess.run(
            cmd,
            input=RNODECONF_STDIN,
            capture_output=True,
            text=True,
            timeout=180,
        )

        spinner_stop.set()
        spin_thread.join()

        combined  = proc.stdout + proc.stderr
        out_lines = [l for l in combined.splitlines() if l.strip()]

        success_markers = ["firmware flashed", "rnode firmware installed", "device configured", "flashing"]
        flashed = any(m in combined.lower() for m in success_markers) or proc.returncode == 0

        if flashed:
            log_ok(f"RNode flash SUCCESS", port=port)
            for line in out_lines[-4:]:
                log_info(f"  {line}", port=port)
            results[idx] = ("ok", port)
        else:
            err_summary = out_lines[-1] if out_lines else "unknown error"
            log_err(f"Flash FAILED: {err_summary}", port=port)
            for line in out_lines[-5:]:
                log_err(f"  {line}", port=port)
            results[idx] = ("fail", port, err_summary)

    except subprocess.TimeoutExpired:
        spinner_stop.set()
        spin_thread.join()
        log_err(f"Flash TIMED OUT after 180s", port=port)
        log_warn(f"Try manually: rnodeconf {port} --autoinstall", port=port)
        results[idx] = ("timeout", port)
    except Exception as e:
        spinner_stop.set()
        spin_thread.join()
        log_err(f"Flash ERROR: {e}", port=port)
        results[idx] = ("error", port, str(e))

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    # Enable ANSI colours on Windows
    os.system("")

    parser = argparse.ArgumentParser(
        description="Torres-Core bulk RNode flasher for Heltec LoRa32 V3"
    )
    parser.add_argument("--list",    action="store_true", help="List detected boards and exit")
    parser.add_argument("--port",    type=str,            help="Flash a single specific COM port")
    parser.add_argument("--dry-run", action="store_true", help="Detect boards only, don't flash")
    args = parser.parse_args()

    print(f"\n{BOLD}{CYAN}Torres-Core Mesh — Bulk RNode Flasher{RESET}")
    print(f"{CYAN}{'─' * 40}{RESET}\n")

    # Detect boards
    if args.port:
        ports = [args.port]
        log_info(f"Single-port mode: {args.port}")
    else:
        ports = find_heltec_ports()

    if not ports:
        log_err("No Heltec LoRa32 V3 boards detected.")
        log_warn("Check that:")
        log_warn("  1. CP210x driver is installed (silabs.com VCP drivers)")
        log_warn("  2. USB cable supports data (not charge-only)")
        log_warn("  3. Board is powered on (OLED lit)")
        sys.exit(1)

    print()
    log_info(f"Detected {len(ports)} board(s): {', '.join(ports)}")

    if args.list:
        sys.exit(0)

    # Verify rnodeconf is available before proceeding
    print()
    rnodeconf_cmd = check_rnodeconf()
    print()

    if args.dry_run:
        log_ok("Dry run complete — boards detected, rnodeconf available, nothing flashed.")
        log_info("To flash manually: rnodeconf <PORT> --autoinstall")
        sys.exit(0)

    # Confirm before flashing
    print(f"{YELLOW}About to flash {len(ports)} board(s) with RNode firmware:{RESET}")
    print(f"  Method   : rnodeconf --autoinstall (downloads latest RNode firmware)")
    print(f"  Ports    : {', '.join(ports)}")
    print(f"  Parallel : {'yes — one thread per board' if len(ports) > 1 else 'no'}")
    print(f"  Timeout  : 3 min per board (firmware download + flash)\n")
    confirm = input(f"{BOLD}Proceed? [y/N]: {RESET}").strip().lower()
    if confirm != "y":
        log_warn("Aborted.")
        sys.exit(0)

    print()
    start = time.time()

    # Flash all boards in parallel threads
    results = [None] * len(ports)
    threads = []

    for i, port in enumerate(ports):
        t = threading.Thread(
            target=flash_device,
            args=(port, rnodeconf_cmd, results, i),
            daemon=True,
        )
        threads.append(t)
        t.start()
        time.sleep(0.5)  # stagger starts slightly to avoid hub contention on init

    for t in threads:
        t.join(timeout=200)  # slightly longer than per-board timeout

    # Summary
    elapsed = time.time() - start
    print(f"\n{BOLD}{'─' * 40}")
    print(f"Results ({elapsed:.0f}s){RESET}")

    ok   = [r for r in results if r and r[0] == "ok"]
    fail = [r for r in results if r and r[0] != "ok"]

    for r in ok:
        log_ok(f"  {r[1]} — RNode firmware installed")
    for r in fail:
        detail = r[2] if len(r) > 2 else r[0]
        log_err(f"  {r[1]} — {detail}")

    print()
    if fail:
        log_warn(f"{len(ok)}/{len(ports)} boards flashed. {len(fail)} failed.")
        log_warn("For failed boards:")
        log_warn("  1. Unplug and replug the board")
        log_warn("  2. Try: rnodeconf <PORT> --autoinstall")
        log_warn("  3. If still failing, hold PRG + press RST to force bootloader mode")
        sys.exit(1)
    else:
        log_ok(f"All {len(ok)} board(s) flashed with RNode firmware.")
        log_ok("Boards will reboot automatically.")
        print()
        log_info("Next steps:")
        log_info("  Verify:  rnodeconf <PORT> --info")
        log_info("  Config:  add interface to ~/.reticulum/config")
        log_info("  Test:    rnstatus (should show interface UP)")
        sys.exit(0)

if __name__ == "__main__":
    main()
