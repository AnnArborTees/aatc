module Aatc
  module Common
    extend self

    def require_rugged!
      return if defined?(Rugged)
      return unless require 'rugged'
      fail 'Could not require rugged. Run `gem install rugged`.'
    end

    def camelize(term)
      string = term.to_s
      string = string.sub(/^[a-z\d]*/) { $&.capitalize }
      string.gsub!(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{$2.capitalize}" }
      string.gsub!(/\//, '::')
      string
    end

    def config(force = false)
      if force || @config.nil?
        @config = YAML.load_file(config_file)
      else
        @config
      end
    end

    def save_config!
      File.open(config_file, 'w') do |f|
        f.write(config.to_yaml)
      end
    end

    def config_file
      CONFIG_PATH + '/apps.yml'
    end
  end
end
