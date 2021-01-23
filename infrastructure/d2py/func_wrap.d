module d2py.func_wrap;

import std.format : format;
import std.conv : to;
import std.exception : enforce;
import std.traits : Parameters, ReturnType, ParameterIdentifierTuple, functionAttributes, variadicFunctionStyle,
    Variadic, Unqual, isIntegral, isFloatingPoint, isAggregateType, isStaticArray, isAssociativeArray, isPointer,
    isSomeChar, isCallable, isSomeString, isFunctionPointer, isDelegate, PointerTarget;

import d2py.python;
import d2py.attributes : signatureWithAttributes;



template method_wrap(C, alias fn, string fname) {
    import pyd.util.typeinfo : constCompatible, constness;
    import pyd.exception : exception_catcher;
    import pyd.references : get_d_reference;
    import pyd.func_wrap : pyApplyToAlias;

    static assert(
        constCompatible(constness!C, constness!(typeof(fn))),
        format("constness mismatch instance: %s function: %s", C.stringof, typeof(fn).stringof)
    );
    alias Info = Parameters!fn ;
    enum size_t ARGS = Info.length;
    alias RT = ReturnType!fn;

    // DBHERE
    pragma(msg, "d2py.func_wrap.method_wrap fn - "~signatureWithAttributes!fn);
    //@(__traits(getAttributes, fn))
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
            alias func = memberfunc_to_func!(C,fn).func;
            return pyApplyToAlias!(func,fname)(self_and_args, kwargs);
        });
    }
}



template memberfunc_to_func(T, alias mf) {
    import pyd.util.typeinfo : WorkaroundParameterDefaults;
    import pyd.func_wrap : getparams;
    import pyd.util.replace : Replace;
    import pyd.util.typelist : Join;
    import pyd.util.dg_wrapper : dg_wrapper;

    alias Ret = ReturnType!mf;
    alias PS = Parameters!mf;
    alias ids = ParameterIdentifierTuple!mf;
    //https://issues.dlang.org/show_bug.cgi?id=17192
    //alias ParameterDefaultValueTuple!mf dfs;
    alias dfs = WorkaroundParameterDefaults!mf;
    enum params = getparams!(mf,"PS","dfs");
    enum t = gensym!ids();

    // DBHERE
    pragma(msg, "d2py.func_wrap.memberfunc_to_func mf - "~signatureWithAttributes!mf);

    mixin(Replace!(
        q{
            // DBHERE
            @(__traits(getAttributes, mf))
            Ret func(T $t, $params) {
                auto dg = dg_wrapper($t, &mf);
                return dg($ids);
            }
        },
        "$params", params,
        "$fn", __traits(identifier, mf),
        "$t", t,
        "$ids", Join!(",",ids)
    ));
}

private string gensym(Taken...)() {
    bool ok(string s) {
        bool _ok = true;
        foreach(t; Taken) {
            if(s == t) _ok = false;
        }
        return _ok;
    }
    foreach(c; 'a' .. 'z'+1) {
        string s = to!string(cast(char)c);
        if (ok(s)) return s;
    }
    // teh heck? wat kind of function takes more than 26 user-typed params?
    int i = 0;
    while(true) {
        string s = format("_%s",i);
        if (ok(s)) return s;
        i++;
    }
}

