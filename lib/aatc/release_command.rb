require 'byebug'

module Aatc
  class ReleaseCommand
    class GitError < StandardError
    end

    include Common

    def help_open(_args)
      puts "`aatc open [release-name] [*apps]`"
      puts "Opens a new release with the given release name, on the"
      puts "given apps. All trailing arguments will be interpreted"
      puts "as the names of apps on which to have the release opened."
      puts
      puts "Will ask you to input release name and apps if called without"
      puts "arguments. If no apps are specified, will attempt to open the"
      puts "release on the app in the current working directory."
      puts
      puts "If 'all' (without quotes) is supplied as the only app name,"
      puts "all registered apps (see add-app) will have the release opened."
    end
    # TODO factor this MONSTROSITY (MORE!)
    def run_open(args)
      process_open_args(args)
      assure_valid_release_and_apps('new release')

      # First pass: make sure no apps have open releases.
      already_open = []
      @apps.each do |app_name|
        app    = apps_by_name[app_name]
        status = app_status(app['path'])
        already_open << app_name if status.open_release
      end

      app_configs, unstaged_changes, release_exists = check_git_status

      cannot_go_on = false

      # Cannot have apps with unstaged changes.
      unless unstaged_changes.empty?
        repositories = unstaged_changes.size > 1 ? 'repositories' : 'repository'
        have = unstaged_changes.size > 1 ? 'have' : 'has'
        $stderr.puts %(
          The #{repositories} for #{unstaged_changes.join(', ')} #{have}
          unstaged changes and cannot have a new release opened.
        ).squeeze(' ')
        cannot_go_on = true
      end

      # Apps cannot have an existing git branch with the same name as @release.
      unless release_exists.empty?
        repositories = release_exists.size > 1 ? 'repositories' : 'repository'
        have = release_exists.size > 1 ? 'have' : 'has'
        $stderr.puts %(
          The #{repositories} for #{release_exists.join(', ')}
          already #{have} a branch called #{@release}.
        ).squeeze(' ')
        cannot_go_on = true
      end

      # Cannot open an app that's already open!
      unless already_open.empty?
        if unstaged_changes.size + release_exists.size > 0
          $stderr.print 'Additionally, '
        else
          app_apps = already_open.size > 1 ? 'apps' : 'app'
          $stderr.print "The #{app_apps} "
        end
        if already_open.size > 1
          problem = "already have open releases"
        else
          release = apps_by_name[already_open[0]]['open_release']
          problem = "already has an open release (#{release})"
        end
        $stderr.puts "#{already_open.join(', ')} #{problem}."
        cannot_go_on = true
      end

      fail 'Fix the aformentioned issues, then try again.' if cannot_go_on

      # Now we try to pull from develop
      failed = []
      succeeded = []

      app_configs.each do |app|
        app_name = app['name']
        app_path = app['path']

        Dir.chdir(app_path) do
          begin
            git 'checkout develop',        successful_checkout('develop')
            git 'pull -u origin develop',  successful_pull
            git "checkout -b #{@release}", successful_checkout(@release)

            status = app_status(app_path)
            status.open_release = @release
            status.save

            git 'add -A'
            git %_commit -m "RELEASE OPENED: #{@release}"_, successful_commit
            git "push -u origin #{@release}",               successful_push(@release)

            succeeded << app
            puts "Successfully opened #{@release} for #{app_name}."

          rescue GitError => e
            $stderr.puts "#{app_name}: #{e.message}"
            failed << app
          end
        end

        failed.each do |error|
          $stderr.puts error
        end
        if succeeded.empty?
          fail "No apps were successfully released."
        end

        puts "Successfully opened release #{@release}!"
        unless failed.empty?
          puts "Except for on #{failed.join(', ')}."
        end
      end
    end


    def help_close(_args)
      puts "`aatc close [release-name] [*apps]`"
      puts "Closes the given release on the given apps, given"
      puts "that the release is currently open on the apps."
      puts
      puts "'all' can be passed instead of app names similarly"
      puts "to the open subcommand, except it will close all "
      puts "apps for which the release is open (will not attempt"
      puts "to close unopened apps)."
    end
    def run_close(args)
      process_close_args(args)

      matching_open_release = lambda do |a|
        app_status(a['path']).open_release == @release
      end

      assure_valid_release_and_apps(
        'release to close',

        all: lambda do
          @all = true;
          all_apps.select(&matching_open_release).map do |a|
            a['name']
          end
        end
      )

      # Make sure the given release matches all apps
      unless @all
        apps     = @apps.map { |a| apps_by_name[a] }
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

      failed = []
      succeeded = []

      app_configs.each do |app|
        app_name = app['name']
        app_path = app['path']

        Dir.chdir(app_path) do
          begin
            git "checkout #{@release}",       successful_checkout(@release)
            git "pull -u origin #{@release}", successful_pull

            status = app_status(app_path)
            status.open_release = nil
            status.save

            git 'add -A'
            git %_commit -m "RELEASE CLOSED: #{@release}"_, successful_commit
            git "push -u origin #{@release}",               successful_push(@release)

            succeeded << app
            puts "Successfully closed #{@release} for #{app_name}!"

          rescue GitError => e
            $stderr.puts "#{app_name}: #{e.message}"
            failed << app
          end
        end
      end

      if succeeded.empty?
        fail "Failed to release any apps."
      elsif failed.empty?
        puts "Successfully closed #{@release}!"
      else
        puts "Successfully closed some apps! Take a look at #{failed.keys.join(', ')}."
      end
    end

    def help_hotfix(_args)
      puts "`aatc hotfix hotfix-name [app-name]`"
      puts "Opens a hotfix on the given app with the given name."
      puts
      puts "If no app-name is given, will use the app in the current"
      puts "working directory."
    end
    def run_hotfix(args)
      process_hotfix_args(args)
      @name = app_from_current_directory if @name.nil?
      fail "try `aatc hotfix <hotfix-name> [app-name]`" if @name.nil?

      @app = app_in_cwd! if @app.nil?

      branch = "hotfix-#{@name}"

      # Check errors...
      app_configs, unstaged_changes, branch_exists =
        check_git_status([@app], branch)

      unless branch_exists.empty?
        fail "Cannot create a hotfix branch for #{@app} called '#{@name}' "\
             "(branch already exists)."
      end

      unless unstaged_changes.empty?
        fail "It is recommended you clean up your current changes if you "\
             "wish to initiate a hotfix."
      end

      # Pull from master and checkout hotfix branch.
      app = app_configs.first
      app_path = app['path']

      Dir.chdir(app_path) do
        begin
          git 'checkout master', successful_checkout('master')
          git 'pull -u origin master', successful_pull
          git "checkout -b #{branch}", successful_checkout(branch)

          status = app_status(app_path)
          status.hotfix = @name
          status.save

          git 'add -A'
          git %_commit -m "HOTFIX INITIATED: #{@name}"_, successful_commit

          puts "You are now working on hotfix #{@name} off of master branch!"
          puts "Remember to merge this with the appropriate release after "\
               "executing `aatc hotfix-close`."

        rescue GitError => e
          fail e
        end
      end
    end

    def help_hotfix_close(_args)
      puts "`aatc hotfix-close [app-name]`"
      puts "Closes the current hotfix on either the given app, or the"
      puts "app in the current working directory."
      puts
      puts "Closing a hotfix includes merging/pushing with master and"
      puts "develop, but NOT the current release. Hotfixes have a high"
      puts "chance of merge conflicts with in-development release branches."
    end
    def run_hotfix_close(args)
      process_hotfix_close_args(args)

      @app = app_in_cwd! if @app.nil?

      app      = apps_by_name[@app]
      app_path = app['path']
      status   = app_status(app_path)

      if status.hotfix.nil?
        fail "There appears to be no hotfix on the current branch for "\
             "#{@app}. Please checkout the branch of the hotfix you'd "\
             "like to close, and try again."
      end

      Dir.chdir(app_path) do
        begin
          case `git status`
          when /Changes not staged for commit/
            fail "Please commit or stash your unstaged changes before closing "\
                 "the hotfix."
          end

          hotfix_name = status.hotfix
          status.hotfix = nil
          status.save

          git 'add -A'
          git %_commit -m "HOTFIX CLOSED: #{hotfix_name}"_, successful_commit

          %w(master develop).each do |branch|
            git "checkout #{branch}",          successful_checkout(branch)
            git "pull -u origin #{branch}",    successful_pull
            git "merge hotfix-#{hotfix_name}", successful_merge
            git "push -u origin #{branch}",    successful_push(branch)
          end

          puts "Hotfix #{hotfix_name} successfully closed and merged with master "\
               "and develop, but NOT the current release."
          puts "It is up to you to merge hotfix-#{hotfix_name} with the current release."

        rescue GitError => e
          fail e
        end
      end
    end

    private

    def `(cmd)
      super(cmd + ' 2>&1')
    end

    def successful_checkout(branch)
      [
        /Switched to( a new)? branch '#{branch}'/,
        /Already on '#{branch}'/
      ]
    end

    def successful_merge
      successful_commit
    end

    def successful_pull
      [
        successful_commit,
        /Already up-to-date/
      ]
    end

    def successful_commit
      /\d+ files? changed,( \d+ insertions?\(\+\),?)? (\d+ deletions?\(\-\))?/
    end

    def successful_push(branch, to_branch = nil)
      to_branch ||= branch
      [
        /Everything up-to-date/,
        /\w+\.\.\w+\s+#{branch} -> #{to_branch}/
      ]
    end

    # TODO uhh this is the same as process_close_args...
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

    def process_hotfix_args(args)
      args.each do |arg|
        if @name.nil?
          @name = arg
        elsif @app.nil?
          @app = arg
        else
          fail "Too many arguments for hotfix! Please just specify "\
               "app name, and hotfix name."
        end
      end
    end

    def process_hotfix_close_args(args)
      if args.size > 1
        fail "Only 1 argument (app name) can be accepted."
      end
      @app = args.first
    end

    def app_in_cwd!
      all_apps.each do |app|
        path      = app['path']
        full_path = path.gsub('~', Dir.home)

        case Dir.pwd
        when path, full_path then return app['name']
        end
      end

      fail "Please specify an app name, or cd into an app's project root."
    end

    def git(git_cmd, regex = nil)
      output = `git #{git_cmd}`
      return output if regex.nil?

      case output
      when *Array(regex)
        output
      else
        raise GitError, "Unexpected output for `git #{git_cmd}`: #{output}"
      end
    end

    def assure_valid_release_and_apps(release = 'release', options = {})
      options[:all] ||= -> { apps_by_name.keys }

      # Prompt for release and apps if they were not proveded via command line.
      if @release.nil?
        puts "Enter the name of the #{release}."
        @release = (STDIN.gets || nil_thing!('release')).strip
      end
      if @apps.nil? || @apps.empty?
        @apps ||= []

        puts "Enter a comma separated list of apps on which you'd like"
        puts "to open this release (or 'all' for every app)."
        puts
        print_registered_apps

        @apps = (STDIN.gets || nil_thing!('apps')).split(',').map(&:strip)
      end
      @apps = options[:all].call if @apps.size == 1 && @apps[0].downcase == 'all'

      @apps.reject!(&:empty?)
      fail "I need a non-empty list!" if @apps.empty?

      # Make sure the app names we were given actually corrospond to apps.
      valid_app_names = apps_by_name.keys
      non_apps  = @apps.reject { |a| valid_app_names.include?(a) }
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

    def check_git_status(apps = nil, branch = nil)
      app_configs      = []
      unstaged_changes = []
      release_exists   = []
      # Second pass: make sure the git repositories in all apps
      # are clean.
      (apps || @apps).each do |app_name|
        app  = apps_by_name[app_name]
        path = app['path']
        app_configs << app

        Dir.chdir(path) do
          case `git status`
          when /Changes not staged for commit/
            unstaged_changes << app_name
          when /nothing to commit, working directory clean/,
               /nothing added to commit but untracked files present/ 

            b = (branch || @release)
            if b && `git branch`.include?(b)
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
