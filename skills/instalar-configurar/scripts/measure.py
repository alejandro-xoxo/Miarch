#!/usr/bin/env python3
"""Measure the real memory (PSS) and idle CPU of a command and everything it spawns.

Use it to compare two candidates (two browsers, two editors...) under the same conditions instead of guessing which is lighter.

  measure.py [--wait 40] [--sample 20] -- COMMAND [ARGS...]

The command is started in its own session; after --wait seconds (time to settle: a fresh profile does heavy first-run work)
it samples for --sample seconds and prints one line:  N processes | RAM X MB (PSS) | idle CPU Y% of one core
PSS does not double-count memory shared between processes, so it is the fair number for multi-process apps.
Afterwards only that session is closed (SIGTERM, then SIGKILL); nothing else on the machine is touched.
Limits: processes that detach into a new session are not counted; Linux only (/proc).
Run candidates one at a time, with a fresh profile each and the same workload. If the command opens a window, do it where it
will not disturb the user (an empty workspace) and let this script close it.
"""
import argparse, os, signal, subprocess, sys, time

HZ = os.sysconf("SC_CLK_TCK")

def session_pids(sid):
    out = []
    for p in os.listdir("/proc"):
        if not p.isdigit():
            continue
        try:
            campos = open(f"/proc/{p}/stat").read().rsplit(")", 1)[1].split()
            if int(campos[3]) == sid and campos[0] != "Z":      # un proceso ya terminado (zombi) no cuenta
                out.append(int(p))
        except (OSError, IndexError, ValueError):
            pass
    return out

def cpu_ticks(pid):
    try:
        c = open(f"/proc/{pid}/stat").read().rsplit(")", 1)[1].split()
        return int(c[11]) + int(c[12])
    except (OSError, IndexError, ValueError):
        return 0

def pss_mb(pid):
    try:
        for linea in open(f"/proc/{pid}/smaps_rollup"):
            if linea.startswith("Pss:"):
                return int(linea.split()[1]) / 1024
    except OSError:
        pass
    return 0.0

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--wait", type=float, default=40, help="seconds to let it settle before measuring")
    ap.add_argument("--sample", type=float, default=20, help="seconds of CPU sampling")
    ap.add_argument("cmd", nargs=argparse.REMAINDER, help="-- COMMAND [ARGS...]")
    a = ap.parse_args()
    cmd = a.cmd[1:] if a.cmd and a.cmd[0] == "--" else a.cmd
    if not cmd:
        ap.error("give the command after --")
    proc = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    sid = proc.pid
    try:
        time.sleep(a.wait)
        antes = {p: cpu_ticks(p) for p in session_pids(sid)}
        if not antes:
            print("ERROR: the command is not running (it exited, or it detached from its session)")
            return 1
        t0 = time.time()
        time.sleep(a.sample)
        dt = time.time() - t0
        pids = session_pids(sid)
        cpu = sum(cpu_ticks(p) - antes.get(p, cpu_ticks(p)) for p in pids) / HZ / dt * 100
        ram = sum(pss_mb(p) for p in pids)
        print(f"{len(pids)} processes | RAM {ram:.0f} MB (PSS) | idle CPU {cpu:.1f}% of one core | {' '.join(cmd)[:60]}")
        return 0
    finally:
        try:
            os.killpg(sid, signal.SIGTERM)
            time.sleep(3)
            os.killpg(sid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass

if __name__ == "__main__":
    sys.exit(main())
