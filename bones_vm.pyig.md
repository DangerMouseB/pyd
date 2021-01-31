### bones_vm.pyig
Derivative work of autowrap:pyd and pyd. Provides markup (via User Defined Attributes - UDAs) to expose d 
functions, structs, etc to python without requiring redesign of d code, just markup and clarification code.

<br> 

What does this give us?

We like the way autowrap hoovers up all the definitions (functions, classes, structs, members, methods, etc) but sometimes 
we need finer grained control and also don't want to change the api of the d code just to accommodate a python client. By
providing attributes we can mark up methods to give this control, for example:

1) toString is mapped to \_\_repr__ but we might like to add a more specialised \_\_repr__ function for python user. 
    And also provide a \_\_str__.
2) currently a mismatch between the d signature and the calling code causes a D runtime error but we might like to 
   return NotImplemented (in the case of arithmetic operators) or throw a python TypeError which will have more 
   understandable behaviour in the client code
3) we might like python clients to be able to \*args and \*\*kwargs
4) might like to implement <pyobject>**<myDObject>



We rely on more recent D compilers which are able to do the following (thx to Adam Ruppe for the hint):

```
mixin(Replace!(q{
        @(__traits(getAttributes, memfn))                 <-- copies the UDAs from memfn to func
        Ret func(T $t, $params) {
            auto dg = dg_wrapper($t, &memfn);
            return dg($ids);
        }
    }, "$params", params, "$fn", __traits(identifier, memfn), "$t",t,
       "$ids",Join!(",",ids)));
```



#### Thus far

* structs are now working
* @__richcmpfunc__ instead of opCmp (so can return Py_RETURN_NOTIMPLEMENTED), also don't need opEquals
* @args, @kwargs  - not yet mixing with other variables
* refactoring and tidyup - naming to reflect cpython api where possible
* keep old d api used in the pyd examples - needs testing
* gives a detailed log as compiling to make it easier to debug


#### WISHLIST

1. any vulnerabilities get discovered by PyCharm in the variable inspector in debug mode - make it easy to prevent this
2. have a clear public api
3. be deployable on pypi



```
struct Vector {
    private ubyte nDims;
    private ubyte dimension;
    private ubyte units;
    private ubyte other;
    double x;
    double y;
    double z;

    @property
    double norm() {...}

    Vector opBinary(string op)(Vector rhs) if op == "+" {}
    Vector opBinary(string op)(Vector rhs) if op == "*" {return crossProduct(that)}
    Vector opBinary(string op)(double rhs) if op == "*" {return scalarMul(that)}
    Vector opBinaryRight(string op)(Vector lhs) if op == "*" {return crossProduct(lhs)}
    Vector opBinaryRight(string op)(double lhs) if op == "*" {return scalarMul(lhs)}


    string toString() {"<"~x.to!string~", "~y.to!string~", "~z.to!string~">"}

    bool opEquals(Vector that) {}

    fromDouble(double[] v, dimensions=null, units=null) {...}

    @__matmul__
    Vector crossProduct(Vector

    @__mul__
    Vector scalarMul(double rhs) {...}

    @__rmul__
    Vector scalarMul(double rhs) {...}

    @__eq__
    PyObject* pyEquals(PyObject* rhs) {...}

    @__add__
    PyObject* pyAdd(PyObject* rhs) {...}

    @__radd__
    PyObject* pyAdd(PyObject* lhs) {...}

    @__init__
    void init1(double x) {...}
    
    @__init__
    void init2(double x, double y) {...}
    
    @__init__
    void init3(double x, double y, double z) {
        answer.x = x ;
        answer.y = y;
        answer.z = z;
        if (x is null) {answer.nDims = 0;}
        else if (y is null) {answer.nDims = 1;}
        else if (z is null) {answer.nDims = 2;}
        else if (y is null) {answer.nDims = 3;}
        if (x is null) {answer.nDims = 0;}
    }
    
    @__init__
    void fromInts(@args *PyObject v) {this.fromInts(ints.checkTo!([]int]());}
    
    @__repr__
    string pyRepr() {return "vector("~x.to!string~", "~y.to!string~", "~z.to!string~")";}

    @__str__
    string pyStr() {return "["~x.to!string~", "~y.to!string~", "~z.to!string~"]";}
    
}


@__new__("metersPerSecond")
Vector newPartialSum(Vector cls, @args PyObject* args, @kwargs PyObject* kwargs)) {
    Vector answer;
    answer.dimension = "[L T−1]".to!dimension;
    answer.unit = "meters".to!unit;
    return answer
}

@def
string displayInInches(Vector x): {}
```

Python should just see `metersPerSecond` as a new type and a new function 
`displayInInches`.



