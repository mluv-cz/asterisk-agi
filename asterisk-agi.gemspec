lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'asterisk/agi/version'

Gem::Specification.new do |spec|
  spec.name          = "asterisk-agi"
  spec.version       = Asterisk::Agi::VERSION
  spec.authors       = ["Jan Svoboda"]
  spec.email         = ["jan@mluv.cz"]
  spec.summary       = %q{Ruby server library for the Asterisk Gateway Interface (AGI).}
  spec.description   = %q{Ruby server library for the Asterisk Gateway Interface (AGI).}
  spec.homepage      = "https://github.com/mluv-cz/asterisk-agi"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 1.9"

  spec.add_dependency "gserver"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"

  spec.add_development_dependency "minitest", "~> 5.4"
end
