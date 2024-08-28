ARG PYTHON_VERSION=3.11
ARG BASE_IMAGE=python:${PYTHON_VERSION}-alpine

FROM ${BASE_IMAGE}

# Install necessary dependencies
RUN apk update && \
    apk -U upgrade && \
    apk add --no-cache \
        ca-certificates \
        openssl \
        linux-headers \
        build-base \
        libmagic \
        bash \
        curl \
        g++ \
        gcc \
        musl-dev \
        py3-virtualenv \ 
        tini

ENV STRIVE_UID=1000
RUN addgroup -g $STRIVE_UID strive && \
    adduser -D -h /home/strive -G strive -s /bin/bash -u $STRIVE_UID strive && \
    addgroup strive root && \
    chmod g+w -R /etc/ssl

# Remove old setuptools and install the latest version globally
RUN pip uninstall -y setuptools && \
    pip install --no-cache-dir "setuptools>=70.0.0"

# Install Poetry and create virtual environment
ARG POETRY_VERSION=1.7.1
WORKDIR /kserve
RUN pip install --no-cache-dir virtualenv && \
    virtualenv /kserve/.venv && \
    /kserve/.venv/bin/pip install --no-cache-dir --upgrade pip && \
    /kserve/.venv/bin/pip install "poetry==$POETRY_VERSION"

# Configure Poetry with CodeArtifact
ARG AWS_TOKEN_TIMESTAMP
RUN --mount=type=secret,id=AWS_PIP_TOKEN \
    /kserve/.venv/bin/poetry config repositories.codeartifact "https://striveworks-724664234782.d.codeartifact.us-east-1.amazonaws.com/pypi/striveworks/simple" && \
    /kserve/.venv/bin/poetry config http-basic.codeartifact aws "$(cat /run/secrets/AWS_PIP_TOKEN)"

ENV PATH="/kserve/.venv/bin:$PATH"

COPY kserve/README.md kserve/pyproject.toml kserve/poetry.lock /kserve/
RUN poetry install --no-root --no-interaction --no-cache --extras "storage"
COPY kserve/kserve /kserve/kserve
RUN poetry install --no-interaction --no-cache --extras "storage"

#RUN pip install --no-cache-dir krbcontext==0.10 hdfs~=2.6.0 requests-kerberos==0.14.0

COPY third_party third_party
COPY ./storage-initializer /storage-initializer

RUN chmod +x /storage-initializer/scripts/initializer-entrypoint
RUN mkdir /work
WORKDIR /work

USER 1000
ENTRYPOINT ["/storage-initializer/scripts/initializer-entrypoint"]
