# GitHub action for SWI-Prolog pack installation with test coverage

Why is this GitHub action repository useful? You can use it to perform
continuous development and integration on GitHub while running tests
simultaneously against macOS, Windows and Ubuntu Linux operating systems
across the latest stable and development versions of SWI-Prolog. This
may not matter if you run tests locally and target your own particular
platform. Other pack users may be running on a different operating
system however and encounter issues when installing; especially so if
your pack incorporates foreign libraries.

## Usage

Too long, won't read! In short, apply the following guidelines to your
pack project repository on GitHub.

Copy and paste the following YAML to your pack project at
`.github/workflows/pack-cover.yaml` and commit the change. You will
immediately see GitHub spool up runners for macOS, Windows and Ubuntu at
the same time. After checking out your project repository, the runners
will then proceed to install SWI-Prolog either using Homebrew,
Chocolatey or APT depending on the runner's operating system. The pack
will install, run tests with captured coverage statistics. You can see
the normal SWI-Prolog coverage report in the runner job logs.

```yaml
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

name: Pack install and test with coverage

jobs:
  run-tests:
    runs-on: ${{ matrix.os }}-latest
    name: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [macOS, Windows, Ubuntu]
    steps:
      - uses: actions/checkout@v2
      - uses: royratcliffe/swi-prolog-pack-cover@main
```

Note that `uses` requires a repository _and_ repository branch, tag or
commit reference; actions do _not_ default to the main branch.
