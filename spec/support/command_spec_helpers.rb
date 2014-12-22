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

    proc { cmd.send(name, args, &block) }
  end
end
