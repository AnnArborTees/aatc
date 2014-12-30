require 'spec_helper'
require 'aatc'
require 'aatc/app_command'

describe Aatc::AppCommand, type: :command do
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
          expect(&run_apps('-p')).to output(/\/aatc_test\/what-up/).to_stdout
          expect(&run_apps('-p')).to output(/\/aatc_test\/other-app/).to_stdout
          expect(&run_apps('-p')).to output(/\/somewhere\/else/).to_stdout
        end
      end

      context 'with --last-closed', pending: true do
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
          # Enter app name.
          input.puts 'new-app'
          # Enter app path.
          input.puts '~/some/path'
          input.rewind

          stub_input_with(input)

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

  describe '#run_rm_app', rm: true do
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
          # Enter app name.
          input.puts 'first-app'
          # Are you sure?
          input.puts 'y'
          input.rewind

          stub_input_with(input)

          expect(&run_rm_app).to output(/was removed/).to_stdout
        end
      end

      context 'with an app name argument' do
        it 'asks if you are sure, then removes the app with that name' do
          input = StringIO.new
          # Are you sure?
          input.puts 'y'
          input.rewind

          stub_input_with(input)

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
          # Enter app name.
          input.puts 'first-app'
          # Are you sure?
          input.puts 'n'
          input.rewind

          stub_input_with(input)

          expect(&run_rm_app).to output(/was not removed/).to_stdout
        end
      end

      context 'with an app name argument' do
        it 'asks, then saying no cancels the deletion' do
          input = StringIO.new
          # Are you sure?
          input.puts 'n'
          input.rewind

          stub_input_with(input)

          expect(&run_rm_app('first-app')).to output(/was not removed/).to_stdout
        end
      end
    end
  end
end
