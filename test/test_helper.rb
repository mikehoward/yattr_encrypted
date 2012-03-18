require 'pry'
require 'minitest/autorun'
require 'digest/sha2'
require 'rubygems'

$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift(File.dirname(__FILE__))
require 'yattr_encrypted'
