# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

# prevent loading when called by Bundler, only load when called by capistrano
if caller.any? { |callstack_line| callstack_line =~ /^Capfile:/ }
  unless Capistrano::Configuration.respond_to?(:instance)
    abort "edeprec requires Capistrano 2"
  end

  require 'deprec_minus_rails'

  all_deprec_extensions = [
    "deprec-check-roles",
    "deprec-config-compare",
    "deprec-default-task-stubs",
    "deprec-filter-hosts",
    "deprec-generate-variables-configs",
    "deprec-substitute-in-file"
  ]
  load_deprec_extensions = []

  if defined?(EXCLUDE_DEPREC_EXTENSIONS)
    load_deprec_extensions += all_deprec_extensions.reject { |ext| EXCLUDE_DEPREC_EXTENSIONS.include?(ext.to_sym) }
  elsif defined?(INCLUDE_DEPREC_EXTENSIONS)
    load_deprec_extensions += all_deprec_extensions.select { |ext| INCLUDE_DEPREC_EXTENSIONS.include?(ext.to_sym) }
  else
    load_deprec_extensions += all_deprec_extensions
  end

  load_deprec_extensions.each do |ext|
    require "#{ext}"
  end

  Dir.glob("#{File.dirname(__FILE__)}/edeprec/recipes/**/*.rb").collect do |filename|
    require filename
  end

  require "edeprec/profiles"

  [ :edeprec, :ubuntu, :hardy, :lucid ].each do |base_namespace|
    define_check_roles_tasks(base_namespace)
    define_config_compare_tasks(base_namespace)
    define_default_task_stubs(base_namespace)
    define_generate_variables_configs_tasks(base_namespace)
  end
end