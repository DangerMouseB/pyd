module bones_vm.pyig.tp_slots;


import std.algorithm: countUntil;
import std.exception : enforce;
import std.format : format;
import std.conv : to;
import std.stdio : writeln;
import std.meta : Filter;           // allSatisfy, AliasSeq, Filter, staticMap, templateNot;
import std.traits : Parameters, ParameterIdentifierTuple, isPointer, PointerTarget;
import std.typetuple: TypeTuple; //, staticMap, NoDuplicates, staticIndexOf, allSatisfy;

import deimos.python.object : PyObject;
import deimos.python.Python: Py_ssize_t;
import deimos.python.abstract_ : PyObject_Length;
import deimos.python.pyerrors : PyErr_SetString, PyExc_RuntimeError, PyExc_TypeError;

import pyd.def : def_selector, Args;
import pyd.exception : exception_catcher;
import pyd.references : PydTypeObject, get_d_reference, is_wrapped, set_pyd_mapping;
import pyd.util.typeinfo : ApplyConstness, constness, constCompatible, NewParamT;
import pyd.util.dg_wrapper : dg_wrapper;
import pyd.util.replace : Replace;
import pyd.util.typelist : Join;

import pyd.func_wrap : getparams;
import pyd.conversions.d_to_python : d_to_python;
import pyd.conversions.python_to_d : python_to_d;
import pyd.class_wrap : Infer;

import bones_vm.pyig._dispatch_utils : supportsNArgs;
import bones_vm.pyig.adaptors : to_reprfunc, reprfunc, to_richcmpfunc, richcmpfunc, to_PyGetSetDef;
import bones_vm.pyig._dispatch : callFuncArgsKwargsReturnDType;



// ?set_tp_repr
// ne pyd.class_wrap.Repr
struct set_tp_repr(alias _fn) {
    alias fn = def_selector!(_fn, reprfunc).FN;
    enum bool needs_shim = false;
    static void assemble(string classname, T)() {
        //pragma(msg, "set_tp_repr.assemble 1 - ", T.stringof);
        alias cT = ApplyConstness!(T, constness!(typeof(fn)));
        alias type = PydTypeObject!(T);
        //pragma(msg, "set_tp_repr.assemble 2 - ", type.stringof);
        type.tp_repr = &to_reprfunc!(cT, fn).reprfunc;
    }
    template shim(size_t i,T) {
        enum shim = "";
    }
}


// ?set_tp_str
struct set_tp_str(alias _fn) {
    alias fn = def_selector!(_fn, reprfunc).FN;
    enum bool needs_shim = false;
    static void assemble(string classname, T)() {
        alias cT = ApplyConstness!(T, constness!(typeof(fn)));
        alias type = PydTypeObject!(T);
        type.tp_str = &to_reprfunc!(cT, fn).reprfunc;
    }
    template shim(size_t i,T) {
        enum shim = "";
    }
}


// struct types could probably take any parameter type
// class types must take Object
/**
  Wrap opCmp.

Params:
    _rhs_t = (optional) Type of opCmp's parameter for disambiguation if there
    are multiple overloads (for classes it will always be Object).
  */
// ?set_tp_richcompare - ne OpCompare
struct set_tp_richcompare(alias _fn, _rhs_t = Infer) {
    alias fn = def_selector!(_fn, richcmpfunc).FN;
    enum bool needs_shim = false;
    //template Inner(_T) {
    //    pragma(msg, "set_tp_richcompare.Inner - ", fullyQualifiedName!_T, " is ptr ", isPointer!_T);
    //    static if (isPointer!_T) {
    //        alias T = PointerTarget!_T;
    //    }else{
    //        alias T = _T;
    //    }
    //    static if(is(_rhs_t == Infer) && is(T == class)){
    //        alias rhs_t = Object;
    //    }else{
    //        alias rhs_t = _rhs_t;
    //    }
    //    pragma(msg, "--- ", T, ".opCmp(", _rhs_t, ") ---");
    //
    //    //static assert( __traits(hasMember, T, "opCmp"), T.stringof ~ " has no comparison operator overloads");
    //    //static assert( is(typeof(T.init.opCmp) == function), format("%s.opCmp must be a function", T.stringof));
    //
    //    alias Overloads = TypeTuple!(__traits(getOverloads, T, "opCmp"));
    //
    //    static assert(! (is(rhs_t == Infer) && Overloads.length > 1), format("Cannot choose between %s", Overloads));
    //
    //    static if(Overloads.length == 1){
    //        static assert((is(rhs_t == Infer) || is(Parameters!(Overloads[0])[0] == rhs_t)), format("%s.opCmp(...): should expect type %s but signature has %s", T.stringof, rhs_t.stringof, Parameters!(Overloads[0]).stringof));
    //        alias FN = Overloads[0];
    //    }else{
    //        template IsDesiredOverload(alias fn) {
    //            enum bool IsDesiredOverload = is(Parameters!(fn)[0] == rhs_t);
    //        }
    //        alias Overloads1 = Filter!(IsDesiredOverload, Overloads);
    //        static assert(Overloads1.length == 1, format("Cannot choose between %s", Overloads1));
    //        alias FN = Overloads1[0];
    //    }
    //}

    static void assemble(string classname, T)() {
        pragma(msg, "set_tp_richcompare.assemble - ", T.stringof);
        alias type = PydTypeObject!T;
        alias cT = ApplyConstness!(T, constness!(typeof(fn)));      // fn was Inner!T.FN
        type.tp_richcompare = &to_richcmpfunc!(cT, fn).richcmpfunc;
    }
    template shim(size_t i,T) {
        enum shim = "";
    }
}


// ?set_tp_init
struct set_tp_init(string pyname, Ctors...) {
    enum bool needs_shim = true;

    static void assemble(T, ShimT)() {
        alias type = PydTypeObject!T;
        alias U = NewParamT!T;
        static if(Ctors.length) {
            type.tp_init = &wrapped_ctors!(pyname, T, ShimT, Ctors).initproc;
        }else {
            // If a ctor wasn't supplied, try the default.
            // If the default ctor isn't available, and no ctors were supplied,
            // then this class cannot be instantiated from Python.
            // (Structs always use the default ctor.)
            static if (is(typeof(new U))) {
                static if (is(U == class)) {
                    type.tp_init = &wrapped_init!(Shim).initproc;
                } else static if (is(U == struct)) {
                    type.tp_init = &wrapped_struct_init!(U).initproc;
                }
            }
        }
    }
}


// ?set_tp_init
template set_tp_getset(string dname, string pyname, string mode, string docstring, parts...) {
    static const bool needs_shim = false;
    static void assemble(string classname, T) () {
        import std.algorithm : countUntil;
        import bones_vm.pyig.adaptors : to_PyGetSetDef;
        import deimos.python.descrobject : PyGetSetDef;
        import pyd.class_wrap : wrapped_prop_list;
        static PyGetSetDef empty = {null, null, null, null, null};
        alias list = wrapped_prop_list!(T);
        list[$-1].name = (pyname ~ "\0").dup.ptr;
        static if(countUntil(mode, "r") != -1) {
            list[$-1].get = &to_PyGetSetDef!(T, dname, mode, parts).get;
        }
        static if(countUntil(mode, "w") != -1) {
            list[$-1].set = &to_PyGetSetDef!(T, dname, mode, parts).set;
        }
        list[$-1].doc = (docstring~"\0").dup.ptr;
        list[$-1].closure = null;
        list ~= empty;
        alias type = PydTypeObject!(T);
        type.tp_getset = list.ptr;
    }
}


// https://docs.python.org/3/c-api/typeobj.html#c.PyTypeObject.tp_new
// PyObject *tp_new(PyTypeObject *subtype, PyObject *args, PyObject *kwds);

// https://docs.python.org/3/c-api/typeobj.html#c.PyTypeObject.tp_init
// int tp_init(PyObject *self, PyObject *args, PyObject *kwds);

// This template accepts a tuple of function pointer types, which each describe
// a ctor of T, and  uses them to wrap a Python tp_init function.
template wrapped_ctors(string pyname, T, Shim, C ...) {
    static if (isPointer!T) {
        pragma(msg, "tp_slots.wrapped_ctors ", T, ", ", isPointer!T, ", ", PointerTarget!T, ", isStruct", is(PointerTarget!T == struct));
        static if(is(PointerTarget!T == struct)){
            enum valid = true;
        }else{
            enum valid = false;
        }
    }else{
        pragma(msg, "tp_slots.wrapped_ctors ", T, ", isClass", is(T == class));
        static if(is(T == class)){
            enum valid = true;
        }else{
            enum valid = false;
        }
    }
    static if (valid) {
        //alias shim_class T;
        alias wrap_object = wrapped_class_object!(T);
        alias U = NewParamT!T;

        extern(C) static int initproc(PyObject* self, PyObject* args, PyObject* kwargs) {
            pragma(msg, "wrapped_ctors.initproc");
            Py_ssize_t arglen = PyObject_Length( args);
            Py_ssize_t kwlen = kwargs is null?-1:PyObject_Length( kwargs);
            enforce( arglen != -1);
            Py_ssize_t len = arglen + ((kwlen == -1) ? 0 : kwlen);

            return exception_catcher( {
                // Default ctor
                static if (is(typeof(new U))) {
                    if (len == 0) {
                        set_pyd_mapping( self, new U);
                        return 0;
                    }
                }
                // find the first constructor that matches with supportsNArgs
                foreach (i, init; C) {
                    if (supportsNArgs!(init.Inner!T.FN)( len)) {
                        alias initFn = call_ctor!(T, init).func;
                        T t = callFuncArgsKwargsReturnDType!(initFn, pyname)( args, kwargs);
                        if (t is null) {
                            PyErr_SetString( PyExc_RuntimeError, "Class ctor redirect didn't return a class instance!");
                            return -1;
                        }
                        set_pyd_mapping( self, t);
                        return 0;
                    }
                }
                // No ctor found
                PyErr_SetString( PyExc_TypeError, "Unsupported number of constructor arguments.");
                return -1;
            });
        }
    }else{
        static assert(0, "not (is(T == class) || (isPointer!T && is(PointerTarget!T == struct)))");
    }
}


template call_ctor(T, init) {
    alias Parameters!(init.Inner!T.FN) paramtypes;
    alias ParameterIdentifierTuple!(init.Inner!T.FN) paramids;
    //https://issues.dlang.org/show_bug.cgi?id=17192
    //alias ParameterDefaultValueTuple!(init.Inner!T.FN) dfs;
    import pyd.util.typeinfo : WorkaroundParameterDefaults;
    alias dfs = WorkaroundParameterDefaults!(init.Inner!T.FN);
    enum params = getparams!(init.Inner!T.FN, "paramtypes", "dfs");
    mixin(Replace!(q{
    T func($params) {
        return new $T($ids);
    }
    },"$params",params, "$ids", Join!(",",paramids),
    "$T", (is(T == class)?"T":"PointerTarget!T")));
}

// The __init__ slot for wrapped structs.
template wrapped_struct_init(T) if (is(T == struct)){
    extern(C) int initproc(PyObject* self, PyObject* args, PyObject* kwargs) {
        return exception_catcher({
            T* t = new T;
            set_pyd_mapping(self, t);
            return 0;
        });
    }
}

// The default __init__ method calls the class's zero-argument constructor.
template wrapped_init(T) {
    extern(C) int initproc(PyObject* self, PyObject* args, PyObject* kwargs) {
        return exception_catcher({
            set_pyd_mapping(self, new T);
            return 0;
        });
    }
}



/**
Wraps the constructors of the class.

This template takes a single specialization of the ctor template
(see ctor_wrap.d), which describes a constructor that the class
supports. The default constructor need not be
specified, and will always be available if the class supports it.

Supports default arguments, typesafe variadic arguments, and python's
keyword arguments.

Params:
    cps = Parameter list of the constructor to be wrapped.

Bugs:
This currently does not support having multiple constructors with
the same number of arguments.
*/
// ?Init
struct Init(cps ...) {
    alias CtorParams = cps;
    enum bool needs_shim = false;
    template Inner(T) {
        pragma(msg, "Init.Inner ", T);
        alias BaseT = NewParamT!T;
        alias Overloads = TypeTuple!(__traits(getOverloads, BaseT, "__ctor"));
        template IsDesired(alias ctor) {
            alias ps = Parameters!ctor;
            enum bool IsDesired = is(ps == CtorParams);
        }
        alias VOverloads = Filter!(IsDesired, Overloads);
        static if(VOverloads.length == 0) {
            template concatumStrings(s...) {
                static if(s.length == 0) {
                    enum concatumStrings = "";
                }else {
                    enum concatumStrings = T.stringof ~ (Parameters!(s[0])).stringof ~ "\n" ~ concatumStrings!(s[1 .. $]);
                }
            }
            alias allOverloadsString = concatumStrings!(Overloads);
            static assert(false, format("%s: Cannot find constructor with params %s among\n %s", T.stringof, CtorParams.stringof, allOverloadsString));
        }else{
            alias FN = VOverloads[0];
            alias Pt = Parameters!FN;
            //https://issues.dlang.org/show_bug.cgi?id=17192
            //alias ParameterDefaultValueTuple!FN Pd;
            import pyd.util.typeinfo : WorkaroundParameterDefaults;
            alias Pd = WorkaroundParameterDefaults!FN;
        }
    }

    static void assemble(string classname, T)() {}

    template shim(size_t i, T) {
        enum params = getparams!(Inner!T.FN,
            format("__pyd_p%s.Inner!T.Pt",i),
            format("__pyd_p%s.Inner!T.Pd",i)
        );
        alias paramids = ParameterIdentifierTuple!(Inner!T.FN);
        enum shim = Replace!(
            q{
                alias Params[$i] __pyd_p$i;
                this($params) {
                    super($ids);
                }
            },
            "$i", i,
            "$params", params,
            "$ids", Join!(",", paramids)
        );
    }
}



// kill
private template wrapped_class_object(T) {
    alias wrapped_class_object = PyObject;
}

