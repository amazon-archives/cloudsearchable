module Cloudsearchable
  module Config

    # Encapsulates logic for setting options.
    module Options
      def self.included base
        base.extend ClassMethods
      end

      module ClassMethods
        # Get the defaults or initialize a new empty hash.
        def defaults
          @defaults ||= {}
        end

        # Reset the configuration options to the defaults.
        def reset
          settings.replace(defaults)
        end

        # Get the settings or initialize a new empty hash.
        def settings
          @settings ||= {}
        end

        # Define a configuration option with a default. Example usage:
        #   Options.option(:persist_in_safe_mode, :default => false)
        def option(name, options = {})
          defaults[name] = settings[name] = options[:default]

          define_method name do
            settings[name]
          end

          define_method "#{name}=" do |value|
            settings[name] = value
          end

          define_method "#{name}?" do
            !!settings[name]
          end

          define_method "reset_#{name}" do
            settings[name] = defaults[name]
          end
        end
      end
    end

  end
end
