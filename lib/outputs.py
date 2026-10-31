#!/usr/bin/env python3
"""Convert `niri msg --json outputs` into a niri outputs.kdl fragment.

Reads JSON on stdin, writes KDL on stdout. Exits 1 when the JSON does not
look like the expected schema, so the caller can fall back to auto-detect.
"""

import json
import sys


def fmt_refresh(value):
    """niri reports refresh_rate in millihertz (60002 = 60.002 Hz)."""
    try:
        rate = float(value)
    except (TypeError, ValueError):
        return None
    if rate >= 1000:  # mHz; anything smaller is already Hz
        rate /= 1000.0
    return f"{rate:.3f}"


def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 1

    if not isinstance(data, dict) or not data:
        return 1

    lines = []
    found = False

    for name, out in data.items():
        if not isinstance(out, dict):
            continue
        if out.get("active") is False:
            continue

        logical = out.get("logical") or {}
        scale = logical.get("scale", 1.0)
        transform = str(logical.get("transform", "normal")).lower()
        x = logical.get("x", 0)
        y = logical.get("y", 0)

        mode = None
        modes = out.get("modes") or []
        idx = out.get("current_mode")
        if isinstance(idx, int) and 0 <= idx < len(modes):
            mode = modes[idx]
        elif modes:
            mode = next((m for m in modes if m.get("is_preferred")), modes[0])

        lines.append(f'output "{name}" {{')
        if isinstance(mode, dict):
            w = mode.get("width")
            h = mode.get("height")
            r = fmt_refresh(mode.get("refresh_rate"))
            if w and h:
                if r:
                    lines.append(f'    mode "{w}x{h}@{r}"')
                else:
                    lines.append(f'    mode "{w}x{h}"')
        try:
            lines.append(f"    scale {float(scale):g}")
        except (TypeError, ValueError):
            lines.append("    scale 1.0")
        if transform and transform != "normal":
            lines.append(f'    transform "{transform}"')
        try:
            if int(x) or int(y):
                lines.append(f"    position x={int(x)} y={int(y)}")
        except (TypeError, ValueError):
            pass
        lines.append("}")
        lines.append("")
        found = True

    if not found:
        return 1

    sys.stdout.write("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
