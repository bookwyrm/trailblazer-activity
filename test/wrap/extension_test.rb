require "test_helper"

class TaskWrapMacroTest < Minitest::Spec
  TaskWrap = Trailblazer::Activity::TaskWrap
  Builder  = Trailblazer::Activity::Magnetic::Builder

  # Sample {Extension}
  # We test if we can change `activity` here.
  SampleExtension = ->(activity, task, local_options, *returned_options) do
    activity.task activity.method(:b), id: "add_another_1", before: local_options[:id]
  end

  #
  # Actual {Activity} using :extension
  module Create
    extend Trailblazer::Activity[]

    def self.a( (ctx, flow_options), **)
      ctx[:seq] << :a

      return Right, [ ctx, flow_options ]
    end

    def self.b( (ctx, flow_options), **)
      ctx[:seq] << :b

      return Right, [ ctx, flow_options ]
    end

    task method(:a), extension: [ SampleExtension ], id: "a"
  end

  it "runs two tasks" do
    event, (options, flow_options) = Create.( [{ seq: [] }, {}], {} )

    options.must_equal( {:seq=>[:b, :a]} )
  end

  describe "add_introspection" do
    it { Create.debug.inspect.must_equal %{{#<Method: TaskWrapMacroTest::Create.a>=>{:id=>"a"}, #<Method: TaskWrapMacroTest::Create.b>=>{:id=>"add_another_1"}}} }
  end
end