module Trailblazer
  module Activity::Magnetic
    module DSL
      # each "line" in the DSL adds an element, the entire line is processed here.
      module ProcessElement
        module_function
        # add new task with Polarizations
        # add new connections
        # add new ends
        def call(sequence, task, options={}, id:raise, strategy:raise, &block)
          # 2. compute default Polarizations by running the strategy
          strategy, args = strategy
          magnetic_to, plus_poles = strategy.(task, args )

          # 3. process user options
          arr = ProcessOptions.(id, options, args[:plus_poles])

          _plus_poles = arr.collect { |cfg| cfg[0] }.compact
          adds       = arr.collect { |cfg| cfg[1] }.compact.flatten(1)
          proc, _    = arr.collect { |cfg| cfg[2] }.compact

          # 4. merge them with the default Polarizations
          plus_poles = plus_poles.merge( Hash[_plus_poles] )

          # 5. seq.add step, polarizations
          sequence.add( id, [ magnetic_to, task, plus_poles.to_a ],  )

          # 6. add additional steps
          adds.each do |method, cfg| sequence.send( method, *cfg ) end

          sequence
        end
      end

      # Generate PlusPoles and additional sequence alterations from the DSL options such as
      #   Output(:success) => End("my.new")
      module ProcessOptions
        module_function

        # Output => target (End/"id"/:color)
        # @return [PlusPole]
        # @return additional alterations
        #
        # options:
        #   { DSL::Output[::Semantic] => target }
        #
        def call(id, options, outputs)
          options.collect { |key, task| process_tuple(id, key, task, outputs) }
        end

        def process_tuple(id, output, task, outputs)
          output = output_for(output, outputs) if output.kind_of?(DSL::Output::Semantic)

          if task.kind_of?(Circuit::End)
            new_edge = "#{id}-#{output.signal}"

            [
              [ output, new_edge ],

              [[ :add, [task.instance_variable_get(:@name), [ [new_edge], task, [] ], group: :end] ]]
            ]
          elsif task.is_a?(String) # let's say this means an existing step
            new_edge = "#{output.signal}-#{task}"
            [
              [ output, new_edge ],

              [[ :magnetic_to, [ task, [new_edge] ] ]],
            ]
          elsif task.is_a?(Proc)
            seq = Activity.plan(track_color: color="track_#{rand}", &task)

            # TODO: this is a pseudo-"merge" and should be public API at some point.
            adds = seq[1..-1].collect do |arr|
              [ :add, [ "options[:id]#{rand}_fixme", arr ] ]
            end

            [
              [ output, color ],
              adds
            ]
          else # An additional plus polarization. Example: Output => :success
            [
              [ output, task ]
            ]
          end
        end

        # @param semantic DSL::Output::Semantic
        def output_for(semantic, outputs)
          # DISCUSS: review PlusPoles#[]
          output, _ = outputs.instance_variable_get(:@plus_poles)[semantic.value]
          output or raise("Couldn't find existing output for `#{semantic.value.inspect}`.")
        end
      end # OptionsProcessing

      # DSL datastructures
      module Output
        Semantic = Struct.new(:value)
      end

      # helpers used in the DSL

      #   Output( Left, :failure )
      #   Output( :failure ) #=> Output::Semantic
      def self.Output(signal, semantic=nil)
        return Output::Semantic.new(signal) if semantic.nil?

        Activity::Magnetic.Output(signal, semantic)
      end

      def self.End(name, semantic)
         evt = Circuit::End.new(name)
        evt
      end
    end # DSL
  end
end
