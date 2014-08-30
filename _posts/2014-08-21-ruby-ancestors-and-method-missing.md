---
layout: post
title:  "Ruby的方法查找与method_missing"
date:   2014-08-21 09:31:01
categories: ruby
excerpt: 对Ruby祖先链和“method_missing”方法进行一次较为深入的探索。
---

在Ruby的世界里，一切都是对象。她的继承体系不像C++那么复杂，但是也有自己的特色。她不支持多重继承，但是支持模块的混入。她虽然没有接口，但是有“鸭子类型”(duck type)。

```
如果对象能够象鸭子那样行走，象鸭子那样呱呱叫，那么解释器会很高兴的把它当做鸭子来对待的。（Programming Ruby 中文版 P367）
```

在Ruby中方法调用都是通过**“对象.方法”**的形式。当调用一个方法时，Ruby会在对象的类中查找那个方法，如果当前类中没有这个方法的定义，Ruby会搜索祖先链，看看其中是否存在这个方法。再更进一步前，我们得先来了解下什么是“祖先链”。

在Ruby的世界里，“祖先链”是一个很重要的概念。祖先链为我们展示了一个完整的类继承路径，同时它也是Ruby中方法查找的路径。
先来看一个简单的情况：

``` ruby
class Animal; end

class Dog < Animal

end

def my_ancestors(klass)
  a = []
  a << klass
  sc = klass.superclass
  until sc==nil
    a << sc
    sc = sc.superclass
  end
  a
end

p my_ancestors Dog
```

首先，我们定义两个类`Animal`、`Dog`。其中`Dog`继承`Animal`类。`superclass()`方法可以访问到某个类的父类。`my_ancestors()`方法，会帮助我们输出一个类的所有父类。我们想象中`Dog`的祖先链应该是这样：

![想象的图](/images/2014-08/ruby_superclass.png)

但是执行这段代码会输出如下的内容：

```
[Dog, Animal, Object, BasicObject]
```

其中多了 `Object`,`BasicObject`两个类。可见一个Ruby类如果不声明父类，默认继承于`Object`类。而`Object`又继承于`BasicObject`类（Ruby 1.9 版本引入了BasicObject）。`BasicObject`是这条继承链的顶端。于是现在的继承链应该是：

![实际的图](/images/2014-08/ruby_superclass_object.png)

这就是一个类的祖先链了吗？别忘了还有模块没有试验。下面我们来添加一个`Action`模块，这个模块可以为类添加一些方法：

``` ruby
module Action

  def eat
    puts 'eat'
  end

end

class Animal; end

class Dog < Animal
  include Action
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

p my_ancestors Dog
```

再运行这个脚本，发现输出跟刚才没有什么区别:

```
[Dog, Animal, Object, BasicObject]
```

在这个输出中，我们并没有发现添加进来的模块。看来使用`superclass()`方法并不能访问到添加到类中模块。那么模块被添加到哪里了呢？还好，Ruby提供了一个更强力的方法`ancestors()`，可以打印一个类所有的祖先。在脚本文件中加上一行

``` ruby
p Dog.ancestors
```

然后执行脚本：


```
[Dog, Animal, Object, BasicObject]
[Dog, Action, Animal, Object, Kernel, BasicObject]
```
在新的输出中，我们找到了`Action`模块，它位于`Dog`类的上方。同时我们还发现了另一个东西 -- `kernel`，它是Ruby在`Object`类中引入的一个模块。这使得我们可以在任何对象上调用 `kernel` 中定义的方法。

如果一个类中添加了多个模块呢？再添加一个模块，看看输出：

``` ruby
module Action

  def eat
    puts 'eat'
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

p my_ancestors Dog
p Dog.ancestors
```

```
[Dog, Animal, Object, BasicObject]
[Dog, Status, Action, Animal, Object, Kernel, BasicObject]
```

可见新的模块被添加到`Dog`上方，最接近`Dog`的地方。现在祖先链完整了。它包括了从当前类到`BasicObject`类的完整路径。

![祖先链](/images/2014-08/ruby_ancestors.png)

好了，明白了什么是祖先链，现在让我们回到主题，看看当在一个对象上调用方法时，Ruby如何查找这个方法。

**1. 先看一个简单的情况，在一个包含模块且有继承关系的类如何查找方法。**

``` ruby
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
```

`Dog`类本身没有`eat()`方法，我们在`Dog`的对象上调用`eat()`方法后，Ruby会先查找`Dog`类中的实例方法，然后沿着原型链一直向上找，直到找到`Action`模块中的方法后进行了调用。

![find eat](/images/2014-08/ruby_method_eat.png)

这种查找能到什么程度呢?如祖先链表示的，接下来就是Object类，这是Ruby中一切对象的开始。其中有一个模块`Kernel`。也就是说，如果你在Kernel中定义了一个方法，那么Ruby中的所有对象都可以用这个方法。


**2. 如果类和混入的模块中有相同的方法，会发生什么呢？**

``` ruby

class Dog < Animal
  include Action
  include Status

  def eat
    puts 'eat from dog'
  end

end

```

我们在`Dog`类中添加了新的`eat()`方法。运行后输出:

```
eat from dog
[Dog, Status, Action, Animal, Object, Kernel, BasicObject]
```

可以看出来，Ruby调用了`Dog`类中的`eat()`方法。也就是说，如果存在同名方法，在祖先链中靠前的方法会覆盖靠后的方法。这个规则同样适用于混入的多个模块中存在同名方法的情况。

这是不是Ruby方法查找路径的全部呢？我们来看个简单的例子：

``` ruby
class Foo; end

a = Foo.new
b = Foo.new

class << b
  def bar
    puts 'bar'
  end
end

b.bar
a.bar

```
在irb里运行：

```
2.1.2 :001 > class Foo;end
 => nil
2.1.2 :002 > a = Foo.new
 => #<Foo:0x007fc019952e38>
2.1.2 :003 > b = Foo.new
 => #<Foo:0x007fc01994ae90>
2.1.2 :004 > class << b
2.1.2 :005?>   def bar; puts 'bar'; end
2.1.2 :006?>   end
 => :bar
2.1.2 :007 > b.bar
bar
 => nil
2.1.2 :008 > a.bar
NoMethodError: undefined method `bar' for #<Foo:0x007fc019952e38>
  from (irb):8
  from /Users/molezz/.rvm/rubies/ruby-2.1.2/bin/irb:11:in `<main>'
```

很奇怪，`a`和`b`都是`Foo`类的对象，为什么`bar()`方法在`b`对象中存在，而`a`中却没有呢？看来Ruby还有隐藏关卡。


``` ruby
class << b
  def bar
    puts 'bar'
  end
end
```

这个写法，打开了`b`对象的单件类。单件类（singleton class/eigenclass）又称，元类(meta class)，影子类...。在Ruby 2.0之前，官方一直没有一个明确的名字，2.0以后官方称之为“Singleton class”。在单件类中定义的方法只在当前对象中存在。这就是为什么`a`对象没有响应`bar()`方法的原因。Ruby在进行方法查找的时候会优先查找对象单件类中定义的方法。所以，现在的方法查找路径变成了：


![find singleton eat](/images/2014-08/ruby_method_singleton_eat.png)


有一点很有意思:在Ruby的世界里，一切皆是对象。我们定义的类也是对象（它们是`Class`类的对象）。所以每个类也有自己的单件类。我们常见的类方法实际上就定义在这个类的单件类中。模块也有自己的单件类，但模块的单件类并不在祖先链中。单件类不能被继承，它只属于当前的对象。但是单件类可以有父类或子类。**一个类的单件类的父类或子类是这个类的父类或子类的单件类**。这读起来有点绕口，画个图就明白了：

![find singleton class](/images/2014-08/ruby_method_singleton_class.png)

图中虚线框的类是单件类。虚线箭头是实例方法的查找路径。实线箭头是类方法的查找路径。这就是较为完整的Ruby方法查找路径了。

当方法被调用时，Ruby会沿着这样的路径去查找，一直到顶部。如果方法没有找到，Ruby会调用一个叫做`method_missing()`的方法。默认情况下，这个方法会抛出一个`NoMethodError`的异常。我们可以在自己的类中覆盖这个方法，从而实现各种惊奇的功能。Rails中使用`method_missing()`的代码随处可见:

``` ruby
#rails / activesupport / lib / active_support / option_merger.rb

def method_missing(method, *arguments, &block)
  if arguments.first.is_a?(Proc)
    proc = arguments.pop
    arguments << lambda { |*args| @options.deep_merge(proc.call(*args)) }
  else
    arguments << (arguments.last.respond_to?(:to_hash) ? @options.deep_merge(arguments.pop) : @options.dup)
  end

  @context.__send__(method, *arguments, &block)
end

```

我们在`Dog`类中也添加一个自己的方法：

``` ruby
class Dog < Animal
  include Action
  include Status

  def eat
    puts 'eat from dog'
  end

  private

  def method_missing(method, *arguments, &block)
    puts "call method: #{method}"
  end

end
```

然后调用下不存在的`wang()`方法

``` ruby
Dog.new.wang
```

```
eat from dog
[Dog, Status, Action, Animal, Object, Kernel, BasicObject]
call method: wang
```
奇迹出现了！Ruby没有报`NoMethodError`而是打印出了我们调用的方法名字。当你沉浸在`method_missing()`带来的喜悦中的时候，你可能已经掉进了一个坑中。来看下面一段测试：

``` ruby
require 'benchmark'
require 'rubygems'
require 'sqlite3'
require 'active_record'


ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => ':memory:'
)

ActiveRecord::Migration.class_eval do
  create_table :as do |table|

    table.column :title, :string
    table.column :performer, :string

  end

  create_table :bs do |table|

    table.column :title, :string
    table.column :performer, :string

  end
end


class A < ActiveRecord::Base

  def test
    true
  end

end

class B < ActiveRecord::Base

  def method_missing(method)
    true
  end

end

a = A.new
b = B.new


Benchmark.bmbm do |x|
  x.report('call method:') { 10000000.times { a.test } }
  x.report('call method_missing:'){ 10000000.times { b.test }  }
end

```

我们使用Ruby提供的`Benchmark`进行基准测试。为了尽可能减小误差，代码中使用了`bmbm()`方法，给要测试的代码进行“预热”。输出的结果如下：



```
# Ruby 2.1 / Activerecord 3.2.16

Rehearsal --------------------------------------------------------
call method:           1.040000   0.000000   1.040000 (  1.047809)
call method_missing:   1.300000   0.010000   1.310000 (  1.295754)
----------------------------------------------- total: 2.350000sec

                           user     system      total        real
call method:           1.050000   0.000000   1.050000 (  1.047334)
call method_missing:   1.280000   0.000000   1.280000 (  1.286637)

```


`method_missing()`固然很强大，但是它是有一定性能损失的(从测试上看，大概20%左右)。这个性能损失一部分就是来自于祖先链的查找。祖先链越长，性能损失越大。虽然相比性能损失，`method_missing()`带来的便捷性和灵活性是我们更看重的，但是在一些高负载的环节，性能问题还是不得不留意。

##讨论

我们在Rails的源代码里经常见到这样的写法：

``` ruby
#rails / actionpack / lib / action_dispatch / routing / routes_proxy.rb line 25
def method_missing(method, *args)
  if routes.url_helpers.respond_to?(method)
    self.class.class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def #{method}(*args)
        options = args.extract_options!
        args << url_options.merge((options || {}).symbolize_keys)
        routes.url_helpers.#{method}(*args)
      end
    RUBY
    send(method, *args)
  else
    super
  end
end

```

在一些文章里也有很多人讨论使用类似的方法提高`method_missing()`的性能。即在`method_missing()`中动态创建方法，这样可以省掉后面调用时对祖先链进行查找消耗的时间。我们也把试验代码改动下：

``` ruby
require 'benchmark'
require 'rubygems'
require 'sqlite3'
require 'active_record'


ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => ':memory:'
)


ActiveRecord::Migration.class_eval do
  create_table :as do |table|

    table.column :title, :string
    table.column :performer, :string

  end

  create_table :bs do |table|

    table.column :title, :string
    table.column :performer, :string

  end

  create_table :cs do |table|

    table.column :title, :string
    table.column :performer, :string

  end
end


class A < ActiveRecord::Base

  def test
    true
  end

end

class B < ActiveRecord::Base

  def method_missing(method)
    true
  end

end

class C < ActiveRecord::Base

  def method_missing(method, *args)

    self.class.send(:define_method, method) do
      true
    end

    # self.class.class_eval <<-RUBY
    #   def #{method}(*args)
    #     true
    #   end
    # RUBY

    send(method, *args)

  end

end

a = A.new
b = B.new
c = C.new



Benchmark.bmbm do |x|
  x.report('call method:') { 1000000.times { a.test } }
  x.report('call method_missing:'){ 1000000.times { b.test }  }
  x.report('call dynamic method:'){ 1000000.times { c.test }  }
end
```

这次加入`C`类，并且在`method_missing()`中动态定义了方法，然后执行测试:


```
# Ruby 2.1 / Activerecord 3.2.16

Rehearsal --------------------------------------------------------
call method:           0.110000   0.000000   0.110000 (  0.110478)
call method_missing:   0.140000   0.000000   0.140000 (  0.137801)
call dynamic method:   0.160000   0.000000   0.160000 (  0.158153)
----------------------------------------------- total: 0.410000sec

                           user     system      total        real
call method:           0.110000   0.000000   0.110000 (  0.105553)
call method_missing:   0.130000   0.000000   0.130000 (  0.134528)
call dynamic method:   0.150000   0.000000   0.150000 (  0.155159)
```

很奇怪动态创建方法不仅没有提升性能，反而略有降低。我们把同样的代码在 Ruby 1.9.3环境下测试一遍：

```
#Ruby 1.9.3 p547 / Activerecord 3.2.16

Rehearsal --------------------------------------------------------
call method:           0.290000   0.000000   0.290000 (  0.294679)
call method_missing:   0.450000   0.000000   0.450000 (  0.449482)
call dynamic method:   0.410000   0.000000   0.410000 (  0.410275)
----------------------------------------------- total: 1.150000sec

                           user     system      total        real
call method:           0.300000   0.000000   0.300000 (  0.297368)
call method_missing:   0.460000   0.000000   0.460000 (  0.454473)
call dynamic method:   0.410000   0.000000   0.410000 (  0.409693)

```

这次跟我们的猜测一致了。在`method_missing()`中动态定义方法确实能提高一些性能。看来Ruby 2.1版对`method_missing()`进行了优化。“今后是否还要在`method_missing()`中使用动态方法定义来提高性能？”成为一个值得考虑的问题。






