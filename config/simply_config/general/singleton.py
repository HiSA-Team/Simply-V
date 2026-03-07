# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: Singleton and SingletonABCMeta are used througout
# the rest of the project to define singleton and abstract singleton classes
# the "Singleton" class is used as a "metaclass" for the specific classes
# that we want to make singletons.
# (https://docs.python.org/3/reference/datamodel.html#metaclasses)
# When defyning a class in Python with the syntax "class Class_Name:"
# the Python interpreter is effectively creating an object in memory representing
# the class we defined using a "Metaclass" (the default one is "type").
# Basically a metaclass creates classes like a class creates objects.
# This mechanism enable us to effectively "redefine" what a class can do.

from abc import ABCMeta

# Singleton Metaclass deriving from "type"
# that redefines the "__call__" function (the function automatically called when doing "obj = Class_Name()"
# to create an object)
class Singleton(type):
	_instances = {}

	#should be used instead of the class constructor to make the "Singleton"
	#semantics clearer
	def get_instance(cls, *args, **kwargs):
		return cls(*args, **kwargs)

	#since isn't possible to define the constructor as private in Python
	#we also redefine the normal constructor in order to avoid problems.
	#the __call__ function is used by the metaclass "type"
	#when creating an object of a Class with the syntax obj = MyClass()
	#we wrap it in a check for already allocated istances, in order to return always the same
	#instance
	def __call__(cls, *args, **kwargs):
		if cls not in cls._instances:
			cls._instances[cls] = super(Singleton, cls).__call__(*args, **kwargs)
		return cls._instances[cls]


# Combine both metaclasses so that it's possible to define a class as abstract
# but still enforcing "Singleton" semantics
class SingletonABCMeta(Singleton, ABCMeta):
    pass
