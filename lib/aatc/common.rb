require 'yaml'
require 'fileutils'

module Aatc
  AppStatus = Struct.new(:path, :open_release, :hotfix) do
    def initialize(hash, path)
      self.path = path
      self.open_release = hash['open_release']
      self.hotfix = hash['hotfix']
    end

    def save
      File.open(path, 'w') do |f|
        f.write(to_yaml)
      end
    end

    def to_yaml
      {
        'open_release' => open_release,
        'hotfix'       => hotfix
      }
        .to_yaml
    end
  end

  module Common
    extend self

    def camelize(term)
      string = term.to_s
      string = string.sub(/^[a-z\d]*/) { $&.capitalize }
      string.gsub!(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{$2.capitalize}" }
      string.gsub!(/\//, '::')
      string
    end

    def config(force = false)
      if force || @config.nil?
        if File.exists?(config_file)
          @config = YAML.load_file(config_file)
        else
          FileUtils.mkdir_p CONFIG_PATH
          @config = { 'apps' => [] }
        end
      else
        @config
      end
    end

    def apps_by_name(force = false)
      return @apps_by_name if @apps_by_name && !force
      @apps_by_name = {}
      config(force)['apps'].each do |app|
        @apps_by_name[app['name']] = app
      end
      @apps_by_name
    end

    def all_apps
      apps_by_name.values
    end

    def save_config!
      File.open(config_file, 'w') do |f|
        f.write(config.to_yaml)
      end
    end

    def config_file
      CONFIG_PATH.gsub('~', Dir.home) + '/apps.yml'
    end

    def status_file(project_root)
      path = project_root
      path += '/' unless path[-1] == '/'
      path + '.aatc'
    end

    def app_status(project_root, force = false)
      path = status_file(project_root)

      @app_statuses ||= {}
      return @app_statuses[path] if @app_statuses.key?(path) && !force
      @app_statuses[path] = (
        data = File.exists?(path) ? YAML.load_file(path) : {}
        AppStatus.new(data, path)
      )
    end

    def save_app_status!(project_root)
      path = status_file(project_root)

      File.open(path, 'w') do |f|
        f.write(app_status.to_yaml)
      end
    end

    # TODO not used?
    def ask(question)
      response = ''
      until response == 'y' || response == 'n'
        puts "#{question} (y/[n])"
        response = (STDIN.gets || 'n').downcase.strip
      end
      if response == 'n'
        puts "#{@name} was not removed."
        return
      end
    end

    def print_registered_apps
      $stdout.puts "Registered apps: "\
        "#{apps_by_name.empty? ? '<none>' : apps_by_name.keys.join(', ')}"
    end

    def nil_thing!(thing)
      fail "Invalid (nil) #{thing}."
    end

    def weird_git!(command, path, output = nil)
      fail %(
        Got an unexpected output from running `git #{command}` inside 
        #{path}. Either you are rebasing or in some other weird state
        that must be gotten out of before aatc can cleanly manage your
        respository. If nothing seems wrong, this could be an aatc bug.
        It's possible that git has updated and changed its output enough
        to throw me off. If that is the case, then I am sorry.
        #{output}
      ).squeeze(' ')
    end
  end
end
