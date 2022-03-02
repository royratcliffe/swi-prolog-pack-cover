# GitHub action for SWI-Prolog pack installation with test coverage

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
      - uses: royratcliffe/swi-prolog-pack-cover
```
