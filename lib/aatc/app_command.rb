require 'yaml'

module Aatc
  class AppCommand
    include Common

    def run_apps(args)
      process_apps_args(args)

      config['apps'].each do |app|
        puts app['name']
        puts app['path'] if @print_paths
        if @last_closed
          closed = app['closed_releases'] || []
          puts closed.last || '<none>'
        end
      end
    end

    def run_add_app(args)
      process_add_app_args(args)

      if @name.nil?
        puts "Enter the name of the new app."
        @name = (gets || nil_thing!('app name')).strip
      end
      if @path.nil?
        puts "Enter the path to the app's project directory."
        @path = (gets || nil_thing!('app project root')).strip
      end

      if config['apps'].find { |a| a['name'] == @name }
        fail "There is already a registered app called #{@name}."
      end

      config['apps'] << {
        'name' => @name,
        'path' => @path
      }
      save_config!

      puts "Successfully added #{@name} to apps list."
    end

    def run_rm_app(args)
      process_rm_app_args(args)

      if @name.nil?
        puts "Enter the name of the app you'd like removed."
        @name = (gets || nil_thing!('app name')).strip
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
          response = (gets || 'n').downcase.strip
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
        when '-p'            then @print_paths = true
        when '--last-closed' then @last_closed = true

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
        when '-f' then @force = true

        else
          if @name.nil?
            @name = arg
          else
            fail "Unknown argument #{arg}"
          end
        end
      end
    end

    def nil_thing!(thing)
      fail "Invalid (nil) #{thing}."
    end
  end
end
