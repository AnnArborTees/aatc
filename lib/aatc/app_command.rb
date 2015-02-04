require 'yaml'

module Aatc
  class AppCommand
    include Common

    def help_apps(_args)
      puts "Displays a list of all registered apps."
      puts
      puts "Note that this may hang if your cap deploy asks the user for"
      puts "input for anything OTHER than which branch to deploy off of."
      puts
      puts "OPTIONS:"
      puts "-p   => Print project root directories of each app."
      puts "-a   => Print registered branch aliases of each app."
    end
    def run_apps(args)
      process_apps_args(args)

      config['apps'].each do |app|
        puts app['name']
        puts app['path'] if @print_paths
        if @print_aliases
          (app['aliases'] || {}).each do |key, value|
            puts "#{key} => #{value}"
          end
        end
        puts "==============================================="
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
        @name = ($stdin.gets || nil_thing!('app name')).strip
      end
      if @path.nil?
        puts "Enter the path to the app's project directory."
        @path = ($stdin.gets || nil_thing!('app project root')).strip
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
        @name = ($stdin.gets || nil_thing!('app name')).strip
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
          response = ($stdin.gets || 'n').downcase.strip
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

    def help_app_alias
      puts "`aatc app-alias <original> <new> <*app names>`"
      puts "Adds the given 'alias'."
      puts
      puts "If you alias 'master' to be 'toast', release and deploy"
      puts "commands will use the 'toast' branch instead of 'master'."
      puts
      puts "Currently, aliasing 'master' and 'develop' are the only"
      puts "valid aliases."
    end
    def run_app_alias(args)
      parse_app_alias_args(args)

      could_not_find = []

      @app_names.each do |app_name|
        app = config['apps'].find { |a| a['name'] == app_name }
        if app.nil?
          could_not_find << app_name
          next
        end

        app['aliases'] ||= {}
        app['aliases'][@original] = @new
      end

      save_config!

      if could_not_find.empty?
        puts "Successfully added alias #{@original} => #{@new}!"
      elsif could_not_find.size == @app_names.size
        $stderr.puts "Couldn't find any apps with those names!"
      else
        puts "Successfully added alias #{@original} => #{@new}!"
        $stderr.puts "Except for nonexistent apps: #{could_not_find.join(', ')}"
      end
    end

    private

    def process_apps_args(args)
      args.each do |arg|
        case arg
        when '-p' then @print_paths = true
        when '-a' then @print_aliases = true

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

    def parse_app_alias_args(args)
      unless args.size >= 3
        fail "Try `aatc app-alias <original> <new> <*app names>`"
      end
      @original = args[0]
      @new = args[1]
      @app_names = args[2..-1]

      unless @original == 'master' || @original == 'develop'
        fail "Only 'master' or 'develop' may be aliased at this time."
      end
    end
  end
end
