module bones_vm.pyig._dispatch;


// the imports section is a chance to express something about the overall structure

import std.format : format;
import std.conv : to;
import std.stdio;
import std.exception : enforce;
import std.algorithm: max;
import std.traits : Parameters, ReturnType, ParameterIdentifierTuple, functionAttributes, variadicFunctionStyle,
    Variadic, Unqual, PointerTarget, ParameterTypeTuple,
    isIntegral, isFloatingPoint, isAggregateType, isStaticArray, isAssociativeArray, isPointer, isSomeChar, isCallable,
    isSomeString, isFunctionPointer, isDelegate;
import std.range.primitives : ElementType;

import deimos.python.object : PyObject, Py_INCREF, Py_DECREF, Py_XDECREF, Py_XINCREF, Py_None;
import deimos.python.abstract_ : PyObject_Length, PySequence_GetItem;
import deimos.python.pyerrors : PyErr_SetString, PyExc_TypeError, PyExc_ValueError;
import deimos.python.tupleobject : PyTuple_New, PyTuple_SetItem, PyTuple_GetItem;
import deimos.python.dictobject : PyDict_Keys, PyDict_GetItem, PyDict_New;
import deimos.python.listobject : PyList_Check;
import deimos.python.pyport : Py_ssize_t;
import deimos.python.pythonrun : Py_Initialize;

import pyd.util.dg_wrapper : dg_wrapper;
import pyd.util.replace : Replace;
import pyd.util.typeinfo : constCompatible, constness, WorkaroundParameterDefaults;
import pyd.util.typelist : Join;
import pyd.util.dg_wrapper : dg_wrapper;

import pyd.exception : exception_catcher, handle_exception, PythonException;
import pyd.references : get_d_reference;
import pyd.func_wrap : setWrongArgsError, getparams;
import pyd.conversions.d_to_python : d_to_python;
import pyd.conversions.python_to_d : python_to_d;

import bones_vm.pyig.attributes : signatureWithAttributes, fnHasArgsAttr, fnHasKwargsAttr;
import bones_vm.pyig._dispatch_utils : supportsNArgs, minArgs, maxArgs, gensym;
import bones_vm.pyig.utils : TupleComposer;
import bones_vm.pyig.config : PyiTrace;




// ne pyApplyToAlias
PyObject* callFuncArgsKwargsReturnPyObject(alias fn, string fname) (PyObject* args, PyObject* kwargs) {
    static if (is(ReturnType!fn == void)) {
        callFuncArgsKwargsReturnDType!(fn,fname)( args, kwargs);
        return Py_INCREF(Py_None());
    } else {
        return d_to_python( callFuncArgsKwargsReturnDType!(fn,fname)( args, kwargs) );
    }
}

void checkA(alias VSTYLE, size_t MIN_FN_ARGS, int NUM_PARAMS, int SELF_ARGS, alias fn)(PyObject* args, PyObject* kwargs) {
    static assert(
        VSTYLE == Variadic.no && MIN_FN_ARGS == SELF_ARGS && NUM_PARAMS == SELF_ARGS,
        signatureWithAttributes!(fn)~" is not of form fn(*args)"
    );
    pragma(msg, "form fn(*args)");

    if(!(kwargs is null || PyObject_Length(kwargs) == 0)) {
        PyErr_SetString(PyExc_TypeError, &"no keyword args are allowed"[0]);
        handle_exception();
    }

}




//
//
//// ne applyPyTupleToAlias
//// args includes self, kwargs maybe null
//ReturnType!fn callFuncArgsKwargsReturnDTypeHmmm(alias fn, string fname) (PyObject* args, PyObject* kwargs) {
//    // DBHERE
//    enum bool LOG = true;
//    alias VSTYLE = variadicFunctionStyle!fn;
//    enum size_t MIN_FN_ARGS = minArgs!fn;
//    enum int NUM_PARAMS = Parameters!(fn).length;
//    enum int SELF_ARGS = 2;
//    enum int SELF_KWARGS = 2;
//    enum int SELF_ARGS_KWARGS = 3;
//
//    static if(PyiTrace && LOG) pragma(msg, "terneryfunc!"~fname~" = "~signatureWithAttributes!fn);
//
//    //alias sAttributes = __traits(getAttributes, fn);
//    alias sigHasArgs = fnHasArgsAttr!fn;
//    alias sigHasKwargs = fnHasKwargsAttr!fn;
//
//    // for simplicity in the short term I'll handle 3 signatures
//    // 1) fn(PyObject* args) - sigHasArgs && !sigHasKwargs  -> numDArgs == 1 (i.e. just the *args) check that kwargs is null || len(kwargs) == 0
//    // 2) fn(PyObject* kwargs) - !sigHasArgs && sigHasKwargs -> numDArgs == 1 (i.e. just the **kwargs) check that len(args) == 0
//    // 3) fn(PyObject* args, PyObject* kwargs) - sigHasArgs && sigHasKwargs -> numDArgs == 2
//
//    // so not handling signatures similar to python functions of the form
//    // def joe(a, b, c=2, *args, d, **kwargs): pass  d is a keyword only argument, takes 2+ positional
//    // def joe(a, b, c=2, *args, d=10, **kwargs): pass  d is a keyword only argument, takes 2+ positional
//    // def fred(a, b, c=2, **kwargs): return dict(a=a,b=b,c=c,kwargs=kwargs)
//
//
//    static if (sigHasArgs && !sigHasKwargs){
//
//        checkA!(VSTYLE,MIN_FN_ARGS,NUM_PARAMS,SELF_ARGS,fn)(args,kwargs);
//
//        selfAndArgs
//
//
//
//        static if (__traits(compiles, fn( args))) {
//            //return fn(args);
//        }else {
//            pragma( msg, "Can't compile "~signatureWithAttributes!(fn)~" possibly incorrect args and kwargs?");
//            return fn( args);
//        }
//    //    PyObject* selfArgsTuple = PyTuple_New(2);
//    //
//    //
//    //
//    //// A generic wrapper around a "setter" property.
//    //extern(C)
//    //int func(PyObject* self, PyObject* value, void* closure) {
//    //    PyObject* temp_tuple = PyTuple_New(1);
//    //    if (temp_tuple is null) return -1;
//    //    scope(exit) Py_DECREF(temp_tuple);
//    //    Py_INCREF(value);
//    //    PyTuple_SetItem(temp_tuple, 0, value);
//    //    PyObject* res = method_wrap!(T, Parts.SetterFn, fname).func(self, temp_tuple, null);
//    //    // If we get something back, we need to DECREF it.
//    //    if (res) Py_DECREF(res);
//    //    // If we don't, propagate the exception
//    //    else return -1;
//    //    // Otherwise, all is well.
//    //    return 0;
//    //}
//    //
//    //
//    //    PyTuple_SetItemself = PyTuple_GetSlice
//    //    args = PyTuple_GetSlice
//    //    PyTuple_New
//    //    PyTuple_GET_ITEM
//
//
//        return fn( args);       // if this is a method it is up to receiver to unpack self from the args
//
//    }else static if (!sigHasArgs && sigHasKwargs){
//        static assert(
//            VSTYLE == Variadic.no && MIN_FN_ARGS == SELF_KWARGS && NUM_PARAMS == SELF_KWARGS,
//            signatureWithAttributes!(fn)~"Not of form fn(**kwargs)"
//        );
//        pragma(msg, "form fn(*kwargs)");
//
//        if(!(args is null || PyObject_Length(args) == 0)) {
//            PyErr_SetString(PyExc_TypeError, &"only keyword args are allowed"[0]);
//            handle_exception();
//        }
//        if (kwargs is null) {
//            static if (__traits(compiles, fn(args))) {
//                return fn(PyDict_New());
//            }else {
//                pragma( msg, "Can't compile "~signatureWithAttributes!(fn)~" possibly incorrect args and kwargs?");
//                return fn(PyDict_New());
//            }
//
//            return fn(PyDict_New());
//
//        } else {
//            static if (__traits(compiles, fn(args))) {
//                return fn(kwargs);
//            }else {
//                pragma( msg, "Can't compile "~signatureWithAttributes!(fn)~" possibly incorrect args and kwargs?");
//                return fn(kwargs);
//            }
//
//            return fn(kwargs);
//        }
//
//    }else static if (sigHasArgs && sigHasKwargs){
//        static assert(
//            VSTYLE == Variadic.no && MIN_FN_ARGS == SELF_ARGS_KWARGS && NUM_PARAMS == SELF_ARGS_KWARGS,
//            signatureWithAttributes!(fn)~"Not of form fn(*args, **kwargs)"
//        );
//        pragma(msg, "form fn(*args, **kwargs)");
//
//        if (kwargs is null) {
//            static assert (
//                __traits(compiles, fn( args, PyDict_New())),
//                "Can't compile "~signatureWithAttributes!(fn)~" possibly incorrect args and kwargs?"
//            );
//
//            return fn( args, PyDict_New());
//
//        } else {
//            static assert (
//                __traits(compiles, fn( args, kwargs)),
//                "Can't compile "~signatureWithAttributes!(fn)~" possibly incorrect args and kwargs?"
//            );
//
//            return fn( args, kwargs);
//
//        }
//
//    }else{
//        pragma(msg, "form fn(...)");
//        writeln(PyObject_Length(args));
//        return callFuncArgsKwargsReturnDType2!(fn, fname)(args, kwargs);
//
//    }
//
//}


// can be currently called from 3 places
// 1) when a python type (or D type wrapped in a PyObject) is called, e.g. MyDType() - see ctor_wrap.d,
//     form is fn(args, kwargs) and new instance is returned
// 2) by a member via callFuncArgsKwargsReturnPyObject using the form fn(selfAndArgs, kwargs),
//     e.g. myObj.fred() - see _dispatch.method_wrap
// 3) by a free function, also via callFuncArgsKwargsReturnPyObject, using form fn(args, kwargs),
//     e.g. freeFn(args, kwargs), see func_wrap.function_wrap
//
// current __call__ does not use this but perhaps it should
ReturnType!fn callFuncArgsKwargsReturnDType(alias fn, string fname)(PyObject* args, PyObject* kwargs) {
    enum bool LOG = false;
    alias T = ParameterTypeTuple!fn;
    enum size_t MIN_FN_ARGS = minArgs!fn;
    alias MAX_FN_ARGS = maxArgs!fn;
    alias RT = ReturnType!fn;
    bool argsoverwrote = false;
    enum bool hasUnconditionalReturn = false;

    Py_ssize_t argCount = 0;
    // This can make it more convenient to call this with 0 args.
    if(kwargs !is null && PyObject_Length(kwargs) > 0) {
        args = arrangeNamedArgs!(fn,fname)(args, kwargs);
        Py_ssize_t newlen = PyObject_Length(args);
        argsoverwrote = true;
    }
    scope(exit) if(argsoverwrote) Py_DECREF(args);
    if (args !is null) {
        argCount += PyObject_Length(args);
    }

    // Sanity check!
    if (!supportsNArgs!(fn)(argCount)) {
        setWrongArgsError(cast(int) argCount, MIN_FN_ARGS,
        (MAX_FN_ARGS.hasMax ? MAX_FN_ARGS.max:-1));
        handle_exception();
    }

    static if (MAX_FN_ARGS.vstyle == Variadic.no && MIN_FN_ARGS == 0){
        static if(PyiTrace && LOG) pragma(msg, "--------- MAX_FN_ARGS.vstyle == Variadic.no && MIN_FN_ARGS == 0");

        if (argCount == 0) {
            return fn();
        }

    }

    auto t = new TupleComposer!(MAX_FN_ARGS.ps)();
    foreach(i, arg; t.fields) {
        enum size_t argNum = i+1;
        static if(PyiTrace && LOG) pragma(msg, "--------- argNum"~argNum.stringof);

        static if(MAX_FN_ARGS.vstyle == Variadic.no){
            static if(PyiTrace && LOG) pragma(msg, "--------- MAX_FN_ARGS.vstyle == Variadic.no");

            //https://issues.dlang.org/show_bug.cgi?id=17192
            //alias ParameterDefaultValueTuple!fn Defaults;
            import pyd.util.typeinfo : WorkaroundParameterDefaults;
            alias Defaults = WorkaroundParameterDefaults!fn;
            if (i < argCount) {
                auto bpobj =  PyTuple_GetItem(args, cast(Py_ssize_t) i);
                if(bpobj) {
                    auto pobj = Py_XINCREF(bpobj);
                    t = t.put!i(python_to_d!(typeof(arg))(pobj));
                    Py_DECREF(pobj);
                } else {

                    static if(!is(Defaults[i] == void)){

                        t = t.put!i(Defaults[i]);

                    }else{

                        enforce(0, "python non-keyword arg is NULL!");          // should never happen

                    }

                }
            }

            static if (argNum >= MIN_FN_ARGS && (!MAX_FN_ARGS.hasMax || argNum <= MAX_FN_ARGS.max)){
                static if(PyiTrace && LOG) pragma(msg, "--------- (argNum >= MIN_FN_ARGS && (!MAX_FN_ARGS.hasMax || argNum <= MAX_FN_ARGS.max))");

                if (argNum == argCount) {
                    auto actualArgs = t.fields[0 .. argNum];
                    //writeln("#3");
                    //string s = actualArgs.stringof;
                    //writeln(s);
                    //writeln("#4");
                    return fn(t.fields[0 .. argNum]);
                }

            }
        }else static if(MAX_FN_ARGS.vstyle == Variadic.typesafe){
            static if(PyiTrace && LOG) pragma(msg, "--------- (MAX_FN_ARGS.vstyle == Variadic.typesafe)");
            static if (argNum < t.fields.length){

                auto pobj = Py_XINCREF(PyTuple_GetItem(args, cast(Py_ssize_t) i));
                t = t.put!i(python_to_d!(typeof(arg))(pobj));
                Py_DECREF(pobj);

            }else static if(argNum == t.fields.length){
                static if(PyiTrace) pragma(msg, "--------- (argNum == t.fields.length)");

                alias Unqual!(ElementType!(typeof(t.fields[i]))) elt_t;
                auto varlen = argCount-i;
                if(varlen == 1) {
                    auto  pobj = Py_XINCREF(PyTuple_GetItem(args, cast(Py_ssize_t) i));
                    if(PyList_Check(pobj)) {
                        try{
                            t = t.put!i(cast(typeof(t.fields[i])) python_to_d!(elt_t[])(pobj));
                        }catch(PythonException e) {
                            t = t.put!i(cast(typeof(t.fields[i])) [python_to_d!elt_t(pobj)]);
                        }
                    }else{
                        t = t.put!i(cast(typeof(t.fields[i])) [python_to_d!elt_t(pobj)]);
                    }
                    Py_DECREF(pobj);
                } else {
                    elt_t[] vars = new elt_t[](argCount-i);
                    foreach(j; i .. argCount) {
                        auto  pobj = Py_XINCREF(PyTuple_GetItem(args, cast(Py_ssize_t) j));
                        vars[j-i] = python_to_d!(elt_t)(pobj);
                        Py_DECREF(pobj);
                    }
                    t = t.put!i(cast(typeof(t.fields[i])) vars);
                }
                return fn(t.fields);

            }
        }else static assert(false, "not Variadic.no nor Variadic.typesafe");
    }
    static if(!(maxArgs!fn.vstyle == Variadic.typesafe)) {
        // Won't actually get here but let's keep the compiler quiet
        throw new Exception( "callFuncArgsKwargsReturnDType reached end! argCount = " ~ to!string( argCount));
    }
}


template method_wrap(C, alias fn, string fname) {
    static assert(
        constCompatible(constness!C, constness!(typeof(fn))),
        format("constness mismatch instance: %s function: %s", C.stringof, typeof(fn).stringof)
    );
    alias Info = ParameterTypeTuple!fn;
    enum size_t ARGS = Info.length;
    alias RT = ReturnType!fn;

    extern(C) PyObject* func(PyObject* self, PyObject* args, PyObject* kwargs) {
        return exception_catcher(delegate PyObject*() {

            if (self is null) {
                PyErr_SetString(PyExc_TypeError, "Wrapped method didn't get a 'self' parameter.");
                return null;
            }
            C instance = get_d_reference!C(self);
            if (instance is null) {
                PyErr_SetString(PyExc_ValueError, "Wrapped class instance is null!");
                return null;
            }

            alias sigHasArgs = fnHasArgsAttr!fn;
            alias sigHasKwargs = fnHasKwargsAttr!fn;

            // for simplicity in the short term I'll handle 3 signatures
            // 1) fn(PyObject* args) - sigHasArgs && !sigHasKwargs  -> numDArgs == 1 (i.e. just the *args) check that kwargs is null || len(kwargs) == 0
            // 2) fn(PyObject* kwargs) - !sigHasArgs && sigHasKwargs -> numDArgs == 1 (i.e. just the **kwargs) check that len(args) == 0
            // 3) fn(PyObject* args, PyObject* kwargs) - sigHasArgs && sigHasKwargs -> numDArgs == 2

            // so not handling signatures similar to python functions of the form
            // def joe(a, b, c=2, *args, d, **kwargs): pass  d is a keyword only argument, takes 2+ positional
            // def joe(a, b, c=2, *args, d=10, **kwargs): pass  d is a keyword only argument, takes 2+ positional
            // def fred(a, b, c=2, **kwargs): return dict(a=a,b=b,c=c,kwargs=kwargs)


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
                alias func = memberfunc_to_func!(C, fn).func;
                //static if(PyiTrace) pragma(msg, "bones_vm.pyig._dispatch.method_wrap func - "~signatureWithAttributes!func);
                return callFuncArgsKwargsReturnPyObject!(func, fname)( self_and_args, kwargs);
            }
        });
    }
}


template memberfunc_to_func(T, alias fn) {
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


// ne applyPyTupleToDelegate
PyObject* applyTernaryDelegateReturnPyObject(dg_t) (dg_t dg, PyObject* args) {
    static if (is(ReturnType!(dg_t) == void)) {
        applyDelegateToPyTuple(dg, args);
        return Py_INCREF(Py_None());
    } else {
        return d_to_python( applyDelegateToPyTuple(dg, args) );
    }
}


// ne applyPyTupleToDelegate
ReturnType!(dg_t) applyDelegateToPyTuple(dg_t) (dg_t dg, PyObject* args) {  // DBHERE add kwargs
    alias T = Parameters!(dg_t);
    enum size_t ARGS = T.length;
    alias RT = ReturnType!(dg_t);

    Py_ssize_t argCount = 0;
    if (args !is null) argCount = PyObject_Length(args);  // This can make it more convenient to call this with 0 args.

    // Sanity check!
    if (!supportsNArgs!(dg,dg_t)(argCount)) {
        setWrongArgsError(argCount, ARGS, ARGS);
        handle_exception();
    }

    static if (ARGS == 0) {
        if (argCount == 0) {
            return dg();
        }
    }
    T t;
    foreach(i, arg; t) {
        auto pi = Py_XINCREF(PyTuple_GetItem(args, cast(Py_ssize_t) i));
        t[i] = python_to_d!(typeof(arg))(pi);
        Py_DECREF(pi);
    }
    return dg(t);
}


template method_dgwrap(C, alias fn) {
    alias Info = Parameters!fn;
    enum size_t ARGS = Info.length;
    alias RT = ReturnType!fn;
    extern(C) PyObject* func(PyObject* self, PyObject* args) {
        return exception_catcher(delegate PyObject*() {
            // Didn't pass a "self" parameter! Ack!
            if (self is null) {
                PyErr_SetString(PyExc_TypeError, "Wrapped method didn't get a 'self' parameter.");
                return null;
            }
            C instance = get_d_reference!C(self);
            if (instance is null) {
                PyErr_SetString(PyExc_ValueError, "Wrapped class instance is null!");
                return null;
            }
            auto dg = dg_wrapper!(C, typeof(&fn))(instance, &fn);
            return applyTernaryDelegateReturnPyObject(dg, args);
        });
    }
}


private PyObject* arrangeNamedArgs(alias fn, string fname)(PyObject* args, PyObject* kwargs) {
    alias ParameterIdentifierTuple!fn ids;
    string[] allfnnames = new string[](ids.length);
    size_t[string] allfnnameset;
    foreach(i,id; ids) {
        allfnnames[i] = id;
        allfnnameset[id] = i;
    }
    alias variadicFunctionStyle!fn vstyle;
    size_t firstDefaultValueIndex = ids.length;
    static if(vstyle == Variadic.no) {
        //https://issues.dlang.org/show_bug.cgi?id=17192
        //alias ParameterDefaultValueTuple!fn Defaults;
        import pyd.util.typeinfo : WorkaroundParameterDefaults;
        alias Defaults = WorkaroundParameterDefaults!fn;
        foreach(i, v; Defaults) {
            static if(!is(v == void)) {
                firstDefaultValueIndex = i;
                break;
            }
        }
    }

    Py_ssize_t arglen = PyObject_Length(args);
    enforce(arglen != -1);
    Py_ssize_t kwarglen = PyObject_Length(kwargs);
    enforce(kwarglen != -1);
    // variadic args might give us a count greater than ids.length
    // (but in that case there should be no kwargs)
    auto allargs = PyTuple_New(cast(Py_ssize_t)
    max(ids.length, arglen+kwarglen));

    foreach(i; 0 .. arglen) {
        auto pobj = Py_XINCREF(PyTuple_GetItem(args, cast(Py_ssize_t) i));
        PyTuple_SetItem(allargs, cast(Py_ssize_t) i, pobj);
    }
    PyObject* keys = PyDict_Keys(kwargs);
    enforce(keys);
    for(size_t _n = 0; _n < kwarglen; _n++) {
        PyObject* pkey = PySequence_GetItem(keys, cast(Py_ssize_t) _n);
        auto name = python_to_d!string(pkey);
        if(name !in allfnnameset) {
            enforce(false, format("%s() got an unexpected keyword argument '%s'",fname, name));
        }
        size_t n = allfnnameset[name];
        auto bval = PyDict_GetItem(kwargs, pkey);
        if(bval) {
            auto val = Py_XINCREF(bval);
            PyTuple_SetItem(allargs, cast(Py_ssize_t) n, val);
        }else if(vstyle == Variadic.no && n >= firstDefaultValueIndex) {
            // ok, we can get the default value
        }else{
            enforce(false, format("argument '%s' is NULL! <%s, %s, %s, %s>",
            name, n, firstDefaultValueIndex, ids.length,
            vstyle == Variadic.no));
        }
    }
    Py_DECREF(keys);
    return allargs;
}


