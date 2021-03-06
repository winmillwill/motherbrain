module MotherBrain
  module Cli
    module SubCommand
      # A set of component tasks collected into a SubCommand to be registered with the
      # CliGateway. This class should not be instantiated, configured, and used by itself.
      # Use {SubCommand::Component.fabricate} to create an anonymous class of this type.
      #
      # @api private
      class Component < SubCommand::Base
        class << self
          extend Forwardable

          def_delegator :component, :description

          # Return the component associated with this instance of the class
          #
          # @return [MB::Component]
          attr_reader :component

          # @param [MB::Component] component
          #
          # @return [SubCommand::Component]
          def fabricate(component)
            environment = CliGateway.invoked_opts[:environment]

            Class.new(self) do
              set_component(component)

              component.commands.each do |command|
                define_task(command)
              end

              desc("nodes", "List all nodes grouped by Group")
              define_method(:nodes) do
                ui.say "Listing nodes for '#{component.name}' in '#{environment}':"
                nodes = component.nodes(environment).each do |group, nodes|
                  nodes.collect! { |node| "#{node.public_hostname} (#{node.public_ipv4})" }
                end
                ui.say nodes.to_yaml
              end
            end
          end

          # Set the component for this instance of the class and tailor the class for the
          # given component.
          #
          # @param [MB::Component] component
          def set_component(component)
            self.namespace(component.name)
            @component = component
          end
        end
      end
    end
  end
end
