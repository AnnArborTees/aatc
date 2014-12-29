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

  def stub_input_with(input)
    allow(cmd).to receive(:gets, &input.method(:gets))
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
          path: ~/some/path
    )
  end

  def config(force = false)
    cmd.send(:config, force)
  end

  def reload_config
    cmd.send(:config, true)
  end
end
