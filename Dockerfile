ARG ELIXIR_VERSION=1.14.3
ARG ERLANG_VERSION=25.2.2
ARG ALPINE_VERSION=3.17.0

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-alpine-${ALPINE_VERSION} as builder

WORKDIR /root

# Install Hex+Rebar
RUN mix local.hex --force && \
  mix local.rebar --force

RUN apk add --update git make build-base erlang-dev

ENV MIX_ENV=prod BUILD_WITHOUT_QUIC=1

ADD apps apps
ADD config config
ADD mix.* /root/

RUN mix do deps.get --only prod, phx.swagger.generate, compile, phx.digest
RUN mix eval "Application.ensure_all_started(:tzdata); Tzdata.DataBuilder.load_and_save_table()"

ADD rel/ rel/

RUN mix release

# The one the elixir image was built with
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache libssl1.1 dumb-init libstdc++ libgcc ncurses-libs && \
    mkdir /work /api && \
    adduser -D api && chown api /work

COPY --from=builder /root/_build/prod/rel/api_web /api

# Set exposed ports
EXPOSE 4000
ENV PORT=4000 MIX_ENV=prod TERM=xterm LANG=C.UTF-8 \
    ERL_CRASH_DUMP_SECONDS=0 RELEASE_TMP=/work

USER api
WORKDIR /work

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

HEALTHCHECK CMD ["/api/bin/api_web", "rpc", "1 + 1"]
CMD ["/api/bin/api_web", "start"]
