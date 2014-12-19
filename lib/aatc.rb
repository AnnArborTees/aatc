require "aatc/version"
require 'aatc/test'

module Aatc
  class << self
    attr_accessor :debug
    def debug?; debug; end

    SUBCOMMANDS = %i{
      test
    }

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
      case subcommand.to_sym
      when *SUBCOMMANDS
        require "aatc/#{subcommand}"
        class_name    = subcommand
        class_name[0] = subcommand[0].upcase

        subcmd_class = const_get "Aatc::#{class_name}"
        subcmd.new.run(args)

      else
        fail "There is no '#{subcommand}' subcommand!"
      end
    end

    def process_param(param)
      case param
      when '-d', '--debug'
        debug = true

      else
        fail "Invalid parameter #{param}"
      end
    end
  end
end
