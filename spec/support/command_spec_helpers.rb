require 'fileutils'

module CommandSpecHelpers
  def cmd
    @cmd ||= described_class.new
  end

  def refresh_cmd!
    @cmd = described_class.new
  end

  def respond_to?(name, *args)
    return super || /^run_/ =~ name
  end

  def method_missing(name, *args, &block)
    return super unless /^run_/ =~ name
    return super unless cmd.respond_to?(name)

    proc { cmd.send(name, args, &block) }
  end

  def expect_clean_git_status
    expect(cmd).to receive(:`).with('git status')
      .and_return "nothing to commit, working directory clean"
  end
  def expect_git_branch(*args)
    options = {}
    options = args.pop if args.last.is_a?(Hash)

    branches = args.flatten

    on = options[:on] || 'master'
    branches.map! { |b| b == on ? "* #{b}" : b }

    expect(cmd).to receive(:`).with('git branch')
      .and_return branches.join("\n")
  end
  def expect_successful_git_checkout(branch, b = false)
    expect(cmd).to receive(:`).with("git checkout#{' -b' if b} #{branch}")
      .and_return "Switched to#{' a new' if b} branch '#{branch}'"
  end
  def expect_successful_git_checkout_b(branch)
    expect_successful_git_checkout(branch, true)
  end
  def expect_successful_git_pull(branch)
    expect(cmd).to receive(:`).with("git pull -u origin #{branch}")
      .and_return '1 file changed, 5 insertions(+), 2 deletions(-)'
  end
  def expect_successful_git_push(branch)
    expect(cmd).to receive(:`).with("git push -u origin #{branch}")
      .and_return "0bd2488..f70d739  #{branch} -> #{branch}"
  end
  def expect_successful_git_add_a
    expect(cmd).to receive(:`).with('git add -A').and_return ''
  end
  def expect_successful_git_commit(message)
    expect(cmd).to receive(:`)
      .with(%_git commit -m "#{message}"_)
      .and_return '1 file changed, 5 insertions(+), 2 deletions(-)'
  end
  def expect_successful_git_commit_without_deletions(message)
    expect(cmd).to receive(:`)
      .with(%_git commit -m "#{message}"_)
      .and_return '1 file changed, 5 insertions(+)'
  end
  def expect_successful_git_commit_without_insertions(message)
    expect(cmd).to receive(:`)
      .with(%_git commit -m "#{message}"_)
      .and_return '1 file changed, 8 deletions(-)'
  end
  def expect_successful_git_merge(branch)
    # TODO
    expect(cmd).to receive(:`).with("git merge #{branch}")
      .and_return '8 files changed, 20 insertions(+), 2 deletions(-)'
  end

  def stub_input_with(input)
    allow(STDIN).to receive(:gets, &input.method(:gets))
  end

  def stub_chdir_with(*dirs)
    expect(Dir).to receive(:chdir).with(*dirs) { |&block|
      block.call
    }
  end

  def app_paths
    ['/aatc_test/what-up',
     '/aatc_test/other-app',
     '/somewhere/else',
     '/whatever/path']
  end

  def valid_apps_yml
    @valid_apps_yml ||= (
      app_paths.each(&FileUtils.method(:mkdir_p))

      %(
        apps:
          -
            name: first-app
            path: /aatc_test/what-up

          -
            name: other-app
            path: /aatc_test/other-app

          -
            name: unreleased
            path: /somewhere/else

          -
            name: whatever
            path: /whatever/path
      )
    )
  end

  def config(force = false)
    cmd.send(:config, force)
  end

  def reload_config
    cmd.send(:config, true)
  end
end
