# builder img
FROM debian:stable-slim as rmq-statsd-builder
RUN apt update && \
    apt install --no-install-recommends -y curl xz-utils gcc g++ openssl ca-certificates git && \
    curl https://nim-lang.org/choosenim/init.sh -sSf | bash -s -- -y && \
    apt -y autoremove && apt -y clean && rm -r /tmp/*
WORKDIR /projects/
ENV PATH="/root/.nimble/bin:$PATH"
COPY rmq_statsd.* ./
COPY src ./src
RUN nimble build -d:release -l:"-flto" -t:"-flto" --opt:size --threads:on
RUN objcopy --strip-all -R .comment -R .comments rmq-statsd


# main img
FROM debian:stable-slim as release
WORKDIR /opt
COPY --from=rmq-statsd-builder /projects/rmq-statsd ./
COPY rmq-statsd.ini ./
ENTRYPOINT ["./rmq-statsd"]
