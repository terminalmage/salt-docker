# salt-docker

A shell script and Dockerfile to aid in Salt development

## Problem

Getting a development environment up and running can take awhile, especially if
you are new to things like pyenv, virtualenvs, etc. Additionally, what if you
are developing on a Fedora machine and need to work on CentOS-related code, or
your dev box is Arch Linux and you need to work on Ubuntu-specific code?

Salt could use something to reduce development friction and make it easier to
start hacking on Salt.

## Solution

A while back, I collaborated on a project called
[barnacle](https://github.com/cachedout/barnacle), which is a collection of
Dockerfiles to set up an image, install the Salt depchain, and configure the
PYTHONPATH such that one could mount a clone of Salt into an instance of a
Docker image and run Salt against the current code in your git clone.

I have taken the concepts from that project and designed a Dockerfile (using
BuildKit-specific syntax) which can be used to create images for different
Linux distros. The Dockerfile builds Python using pyenv, and then creates a
virtualenv and installs the static requirements file used by Salt's CI
pipelines to ensure that all of the necessary libraries are present.

### Try It Out

This repo contains a Dockerfile which currently supports the following
platforms (and should be easily expandable to support others):

- Arch Linux
- Debian 10
- Debian 11
- Debian 12
- Ubuntu 20.04
- Ubuntu 22.04
- CentOS 7
- Rocky Linux 8
- Rocky Linux 9
- openSUSE Leap 15.4

If you want to try it out, you'll need the following:

- Docker >= 19.03
- [Docker Buildx](https://github.com/docker/buildx#installing) (may be included
  in the Docker package, but is packaged separately in some distros)
- git

To try this tool, clone this repo and add the repo dir to your `PATH`:

```bash
# Clone this repo
git clone https://github.com/terminalmage/salt-docker.git
# Add directory to path
export PATH="$PATH:$(realpath salt-docker)"
# cd to your clone of Salt
cd /path/to/git/clone/of/salt
```

**NOTE:** You can also just add the path to your clone of this repo to your
`PATH` via your shell rcfile.

Once you're in a git clone of Salt, you can use the `salt-docker` script to
build any of the supported platforms:

```
❯ salt-docker -h
USAGE: /home/erik/git/salt-docker [OPTIONS] [BUILD OPTIONS] platform [ -- ] [ command ]

    platform            The platform to use (see --list-platforms)
    command             Optional command to run in the container (use "--" to
                        explicitly separate the container command from the
                        script arguments)

OPTIONS:
    -h/--help           Show this message
    --list-platforms    Print the supported platforms to stdout
    --no-build          Skip docker build
    --no-run            Skip docker run

BUILD OPTIONS (ignored if --no-build is used):
    --no-cache          Disgregard cache for docker build (forces full rebuild)
    --image             Docker image name (default: saltdev)
    --locale            Locale to use (default: en_US.UTF-8)
    --python            Python to install into built image (default: 3.10.11)

RUN OPTIONS (ignored if --no-run is used):
    --mount SRC DEST    Bind-mounts SRC into the container at DEST

❯ salt-docker --list-platforms
archlinux
centos7
debian10
debian11
debian12
rocky8
rocky9
suseleap154
ubuntu20
ubuntu22
```

Once it is done building an image, `salt-docker` will `docker run` an instance
of the tagged image, mounting the root of the git repo into the container at
`/testing`. This will by default launch you into a bash shell, with Salt
configured to run masterless. This is ideal for state/execution module
development, as you can run everything through masterless `salt-call`:

```bash
❯ salt-docker ubuntu22
(saltdev) root@c230dce46e7a:/# salt-call --version
salt-call 3006.1+192.g23582dce20
(saltdev) root@c230dce46e7a:/# salt-call test.ping
local:
    True
(saltdev) root@c230dce46e7a:/# salt-call pkg.version bash
local:
    5.1-6ubuntu1
```

You can also pass additional positional arguments to the tool to run a command
(such as pytest) in the container and immediately exit (the container will be
removed automatically upon exit):

```bash
salt-docker ubuntu22 py.test -vvv /testing/tests/pytests/unit/modules/test_aptpkg.py
```

### Caveats

- Since this project uses the static pip requirements generated for use in
  Salt's test suite, if you use salt-docker to build an image for given
  platform, but come back later and run for example `salt-docker ubuntu22`, if
  the static requirements have changed, this will cause the image to be rebuilt
  with the updated requirements. If you would like to skip the `docker build`
  that salt-docker runs under-the-hood, simply run it with `--no-build`, for
  example:

  ```bash
  salt-docker --no-build ubuntu22
  ```

### Outstanding Needs/Questions

- Where should the Dockerfile and tool live? Ideally this would be merged into
  the salt codebase so that one can clone the Salt repo, run the script, make a
  sandwich, and come back and start hacking.

- The Dockerfile has some configuration to allow the container to run systemd
  as PID 1, but this is not fully built out and needs some additional work.
  Running systemd as PID 1 also requires additional CLI arguments to be added
  to your `docker run` (some `CAP_ADD`, bind mounting the cgroups into the
  container, etc.), which is another reason CLI tooling to manage launching
  containers will be useful.

- A lot of the functional tests use `platform.platform()` to handle marking
  tests as `skipif`. The problem with this is that inside a docker image,
  `platform.platform()` refers to the host machine's OS, not the one in the
  container. This means that if you are not on Debian/Ubuntu, you can't run
  these tests, even if you are running pytest from within an Ubuntu 22 Docker
  container. I spoke with @Ch3LL a bit about this, and (where available)
  `platform.freedesktop_os_release()` can be used to parse the
  `/etc/os-release` and adjust `skipif` conditions, falling back to
  `platform.platform()` where not available.

  ```python
  try:
      os_release = platform.freedesktop_os_release()
  except (AttributeError, OSError):
      os_release = {'ID': platform.platform()}
  ```

  Before updating the tests though, I'd want to settle on a solution acceptable
  to the core team, so feedback/suggestions would be welcome.
