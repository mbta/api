# The one the elixir image was built with
FROM debian:stretch

RUN apt-get update && apt-get install -y --no-install-recommends \
		libssl1.1 libsctp1 curl \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /root

# Set exposed ports
EXPOSE 4000
ENV PORT=4000 MIX_ENV=prod TERM=xterm LANG=C.UTF-8 REPLACE_OS_VARS=true

ADD . rel/api
RUN mkdir /root/work

WORKDIR /root/work

CMD ["/root/rel/api/bin/startup", "foreground"]
