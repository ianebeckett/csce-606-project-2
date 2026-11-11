module Judge
  class Runner
    class << self
      def build
        if ENV["JUDGE_HEROKU_APP"].present? || ENV["JUDGE_HEROKU_TOKEN"].present?
          return HerokuDynoRunner.new
        end
        return RemoteRunner.new if Rails.env.production? || ENV["JUDGE_URL"].present?

        DockerRunner.new
      end
    end
  end
end
