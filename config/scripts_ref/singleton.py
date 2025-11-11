from abc import ABCMeta


class Singleton(type):
	_instances = {}

	#since isn't possible to define the constructor as private in Python
	#we also redefine the normal constructor in order to avoid problems of replication
	#the __call__ function is used by the metaclass "type"
	#when creating an object of a Class with the syntax obj = MyClass()
	#in order to wrap it in a check for already allocated istances to return
	def __call__(cls, *args, **kwargs):
		if cls not in cls._instances:
			cls._instances[cls] = super(Singleton, cls).__call__(*args, **kwargs)
		return cls._instances[cls]

	#should be used instead of the class constructor to make the "Singleton"
	#semantics clearer
	def get_instance(cls, *args, **kwargs):
		return cls(*args, **kwargs)


# Combine both metaclasses
class SingletonABCMeta(Singleton, ABCMeta):
    pass
