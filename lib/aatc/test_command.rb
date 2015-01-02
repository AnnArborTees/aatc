module Aatc
  class TestCommand
    def help_test(_args)
      puts "Just a test function used to make sure subcommand"
      puts "dispatching works. Will print back any args given."
    end
    def run_test(args)
      puts 'Ayoooooo'
      puts "Here my args: #{args.inspect}"
    end
  end
end
