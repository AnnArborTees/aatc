require 'spec_helper'
require 'aatc'
require 'aatc/release_command'

describe Aatc::ReleaseCommand, type: :command do
  describe '#run_open' do
    context 'with no args' do
      it 'asks me which apps, and what to call the release' do
        input = StringIO.new
        input.puts 'other-app'
        input.puts 'release-2015-01-01'
        input.rewind

        stub_input_with(input)

        # TODO
        expect(&run_open).to output('something regarding success').to_stdout
      end
    end

    context 'when the app already has an open release' do
      it 'informs the user that they must close it first' do
        input = StringIO.new
        input.puts 'release-2015-01-01'
        input.puts 'first-app'
        input.rewind

        stub_input_with(input)

        expect(&run_open).to output(/is currently on release-2014-07-02/).to_stdout
      end
    end

    context 'with <release-name> <appname> args', :test_cmd do
      it 'opens the given release' do
        expect(config['apps'][1]['open_release']).to be_nil

        expect(Dir).to receive(:chdir).with('~/aatc_test/other-app')
          .and_call_original
        expect(cmd).to receive(:`).with('git branch')
          .and_return "* master\nsome-branch\nother-branch"
        expect(cmd).to receive(:`).with('git checkout -b release-2015-01-01')
          # TODO
          .and_return "whatever this would return on success. nothing?"

        expect(&run_open('release-2015-01-01', 'other-app'))
          .to output(/successfully opened release-2015-01-01/).to_stdout

        expect(reload_config['apps'][1]['open_release']).to eq 'release-2015-01-01'
      end
    end
  end

  describe '#run_close' do
  end
end
