require 'spec_helper'
require 'aatc'
require 'aatc/common'

describe Aatc::DeployCommand, type: :command do
  describe '#run_deploy' do
    context 'staging' do
      context 'when deployment is successful for all apps' do
        it 'calls cap staging deploy in each app folder' do
          app_paths.each do |path|
            stub_chdir_with(path)
            expect(cmd).to receive(:system).with('bundle exec cap staging deploy')
              .and_return true
          end

          expect(&run_deploy).to output("all apps succeeded").to_stdout
        end
      end

      context 'when deployment fails for an app' do
        it "dumps the output of the system call to failed-deploy.log in the app's path"
      end
    end
  end
end
