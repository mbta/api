FROM elixir:1.9.1 as builder

WORKDIR /root

# Install Hex+Rebar
RUN mix local.hex --force && \
  mix local.rebar --force

ENV MIX_ENV=prod

ADD apps apps
ADD config config
ADD mix.* /root/

RUN mix do deps.get --only prod, phx.swagger.generate, compile, phx.digest

ADD rel/ rel/

RUN mix distillery.release --verbose

# The one the elixir image was built with
FROM debian:stretch

RUN apt-get update && apt-get install -y --no-install-recommends \
		libssl1.1 libsctp1 curl dumb-init \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /root

COPY --from=builder /root/_build/prod/rel/api_web /root/rel
COPY --from=builder /root/rel/bin/startup /root/rel/bin/

# Set exposed ports
EXPOSE 4000
ENV PORT=4000 MIX_ENV=prod TERM=xterm LANG=C.UTF-8 REPLACE_OS_VARS=true

RUN mkdir /root/work

WORKDIR /root/work

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["/root/rel/bin/startup", "foreground"]
