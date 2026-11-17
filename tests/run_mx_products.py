#!/usr/bin/env python3
"""Run standalone numerical regressions without a Spike installation."""
import argparse
import pathlib
import shlex
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cxx", default="c++")
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="gemmini-mx-products-") as temporary:
        for mode in ("legacy", "full-bf16"):
            executable = pathlib.Path(temporary) / mode
            command = shlex.split(args.cxx) + ["-std=c++17", "-O2", "-I", str(root)]
            if mode == "full-bf16":
                command += ["-DGEMMINI_MX_BF16_ARITH"]
            subprocess.run(
                command + [str(root / "tests/mx_products.cc"), "-o", str(executable)], check=True
            )
            subprocess.run([str(executable)], check=True)


if __name__ == "__main__":
    main()
