
require 'serverspec'
require 'net/ssh'
require 'yaml'

host = ENV['TARGET_HOST']
ssh_config_files = ['./.vagrant/ssh-config'] + Net::SSH::Config.default_files
options = Net::SSH::Config.for(host, ssh_config_files)
options[:user] ||= 'vagrant'
options[:keys].push("#{Dir.home}/.vagrant.d/insecure_private_key")

set :backend, :ssh
set :host, host
set :ssh_options, options

def to_ini_value(value)
  return '' if value.nil?
  if !!value === value
    return value ? 'On' : 'Off'
  end
  escape_value = value.is_a?(String) ? value : value.to_s
  Regexp.escape(escape_value)
end

def e(value)
  Regexp.escape(value.is_a?(String) ? value : value.to_s)
end

class ::Hash
  def deep_merge(other_hash, &block)
    dup.deep_merge!(other_hash, &block)
  end

  def deep_merge!(other_hash, &block)
    other_hash.each_pair do |k, v|
      tv = self[k]
      if tv.is_a?(Hash) && v.is_a?(Hash)
        self[k] = tv.deep_merge(v, &block)
      else
        self[k] = block && tv ? block.call(k, tv, v) : v
      end
    end
    self
  end
end

spec_dir = File.dirname(__FILE__)
role_dir = File.dirname(spec_dir)

test_vars = {}

var_file = File.join(role_dir, 'defaults', 'main.yml')
test_vars.deep_merge!(YAML.load_file(var_file)) if File.exist?(var_file)

group_names = ['all']

var_file = File.join(role_dir, '.molecule', 'facts', host + '.yml')
if File.exist?(var_file)
  test_vars.merge!(YAML.load_file(var_file))
  group_names = test_vars['group_names'].unshift('all') if test_vars.key?('group_names')
end

group_names.each do |name|
  var_file = File.join(role_dir, '.molecule', 'group_vars', name)
  test_vars.deep_merge!(YAML.load_file(var_file)) if File.exist?(var_file)
end

var_file = File.join(role_dir, '.molecule', 'host_vars', host)
test_vars.deep_merge!(YAML.load_file(var_file)) if File.exist?(var_file)

var_file = File.join(role_dir, 'vars', 'main.yml')
test_vars.deep_merge!(YAML.load_file(var_file)) if File.exist?(var_file)

set_property test_vars

RSpec.configure do |config|
  config.color = true
  config.tty = true
  config.formatter = :documentation
end