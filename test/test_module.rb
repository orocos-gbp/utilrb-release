require 'test_config'

require 'flexmock/test_unit'
require 'set'
require 'enumerator'
require 'utilrb/module'

class TC_Module < Test::Unit::TestCase
    def test_include
        class_extension = Module.new do
            def tag; end
        end

        m = Module.new do
            const_set(:ClassExtension, class_extension)
        end
        
        m2 = Module.new { include m }
        assert(m2::ClassExtension.method_defined?(:tag))
        k = Class.new do
            include m2
        end
        assert(k.respond_to?(:tag))
    end

    Foo = 42

    def test_define_or_reuse
	mod = Module.new
        klass = Class.new

	new_mod = mod.define_or_reuse(:Foo) { klass.new }
        assert_kind_of(klass, new_mod)
	assert_equal(new_mod, mod.define_or_reuse(:Foo) { flunk("block called in #define_under") })

        # Now try with a constant that is widely available
	new_mod = mod.define_or_reuse('Signal') { klass.new }
        assert_kind_of(klass, new_mod)
	assert_equal(new_mod, mod.define_or_reuse('Signal') { flunk("block called in #define_under") })
    end

    def test_define_method_with_block
	FlexMock.use do |mock|
	    mock.should_receive(:called).once
	    block_obj = lambda { mock.called }
	    test_obj = self
	    method = lambda do |block, a, b|
		test_obj.assert_equal(a, 1)
		test_obj.assert_equal(b, 2)
		test_obj.assert_equal(block, block_obj)
		block_obj.call
	    end

	    klass = Class.new do
		define_method_with_block(:call, &method)
	    end
	    klass.new.call(1, 2, &block_obj)
	end
    end

    def test_attr_enumerable
        klass = Class.new do
            attr_enumerable(:mapped, :map) { Hash.new }
        end

        obj = klass.new
        obj.map[:a] = [10, 20]
        obj.map[:b] = 10
        assert_equal( [[:a, [10, 20]], [:b, 10]].to_set, obj.enum_for(:each_mapped).to_set )
        assert_equal( [10, 20], obj.enum_for(:each_mapped, :a).to_a )
    end

    def test_inherited_enumerable_module
        m = Module.new do
            inherited_enumerable(:signature, :signatures) { Array.new }
        end
        k = Class.new do
            include m
            inherited_enumerable(:child_attribute) { Array.new }
        end

        # Add another attribute *after* k has been defined
        m.class_eval do
            inherited_enumerable(:mapped, :map, :map => true) { Hash.new }
        end
        check_inherited_enumerable(m, k)
    end

    def test_inherited_enumerable_class
	a = Class.new do
	    inherited_enumerable(:signature, :signatures) { Array.new }
	    inherited_enumerable(:mapped, :map, :map => true) { Hash.new }
	end
	b = Class.new(a) do
	    include Module.new # include an empty module between a and b to check that the module
			       # is skipped transparently
	    inherited_enumerable(:child_attribute) { Array.new }
	end
	check_inherited_enumerable(a, b)
	
	# Test for singleton class support
	object = b.new
	assert(object.singleton_class.respond_to?(:signatures))
	object.singleton_class.signatures << :in_singleton
	assert_equal([:in_singleton], object.singleton_class.signatures)
    end

    def check_inherited_enumerable(base, derived)
	assert(base.respond_to?(:each_signature))
	assert(base.respond_to?(:signatures))
	assert(!base.respond_to?(:has_signature?))
	assert(!base.respond_to?(:find_signatures))

	assert(base.respond_to?(:each_mapped))
	assert(base.respond_to?(:map))
	assert(base.respond_to?(:has_mapped?))

        base.signatures << :in_base
        base.map[:base] = 10
        base.map[:overriden] = 20
        assert_equal([:in_base], base.enum_for(:each_signature).to_a)
        assert_equal([10].to_set, base.enum_for(:each_mapped, :base, false).to_set)

	assert(!base.respond_to?(:child_attribute))
	assert(!base.respond_to?(:each_child_attribute))
	assert(derived.respond_to?(:child_attribute))
	assert(derived.respond_to?(:each_child_attribute))

        derived.signatures << :in_derived

        derived.map[:overriden] = 15
        derived.map[:derived] = 25

        assert_equal([:in_derived, :in_base], derived.enum_for(:each_signature).to_a)
        assert_equal([20, 15].to_set, derived.enum_for(:each_mapped, :overriden, false).to_set)
        assert_equal([15].to_set, derived.enum_for(:each_mapped, :overriden, true).to_set)
        assert_equal([25].to_set, derived.enum_for(:each_mapped, :derived).to_set)
        assert_equal([[:base, 10], [:overriden, 20], [:overriden, 15], [:derived, 25]].to_set, derived.enum_for(:each_mapped, nil, false).to_set)
        assert_equal([[:base, 10], [:overriden, 15], [:derived, 25]].to_set, derived.enum_for(:each_mapped, nil, true).to_set)
    end

    def test_inherited_enumerable_non_mapping_promote
	a = Class.new do
            def self.promote_value(v)
                v
            end
	    inherited_enumerable(:value, :values) { Array.new }
	end
        b = flexmock(Class.new(a), 'b')
        c = flexmock(Class.new(b), 'c')
        d = flexmock(Class.new(c), 'd')

        c.should_receive(:promote_value).with(10).and_return("10_b_c").once.ordered
        d.should_receive(:promote_value).with("10_b_c").and_return(12).once.ordered
        c.should_receive(:promote_value).with(11).and_return("11_b_c").once.ordered
        d.should_receive(:promote_value).with("11_b_c").and_return(13).once.ordered
        b.should_receive(:promote_value).with(0).and_return("0_b_c").once.ordered
        c.should_receive(:promote_value).with("0_b_c").and_return("0_c_d").once.ordered
        d.should_receive(:promote_value).with("0_c_d").and_return(2).once.ordered
        b.should_receive(:promote_value).with(1).and_return("1_b_c").once.ordered
        c.should_receive(:promote_value).with("1_b_c").and_return("1_c_d").once.ordered
        d.should_receive(:promote_value).with("1_c_d").and_return(3).once.ordered

        a.values << 0 << 1
        b.values << 10 << 11
        # Do NOT add anything at the level of C. Its promote_value method should
        # still be called, though
        d.values << 100 << 110
        assert_equal [0, 1], a.each_value.to_a
        assert_equal [100, 110, 12, 13, 2, 3], d.each_value.to_a
    end

    def test_inherited_enumerable_mapping_promote
	a = Class.new do
            def self.promote_value(key, v)
            end
            def self.name; 'A' end
	    inherited_enumerable(:value, :values, :map => true) { Hash.new }
	end
        b = Class.new(a)
        c = Class.new(b)
        d = Class.new(c)

        flexmock(c).should_receive(:promote_value).with('b', 2).and_return("b2_b_c").once.ordered
        flexmock(d).should_receive(:promote_value).with('b', "b2_b_c").and_return(15).once.ordered

        flexmock(c).should_receive(:promote_value).with('c', 3).and_return("c3_b_c").once.ordered
        flexmock(d).should_receive(:promote_value).with('c', "c3_b_c").and_return(16).once.ordered

        flexmock(b).should_receive(:promote_value).with('a', 0).and_return("a0_a_b").once.ordered
        flexmock(c).should_receive(:promote_value).with('a', "a0_a_b").and_return("a0_b_c").once.ordered
        flexmock(d).should_receive(:promote_value).with('a', "a0_b_c").and_return(10).once.ordered

        a.values.merge!('a' => 0, 'b' => 1)
        b.values.merge!('b' => 2, 'c' => 3, 'd' => 4)
        d.values.merge!('d' => 5, 'e' => 6)
        assert_equal [['d', 5], ['e', 6], ['b', 15], ['c', 16], ['a', 10]], d.each_value.to_a
    end

    def test_inherited_enumerable_mapping_promote_non_uniq
	a = Class.new do
            def self.promote_value(key, v)
            end
	    inherited_enumerable(:value, :values, :map => true) { Hash.new }
	end
        b = flexmock(Class.new(a), 'b')
        c = flexmock(Class.new(b), 'c')
        d = flexmock(Class.new(c), 'd')

        c.should_receive(:promote_value).with('b', 2).and_return("b2_b_c").once.ordered
        d.should_receive(:promote_value).with('b', "b2_b_c").and_return(12).once.ordered

        c.should_receive(:promote_value).with('c', 3).and_return("c3_b_c").once.ordered
        d.should_receive(:promote_value).with('c', "c3_b_c").and_return(13).once.ordered

        c.should_receive(:promote_value).with('d', 4).and_return("d4_b_c").once.ordered
        d.should_receive(:promote_value).with('d', "d4_b_c").and_return(14).once.ordered

        b.should_receive(:promote_value).with('a', 0).and_return("a0_a_b").once.ordered
        c.should_receive(:promote_value).with('a', "a0_a_b").and_return("a0_b_c").once.ordered
        d.should_receive(:promote_value).with('a', "a0_b_c").and_return(10).once.ordered

        b.should_receive(:promote_value).with('b', 1).and_return("b1_a_b").once.ordered
        c.should_receive(:promote_value).with('b', "b1_a_b").and_return("b1_b_c").once.ordered
        d.should_receive(:promote_value).with('b', "b1_b_c").and_return(11).once.ordered

        a.values.merge!('a' => 0, 'b' => 1)
        b.values.merge!('b' => 2, 'c' => 3, 'd' => 4)
        d.values.merge!('d' => 5, 'e' => 6)
        assert_equal [['d', 5], ['e', 6], ['b', 12], ['c', 13], ['d', 14], ['a', 10], ['b', 11]], d.each_value(nil, false).to_a
    end

    def test_inherited_enumerable_mapping_promote_with_key_uniq
	a = Class.new do
            def self.promote_value(key, v)
            end
	    inherited_enumerable(:value, :values, :map => true) { Hash.new }
	end
        b = flexmock(Class.new(a), 'b')
        c = flexmock(Class.new(b), 'c')
        d = flexmock(Class.new(c), 'd')

        c.should_receive(:promote_value).with('b', 2).and_return("b2_b_c").once.ordered
        d.should_receive(:promote_value).with('b', "b2_b_c").and_return(12).once.ordered

        a.values.merge!('a' => 0, 'b' => 1)
        b.values.merge!('b' => 2, 'c' => 3, 'd' => 4)
        d.values.merge!('d' => 5, 'e' => 6)
        assert_equal [12], d.each_value('b', true).to_a
    end

    def test_inherited_enumerable_mapping_promote_with_key_non_uniq
	a = Class.new do
            def self.promote_value(key, v)
            end
	    inherited_enumerable(:value, :values, :map => true) { Hash.new }
	end
        b = flexmock(Class.new(a), 'b')
        c = flexmock(Class.new(b), 'c')
        d = flexmock(Class.new(c), 'd')

        c.should_receive(:promote_value).with('b', 2).and_return("b2_b_c").once.ordered
        d.should_receive(:promote_value).with('b', "b2_b_c").and_return(12).once.ordered

        b.should_receive(:promote_value).with('b', 1).and_return("b1_a_b").once.ordered
        c.should_receive(:promote_value).with('b', "b1_a_b").and_return("b1_b_c").once.ordered
        d.should_receive(:promote_value).with('b', "b1_b_c").and_return(11).once.ordered

        a.values.merge!('a' => 0, 'b' => 1)
        b.values.merge!('b' => 2, 'c' => 3, 'd' => 4)
        d.values.merge!('d' => 5, 'e' => 6)
        assert_equal [12, 11], d.each_value('b', false).to_a
    end

    def test_has_ancestor
        mod       = Module.new
        parent    = Class.new do
            include mod
        end
        child     = Class.new(parent)

        assert(child.has_ancestor?(parent))
        assert(child.has_ancestor?(mod))
        assert(parent.has_ancestor?(mod))

        assert(!parent.has_ancestor?(child))
    end

    def test_dsl_attribute_without_filter
        obj = Class.new do
            dsl_attribute :value
        end.new
        assert_same nil, obj.value
        assert_same obj, obj.value(10)
        assert_equal 10, obj.value
    end

    def test_dsl_attribute_with_filter
        obj = Class.new do
            dsl_attribute :value do |v|
                v * 2
            end
        end.new
        assert_same nil, obj.value
        assert_same obj, obj.value(10)
        assert_equal 20, obj.value
    end

end

