import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


MOCK = r'''
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
event = name
if name == "nix":
    event = "copy" if args[0] == "copy" else (
        "cli-build" if args[-1].endswith(".home-pi-layat") else "manifest-build")
record = {"event": event, "args": args}
if name == "layat":
    record.update(home=os.environ["HOME"], xdg=os.environ.get("XDG_STATE_HOME"))
if name == "ssh":
    record["script"] = sys.stdin.read()
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps(record) + "\n")
if os.environ.get("FAIL_STAGE") == event:
    sys.exit(23)
if name == "nix" and args[0] == "build":
    assert "--no-update-lock-file" in args
    output = args[args.index("--out-link") + 1]
    path = os.environ["CLI_STORE" if event == "cli-build" else "MANIFEST_STORE"]
    Path(output).symlink_to(path)
elif name == "ssh":
    assert args[:3] == ["-T", "-o", "BatchMode=yes"]
    assert args[3] == "deploy@192.0.2.100"
    remote = shlex.split(args[4])
    assert remote[:3] == ["/run/current-system/sw/bin/bash", "-s", "--"]
    assert remote[3:5] == [os.environ["CLI_STORE"], os.environ["MANIFEST_STORE"]]
    script = record["script"].replace("/run/current-system/sw/bin/env", "env")
    script = script.replace("PATH=/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin",
                            'PATH="$TEST_PATH"')
    script = script.replace("/run/current-system/sw/bin/apply-blocky-config", "refresh")
    script = script.replace("/etc/blocky/", os.environ["FAKE_DEPLOYED"] + "/")
    result = subprocess.run(["bash", "-s", "--", os.environ["FAKE_CLI"],
                             os.environ["FAKE_MANIFEST"], remote[5]],
                            input=script, text=True)
    sys.exit(result.returncode)
elif name == "sudo":
    assert args[:2] == ["-n", "-H"]
    env = dict(os.environ, HOME=os.environ["ROOT_HOME"])
    sys.exit(subprocess.run(args[2:], env=env).returncode)
elif name == "layat":
    assert args == ["apply", "home-pi-blocky-lists", "--manifest", os.environ["FAKE_MANIFEST"]]
    assert os.environ["HOME"] == os.environ["ROOT_HOME"]
    assert "XDG_STATE_HOME" not in os.environ
    for name in ["allowlist.txt", "denylist.txt"]:
        source = Path(os.environ["FAKE_MANIFEST"], name).resolve()
        if os.environ.get("UNREADABLE_AFTER") == name:
            source = source.with_name("missing-source")
        Path(os.environ["FAKE_DEPLOYED"], name).symlink_to(source)
'''


def check_manifest_closure():
    manifest = Path(os.environ["BLOCKY_MANIFEST"])
    data = json.loads((manifest / "manifest.json").read_text())
    assert data["root"] == {"root": "/etc/blocky", "rootKind": "fixed"}
    entries = {entry["target"]: entry for entry in data["entries"]}
    assert set(entries) == {"allowlist.txt", "denylist.txt"}
    closure = set(Path("manifest-closure").read_text().splitlines())
    for target, expected in [("allowlist.txt", "EXPECTED_ALLOWLIST"),
                             ("denylist.txt", "EXPECTED_DENYLIST")]:
        entry = entries[target]
        assert entry["srcKind"] == "store" and entry["method"] == "symlink"
        source = Path(entry["src"]) / entry["subpath"]
        store_root = str(Path(*source.parts[:4]))
        assert store_root in closure, f"Missing from manifest closure: {store_root}"
        assert source.read_text() == os.environ[expected], target
    print("PASS: real manifest closure contains readable allow/deny lists with expected contents")


def main():
    check_manifest_closure()
    script = str(Path(sys.argv[1]).resolve())
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        repo = root / "repo with spaces"
        (repo / "hosts/home-pi/blocky").mkdir(parents=True)
        (repo / "child").mkdir()
        for file in ["flake.nix", "flake.lock", "hosts/home-pi/blocky/layat.nix"]:
            (repo / file).touch()
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        mock_bin = root / "mock-bin"
        mock_bin.mkdir()
        cli = root / "fake-cli"
        (cli / "bin").mkdir(parents=True)
        for path in [*(mock_bin / name for name in ["nix", "ssh", "sudo", "refresh"]),
                     cli / "bin/layat"]:
            path.write_text(f"#!{sys.executable}\n" + MOCK)
            path.chmod(0o755)
        log = root / "calls.jsonl"
        manifest_fixture = root / "fake-manifest"
        manifest_fixture.mkdir()
        (manifest_fixture / "manifest.json").write_text("{}")
        for name in ["allowlist.txt", "denylist.txt"]:
            source = root / name
            source.write_text("example.org\n")
            (manifest_fixture / name).symlink_to(source)
        deployed = root / "fake-blocky"
        deployed.mkdir()
        env = dict(os.environ,
                   PATH=f"{mock_bin}:{os.environ['PATH']}",
                   TEST_PATH=f"{mock_bin}:{os.environ['PATH']}",
                   HOME_PI_LOCAL_SYSTEM="x86_64-linux",
                   HOME_PI_SSH_TARGET="deploy@192.0.2.100",
                   MANIFEST_STORE="/nix/store/" + "0" * 32 + "-layat-manifest",
                   CLI_STORE="/nix/store/" + "1" * 32 + "-layat-0.1.0",
                   FAKE_MANIFEST=str(manifest_fixture), FAKE_DEPLOYED=str(deployed),
                   FAKE_CLI=str(cli), CALL_LOG=str(log), ROOT_HOME=str(root / "root"),
                   XDG_STATE_HOME="/unexpected-state")

        def run(args, *, cwd=repo / "child", failure="", succeeds=True,
                unreadable_after="", error=""):
            log.unlink(missing_ok=True)
            for path in deployed.iterdir():
                path.unlink()
            result = subprocess.run(["bash", "-euo", "pipefail", script, *args],
                                    cwd=cwd, env=dict(env, FAIL_STAGE=failure,
                                                     UNREADABLE_AFTER=unreadable_after),
                                    capture_output=True, text=True)
            assert (result.returncode == 0) == succeeds, result.stdout + result.stderr
            assert error in result.stderr, result.stderr
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            # Temporary out-links must be cleaned on success and failure.
            for call in calls:
                if call["event"].endswith("build"):
                    args = call["args"]
                    assert not Path(args[args.index("--out-link") + 1]).parent.exists()
            return calls

        assert run(["--help"]) == []
        for args in [["--repo"], ["--repo", "--refresh"], ["--unknown"]]:
            assert run(args, succeeds=False) == []
        assert run([], cwd=root, succeeds=False) == []
        assert run(["--repo", str(root)], succeeds=False) == []

        expected = ["manifest-build", "cli-build", "copy", "ssh", "sudo", "layat"]
        calls = run([])
        assert [call["event"] for call in calls] == expected
        assert calls[0]["args"][-1] == f"{repo}#layat.x86_64-linux.home-pi-blocky-lists"
        assert calls[1]["args"][-1] == f"{repo}#packages.aarch64-linux.home-pi-layat"
        assert calls[2]["args"] == ["copy", "--to", "ssh://deploy@192.0.2.100",
                                    env["MANIFEST_STORE"], env["CLI_STORE"]]
        calls = run(["--repo", str(repo), "--refresh"], cwd=root)
        assert [call["event"] for call in calls] == [*expected, "refresh"]
        for index, stage in enumerate([*expected, "refresh"]):
            calls = run(["--refresh"], failure=stage, succeeds=False)
            assert [call["event"] for call in calls] == [*expected, "refresh"][:index + 1]

        # A copied manifest with a dangling source must stop before layat.
        (root / "allowlist.txt").unlink()
        calls = run(["--refresh"], succeeds=False, error="Unreadable manifest source:")
        assert [call["event"] for call in calls] == expected[:4]
        (root / "allowlist.txt").write_text("example.org\n")

        # Unreadable deployed links must never be reported as success or refreshed.
        for name in ["allowlist.txt", "denylist.txt"]:
            calls = run(["--refresh"], unreadable_after=name, succeeds=False,
                        error="Unreadable deployed list:")
            assert [call["event"] for call in calls] == expected
        print("PASS: paths, profile identity, root environment, refresh and failure ordering")


if __name__ == "__main__":
    main()
