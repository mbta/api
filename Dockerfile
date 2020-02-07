FROM erlang:22.0 as builder

# elixir expects utf8.
ENV ELIXIR_VERSION="v1.9.1" \
	LANG=C.UTF-8

RUN set -xe \
	&& ELIXIR_DOWNLOAD_URL="https://github.com/elixir-lang/elixir/archive/${ELIXIR_VERSION}.tar.gz" \
	&& ELIXIR_DOWNLOAD_SHA256="94daa716abbd4493405fb2032514195077ac7bc73dc2999922f13c7d8ea58777" \
	&& curl -fSL -o elixir-src.tar.gz $ELIXIR_DOWNLOAD_URL \
	&& echo "$ELIXIR_DOWNLOAD_SHA256  elixir-src.tar.gz" | sha256sum -c - \
	&& mkdir -p /usr/local/src/elixir \
	&& tar -xzC /usr/local/src/elixir --strip-components=1 -f elixir-src.tar.gz \
	&& rm elixir-src.tar.gz \
	&& cd /usr/local/src/elixir \
	&& make install clean

WORKDIR /root

# Install Hex+Rebar
RUN mix local.hex --force && \
  mix local.rebar --force

ENV MIX_ENV=prod

ADD apps apps
ADD config config
ADD mix.* /root/

RUN elixir --erl "-smp enable" /usr/local/bin/mix do deps.get --only prod, phx.swagger.generate, compile, phx.digest

ADD rel/ rel/

RUN elixir --erl "-smp enable" /usr/local/bin/mix distillery.release --verbose

ADD rel rel

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
