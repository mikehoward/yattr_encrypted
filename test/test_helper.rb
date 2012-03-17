require 'pry'
require 'minitest/autorun'
require 'digest/sha2'
require 'rubygems'
# gem 'activerecord', ENV['ACTIVE_RECORD_VERSION'] if ENV['ACTIVE_RECORD_VERSION']
# require 'active_record'
# require 'mocha'

$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift(File.dirname(__FILE__))
require 'yattr_encrypted'
