# VS Code utilities (v5)
#
# vscode-fullscreen-v5: identical strategy to v4 (visit each display's type-0
# desktop, full-screen the windows AX exposes, retry to ride out AX flakiness,
# repeat passes until one full-screens nothing, never activate VSCode). The
# ONE change is how a full-screen is CONFIRMED.
#
# v4 confirmed by re-reading the window's AXFullScreen attribute in a loop.
# That read lags and is unreliable: we saw windows report "not full-screen
# yet" for the full 3s even though they had already gone full-screen (false
# timeouts), and the same window full-screened twice from stale reads.
#
# v5 confirms from the window server instead: every full-screen window owns a
# type-4 Space whose record carries the owning process's pid (verified: Code's
# full-screen Spaces have pid == the `pgrep -x Code` pid). So after asking AX
# to full-screen a window, we wait until the count of type-4 Spaces owned by
# Code goes UP by one. That signal is live and reliable, which:
#   - kills the false 3s timeouts,
#   - avoids re-full-screening a window that already went full-screen (if no
#     new Space appears, we treat it as no progress, not success).
#
# The reliable current-Space type from the window server also fixes a
# straggler v4 had: after full-screening a window ON the display being driven,
# macOS switches that display onto the new full-screen Space, so any OTHER
# window still on that desktop falls off the current Space and AX stops
# exposing it — it only got picked up on a later pass. After each full-screen
# v5 decides, from the window's x (which display it belongs to — read before
# the animation, reliable), whether the driving display moved: if the window
# was on this display it steps Ctrl+Left back to the desktop (waiting for the
# switch first, since the current-Space read lags). A cross-display catch
# leaves this display put, so it skips — never steps the wrong display.
#
# Note: this only makes each confirmation reliable. FINDING the next window to
# full-screen still goes through AX enumeration, which is non-deterministic
# across Spaces. This build runs a SINGLE pass (MAX_PASSES = 1) to favour
# speed — the step-back makes one pass enough in the common case, but there is
# no confirming pass to recover an occasional AX miss; re-run if the end
# snapshot shows a leftover. Raise MAX_PASSES to trade speed for that safety net.
#
# v4 is left untouched; this is a separate function/file.

vscode-fullscreen-v5() {
  if ! pgrep -x "Code" >/dev/null 2>&1; then
    echo "⚠️  未检测到 VSCode 进程，请先打开 VSCode"
    return 1
  fi

  /usr/bin/python3 <<'PYEOF'
import ctypes, plistlib, subprocess, time

START = time.time()
def el(): return f"{time.time() - START:.2f}"
def log(m): print(f"[{el()}s] {m}", flush=True)

CODE_PIDS = set(int(x) for x in
    subprocess.run(["pgrep", "-x", "Code"], capture_output=True, text=True).stdout.split())

# ---- private window-server + CoreFoundation + CoreGraphics via ctypes ----
sky = ctypes.CDLL("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight")
cf  = ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
cg  = ctypes.CDLL("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")

sky.CGSMainConnectionID.restype = ctypes.c_int
sky.CGSCopyManagedDisplaySpaces.restype = ctypes.c_void_p
sky.CGSCopyManagedDisplaySpaces.argtypes = [ctypes.c_int]

cf.CFPropertyListCreateData.restype = ctypes.c_void_p
cf.CFPropertyListCreateData.argtypes = [ctypes.c_void_p]*2 + [ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
cf.CFDataGetLength.restype = ctypes.c_long; cf.CFDataGetLength.argtypes = [ctypes.c_void_p]
cf.CFDataGetBytePtr.restype = ctypes.c_void_p; cf.CFDataGetBytePtr.argtypes = [ctypes.c_void_p]
cf.CFStringGetCString.restype = ctypes.c_bool
cf.CFStringGetCString.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long, ctypes.c_uint32]
cf.CFUUIDCreateString.restype = ctypes.c_void_p
cf.CFUUIDCreateString.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
cf.CFRelease.argtypes = [ctypes.c_void_p]

class CGPoint(ctypes.Structure): _fields_ = [("x", ctypes.c_double), ("y", ctypes.c_double)]
class CGSize(ctypes.Structure):  _fields_ = [("width", ctypes.c_double), ("height", ctypes.c_double)]
class CGRect(ctypes.Structure):  _fields_ = [("origin", CGPoint), ("size", CGSize)]

cg.CGGetActiveDisplayList.restype = ctypes.c_int32
cg.CGGetActiveDisplayList.argtypes = [ctypes.c_uint32, ctypes.POINTER(ctypes.c_uint32), ctypes.POINTER(ctypes.c_uint32)]
cg.CGDisplayBounds.restype = CGRect
cg.CGDisplayBounds.argtypes = [ctypes.c_uint32]
# CGDisplayCreateUUIDFromDisplayID is no longer exported by CoreGraphics on
# recent macOS; SkyLight (already loaded) still exports it.
sky.CGDisplayCreateUUIDFromDisplayID.restype = ctypes.c_void_p
sky.CGDisplayCreateUUIDFromDisplayID.argtypes = [ctypes.c_uint32]
cg.CGWarpMouseCursorPosition.restype = ctypes.c_int32
cg.CGWarpMouseCursorPosition.argtypes = [CGPoint]

def _cfstr(ref):
    buf = ctypes.create_string_buffer(128)
    if cf.CFStringGetCString(ref, buf, 128, 0x08000100):  # kCFStringEncodingUTF8
        return buf.value.decode()
    return None

def snapshot():
    """Live, per-display Space layout from the window server.
    Returns [{uuid, current(space id), spaces:[(id, type, pid), ...]}].
    pid is present only for type-4 (full-screen) Spaces; None otherwise."""
    cid = sky.CGSMainConnectionID()
    arr = sky.CGSCopyManagedDisplaySpaces(cid)
    data = cf.CFPropertyListCreateData(None, arr, 100, 0, None)  # 100 = XML plist
    raw = ctypes.string_at(cf.CFDataGetBytePtr(data), cf.CFDataGetLength(data))
    cf.CFRelease(data); cf.CFRelease(arr)
    out = []
    for d in plistlib.loads(raw):
        out.append({
            "uuid": d["Display Identifier"],
            "current": d.get("Current Space", {}).get("ManagedSpaceID"),
            "spaces": [(s["ManagedSpaceID"], s.get("type"), s.get("pid")) for s in d["Spaces"]],
        })
    return out

def code_fs_count():
    """Number of full-screen (type-4) Spaces owned by VSCode. Live from the
    window server, so it is a reliable count of VSCode full-screen windows."""
    return sum(1 for d in snapshot()
               for (sid, t, pid) in d["spaces"]
               if t == 4 and pid in CODE_PIDS)

def display_of(uuid):
    return next((x for x in snapshot() if x["uuid"] == uuid), None)

def cur_type(uuid):
    """Type of the Space currently showing on this display (0 desktop / 4 full-screen)."""
    d = display_of(uuid)
    if not d:
        return None
    return {sid: t for sid, t, pid in d["spaces"]}.get(d["current"])

def displays():
    """Active displays with center point (in the global, top-left coordinate
    space CGWarpMouseCursorPosition uses)."""
    n = ctypes.c_uint32()
    cg.CGGetActiveDisplayList(0, None, ctypes.byref(n))
    ids = (ctypes.c_uint32 * n.value)()
    cg.CGGetActiveDisplayList(n.value, ids, ctypes.byref(n))
    out = []
    for i in range(n.value):
        did = ids[i]
        b = cg.CGDisplayBounds(did)
        uref = sky.CGDisplayCreateUUIDFromDisplayID(did)
        sref = cf.CFUUIDCreateString(None, uref)
        uuid = _cfstr(sref)
        cf.CFRelease(sref); cf.CFRelease(uref)
        out.append({
            "uuid": uuid,
            "cx": b.origin.x + b.size.width / 2,
            "cy": b.origin.y + b.size.height / 2,
            "minx": b.origin.x,
            "maxx": b.origin.x + b.size.width,
        })
    return out

def warp(x, y): cg.CGWarpMouseCursorPosition(CGPoint(x, y))

def press(direction):
    code = 124 if direction == "right" else 123  # right / left arrow
    subprocess.run(["osascript", "-e",
        f'tell application "System Events" to key code {code} using control down'],
        capture_output=True)

def osa_out(script):
    return subprocess.run(["osascript", "-e", script], capture_output=True, text=True).stdout.strip()

# Ask AX to full-screen the first non-fullscreen VSCode window it exposes and
# return immediately — confirmation is done outside via the window server (see
# code_fs_count). No display filter / no app activation on purpose: setting
# AXFullScreen works on a background app's window on any Space/display, and
# activating VSCode HIDES its off-Space windows from the AX list. Returns
# "ok:<name>|<x>,<y>" or "none".
_FS = r'''
tell application "System Events"
    tell process "Code"
        repeat with w in every window
            try
                if value of attribute "AXFullScreen" of w is false then
                    set wname to name of w
                    set wpos to position of w
                    set wposText to ((item 1 of wpos) as string) & "," & ((item 2 of wpos) as string)
                    perform action "AXRaise" of w
                    delay 0.2
                    set value of attribute "AXFullScreen" of w to true
                    return "ok:" & wname & "|" & wposText
                end if
            end try
        end repeat
    end tell
end tell
return "none"
'''
def fullscreen_one():
    return osa_out(_FS)

def wait_fs_confirm(before, timeout=1.5):
    """Return True once VSCode's full-screen Space count rises above `before`
    (the full-screen actually took effect), or False on timeout."""
    t0 = time.time()
    while time.time() - t0 < timeout:
        time.sleep(0.2)
        if code_fs_count() > before:
            return True
    return False

def step_back_if_moved(d, wx, timeout=1.5):
    """Full-screening a window ON this display switches the display onto the new
    full-screen Space, hiding its other desktop windows from AX. Step back left
    to the desktop so they stay enumerable this pass.

    Which display the window belongs to is decided by the window's x (read
    before the animation, reliable) — NOT by reading the current-Space type,
    which lags ~1s after a switch and would misread as "didn't move". For a
    cross-display window this display never moved, so we skip immediately."""
    if not (d["minx"] <= wx < d["maxx"]):
        return
    # Wait for this display to actually land on the new full-screen Space, then
    # step back. (The current-Space read lags, so poll until it shows type 4.)
    t0 = time.time()
    while time.time() - t0 < timeout and cur_type(d["uuid"]) != 4:
        time.sleep(0.2)
    if cur_type(d["uuid"]) != 4:
        return
    warp(d["cx"], d["cy"])  # Ctrl+Arrow moves the display under the pointer
    press("left")
    t0 = time.time()
    while time.time() - t0 < timeout and cur_type(d["uuid"]) != 0:
        time.sleep(0.2)

_DEBUG = r'''
tell application "System Events"
    tell process "Code"
        set t to ""
        repeat with w in every window
            try
                set fs to value of attribute "AXFullScreen" of w
                set p to position of w
                set t to t & (name of w) & "|" & fs & "|" & ((item 1 of p) as string) & "," & ((item 2 of p) as string) & linefeed
            end try
        end repeat
        return t
    end tell
end tell
'''
def debug_list():
    for ln in osa_out(_DEBUG).splitlines():
        if ln.strip(): print("    " + ln)

EMPTY_STREAK = 2  # consecutive "none" needed to trust a Space is clean

def scan_current(d, tag, space_no):
    """Full-screen windows AX exposes from the current Space, retrying to ride
    out AX's flaky enumeration until EMPTY_STREAK scans in a row are empty.
    Each full-screen is confirmed against the window server, not AX."""
    n = 0
    empties = 0
    while empties < EMPTY_STREAK:
        before = code_fs_count()
        res = fullscreen_one()
        if res.split(":", 1)[0] == "ok":
            name, pos = res.split(":", 1)[1].rsplit("|", 1)
            if wait_fs_confirm(before):
                empties = 0; n += 1
                log(f"✅ {tag} 空间#{space_no}：全屏确认 [pos={pos}] {name}")
                try:
                    step_back_if_moved(d, int(pos.split(",")[0]))
                except ValueError:
                    pass
                time.sleep(0.3)
            else:
                # AX said it set full-screen but no new Space appeared (stale
                # read / window was already full-screen) — not real progress.
                empties += 1
                log(f"⏱️  {tag} 空间#{space_no}：请求全屏但未确认新增全屏空间 {name}")
        else:
            empties += 1
            time.sleep(0.3)
    if n == 0:
        log(f"·  {tag} 空间#{space_no}：无待处理窗口")
    return n

def process_display(d, tag):
    warp(d["cx"], d["cy"]); time.sleep(0.3)
    s = display_of(d["uuid"])
    if not s:
        log(f"·  显示器 {tag}：无法获取空间信息，跳过"); return 0
    spaces = s["spaces"]
    ids = [sid for sid, t, pid in spaces]
    desktops = [i for i, (sid, t, pid) in enumerate(spaces) if t == 0]  # type-0 = user desktop
    log(f"·  显示器 {tag}：共 {len(spaces)} 个空间，桌面(type0) {len(desktops)} 个")
    if not desktops:
        return 0

    # Home to the leftmost Space. We know the current index from the snapshot,
    # so press left just that many times (+1 buffer to absorb a dropped press),
    # instead of always pressing the full Space count. Over-pressing at the
    # edge is a harmless no-op; capping at len keeps it bounded.
    cur_idx = ids.index(s["current"]) if s["current"] in ids else len(spaces)
    for _ in range(min(cur_idx + 1, len(spaces))):
        press("left"); time.sleep(0.25)

    # Visit each desktop Space (skipping full-screen Spaces entirely) and retry
    # there. AX full-screening reaches windows on other Spaces of this display
    # too, so sitting on the desktop is enough — no need to walk every Space.
    total = 0
    physical = 0
    for di in desktops:
        while physical < di:
            press("right"); time.sleep(0.4); physical += 1
        total += scan_current(d, tag, f"桌面 idx{di}")
    return total

def main():
    log("🔍 启动前窗口快照："); debug_list()
    disps = displays()
    log("🖥️  显示器：" + ", ".join(
        f"{(d['uuid'] or '?')[:8]}@{int(d['cx'])},{int(d['cy'])}" for d in disps))
    log(f"🚀 开始全屏所有显示器、所有桌面上的 VSCode 窗口...（当前 Code 全屏空间 {code_fs_count()} 个）")

    front = osa_out('tell application "System Events" to get name of first process where frontmost is true')
    # Keep VSCode in the background: activating it hides its off-Space windows
    # from the AX list. Finder is a neutral frontmost app to park focus on.
    subprocess.run(["osascript", "-e", 'tell application "Finder" to activate'], capture_output=True)
    time.sleep(0.4)

    # Single pass by choice (favour speed): the SkyLight-confirmed step-back
    # fixes the reproducible straggler, so one pass catches everything in the
    # common case. AX enumeration is still non-deterministic, so a window can
    # occasionally be missed with no retry to recover it — re-run if the end
    # snapshot shows a leftover. Bump this to add confirming/retry passes.
    MAX_PASSES = 1
    total = 0
    for p in range(1, MAX_PASSES + 1):
        log(f"—— 第 {p} 遍 ——")
        pass_total = 0
        for d in disps:
            tag = (d["uuid"] or "?")[:8]
            log(f"▶️  切到显示器 {tag} @ {int(d['cx'])},{int(d['cy'])}")
            pass_total += process_display(d, tag)
        total += pass_total
        log(f"第 {p} 遍结束：本遍全屏 {pass_total} 个（累计 {total}）")
        if pass_total == 0:
            break

    if front:
        subprocess.run(["osascript", "-e", f'tell application "{front}" to activate'], capture_output=True)

    log("🔍 结束后窗口快照（fs=false 为残留；AX 枚举本身不稳定，仅供参考）："); debug_list()
    log(f"🎉 完成，共全屏 {total} 个窗口，总耗时 {el()}s")

main()
PYEOF
}
