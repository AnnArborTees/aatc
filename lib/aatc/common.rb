module Aatc
  module Common
    extend self

    def require_rugged!
      return if defined?(Rugged)
      return unless require 'rugged'
      fail 'Could not require rugged. Run `gem install rugged`.'
    end

    def camelize(term)
      string = term.to_s
      string = string.sub(/^[a-z\d]*/) { $&.capitalize }
      string.gsub!(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{$2.capitalize}" }
      string.gsub!(/\//, '::')
      string
    end
  end
end
