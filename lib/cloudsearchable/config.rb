require "cloudsearchable/config/options"

module Cloudsearchable

  # basic configuration for Cloudsearchable. Most of this code was patterned from Dynamoid.
  module Config
    extend self
    include Options

    option :domain_prefix, :default => defined?(Rails) ? "#{Rails.env}" : ""
    option :fatal_warnings, :default => defined?(Rails) && Rails.env.production? ? false : true
    option :logger, :default => defined?(Rails)

    # The default logger either the Rails logger or just stdout.
    def default_logger
      defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : ::Logger.new($stdout)
    end

    # Returns the assigned logger instance.
    def logger
      @logger ||= default_logger
    end

    # If you want to, set the logger manually to any output you'd like. Or pass false or nil to disable logging entirely.
    def logger=(logger)
      case logger
      when false, nil then @logger = nil
      when true then @logger = default_logger
      else
        @logger = logger if logger.respond_to?(:info)
      end
    end

  end
end
