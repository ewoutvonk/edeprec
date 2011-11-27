# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "edeprec"
  s.version     = "0.9.8.1"
  s.authors     = ["Ewout Vonk"]
  s.email       = ["dev@ewout.to"]
  s.homepage    = "https://github.com/ewoutvonk/edeprec"
  s.summary     = %q{All deprec extensions developed by ewoutvonk combined + set of extra recipes for deprec + profiles}
  s.description = %q{All deprec extensions developed by ewoutvonk combined + set of extra recipes for deprec + profiles}

  s.rubyforge_project = "edeprec"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "deprec"
  s.add_runtime_dependency "deprec-check-roles"
  s.add_runtime_dependency "deprec-config-compare"
  s.add_runtime_dependency "deprec-default-task-stubs"
  s.add_runtime_dependency "deprec-filter-hosts"
  s.add_runtime_dependency "deprec-generate-variables-configs"
  s.add_runtime_dependency "deprec-substitute-in-file"
  s.add_runtime_dependency "capistrano"
end
