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
    )
  end
  # let!(:cmd) { Aatc::AppCommand.new }
  # def run_apps(*args)
  #   proc { cmd.run_apps(*args) }
  # end

  describe '#run_apps' do
    context 'given a valid apps.yml file' do
      before(:each) do
        Aatc::AppCommand.const_set 'CONFIG_PATH', 'aatc'
        FakeFS.activate!

        Dir.mkdir(Aatc::AppCommand::CONFIG_PATH)
        File.open(Aatc::AppCommand::CONFIG_PATH + '/apps.yml', 'w+') do |f|
          f.write(valid_apps_yml)
        end
      end
      after(:each) do
        FakeFS.deactivate!
      end

      context 'with no args' do
        it 'lists every app name from the yml' do
          expect(&run_apps).to output(/first\-app/).to_stdout
          expect(&run_apps).to output(/other\-app/).to_stdout
        end
      end

      context 'with -p' do
        it 'lists every app name and their full paths'
      end
    end

    context 'given an invalid apps.yml file' do
      it 'prints a warning or something'
    end
  end
end
