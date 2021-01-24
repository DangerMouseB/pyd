module py.magic;

import std.stdio;

import deimos.python.object : PyObject, Py_INCREF, Py_None;
import pyd.make_object : python_to_d, d_to_python;
import deimos.python.Python: Py_ssize_t, Py_Initialize;
import pyd.reboot.attributes : pyargs, pykwargs, pymagic;

import d.types : fred;

struct joe {};

//export class Urm {
//    PyObject* opBinary(string op)(PyObject* rhs) if (op == "^^") {
//        return null;
//    }
//    PyObject* opBinaryRight(string op)(PyObject* lhs, PyObject* mod = null) if (op == "^^") {
//        return null;
//    }
//}


export class Magic {
    // "in"

    private string _name;

    @property string name() { return _name; }
    @property void name(string n) { _name = n; }


    // __add__  => "+"
    PyObject* opBinary(string op)(PyObject* rhs) if (op == "+") {
        return __add__(this, rhs);
    }

    // __radd__
    PyObject* opBinaryRight(string op)(PyObject* lhs) if (op == "+") {
        return __radd__(lhs, this);
    }


    //// __sub__  => "-"
    //PyObject* opBinary(string op)(PyObject* rhs) if (op == "-") {
    //    return __sub__(this, rhs);
    //}
    //
    //// __rsub__
    //PyObject* opBinaryRight(string op)(PyObject* lhs) if (op == "-") {
    //    return __rsub__(lhs, this);
    //}


    // __mul__  => "*"
    // __div__  => "/"

    // __floordiv__(self, other)
    // Implements integer division using the // operator.

    // __div__(self, other)
    // Implements division using the / operator.

    // __truediv__(self, other)
    // Implements true division. Note that this only works when from __future__ import division is in effect.


    // __mod__(self, other)
    // Implements modulo using the % operator
    PyObject* opBinary(string op)(PyObject* rhs) if (op == "%") {
        return __mod__(this, rhs);
    }

    // __rmod__
    PyObject* opBinaryRight(string op)(PyObject* lhs) if (op == "%") {
        return __rmod__(lhs, this);
    }


    // __divmod__(self, other)
    // Implements behavior for long division using the divmod() built in function.

    // __pow__
    // Implements behavior for exponents using the ** operator.
    PyObject* opBinary(string op)(PyObject* rhs) if (op == "^^") {
        return __pow__(this, rhs);
    }

    //// __rmod__
    //PyObject* opBinaryRight(string op)(PyObject* lhs) if (op == "^^") {
    //    return __rpow__(lhs, this);
    //}


    // __lshift__(self, other)
    // Implements left bitwise shift using the << operator.
    PyObject* opBinary(string op)(PyObject* rhs) if (op == "<<") {
        return __lshift__(this, rhs);
    }

    // __rlshift__
    PyObject* opBinaryRight(string op)(PyObject* lhs) if (op == "<<") {
        return __rlshift__(lhs, this);
    }



    // __rshift__(self, other)
    // Implements right bitwise shift using the >> operator.
    PyObject* opBinary(string op)(PyObject* rhs) if (op == ">>") {
        return __rshift__(this, rhs);
    }

    // __rrshift__
    PyObject* opBinaryRight(string op)(PyObject* lhs) if (op == ">>") {
        return __rrshift__(lhs, this);
    }



    // __and__(self, other)
    // Implements bitwise and using the & operator.
    PyObject* opBinary(string op)(PyObject* rhs) if (op == "&") {
        return __and__(this, rhs);
    }

    // __rand__
    PyObject* opBinaryRight(string op)(PyObject* lhs) if (op == "&") {
        return __rand__(lhs, this);
    }


    // __or__(self, other)
    // Implements bitwise or using the | operator.
    PyObject* opBinary(string op)(PyObject* rhs) if (op == "|") {
        return __or__(this, rhs);
    }

    // __ror__
    PyObject* opBinaryRight(string op)(PyObject* lhs) if (op == "|") {
        return __ror__(lhs, this);
    }


    // __xor__(self, other)
    // Implements bitwise xor using the ^ operator.
    PyObject* opBinary(string op)(PyObject* rhs) if (op == "^") {
        return __xor__(this, rhs);
    }

    // __rrshift__
    PyObject* opBinaryRight(string op)(PyObject* lhs) if (op == "^") {
        return __rxor__(lhs, this);
    }


    //__pos__(self)	To get called for unary positive e.g. +someobject.
    PyObject* opUnary(string op)() if (op == "+") {
        return __pos__(this, rhs);
    }

    //__neg__(self)	To get called for unary negative e.g. -someobject.
    PyObject* opUnary(string op)() if (op == "-") {
        return __neg__(this, rhs);
    }

    //__invert__(self)
    PyObject* opUnary(string op)() if (op == "~") {
        return __invert__(this);
    }

    //__abs__(self)	To get called by built-in abs() function.
    PyObject* __abs__() {return Magic__abs__(this);}


    // __cmp__


    // __eq__


    // __index__(self)
    // Implements type conversion to an int when the object is used in a slice expression. If you define a custom
    // numeric type that might be used in slicing, you should define __index__.
    PyObject* opIndex(PyObject* arg) {
        writeln("opIndex");
        return __getitem__(this, arg);
    }

    PyObject* opSlice(PyObject* a, PyObject* b) {
        writeln("opSlice");
        return __getitem__(this, a);
    }

    // __trunc__(self)
    // Called when math.trunc(self) is called. __trunc__ should return the value of `self truncated to an
    // integral type (usually a long).

    //__coerce__(self, other)
    // for mixed mode arithmetic, return None if type conversion is impossible, else , a pair (2-tuple) of self and
    // other, manipulated to have the same type.




    // __repr__
    //@pymagic("__repr__")
    string __repr__() { return Magic__repr__(this);}


    // __str__
    //@pymagic("__str__")
    string __str__() { return Magic__str__(this);}


    // __hash__


    // __bool__ was __nonzero__


    // __getattr__


    // __setattr__


    // __delattr__


    // __getattribute__


    // __len__
    @property Py_ssize_t length() { return __len__(this); }
    //@property PyObject* length() { return __len__(this); }

    // __getitem__(self, key)
    // self[key] answer TypeError if key is wrong type, and KeyError if no key

    // __setitem__(self, key, value)
    // self[nkey] = value, raise KeyError and TypeError appropriately

    // __delitem__(self, key)
    // del self[key]), raise KeyError and TypeError appropriately

    // __iter__(self)
    // for x in container: answer an iterator for the container, iIterators are their own objects must define an __iter__ method that returns self

    // __reversed__(self)
    // implement behavior for reversed() built in

    // __contains__(self, item)
    // in and not in

    // __missing__(self, key)
    // used in subclasses of dict, called whenever a key is accessed that does not exist in a dict

    // __instancecheck__(self, instance)
    // isinstance(instance, class) is instance is an instance of the class you defined

    //__subclasscheck__(self, subclass)
    // issubclass(subclass, class) is subclass a class subclasses the class you defined

     //__call__(self, [args...])
    //@pykwargs("kwargs")
    //@pymagic("__call__")
    //@pyargs("args")
    PyObject* opCall(PyObject* args) {
        //return __call__(this, args, kwargs);
        return d_to_python("__call__");
    }

    //@pykwargs("kwargs")
    //@pyargs("args")
    //@pymagic("__call__")
    PyObject* joe(PyObject* args, PyObject* kwargs) {
        return d_to_python("fred");
    }

    // __enter__(self)

    // __exit__(self, exception_type, exception_value, traceback)

    // __copy__(self)
    // shallow copy of your object

    //__deepcopy__(self, memodict={})

}


PyObject* __add__(Magic lhs, PyObject* rhs) {
    //return Py_INCREF(Py_None);
    return d_to_python("__add__");
}

PyObject* __radd__(PyObject* lhs, Magic rhs) {
    //return Py_INCREF(Py_None);
    return d_to_python("__radd__");
}


PyObject* __mod__(Magic lhs, PyObject* rhs) {
    return d_to_python("__mod__");
}

PyObject* __rmod__(PyObject* lhs, Magic rhs) {
    return d_to_python("__rmod__");
}

PyObject* __pow__(Magic lhs, PyObject* rhs) {
    return d_to_python("__pow__");
}

PyObject* __rpow__(PyObject* lhs, Magic rhs) {
    return d_to_python("__rpow__");
}




PyObject* __lshift__(Magic lhs, PyObject* rhs) {
    return d_to_python("__lshift__");
}

PyObject* __rlshift__(PyObject* lhs, Magic rhs) {
    return d_to_python("__rlshift__");
}


PyObject* __rshift__(Magic lhs, PyObject* rhs) {
    return d_to_python("__rshift__");
}

PyObject* __rrshift__(PyObject* lhs, Magic rhs) {
    return d_to_python("__rrshift__");
}


PyObject* __and__(Magic lhs, PyObject* rhs) {
    return d_to_python("__and__");
}

PyObject* __rand__(PyObject* lhs, Magic rhs) {
    return d_to_python("__rand__");
}


PyObject* __or__(Magic lhs, PyObject* rhs) {
    return d_to_python("__or__");
}

PyObject* __ror__(PyObject* lhs, Magic rhs) {
    return d_to_python("__ror__");
}


PyObject* __xor__(Magic lhs, PyObject* rhs) {
    return d_to_python("__xor__");
}

PyObject* __rxor__(PyObject* lhs, Magic rhs) {
    return d_to_python("__rxor__");
}


PyObject* __pos__(Magic self) {
    return d_to_python(1);
}

PyObject* __neg__(Magic self) {
    return d_to_python(-1);
}

PyObject* __invert__(Magic self) {
    return d_to_python(0);
}

PyObject* Magic__abs__(Magic self) {
    return d_to_python( "__abs__");
}


string Magic__repr__(Magic self) {
    return "__repr__";
}

string Magic__str__(Magic self) {
    return "__str__";
}

Py_ssize_t __len__(Magic self) {
    return 0;
}

PyObject* __call__(Magic self, PyObject* args, PyObject* kwargs) {
    return d_to_python("__call__");
}

PyObject* __getitem__(Magic self, PyObject* args) {
    return d_to_python("__getitem__");
}

