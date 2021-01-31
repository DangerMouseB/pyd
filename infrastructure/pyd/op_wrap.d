/*
Copyright (c) 2006 Kirk McDonald

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

module pyd.op_wrap;

import std.algorithm: startsWith, endsWith;
import std.traits;
import std.exception: enforce;
import std.string: format;
import std.conv: to;
import std.stdio : writeln;

import deimos.python.Python;
import pyd.util.typeinfo;
import pyd.util.dg_wrapper;
import pyd.references;
import pyd.class_wrap;
import pyd.exception;
import pyd.conversions.d_to_python : d_to_python;
import pyd.conversions.python_to_d : python_to_d;


import bones_vm.pyig.config : PyiTrace;
import bones_vm.pyig._dispatch : memberfunc_to_func, method_dgwrap, applyTernaryDelegateReturnPyObject, callFuncArgsKwargsReturnPyObject;
import bones_vm.pyig.attributes : signatureWithAttributes, fnHasArgsAttr, fnHasKwargsAttr;




template binopasg_wrap(T, alias fn) {
    alias wtype = PydTypeObject!T;
    alias get_dg = dg_wrapper!(T, typeof(&fn));
    alias OtherT = Parameters!(fn)[0];
    alias Ret = ReturnType!(fn) ;

    extern(C) PyObject* func(PyObject* self, PyObject* o2) {
        auto dg = get_dg(get_d_reference!T(self), &fn);
        dg(python_to_d!OtherT(o2));
        // why?
        // http://stackoverflow.com/questions/11897597/implementing-nb-inplace-add-results-in-returning-a-read-only-buffer-object
        // .. still don't know
        Py_INCREF(self);
        return self;
    }
}


template powopasg_wrap(T, alias fn) {
    alias PydTypeObject!T wtype;
    alias dg_wrapper!(T, typeof(&fn)) get_dg;
    alias Parameters!(fn)[0] OtherT;
    alias ReturnType!(fn) Ret;

    extern(C) PyObject* func(PyObject* self, PyObject* o2, PyObject* o3) {
        auto dg = get_dg(get_d_reference!T(self), &fn);
        dg(python_to_d!OtherT(o2));
        // why?
        // http://stackoverflow.com/questions/11897597/implementing-nb-inplace-add-results-in-returning-a-read-only-buffer-object
        // .. still don't know
        Py_INCREF(self);
        return self;
    }
}

template opcall_wrap(C, alias fn, string classname) {
    // DBHERE
    import bones_vm.pyig.attributes : signatureWithAttributes;
    //static if(PyiTrace) pragma(msg, "pyd.op_wrap.opcall_wrap #1");
    static assert(constCompatible(constness!C, constness!(typeof(fn))),
            format("constness mismatch instance: %s function: %s",
                C.stringof, typeof(fn).stringof));
    alias wtype = PydTypeObject!C;
    alias get_dg = dg_wrapper!(C, typeof(&fn));
    //alias OtherT = Parameters!(fn)[0];   // DBHERE
    alias Ret = ReturnType!(fn);
    enum string fname = classname~"__call__";

    //static if(PyiTrace) pragma(msg, "pyd.op_wrap.opcall_wrap #2");
    @(__traits(getAttributes, fn))
    extern(C) PyObject* func(PyObject* self, PyObject* args, PyObject* kwargs) {
        return exception_catcher(delegate PyObject*() {
            // Didn't pass a "self" parameter! Ack!
            if (self is null) {
                PyErr_SetString(PyExc_TypeError, "OpCall didn't get a 'self' parameter.");
                return null;
            }
            C instance = get_d_reference!C(self);
            if (instance is null) {
                PyErr_SetString(PyExc_ValueError, "Wrapped class instance is null!");
                return null;
            }

            alias sigHasArgs = fnHasArgsAttr!fn;
            alias sigHasKwargs = fnHasKwargsAttr!fn;

            static if (sigHasArgs && !sigHasKwargs){
                // should do - figure where the arg is and place in tuple accordingly?
                // SHOULDDO throw type error if we have kwargs
                PyObject* self_args = PyTuple_New( cast(Py_ssize_t) 2);
                scope(exit) {Py_XDECREF( self_args);}
                enforce( self_args);
                Py_INCREF( self);
                PyTuple_SetItem( self_args, 0, self);
                if (args is null) {
                    PyObject* t = PyTuple_New(0);
                    Py_INCREF( t);
                    PyTuple_SetItem( self_args, 1, t);
                } else {
                    Py_INCREF( args);
                    PyTuple_SetItem( self_args, 1, args);
                }

                alias func = memberfunc_to_func!(C, fn).func;
                //static if(PyiTrace) pragma(msg, "bones_vm.pyig._dispatch.method_wrap func - "~signatureWithAttributes!func);
                return callFuncArgsKwargsReturnPyObject!(func, fname)( self_args, null);

            } else static if (!sigHasArgs && sigHasKwargs){
                // should do - figure where the arg is and place in tuple accordingly?
                // SHOULDDO throw type error if we have args
                Py_ssize_t arglen = args is null ? 0 : PyObject_Length( args);
                enforce( arglen != -1);
                // if len args > 0 then throw a typr error
                PyObject* self_kwargs = PyTuple_New( cast(Py_ssize_t) 2);
                scope(exit) {Py_XDECREF( self_kwargs);}
                enforce( self_kwargs);
                Py_INCREF( self);
                PyTuple_SetItem( self_kwargs, 0, self);
                if (kwargs is null) {
                    PyObject* d = PyDict_New();
                    Py_INCREF( d);
                    PyTuple_SetItem( self_kwargs, 1, d);
                } else {
                    Py_INCREF( kwargs);
                    PyTuple_SetItem( self_kwargs, 1, kwargs);
                }

                alias func = memberfunc_to_func!(C, fn).func;
                //static if(PyiTrace) pragma(msg, "bones_vm.pyig._dispatch.method_wrap func - "~signatureWithAttributes!func);
                return callFuncArgsKwargsReturnPyObject!(func, fname)( self_kwargs, null);

            } else static if (sigHasArgs && sigHasKwargs){
                // should do - figure where the arg is and place in tuple accordingly?

                PyObject* self_args_kwargs = PyTuple_New( cast(Py_ssize_t) 3);
                scope(exit) {Py_XDECREF( self_args_kwargs);}
                enforce( self_args_kwargs);
                Py_INCREF( self);
                PyTuple_SetItem( self_args_kwargs, 0, self);
                if (args is null) {
                    PyObject* t = PyTuple_New(0);
                    Py_INCREF( t);
                    PyTuple_SetItem( self_args_kwargs, 1, t);
                } else {
                    Py_INCREF( args);
                    PyTuple_SetItem( self_args_kwargs, 1, args);
                }
                if (kwargs is null) {
                    PyObject* d = PyDict_New();
                    Py_INCREF( d);
                    PyTuple_SetItem( self_args_kwargs, 2, d);
                } else {
                    Py_INCREF( kwargs);
                    PyTuple_SetItem( self_args_kwargs, 2, kwargs);
                }

                alias func = memberfunc_to_func!(C, fn).func;
                //static if(PyiTrace) pragma(msg, "bones_vm.pyig._dispatch.method_wrap func - "~signatureWithAttributes!func);
                return callFuncArgsKwargsReturnPyObject!(func, fname)( self_args_kwargs, null);

            } else {

                Py_ssize_t arglen = args is null ? 0 : PyObject_Length( args);
                enforce( arglen != -1);
                PyObject* self_and_args = PyTuple_New( cast(Py_ssize_t) arglen+1);
                scope(exit) {Py_XDECREF( self_and_args);}
                enforce( self_and_args);
                PyTuple_SetItem( self_and_args, 0, self);
                Py_INCREF( self);
                foreach (i; 0 .. arglen) {
                    auto pobj = Py_XINCREF( PyTuple_GetItem( args, cast(Py_ssize_t) i));
                    PyTuple_SetItem( self_and_args, cast(Py_ssize_t) i+1, pobj);
                }
                alias func = oldmemberfunc_to_func!(C, fn).func;
                //static if(PyiTrace) pragma(msg, "bones_vm.pyig._dispatch.method_wrap func - "~signatureWithAttributes!func);
                return callFuncArgsKwargsReturnPyObject!(func, fname)( self_and_args, kwargs);


                //auto dg = get_dg( instance, &fn);
                ////pragma(msg, "pyd.op_wrap.opcall_wrap.func.exception_catcher #4");
                //return applyTernaryDelegateReturnPyObject( dg, args);   // DBHERE add kwargs
            }
        });
    }
}



private template oldmemberfunc_to_func(T, alias fn) {
    alias Ret = ReturnType!fn;
    alias PS = ParameterTypeTuple!fn;
    alias ids = ParameterIdentifierTuple!fn;
    //alias dfs = ParameterDefaultValueTuple!fn;      //https://issues.dlang.org/show_bug.cgi?id=17192
    alias dfs = WorkaroundParameterDefaults!fn;
    enum params = getparams!(fn,"PS","dfs");
    enum t = gensym!ids();

    mixin(Replace!(
        q{
            @(__traits(getAttributes, fn))
            Ret func(T $t, $params) {
                auto dg = dg_wrapper($t, &fn);
                return dg($ids);
            }
        },
        "$params", params,
        "$fn", __traits(identifier, fn),
        "$t",t,
        "$ids",Join!(",",ids)
    ));
}


//----------------
// Implementation
//----------------




template opiter_wrap(T, alias fn){
    alias params = Parameters!fn;
    extern(C) PyObject* func(PyObject* self) {
        alias func = memberfunc_to_func!(T,fn).func;
        return exception_catcher(delegate PyObject*() {
            T t = python_to_d!T(self);
            auto dg = dg_wrapper(t, &fn);
            return d_to_python(dg());
        });
    }
}


template opindex_wrap(T, alias fn) {
    alias Params = Parameters!fn;
    alias get_dg = dg_wrapper!(T, typeof(&fn));

    // Multiple arguments are converted into tuples, and thus become a standard
    // wrapped member function call. A single argument is passed directly.
    static if (Params.length == 1){
        alias KeyT = Params[0];
        extern(C) PyObject* func(PyObject* self, PyObject* key) {
            return exception_catcher(delegate PyObject*() {
                auto dg = get_dg(get_d_reference!T(self), &fn);
                return d_to_python(dg(python_to_d!KeyT(key)));
            });
        }
    }else{
        alias opindex_methodT = method_dgwrap!(T, fn);
        extern(C) PyObject* func(PyObject* self, PyObject* key) {
            Py_ssize_t args;
            if (!PyTuple_CheckExact(key)) {
                args = 1;
            } else {
                args = PySequence_Length(key);
            }
            if (Params.length != args) {
                setWrongArgsError(args, Params.length, Params.length);
                return null;
            }
            return opindex_methodT.func(self, key);
        }
    }
}


template opindexassign_wrap(T, alias fn) {
    alias Params = Parameters!(fn);

    static if (Params.length > 2){
        alias fn_wrap = method_dgwrap!(T, fn);
        extern(C) int func(PyObject* self, PyObject* key, PyObject* val) {
            Py_ssize_t args;
            if (!PyTuple_CheckExact(key)) {
                args = 2;
            } else {
                args = PySequence_Length(key) + 1;
            }
            if (Params.length != args) {
                setWrongArgsError(args, Params.length, Params.length);
                return -1;
            }
            // Build a new tuple with the value at the front.
            PyObject* temp = PyTuple_New(Params.length);
            if (temp is null) return -1;
            scope(exit) Py_DECREF(temp);
            PyTuple_SetItem(temp, 0, val);
            for (int i=1; i<Params.length; ++i) {
                Py_INCREF(PyTuple_GetItem(key, i-1));
                PyTuple_SetItem(temp, i, PyTuple_GetItem(key, i-1));
            }
            fnwrap.func(self, temp);
            return 0;
        }
    }else{
        alias get_dg = dg_wrapper!(T, typeof(&fn));
        alias ValT = Params[0];
        alias KeyT = Params[1];

        extern(C) int func(PyObject* self, PyObject* key, PyObject* val) {
            return exception_catcher(delegate int() {
                auto dg = get_dg(get_d_reference!T(self), &fn);
                dg(python_to_d!ValT(val), python_to_d!KeyT(key));
                return 0;
            });
        }
    }
}



template opcmp_wrap(T, alias fn) {
    static assert(constCompatible(constness!T, constness!(typeof(fn))),
            format("constness mismatch instance: %s function: %s",
                T.stringof, typeof(fn).stringof));
    alias Info = Parameters!(fn);
    alias OtherT = Info[0];
    extern(C) int func(PyObject* self, PyObject* other) {
        return exception_catcher(delegate int() {
            int result = get_d_reference!T(self).opCmp(python_to_d!OtherT(other));
            // The Python API reference specifies that tp_compare must return
            // -1, 0, or 1. The D spec says opCmp may return any integer value,
            // and just compares it with zero.
            if (result < 0) return -1;
            if (result == 0) return 0;
            if (result > 0) return 1;
            assert(0);
        });
    }
}



template length_wrap(T, alias fn) {
    alias get_dg = dg_wrapper!(T, typeof(&fn));
    extern(C) Py_ssize_t func(PyObject* self) {
        return exception_catcher(delegate Py_ssize_t() {
            auto dg = get_dg(get_d_reference!T(self), &fn);
            return dg();
        });
    }
}


template opslice_wrap(T,alias fn) {
    alias get_dg = dg_wrapper!(T, typeof(&fn));
    extern(C) PyObject* func(PyObject* self, Py_ssize_t i1, Py_ssize_t i2) {
        return exception_catcher(delegate PyObject*() {
            auto dg = get_dg(get_d_reference!T(self), &fn);
            return d_to_python(dg(i1, i2));
        });
    }
}


template opsliceassign_wrap(T, alias fn) {
    alias Params = Parameters!fn;
    alias AssignT = Params[0];
    alias get_dg = dg_wrapper!(T, typeof(&fn));

    extern(C) int func(PyObject* self, Py_ssize_t i1, Py_ssize_t i2, PyObject* o) {
        return exception_catcher(delegate int() {
            auto dg = get_dg(get_d_reference!T(self), &fn);
            dg(python_to_d!AssignT(o), i1, i2);
            return 0;
        });
    }
}

