
flow of info is:

- Makefile is preferred source of truth
  for names, versions, etc.
- Then current env vars
- build.py uses these to generate command-line invocations
  of docker
- preferred way to build is to invoke build.py, not use makefile
  targets

