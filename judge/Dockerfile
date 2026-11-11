FROM python:3.15.2-slim-trixie@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928 AS python
FROM golang:1.27.3-trixie@sha256:af1bfc2614ebb1dbd31af514b78740fd678850e76498762b425ecee4c5c6ea80 AS golang
FROM ruby:4.0.1-slim-trixie@sha256:939bb2710ba0a49ffdba9470b4e562c9dfc5ee6718ba5a5214f1d421d0414d29 AS ruby
FROM gcc:16.2.0-trixie@sha256:9af8c7003ad451f09496c7182f320c58554e10ec080e7038e0aa5e41146c916b

COPY --from=python /usr/local/ /usr/local/
COPY --from=ruby /usr/local/ /usr/local/
COPY --from=golang /usr/local/go/ /usr/local/go/
ENV PATH="/usr/local/go/bin:${PATH}"

RUN test "$(python3 --version)" = "Python 3.15.2" \
    && test "$(go version | cut -d' ' -f3)" = "go1.27.3" \
    && test "$(g++ -dumpfullversion)" = "16.2.0" \
    && test "$(ruby -e 'print RUBY_VERSION')" = "4.0.1"

WORKDIR /judge
COPY main.rb runner.rb ./
USER 65534:65534
ENTRYPOINT ["timeout", "--signal=KILL"]
CMD ["55s", "ruby", "-rcoverage", "-e", "Coverage.start(lines: true) if ENV['JUDGE_COVERAGE'] == '1'; load '/judge/main.rb'"]
