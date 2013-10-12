# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "poro_repository"
  s.version     = "0.0.2"
  s.authors     = ["Joel Plane"]
  s.email       = ["joel.plane@gmail.com"]
  s.homepage    = "https://github.com/joelplane/poro_repository"
  s.summary     = %q{PORO Repository}
  s.description = %q{Library for storing plain old ruby objects to the file system}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
end
