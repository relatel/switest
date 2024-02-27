Gem::Specification.new do |s|
  s.name     = "switest"
  s.version  = "0.1"
  s.date     = "2015-04-23"
  s.summary  = "Switest"
  s.email    = "teknik@relatel.dk"
  s.homepage = "http://github.com/relatel/switest"
  s.description = "Functional testing for voice applications"
  s.authors  = ["Harry Vangberg", "Relatel A/S"]
  s.files    = Dir["lib/**/*"] + %w(README.md)
  s.test_files = Dir["test/**/*"]

  s.add_dependency "adhearsion", "~> 3.0.0.rc1"
  s.add_dependency "timers", "~> 4.0"
  s.add_dependency "minitest", "~> 5.5.0"
end
