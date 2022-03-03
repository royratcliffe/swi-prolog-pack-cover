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

## Shield badges

If you set up a Gist, your project can utilise
[Shields](https://shields.io) to place coverage and failure badges on
your project's README page. Set up two repository secrets for your
actions; see variables below. Create a new Gist, a public one. Note its
Gist identifier. You also need a GitHub personal-access token with
_Create gists_ permissions.

  * Variable `COVFAIL_GISTID` for the Gist identifier.
  * Variable `GHAPI_PAT` for the private token.

The action only updates the shield on *one* selected operating system,
defaulting to Linux. Ubuntu Linux runs the development version of Prolog
so the shield images reflect coverage performance using the latest
odd-minor release. You also need to set up the environment for the
coverage step.

```yaml
      - uses: royratcliffe/swi-prolog-pack-cover@main
        env:
          GHAPI_PAT: ${{ secrets.GHAPI_PAT }}
          COVFAIL_GISTID: ${{ secrets.COVFAIL_GISTID }}
```

Add links to your README file as below, albeit after replacing the
organisation and Gist identifier with your own.

```markdown
![cov](https://shields.io/endpoint?url=https://gist.githubusercontent.com/royratcliffe/ccccef2ac1329551794f2a466ee61014/raw/cov.json)
![fail](https://shields.io/endpoint?url=https://gist.githubusercontent.com/royratcliffe/ccccef2ac1329551794f2a466ee61014/raw/fail.json)
```

## Failed in file

The Prolog coverage analyses the number of failed clauses. This is *not* an entirely useful metric since some tests purposefully check for failure. Raising an exception fails a predicate and triggers a count within the failed-in-file tally and its derived percentage figure. Failed clauses do not directly indicate a problem.

The solution inverts the colours for the fail shield: green for low percentage, red for high. A project with a high coverage and low failure shows green by green.

## No symbolic linking

Installing the pack involves building it using compiler tools if the
pack includes foreign libraries. SWI-Prolog cleverly uses symbol links
when installing a pack on those operating systems that support it;
includes macOS and Linux. Important _not_ to link the pack. The default
`link(true)` complicates coverage-by-file filtering because it compares
source file paths relative to the installed pack directory.
