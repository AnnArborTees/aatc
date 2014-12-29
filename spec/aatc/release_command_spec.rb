require 'spec_helper'
require 'aatc'
require 'aatc/release_command'

describe Aatc::ReleaseCommand, type: :command do
  describe '#run_open' do
    context 'with no args' do
      it 'asks me which apps, and what to call the release' do
        input = StringIO.new
        input.puts 'release-2015-01-01'
        input.puts 'other-app'
        input.rewind

        stub_chdir_with('~/aatc_test/other-app').twice
        stub_input_with(input)

        expect_clean_git_status
        expect_git_branch('master', 'develop', 'local')
        expect_successful_git_checkout('develop')
        expect_successful_git_pull('develop')
        expect_successful_git_checkout_b('release-2015-01-01')

        expect(&run_open)
          .to output(/Successfully opened release-2015-01-01 for other-app/).to_stdout

        expect(reload_config['apps'][1]['open_release']).to eq 'release-2015-01-01'
      end
    end

    context 'when the app already has an open release' do
      it 'informs the user that they must close it first' do
        input = StringIO.new
        input.puts 'release-2015-01-01'
        input.puts 'first-app'
        input.rewind

        stub_chdir_with('~/aatc_test/what-up')
        stub_input_with(input)

        expect_clean_git_status
        expect_git_branch('master', 'whatever')

        expect do
          expect(&run_open)
            .to output(/first-app already has an open release \(release-2014-07-02\)/)
            .to_stderr
        end
          .to raise_error
      end
    end

    context 'with <release-name> <appname> args', :test_cmd do
      it 'opens the given release' do
        expect(config['apps'][1]['open_release']).to be_nil

        stub_chdir_with('~/aatc_test/other-app').twice
        
        expect_clean_git_status
        expect_git_branch('master', 'develop', 'ok')
        expect_successful_git_checkout('develop')
        expect_successful_git_pull('develop')
        expect_successful_git_checkout_b('release-2015-01-01')

        expect(&run_open('release-2015-01-01', 'other-app'))
          .to output(/Successfully opened release-2015-01-01 for other-app/).to_stdout

        expect(reload_config['apps'][1]['open_release']).to eq 'release-2015-01-01'
      end
    end
  end

  describe '#run_close' do
    context 'when passed "all"' do
      it 'closes them all', all: true do
        expect(config['apps'][0]['open_release']).to_not be_nil
        expect(config['apps'][2]['open_release']).to_not be_nil

        release = 'release-2014-07-02'

        stub_chdir_with('~/aatc_test/what-up').twice
        stub_chdir_with('~/somewhere/else').twice

        expect_clean_git_status.twice
        expect_successful_git_checkout(release).twice
        expect_successful_git_pull(release).twice
        expect_successful_git_push(release).twice

        expect(&run_close(release, 'all'))
          .to output(/Successfully/).to_stdout

        expect(config['apps'][0]['open_release']).to be_nil
        expect(config['apps'][2]['open_release']).to be_nil
      end
    end

    context 'with no args' do
      it 'Asks the user for input before closing' do
        expect(config['apps'][0]['open_release']).to_not be_nil

        release = 'release-2014-07-02'

        input = StringIO.new
        input.puts release
        input.puts 'first-app'
        input.rewind
        stub_input_with(input)

        stub_chdir_with('~/aatc_test/what-up').twice

        expect_clean_git_status
        expect_successful_git_checkout(release)
        expect_successful_git_pull(release)
        expect_successful_git_push(release)

        expect(&run_close).to output(/Successfully/).to_stdout

        expect(reload_config['apps'][0]['open_release']).to be_nil
      end
    end
  end
end
