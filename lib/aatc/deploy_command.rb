module Aatc
  class DeployCommand
    def run_deploy
      include Common

      def help_deploy(_args)
      end
      def run_deploy(args)
        process_deploy_args(args)

        if @environment.nil?
          fail "Please specify 'staging' or 'production': "\
               "`aatc deploy staging`"
        end

        if @apps.nil || @apps.empty?
          puts "Please enter a comma separated list of app names, or 'all' "\
               "for all apps."

          @apps = (gets || nil_thing!('app names')).split(',').map(&:strip)
          @apps = apps_by_name.keys if @apps == ['all']
        end

        succeeded = []
        failed    = []
        @apps.each do |app_name|
          app = apps_by_name[app_name]
          app_path = app['path']

          Dir.chdir(app_path) do
            if bundle_exec "cap #{@environment} deploy"
              succeeded
            else
              failed
            end << app
          end
        end

        if succeeded.empty?
          STDERR.puts "No app was successfully deployed."
          STDERR.puts "Failed apps have received a failed-deploy.log"
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
            when '-what' then @what = true
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

      def bundle_exec(command)
        system("bundle exec #{command}")
      end
    end
  end
end
