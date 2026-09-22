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
