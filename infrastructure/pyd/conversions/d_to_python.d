/*
Copyright 2006, 2007 Kirk McDonald

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/


// -------------------------------------------------------------------------------
//
// Utilities for converting D types into python objects
//
// PyObject* d_to_python(T) (T t)
// PydObject d_to_pydobject(T) (T t)
//
// To convert a PydObject to a D type, use PydObject.to_d
//
// -------------------------------------------------------------------------------

module pyd.conversions.d_to_python;

import std.array;
import std.algorithm;
import std.complex;
import std.typetuple;
import std.bigint;
import std.datetime;
import std.traits;
import std.typecons;
import std.conv;
import std.range : ElementType, isInputRange;
import std.stdio;
import std.exception: enforce;
import std.string: format;

import deimos.python.Python;
//import deimos.python.Python : PyObject, PyTypeObject, Py_ssize_t;
//import deimos.python.object : PyObject_VAR_HEAD, PyVarObject, Py_INCREF, Py_DECREF;
//import deimos.python.dictobject : PyDict_New, PyDict_SetItem, PyDict_New;
//import deimos.python.unicodeobject : PyUnicode_DecodeUTF8;

import pyd.references: is_wrapped, PydTypeObject, get_d_reference, wrap_d_object;
import pyd.pydobject : PydObject, PydInputRange;
import pyd.class_wrap : Def, wrapped_classes;
import pyd.func_wrap : PydWrappedFunc_Ready;
import pyd.def : on_py_init, PyName, PyInitOrdering, add_module, ModuleName;
import pyd.exception : handle_exception;
import pyd.util.dg_wrapper : dg_wrapper;
import pyd.conversions.python_to_d : InputRangeWrapper, could_not_convert, python_to_d;


class to_conversion_wrapper(dg_t) {
    alias Parameters!(dg_t)[0] T;
    alias ReturnType!(dg_t) Intermediate;
    dg_t dg;
    this(dg_t fn) { dg = fn; }
    PyObject* opCall(T t) {
        static if (is(Intermediate == PyObject*)) {
            return dg(t);
        } else {
            return d_to_python(dg(t));
        }
    }
}


template to_converter_registry(From) {
    PyObject* delegate(From) dg=null;
}


/**
Extend pyd's conversion mechanism. Will be used by d_to_python only if d_to_python cannot
convert its argument by regular means.

Params:
dg = A callable which takes a D type and returns a PyObject*, or any
type convertible by d_to_python.
*/
void ex_d_to_python(dg_t) (dg_t dg) {
    static if (is(dg_t == delegate) && is(ReturnType!(dg_t) == PyObject*)) {
        to_converter_registry!(Parameters!(dg_t)[0]).dg = dg;
    } else {
        auto o = new to_conversion_wrapper!(dg_t)(dg);
        to_converter_registry!(typeof(o).T).dg = &o.opCall;
    }
}


/**
 * Returns a new (owned) reference to a Python object based on the passed
 * argument. If the passed argument is a PyObject*, this "steals" the
 * reference. (In other words, it returns the PyObject* without changing its
 * reference count.) If the passed argument is a PydObject, this returns a new
 * reference to whatever the PydObject holds a reference to.
 *
 * If the passed argument can't be converted to a PyObject, a Python
 * RuntimeError will be raised and this function will return null.
 */
// ?d_to_python
PyObject* d_to_python(T) (T t) {

    // If T is a U or a U*
    enum isTypeOrPointerTo(U) = is(T == U) || is(T == U*);

    static if(isTypeOrPointerTo!DateTime || isTypeOrPointerTo!Date ||
    isTypeOrPointerTo!SysTime || isTypeOrPointerTo!TimeOfDay)
    {
        if(PyDateTimeAPI is null) {
            PyDateTime_IMPORT();
        }
    }

    static if (!is(T == PyObject*) && is(typeof(t is null)) &&
    !isAssociativeArray!T && !isArray!T) {
        if (t is null) {
            return Py_INCREF(Py_None());
        }
    }
    static if (isBoolean!T) {
        return Py_INCREF(t ? Py_True : Py_False);
    } else static if(isIntegral!T) {
        static if(isUnsigned!T) {
            return PyLong_FromUnsignedLongLong(t);
        }else static if(isSigned!T) {
            return PyLong_FromLongLong(t);
        }
    } else static if (isFloatingPoint!T) {
        return PyFloat_FromDouble(t);
    } else static if( isTuple!T) {
        return d_tuple_to_python!T(t);
    } else static if (isTypeOrPointerTo!DateTime) {
        return PyDateTime_FromDateAndTime(t.year, t.month, t.day, t.hour, t.minute, t.second, 0);
    } else static if (isTypeOrPointerTo!Date) {
        return PyDate_FromDate(t.year, t.month, t.day);
    } else static if (isTypeOrPointerTo!SysTime) {
        return PyDateTime_FromDateAndTime(t.year, t.month, t.day, t.hour, t.minute, t.second, 0);
    } else static if (isTypeOrPointerTo!TimeOfDay) {
        return PyTime_FromTime(t.hour, t.minute, t.second, 0);
    } else static if (is(Unqual!T _unused : Complex!F, F)) {
        return PyComplex_FromDoubles(t.re, t.im);
    } else static if(isTypeOrPointerTo!(std.bigint.BigInt)) {
        return d_bigint_to_python(t);
    } else static if(is(Unqual!T _unused : PydInputRange!E, E)) {
        return Py_INCREF(t.ptr);
    } else static if(isSomeString!T) {
        return d_string_to_python(t);
    } else static if (isArray!(T)) {
        return d_array_to_python(t);
    } else static if (isAssociativeArray!(T)) {
        return d_aarray_to_python(t);
    } else static if (isDelegate!T || isFunctionPointer!T) {
        PydWrappedFunc_Ready!(T)();
        return wrap_d_object(t);
    } else static if (is(T : PydObject)) {
        return Py_INCREF(t.ptr());
    } else static if (is(T : PyObject*)) {
        // The function expects to be passed a borrowed reference and return an
        // owned reference. Thus, if passed a PyObject*, this will increment the
        // reference count.
        Py_XINCREF(t);
        return t;
    } else static if (is(T == class)) {
        // Convert wrapped type to a PyObject*
        alias Unqual!T Tu;
        // But only if it actually is a wrapped type. :-)
        PyTypeObject** type = Tu.classinfo in wrapped_classes;
        if (type) {
            return wrap_d_object(t, *type);
        }
        return d_to_python_try_extends(t);
        // If it's not a wrapped type, fall through to the exception.
        // If converting a struct by value, create a copy and wrap that
    } else static if (is(T == struct) &&
    !is(T == InputRangeWrapper) &&
    isInputRange!T) {
        if (to_converter_registry!(T).dg) {
            return d_to_python_try_extends(t);
        } else static if(__traits(compiles, wrap_range(t))) {
            assert(is_wrapped!(InputRangeWrapper*));
            return d_to_python(wrap_range(t));
        } else {
            pragma(msg, "Didn't compile - pyd.converstions.d_to_python.d_to_python");
            wrap_range(t);
        }
    } else static if (is(T == struct)) {
        alias Unqual!T Tu;
        if (is_wrapped!(Tu*)) {
            Tu* temp = new Tu;
            *temp = cast(Tu) t;
            return wrap_d_object(cast(T*)temp);
        }
        return d_to_python_try_extends(t);
        // If converting a struct by reference, wrap the thing directly
    } else static if (is(typeof(*t) == struct)) {
        alias Unqual!T Tu;
        if (is_wrapped!(Tu)) {
            if (t is null) {
                return Py_INCREF(Py_None());
            }
            return wrap_d_object(t);
        }
        return d_to_python_try_extends(t);
    }

    assert(0);
}


PyObject* d_to_python_try_extends(T) (T t) {
    if (to_converter_registry!(T).dg) {
        return to_converter_registry!(T).dg(t);
    }
    PyErr_SetString(PyExc_RuntimeError, ("D conversion function d_to_python failed with type " ~ typeid(T).toString()).ptr);
    return null;
}


PyObject* d_tuple_to_python(T) (T t) if (isTuple!T) {
    T.Types tuple;
    foreach(i, _t; T.Types) {
        tuple[i] = t[i];
    }
    return items_to_PyTuple(tuple);
}


PyObject* d_bigint_to_python(BigInt t) {
    string num_str = format("%s\0",t);
    return PyLong_FromString(num_str.dup.ptr, null, 10);
}


PyObject* d_string_to_python(T)(T t) if(isSomeString!T) {
    alias Unqual!(typeof(T.init[0])) C;
    static if(is(C == char)) {
        return PyUnicode_DecodeUTF8(t.ptr, cast(Py_ssize_t) t.length, null);
    }else static if(is(C == wchar)) {
        return PyUnicode_DecodeUTF16(cast(char*) t.ptr,
        cast(Py_ssize_t)(2*t.length), null, null);
    }else static if(is(C == dchar)) {
        version(Python_2_6_Or_Later) {
            return PyUnicode_DecodeUTF32(cast(char*) t.ptr,
            cast(Py_ssize_t)(4*t.length), null, null);
        }else{
            return d_to_python(to!string(t));
        }
    }else static assert(false, "waht is this T? " ~ T.stringof);
}


PyObject* d_array_to_python(T)(T t) if(isArray!T) {
    // Converts any array (static or dynamic) to a Python list
    PyObject* lst = PyList_New(cast(Py_ssize_t) t.length);
    PyObject* temp;
    if (lst is null) return null;
    for(int i=0; i<t.length; ++i) {
        temp = d_to_python(t[i]);
        if (temp is null) {
            Py_DECREF(lst);
            return null;
        }
        // Steals the reference to temp
        PyList_SET_ITEM(lst, cast(Py_ssize_t) i, temp);
    }
    return lst;
}


PyObject* d_aarray_to_python(T)(T t) if(isAssociativeArray!T) {
    // Converts any associative array to a Python dict
    PyObject* dict = PyDict_New();
    PyObject* ktemp, vtemp;
    int result;
    if (dict is null) return null;
    foreach(k, v; t) {
        ktemp = d_to_python(k);
        vtemp = d_to_python(v);
        if (ktemp is null || vtemp is null) {
            if (ktemp !is null) Py_DECREF(ktemp);
            if (vtemp !is null) Py_DECREF(vtemp);
            Py_DECREF(dict);
            return null;
        }
        result = PyDict_SetItem(dict, ktemp, vtemp);
        Py_DECREF(ktemp);
        Py_DECREF(vtemp);
        if (result == -1) {
            Py_DECREF(dict);
            return null;
        }
    }
    return dict;
}


T python_to_aarray(T)(PyObject* o) if(isAssociativeArray!T) {
    PyObject* keys = null;
    if(PyDict_Check(o)) {
        keys = PyDict_Keys(o);
    }else if(PyMapping_Keys(o)) {
        keys = PyMapping_Keys(o);
    }else{
        could_not_convert!(T)(o);
        assert(0);
    }
    PyObject* iterator = PyObject_GetIter(keys);
    T result;
    PyObject* key;
    while ((key=PyIter_Next(iterator)) !is null) {
        PyObject* value = PyObject_GetItem(o, key);
        auto d_key = python_to_d!(KeyType!T)(key);
        auto d_value = python_to_d!(ValueType!T)(value);
        result[d_key] = d_value;
        Py_DECREF(key);
        Py_DECREF(value);
    }
    Py_DECREF(iterator);
    return result;
}


/**
 * Helper function for creating a PyTuple from a series of D items.
 */
PyObject* items_to_PyTuple(T ...)(T t) {
    PyObject* tuple = PyTuple_New(t.length);
    PyObject* temp;
    if (tuple is null) return null;
    foreach(i, arg; t) {
        temp = d_to_python(arg);
        if (temp is null) {
            Py_DECREF(tuple);
            return null;
        }
        PyTuple_SetItem(tuple, i, temp);
    }
    return tuple;
}


/**
 * Constructs an object based on the type of the argument passed in.
 *
 * For example, calling d_to_pydobject(10) would return a PydObject holding the value 10.
 *
 * Calling this with a PydObject will return back a reference to the very same
 * PydObject.
 */
PydObject d_to_pydobject(T) (T t) {
    static if(is(T : PydObject)) {
        return t;
    } else {
        return new PydObject(d_to_python(t));
    }
}



