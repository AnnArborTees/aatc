module Aatc
  # Perhaps this is how this command should be used:
  #
  # aatc close 2014-09-19 softwear-crm annarbortees-spree spree_mockbot_integration
  #
  # OR
  #
  # aatc close 09-19
  # 
  # Then it asks, current year?, close all apps?
  class Close
    include Common

    def run(args)
      require_rugged!

      puts 'insert me doing the close thing here'
    end
  end
end
