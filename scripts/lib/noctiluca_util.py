"""xdg dirs and file writes that only touch a file when it changed."""
import os
import tempfile
from pathlib import Path


def config_dir() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")


def data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")


def state_dir() -> Path:
    base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(base) / "noctiluca"


def fixed_hue() -> float | None:
    """The accent hue chosen in the settings app, or None when it follows the wallpaper."""
    import json
    try:
        doc = json.loads((config_dir() / "noctiluca" / "settings.json").read_text())
        look = doc.get("appearance") or {}
        if look.get("accent") == "fixed":
            return float(look.get("hue", 186)) % 360
    except (OSError, ValueError, TypeError, AttributeError):
        pass
    return None


def atomic_write(path: Path, text: str, mode: int | None = None) -> bool:
    """atomic write, skipped if nothing changed. True if it wrote"""
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not path.is_symlink() and path.read_text() == text:
        return False
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".tmp-")
    with os.fdopen(fd, "w") as f:
        f.write(text)
    if mode is not None:
        os.chmod(tmp, mode)
    os.replace(tmp, path)
    return True
