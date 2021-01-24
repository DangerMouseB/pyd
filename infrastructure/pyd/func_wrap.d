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

/**
  Mostly internal utilities.
  */
module pyd.func_wrap;

import std.range;
import std.conv;
import std.compiler;
import std.string: format;
import std.traits;


import deimos.python.Python;
import pyd.util.typelist;
import pyd.util.typeinfo;
import pyd.util.replace: Replace;
import pyd.util.dg_wrapper;

import pyd.def;
import pyd.references;
import pyd.class_wrap;
import pyd.exception;
import pyd.make_object : d_to_python, python_to_d, items_to_PyTuple;

import pyd.reboot.attributes : pyargs, pykwargs, pymagic, signatureWithAttributes;
import pyd.reboot._dispatch : applyFnDelegateToArgs, applyFnAliasToArgsKwargsAnswerNoneIfVoid;
import pyd.reboot._dispatch_utils : supportsNArgs, minArgs, maxArgs;


template hasFunctionAttrs(T) {
    static if(isDelegate!T || isFunctionPointer!T) {
        enum bool hasFunctionAttrs = functionAttributes!T !=
            FunctionAttribute.none;
    }else{
        enum bool hasFunctionAttrs = false;
    }
}

template StripFunctionAttributes(F) {
    static if(hasFunctionAttrs!F) {
        alias StripFunctionAttributes = SetFunctionAttributes!(F,
                functionLinkage!F,
                StrippedFunctionAttributes);
    }else{
        alias StripFunctionAttributes = F;
    }
}

static if(version_major == 2 && version_minor >= 67) {
    enum StrippedFunctionAttributes = FunctionAttribute.system;
}else{
    enum StrippedFunctionAttributes = FunctionAttribute.none;
}

// Builds a callable Python object from a delegate or function pointer.
void PydWrappedFunc_Ready(S)() {
    alias T = StripFunctionAttributes!S;
    alias PydTypeObject!(T) type;
    alias wrapped_class_object!(T) obj;
    if (!is_wrapped!(T)) {
        init_PyTypeObject!T(type);
        Py_SET_TYPE(&type, &PyType_Type);
        type.tp_basicsize = obj.sizeof;
        type.tp_name = "PydFunc".ptr;
        type.tp_flags = Py_TPFLAGS_DEFAULT;

        type.tp_call = &wrapped_func_call!(T).call;

        PyType_Ready(&type);
        is_wrapped!T = true;
    }
}

void setWrongArgsError(Py_ssize_t gotArgs, size_t minArgs, size_t maxArgs, string funcName="") {

    string argStr(size_t args) {
        string temp = to!string(args) ~ " argument";
        if (args > 1) {
            temp ~= "s";
        }
        return temp;
    }
    string str = (funcName == ""?"function":funcName~"()") ~ "takes";

    if (minArgs == maxArgs) {
        if (minArgs == 0) {
            str ~= "no arguments";
        } else {
            str ~= "exactly " ~ argStr(minArgs);
        }
    }
    else if (gotArgs < minArgs) {
        str ~= "at least " ~ argStr(minArgs);
    } else {
        str ~= "at most " ~ argStr(maxArgs);
    }
    str ~= " (" ~ to!string(gotArgs) ~ " given)";

    PyErr_SetString(PyExc_TypeError, (str ~ "\0").dup.ptr);
}


template wrapped_func_call(fn_t) {
    enum size_t ARGS = Parameters!(fn_t).length;
    alias ReturnType!(fn_t) RT;
    // The entry for the tp_call slot of the PydFunc types.
    // (Or: What gets called when you pass a delegate or function pointer to
    // Python.)
    extern(C)
    PyObject* call(PyObject* self, PyObject* args, PyObject* kwargs) {
        if (self is null) {
            PyErr_SetString(PyExc_TypeError, "Wrapped method didn't get a function pointer.");
            return null;
        }

        return exception_catcher(delegate PyObject*() {
            fn_t fn = get_d_reference!fn_t(self);
            return applyFnDelegateToArgs(fn, args);  // DBHERE add kwargs
        });
    }
}


// Wraps a function alias with a PyCFunctionWithKeywords.
template function_wrap(alias real_fn, string fnname) {
    alias Info = Parameters!real_fn;
    enum size_t MAX_ARGS = Info.length;
    alias RT = ReturnType!real_fn;

    extern (C)
    PyObject* func(PyObject* self, PyObject* args, PyObject* kwargs) {
        return exception_catcher(delegate PyObject*() {
            import thread = pyd.thread;
            thread.ensureAttached();
            return applyFnAliasToArgsKwargsAnswerNoneIfVoid!(real_fn,fnname)(args, kwargs);
        });
    }
}



//-----------------------------------------------------------------------------
// And now the reverse operation: wrapping a Python callable with a delegate.
// These rely on a whole collection of nasty templates, but the result is both
// flexible and pretty fast.
// (Sadly, wrapping a Python callable with a regular function is not quite
// possible.)
//-----------------------------------------------------------------------------
// The steps involved when calling this function are as follows:
// 1) An instance of PydWrappedFunc is made, and the callable placed within.
// 2) The delegate type Dg is broken into its constituent parts.
// 3) These parts are used to get the proper overload of PydWrappedFunc.fn
// 4) A delegate to PydWrappedFunc.fn is returned.
// 5) When fn is called, it attempts to cram the arguments into the callable.
//    If Python objects to this, an exception is raised. Note that this means
//    any error in converting the callable to a given delegate can only be
//    detected at runtime.

Dg PydCallable_AsDelegate(Dg) (PyObject* c) {
    return _pycallable_asdgT!(Dg).func(c);
}

private template _pycallable_asdgT(Dg) if(is(Dg == delegate)) {
    alias Parameters!(Dg) Info;
    alias ReturnType!(Dg) Tr;

    Dg func(PyObject* c) {
        static if(isImmutableFunction!Dg) {
            auto f = cast(immutable) new PydWrappedFunc(c);
            return &f.fn_i!(Tr,Info);
        }else static if(isConstFunction!Dg) {
            auto f = new const(PydWrappedFunc)(c);
            return &f.fn_c!(Tr,Info);
        }else{
            auto f = new PydWrappedFunc(c);
            return &f.fn!(Tr,Info);
        }
    }
}

private
class PydWrappedFunc {
    PyObject* callable;

    this(PyObject* c) {
        callable = c;
        Py_INCREF(c);
    }

    ~this() {
        if(callable && !Py_Finalize_called) {
            Py_DECREF(callable);
        }
        callable = null;
    }

    Tr fn(Tr, T ...) (T t) {
        PyObject* ret = call(t);
        if (ret is null) handle_exception();
        scope(exit) Py_DECREF(ret);
        return python_to_d!(Tr)(ret);
    }
    Tr fn_c(Tr, T ...) (T t) const {
        PyObject* ret = call_c(t);
        if (ret is null) handle_exception();
        scope(exit) Py_DECREF(ret);
        return python_to_d!(Tr)(ret);
    }
    Tr fn_i(Tr, T ...) (T t) immutable {
        PyObject* ret = call_i(t);
        if (ret is null) handle_exception();
        scope(exit) Py_DECREF(ret);
        return python_to_d!(Tr)(ret);
    }

    PyObject* call(T ...) (T t) {
        enum size_t ARGS = T.length;
        PyObject* pyt = items_to_PyTuple(t);
        if (pyt is null) return null;
        scope(exit) Py_DECREF(pyt);
        return PyObject_CallObject(callable, pyt);
    }
    PyObject* call_c(T ...) (T t) const {
        enum size_t ARGS = T.length;
        PyObject* pyt = items_to_PyTuple(t);
        if (pyt is null) return null;
        scope(exit) Py_DECREF(pyt);
        return PyObject_CallObject(cast(PyObject*) callable, pyt);
    }
    PyObject* call_i(T ...) (T t) immutable {
        enum size_t ARGS = T.length;
        PyObject* pyt = items_to_PyTuple(t);
        if (pyt is null) return null;
        scope(exit) Py_DECREF(pyt);
        return PyObject_CallObject(cast(PyObject*) callable, pyt);
    }
}



/**
  Get the parameters of function as a string.

  pt_alias refers to an alias of Parameters!fn
  visible to wherever you want to mix in the results.
  pd_alias refers to an alias of ParameterDefaultValueTuple!fn
  visible to wherever you want to mix in the results.
Example:
---
void foo(int i, int j=2) {
}

static assert(getparams!(foo,"P","Pd") == "P[0] i, P[1] j = Pd[1]");
---
  */
template getparams(alias fn, string pt_alias, string pd_alias) {
    alias ParameterIdentifierTuple!fn Pi;
    //https://issues.dlang.org/show_bug.cgi?id=17192
    //alias ParameterDefaultValueTuple!fn Pd;
    import pyd.util.typeinfo : WorkaroundParameterDefaults;
    alias Pd = WorkaroundParameterDefaults!fn;
    enum var = variadicFunctionStyle!fn;

    string inner() {
        static if(var == Variadic.c || var == Variadic.d) {
            return "...";
        }else{
            string ret = "";
            foreach(size_t i, id; Pi) {
                ret ~= format("%s[%s] %s", pt_alias, i, id);
                static if(!is(Pd[i] == void)) {
                    ret ~= format(" = %s[%s]", pd_alias, i);
                }
                static if(i != Pi.length-1) {
                    ret ~= ", ";
                }
            }
            static if(var == Variadic.typesafe) {
                ret ~= "...";
            }
            return ret;
        }
    }

    enum getparams = inner();

}






bool constnessMatch2(fn...)(Constness c) if(fn.length == 1) {
    static if(isImmutableFunction!(fn)) return c == Constness.Immutable;
    static if(isMutableFunction!(fn)) return c == Constness.Mutable;
    static if(isConstFunction!(fn)) return c != Constness.Wildcard;
    else return false;
}





