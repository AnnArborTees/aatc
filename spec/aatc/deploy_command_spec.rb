require 'spec_helper'
require 'aatc'
require 'aatc/common'
require 'aatc/deploy_command'
require 'byebug' if RUBY_ENGINE != 'rbx'

describe Aatc::DeployCommand, type: :command do
  describe '#run_deploy' do
    before(:each) do
      app_paths.each do |path|
        FileUtils.mkdir_p path + '/log'
      end
    end

    context 'staging', 'all' do
      context 'when deployment is successful for all apps' do
        it 'calls cap staging deploy in each app folder' do
          app_paths.each do |path|
            stub_chdir_with(path)

            expect(cmd).to receive(:system)
              .with('bundle exec cap staging deploy -q branch=develop > log/failed-deploy.log')
              .and_return true
          end

          expect(&run_deploy('staging', 'all')).to output(/Deployed all apps/).to_stdout
        end

        it 'kills any failed-deploy.logs it may have generated', not_working: true do
          app_paths.each do |path|
            stub_chdir_with(path)

            expect(cmd).to receive(:system)
              .with('bundle exec cap staging deploy -q branch=develop > log/failed-deploy.log') { |_|
                File.open(path + '/log/failed-deploy.log', 'w') do |f|
                  f.write "This should not make it through to the end of the command."
                end
                true
              }
          end

          run_deploy('staging', 'all').call

          app_paths.each do |path|
            expect(File.exists?(path + '/log/failed-deploy.log'))
              .to_not be_truthy
          end
        end

        context 'given --branch=hello' do
          it 'deploys from the "hello" branch' do
            app_paths.each do |path|
              stub_chdir_with(path)

              expect(cmd).to receive(:system)
                .with('bundle exec cap staging deploy -q branch=hello > log/failed-deploy.log')
                .and_return true
            end

            run_deploy('staging', 'all', '--branch=hello').call
          end
        end
      end

      context 'when deployment fails for all apps' do
        it "dumps the output of the system call to failed-deploy.log in the app's path" do
          app_paths.each do |path|
            stub_chdir_with(path)

            expect(cmd).to receive(:system)
              .with('bundle exec cap staging deploy -q branch=develop > log/failed-deploy.log') { |_|
                File.open(path + '/log/failed-deploy.log', 'w') do |f|
                  f.write "Bad deploy. Real bad."
                end
                false
              }
          end

          expect(&run_deploy('staging', 'all'))
            .to output(/All apps have received a failed-deploy\.log/)
            .to_stderr

          app_paths.each do |path|
            expect(File.exists?(path + '/log/failed-deploy.log')).to be_truthy
            File.open(path + '/log/failed-deploy.log') do |f|
              expect(f.read).to eq 'Bad deploy. Real bad.'
            end
          end
        end
      end
    end
  end
end
