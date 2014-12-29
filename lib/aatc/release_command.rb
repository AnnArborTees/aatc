require 'byebug'
module Aatc
  class ReleaseCommand
    include Common

    # TODO factor this MONSTROSITY
    def run_open(args)
      process_open_args(args)

      if @release.nil?
        puts "Enter the name of the new release."
        @release = (gets || nil_thing!('release')).strip
      end
      if @apps.nil? || @apps.empty?
        @apps ||= []
        puts %(
          Enter a comma separated list of apps on which you'd like
          to open this release.
        ).squeeze(' ')
        @apps = (gets || nil_thing!('apps')).split(',').map(&:strip)
      end

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

      # First pass: make sure no apps have open releases.
      already_open = []
      @apps.each do |app_name|
        app = apps_by_name[app_name]
        already_open << app_name if app['open_release']
      end

      app_configs      = []
      unstaged_changes = []
      release_exists   = []
      # Second pass: make sure the git repositories in all apps
      # are clean.
      @apps.each do |app_name|
        app  = apps_by_name[app_name]
        path = app['path']

        Dir.chdir(path) do
          case `git status`
          when /Changes not staged for commit/
            unstaged_changes << app_name
          when /nothing to commit, working directory clean/,
               /nothing added to commit but untracked files present/ 

            if `git branch`.include?(@release)
              release_exists << app_name
            else
              app_configs << app
            end

          else
            weird_git!('status', app['path'])
          end
        end
      end

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
            when /\d+ files? changed, \d+ insertions?\(\+\), \d+ deletions?\(\-\)/
              case `git checkout -b #{@release}`
              when /Switched to a new branch '#{@release}'/
                puts "Successfully opened #{@release} for #{app_name}."
                # TODO make sure this goes into config file on save.
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

      failed.each do |app_name, error|
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
    end

    private

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
  end
end
