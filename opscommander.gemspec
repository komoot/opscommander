# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "mygem/version"

Gem::Specification.new do |s|
  s.name        = "opscommander"
  s.version     = "0.1.0"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jan Heuer", "Johannes Staffans"]
  s.email       = ["jan@komoot.de" "johannes@komoot.de"]
  s.homepage    = ""
  s.summary     = %q{OpsWorks commander}
  s.description = %q{Scripting for AWS OpsWorks}

  s.add_runtime_dependency "commander", ">=4.2.1"
  s.add_runtime_dependency "aws-sdk", ">=1.0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
