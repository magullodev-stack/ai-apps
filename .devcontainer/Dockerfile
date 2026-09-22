FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openjdk-21-jdk-headless \
        ca-certificates \
        curl \
        git \
        unzip \
        xz-utils \
        zip \
        libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

ARG FLUTTER_REV=6a19cca56475dbfba1478ee68d7bd0c2ef891da1

RUN git clone --depth 1 --branch stable \
        https://github.com/flutter/flutter.git /opt/flutter \
    && cd /opt/flutter \
    && git fetch --depth 1 origin "$FLUTTER_REV" \
    && git checkout -B stable "$FLUTTER_REV" \
    && chown -R vscode:vscode /opt/flutter

ENV PATH="/opt/flutter/bin:${PATH}"

USER vscode

RUN flutter --version \
    && dart --version

# Android SDK para compilar aplicaciones Flutter.
USER root

ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH="${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/cmdline-tools/latest/bin:${PATH}"

RUN set -eu; \
    mkdir -p "${ANDROID_HOME}/cmdline-tools"; \
    curl -fL --retry 3 \
        https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
        -o /tmp/android-cmdline-tools.zip; \
    unzip -q /tmp/android-cmdline-tools.zip -d "${ANDROID_HOME}/cmdline-tools"; \
    mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" \
        "${ANDROID_HOME}/cmdline-tools/latest"; \
    rm /tmp/android-cmdline-tools.zip; \
    yes | sdkmanager --sdk_root="${ANDROID_HOME}" --licenses >/dev/null; \
    sdkmanager --sdk_root="${ANDROID_HOME}" \
        "platform-tools" \
        "platforms;android-36" \
        "build-tools;36.0.0"; \
    chown -R vscode:vscode "${ANDROID_HOME}"

USER vscode

RUN flutter config --android-sdk "$ANDROID_HOME" \
    && test -x "$ANDROID_HOME/platform-tools/adb"
