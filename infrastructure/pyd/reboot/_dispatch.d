module pyd.reboot._dispatch;


// the imports section is a chance to express something about the overall structure

import std.format : format;
import std.conv : to;
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
import deimos.python.dictobject : PyDict_Keys, PyDict_GetItem;
import deimos.python.listobject : PyList_Check;
import deimos.python.pyport : Py_ssize_t;
import deimos.python.pythonrun : Py_Initialize;

import pyd.util.typeinfo : constCompatible, constness;
import pyd.util.dg_wrapper : dg_wrapper;
import pyd.util.typeinfo : WorkaroundParameterDefaults;
import pyd.exception : exception_catcher, handle_exception, PythonException;
import pyd.references : get_d_reference;
import pyd.func_wrap : setWrongArgsError;
import pyd.make_object : d_to_python, python_to_d;

import pyd.reboot.attributes : signatureWithAttributes;
import pyd.reboot._dispatch_utils : supportsNArgs, minArgs, maxArgs;
import pyd.reboot.utils : TupleComposer;
import pyd.reboot.common : RebootFullTrace;



// ne pyApplyToAlias
PyObject* applyFnAliasToArgsKwargsAnswerNoneIfVoid(alias fn, string fname) (PyObject* args, PyObject* kwargs) {
    static if (is(ReturnType!fn == void)) {
        applyFnAliasToArgsKwargs!(fn,fname)(args, kwargs);
        return Py_INCREF(Py_None());
    } else {
        // DBHERE
        static if(RebootFullTrace) pragma(msg, "pyd.reboot.func_wrap.applyFnAliasToArgsKwargsAnswerNoneIfVoid fn - "~signatureWithAttributes!fn);
        return d_to_python( applyFnAliasToArgsKwargs!(fn,fname)(args, kwargs) );
    }
}

// Calls callable alias fn with PyTuple args.
// kwargs may be null, args may not
//ReturnType!fn applyFnAliasToArgsKwargs(alias fn, string fname)(PyObject* args, PyObject* kwargs) {
//    alias Parameters!fn T;
//    enum size_t MIN_ARGS = minArgs!fn;
//    alias maxArgs!fn MaxArgs;
//    alias ReturnType!fn RT;
//
//    bool argsoverwrote = false;
//    scope(exit) if(argsoverwrote) Py_DECREF(args);
//
//    // DBHERE
//    import pyd.reboot.attributes : signatureWithAttributes, hasArgs, hasKwargs;
//    pragma(msg, signatureWithAttributes!fn);
//
//    //alias sAttributes = __traits(getAttributes, fn);
//    alias sHasStar = hasArgs!fn;
//    alias sHasStarStar = hasKwargs!fn;
//
//    // for simplicity in the short term I'll handle 3 cases
//    // 1) sHasStar && !sHasStarStar  -> numDArgs == 1 (i.e. just the *args) check that kwargs is null || len(kwargs) == 0
//    // 2) !sHasStar && sHasStarStar -> numDArgs == 1 (i.e. just the **kwargs) check that len(args) == 0
//    // 3) sHasStar && sHasStarStar -> numDArgs == 2
//
//    // so not handling signatures like
//    // def joe(a, b, c=2, *args, d, **kwargs): pass  d is a keyword only argument, takes 2+ positional
//    // def fred(a, b, c=2, **kwargs): return dict(a=a,b=b,c=c,kwargs=kwargs)
//
//    static if (false) {
//        //static if (sHasStar && !sHasStarStar) {
//        //    if(!(kwargs is null || PyObject_Length(kwargs) == 0)) {
//        //        PyErr_SetString(PyExc_TypeError, &"* is defined and kwargs have been passed"[0]);
//        //        handle_exception();
//        //    }
//        //    return fn(args);
//        //}
//        //else static if (!sHasStar && sHasStarStar) {
//        //    if(!(args is null || PyObject_Length(args) == 0)) {
//        //        PyErr_SetString(PyExc_TypeError, &"** is defined and args have been passed"[0]);
//        //        handle_exception();
//        //    }
//        //    if (kwargs is null) {
//        //        import deimos.python.dictobject : PyDict_New;
//        //        return fn(PyDict_New());
//        //    } else {
//        //        return fn(kwargs);
//        //    }
//        //}
//        //else static if (sHasStar && sHasStarStar) {
//        //    if(!(args is null || PyObject_Length(args) == 0)) {
//        //        PyErr_SetString(PyExc_TypeError, &"** is defined and args have been passed"[0]);
//        //        handle_exception();
//        //    }
//        //    if (kwargs is null) {
//        //        import deimos.python.dictobject : PyDict_New;
//        //        return fn(args, PyDict_New());
//        //    } else {
//        //        return fn(args, kwargs);
//        //    }
//    } else {
//
//
//        // else use the current code - SHOULDDO rewite to incorporate the presence of *args and **kwargs
//
//        Py_ssize_t argCount = 0;
//        // This can make it more convenient to call this with 0 args.
//        if(kwargs !is null && PyObject_Length(kwargs) > 0) {
//            args = arrangeNamedArgs!(fn,fname)(args, kwargs);
//            Py_ssize_t newlen = PyObject_Length( args);
//            argsoverwrote = true;
//        }
//
//        if (args !is null) {
//            argCount += PyObject_Length(args);
//        }
//
//        // Sanity check!
//        if (!supportsNArgs!(fn)(argCount)) {
//            setWrongArgsError(cast(int) argCount, MIN_ARGS, (MaxArgs.hasMax ? MaxArgs.max:-1));
//            handle_exception();
//        }
//
//        static if (MaxArgs.vstyle == Variadic.no && MIN_ARGS == 0) {
//            if (argCount == 0) {
//                return fn();
//            }
//        }
//        auto t = new TupleComposer!(MaxArgs.ps)();
//        foreach(i, arg; t.fields) {
//            enum size_t argNum = i+1;
//            static if (MaxArgs.vstyle == Variadic.no) {
//                //https://issues.dlang.org/show_bug.cgi?id=17192
//                //alias ParameterDefaultValueTuple!fn Defaults;
//                import pyd.util.typeinfo : WorkaroundParameterDefaults;
//                alias Defaults = WorkaroundParameterDefaults!fn;
//                if (i < argCount) {
//                    auto bpobj =  PyTuple_GetItem(args, cast(Py_ssize_t) i);
//                    if(bpobj) {
//                        auto pobj = Py_XINCREF(bpobj);
//                        t = t.put!i(python_to_d!(typeof(arg))(pobj));
//                        Py_DECREF(pobj);
//                    }else{
//                        static if(!is(Defaults[i] == void)) {
//                            t = t.put!i(Defaults[i]);
//                        }else{
//                            // should never happen
//                            enforce(0, "python non-keyword arg is NULL!");
//                        }
//                    }
//                }
//                static if (argNum >= MIN_ARGS &&
//                (!MaxArgs.hasMax || argNum <= MaxArgs.max)) {
//                    if (argNum == argCount) {
//                        return fn(t.fields[0 .. argNum]);
//                    }
//                }
//            } else static if(MaxArgs.vstyle == Variadic.typesafe) {
//                static if (argNum < t.fields.length) {
//                    auto pobj = Py_XINCREF(PyTuple_GetItem(args, cast(Py_ssize_t) i));
//                    t = t.put!i(python_to_d!(typeof(arg))(pobj));
//                    Py_DECREF(pobj);
//                } else static if(argNum == t.fields.length) {
//                    alias Unqual!(ElementType!(typeof(t.fields[i]))) elt_t;
//                    auto varlen = argCount-i;
//                    if(varlen == 1) {
//                        auto  pobj = Py_XINCREF(PyTuple_GetItem(args, cast(Py_ssize_t) i));
//                        if(PyList_Check(pobj)) {
//                            try{
//                                t = t.put!i(cast(typeof(t.fields[i])) python_to_d!(elt_t[])(pobj));
//                            }catch(PythonException e) {
//                                t = t.put!i(cast(typeof(t.fields[i])) [python_to_d!elt_t(pobj)]);
//                            }
//                        }else{
//                            t = t.put!i(cast(typeof(t.fields[i])) [python_to_d!elt_t(pobj)]);
//                        }
//                        Py_DECREF(pobj);
//                    }else{
//                        elt_t[] vars = new elt_t[](argCount-i);
//                        foreach(j; i .. argCount) {
//                            auto  pobj = Py_XINCREF(PyTuple_GetItem(args, cast(Py_ssize_t) j));
//                            vars[j-i] = python_to_d!(elt_t)(pobj);
//                            Py_DECREF(pobj);
//                        }
//                        t = t.put!i(cast(typeof(t.fields[i])) vars);
//                    }
//                    return fn(t.fields);
//                }
//            }else static assert(0);
//        }
//        // This should never get here.
//        //throw new Exception("applyFnAliasToArgsKwargs reached end! argCount = " ~ to!string(argCount));
//    }
//}


// ne applyPyTupleToAlias
// kwargs may be null, args may not
ReturnType!fn applyFnAliasToArgsKwargs(alias fn, string fname)(PyObject* args, PyObject* kwargs) {
    alias T = ParameterTypeTuple!fn;
    enum size_t MIN_ARGS = minArgs!fn;
    alias MaxArgs = maxArgs!fn;
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
        setWrongArgsError(cast(int) argCount, MIN_ARGS,
        (MaxArgs.hasMax ? MaxArgs.max:-1));
        handle_exception();
    }

    static if (MaxArgs.vstyle == Variadic.no && MIN_ARGS == 0){
        pragma(msg, "--------- MaxArgs.vstyle == Variadic.no && MIN_ARGS == 0");

        if (argCount == 0) {
            return fn();
        }

    }

    auto t = new TupleComposer!(MaxArgs.ps)();
    foreach(i, arg; t.fields) {
        enum size_t argNum = i+1;
        static if(RebootFullTrace) pragma(msg, "--------- argNum"~argNum.stringof);

        static if(MaxArgs.vstyle == Variadic.no){
            static if(RebootFullTrace) pragma(msg, "--------- MaxArgs.vstyle == Variadic.no");

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

            static if (argNum >= MIN_ARGS && (!MaxArgs.hasMax || argNum <= MaxArgs.max)){
                static if(RebootFullTrace) pragma(msg, "--------- (argNum >= MIN_ARGS && (!MaxArgs.hasMax || argNum <= MaxArgs.max))");

                if (argNum == argCount) {
                    return fn(t.fields[0 .. argNum]);
                }

            }
        }else static if(MaxArgs.vstyle == Variadic.typesafe){
            static if(RebootFullTrace) pragma(msg, "--------- (MaxArgs.vstyle == Variadic.typesafe)");
            static if (argNum < t.fields.length){

                auto pobj = Py_XINCREF(PyTuple_GetItem(args, cast(Py_ssize_t) i));
                t = t.put!i(python_to_d!(typeof(arg))(pobj));
                Py_DECREF(pobj);

            }else static if(argNum == t.fields.length){
                static if(RebootFullTrace) pragma(msg, "--------- (argNum == t.fields.length)");

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
        }
    }
    static if(!(maxArgs!fn.vstyle == Variadic.typesafe)) {
        // Won't actually get here bt let's keep the compiler quiet
        throw new Exception( "applyFnAliasToArgsKwargs reached end! argCount = " ~ to!string( argCount));
    }
}





template method_wrap(C, alias real_fn, string fname) {
    static assert(
        constCompatible(constness!C, constness!(typeof(real_fn))),
        format("constness mismatch instance: %s function: %s", C.stringof, typeof(real_fn).stringof)
    );
    alias Info = ParameterTypeTuple!real_fn;
    enum size_t ARGS = Info.length;
    alias RT = ReturnType!real_fn;

    // DBHERE
    static if(RebootFullTrace) pragma(msg, "pyd.reboot.func_wrap.method_wrap real_fn - "~signatureWithAttributes!real_fn);
    //@(__traits(getAttributes, real_fn))
    extern(C)
    PyObject* func(PyObject* self, PyObject* args, PyObject* kwargs) {
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

            Py_ssize_t arglen = args is null ? 0 : PyObject_Length(args);
            enforce(arglen != -1);
            PyObject* self_and_args = PyTuple_New(cast(Py_ssize_t) arglen+1);
            scope(exit) {
                Py_XDECREF(self_and_args);
            }
            enforce(self_and_args);
            PyTuple_SetItem(self_and_args, 0, self);
            Py_INCREF(self);
            foreach(i; 0 .. arglen) {
                auto pobj = Py_XINCREF(PyTuple_GetItem(args, cast(Py_ssize_t) i));
                PyTuple_SetItem(self_and_args, cast(Py_ssize_t) i+1, pobj);
            }
            alias func = memberfunc_to_func!(C,real_fn).func;
            return applyFnAliasToArgsKwargsAnswerNoneIfVoid!(func,fname)(self_and_args, kwargs);
        });
    }
}



template memberfunc_to_func(T, alias memfn) {
    import pyd.util.typeinfo : WorkaroundParameterDefaults;
    import pyd.func_wrap : getparams;
    import pyd.util.replace : Replace;
    import pyd.util.typelist : Join;
    import pyd.util.dg_wrapper : dg_wrapper;
    import pyd.reboot._dispatch_utils : gensym;

    // DBHERE
    static if(RebootFullTrace) pragma(msg, "pyd.reboot.func_wrap.memberfunc_to_func mf - "~signatureWithAttributes!memfn);

    alias Ret = ReturnType!memfn;
    alias PS = ParameterTypeTuple!memfn;
    alias ids = ParameterIdentifierTuple!memfn;
    //alias dfs = ParameterDefaultValueTuple!memfn;      //https://issues.dlang.org/show_bug.cgi?id=17192
    alias dfs = WorkaroundParameterDefaults!memfn;
    enum params = getparams!(memfn,"PS","dfs");
    enum t = gensym!ids();

    mixin(Replace!(
        q{
            Ret func(T $t, $params) {
                auto dg = dg_wrapper($t, &memfn);
                return dg($ids);
            }
        },
        "$params", params,
        "$fn", __traits(identifier, memfn),
        "$t",t,
        "$ids",Join!(",",ids)
    ));
}

//template memberfunc_to_func(T, alias memfn) {
//    alias ReturnType!memfn Ret;
//    alias ParameterTypeTuple!memfn PS;
//    alias ParameterIdentifierTuple!memfn ids;
//    //https://issues.dlang.org/show_bug.cgi?id=17192
//    //alias ParameterDefaultValueTuple!memfn dfs;
//    import pyd.util.typeinfo : WorkaroundParameterDefaults;
//    alias dfs = WorkaroundParameterDefaults!memfn;
//    enum params = getparams!(memfn,"PS","dfs");
//    enum t = gensym!ids();
//
//    mixin(Replace!(q{
//        Ret func(T $t, $params) {
//            auto dg = dg_wrapper($t, &memfn);
//            return dg($ids);
//        }
//    }, "$params", params, "$fn", __traits(identifier, memfn), "$t",t,
//    "$ids",Join!(",",ids)));
//
//}



PyObject* applyFnDelegateToArgs(dg_t) (dg_t dg, PyObject* args) {
    static if (is(ReturnType!(dg_t) == void)) {
        pragma(msg, "pyd.funcwrap.applyFnDelegateToArgs (void)");
        applyDelegateToPyTuple(dg, args);
        return Py_INCREF(Py_None());
    } else {
        pragma(msg, "pyd.funcwrap.applyFnDelegateToArgs");
        return d_to_python( applyDelegateToPyTuple(dg, args) );
    }
}

//// wraps applyPyTupleToDelegate to return a PyObject*
//PyObject* pyApplyToDelegate(dg_t) (dg_t dg, PyObject* args) {
//    static if (is(ReturnType!(dg_t) == void)) {
//        applyPyTupleToDelegate(dg, args);
//        return Py_INCREF(Py_None());
//    } else {
//        return d_to_python( applyPyTupleToDelegate(dg, args) );
//    }
//}


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

//ReturnType!(dg_t) applyPyTupleToDelegate(dg_t) (dg_t dg, PyObject* args) {
//    alias ParameterTypeTuple!(dg_t) T;
//    enum size_t ARGS = T.length;
//    alias ReturnType!(dg_t) RT;
//
//    Py_ssize_t argCount = 0;
//    // This can make it more convenient to call this with 0 args.
//    if (args !is null) {
//        argCount = PyObject_Length(args);
//    }
//
//    // Sanity check!
//    if (!supportsNArgs!(dg,dg_t)(argCount)) {
//        setWrongArgsError(argCount, ARGS, ARGS);
//        handle_exception();
//    }
//
//    static if (ARGS == 0) {
//        if (argCount == 0) {
//            return dg();
//        }
//    }
//    T t;
//    foreach(i, arg; t) {
//        auto pi = Py_XINCREF(PyTuple_GetItem(args, cast(Py_ssize_t) i));
//        t[i] = python_to_d!(typeof(arg))(pi);
//        Py_DECREF(pi);
//    }
//    return dg(t);
//}



template method_dgwrap(C, alias fn) {
    alias Info = Parameters!fn;
    enum size_t ARGS = Info.length;
    alias RT = ReturnType!fn;
    extern(C)
    PyObject* func(PyObject* self, PyObject* args) {
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
            return applyFnDelegateToArgs(dg, args);  // DBHERE add kwargs
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


//
//
//
//
//PyObject* tp_call(PyObject* self, PyObject* args, PyObject* kwargs) {return null};
//PyNumberMethods.nb_add
//
//
//
//PyObject* nb_add(PyObject* self, PyObject* other) PyNumberMethods.nb_add
//
//binaryfunc PyNumberMethods.nb_subtract
//binaryfunc PyNumberMethods.nb_multiply
//binaryfunc PyNumberMethods.nb_remainder
//binaryfunc PyNumberMethods.nb_divmod
//ternaryfunc PyNumberMethods.nb_power
//unaryfunc PyNumberMethods.nb_negative
//unaryfunc PyNumberMethods.nb_positive
//unaryfunc PyNumberMethods.nb_absolute
//inquiry PyNumberMethods.nb_bool
//unaryfunc PyNumberMethods.nb_invert
//binaryfunc PyNumberMethods.nb_lshift
//binaryfunc PyNumberMethods.nb_rshift
//binaryfunc PyNumberMethods.nb_and
//binaryfunc PyNumberMethods.nb_xor
//binaryfunc PyNumberMethods.nb_or
//unaryfunc PyNumberMethods.nb_int
//void *PyNumberMethods.nb_reserved
//unaryfunc PyNumberMethods.nb_float
//binaryfunc PyNumberMethods.nb_inplace_add
//binaryfunc PyNumberMethods.nb_inplace_subtract
//binaryfunc PyNumberMethods.nb_inplace_multiply
//binaryfunc PyNumberMethods.nb_inplace_remainder
//ternaryfunc PyNumberMethods.nb_inplace_power
//binaryfunc PyNumberMethods.nb_inplace_lshift
//binaryfunc PyNumberMethods.nb_inplace_rshift
//binaryfunc PyNumberMethods.nb_inplace_and
//binaryfunc PyNumberMethods.nb_inplace_xor
//binaryfunc PyNumberMethods.nb_inplace_or
//binaryfunc PyNumberMethods.nb_floor_divide
//binaryfunc PyNumberMethods.nb_true_divide
//binaryfunc PyNumberMethods.nb_inplace_floor_divide
//binaryfunc PyNumberMethods.nb_inplace_true_divide
//unaryfunc PyNumberMethods.nb_index
//binaryfunc PyNumberMethods.nb_matrix_multiply
//binaryfunc PyNumberMethods.nb_inplace_matrix_multiply
//
//PyObject *(*unaryfunc)(PyObject *)
//PyObject *(*binaryfunc)(PyObject *, PyObject *)
//PyObject *(*ternaryfunc)(PyObject *, PyObject *, PyObject *)
//PyObject *(*ssizeargfunc)(PyObject *, Py_ssize_t)
//
//
//nb_power            __pow__ __rpow__
//nb_inplace_power   __pow__
//