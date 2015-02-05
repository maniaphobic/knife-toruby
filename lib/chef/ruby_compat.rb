#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/role'
require 'chef/environment'
require 'stringio'
require "awesome_print"

# Wrapper class for interacting with Ruby.

class Chef
  class RubyCompat

    def self.to_ruby(data)

      case data
      when Chef::Role
        role_to_ruby(data)
      when Chef::Environment
        environment_to_ruby(data)
      else
        raise ArgumentError, "[#{data.class.name}] is not supported by ruby format"
      end

    end

    private

    def self.role_to_ruby(role)
      ruby = RubyIO.new

      # Emit a string encoding header to satisfy Rubocop
      ruby.write('# encoding: utf-8')
      ruby.new_line
      ruby.new_line

      # Name
      ruby.write_method("name", role.name)
      ruby.new_line

      # Description
      ruby.write_method("description", role.description)
      ruby.new_line

      # Default Attributes
      ruby.write_method("default_attributes", role.default_attributes)
      ruby.new_line

      # Override Attributes
      ruby.write_method("override_attributes", role.override_attributes)
      ruby.new_line

      # Run list
      if role.env_run_lists.size <= 1
        ruby.write_method("run_list", *role.run_list.map{|val| val.to_s})
      else
        ruby.write_method("env_run_lists", Hash[role.env_run_lists.map{|k, v| [k, v.map{|val| val.to_s}]}])
      end
      ruby.new_line

      ruby.string
    end

    def self.environment_to_ruby(environment)
      ruby = RubyIO.new

      # Name
      ruby.write_method("name",  environment.name)
      ruby.new_line

      # Description
      ruby.write_method("description", environment.description)
      ruby.new_line

      # Cookbook versions
      environment.cookbook_versions.each do |cookbook, version_constraint|
        ruby.write_method("cookbook", cookbook, version_constraint)
      end
      ruby.new_line

      # Default Attributes
      ruby.write_method("default_attributes", environment.default_attributes)
      ruby.new_line

      # Override Attributes
      ruby.write_method("override_attributes", environment.override_attributes)
      ruby.new_line

      ruby.string
    end

    class RubyIO

      @@inspector =AwesomePrint::Inspector.new :plain => true, :indent => 2, :index => false, :multiline => true

      def initialize
        @out = StringIO.new
      end

      def write_method(method_name, *args)
        write method_name
        write("(\n")

        arg_values = args.map do |arg|
          if arg.is_a? String
            CustomString.new(arg).inspect
          elsif arg.is_a? Hash
            format(arg)
          else
            raise "Object type [#{arg.class.name}] is not supported"
          end
        end

        write(arg_values.join(",\n").gsub(/^/, '  '))

        write("\n)")

        new_line
      end

      def new_line
        write "\n"
      end

      def write(string)
        @out.write string
      end

      def string
        # Strip trailing whitespace to satisfy Rubocop
        @out.string.rstrip
      end

      def format(obj)
#DEBUG#        $stderr.write("!!!: obj =>#{obj}<=\n") #DEBUG#
        @@inspector.awesome obj
      end

    end

    class CustomString < String

      def initialize(new_string)
        @string = new_string
      end

      def inspect() to_s end

      def to_s() "'#{@string}'" end

    end

  end
end
