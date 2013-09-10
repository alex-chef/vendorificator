require 'fileutils'
require 'tmpdir'
require 'thor/shell/basic'
require 'yaml'
require 'vendorificator/config'

module Vendorificator
  class Vendor

    class << self
      attr_accessor :group, :method_name

      def arg_reader(*names)
        names.each do |name|
          define_method(name) do
            args[name]
          end
        end
      end
    end

    attr_reader :environment, :name, :args, :block, :unit
    attr_accessor :git
    arg_reader :version

    def initialize(environment, name, args = {}, &block)
      @environment = environment
      @name = name
      @block = block
      @metadata = {
        :unparsed_args => args.clone
      }
      @metadata[:parsed_args] = @args = parse_initialize_args(args)
      @metadata[:module_annotations] = @args[:annotate] if @args[:annotate]

      @unit = if config.overlay_instance
                Unit::Overlay.new(vendor: self)
              else
                Unit::Vendor.new(vendor: self)
              end
      @environment.units << @unit
    end

    def ===(other)
      other === name || File.expand_path(other.to_s) == unit.work_dir
    end

    def group
      defined?(@group) ? @group : self.class.group
    end

    def inspect
      "#<#{self.class} #{self}>"
    end

    def version
      @args[:version] ||
        (!config[:use_upstream_version] && unit.merged_version) ||
        upstream_version
    end

    def conjure!
      block.call(self) if block
    end

    # Hook points
    def git_add_extra_paths ; [] ; end
    def before_conjure! ; end
    def compute_dependencies! ; end
    def upstream_version ; end

    def metadata
      default = {
        :module_name => @name,
        :module_version => version,
        :module_group => @group,
      }
      default.merge @metadata
    end

    def conjure_commit_message
      "Conjured vendor module #{name} version #{version}"
    end

    private

    def parse_initialize_args(args = {})
      @group = args.delete(:group) if args.key?(:group)
      if args.key?(:category)
        @group ||= args.delete(:category)
        say_status :default, 'DEPRECATED', 'Using :category option is deprecated and will be removed in future versions. Use :group instead.'
      end

      unless (hooks = Array(args.delete(:hooks))).empty?
        hooks.each do |hook|
          hook_module = hook.is_a?(Module) ? hook : ::Vendorificator::Hooks.const_get(hook)
          klass = class << self; self; end;
          klass.send :include, hook_module
        end
      end

      args
    end

    def git
      @git || environment.git
    end

    def config
      environment.config
    end

    def work_dir
      unit.work_dir
    end

    def shell
      environment.shell
    end

    def say(verb_level= :default, &block)
      output = yield
      environment.say verb_level, output
    end

    def say_status(*args, &block)
      environment.say_status(*args, &block)
    end
  end

  Config.register_module :vendor, Vendor
end
