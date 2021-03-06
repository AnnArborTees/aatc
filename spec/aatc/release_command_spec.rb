require 'spec_helper'
require 'aatc'
require 'aatc/common'
require 'aatc/release_command'

# TODO Perhaps make these commands do work on the app in the current
# directory if no app is supplied?

# TODO Also, perhaps make open and close check for in-progress hotfixes
# and not operate on those apps.

Common = Aatc::Common
describe Aatc::ReleaseCommand, type: :command do
  describe '#run_open' do
    context 'with no args' do
      it 'asks me which apps, and what to call the release' do
        expect(Common.app_status('/aatc_test/other-app', :force).open_release)
          .to be_nil

        input = StringIO.new
        input.puts 'release-2015-01-01'
        input.puts 'other-app'
        input.rewind

        stub_chdir_with('/aatc_test/other-app').twice
        stub_input_with(input)

        expect_clean_git_status
        expect_git_branch('master', 'develop', 'local')
        expect_successful_git_checkout('develop')
        expect_successful_git_pull('develop')
        expect_successful_git_checkout_b('release-2015-01-01')
        expect_successful_git_add_a
        expect_successful_git_commit('RELEASE OPENED: release-2015-01-01')
        expect_successful_git_push('release-2015-01-01')

        expect(&run_open)
          .to output(/Successfully opened release-2015-01-01 for other-app/).to_stdout

        expect(Common.app_status('/aatc_test/other-app', :force).open_release)
          .to eq 'release-2015-01-01'
      end
    end

    context 'when the app has "develop" aliased as "letest"', alias: true do
      it 'uses "letest" instead of "develop"' do
        app_status = Common.app_status('/aatc_test/other-app', :force)
        expect(app_status.open_release).to be_nil

        c = config(:force)
        c['apps'].find { |a| a['name'] == 'other-app' }['aliases'] = { 'develop' => 'letest' }

        input = StringIO.new
        input.puts 'release-2015-01-01'
        input.puts 'other-app'
        input.rewind

        stub_chdir_with('/aatc_test/other-app').twice
        stub_input_with(input)

        expect_clean_git_status
        expect_git_branch('master', 'letest', 'local')
        expect_successful_git_checkout('letest')
        expect_successful_git_pull('letest')
        expect_successful_git_checkout_b('release-2015-01-01')
        expect_successful_git_add_a
        expect_successful_git_commit('RELEASE OPENED: release-2015-01-01')
        expect_successful_git_push('release-2015-01-01')

        expect(&run_open)
          .to output(/Successfully opened release-2015-01-01 for other-app/).to_stdout

        expect(Common.app_status('/aatc_test/other-app', :force).open_release)
          .to eq 'release-2015-01-01'
      end
    end

    context 'when the app already has an open release' do
      before(:each) do
        status = Common.app_status('/aatc_test/what-up/', :force)
        status.open_release = 'release-2015-01-01'
        status.save
      end

      it 'informs the user that the app cannot be opened' do
        expect do
          expect(&run_open('release-2015-01-01', 'other-app'))
            .to output('Cannot open new release').to_stderr
        end
          .to raise_error
      end
    end

    context 'with <release-name> <appname> args', :test_cmd do
      it 'opens the given release' do
        stub_chdir_with('/aatc_test/other-app').twice
        
        expect_clean_git_status
        expect_git_branch('master', 'develop', 'ok')
        expect_successful_git_checkout('develop')
        expect_successful_git_pull('develop')
        expect_successful_git_checkout_b('release-2015-01-01')
        expect_successful_git_add_a
        expect_successful_git_commit('RELEASE OPENED: release-2015-01-01')
        expect_successful_git_push('release-2015-01-01')

        expect(&run_open('release-2015-01-01', 'other-app'))
          .to output(/Successfully opened release-2015-01-01 for other-app/).to_stdout

        expect(Common.app_status('/aatc_test/other-app', :force).open_release)
          .to eq 'release-2015-01-01'
      end

      it 'works when there are only deletions or insertions', limit: true do
        stub_chdir_with('/aatc_test/other-app').at_least(:once)

        %w(without_insertions without_deletions).each do |suffix|
          expect_clean_git_status
          expect_git_branch('master', 'develop', 'ok')
          expect_successful_git_checkout('develop')
          expect_successful_git_pull('develop')
          expect_successful_git_checkout_b('release-2015-01-01')
          expect_successful_git_add_a
          method("expect_successful_git_commit_#{suffix}").call('RELEASE OPENED: release-2015-01-01')
          expect_successful_git_push('release-2015-01-01')

          expect(&run_open('release-2015-01-01', 'other-app'))
            .to output(/Successfully opened release-2015-01-01 for other-app/).to_stdout

          File.unlink Common.status_file '/aatc_test/other-app'
          refresh_cmd!
        end
      end
    end
  end

  describe '#run_close' do
    context 'when passed "all"' do
      it 'closes them all', all: true do
        release = 'release-2014-07-02'

        app_paths.each do |path|
          status = Common.app_status(path, :force)
          status.open_release = release
          status.save
          stub_chdir_with(path).twice
        end

        [
         expect_clean_git_status,
         expect_successful_git_checkout(release),
         expect_successful_git_pull(release),
         expect_successful_git_add_a,
         expect_successful_git_commit('RELEASE CLOSED: release-2014-07-02'),
         expect_successful_git_push(release)
        ]
          .each { |e| e.at_least(app_paths.size).times }

        expect(&run_close(release, 'all'))
          .to output(/Successfully/).to_stdout

        app_paths.each do |path|
          expect(Common.app_status(path, :force).open_release).to be_nil
        end
      end
    end

    context 'with no args' do
      it 'Asks the user for input before closing' do
        path    = '/aatc_test/what-up'
        release = 'release-2014-07-02'

        status = Common.app_status(path, :force)
        status.open_release = release
        status.save

        input = StringIO.new
        input.puts release
        input.puts 'first-app'
        input.rewind
        stub_input_with(input)

        stub_chdir_with(path).twice

        expect_clean_git_status
        expect_successful_git_checkout(release)
        expect_successful_git_pull(release)
        expect_successful_git_add_a
        expect_successful_git_commit('RELEASE CLOSED: release-2014-07-02')
        expect_successful_git_push(release)

        expect(&run_close).to output(/Successfully/).to_stdout
        expect(Common.app_status('/aatc_test/what-up', :force).open_release).to be_nil
      end
    end
  end

  describe 'run_hotfix' do
    it 'checks out master, then creates a new branch with the given title' do
      stub_chdir_with('/aatc_test/what-up').twice
      expect_clean_git_status
      expect_successful_git_checkout('master')
      expect_successful_git_pull('master')
      expect_successful_git_checkout_b('hotfix-fix-things')
      expect_successful_git_add_a
      expect_successful_git_commit('HOTFIX INITIATED: fix-things')

      expect(&run_hotfix('fix-things', 'first-app'))
       .to output(/now working on hotfix fix-things/).to_stdout
    end

    it 'works when current directory is project root' do
      stub_chdir_with('/aatc_test/what-up').twice
      expect_clean_git_status
      expect_successful_git_checkout('master')
      expect_successful_git_pull('master')
      expect_successful_git_checkout_b('hotfix-fix-things')
      expect_successful_git_add_a
      expect_successful_git_commit('HOTFIX INITIATED: fix-things')

      expect(Dir).to receive(:pwd).and_return('/aatc_test/what-up').at_least(:once)

      expect(&run_hotfix('fix-things'))
       .to output(/now working on hotfix fix-things/).to_stdout
    end

    it 'fails when not given a valid app' do
      expect do
        expect(&run_hotfix('fix-things'))
          .to output(/Please specify an app name, or cd into an app's project root/)
          .to_stderr
      end
        .to raise_error
    end
  end

  describe 'run_hotfix_close' do
    context 'when app is not currently working on a hotfix' do
      it 'issues an error' do
        expect do
          expect(&run_hotfix_close('first-app'))
            .to output(/There appears to be no hotfix on the current branch for first-app/)
            .to_stderr
        end
          .to raise_error
      end
    end

    context 'when the given app is in the middle of a hotfix' do
      it 'unmarks the hotfix, merges with master/develop, and reminds user to merge release' do
        status = Common.app_status('/aatc_test/what-up', :force)
        status.hotfix = 'my-hotfix'
        status.save

        stub_chdir_with('/aatc_test/what-up')

        # expect_git_branch('master', 'develop', 'hotfix-my-hotfix', on: 'hotfix-my-hotfix')
        expect_clean_git_status
        expect_successful_git_add_a
        expect_successful_git_commit('HOTFIX CLOSED: my-hotfix')
        expect_successful_git_checkout('master')
        expect_successful_git_pull('master')
        expect_successful_git_merge('hotfix-my-hotfix')
        expect_successful_git_push('master')

        expect_successful_git_checkout('develop')
        expect_successful_git_pull('develop')
        expect_successful_git_merge('hotfix-my-hotfix')
        expect_successful_git_push('develop')

        expect(&run_hotfix_close('first-app'))
          .to output(/It is up to you to merge hotfix-my-hotfix with the current release/)
          .to_stdout

        status = Common.app_status('/aatc_test/what-up', :force)
        expect(status.hotfix).to be_nil
      end
    end
  end

  describe 'run_release' do
    context 'when there are no conflicts' do
      it 'merges develop into master and then pushes' do
        input = StringIO.new
        input.puts 'yes'
        input.rewind

        stub_input_with(input)
        stub_chdir_with('/aatc_test/what-up').twice

        expect_clean_git_status
        expect_successful_git_checkout('develop')
        expect_successful_git_pull('develop')
        expect_successful_git_checkout('master')
        expect_successful_git_pull('master')

        expect_successful_git_merge('develop')
        expect_successful_git_push('master')

        expect(&run_release('first-app')).to output(/Successfully released all given apps/).to_stdout
      end
    end
  end
end
