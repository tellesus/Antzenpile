"""Offline, committed-runtime Windows beta export. Python standard library only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE_SHA = "d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562"
PRESET = "Windows Systems Beta"
RUNTIME = ("project.godot", "src", "data", "scenes", "assets")


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def checked(command, *, cwd=ROOT, env=None, log=None):
    result = subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, check=False, timeout=120)
    output = result.stdout.decode("utf-8", errors="replace")
    if log:
        log.write_text(output, encoding="utf-8")
    if result.returncode or "SCRIPT ERROR:" in output or "ERROR:" in output:
        raise RuntimeError(f"Command failed ({result.returncode}); see {log or output}")
    return output.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--templates", required=True, type=Path)
    args = parser.parse_args()
    godot = args.godot.resolve(strict=True)
    template = (args.templates / "windows_release_x86_64.exe").resolve(strict=True)
    version = checked([str(godot), "--version"])
    if not version.startswith("4.7.2.stable."):
        raise RuntimeError(f"Wrong engine: {version}")
    if (args.templates / "version.txt").read_text().strip() != "4.7.2.stable":
        raise RuntimeError("Wrong template version")
    if sha(template) != TEMPLATE_SHA:
        raise RuntimeError("Release template differs from the verified official 4.7.2 archive")
    revision = checked(["git", "rev-parse", "HEAD"])
    cache = ROOT / ".godot" / "windows-beta"
    cache.mkdir(parents=True, exist_ok=True)
    builds = ROOT / "builds"
    builds.mkdir(exist_ok=True)
    # Unique directories: no recursive cleanup, no stale output carried into a package.
    work = Path(tempfile.mkdtemp(prefix="export-", dir=cache))
    source = work / "source"
    source.mkdir()
    source_zip = work / "committed-runtime.zip"
    checked(["git", "archive", "--format=zip", f"--output={source_zip}", revision, *RUNTIME])
    with zipfile.ZipFile(source_zip) as archive:
        for item in archive.infolist():
            target = (source / item.filename).resolve()
            if not target.is_relative_to(source.resolve()):
                raise RuntimeError("Runtime archive path escaped staging")
        archive.extractall(source)
    source_files = {p.relative_to(source).as_posix(): sha(p)
                    for p in sorted(source.rglob("*")) if p.is_file()}
    preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    preset = preset.replace('custom_template/release=""',
                            "custom_template/release=" + json.dumps(template.as_posix()))
    (source / "export_presets.cfg").write_text(preset, encoding="utf-8")
    # Export/import/smoke never touch the player's real slot or sound preferences.
    env = dict(os.environ, APPDATA=str(work / "user-data"))
    common = [str(godot), "--headless", "--path", str(source)]
    import_retried = False
    try:
        checked([*common, "--editor", "--import"], env=env, log=work / "import.log")
    except RuntimeError as error:
        first_log = (work / "import.log").read_text(encoding="utf-8")
        # Observed pinned Windows editor teardown fault after a complete cold import.
        # Only this exact exit may retry once; parse/import failures remain fatal.
        if ("(3221225477)" not in str(error) or "[ DONE ] reimport" not in first_log
                or "ERROR:" in first_log):
            raise
        import_retried = True
        checked([*common, "--editor", "--import"], env=env, log=work / "import-retry.log")
    folder = Path(tempfile.mkdtemp(prefix="Antzenpile-systems-beta-", dir=builds))
    package = folder / "Antzenpile"
    package.mkdir()
    exe = package / "Antzenpile.exe"
    checked([*common, "--export-release", PRESET, str(exe)], env=env, log=work / "export.log")
    # ZIP pack uses the same preset; audit actual exported paths, not guesses from res:// strings.
    audit_zip = work / "resources.zip"
    checked([*common, "--export-pack", PRESET, str(audit_zip)], env=env, log=work / "inventory.log")
    with zipfile.ZipFile(audit_zip) as archive:
        resources = [{"path": i.filename, "bytes": i.file_size,
                      "sha256": hashlib.sha256(archive.read(i)).hexdigest()}
                     for i in sorted(archive.infolist(), key=lambda i: i.filename) if not i.is_dir()]
    allowed = ("src/", "data/", "scenes/", "assets/", ".godot/")
    for entry in resources:
        name = entry["path"].removeprefix("res://")
        if (not name.startswith(allowed) and name != "project.binary") or name.startswith("src/debug/"):
            raise RuntimeError(f"Unexpected exported resource: {name}")
    for name in ("GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt", "ASSET_NOTICES.txt", "READ_ME_FIRST.txt"):
        shutil.copyfile(ROOT / "docs" / "distribution" / name, package / name)
    files = {p.name: {"bytes": p.stat().st_size, "sha256": sha(p)}
             for p in sorted(package.iterdir()) if p.is_file()}
    manifest = {"status": "systems beta; native player acceptance pending", "revision": revision,
                "engine": version, "release_template_sha256": TEMPLATE_SHA,
                "preset_sha256": sha(ROOT / "export_presets.cfg"), "cold_import_shutdown_retry": import_retried,
                "committed_runtime": source_files, "exported_resources": resources, "files": files}
    (package / "BUILD_MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    bundle = folder.with_suffix(".zip")
    with zipfile.ZipFile(bundle, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(package.iterdir()):
            archive.write(path, "Antzenpile/" + path.name)
    extracted = work / "extracted"
    with zipfile.ZipFile(bundle) as archive:
        archive.extractall(extracted)
    installed = extracted / "Antzenpile"
    for name, details in files.items():
        if sha(installed / name) != details["sha256"]:
            raise RuntimeError(f"Extracted file hash mismatch: {name}")
    checked([str(installed / "Antzenpile.exe"), "--headless",
             "--quit-after", "120", "--log-file", str(work / "main.log")], cwd=installed, env=env,
            log=work / "main-stdout.log")
    if "ERROR:" in (work / "main.log").read_text(encoding="utf-8"):
        raise RuntimeError("Extracted Main reported an error")
    # Official release templates prohibit external --script/--path overrides.
    # Use the pinned editor for deeper unchanged-PCK checks; actual release Main
    # is independently launched above, without external script/path overrides.
    checked([str(godot), "--headless", "--main-pack", str(installed / "Antzenpile.pck"),
             "--script", str(ROOT / "tools/package/release_smoke.gd"),
             "--log-file", str(work / "release-smoke.log")], cwd=installed, env=env,
            log=work / "release-smoke-stdout.log")
    checks = (work / "release-smoke.log").read_text(encoding="utf-8")
    if "ERROR:" in checks or "RELEASE PACKAGE CHECKS PASSED" not in checks:
        raise RuntimeError("Release boundary/save checks failed")
    latest = builds / "Antzenpile-systems-beta-windows.zip"
    shutil.copyfile(bundle, latest)
    result = {"zip": str(latest), "archived_zip": str(bundle), "zip_bytes": latest.stat().st_size, "zip_sha256": sha(latest),
              "launch": str(exe), "revision": revision, "resources": len(resources), "logs": str(work),
              "cold_import_shutdown_retry": import_retried,
              "checked": "isolated import/export/inventory/extraction/release Main; packed save-resume-review under pinned editor",
              "not_checked": "native graphics/audio/feel/performance/clean machine"}
    (builds / "windows-beta-latest.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
