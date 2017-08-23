module Trailblazer
  # Note that Graph is a superset of a real directed graph. For instance, it might contain detached nodes.
  # == Design
  # * This class is designed to maintain a graph while building up a circuit step-wise.
  # * It can be imperformant as this all happens at compile-time.
  module Activity::Graph
    # Task => { name: "Nested{Task}", type: :subprocess, boundary_events: { Circuit::Left => {} }  }

    # TODO: make Edge, Node, Start Hash::Immutable ?
    class Edge
      def initialize(data)
        @data = data.freeze
      end

      def [](key)
        @data[key]
      end

      def to_h
        @data.to_h
      end
    end

    class Node < Edge
    end

    class Start < Node
      def initialize(data)
        yield self, data if block_given?
        super
      end

      # Single entry point for adding nodes and edges to the graph.
      # @returns target Node
      # @returns edge Edge the edge created connecting source and target.
      def connect_for!(source, edge_args=nil, target=nil, old_edge:nil)
        # raise if find_all( source[:id] ).any?
        self[:graph][source] ||= {}

        return if edge_args.nil?

        self[:graph][source].delete(old_edge)

        edge = Edge(source, edge_args, target)


        self[:graph][target] ||= {} # keep references to all nodes, even when detached.

        self[:graph][source][edge] = target

        return target, edge
      end
      private :connect_for!

      # Builds a node from the provided `:target` argument array.
      def attach!(target:raise, edge:raise, source:self)
        target = target.kind_of?(Node) ? target : Node(*target)

        connect!(target: target, edge: edge, source: source)
      end

      def connect!(target:raise, edge:raise, source:self)
        target = target.kind_of?(Node) ? target : (find_all { |_target| _target[:id] == target }[0] || raise( "#{target} not found"))
        source = source.kind_of?(Node) ? source : (find_all { |_source| _source[:id] == source }[0] || raise( "#{source} not found"))

        connect_for!(source, edge, target)
      end

      def insert_before!(old_node, node:raise, outgoing:nil, incoming:raise)
        old_node = find_all(old_node)[0] || raise( "#{old_node} not found") unless old_node.kind_of?(Node)
        new_node = Node(*node)
        new_incoming_edges = []

        raise IllegalNodeError.new("The ID `#{new_node[:id]}` has been added before.") if find_all( new_node[:id] ).any?

        incoming_tuples     = predecessors(old_node)
        rewired_connections = incoming_tuples.find_all { |(node, edge)| incoming.(edge) }

        # rewire old_task's predecessors to new_task.
        if rewired_connections.size == 0 # this happens when we're inserting "before" an orphaned node.
          connect_for!(new_node)
        else
          rewired_connections.each { |(node, edge)|
            node, edge = connect_for!(node, [edge[:_wrapped], edge.to_h], new_node, old_edge: edge)
            new_incoming_edges << edge
          }
        end

        # connect new_task --> old_task.
        if outgoing
          node, edge = connect_for!(new_node, outgoing, old_node)
          new_incoming_edges << edge
        end

        return new_node, new_incoming_edges
      end

      def find_all(id=nil, &block)
        nodes = self[:graph].keys + self[:graph].values.collect(&:values).flatten
        nodes = nodes.uniq

        block ||= ->(node) { node[:id] == id }

        nodes.find_all(&block)
      end

      def Edge(source, (wrapped, options), target) # FIXME: test required id. test source and target
        id   = "#{source[:id]}-#{wrapped}-#{target[:id]}"
        edge = Edge.new(options.merge( _wrapped: wrapped, id: id, source: source, target: target ))
      end

      # @private
      def Node(wrapped, id:raise("No ID was provided for #{wrapped}"), **options)
        Node.new( options.merge( id: id, _wrapped: wrapped ) )
      end

      # private
      def predecessors(target_node)
        self[:graph].each_with_object([]) do |(node, connections), ary|
          connections.each { |edge, target| target == target_node && ary << [node, edge] }
        end
      end

      def successors(node)
        ( self[:graph][node].invert.to_a || [] ) # FIXME: test we get node and edges
      end

      def to_h(include_leafs:true)
        hash = ::Hash[
          self[:graph].collect do |node, connections|
            connections = connections.collect { |edge, node| [ edge[:_wrapped], node[:_wrapped] ] }

            [ node[:_wrapped], ::Hash[connections] ]
          end
        ]

        if include_leafs == false
          hash = hash.select { |node, connections| connections.any? }
        end

        hash
      end
    end

    def self.Start(wrapped, graph:{}, **data, &block)
      block ||= ->(node, data) { data[:graph][node] = {} }
      Start.new( { _wrapped: wrapped, graph: graph }.merge(data), &block )
    end

    class IllegalNodeError < RuntimeError
    end
  end # Graph
end
