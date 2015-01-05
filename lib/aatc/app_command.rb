require 'yaml'

module Aatc
  class AppCommand
    include Common

    def help_apps(_args)
      puts "Displays a list of all registered apps."
      puts
      puts "OPTIONS:"
      puts "-p   => Print project root directories of each app."
    end
    def run_apps(args)
      process_apps_args(args)

      config['apps'].each do |app|
        puts app['name']
        puts app['path'] if @print_paths
      end
    end

    def help_add_app(_args)
      puts "`aatc add-app [app-name] [project-root-path]`"
      puts "Register an app with a given name and project root."
      puts
      puts "Will ask for name and path if executed without arguments."
    end
    def run_add_app(args)
      process_add_app_args(args)

      if @name.nil?
        puts "Enter the name of the new app."
        @name = (STDIN.gets || nil_thing!('app name')).strip
      end
      if @path.nil?
        puts "Enter the path to the app's project directory."
        @path = (STDIN.gets || nil_thing!('app project root')).strip
      end

      @path.gsub! '~', Dir.home

      if config['apps'].find { |a| a['name'] == @name }
        fail "There is already a registered app called #{@name}."
      end

      unless File.exists?(@path)
        fail "The path #{@path} does not exist."
      end
      unless File.directory?(@path)
        fail "#{@path} is not a directory."
      end

      config['apps'] << {
        'name' => @name,
        'path' => @path
      }
      save_config!

      puts "Successfully added #{@name} to apps list."
    end

    def help_rm_app(_args)
      puts "`aatc rm-app [name-of-unwanted-app]`"
      puts "Unregisters the app with the given name."
      puts "By default, will ask you if you are sure before unregistering."
      puts
      puts "OPTIONS:"
      puts "-f, --force   => Skip asking whether or not you are sure before "\
           "unregistering."
    end
    def run_rm_app(args)
      process_rm_app_args(args)

      if @name.nil?
        puts "Enter the name of the app you'd like removed."
        @name = (STDIN.gets || nil_thing!('app name')).strip
      end

      name_matches = proc { |a| a['name'] == @name }
      app = config['apps'].find(&name_matches)

      if app.nil?
        fail "Couldn't find an app called #{@name}."
      end

      unless @force
        response = ''
        until response == 'y' || response == 'n'
          puts "Are you sure you'd like to delete #{@name}? "\
               "The project file will remain; only the entry "\
               "in #{config_file} will be removed. (y/n)"
          response = (STDIN.gets || 'n').downcase.strip
        end
        if response == 'n'
          puts "#{@name} was not removed."
          return
        end
      end

      before_len = config['apps'].size
      config['apps'].reject!(&name_matches)
      save_config!
      after_len = config(true)['apps'].size

      case before_len - after_len
      when 1
        puts "The app #{@name} was removed."
      when 0
        puts "Couldn't find app with name #{@name}."
      else
        fail "I have no idea what happened.. Make sure your "\
             "#{config_file} is okay and have someone fix this bug."
      end
    end

    private

    def process_apps_args(args)
      args.each do |arg|
        case arg
        when '-p'                  then @print_paths = true

        else
          fail "Unknown argument #{arg}"
        end
      end
    end

    def process_add_app_args(args)
      args.each do |arg|
        case arg
        when '-lol' then puts 'heh'

        else
          if @name.nil?
            @name = arg
          elsif @path.nil?
            @path = arg
          else
            fail "Unknown argument #{option}"
          end
        end
      end
    end

    def process_rm_app_args(args)
      args.each do |arg|
        case arg
        when '-f', '--force' then @force = true

        else
          if @name.nil?
            @name = arg
          else
            fail "Unknown argument #{arg}"
          end
        end
      end
    end
  end
end
