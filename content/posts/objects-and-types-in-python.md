---
title: "Objects and Types in Python"
date: 2023-01-17T17:27:12+05:30
draft: false
---

Python's type system is fascinating. Everything in Python (anything that can be given a name or passed as an argument) is an object. This includes primitives (such as `int`, `str`, `bool` objects), compound objects (made from handwritten classes), and very interestingly the classes or types themselves. This fact that everything in Python is derived from a common base makes it very powerful because any two of these objects can be combined or extended in similar ways. However, the implementation of this idea has consequences. It sometimes gives rise to confusing behaviours that can be hard to reason about if you only understand the behaviour intuitively. 

In this post, we will go over what this implies, understand the type-system bottom-up, and then use that understanding to reason about some confusing behaviours. By the end of this post, you will have a clear picture of what classes and objects really are and what lies behind this abstraction.

Table of contents
-----------------

1.  [The Chicken-Egg problem](#the-chicken-egg-problem)
    *   [`object` and `type`](#object-and-type)
    *   [relationship between `object` and `type`](#relationship-between-object-and-type)
    *   [`PyObject` and `PyTypeObject`](#pyobject-and-pytypeobject)
2.  [Method lookup](#method-lookup)
    *   [Lookup order, and setting and deleting attributes](#lookup-order-and-setting-and-deleting-attributes)
    *   [`self` injection](#self-injection)
    *   [Descriptors](#descriptors)
    *   [Crafting methods by hand](#crafting-methods-by-hand)
3.  [Classes as objects](#classes-as-objects)
    *   [Creating classes with `type`](#creating-classes-with-type)
    *   [`class` keyword as syntactic sugar](#class-keyword-as-syntactic-sugar)
*   [Conclusion](#conclusion)
*   [Footnotes](#footnotes)

The Chicken-Egg Problem
-----------------------

### `object` and `type`

When people say that everything is an object in Python, they mean that very literally. There is an `object` class that all Python objects are instances of. This is also the implicit base class when you create a new class.

```python
>>> isinstance(5, object)
True
>>> isinstance(int, object)
True
>>> isinstance("abcdef", object)
True
```

Classes themselves are objects too. This is slightly counter-intuitive when you think of an object
as an instance of some class. But it is very much an object in that you can pass it around
as a function argument, name it differently, set attributes and call methods on it.

All classes are instances of the `type` class. In that sense, `type` is a metaclass and other
metaclasses need to inherit from `type`. [<sup>1</sup>](#footnotes)

### Relationship between `object` and `type`

There are at least 3 things about this that are confusing:

1.  `object` is a `class`
2.  All `class`es are objects of the type `type`.
3.  `type` itself is a class

We can verify this in the Python interpreter.

If an `object` is a `class`, it should be an instance of the `type` class.

```python
>>> isinstance(object, type)
True
```

_The interpreter agrees._

To verify #2, we will create a custom class and check whether it's an instance of `object`. Then we'll also verify whether it is an instance of `type`.

```python
>>> class A:
...   pass
...
>>> isinstance(A, object)
True
>>> isinstance(A, type)
True
```

_Checks out._

Now let's see if `type` is a `class`. For this, we will check whether `type` is an instance of `type` and whether `type` is an `object`.

```python
>>> isinstance(type, type)
True
>>> isinstance(type, object)
True
```

_See, I wasn't lying._

What's happening here? type is a type, type is also an object, and object is itself a type.

This relationship is confusing because it is modelled only in the underlying implementation and not in pure Python. 

### `PyObject` and `PyTypeObject`

In the CPython implementation, there are two basic structs for `PyObject` and `PyTypeObject` that look kind of like this:

```c
// a simplified struct definition for PyObject and PyTypeObject

typedef struct PyObject {
    PyTypeObject_HEAD
    // and other metadata
} PyObject;

typedef struct Tuple {
    PyTypeObject_HEAD
    int length;
    PyObject** elements;
} Tuple;

typedef struct PyTypeObject {
    PyObject_HEAD  // macro to "inherit" from PyObject
    char name[50];
    Tuple* bases;
    // and other things
} PyTypeObject;
```

Here, we can see that `type`'s inheritance of `object` isn't like a usual parent-child class relationship, but one that happens because `PyTypeObject` is a struct that inherits from `PyObject`. 

To make it clear, let's try to write the C code that will represent such a relationship:

```c
PyTypeObject type_ = { .name = "type" };
type_.ob_type = &type_;

PyObject object_ = { .name = "object" };
object_.ob_type = &type_;

PyObject* type_elements[] = { &object_, };
Tuple type_bases = {
	.elements = (PyObject**) type_elements,
	.length = sizeof(type_elements)/sizeof(PyObject*),
};
type_.bases = &type_bases;
```

wtfpython has a good explanation on this [here](https://github.com/satwikkansal/wtfpython#-the-chicken-egg-problem-) and CPython has comments explaining this too: [https://github.com/python/cpython/blob/a286caa937405f7415dcc095a7ad5097c4433246/Include/object.h#L24-L29](https://github.com/python/cpython/blob/a286caa937405f7415dcc095a7ad5097c4433246/Include/object.h#L24-L29)

Method Lookup
-------------

### Lookup order, and setting and deleting attributes

This section sets up the context for the next one about method lookup.

The lookup order in Python goes like Object → Class → Base classes. However, the setting and deleting of attributes only happens directly on the object itself.

Take this example where we initialise an object whose class has an attribute `x`, and then
try to delete it:

```python
>>> class A:
...   x = 10
...
>>> a = A()
>>> print(a.x)
10
>>> del a.x
AttributeError: x
```

The attributes of a class can be looked up by its objects, but cannot be deleted from there.

However, deleting directly from the class will work fine:
```
>>> del A.x  # is fine
>>> print(a.x)
AttributeError: 'A' object has no attribute 'x'
```

The same happens when setting attributes too. We can see it in this example where we set `x`
on both the object and the class, and then delete the `x` on the object:

```python
>>> class A:
...   x = 10  # set on class
...
>>> a = A()
>>> a.x = 20  # set on object
>>> print(a.x)
20
>>> del a.x  # delete from object
>>> print(a.x)  # doesn't raise attribute error because A.x is still there
10
```

Even though we deleted `a.x`, `A.x` was still there and that's the value we got when we printed `a.x` the second time.

We can observe that the lookup is dynamic and any modifications to the attributes on the class
should reflect when we perform lookup from the object.

### `self` injection

When we define methods inside a class body, we take the bound object as the first argument `self`.
This is strange because `self` is defined when the method is called from an initialised object,
but not when the method is called from the class itself.

```python
>>> class A:
...   def hello(self):
...     print("Hello, world!")
...
>>> A.hello()
TypeError: A.hello() missing 1 required positional argument: 'self'
>>> a = A()
>>> a.hello()
Hello, world!
```

Additionally, this `self` injection does not happen at the time that the function is called, because
Python also allows you to assign a different variable to this method and it still works:

```python
>>> a = A()
>>> f = a.hello
>>> f()
Hello, world! 
```

So what's the magic here?

If we inspect the types of `A.hello` and `a.hello`, we'll see the difference.

```
>>> type(A.hello)
<class 'function'>
>>> type(a.hello)
<class 'method'>
```

They're not the same, and `a.hello` is a `method` and not a `function`.

The `hello` attribute returns different values depending on if it is called from the class or an initialised object. Python allows such behaviour with descriptors.

### Descriptors

Python descriptors are classes that have `__get__`, `__set__`, or `__del__` methods. So instead
of the actual value, these methods are called when a descriptor is accessed as an attribute. A
popular example of descriptors in use is the `property` decorator that can be used for dynamic
attributes.

Python functions are actually descriptors with a `__get__` method that returns a
`method` with the object and function bound to it. I'll take a couple of examples to
explain descriptors.

A simple Descriptor that always returns 10 would look like this [<sup>2</sup>](#footnotes):

```python
>>> class Ten:
...   def __get__(self, obj, objtype=None):
...     return 10
...
>>> class A:
...   x = 5
...   y = Ten()
...
>>> a = A()
>>> a.x
5
>>> a.y
10
```

A descriptor has access to the object it is called with from the `obj` argument. We could write
this descriptor to return the square of `obj.x`:

```python
>>> class SquareX:
...   def __get__(self, obj, objtype=None):
...     return obj.x * obj.x
...
>>> class A:
...   y = SquareX()
...
...   def __init__(self, x):
...     self.x = x
...
>>> a = A(5)
>>> a.y
25
```

You can also directly try using the `__get__` method on a function. Calling it with the object
as its argument will return a method that binds this function and the object.

### Crafting methods by hand

This is a side section, but rather interesting because we can directly observe how methods are
actually represented differently from functions.

The `method` class isn't available as a builtin, but you can get it by calling `type()` on a method. This class takes a function and an object during initialisation, in that order. We can use that to create methods by hand that were never bound to the class or the object.

```python
>>> class A:
...   greeting = "Hello, I am Foo Bar."
...   def hello(self):
...     pass
...
>>> a = A()
>>> method_class = type(a.hello)
>>> def greet(self):
...   print(self.greeting)
...
>>> greet_with_a = method_class(greet, a)
>>> greet_with_a()
Hello, I am Foo Bar.
```

We just crafted a method that was never an attribute.

Classes as Objects
------------------

### Creating classes with `type` 

Everything is an object, and classes are not exempt from it. We saw earlier that classes are instances of the `type` class.

We can also create classes with the `type` class initialiser, similar to other objects. For example:

```python
>>> def foo(self):
...   return "bar"
...
>>> A = type("A", tuple(), {"foo": foo, "x": 10})
>>> a = A()
>>> a.foo()
'bar'
>>> a.x
10
```

The type signature of the 3-argument `type` initialisation is `type(name, bases, dict) → type`.

The `name` argument will be the value taken by `cls.__name__`, `bases` can be used to achieve
inheritance by providing a tuple of classes, and `dict` is a dict of key-value pairs that
are the attributes on this class.

When a metaclass needs to be used, that class can be used instead of `type`.

### `class` keyword as syntactic sugar

A syntactic sugar is a some additional syntax that makes it easier to express something but doesn't add a new feature to the language.

The `class` keyword can be seen as calling `type` with the variables defined in its scope as
value of the `dict` argument. In that sense, `class` is a a syntactic sugar for creating
instances of `type`. We'll write a [decorator](https://realpython.com/primer-on-python-decorators/)
to show this that will mimick the behaviour of the `class` keyword as closely as possible. 

At the end, we should be able to define classes with something like this:

```python
@create_class
def A():
	x = 10	
	def __init__(self, y, z):
	    self.y = y
	    self.z = z
	return locals()

a = A(5, 10)
```

We should also be able to perform inheritance.

```python
@create_class
def B(A):
	x = 20
	return locals()

b = B(5, 10)  # y and z, as in A.__init__
```

And use metaclasses:

```python
@create_class
def Meta(type):
    def __repr__(self):
        return f"Meta {self.__name__}"
	return locals()

@create_class
def C(metaclass=Meta):
    pass
```

This syntax is very similar to the one used to declare classes with the `class` keyword, except that it is a `def`, has a `create_class` decorator, and returns [`locals()`]().

The decorator gets the function object, and can access the parameters and default arguments. From there, we can resolve the variables from `globals()` and initialise the `class`.

Feel free to give it a try now before reading on with the solution.

Our decorator gets access to the function and we can inspect it to find out its parameters
(base classes) and other keyword arguments (metaclass). We will only get these parameters
as strings, and we need to resolve it using `globals()`. Then we can use the metaclass (by
default, `type`) to initialise this with the three arguments. We can assume that the function
will return the `locals()` dict from inside and use that for building the third argument
in initialisation.

```python
def create_class(func):
    bases = get_params(func)
    kwds = get_defaults(func)

    resolved_bases = tuple(resolve(base, env=globals()) for base in bases)
    func_locals = func(*resolved_bases)

    meta = kwds.get("metaclass", type)
    klass = meta(
        func.__name__, resolved_bases, func_locals
    )
    return klass

# get_params, get_defaults, and resolve

def get_params(func):
    code = func.__code__
    defaults = func.__defaults__ or []
    arg_names = code.co_varnames[:code.co_argcount]
    return arg_names if not defaults else arg_names[:-len(defaults)]

def get_defaults(func):
    code = func.__code__
    defaults = func.__defaults__ or []
    arg_names = code.co_varnames[:code.co_argcount][-len(defaults):]
    return dict(zip(arg_names, defaults))

def resolve(var, env):
    return env.get(varname, getattr(__builtins__, "type"))
```

Now, the examples above will work and we can recreate the `class` keyword without using it.

We can even get rid of the need to return `locals()` from the definitions if we use something like [`inspect.getsource`](https://docs.python.org/3/library/inspect.html#inspect.getsource) and then performing an [`exec`](https://realpython.com/python-exec/) on the function body and supplying a local env, but `inspect.getsource` will actually read the literal text from the Python file to produce the output. I didn't want to get that hacky and stick to what is always available at runtime.

Conclusion
----------

*   Because everything in Python is an object and all objects have a type, there exists a strange relationship between `object` and `type`
*   We looked at how `type` is itself a `type` and how that relationship is defined in the interpreter
*   We saw how Python uses descriptors to implement methods and how we can craft our own
*   We blurred the line between classes and objects by eliminating the need for a special keyword for classes, and instead working with `type`.

The _objects all the way down_ philosophy has its quirks, but it also makes Python very expressive. We can combine classes and functions in a similar manner as other primitive types. Lists and tuples need not be restricted to a single type and we can even have custom meta types. All of this is possible because there is some shared structure to all the objects that the interpreter can exploit. With the knowledge of a few rules, we can extend and combine anything in Python.

Footnotes
---------

_\[1\] In fact, Python allows you to define your own metaclasses. Then the class will be an instance of a different type other than the default that is_ `type`. _Note that metaclasses also need to subclass from_ `type`, _so the stated relationship between_ `type` _and_ `classes` _still holds._

_\[2\] Example borrowed from_ [_Descriptor HowTo Guide_](https://docs.python.org/3/howto/descriptor.html)_, Python documentation._
