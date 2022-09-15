ARG ELIXIR_VERSION=1.13.4
ARG ERLANG_VERSION=24.3.4.5
ARG ALPINE_VERSION=3.16.2

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-alpine-${ALPINE_VERSION} as builder

WORKDIR /root

# Install Hex+Rebar
RUN mix local.hex --force && \
  mix local.rebar --force

RUN apk add --update git make build-base erlang-dev

ENV MIX_ENV=prod

ADD apps apps
ADD config config
ADD mix.* /root/

RUN mix do deps.get --only prod, phx.swagger.generate, compile, phx.digest

ADD rel/ rel/

RUN mix release

# The one the elixir image was built with
FROM alpine:${ALPINE_VERSION}

RUN apk add --update libssl1.1 curl bash dumb-init libstdc++ libgcc \
  && rm -rf /var/cache/apk/*

WORKDIR /root

COPY --from=builder /root/_build/prod/rel/api_web /root/rel

# Set exposed ports
EXPOSE 4000
ENV PORT=4000 MIX_ENV=prod TERM=xterm LANG=C.UTF-8 REPLACE_OS_VARS=true

RUN mkdir /root/work

WORKDIR /root/work

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["/root/rel/bin/api_web", "start"]
