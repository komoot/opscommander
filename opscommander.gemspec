# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "opscommander"
  s.license     = "Apache 2.0"
  s.version     = "1.0.4"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jan Heuer", "Johannes Staffans"]
  s.email       = ["jan@komoot.de" "johannes@komoot.de"]
  s.homepage    = ""
  s.summary     = %q{OpsWorks commander}
  s.description = %q{Scripting for AWS OpsWorks}

  s.add_runtime_dependency "commander", "~>4.2"
  s.add_runtime_dependency "aws-sdk-v1", "~>1.59"
  s.add_runtime_dependency "aws-sdk", "~>2.0.0.pre"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
