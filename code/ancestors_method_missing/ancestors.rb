module Action

  def eat
    puts 'eat in module Action'
  end

end

module Status

  def sleeping?
    true
  end

end

class Animal; end

class Dog < Animal
  include Action
  include Status

  def eat
    puts 'eat from dog'
  end

  def method_missing(method, *arguments, &block)
    puts "call method: #{method}"
  end

end


def my_ancestors(klass)
  a = []
  a << klass
  sc = klass.superclass
  until sc == nil
    a << sc
    sc = sc.superclass
  end
  a
end

#p my_ancestors Dog
Dog.new.eat
p Dog.ancestors
Dog.new.wang