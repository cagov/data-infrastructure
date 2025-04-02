# sqlfluff_pre_commit.py
import pathlib
import subprocess
import sys


def main():
    fnames = [str(pathlib.Path(*pathlib.Path(f).parts[1:])) for f in sys.argv[1:]]
    try:
        subprocess.run(
            [
                "sqlfluff",
                "fix",
                "--show-lint-violations",
                "--processes",
                "0",
                "--nocolor",
                "--disable-progress-bar",
                "--force",
                *fnames,
            ],
            capture_output=True,
            check=True,
            shell=True,
            cwd="transform",
        )
    except subprocess.CalledProcessError as e:
        print(f"SQLFluff found linting errors:\n{e.stdout.decode()}")
        sys.exit(e.returncode)


if __name__ == "__main__":
    main()
