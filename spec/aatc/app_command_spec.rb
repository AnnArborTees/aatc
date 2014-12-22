require 'spec_helper'
require 'aatc'
require 'aatc/app_command'
begin
  require 'byebug'
rescue StandardError => e
end

describe Aatc::AppCommand, type: :command do
  let(:valid_apps_yml) do
    %(
      apps:
        -
          name: first-app
          path: ~/aatc_test/what-up
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
          path: ~/somewhere/else
    )
  end

  def config(force = false)
    cmd.send(:config, force)
  end

  before(:each) do
    Aatc::AppCommand.const_set 'CONFIG_PATH', 'aatc'
    FakeFS.activate!

    Dir.mkdir(Aatc::AppCommand::CONFIG_PATH)
    File.open(Aatc::AppCommand::CONFIG_PATH + '/apps.yml', 'w+') do |f|
      f.write(valid_apps_yml)
    end
  end

  describe '#run_apps' do
    context 'given a valid apps.yml file' do

      context 'with no args' do
        it 'lists every app name from the yml' do
          expect(&run_apps).to output(/first\-app/).to_stdout
          expect(&run_apps).to output(/other\-app/).to_stdout
          expect(&run_apps).to output(/unreleased/).to_stdout
        end
      end

      context 'with -p' do
        it 'lists every app name and their full paths' do
          expect(&run_apps('-p')).to output(/\~\/aatc_test\/what-up/).to_stdout
          expect(&run_apps('-p')).to output(/\~\/aatc_test\/other-app/).to_stdout
          expect(&run_apps('-p')).to output(/\~\/somewhere\/else/).to_stdout
        end
      end

      context 'with --last-closed' do
        it 'prints the last closed release branch for each app' do
          expect(&run_apps('--last-closed'))
            .to output(/release\-2014\-06\-15/).to_stdout

          expect(&run_apps('--last-closed'))
            .to output(/\<none\>/).to_stdout
        end
      end
    end

    context 'given an invalid apps.yml file' do
      it 'prints a warning or something'
    end
  end

  describe '#run_add_app' do
    context 'with no args' do
      context 'and valid stream input' do
        it 'writes an app entry to apps.yml' do
          before_names = config['apps'].map { |a| a['name'] }
          before_paths = config['apps'].map { |a| a['path'] }
          expect(before_names).to_not include 'new-app'
          expect(before_paths).to_not include '~/some/path'

          input = StringIO.new
          input.puts 'new-app'
          input.puts '~/some/path'
          input.rewind

          allow(cmd).to receive(:gets, &input.method(:gets))

          expect(&run_add_app).to output(/Successfully/).to_stdout

          after_names = config(true)['apps'].map { |a| a['name'] }
          after_paths = config(true)['apps'].map { |a| a['path'] }
          expect(after_names).to include 'new-app'
          expect(after_paths).to include '~/some/path'
        end
      end

      context 'with valid input args' do
        it 'writes an app entry to apps.yml' do
          before_names = config['apps'].map { |a| a['name'] }
          before_paths = config['apps'].map { |a| a['path'] }
          expect(before_names).to_not include 'new-app'
          expect(before_paths).to_not include '~/some/path'

          expect(&run_add_app('new-app', '~/some/path')).to output(/Successfully/).to_stdout

          after_names = config(true)['apps'].map { |a| a['name'] }
          after_paths = config(true)['apps'].map { |a| a['path'] }
          expect(after_names).to include 'new-app'
          expect(after_paths).to include '~/some/path'
        end
      end
    end
  end

  describe '#run_rm_app' do
    context 'when we actually want to remove the app' do
      before(:each) do
        before_names = config['apps'].map { |a| a['name'] }
        expect(before_names).to include 'first-app'
      end

      after(:each) do
        after_names = config(true)['apps'].map { |a| a['name'] }
        expect(after_names).to_not include 'first-app'
      end

      context 'with no args' do
        it 'asks which app should be removed' do
          input = StringIO.new
          input.puts 'first-app'
          input.puts 'y'
          input.rewind

          allow(cmd).to receive(:gets, &input.method(:gets))

          expect(&run_rm_app).to output(/was removed/).to_stdout
        end
      end

      context 'with an app name argument' do
        it 'asks if you are sure, then removes the app with that name' do
          input = StringIO.new
          input.puts 'y'
          input.rewind

          allow(cmd).to receive(:gets, &input.method(:gets))

          expect(&run_rm_app('first-app')).to output(/was removed/).to_stdout
        end
      end

      context 'with -f and an app name argument' do
        it 'removes the app with the given name without asking' do
          expect(&run_rm_app('-f', 'first-app')).to output(/was removed/).to_stdout
        end
      end
    end

    context 'when we do not want to remove the app' do
      before(:each) do
        before_names = config['apps'].map { |a| a['name'] }
        expect(before_names).to include 'first-app'
      end

      after(:each) do
        after_names = config(true)['apps'].map { |a| a['name'] }
        expect(after_names).to include 'first-app'
      end

      context 'with no args' do
        it 'asks, and then saying no cancels the deletion' do
          input = StringIO.new
          input.puts 'first-app'
          input.puts 'n'
          input.rewind

          allow(cmd).to receive(:gets, &input.method(:gets))

          expect(&run_rm_app).to output(/was not removed/).to_stdout
        end
      end

      context 'with an app name argument' do
        it 'asks, then saying no cancels the deletion' do
          input = StringIO.new
          input.puts 'n'
          input.rewind

          allow(cmd).to receive(:gets, &input.method(:gets))

          expect(&run_rm_app('first-app')).to output(/was not removed/).to_stdout
        end
      end
    end
  end
end
