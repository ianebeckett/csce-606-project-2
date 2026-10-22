FROM ruby:4.0.1-slim@sha256:939bb2710ba0a49ffdba9470b4e562c9dfc5ee6718ba5a5214f1d421d0414d29
WORKDIR /judge
COPY main.rb runner.rb ./
USER 65534:65534
ENTRYPOINT ["timeout", "--signal=KILL"]
CMD ["6s", "ruby", "-rcoverage", "-e", "Coverage.start(lines: true) if ENV['JUDGE_COVERAGE'] == '1'; load '/judge/main.rb'"]
