module Danger
  class DangerCommitLint < Plugin
    NOOP_MESSAGE = 'All checks were disabled, nothing to do.'.freeze

    def check(config = {})
      @config = config

      if all_checks_disabled?
        warn NOOP_MESSAGE
      else
        check_messages
      end
    end

    private

    def check_messages
      for message in messages
        for klass in warning_checkers
          warn klass::MESSAGE if klass.fail? message
        end

        for klass in failing_checkers
          # rubocop:disable Style/SignalException
          fail klass::MESSAGE if klass.fail? message
          # rubocop:enable Style/SignalException
        end
      end
    end

    def checkers
      [SubjectLengthCheck, SubjectPeriodCheck, EmptyLineCheck]
    end

    def checks
      checkers.map(&:type)
    end

    def enabled_checkers
      checkers.reject { |klass| disabled_checks.include? klass.type }
    end

    def warning_checkers
      enabled_checkers.select { |klass| warning_checks.include? klass.type }
    end

    def failing_checkers
      enabled_checkers - warning_checkers
    end

    def all_checks_disabled?
      @config[:disable] == :all || disabled_checks.count == checkers.count
    end

    def disabled_checks
      @config[:disable] || []
    end

    def warning_checks
      return checks if @config[:warn] == :all
      @config[:warn] || []
    end

    def messages
      git.commits.map do |commit|
        (subject, empty_line) = commit.message.split("\n")
        { subject: subject, empty_line: empty_line }
      end
    end

    class CommitCheck
      def self.fail?(message)
        new(message).fail?
      end

      def initialize(message); end

      def fail?
        raise 'implement in subclass'
      end
    end

    class SubjectLengthCheck < CommitCheck
      MESSAGE = 'Please limit commit subject line to 50 characters.'.freeze

      def self.type
        :subject_length
      end

      def initialize(message)
        @subject = message[:subject]
      end

      def fail?
        @subject.length > 50
      end
    end

    class SubjectPeriodCheck < CommitCheck
      MESSAGE = 'Please remove period from end of commit subject line.'.freeze

      def self.type
        :subject_period
      end

      def initialize(message)
        @subject = message[:subject]
      end

      def fail?
        @subject.split('').last == '.'
      end
    end

    class EmptyLineCheck < CommitCheck
      MESSAGE = 'Please separate subject from body with newline.'.freeze

      def self.type
        :empty_line
      end

      def initialize(message)
        @empty_line = message[:empty_line]
      end

      def fail?
        @empty_line && !@empty_line.empty?
      end
    end
  end
end
