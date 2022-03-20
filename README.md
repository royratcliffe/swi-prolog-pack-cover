# GitHub action for SWI-Prolog pack installation with test coverage

This GitHub action is designed for use when developing [SWI
Prolog](https://www.swi-prolog.org/) packages on GitHub, especially for
packages that incorporate C-based _foreign_ libraries. It simultaneously
compiles your Prolog pack project for all major platforms: macOS, Ubuntu
and Windows; it runs all tests with coverage and optionally updates a
Gist for automatic display of coverage shields.

Use it to perform continuous development and integration on GitHub while
running tests simultaneously against macOS, Windows and Ubuntu Linux
operating systems across the latest stable and development versions of
SWI-Prolog. This may not matter if you run tests locally and target your
own particular platform. Other pack users may be running on a different
operating system however and encounter issues when installing;
especially so if your pack incorporates C libraries.

## Usage

Too long, won't read! In short, apply the following guidelines to your
pack project repository on GitHub.

Copy and paste the following YAML to your pack project at
`.github/workflows/test.yaml` and commit the change. You will
immediately see GitHub spool up runners for macOS, Windows and Ubuntu at
the same time. After checking out your project repository, the runners
will then proceed to install SWI-Prolog either using Homebrew,
Chocolatey or APT depending on the runner's operating system. The pack
will install, then run tests with captured coverage statistics. You can see
the normal SWI-Prolog coverage report in the runner job logs.

```yaml
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

name: test

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
commit reference; actions do _not_ default to the main branch. Name the
workflow for the workflow-passing shield; naming it "test" means that
the green shield will report "test: passing."

## Action logs

The following snippet from the Ubuntu action log shows the summary statistics
along with other useful diagnostic messages.
```
Clauses in files:                      2
Clauses not covered:                   0
Failed clauses in files:               1
Number of files:                       1
{"cover": {"failed_in_file":1, "in_file":2, "not_covered":0}, "rel":"msgpackc/prolog/msgpackc.pl"}
Not covered:                    0.000000%
Failed in file:                50.000000%
Covered:                      100.000000%
raw/cov.json
raw/fail.json
```
Note the raw JSON lines at the end. They indicate successful shield Gist updates.

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
odd-minor release of SWI-Prolog. You also need to set up the environment
for the coverage step.

```yaml
      - uses: royratcliffe/swi-prolog-pack-cover@main
        env:
          GHAPI_PAT: ${{ secrets.GHAPI_PAT }}
          COVFAIL_GISTID: ${{ secrets.COVFAIL_GISTID }}
```

Add links to your README file as below, albeit after replacing the
organisation and Gist identifier with your own.

```markdown
[![test](https://github.com/royratcliffe/msgpackc-prolog/actions/workflows/test.yaml/badge.svg)](https://github.com/royratcliffe/msgpackc-prolog/actions/workflows/test.yaml)
![cov](https://shields.io/endpoint?url=https://gist.githubusercontent.com/royratcliffe/ccccef2ac1329551794f2a466ee61014/raw/cov.json)
![fail](https://shields.io/endpoint?url=https://gist.githubusercontent.com/royratcliffe/ccccef2ac1329551794f2a466ee61014/raw/fail.json)
```

## Failed in file

The Prolog coverage analyses the number of failed clauses. This is *not*
an entirely useful metric since some tests purposefully check for
failure. Raising an exception fails a predicate and triggers a count
within the failed-in-file tally and its derived percentage figure.
Failed clauses do not directly indicate a problem.

The solution inverts the colours for the fail shield: green for low
percentage, red for high. A project with a high coverage and low failure
shows green by green. Although an argument for *not* including the
_fail_ percentage in the shield badges on the project repository page
exists; it might mislead the casual observer. Either that, or arrange
for tests to never fail. Catch the failure instead and complete the
unit-test body for zero clause failures.

## No symbolic linking

Installing the pack involves building it using compiler tools if the
pack includes foreign libraries. SWI-Prolog cleverly uses symbolic links
when installing a pack on those operating systems that support it;
includes macOS and Linux. Important _not_ to link the pack. The default
`link(true)` complicates coverage-by-file filtering because it compares
source file paths relative to the installed pack directory.
