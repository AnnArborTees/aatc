require 'yaml'

module Aatc
  class AppCommand
    CONFIG_PATH = "~/.aatc"

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
        puts "What is the app called?"
        @name = (gets || nil_thing!('app name')).strip
      end
      if @path.nil?
        puts "What is the project path of the app?"
        @path = (gets || nil_thing!('app project root')).strip
      end

      config['apps'] << {
        'name' => @name,
        'path' => @path
      }

      File.open(config_file, 'w') do |f|
        f.write config.to_yaml
      end

      puts "Successfully added #{@name} to apps list."
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

    def nil_thing!(thing)
      fail "Invalid (nil) #{thing}."
    end

    def config(force = false)
      if force || @config.nil?
        @config = YAML.load_file(config_file)
      else
        @config
      end
    end

    def config_file
      CONFIG_PATH + '/apps.yml'
    end
  end
end
