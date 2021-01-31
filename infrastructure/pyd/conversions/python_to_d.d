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
// Utilities for converting python objects into D types
//
// T python_to_d(T) (PyObject* o)
//
// To convert a PydObject to a D type, use PydObject.to_d
//
// -------------------------------------------------------------------------------

module pyd.conversions.python_to_d;


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
import pyd.class_wrap : wrapped_classes;
import pyd.func_wrap : PydWrappedFunc_Ready;
import pyd.def : on_py_init, PyName, PyInitOrdering, add_module, ModuleName;
import pyd.exception : handle_exception;
import pyd.util.dg_wrapper : dg_wrapper;
import pyd.conversions.d_to_python : d_to_python, python_to_aarray;

import bones_vm.pyig.traits : _isConstCharStar, _isCharStar;
import bones_vm.pyig.wrappers : wrap_class, Def;



shared static this() {
    init_rangewrapper();
}


void init_rangewrapper() {
    version(PydPythonExtension) {
        on_py_init({
            wrap_class!(InputRangeWrapper,
            Def!(InputRangeWrapper.iter, PyName!"__iter__"),
            Def!(InputRangeWrapper.next))();
            rangeWrapperInited = true;
        }, PyInitOrdering.After);
    }else{
        on_py_init( {
            add_module!(ModuleName!"pyd")();
        });
        on_py_init( {
            wrap_class!(InputRangeWrapper,
            ModuleName!"pyd",
            Def!(InputRangeWrapper.iter, PyName!"__iter__"),
            Def!(InputRangeWrapper.next))();
            rangeWrapperInited = true;
        }, PyInitOrdering.After);
    }
}


bool rangeWrapperInited = false;


class from_conversion_wrapper(dg_t) {
    alias Intermediate = Parameters!(dg_t)[0];
    alias T = ReturnType!(dg_t);
    dg_t dg;
    this(dg_t fn) { dg = fn; }
    T opCall(PyObject* o) {
        static if (is(Intermediate == PyObject*)) {
            return dg(o);
        } else {
            return dg(python_to_d!(Intermediate)(o));
        }
    }
}


template from_converter_registry(To) {
    To delegate(PyObject*) dg=null;
}


class PyToDConversionException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}


/**
Extend pyd's conversion mechanims. Will be used by python_to_d only if python_to_d
cannot convert its argument by regular means.

Params:
dg = A callable which takes a PyObject*, or any type convertible by python_to_d,
    and returns a D type.
*/
void ex_python_to_d(dg_t) (dg_t dg) {
    static if (is(dg_t == delegate) && is(Parameters!(dg_t)[0] == PyObject*)) {
        from_converter_registry!(ReturnType!(dg_t)).dg = dg;
    } else {
        auto o = new from_conversion_wrapper!(dg_t)(dg);
        from_converter_registry!(typeof(o).T).dg = &o.opCall;
    }
}


/**
 * This converts a PyObject* to a D type. The template argument is the type to
 * convert to. The function argument is the PyObject* to convert. For instance:
 *
 *$(D_CODE PyObject* i = PyInt_FromLong(20);
 *int n = _python_to_d!(int)(i);
 *assert(n == 20);)
 *
 * This throws a PyToDConversionException if the PyObject can't be converted to
 * the given D type.
 */
T python_to_d(T) (PyObject* o) {

    // This ordering is somewhat important. The checks for Tuple and Complex
    // must be before the check for general structs.
    version(PydPythonExtension) {
        // druntime doesn't run module ctors :(
        if(!rangeWrapperInited) {
            init_rangewrapper();
        }
    }

    static if (is(PyObject* : T)) {
        return o;
    } else static if (is(PydObject : T)) {
        return new PydObject(borrowed(o));
    } else static if (is(T == void)) {
        if (o != cast(PyObject*) Py_None()) could_not_convert!(T)(o);
        return;
    } else static if (isTuple!T) {
        if(PyTuple_Check(o)) {
            return python_to_d_tuple!T(o);
        }
        return python_to_d_try_extends!T(o);
    } else static if (is(Unqual!T _unused : Complex!F, F)) {
        if (PyComplex_Check(o) || isNumpyComplexNumber(o)) {
            return python_to_d_complex!T(o);
        }
        return python_to_d_try_extends!T(o);
    } else static if(is(Unqual!T == std.bigint.BigInt)) {
        if (isPyNumber(o)) {
            return python_to_d_bigint!T(o);
        }
        if (isNumpyNumber(o)) {
            auto i = to_python_int(o);
            return python_to_d_bigint!T(i);
        }
        return python_to_d_try_extends!T(o);
    } else static if(is(T == DateTime)) {
        if(PyDateTimeAPI is null) {
            PyDateTime_IMPORT();
        }
        if(PyDateTime_Check(o)) {
            int year = PyDateTime_GET_YEAR(o);
            int month = PyDateTime_GET_MONTH(o);
            int day = PyDateTime_GET_DAY(o);
            int hour = PyDateTime_DATE_GET_HOUR(o);
            int minute = PyDateTime_DATE_GET_MINUTE(o);
            int second = PyDateTime_DATE_GET_SECOND(o);
            return DateTime(year, month, day, hour, minute, second);
        }
        if(PyDate_Check(o)) {
            int year = PyDateTime_GET_YEAR(o);
            int month = PyDateTime_GET_MONTH(o);
            int day = PyDateTime_GET_DAY(o);
            return DateTime(year, month, day, 0, 0, 0);
        }
        if(is_numpy_datetime64(o)) {
            return python_to_d_numpy_datetime64!T(o);
        }

    } else static if(is(T == Date)) {
        if(PyDateTimeAPI is null) {
            PyDateTime_IMPORT();
        }
        if(PyDateTime_Check(o) || PyDate_Check(o)) {
            int year = PyDateTime_GET_YEAR(o);
            int month = PyDateTime_GET_MONTH(o);
            int day = PyDateTime_GET_DAY(o);
            return Date(year, month, day);
        }
        if(is_numpy_datetime64(o)) {
            return python_to_d_numpy_datetime64!T(o);
        }
    } else static if(is(T == SysTime)) {
        if(PyDateTimeAPI is null) {
            PyDateTime_IMPORT();
        }
        if(PyDateTime_Check(o)) {
            int year = PyDateTime_GET_YEAR(o);
            int month = PyDateTime_GET_MONTH(o);
            int day = PyDateTime_GET_DAY(o);
            int hour = PyDateTime_DATE_GET_HOUR(o);
            int minute = PyDateTime_DATE_GET_MINUTE(o);
            int second = PyDateTime_DATE_GET_SECOND(o);
            auto dt = DateTime(year, month, day, hour, minute, second);
            return SysTime(dt);
        }
        if(PyDate_Check(o)) {
            int year = PyDateTime_GET_YEAR(o);
            int month = PyDateTime_GET_MONTH(o);
            int day = PyDateTime_GET_DAY(o);
            auto dt = DateTime(year, month, day, 0, 0, 0);
            return SysTime(dt);
        }
        if(is_numpy_datetime64(o)) {
            return python_to_d_numpy_datetime64!T(o);
        }
    } else static if(is(T == TimeOfDay)) {
        if(PyDateTimeAPI is null) {
            PyDateTime_IMPORT();
        }
        if(PyTime_Check(o)) {
            int hour = PyDateTime_TIME_GET_HOUR(o);
            int minute = PyDateTime_TIME_GET_MINUTE(o);
            int second = PyDateTime_TIME_GET_SECOND(o);
            return TimeOfDay(hour, minute, second);
        }
        if(PyDateTime_Check(o)) {
            int hour = PyDateTime_DATE_GET_HOUR(o);
            int minute = PyDateTime_DATE_GET_MINUTE(o);
            int second = PyDateTime_DATE_GET_SECOND(o);
            return TimeOfDay(hour, minute, second);
        }
        if(is_numpy_datetime64(o)) {
            return python_to_d_numpy_datetime64!T(o);
        }
    } else static if(is(Unqual!T _unused : PydInputRange!E, E)) {
        return cast(T) PydInputRange!E(borrowed(o));
    } else static if (is(T == class)) {
        // We can only convert to a class if it has been wrapped, and of course
        // we can only convert the object if it is the wrapped type.
        if (
        is_wrapped!(T) &&
        PyObject_IsInstance(o, cast(PyObject*)&PydTypeObject!(T)) )
        {
            if ( get_d_reference!T(o) !is null) {
                return get_d_reference!(T)(o);
            }
        }
        return python_to_d_try_extends!T(o);
    } else static if (is(T == struct)) { // struct by value
        // struct is wrapped
        if (is_wrapped!(T*) && PyObject_TypeCheck(o, &PydTypeObject!(T*))) {
            return *get_d_reference!(T*)(o);
        }
        // or struct is wrapped range
        if(PyObject_IsInstance(o,
        cast(PyObject*)&PydTypeObject!(InputRangeWrapper*))) {
            InputRangeWrapper* wrapper = get_d_reference!(InputRangeWrapper*)(o);
            if(typeid(T) != wrapper.tid) {
                could_not_convert!T(o, format("typeid mismatch: %s vs %s",
                wrapper.tid, typeid(T)));
            }
            T t = *cast(T*) wrapper.range;
            return t;
        }
        return python_to_d_try_extends!T(o);
    } else static if (isPointer!T && is(PointerTarget!T == struct)) {
        // pointer to struct
        if (is_wrapped!(T) && PyObject_TypeCheck(o, &PydTypeObject!(T))) {
            return get_d_reference!(T)(o);
        }
        return python_to_d_try_extends!T(o);
    } else static if (is(T == delegate)) {
        // Get the original wrapped delegate out if this is a wrapped delegate
        if (is_wrapped!(T) && PyObject_TypeCheck(o, &PydTypeObject!(T))) {
            return get_d_reference!(T)(o);
            // Otherwise, wrap the PyCallable with a delegate
        } else if (PyCallable_Check(o)) {
            return PydCallable_AsDelegate!(T)(o);
        }
        return python_to_d_try_extends!T(o);
    } else static if (isDelegate!T || isFunctionPointer!T) {
        // We can only make it a function pointer if we originally wrapped a
        // function pointer.
        if (is_wrapped!(T) && PyObject_TypeCheck(o, &PydTypeObject!(T))) {
            return get_d_reference!(T)(o);
        }
        return python_to_d_try_extends!T(o);
    } else static if (isSomeString!T) {
        return python_to_d_string!T(o);
    } else static if (_isConstCharStar!T) {
        return cast(const(char*)) o;                        // DBHERE at the mo structs expose tp_name in __init__
        // needs some more thinking though - why are we pythoning to d in the first place?
    } else static if (_isCharStar!T) {
        return cast(char*) o;                        // DBHERE at the mo structs expose tp_name in __init__
        // needs some more thinking though - why are we pythoning to d in the first place?
    } else static if (isArray!T || IsStaticArrayPointer!T) {
        static if(isPointer!T) {
            alias E = Unqual!(ElementType!(PointerTarget!T));
        }else {
            alias E = Unqual!(ElementType!T);
        }
        version(Python_2_6_Or_Later) {
            if(PyObject_CheckBuffer(o)) {
                return python_buffer_to_d!(T)(o);
            }
        }
        if(o.ob_type is array_array_Type) {
            return python_array_array_to_d!T(o);
        }else {
            return python_iter_to_d!T(o);
        }
    } else static if (isAssociativeArray!T) {
        return python_to_aarray!T(o);
    } else static if (isFloatingPoint!T) {
        if (isPyNumber(o) || isNumpyNumber(o)) {
            double res = PyFloat_AsDouble(o);
            return cast(T) res;
        }
        return python_to_d_try_extends!T(o);
    } else static if(isIntegral!T) {
        if (isNumpyNumber(o)) {
            o = to_python_int(o);
        }

        version(Python_3_0_Or_Later) {
        }else{
            if(PyInt_Check(o)) {
                C_long res = PyInt_AsLong(o);
                handle_exception();
                static if(isUnsigned!T) {
                    if(res < 0) could_not_convert!T(o, format("%s out of bounds [%s, %s]", res, 0, T.max));
                    if(T.max < res) could_not_convert!T(o,format("%s out of bounds [%s, %s]", res, 0, T.max));
                    return cast(T) res;
                }else static if(isSigned!T) {
                    if(T.min > res) could_not_convert!T(o, format("%s out of bounds [%s, %s]", res, T.min, T.max));
                    if(T.max < res) could_not_convert!T(o, format("%s out of bounds [%s, %s]", res, T.min, T.max));
                    return cast(T) res;
                }
            }
        }
        if(PyLong_Check(o)) {
            static if(isUnsigned!T) {
                static assert(T.sizeof <= C_ulonglong.sizeof);
                C_ulonglong res = PyLong_AsUnsignedLongLong(o);
                handle_exception();
                // no overflow from python to C_ulonglong,
                // overflow from C_ulonglong to T?
                if(T.max < res) could_not_convert!T(o);
                return cast(T) res;
            }else static if(isSigned!T) {
                static assert(T.sizeof <= C_longlong.sizeof);
                C_longlong res = PyLong_AsLongLong(o);
                handle_exception();
                // no overflow from python to C_longlong,
                // overflow from C_longlong to T?
                if(T.min > res) could_not_convert!T(o);
                if(T.max < res) could_not_convert!T(o);
                return cast(T) res;
            }
        }

        return python_to_d_try_extends!T(o);
    } else static if (isBoolean!T) {
        if (isPyNumber(o) || isNumpyNumber(o)) {
            int res = PyObject_IsTrue(o);
            return res == 1;
        }
        return python_to_d_try_extends!T(o);
    }

    assert(0);
}


PyObject* to_python_int(PyObject* o) {
    auto builtins = new PydObject(PyEval_GetBuiltins());
    auto int_ = builtins["int"];
    return int_(o).to_d!(PyObject*)();
}


T python_to_d_try_extends(T) (PyObject* o) {
    if (from_converter_registry!(T).dg) {
        return from_converter_registry!(T).dg(o);
    }
    could_not_convert!(T)(o);
    assert(0);
}


T python_to_d_tuple(T) (PyObject* o) {
    T.Types tuple;
    auto len = PyTuple_Size(o);
    if(len != T.Types.length) could_not_convert!T(o);
    foreach(i,_t; T.Types) {
        auto obj =  Py_XINCREF(PyTuple_GetItem(o, i));
        tuple[i] = python_to_d!_t(obj);
        Py_DECREF(obj);
    }
    return T(tuple);
}


T python_to_d_complex(T) (PyObject* o) {
    import pyd.util.conv;
    static if (is(Unqual!T _unused : Complex!F, F)) {
        double real_ = python_to_d!double(PyObject_GetAttrString(o, "real"));
        handle_exception();
        double imag = python_to_d!double(PyObject_GetAttrString(o, "imag"));
        handle_exception();
        return complex!(F,F)(real_, imag);
    }else static assert(false);
}


T python_to_d_bigint(T) (PyObject* o) {
    string num_str = python_to_d!string(o);
    if(num_str.endsWith("L")) num_str = num_str[0..$-1];
    return BigInt(num_str);
}


T python_to_d_string(T) (PyObject* o) {
    alias C = Unqual!(typeof(T.init[0]));
    PyObject* str;
    if(PyBytes_Check(o)) {
        static if(is(C == char)) {
            str = o;
        }else{
            version(Python_3_0_Or_Later) {
                str = PyObject_Str(o);
                if(!str) handle_exception();
            }else{
                str = PyObject_Unicode(o);
                if(!str) handle_exception();
            }
        }
    }else if(PyUnicode_Check(o)) {
        str = o;
    }else {
        str = PyObject_Repr(o);
        if(!str) handle_exception();
        version(Python_3_0_Or_Later) {
        }else{
            static if(!is(C == char)) {
                str = PyObject_Unicode(str);
                if(!str) handle_exception();
            }
        }
    }
    static if(is(C == char)) {
        if(PyBytes_Check(str)) {
            const(char)* res = PyBytes_AsString(str);
            if(!res) handle_exception();
            return to!T(res);
        }
    }

    if(PyUnicode_Check(str)) {
        static if(is(C == char)) {
            PyObject* utf8 = PyUnicode_AsUTF8String(str);
            if(!utf8) handle_exception();
            const(char)* res = PyBytes_AsString(utf8);
            if(!res) handle_exception();
            return to!T(res);
        }else static if(is(C == wchar)) {
            PyObject* utf16 = PyUnicode_AsUTF16String(str);
            if(!utf16) handle_exception();
            // PyUnicode_AsUTF16String puts a BOM character in front of
            // string
            auto ptr = cast(const(wchar)*)(PyBytes_AsString(utf16)+2);
            Py_ssize_t len = PyBytes_Size(utf16)/2-1;
            wchar[] ws = new wchar[](len);
            ws[] = ptr[0 .. len];
            return cast(T) ws;
        }else static if(is(C == dchar)) {
            version(Python_2_6_Or_Later) {
                PyObject* utf32 = PyUnicode_AsUTF32String(str);
                if(!utf32) handle_exception();
                // PyUnicode_AsUTF32String puts a BOM character in front of
                // string
                auto ptr = cast(const(dchar)*)(PyBytes_AsString(utf32)+4);
                Py_ssize_t len = PyBytes_Size(utf32)/4-1;
                dchar[] ds = new dchar[](len);
                ds[] = ptr[0 .. len];
                return cast(T) ds;
            }else{
                return to!(T)(python_to_d!string(str));
            }
        }else static assert(false, "what T is this!? " ~ T.stringof);
    }
    assert(0);
}


// (*^&* array doesn't implement the buffer interface, but we still
// want it to copy fast.
/// Convert an array.array object to a D object.
///
/// Used by python_to_d.
T python_array_array_to_d(T)(PyObject* o) if(isArray!T || IsStaticArrayPointer!T) {
    import core.stdc.string : memcpy;

    static if (isPointer!T) {
        alias _T = PointerTarget!T;
    }else{
        alias _T = T;
    }

    static if (is(_T == struct)){
        pragma(msg, "python_array_array_to_d - ", fullyQualifiedName!T, " struct");
    }else static if (is(_T == class)) {
        pragma(msg, "python_array_array_to_d - ", fullyQualifiedName!T, " class");
    }else{
        pragma(msg, "python_array_array_to_d - ", fullyQualifiedName!T, " other");
    }

    static if(isPointer!T)
        alias E = Unqual!(ElementType!(PointerTarget!T));
    else
        alias E = Unqual!(ElementType!T);
    if(o.ob_type !is array_array_Type) could_not_convert!T(o, "not an array.array");
    arrayobject* arr_o = cast(arrayobject*) o;
    // array.array's data can be got with a single memcopy.
    enforce(arr_o.ob_descr, "array.ob_descr null!");
    char typecode = cast(char) arr_o.ob_descr.typecode;
    if(!match_format_type!E(""~typecode)) could_not_convert!T(o, format("item mismatch: '%s' vs %s", typecode, E.stringof));

    int itemsize = arr_o.ob_descr.itemsize;
    if(itemsize != E.sizeof) could_not_convert!T(o, format("item size mismatch: %s vs %s", itemsize, E.sizeof));
    Py_ssize_t count = Py_SIZE(arr_o);
    if(count < 0) could_not_convert!T(o, format("nonsensical array length: %s", count));
    MatrixInfo!T.unqual _array;
    static if(isDynamicArray!T) {
        _array = new MatrixInfo!T.unqual(count);
    }else {
        if(!MatrixInfo!T.check([count]))
            could_not_convert!T(o, format("length mismatch: %s vs %s", count, T.length));
    }
    // copy data, don't take slice
    static if(isPointer!(typeof(_array))) {
        memcpy((*_array).ptr, arr_o.ob_item, count*itemsize);
    }else{
        memcpy(_array.ptr, arr_o.ob_item, count*itemsize);
    }
    //_array[] = cast(E[]) arr_o.ob_item[0 .. count*itemsize];
    return cast(T) _array;
}


/**
  Convert a d array to a python array.array.
  array.array does not support 8 byte integers.

  Not used by d_to_python.
  */
PyObject* d_to_python_array_array(T)(T t) if(
        (isArray!T || !T) &&
        MatrixInfo!T.ndim == 1 &&
        SimpleFormatType!(MatrixInfo!T.MatrixElementType).supported
){
    import core.stdc.string : memcpy;

    alias ME = MatrixInfo!T.MatrixElementType;
    PyObject* pyformat = SimpleFormatType!ME.pyType();
    PyObject* args = PyTuple_New(1);
    PyTuple_SetItem(args, 0, pyformat);
    scope(exit) Py_DECREF(args);
    PyObject* obj = array_array_Type.tp_new(array_array_Type, args, null);
    if(!obj) handle_exception();
    arrayobject* arr_o = cast(arrayobject*) obj;
    Py_ssize_t[] shape = MatrixInfo!T.build_shape(t);
    size_t datalen = ME.sizeof*shape[0];
    Py_SET_SIZE(arr_o, shape[0]);
    void* data = PyMem_Malloc(datalen);
    static if(isPointer!T) {
        memcpy(data, t, datalen);
    }else {
        memcpy(data, t.ptr, datalen);
    }
    arr_o.ob_item = cast(ubyte*) data;
    return obj;
}


PyObject* d_to_python_bytes(T)(T t) if(is(T == string)) {
    return PyBytes_FromStringAndSize(t.ptr, cast(Py_ssize_t) t.length);
}


T python_iter_to_d(T)(PyObject* o) if(isArray!T || IsStaticArrayPointer!T) {
    static if(isPointer!T)
        alias E = Unqual!(ElementType!(PointerTarget!T));
    else
        alias E = Unqual!(ElementType!T);
    PyObject* iter = PyObject_GetIter(o);
    if (iter is null) {
        PyErr_Clear();
        could_not_convert!(T)(o);
    }
    scope(exit) Py_DECREF(iter);
    Py_ssize_t len = PyObject_Length(o);
    if (len == -1) {
        PyErr_Clear();
        could_not_convert!(T)(o);
    }

    MatrixInfo!T.unqual _array;
    static if(isDynamicArray!T) {
        _array = new MatrixInfo!T.unqual(len);
    }else static if(isStaticArray!T){
        if(len != T.length)
            could_not_convert!T(o,
            format("length mismatch: %s vs %s",
            len, T.length));
    }else static if(isPointer!T){
        ubyte[] bufi = new ubyte[](PointerTarget!T.sizeof);
        _array = cast(MatrixInfo!T.unqual)(bufi.ptr);
    }
    int i = 0;
    PyObject* item = PyIter_Next(iter);
    while (item) {
        try {
            _array[i] = python_to_d!(E)(item);
        } catch(PyToDConversionException e) {
            Py_DECREF(item);
            // We re-throw the original conversion exception, rather than
            // complaining about being unable to convert to an array. The
            // partially constructed array is left to the GC.
            throw e;
        }
        ++i;
        Py_DECREF(item);
        item = PyIter_Next(iter);
    }
    return cast(T) _array;
}


bool isPyNumber(PyObject* obj) {
    version(Python_3_0_Or_Later) {
        return
        PyLong_Check(obj) ||
        PyFloat_Check(obj);
    }else{
        return
        PyInt_Check(obj) ||
        PyLong_Check(obj) ||
        PyFloat_Check(obj);
    }
}


const(char)[] type_name(PyObject* obj) {
    import core.stdc.string : strlen;

    auto type = cast(PyTypeObject*)PyObject_Type(obj);
    return type.tp_name[0 .. strlen(type.tp_name)];
}


bool isNumpyBool(PyObject* obj) {
    switch(type_name(obj)) {
        case "numpy.bool_":
        return true;
        default:
        return false;
    }
}


bool isNumpyInteger(PyObject* obj) {
    switch(type_name(obj)) {
        case "numpy.int8":
        case "numpy.int16":
        case "numpy.int32":
        case "numpy.int64":
        case "numpy.uint8":
        case "numpy.uint16":
        case "numpy.uint32":
        case "numpy.uint64":
        return true;
        default:
        return false;
    }
}


bool isNumpyFloat(PyObject* obj) {
    switch(type_name(obj)) {
        case "numpy.float32":
        case "numpy.float64":
        return true;
        default:
        return false;
    }
}


bool isNumpyComplexNumber(PyObject* obj) {
    switch(type_name(obj)) {
        case "numpy.complex32":
        case "numpy.complex64":
        return true;
        default:
        return false;
    }
}


bool isNumpyNumber(PyObject* obj) {
    return isNumpyBool(obj) || isNumpyInteger(obj) || isNumpyFloat(obj);
}


version(Python_2_6_Or_Later) {
    /// Convert a Python new-style buffer to a D object.
    ///
    /// Used by python_to_d.
    T python_buffer_to_d(T)(PyObject* o) if (isArray!T || IsStaticArrayPointer!T) {
        import core.stdc.string : memcpy;

        PydObject bob = new PydObject(borrowed(o));
        auto buf = bob.buffer_view();
        alias MatrixInfo!T.MatrixElementType ME;
        MatrixInfo!T.unqual _array;
        /+
        if(buf.itemsize != ME.sizeof)
            could_not_convert!T(
                o,
                format(
                    "item size mismatch: %s vs %s",
                    buf.itemsize,
                    ME.sizeof
                )
            );
        +/
        if(!match_format_type!ME(buf.format)) {
            could_not_convert!T(o, format("item type mismatch: '%s' vs %s",
            buf.format, ME.stringof));
        }
        if(buf.has_nd) {
            if(!MatrixInfo!T.check(buf.shape))
                could_not_convert!T(
                    o,
                    format(
                        "dimension mismatch: %s vs %s",
                        buf.shape,
                        MatrixInfo!T.dimstring
                    )
                );
            if(buf.c_contiguous) {
                // woohoo! single memcpy
                static if(MatrixInfo!T.isRectArray && isStaticArray!T) {
                    memcpy(_array.ptr, buf.buf.ptr, buf.buf.length);
                }else{
                    alias MatrixInfo!T.RectArrayType RectArrayType;
                    static if(!isStaticArray!(RectArrayType)) {
                        ubyte[] dbuf = new ubyte[](buf.buf.length);
                        memcpy(dbuf.ptr, buf.buf.ptr, buf.buf.length);
                    }
                    size_t rectsize = ME.sizeof;
                    size_t MErectsize = 1;
                    foreach(i; MatrixInfo!T.rectArrayAt .. MatrixInfo!T.ndim) {
                        rectsize *= buf.shape[i];
                        MErectsize *= buf.shape[i];
                    }
                    static if(MatrixInfo!T.isRectArray) {
                        static if(isPointer!T)
                            _array = cast(typeof(_array)) dbuf.ptr;
                        else {
                            static assert(isDynamicArray!T);
                            _array = cast(typeof(_array)) dbuf;
                        }
                    }else{
                        // rubbish. much pointer pointing
                        size_t offset = 0;
                        static if(isDynamicArray!T) {
                            _array = new MatrixInfo!T.unqual(buf.shape[0]);
                        }
                        enum string xx = (MatrixInfo!T.matrixIter(
                            "_array",
                            "buf.shape",
                            "_indices",
                            MatrixInfo!T.rectArrayAt,
                            q{
                                static if(isDynamicArray!(typeof($array_ixn))) {
                                    $array_ixn = new typeof($array_ixn)(buf.shape[$i+1]);
                                }
                                static if(is(typeof($array_ixn) == RectArrayType)) {
                                    // should be innermost loop
                                    assert(offset + rectsize <= buf.buf.length, "uh oh: overflow!");
                                    alias typeof($array_ixn) rectarr;
                                    static if(isStaticArray!rectarr) {
                                        memcpy($array_ixn.ptr, buf.buf.ptr + offset, rectsize);
                                    }else{
                                        static assert(isDynamicArray!rectarr);

                                        $array_ixn = (cast(typeof($array_ixn.ptr))(dbuf.ptr + offset))
                                            [0 .. MErectsize];
                                    }
                                    offset += rectsize;
                                }
                            },
                            ""
                        ));
                        mixin(xx);
                    }
                }
            }else if(buf.fortran_contiguous) {
                // really rubbish. no memcpy.
                static if(isDynamicArray!T) {
                    _array = new MatrixInfo!T.unqual(buf.shape[0]);
                }else static if(isPointer!T) {
                    ubyte[] dubuf = new ubyte[](buf.buffer.len);
                    _array = cast(typeof(_array)) dubuf.ptr;
                }
                enum string xx = (MatrixInfo!T.matrixIter(
                    "_array",
                    "buf.shape",
                    "_indices",
                    MatrixInfo!T.ndim,
                    q{
                        static if(isDynamicArray!(typeof($array_ixn))) {
                            $array_ixn = new typeof($array_ixn)(buf.shape[$i+1]);
                        }else static if(is(typeof($array_ixn) == ME)) {
                            $array_ixn = buf.item!ME(cast(Py_ssize_t[]) _indices);
                        }
                    },
                    ""
                ));
                mixin(xx);
            }else {
                // wut?
                could_not_convert!T(o,("todo: know what todo"));
                assert(0);
            }
            return cast(T) _array;
        }else if(buf.has_simple) {
            /*
               static if(isDynamicArray!T) {
               E[] array = new E[](buf.buf.length);
               }else static if(isStaticArray!T) {
               if(buf.buf.length != T.length)
               could_not_convert!T(o,
               format("length mismatch: %s vs %s",
               buf.buf.length, T.length));
               E[T.length] array;
               }
               return cast(T) array;
             */
            assert(0, "Unhandle case - buf.has_simple");
        }
        return cast(T) _array;
    }
}


/**
  Wrap a D input range as a python iterator object.

  Does not work for UFCS ranges (e.g. arrays), classes
  */
auto wrap_range(Range)(Range range) if(is(Range == struct)) {
    static assert(!is(Range == InputRangeWrapper));
    import core.memory;
    InputRangeWrapper wrap;
    // the hackery! the hackery!
    Range* keeper = cast(Range*) GC.calloc(Range.sizeof);
    std.algorithm.move(range, *keeper);
    wrap.range = cast(void*) keeper;
    wrap.tid = typeid(Range);
    wrap.empty = dg_wrapper(keeper, &Range.empty);
    wrap.popFront = dg_wrapper(keeper, &Range.popFront);
    auto front_dg = dg_wrapper(keeper, cast(ElementType!Range function()) &Range.front);
    wrap.front = delegate PyObject*() {
        return d_to_python(front_dg());
    };
    return wrap;
}


/**
  Wraps D input range as a python iterator object

  Lives in reserved python module "pyd".
  */
struct InputRangeWrapper {
    void* range;
    void delegate() popFront;
    PyObject* delegate() front;
    bool delegate() empty;
    TypeInfo tid;

    InputRangeWrapper* iter() {
        return &this;
    }
    PyObject* next() {
        if(this.empty()) {
            return null;
        }else {
            auto result = d_to_python(this.front());
            this.popFront();
            return result;
        }
    }
}


/// Check T against format
/// See_Also:
/// <a href='http://docs.python.org/library/struct.html#struct-format-strings'>
/// Struct Format Strings </a>
bool match_format_type(T)(string format) {
    import std.exception: enforce;

    alias S = T;
    size_t S_size = S.sizeof;
    enforce(format.length > 0);

    bool native_size = false;
    switch(format[0]) {
        case '@':
        // this (*&^& function is not defined
        //PyBuffer_SizeFromFormat()
        native_size = true;
        goto case;
        case '=','<','>','!':
        format = format[1 .. $];
        default:
        break;
    }
    // by typeishness
    switch(format[0]) {
        case 'x', 's', 'p':
        // don't support these
        enforce(false, "unsupported format: " ~ format);
        case 'c':
        break;
        case 'b', 'h','i','l','q':
        if(!isSigned!S) return false;
        else break;
        case 'B', 'H', 'I', 'L','Q':
        if(!isUnsigned!S) return false;
        else break;
        case 'f','d':
        if(!isFloatingPoint!S) return false;
        else break;
        case '?':
        if(!isBoolean!S) return false;
        case 'Z':
        if (format.length > 1) {
            static if(is(S : Complex!F, F)) {
                S_size = F.sizeof;
            }else{
                return false;
            }
        }
        format = format[1..$];
        break;
        default:
        enforce(false, "unknown format: " ~ format);
    }

    // by sizeishness
    if(native_size) {
        // grr
        assert(0, "todo");
    }else{
        switch(format[0]) {
            case 'c','b','B','?':
            return (S_size == 1);
            case 'h','H':
            return (S_size == 2);
            case 'i','I','l','L','f':
            return (S_size == 4);
            case 'q','Q','d':
            return (S_size == 8);
            default:
            enforce(false, "unknown format: " ~ format);
            assert(0); // seriously, d?

        }
    }
}


/// generate a struct format string from T
template SimpleFormatType(T) {
    enum supported =
    (isFloatingPoint!T && (T.sizeof == 4 || T.sizeof == 8) ||
    isIntegral!T);

    PyObject* pyType() {
        //assert(supported);
        static if(supported) {
            version(Python_3_0_Or_Later) {
                alias to_python = d_to_python;
            }else{
                // stinking py2 array won't take unicode
                alias to_python = d_to_python_bytes;
            }
            static if(isFloatingPoint!T && T.sizeof == 4) {
                return to_python("f");
            }else static if(isFloatingPoint!T && T.sizeof == 8) {
                return to_python("d");
            }else static if(isIntegral!T && T.sizeof == 1) {
                return to_python(isSigned!T ? "b" : "B");
            }else static if(isIntegral!T && T.sizeof == 2) {
                return to_python(isSigned!T ? "h" : "H");
            }else static if(isIntegral!T && T.sizeof == 4) {
                return to_python(isSigned!T ? "i" : "I");
            }else static if(isIntegral!T && T.sizeof == 8) {
                return to_python(isSigned!T ? "q" : "Q");
            }else {
                return null;
            }
        }else{
            assert(false);
        }
    }
}






/**
  Check that T is a pointer to a rectangular static array.
  */
template IsStaticArrayPointer(T) {
    template _Inner(S) {
        static if(isStaticArray!S) {
            enum _Inner = _Inner!(ElementType!S);
        } else static if(isArray!S || isPointer!S) {
            enum _Inner = false;
        }else {
            enum _Inner = true;
        }
    }
    static if(isPointer!T) {
        enum bool IsStaticArrayPointer = _Inner!(PointerTarget!T);
    }else{
        enum bool IsStaticArrayPointer = false;
    }
}


/**
  Some reflective information about multidimensional arrays

  Handles dynamic arrays, static arrays, and pointers to static arrays.
*/
template MatrixInfo(T) if(isArray!T || IsStaticArrayPointer!T) {
    template ElementType2(_T) {
        static if(isSomeString!_T) {
            alias ElementType2=_T;
        }else{
            alias ElementType2=ElementType!_T;
        }
    }

    template _dim_list(T, dimi...) {
        static if(isSomeString!T) {
            alias dimi list;
            alias T elt;
            alias Unqual!T unqual;
        } else static if(isDynamicArray!T) {
            alias _dim_list!(ElementType2!T, dimi,-1) next;
            alias next.list list;
            alias next.elt elt;
            alias next.unqual[] unqual;
        }else static if(isStaticArray!T) {
                alias _dim_list!(ElementType2!T, dimi, cast(Py_ssize_t) T.length) next;
                alias next.list list;
                alias next.elt elt;
                alias next.unqual[T.length] unqual;
            }else {
                alias dimi list;
                alias T elt;
                alias Unqual!T unqual;
            }
    }

    string tuple2string(T...)() {
        string s = "[";
        foreach(i, t; T) {
            if(t == -1) s ~= "*";
            else s ~= to!string(t);
            if(i == T.length-1) {
                s ~= "]";
            }else{
                s ~= ",";
            }
        }
        return s;
    }

    /**
      Build shape from t. Assumes all arrays in a dimension are initialized
      and of uniform length.
      */
    Py_ssize_t[] build_shape(T t) {
        Py_ssize_t[] shape = new Py_ssize_t[](ndim);
        mixin(shape_builder_mixin("t", "shape"));
        return shape;
    }

    string shape_builder_mixin(string arr_name, string shape_name) {
        static if(isPointer!T) {
            string s_ixn = "(*" ~ arr_name ~ ")";
        }else{
            string s_ixn = arr_name;
        }
        string s = "";
        foreach(i; 0 .. ndim) {
            s ~= shape_name ~ "["~ to!string(i) ~"] = cast(Py_ssize_t)" ~ s_ixn ~ ".length;";
            s_ixn ~= "[0]";
        }
        return s;
    }

    /**
      Ensures that T can store a matrix of _shape shape.
      */
    bool check(Py_ssize_t[] shape) {
        if (shape.length != dim_list.length) return false;
        foreach(i, d; dim_list) {
            static if(dim_list[i] == -1) continue;
            else if(d != shape[i]) return false;
        }
        return true;
    }

    /**
    Generate a mixin string of nested for loops that iterate over the
    first ndim dimensions of an array of type T (or, preferrably
    MatrixInfo!T.unqual).

    Params:
    arr_name = name of array to iterate.
    shape_name = name of array of dimension lengths.
    index_name = name to use for index vector. Declared in a new nested scoped.
    ndim = number of dimensions to iterate over.
    pre_code = code to mixin each for loop before beginning the nested for loop.
    post_code = code to mix in to each for loop after finishing the nested for loop.
    */

    string matrixIter(string arr_name, string shape_name,
    string index_name,
    size_t ndim,
    string pre_code, string post_code) {
        string s_begin = "{\n";
        string s_end = "}\n";
        static if(isPointer!T) {
            string s_ixn = "(*" ~ arr_name ~ ")";
        }else{
            string s_ixn = arr_name;
        }

        s_begin ~= "size_t[" ~ to!string(ndim) ~ "] " ~ index_name ~ ";\n";
        foreach(i; 0 .. ndim) {
            string s_i = to!string(i);
            s_ixn ~= "["~ index_name ~ "[" ~ s_i ~ "]]";
            string index = index_name~ "[" ~ s_i ~ "]";
            string shape_i = shape_name ~ "[" ~ s_i ~ "]";
            s_begin ~= "for("~index~" = 0;" ~index ~ " < " ~ shape_i ~
            "; " ~ index ~ "++) {";
            s_end ~= "}\n";

            string pre_code_i = replace(pre_code, "$array_ixn", s_ixn);
            pre_code_i = replace(pre_code_i, "$i", s_i);
            s_begin ~= pre_code_i;
            string post_code_i = replace(post_code, "$array_ixn", s_ixn);
            post_code_i = replace(post_code_i, "$i", s_i);
            s_end ~= post_code_i;
        }
        return s_begin ~ s_end;
    }

    static if(isPointer!T && isStaticArray!(PointerTarget!T)) {
        alias _dim_list!(PointerTarget!T) _dim;
        /// T, with all nonmutable qualifiers stripped away.
        alias _dim.unqual* unqual;
    }else{
        alias _dim_list!T _dim;
        alias _dim.unqual unqual;
    }

    /// tuple of dimensions of T.
    /// dim_list[0] will be the dimension furthest from the MatrixElementType
    /// i.e. for double[1][2][3], dim_list == (3, 2, 1).
    /// Lists -1 as dimension of dynamic arrays.
    alias _dim.list dim_list;

    /// number of dimensions of this matrix
    enum ndim = dim_list.length;

    /// T is a RectArray if:
    /// * it is any multidimensional static array (or a pointer to)
    /// * it is a 1 dimensional dynamic array
    enum bool isRectArray = staticIndexOf!(-1, dim_list) == -1 || dim_list.length == 1;

    //(1,2,3) -> rectArrayAt == 0
    //(-1,2,3) -> rectArrayAt == 1 == 3 - 2 == len - max(indexof_rev, 1)
    //(-1,-1,1) -> rectArrayAt == 2 == 3 - 1 == len - max(indexof_rev,1)
    //(-1,-1,-1) -> rectArrayAt == 2 == 3 - 1 == len - max(indexof_rev,1)
    //(2,2,-1) -> rectArrayAt == 2
    enum size_t indexof_rev = staticIndexOf!(-1, Reverse!dim_list);

    /// Highest dimension where it and all subsequent dimensions form a
    /// RectArray.
    enum size_t rectArrayAt = isRectArray ? 0 : dim_list.length - max(indexof_rev, 1);
    template _rect_type(S, size_t i) {
        static if(i == rectArrayAt) {
            alias S _rect_type;
        } else {
            alias _rect_type!(ElementType!S, i+1) _rect_type;
        }
    }

    /// unqualified highest dimension subtype of T forming RectArray
    alias _rect_type!(unqual, 0) RectArrayType;

    /// Pretty string of dimension list for T
    enum string dimstring = tuple2string!(dim_list)();

    /// Matrix element type of T
    /// E.g. immutable(double) for T=immutable(double[4][4])
    alias _dim.elt MatrixElementType;
}


@property PyTypeObject* array_array_Type() {
    static PyTypeObject* m_type;
    if(!m_type) {
        PyObject* array = PyImport_ImportModule("array");
        scope(exit) Py_XDECREF(array);
        m_type = cast(PyTypeObject*) PyObject_GetAttrString(array, "array");
    }
    return m_type;
}


alias python_to_d_Object = python_to_d!(Object);


void could_not_convert(T) (PyObject* o, string reason = "", string file = __FILE__, size_t line = __LINE__) {
    // Pull out the name of the type of this Python object, and the
    // name of the D type.
    string py_typename, d_typename;
    PyObject* py_type, py_type_str;
    py_type = PyObject_Type(o);
    if (py_type is null) {
        py_typename = "<unknown>";
    } else {
        py_type_str = PyObject_GetAttrString(py_type, cast(const(char)*) "__name__".ptr);
        Py_DECREF(py_type);
        if (py_type_str is null) {
            py_typename = "<unknown>";
        } else {
            py_typename = python_to_d!string(py_type_str);
            Py_DECREF(py_type_str);
        }
    }
    d_typename = typeid(T).toString();
    string because;
    if(reason != "") because = format(" because: %s", reason);
    throw new PyToDConversionException(
    format("Couldn't convert Python type '%s' to D type '%s'%s",
    py_typename,
    d_typename,
    because),
    file, line
    );
}


// stuff this down here until we can figure out what to do with it.
// Python-header-file: Modules/arraymodule.c:

struct arraydescr {
    int typecode;
    int itemsize;
    PyObject* function(arrayobject*, Py_ssize_t) getitem;
    int function(arrayobject*, Py_ssize_t, PyObject*) setitem;
}


struct arrayobject {
    mixin PyObject_VAR_HEAD;
    ubyte* ob_item;
    Py_ssize_t allocated;
    arraydescr* ob_descr;
    PyObject* weakreflist; /* List of weak references */
}


template get_type(string _module, string type_name) {
    @property PyTypeObject* get_type() {
        static PyTypeObject* m_type;
        static bool inited = false;
        if(!inited) {
            inited = true;
            PyObject* py_module = PyImport_ImportModule(_module);
            if(py_module) {
                scope(exit) Py_XDECREF(py_module);
                m_type = cast(PyTypeObject*) PyObject_GetAttrString(
                py_module, type_name
                );
            }else{
                PyErr_Clear();
            }
        }
        return m_type;
    }
}


alias numpy_datetime64 = get_type!("numpy", "datetime64");


alias datetime_datetime = get_type!("datetime", "datetime");


bool is_numpy_datetime64(PyObject* o) {
    auto py_type = cast(PyTypeObject*) PyObject_Type(o);
    return (numpy_datetime64 !is null && py_type == numpy_datetime64);
}


T python_to_d_numpy_datetime64(T)(PyObject* o) {
    PyObject* astype = PyObject_GetAttrString(o, "astype");
    PyObject* args = items_to_PyTuple(cast(PyObject*) datetime_datetime);
    scope(exit) Py_DECREF(args);
    PyObject* datetime = PyObject_CallObject(astype, args);
    scope(exit) Py_DECREF(datetime);
    return python_to_d!T(datetime);
}
