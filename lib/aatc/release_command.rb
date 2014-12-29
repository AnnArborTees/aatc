require 'byebug'
module Aatc
  class ReleaseCommand
    include Common

    # TODO factor this MONSTROSITY
    def run_open(args)
      process_open_args(args)
      assure_valid_release_and_apps('new release')

      # First pass: make sure no apps have open releases.
      already_open = []
      @apps.each do |app_name|
        app = apps_by_name[app_name]
        already_open << app_name if app['open_release']
      end

      app_configs, unstaged_changes, release_exists = check_git_status

      # If any apps failed the passes, we're done.
      cannot_go_on = false
      unless unstaged_changes.empty?
        repositories = unstaged_changes.size > 1 ? 'repositories' : 'repository'
        have = unstaged_changes.size > 1 ? 'have' : 'has'
        STDERR.puts %(
          The #{repositories} for #{unstaged_changes.join(', ')} #{have}
          unstaged changes and cannot have a new release opened.
        ).squeeze(' ')
        cannot_go_on = true
      end

      unless release_exists.empty?
        repositories = release_exists.size > 1 ? 'repositories' : 'repository'
        have = release_exists.size > 1 ? 'have' : 'has'
        STDERR.puts %(
          The #{repositorie} for #{release_exists.join(', ')}
          already #{have} a branch called #{@release}.
        ).squeeze(' ')
        cannot_go_on = true
      end

      unless already_open.empty?
        if unstaged_changes.size + release_exists.size > 0
          STDERR.print 'Additionally, '
        else
          app_apps = already_open.size > 1 ? 'apps' : 'app'
          STDERR.print "The #{app_apps} "
        end
        if already_open.size > 1
          problem = "already have open releases"
        else
          release = apps_by_name[already_open[0]]['open_release']
          problem = "already has an open release (#{release})"
        end
        STDERR.puts "#{already_open.join(', ')} #{problem}."
        cannot_go_on = true
      end

      fail 'Fix the aformentioned issues, then try again.' if cannot_go_on

      # Now we try to pull from develop
      failed = {}
      succeeded = []

      app_configs.each do |app|
        app_name = app['name']

        Dir.chdir(app['path']) do
          case `git checkout develop`
          when /Switched to( a new)? branch 'develop'/

            case `git pull -u origin develop`
            when *successful_pull
              case `git checkout -b #{@release}`
              when /Switched to a new branch '#{@release}'/
                puts "Successfully opened #{@release} for #{app_name}."
                app['open_release'] = @release
                succeeded << app

              else
                failed[app_name] = "Could not create new branch for #{app_name}."
              end

            else
              failed[app_name] = "Something weird happened when executing"\
                                 " `git pull -u origin develop` for #{app_name}."
            end

          else
            failed[app_name] = "No develop branch for #{app_name}."
          end
        end
      end

      failed.each do |_app_name, error|
        STDERR.puts error
      end
      if succeeded.empty?
        fail "No apps were successfully released."
      end

      save_config!
      puts "Successfully opened release #{@release}!"
      unless failed.empty?
        puts "Except for on #{failed.keys.join(', ')}."
      end
    end



    def run_close(args)
      process_close_args(args)

      matching_open_release = lambda do |a|
        a['open_release'] == @release
      end

      assure_valid_release_and_apps(
        'release to close',
        all: lambda do
          @all = true;
          apps_by_name.values.select(&matching_open_release).map do |a|
            a['name']
          end
        end
      )

      # Make sure the given release matches all apps
      unless @all
        apps = @apps.map { |a| apps_by_name[a] }
        bad_apps = apps.reject(&matching_open_release)
        unless bad_apps.empty?
          are_is = bad_apps.size > 1 ? 'are' : 'is'
          fail "#{bad_apps.join(', ')} #{are_is} not currently on release "\
               "#{@release}."
        end
      end

      failed = {}
      succeeded = []

      app_configs, unstaged_changes, _release_exists = check_git_status

      unless unstaged_changes.empty?
        repositories = unstaged_changes.size > 1 ? 'repositories' : 'repository'
        have = unstaged_changes.size > 1 ? 'have' : 'has'
        fail %(
          The #{repositories} for #{unstaged_changes.join(', ')} #{have}
          unstaged changes that should be cleaned up before release.
        ).squeeze(' ')
      end

      failed = {}
      succeeded = []
      app_configs.each do |app|
        app_name = app['name']

        Dir.chdir(app['path']) do
          case `git checkout #{@release}`
          when /Switched to branch '#{@release}'/

            case `git pull -u origin #{@release}`
            when *successful_pull

              case `git push -u origin #{@release}`
              when *successful_push(@release)
                puts "Successfully closed #{@release} for #{app_name}."
                app['open_release'] = nil
                succeeded << app

              else
                failed[app_name] = "Couldn't push #{app_name} to origin #{@release}."
              end

            else
              failed[app_name] = "Couldn't pull #{app_name} from origin #{@release}."
            end

          else
            failed[app_name] = "Couldn't checkout #{app_name} #{@release} branch."
          end
        end
      end

      failed.each do |_app_name, error|
        STDERR.puts error
      end

      save_config! unless succeeded.empty?

      if succeeded.empty?
        fail "Failed to release any apps."
      elsif failed.empty?
        puts "Successfully closed #{@release}!"
      else
        puts "Successfully closed some apps! Take a look at #{failed.keys.join(', ')}."
      end
    end

    private

    def successful_pull
      [
        /\d+ files? changed, \d+ insertions?\(\+\), \d+ deletions?\(\-\)/,
        /Already up-to-date/
      ]
    end

    def successful_push(branch, to_branch = nil)
      to_branch ||= branch
      [
        /Everything up-to-date/,
        /\w+\.\.\w+\s+#{branch} -> #{to_branch}/
      ]
    end

    def process_open_args(args)
      args.each do |arg|
        if @release.nil?
          @release = arg.strip
        else
          @apps ||= []
          @apps << arg.strip unless arg.strip.empty?
        end
      end
    end

    def process_close_args(args)
      args.each do |arg|
        if @release.nil?
          @release = arg.strip
        else
          @apps ||= []
          @apps << arg.strip unless arg.strip.empty?
        end
      end
    end

    def assure_valid_release_and_apps(release = 'release', options = {})
      options[:all] ||= -> { apps_by_name.keys }

      if @release.nil?
        puts "Enter the name of the #{release}."
        @release = (gets || nil_thing!('release')).strip
      end
      if @apps.nil? || @apps.empty?
        @apps ||= []
        puts %(
          Enter a comma separated list of apps on which you'd like
          to open this release (or 'all' for every app).
        ).squeeze(' ')
        @apps = (gets || nil_thing!('apps')).split(',').map(&:strip)
      end
      @apps = options[:all].call if @apps.size == 1 && @apps[0].downcase == 'all'

      @apps.reject!(&:empty?)
      fail "I need a non-empty list!" if @apps.empty?

      app_names = apps_by_name.keys
      non_apps  = @apps.reject { |a| app_names.include?(a) }
      unless non_apps.empty?
        app_apps = non_apps.size > 1 ? 'apps' : 'app'
        is_are   = non_apps.size > 1 ? 'are' : 'is'
        fail %(
          The #{app_apps} #{non_apps.join(', ')} #{is_are} not
          registered. View all registered apps with `aatc apps`,
          and register new ones with `aatc add-app [name] [path]`.
        ).squeeze(' ')
      end
    end

    def check_git_status
      app_configs      = []
      unstaged_changes = []
      release_exists   = []
      # Second pass: make sure the git repositories in all apps
      # are clean.
      @apps.each do |app_name|
        app  = apps_by_name[app_name]
        path = app['path']
        app_configs << app

        Dir.chdir(path) do
          case `git status`
          when /Changes not staged for commit/
            unstaged_changes << app_name
          when /nothing to commit, working directory clean/,
               /nothing added to commit but untracked files present/ 

            if `git branch`.include?(@release)
              release_exists << app_name
            end

          else
            weird_git!('status', app['path'])
          end
        end
      end

      return app_configs, unstaged_changes, release_exists
    end
  end
end
