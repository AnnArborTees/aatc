require 'spec_helper'
require 'aatc'

describe Aatc do
  describe 'Subcommands' do
    Aatc::SUBCOMMANDS.each do |subcommand, filename|
      context "#{subcommand.to_s.gsub('_', '-')}" do
        it 'has an existing, corrosponding file' do
          expect{require("aatc/#{filename}_command")}.to_not raise_error
        end

        it "has a corrosponding class with the run_#{subcommand} method" do
          require("aatc/#{filename}_command")
          class_name = Aatc.camelize(filename) + 'Command'
          get_class_name = proc {Kernel.const_get "Aatc::#{class_name}"}

          expect(&get_class_name).to_not raise_error
          subcmd_class = get_class_name.call

          expect(subcmd_class.new).to respond_to "run_#{subcommand}"
        end

        it "has a corrosponding class with the help_#{subcommand} method" do
          require("aatc/#{filename}_command")
          class_name = Aatc.camelize(filename) + 'Command'
          get_class_name = proc {Kernel.const_get "Aatc::#{class_name}"}

          expect(&get_class_name).to_not raise_error
          subcmd_class = get_class_name.call

          expect(subcmd_class.new).to respond_to "help_#{subcommand}"
        end
      end
    end
  end
end
