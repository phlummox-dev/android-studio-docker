FROM gitpod/workspace-full-vnc:latest
SHELL ["/bin/bash", "-c"]

ARG USER_NAME=gitpod

# Install dart
USER root
# Install dart and other ubuntu packages
# Required packages for android studio:
# - https://developer.android.com/studio/install#64bit-libs
#   requires: libc6:i386 libncurses5:i386 libstdc++6:i386 lib32z1 libbz2-1.0:i386
# For flutter:
# - https://docs.flutter.dev/get-started/install/linux
#   (requires libglu1-mesa for `flutter test`)
# - desktop prereqs:
#   https://docs.flutter.dev/desktop#additional-linux-requirements
#   (clang, cmake, gtk dev headers, ninja, pkg-config)
USER root
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        apt-transport-https       \
        ca-certificates           \
        curl                      \
        gnupg \
    && curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && curl -fsSL https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list | \
            tee /etc/apt/sources.list.d/dart_stable.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential           \
        clang                     \
        cmake                     \
        dart                      \
        file                      \
        git                       \
        lib32z1                   \
        libbz2-1.0:i386           \
        libc6:i386                \
        libglu1-mesa              \
        libgtk-3-dev              \
        libncurses5:i386          \
        libstdc++6:i386           \
        ninja-build               \
        openjdk-11-jdk            \
        pkg-config                \
        pv                        \
        sudo                      \
        unzip                     \
        wget                      \
        xz-utils                  \
        zip                       \
    && \
    apt-get clean && \
    rm -rf /var/cache/apt/* && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /var/tmp/* && \
    update-java-alternatives --set java-1.11.0-openjdk-amd64 && \
    rm -rf /home/${USER_NAME}/.{rustup,pyenv,nvm} && \
    rm -rf /home/${USER_NAME}/{go,go-packages,linuxbrew} && \
    apt-get purge -y emacs-common

USER ${USER_NAME}

# Install flutter
# For Flutter SDK releases,
# see https://docs.flutter.dev/development/tools/sdk/releases

ARG FLUTTER_VERSION=2.8.1-stable
ARG FLUTTER_URL=https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}.tar.xz

RUN \
    curl -s ${FLUTTER_URL} | tar xf - --xz -C $HOME

## android command-line tools: from
## https://developer.android.com/studio/index.html#command-tools
## Handy to have them in addition to studio (as the studio-supplied ones
## seem not to work great with e.g. openjdk 11).

ARG ANDROID_TOOLS_ZIP=commandlinetools-linux-7583922_latest.zip
ARG ANDROID_TOOLS_URL=https://dl.google.com/android/repository/${ANDROID_TOOLS_ZIP}
ARG ANDROID_TOOLS_CHECKSUM=124f2d5115eee365df6cf3228ffbca6fc3911d16f8025bebd5b1c6e2fcfa7faf

# see https://developer.android.com/studio/command-line/variables
ENV ANDROID_HOME=/home/${USER_NAME}/Android/Sdk \
    ANDROID_SDK_ROOT=/home/${USER_NAME}/Android/Sdk

RUN  \
    cd $HOME && \
    wget -q $ANDROID_TOOLS_URL \
    && printf '%s  commandlinetools-linux-7583922_latest.zip' "$ANDROID_TOOLS_CHECKSUM" | sha256sum -c - \
    && mkdir -p $ANDROID_SDK_ROOT/cmdline-tools \
    && unzip -q commandlinetools-linux-*.zip -d /tmp \
    && rm -f commandlinetools-linux-*.zip \
    && mv /tmp/cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/latest

RUN  \
      yes  | $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager "platform-tools" "build-tools;31.0.0" "platforms;android-31"

ENV ANDROID_STUDIO_LOC=/opt/android-studio
ENV PATH=/home/${USER_NAME}/flutter/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH:$ANDROID_STUDIO_LOC/bin:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/platform-tools:$PATH

RUN echo "export ANDROID_HOME=$ANDROID_HOME" >> /home/${USER_NAME}/.bashrc \
    && echo "export ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT" >> /home/${USER_NAME}/.bashrc \
    && echo 'export PATH=/home/${USER_NAME}/flutter/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH:$ANDROID_STUDIO_LOC/bin:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/platform-tools:$PATH' >> /home/${USER_NAME}/.bashrc

# Install studio
ARG ANDROID_STUDIO_URL=https://dl.google.com/dl/android/studio/ide-zips/2020.3.1.26/android-studio-2020.3.1.26-linux.tar.gz
RUN  curl -s $ANDROID_STUDIO_URL | sudo tar xf - --gzip -C /opt

RUN \
  flutter config --android-studio-dir=$ANDROID_STUDIO_LOC \
  &&  yes | flutter doctor --android-licenses \
  && flutter doctor -v

RUN flutter/bin/flutter precache

USER root
# fix display resolution
RUN \
  sed -i 's/1920x1080/1280x720/' /usr/bin/start-vnc-session.sh

USER ${USER_NAME}

RUN \
  mkdir -p $HOME/.local/bin && \
  printf '\nPATH=$HOME/.local/bin:$PATH\n' | \
      tee -a /home/${USER_NAME}/.bashrc && \
  ln -s /opt/android-studio/bin/studio.sh \
    /home/${USER_NAME}/.local/bin/android_studio && \
  : "if running locally (vs using gitpod in cloud) need to create /workspace " && \
  sudo mkdir -p /workspace/.gradle && \
  sudo chown -R ${USER_NAME}:${USER_NAME} /workspace


## For Qt WebEngine on docker
ENV QTWEBENGINE_DISABLE_SANDBOX 1

ARG caches_url="https://github.com/phlummox-dev/gitpod-android-studio-docker/releases/download/v0.1.3/cached-stuff.txz"

RUN \
  : "customize studio install and add caches"       && \
  yes | sdkmanager --install 'build-tools;32.0.0'   && \
  yes | sdkmanager --install 'platforms;android-32' && \
  curl -L ${caches_url} | tar xf - --xz -C ~        && \
  yes | flutter doctor --android-licenses

