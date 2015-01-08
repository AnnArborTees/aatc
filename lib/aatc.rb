require "aatc/version"
require "aatc/common"

module Aatc
  extend Common

  CONFIG_PATH = "~/.aatc"

  SUBCOMMANDS = {
    test: 'test',

    apps: 'app', add_app: 'app', rm_app: 'app',

    open:   'release', close:        'release',
    hotfix: 'release', hotfix_close: 'release',
    release: 'release',

    deploy: 'deploy'
  }

  class << self
    attr_accessor :debug
    attr_accessor :help
    def debug?; debug; end
    def help?;  help; end

    def run(argv)
      return help_dialog if argv.empty?

      did_subcmd = false

      argv.each_with_index do |arg, index|
        if arg[0] == '-'
          process_param(arg)
        else
          run_subcommand(arg, argv[index+1..-1])
          did_subcmd = true
          break
        end
      end

      return help_dialog unless did_subcmd
    end

    def subcommand_list
      SUBCOMMANDS.keys.map { |s| s.to_s.gsub('_', '-') }.join(', ')
    end

    def run_subcommand(subcommand, args)
      subcmd_method = subcommand.gsub('-', '_').to_sym
      case subcmd_method
      when :help
        self.help = true
        return help_dialog if args.empty?
        run_subcommand(args[0], args[1..-1])

      when *SUBCOMMANDS.keys
        location = SUBCOMMANDS[subcmd_method]
        require "aatc/#{location}_command"
        class_name    = camelize(location) + 'Command'
        subcmd_class  = const_get "Aatc::#{class_name}"

        prefix = help? ? 'help_' : 'run_'
        subcmd_class.new.send("#{prefix}#{subcmd_method}", args)

      else
        fail "There is no '#{subcommand}' subcommand! "\
             "Valid subcommands are #{subcommand_list}"
      end
    end

    def process_param(param)
      case param
      when '-d', '--debug'
        self.debug = true

      when '-h', '--help'
        self.help = true

      else
        fail "Invalid parameter #{param}"
      end
    end

    def help_dialog
      puts "--- Ann Arbor T-Shirt Company Command Line Utilities ---"
      puts
      puts "This is a tool for managing releases, deployment, and hotfixes"
      puts "across our multitudinous apps. For the most part, all this"
      puts "utility does is create, merge, and push git branches, so if you"
      puts "know what to do, this is all stuff you can do manually."
      puts
      puts "Available subcommands are #{subcommand_list}."
      puts "Execute `aatc help <subcommand>` to receive more info on any given"
           "subcommand."
    end
  end
end
