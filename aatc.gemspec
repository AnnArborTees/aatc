# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aatc/version'

Gem::Specification.new do |spec|
  spec.name          = "aatc"
  spec.version       = Aatc::VERSION
  spec.authors       = ["Resonious"]
  spec.email         = ["metreckk@gmail.com"]
  spec.summary       = %q{Command line tools for AATC dev workflow.}
  spec.description   = %q{Command line tools for Ann Arbor T-Shirt Company's
                          software development workflow.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "fakefs"
end
