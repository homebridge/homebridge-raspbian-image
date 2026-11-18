# Tests

These tests check the scripts in this repo without building an image.

- Run them all: `tests/run.sh`
- Run one: `tests/run.sh nginx` (any part of the file name)
- They need Linux with `bash`, `dash`, `jq`, `git`, `python3` and `python3-yaml` (and `nginx` and `openssl` for the nginx checks). On a Mac, run them in a container:

```sh
docker run --rm -v "$PWD":/repo -w /repo debian:trixie sh -c \
  'apt-get update -qq && apt-get install -y -qq bash dash git jq nginx openssl python3 python3-yaml >/dev/null && tests/run.sh'
```

How they work:

- A test copies a script into a scratch folder and rewrites its system paths to that folder.
- Fake commands (`systemctl`, `curl`, `apt-get` ...) are put first on the `PATH`. They only write down
  how they were called.
- So nothing on the machine is changed, and no `sudo` is needed.

The pull request workflow (`.github/workflows/ci.yml`) runs them, together with `shellcheck` and
`actionlint`.

A full image can not be tested this way. The image build has its own check (`scripts/check-image.sh`)
that looks inside the finished image before a release is made.
