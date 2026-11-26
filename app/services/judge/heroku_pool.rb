module Judge
  # Each slot prepares a fresh dyno. A claimed dyno never returns to this pool.
  class HerokuPool
    def initialize(size: 2, factory: -> { HerokuDynoRunner.new.prepare }, idle_timeout: 840, retry_delay: 5)
      raise ArgumentError, "Judge pool size must be between 1 and 2" unless (1..2).cover?(size)

      @size, @factory, @idle_timeout, @retry_delay = size, factory, idle_timeout, retry_delay
      @mutex = Mutex.new
      @changed = ConditionVariable.new
      @ready = []
      @threads = []
      @running = false
    end

    def start
      @mutex.synchronize do
        return if @running

        @running = true
        @threads = Array.new(@size) { Thread.new { maintain_slot } }
      end
    end

    def running? = @mutex.synchronize { @running }
    def ready_count = @mutex.synchronize { @ready.size }

    def checkout(timeout: 40)
      deadline = now + timeout
      loop do
        session = @mutex.synchronize do
          loop do
            raise IOError, "Judge pool stopped" unless @running
            raise Timeout::Error, "Judge pool is warming" if now >= deadline

            available = @ready.shift
            if available
              Rails.logger.info("Judge ready pool: claimed, ready=#{@ready.size}")
              @changed.broadcast
              break available
            end
            @changed.wait(@mutex, deadline - now)
          end
        end
        return session if session.usable?

        session.close
      end
    end

    def stop
      @mutex.synchronize { @running = false; @changed.broadcast }
      @threads.each do |thread|
        next if thread.join(2)

        # Interrupt a bounded network connect; its ensure closes the attachment.
        thread.kill
        thread.join
      end
    end

    private

    def maintain_slot
      while running?
        session = nil
        claimed = false
        failed = false
        begin
          session = @factory.call
          @mutex.synchronize do
            if @running
              @ready << session
              Rails.logger.info("Judge ready pool: ready=#{@ready.size}, target=#{@size}")
              @changed.broadcast
              deadline = now + @idle_timeout
              while @running && @ready.include?(session) && now < deadline && session.usable?
                @changed.wait(@mutex, [ deadline - now, 1 ].min)
              end
              claimed = !@ready.delete(session)
            end
          end
        rescue StandardError => error
          failed = true
          # Exceptions can contain API credentials or rendezvous URLs.
          Rails.logger.warn("Judge ready pool: #{error.class}")
        ensure
          unless claimed
            @mutex.synchronize { @ready.delete(session) }
            session&.close
          end
        end
        @mutex.synchronize { @changed.wait(@mutex, @retry_delay) if @running && failed }
      end
    end

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
