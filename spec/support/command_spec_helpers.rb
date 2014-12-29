module CommandSpecHelpers
  def cmd
    @cmd ||= described_class.new
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

  def stub_input_with(input)
    allow(cmd).to receive(:gets, &input.method(:gets))
  end

  def stub_chdir_with(dir)
    expect(Dir).to receive(:chdir).with(dir) { |&block|
      block.call
    }
  end

  def valid_apps_yml
    @valid_apps_yml ||= %(
      apps:
        -
          name: first-app
          path: ~/aatc_test/what-up
          open_release: release-2014-07-02
          closed_releases:
            - release-2014-05-22
            - release-2014-06-15

        -
          name: other-app
          path: ~/aatc_test/other-app
          closed_releases:
            - release-2014-05-22
            - release-2014-06-15

        -
          name: unreleased
          open_release: release-2014-07-02
          path: ~/somewhere/else

        -
          name: whatever
          path: ~/whatever/path
    )
  end

  def config(force = false)
    cmd.send(:config, force)
  end

  def reload_config
    cmd.send(:config, true)
  end
end
