# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'yattr_encrypted/version'
require 'date'

Gem::Specification.new do |s|
  s.name    = 'yattr_encrypted'
  s.version = YattrEncrypted::VERSION
  s.date    = Date.today

  s.summary     = 'Encrypt and decrypt attributes'
  s.description = 'Generates yattr_accessors that encrypt and decrypt attributes transparently.' \
    + ' Based on attr_encrypted by Sean Huber [https://github.com/shuber]'

  s.author    = 'Mike Howard'
  s.email     = 'mike@clove.com'
  s.homepage  = 'http://github.mikhoward/yattr_encrypted'
  # s.author   = 'Sean Huber'
  # s.email    = 'shuber@huberry.com'
  # s.homepage = 'http://github.com/shuber/attr_encrypted'

  s.has_rdoc = false
  s.rdoc_options = ['--line-numbers', '--inline-source', '--main', 'README.mdown']

  s.require_paths = ['lib']

  s.files      = Dir['{bin,lib}/**/*'] + %w(MIT-LICENSE Rakefile README.mdown Gemfile)
  s.test_files = Dir['test/**/*']

  s.add_development_dependency('pry')
end