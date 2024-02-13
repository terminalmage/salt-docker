# vim: et sw=4 ts=4 sts=4

ARG base_image
ARG platform
ARG locale=en_US.UTF-8
ARG pyenv_path=/root/.pyenv
ARG pyenv_url="https://github.com/pyenv/pyenv.git"
ARG python_release=3.10.11
ARG requirements_path=/root/.requirements
ARG requirements_type=linux
ARG salt_source=/testing
ARG venv_path=/root/.virtualenvs/saltdev
ARG path=$venv_path/bin:$pyenv_path/shims:$pyenv_path/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

##############################################################################
# STAGE:        base
# DESCRIPTION:  Perform tasks common to all platforms
##############################################################################

FROM $base_image AS base

# Pull in arg(s) from global build context
ARG salt_source
ARG venv_path

# Make sure /var/tmp exists
RUN test -e /tmp || ln -s /var/tmp /tmp

# Create some dirs for Salt
RUN mkdir -p /etc/salt/master.d /etc/salt/minion.d /etc/salt/proxy.d /etc/salt/cloud.conf.d /etc/salt/cloud.deploy.d /etc/salt/cloud.maps.d /etc/salt/cloud.profiles.d /etc/salt/cloud.providers.d /etc/salt/pki /srv/salt /srv/pillar

# Make the image default to masterless
RUN cat >/etc/salt/minion <<EOF
# Comment this out to run Salt with a non-masterless minion
file_client: local
# Ignored if file_client is set to local
master: localhost
EOF

# Create a pillar top file and empty pillar SLS file
RUN cat >/srv/pillar/top.sls <<EOF
base:
  test:
    - test
EOF

# Create blank test pillar file
RUN touch /srv/pillar/test.sls

# Set the minion ID
RUN echo test >/etc/salt/minion_id

# Create shell wrappers to run Salt in a virtualenv
RUN <<EOF
for cmd in salt salt-api salt-call salt-cloud salt-cp salt-extend salt-factories salt-key salt-master salt-minion salt-proxy salt-run salt-ssh salt-syndic spm; do
    cat >/usr/bin/$cmd <<ENDSCRIPT
#!/bin/bash

$venv_path/bin/python $salt_source/scripts/$cmd "\$@"
ENDSCRIPT
    chmod 0755 /usr/bin/$cmd
done
EOF

# ----------------------------------------------------------------------------
#
# BEGIN PLATFORM-SPECIFIC STAGES
#
# ----------------------------------------------------------------------------

##############
# BEGIN Arch #
##############################################################################
# STAGE:        platform_archlinux
# DESCRIPTION:  Perform tasks needed on Arch Linux
##############################################################################

FROM base AS platform_archlinux

# Pull in arg(s) from global build context
ARG locale

# Install pyenv build deps
RUN pacman -Syyu --noconfirm --needed base-devel openssl zlib xz tk
# Install other packages
RUN pacman -Su --noconfirm --needed git wget curl vim iproute2 openssh openssl man man-pages

# Make sure locale is available
RUN echo "$locale UTF-8" > /etc/locale.gen
RUN locale-gen

#######################
# BEGIN Debian/Ubuntu #
##############################################################################
# STAGE:        platform_debian_common
# DESCRIPTION:  Perform tasks needed on all Debian/Ubuntu platforms
##############################################################################

FROM base AS platform_debian_common

# Pull in arg(s) from global build context
ARG locale

RUN apt-get update
# Install pyenv build deps
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev libcurl4-openssl-dev
# Install other packages
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install git wget curl vim iproute2 openssh-server man-db less locales tree

# Make sure locale is available
RUN echo "$locale UTF-8" > /etc/locale.gen
RUN locale-gen

##############################################################################
# STAGE:        platform_debian10
# DESCRIPTION:  Perform tasks unique to Debian 10 (Buster)
##############################################################################

FROM platform_debian_common AS platform_debian10

##############################################################################
# STAGE:        platform_debian11
# DESCRIPTION:  Perform tasks unique to Debian 11 (Bullseye)
##############################################################################

FROM platform_debian_common AS platform_debian11

##############################################################################
# STAGE:        platform_debian12
# DESCRIPTION:  Perform tasks unique to Debian 12 (Bookworm)
##############################################################################

FROM platform_debian_common AS platform_debian12

##############################################################################
# STAGE:        platform_ubuntu20
# DESCRIPTION:  Perform tasks unique to Ubuntu 20.04 LTS (Focal Fossa)
##############################################################################

FROM platform_debian_common AS platform_ubuntu20

##############################################################################
# STAGE:        platform_ubuntu22
# DESCRIPTION:  Perform tasks unique to Ubuntu 22.04 LTS (Jammy Jellyfish)
##############################################################################

FROM platform_debian_common AS platform_ubuntu22

########################
# BEGIN CentOS / Rocky #
##############################################################################
# STAGE:        platform_centos_common
# DESCRIPTION:  Perform tasks needed on all CentOS platforms
##############################################################################

FROM base AS platform_centos_common

ARG locale

RUN yum -y install epel-release
# Install pyenv build deps
RUN yum -y --skip-broken install gcc gcc-c++ make patch zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel libcurl-devel
# Install other packages
RUN yum -y --skip-broken install git wget curl vim iproute openssh-server man man-pages tree langpacks-${locale%%_*}

##############################################################################
# STAGE:        platform_centos7
# DESCRIPTION:  Perform tasks unique to CentOS 7
##############################################################################

FROM platform_centos_common AS platform_centos7

# Pull in arg(s) from global build context
ARG path
ARG pyenv_path
ARG pyenv_url
ARG python_release

# Newer python needs openssl 1.1 on CentOS 7, since 1.0 is no longer supported
RUN yum -y install openssl11-devel
RUN git clone "$pyenv_url" "$pyenv_path"
RUN PATH=$path CPPFLAGS="-I/usr/include/openssl11" LDFLAGS="-L/usr/lib64/openssl11" pyenv install "$python_release"

##############################################################################
# STAGE:        platform_rocky_common
# DESCRIPTION:  Perform tasks needed on all releases of Rocky Linux
##############################################################################

FROM platform_centos_common AS platform_rocky_common

# Pull in arg(s) from global build context
ARG locale

RUN dnf -y install findutils passwd

##############################################################################
# STAGE:        platform_rocky8
# DESCRIPTION:  Perform tasks unique to Rocky Linux 8
##############################################################################

FROM platform_rocky_common AS platform_rocky8

##############################################################################
# STAGE:        platform_rocky9
# DESCRIPTION:  Perform tasks unique to Rocky Linux 9
##############################################################################

FROM platform_rocky_common AS platform_rocky9

##################
# BEGIN openSUSE #
##############################################################################
# STAGE:        platform_opensuse_common
# DESCRIPTION:  Perform tasks needed on all openSUSE platforms
##############################################################################

FROM base AS platform_opensuse_common

# Install pyenv build deps
run zypper --non-interactive install gcc gcc-c++ automake bzip2 libbz2-devel xz xz-devel openssl-devel ncurses-devel readline-devel zlib-devel tk-devel libffi-devel sqlite3-devel gdbm-devel make findutils patch
# Install other packages
RUN zypper --non-interactive install git wget curl vim iproute2 openssh man man-pages tree tar

##############################################################################
# STAGE:        platform_suseleap154
# DESCRIPTION:  Perform tasks unique to openSUSE Leap 15.4
##############################################################################

FROM platform_opensuse_common AS platform_suseleap154

# ----------------------------------------------------------------------------
#
# END PLATFORM-SPECIFIC STAGES
#
# ----------------------------------------------------------------------------

##############################################################################
# STAGE:        finalize
# DESCRIPTION:  Perform tasks which must happen after platform-specific stages
#               have completed (build Python, setup virtualenv, etc.)
##############################################################################

FROM platform_$platform as finalize

# Pull in arg(s) from global build context
ARG locale
ARG path
ARG pyenv_path
ARG pyenv_url
ARG python_release
ARG requirements_path
ARG requirements_type
ARG salt_source
ARG venv_path

# Turn on password auth for root user, for cases when running this container
# with systemd as PID 1.
RUN sed -i 's/.*PermitRootLogin.\+/PermitRootLogin yes/' /etc/ssh/sshd_config

# Set root password to "changeme" and force a change on first login
RUN echo root:changeme | chpasswd
RUN passwd --expire root

# Allow git describe to work inside bind-mounted clone of Salt source code
RUN git config --global --add safe.directory $salt_source

# Clone and build pyenv, unless these were already done in the platform-specific tasks
RUN test -d "$pyenv_path" || git clone "$pyenv_url" "$pyenv_path"
RUN PATH=$path pyenv versions --bare --skip-aliases --skip-envs | grep -Fqx "$python_release" || PATH=$path pyenv install "$python_release"

# Create virtualenv and update pip within it
RUN "$pyenv_path/versions/$python_release/bin/python" -mvenv "$venv_path"
RUN "$venv_path/bin/pip" install --upgrade pip

# Ensure that root user is activated into virtualenv on login
RUN cat >>/root/.bashrc <<EOF

# Activate into virtualenv
. "$venv_path/bin/activate"
EOF

# Copy the requirements files
RUN mkdir -p "$requirements_path"
COPY --from=requirements static/ci/ "$requirements_path"/

# Install Python packages into virtualenv. Include a workaround to get PyYAML
# 5.4.1 to build since it is broken with Cython 3.0. Note that the salt project
# has since upgraded to PyYAML 6 in their requirements files, but this
# workaround will cover cases where you're testing a commit that is still on
# 5.4.1. For cases where PyYAML 6 is being used, the 5.4.1 version installed by
# the workaround will be replaced with the newer version of PyYAML. when the
# requirements file is installed.
ARG constraint_file=/constraint.txt
RUN "$venv_path/bin/pip" install "Cython < 3.0"
RUN echo 'Cython < 3.0' >$constraint_file; PIP_CONSTRAINT=$constraint_file "$venv_path/bin/pip" install "pyyaml==5.4.1" && rm $constraint_file
RUN "$venv_path/bin/pip" install -r "${requirements_path}/py${python_release%.*}/${requirements_type}.txt"

# Install additional python packages for development
RUN "$venv_path/bin/pip" install pudb pytest

# Add a pudb.cfg which gets rid of welcome message and turns on line numbers
RUN mkdir -p /root/.config/pudb
RUN cat >/root/.config/pudb/pudb.cfg <<EOF
[pudb]
breakpoints_weight = 1
current_stack_frame = top
custom_shell =
custom_stringifier =
custom_theme =
default_variables_access_level = public
display = auto
hide_cmdline_win = False
hotkeys_breakpoints = B
hotkeys_code = C
hotkeys_stack = S
hotkeys_variables = V
line_numbers = True
prompt_on_quit = True
seen_welcome = e999
shell = internal
sidebar_width = 0.5
stack_weight = 1
stringifier = default
theme = classic
variables_weight = 1
wrap_variables = True
EOF

# Setup environment
ENV PATH=$path
ENV PYTHONPATH=$salt_source
ENV LANG=$locale
ENV LC_ALL=$locale
VOLUME $salt_source
