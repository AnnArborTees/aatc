module CommandSpecHelpers
  def cmd
    @cmd ||= described_class.new
  end

  def respond_to?(name)
    return super unless /^run_/ =~ name
  end

  def method_missing(name, *args, &block)
    return super unless /^run_/ =~ name
    return super unless cmd.respond_to?(name)

    cmd_args = args.empty? ? [[]] : args
    proc { cmd.send(name, *cmd_args, &block) }
  end
end
