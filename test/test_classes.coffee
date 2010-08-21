# Test classes with a four-level inheritance chain.
class Base
  func: (string) ->
    "zero/#{string}"

  @static: (string) ->
    "static/#{string}"

class FirstChild extends Base
  func: (string) ->
    super('one/') + string

class SecondChild extends FirstChild
  func: (string) ->
    super('two/') + string

class ThirdChild extends SecondChild
  constructor: ->
    @array = [1, 2, 3]

  # Gratuitous comment for testing.
  func: (string) ->
    super('three/') + string

result = (new ThirdChild).func 'four'

ok result is 'zero/one/two/three/four'
ok Base.static('word') is 'static/word'


class TopClass
  constructor: (arg) ->
    @prop = 'top-' + arg

class SuperClass extends TopClass
  constructor: (arg) ->
    super 'super-' + arg

class SubClass extends SuperClass
  constructor: ->
    super 'sub'

ok (new SubClass).prop is 'top-super-sub'


class OneClass
  constructor: (name) -> @name = name

class TwoClass extends OneClass

ok (new TwoClass('three')).name is 'three'


# And now the same tests, but written in the manual style:
Base = ->
Base::func = (string) ->
  'zero/' + string
Base::['func-func'] = (string) ->
  "dynamic-#{string}"

FirstChild = ->
FirstChild extends Base
FirstChild::func = (string) ->
  super('one/') + string

SecondChild = ->
SecondChild extends FirstChild
SecondChild::func = (string) ->
  super('two/') + string

ThirdChild = ->
  @array = [1, 2, 3]
  this
ThirdChild extends SecondChild
ThirdChild::func = (string) ->
  super('three/') + string

result = (new ThirdChild).func 'four'

ok result is 'zero/one/two/three/four'

ok (new ThirdChild)['func-func']('thing') is 'dynamic-thing'


TopClass = (arg) ->
  @prop = 'top-' + arg
  this

SuperClass = (arg) ->
  super 'super-' + arg
  this

SubClass = ->
  super 'sub'
  this

SuperClass extends TopClass
SubClass extends SuperClass

ok (new SubClass).prop is 'top-super-sub'


# '@' referring to the current instance, and not being coerced into a call.
class ClassName
  amI: ->
    @ instanceof ClassName

obj = new ClassName
ok obj.amI()


# super() calls in constructors of classes that are defined as object properties.
class Hive
  constructor: (name) -> @name = name

class Hive.Bee extends Hive
  constructor: (name) -> super

maya = new Hive.Bee 'Maya'
ok maya.name is 'Maya'


# Class with JS-keyword properties.
class Class
  class: 'class'
  name: -> @class

instance = new Class
ok instance.class is 'class'
ok instance.name() is 'class'


# Classes with methods that are pre-bound to the instance.
# ... or statically, to the class.
class Dog

  constructor: (name) ->
    @name = name

  bark: =>
    "#{@name} woofs!"

  @static: =>
    new this('Dog')

spark = new Dog('Spark')
fido  = new Dog('Fido')
fido.bark = spark.bark

ok fido.bark() is 'Spark woofs!'

obj = func: Dog.static

ok obj.func().name is 'Dog'


# Testing a bound function in a bound function.
class Mini
  num: 10
  generate: =>
    for i in [1..3]
      =>
        @num

m = new Mini
ok (func() for func in m.generate()).join(' ') is '10 10 10'


# Testing a contructor called with varargs.
class Connection
  constructor: (one, two, three) ->
    [@one, @two, @three] = [one, two, three]

  out: ->
    "#{@one}-#{@two}-#{@three}"

list = [3, 2, 1]
conn = new Connection list...
ok conn instanceof Connection
ok conn.out() is '3-2-1'


# Test calling super and passing along all arguments.
class Parent
  method: (args...) -> @args = args

class Child extends Parent
  method: -> super

c = new Child
c.method 1, 2, 3, 4
ok c.args.join(' ') is '1 2 3 4'


# Test `extended` callback.
class Base
  @extended: (subclass) ->
    for key, value of @
      subclass[key] = value

class Element extends Base
  @fromHTML: (html) ->
    node = "..."
    new @(node)

  constructor: (node) ->
    @node = node

ok Element.extended is Base.extended
ok Element.__superClass__ is Base.prototype

class MyElement extends Element

ok MyElement.extended is Base.extended
ok MyElement.fromHTML is Element.fromHTML
ok MyElement.__superClass__ is Element.prototype


# Test classes wrapped in decorators.
func = (klass) ->
  klass::prop = 'value'
  klass

func class Test
  prop2: 'value2'

ok (new Test).prop  is 'value'
ok (new Test).prop2 is 'value2'


# Test anonymous classes.
obj =
  klass: class
    method: -> 'value'

instance = new obj.klass
ok instance.method() is 'value'


# Ensure that nested classes are safely wrapped in parentheses when instantiated
# to avoid JS problems with operator precedence:
class1 = ->
  @name = 'class1'
  this

class1.class2 = ->
  @name = 'class2'
  this

factory = (arg) ->
  return { class2: class1.class2 }

obj1   = new class1
obj2_1 = new class1.class2
obj2_2 = new factory('dummy').class2
obj2_3 = new (factory('dummy')).class2
obj2_4 = new (factory('dummy').class2)

ok obj1.name      is 'class1'
ok obj2_1.name    is 'class2'
ok obj2_2.name    is 'class2'
ok obj2_3.name    is 'class2'
ok obj2_4.name    is 'class2'
ok obj2_2.class2  is undefined
