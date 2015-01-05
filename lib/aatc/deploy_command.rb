module Aatc
  class DeployCommand
    include Common

    def help_deploy(_args)
      puts "`aatc deploy <staging|production> [*apps]`"
      puts "Runs cap deploy on given apps for given environment."
      puts
      puts "OPTIONS:"
      puts "--branch=<branchname>  => "\
           "Specify which branch to deploy from. Defaults to develop "\
           "for staging and master for production."
    end
    def run_deploy(args)
      process_deploy_args(args)

      if @environment.nil?
        fail "Please specify 'staging' or 'production': "\
             "`aatc deploy staging`"
      end

      if @apps.nil? || @apps.empty?
        $stdout.puts "Please enter a comma separated list of app names, or 'all' "\
                     "for all apps."
        $stdout.puts
        print_registered_apps

        @apps = ($stdin.gets || nil_thing!('app names')).split(',').map(&:strip)
      end
      @apps = apps_by_name.keys if @apps == ['all']

      @branch ||= branch_for(@environment)

      succeeded = []
      failed    = []
      @apps.each do |app_name|
        app = apps_by_name[app_name]
        app_path = app['path']

        $stdout.puts "Deploying #{app_name}..."

        Dir.chdir(app_path) do
          if bundle_exec "cap #{@environment} deploy -s branch=#{@branch}", app_path
            succeeded
          else
            failed
          end << app_name
        end
      end

      if succeeded.empty?
        $stderr.puts "No app was successfully deployed."
        $stderr.puts "All apps have received a failed-deploy.log in their "\
                    "log folder."
      elsif failed.empty?
        $stdout.puts "Deployed all apps!"
        $stdout.puts "(#{@apps.join(', ')})"
      else
        $stdout.puts "Some apps failed to deploy."
        $stderr.puts "#{failed.join(', ')} have had a failed-deploy.log dropped "\
                    "in their log folder."
        $stdout.puts "#{succeeded.join(', ')} successfully deployed."
      end
    end

    private

    def invalid_all!
      fail "You have specified 'all' in addition to app names. "\
           "Please specify either 'all' or a list of app names."
    end

    def process_deploy_args(args)
      args.each do |arg|
        if arg[0] == '-'
          case arg
          when /--branch=([\w-]+)/ then @branch = $1
          else
            fail "Invalid parameter #{arg}. See `aatc help deploy` for more info."
          end
        else
          if @environment.nil?
            @environment = arg
          elsif arg == 'all'
            invalid_all! if @apps && !@apps.empty?

            @apps = ['all']
          else
            invalid_all! if @apps == ['all']
            @apps ||= []
            @apps << arg
          end
        end
      end
    end

    def branch_for(environment)
      case environment
      when 'staging'    then 'develop'
      when 'production' then 'master'
      else
        fail "Invalid environment #{environment}"
      end
    end

    def bundle_exec(command, path)
      FileUtils.mkdir_p 'log'

      FileUtils.touch path + '/log/failed-deploy.log'
      result = system("bundle exec #{command} > log/failed-deploy.log")
      File.unlink(path + '/log/failed-deploy.log') if result
      result
    end
  end
end
