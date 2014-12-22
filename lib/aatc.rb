require "aatc/version"

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
  end

  extend Common

  SUBCOMMANDS = {
    test: 'test',
    apps: 'app', add_app: 'app', apps_dir: 'app',
    close: 'close'
  }

  class << self
    attr_accessor :debug
    def debug?; debug; end

    def run(argv)
      if argv.empty?
        fail 'Please specify a subcommand at least!'
      end

      argv.each_with_index do |arg, index|
        if arg[0] == '-'
          process_param(arg)
        else
          run_subcommand(arg, argv[index+1..-1])
          break
        end
      end
    end

    def run_subcommand(subcommand, args)
      subcmd_method = subcommand.gsub('-', '_').to_sym
      case subcmd_method
      when *SUBCOMMANDS.keys
        location = SUBCOMMANDS[subcmd_method]
        require "aatc/#{location}"
        class_name    = camelize(location) + 'Command'
        subcmd_class  = const_get "Aatc::#{class_name}"

        subcmd_class.new.send("run_#{subcmd_method}", args)

      else
        fail "There is no '#{subcommand}' subcommand! "\
             "Valid subcommands are "\
             "#{SUBCOMMANDS.keys.map { |s| s.to_s.gsub('_', '-') }.join(', ')}"
      end
    end

    def process_param(param)
      case param
      when '-d', '--debug'
        self.debug = true

      else
        fail "Invalid parameter #{param}"
      end
    end
  end
end
