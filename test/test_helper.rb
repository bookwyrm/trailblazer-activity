$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "trailblazer-activity"

require "minitest/autorun"

require "trailblazer/circuit/testing"

require "pp"

Inspect = Trailblazer::Activity::Inspect

Minitest::Spec::Circuit  = Trailblazer::Circuit
Minitest::Spec::Activity = Trailblazer::Activity

Minitest::Spec.class_eval do
  def Inspect(*args)
    Trailblazer::Activity::Inspect::Instance(*args)
  end

  def Seq(sequence)
    content =
      sequence.collect do |(magnetic_to, task, plus_poles)|
        pluses = plus_poles.collect { |plus_pole| Seq.PlusPole(plus_pole) }

%{#{magnetic_to.inspect} ==> #{Seq.Task(task)}
 #{pluses.empty? ? "[]" : pluses.join("\n")}}
      end.join("\n")

    "\n#{content}\n"
  end

  module Seq
    def self.PlusPole(plus_pole)
      signal = plus_pole.signal.to_s.sub("Trailblazer::Circuit::", "")
      semantic = plus_pole.send(:output).semantic
      "(#{semantic})/#{signal} ==> #{plus_pole.color.inspect}"
    end

    def self.Task(task)
      return task.inspect unless task.kind_of?(Trailblazer::Circuit::End)

      class_name = strip(task.class)
      name = task.instance_variable_get(:@name)
      "#<#{class_name}:#{name}>"
    end

    def self.strip(string)
      string.to_s.sub("Trailblazer::Circuit::", "")
    end
  end
end
