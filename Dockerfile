ARG EX_VSN=1.16.1
ARG OTP_VSN=26.2.2
ARG DEB_VSN=focal-20240123
ARG BUILDER_IMG="hexpm/elixir:${EX_VSN}-erlang-${OTP_VSN}-ubuntu-${DEB_VSN}"
ARG RUNNER_IMG="ubuntu:${DEB_VSN}"
FROM --platform=linux/amd64 ${BUILDER_IMG} AS builder

RUN apt-get update -y \
    && apt-get -y install openssh-client build-essential git ca-certificates curl gnupg rsync

ENV ERL_FLAGS="+JMsingle true"

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

RUN mkdir config

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix assets.deploy

RUN mix compile

COPY config/runtime.exs config/
COPY rel rel

RUN mix release

FROM ${RUNNER_IMG} AS runner

RUN apt-get update -y \
    && apt-get -y install libstdc++6 openssl libncurses5 locales \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"

WORKDIR "/app"
RUN chown nobody /app
ENV MIX_ENV="prod"

COPY --from=builder \
     --chown=nobody:root /app/_build/${MIX_ENV}/rel/my_app ./

USER nobody

CMD ["/app/bin/server"]
