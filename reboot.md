### reboot
Markup utilities - based on autowrap:pyd and pyd - to expose d functions, structs, etc to python without imposing any structure on the d code

What does this give us?

We like the way autowrap hoovers up all the definitions (functions, classes, structs, members, methods, etc) but sometimes 
we need finer grained control and also don't want to change the api of the d code just to accomodate a python client. By
providing attributes we can mark up methods to give this control, for example:

1) toString is mapped to \_\_repr__ but we might like to add a more specialised \_\_repr__ function for python user. 
    And also provide a \_\_str__.
2) currently a mismatch between the d signature and the calling code causes a D runtime error but we might like to 
   return NotImplemented (in the case of arithmetic operators) or throw a python TypeError which will have more 
   understandable behaviour in the client code
3) we might like python clients to be able to \*args and \*\*kwargs
4) might like to implement <pyobject>**<myDObject>

Current attributes:

@pyargs("<argname>")\
@pykwargs("<argname>")\
@pymagic("<magic method id>")\
@pyignore


We rely on more recent D compilers being able to do the following (thx to Adam Ruppe for the hint):

```
mixin(Replace!(q{
        // DBHERE
        @(__traits(getAttributes, memfn))                 <-- copies the UDAs from memfn to func
        Ret func(T $t, $params) {
            auto dg = dg_wrapper($t, &memfn);
            return dg($ids);
        }
    }, "$params", params, "$fn", __traits(identifier, memfn), "$t",t,
       "$ids",Join!(",",ids)));
```


