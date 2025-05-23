FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

SHELL ["/bin/bash", "-c"]



RUN apt update -qq

# Add gitlab-ci-ls binary for the Gitlab CI Language server
# https://github.com/alesbrelih/gitlab-ci-ls/releases
# used by vscode extension 'alesbrelih.gitlab-ci-ls'
ARG GITLAB_CI_LS_GITHUB_RELEASE_VERSION=1.0.3
ARG GITLAB_CI_LS_GITHUB_RELEASE_SHA256SUM=eadc401873fcb61604bb0cb3674f86b79dedfd72df82e696c2950d8ee45d80f8

RUN wget -qO gitlab-ci-ls-x86_64-unknown-linux-gnu https://github.com/alesbrelih/gitlab-ci-ls/releases/download/${GITLAB_CI_LS_GITHUB_RELEASE_VERSION}/gitlab-ci-ls-x86_64-unknown-linux-gnu && \
    echo "${GITLAB_CI_LS_GITHUB_RELEASE_SHA256SUM}  gitlab-ci-ls-x86_64-unknown-linux-gnu" | sha256sum --strict --check - && \
    mv gitlab-ci-ls-x86_64-unknown-linux-gnu /usr/local/bin/gitlab-ci-ls && \
    chmod +x /usr/local/bin/gitlab-ci-ls

