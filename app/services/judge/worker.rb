module Judge
  class Worker
    def self.run(worker: Delayed::Worker.new(queues: [ "judge" ]), pool: configured_pool)
      HerokuDynoRunner.pool = pool
      pool&.start
      worker.start
    ensure
      pool&.stop
      HerokuDynoRunner.pool = nil
    end

    def self.configured_pool
      return unless ENV["JUDGE_HEROKU_APP"].present? && ENV["JUDGE_HEROKU_TOKEN"].present?

      size = Integer(ENV.fetch("JUDGE_READY_POOL_SIZE", "2"), 10)
      HerokuPool.new(size: size) unless size.zero?
    end
  end
end
