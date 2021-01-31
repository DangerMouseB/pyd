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


module pyd.class_wrap;

string mod(string fn)() {return "class_wrap."~fn;}


import std.traits;
import std.conv;
import std.functional;
import std.typetuple;
import std.string: format;
import std.algorithm: startsWith, countUntil;
import std.stdio : writeln;

import deimos.python.Python;

import pyd.util.typelist;
import pyd.util.typeinfo : attrs_to_string, ApplyConstness, constness, NewParamT, constCompatible, tattrs_to_string;
import pyd.util.dg_wrapper : dg_wrapper;
import pyd.references : PydTypeObject, is_wrapped, remove_pyd_mapping, get_d_reference;
import pyd.ctor_wrap;
import pyd.def;// : defer_class_wrap;
import pyd.exception : exception_catcher, exception_catcher_nogc;
import pyd.func_wrap;
import pyd.conversions.d_to_python : d_to_python;
import pyd.conversions.python_to_d : python_to_d;
import pyd.op_wrap;

import pyd.util.replace: Replace;

import bones_vm.pyig._dispatch : method_wrap;
import bones_vm.pyig._dispatch_utils : minArgs;
import bones_vm.pyig.config : PyiTrace;
import bones_vm.pyig.attributes : signatureWithAttributes;
import bones_vm.pyig.tp_slots : set_tp_init, set_tp_getset;
import bones_vm.pyig.adaptors : to_unaryfunc, to_richcmpfunc, to_objobjproc, to_binaryfunc, to_ternaryfunc;
import bones_vm.pyig.shim : shim_type;
import bones_vm.pyig.traits : _isInit, _isOp;



version(Pyd_with_StackThreads) static assert(0, "sorry - stackthreads are gone");


// ?wrapped_classes
PyTypeObject*[ClassInfo] wrapped_classes;

template shim_class(T) {
    PyTypeObject* shim_class;
}

// kill
template wrapped_class_object(T) {
    alias wrapped_class_object = PyObject;
}

void init_PyTypeObject(T)(ref PyTypeObject tipo) {
    Py_SET_REFCNT(&tipo, 1);
    tipo.tp_dealloc = &wrapped_methods!(T).wrapped_dealloc;
    tipo.tp_new = &wrapped_methods!(T).wrapped_new;
}

template wrapped_method_list(T) {
    PyMethodDef[] wrapped_method_list = [
        { null, null, 0, null }
    ];
}

template wrapped_prop_list(T) {
    static PyGetSetDef[] wrapped_prop_list = [
        { null, null, null, null, null }
    ];
}



//-///////////////////
// STANDARD METHODS //
//-///////////////////

template wrapped_methods(T) {
    /// The generic "__new__" method
    extern(C) PyObject* wrapped_new(PyTypeObject* type, PyObject* args, PyObject* kwargs) {
        return type.tp_alloc(type, 0);
    }

    // The generic dealloc method.
    extern(C) void wrapped_dealloc(PyObject* self) {
        // EMN: the *&%^^%! generic dealloc method is triggering a call to
        //  *&^%*%(! malloc for that delegate during a @(*$76*&!
        //  garbage collection
        //  Solution: don't use a *&%%^^! delegate in a destructor!
        static struct StackDelegate{
            PyObject* x;
            void dg() {
                remove_pyd_mapping!T(x);
                x.ob_type.tp_free(x);
            }
        }
        StackDelegate x;
        x.x = self;
        exception_catcher_nogc(&x.dg);
    }
}





private template ID(A) { alias ID = A; }
private struct CW(A...) { alias C = A; }


template IsProperty(alias T) {
    enum bool IsProperty = (functionAttributes!(T) & FunctionAttribute.property) != 0;
}


template IsGetter(alias T) {
    enum bool IsGetter = Parameters!T .length == 0 && !is(ReturnType!T == void);
}


template IsSetter(RT) {
    template IsSetter(alias T) {
        enum bool IsSetter = Parameters!T .length == 1 && is(Parameters!(T)[0] == RT);
    }
}


template IsAnySetter(alias T) {
    enum bool IsAnySetter = Parameters!T .length == 1;
}


// This template gets an alias to a property and derives the types of the
// getter form and the setter form. It requires that the getter form return the
// same type that the setter form accepts.
struct property_parts(alias p, string _mode) {

    alias ID!(__traits(parent, p)) Parent;
    enum nom = __traits(identifier, p);
    alias TypeTuple!(__traits(getOverloads, Parent, nom)) Overloads;
    static if(_mode == "" || countUntil(_mode, "r") != -1) {
        alias Filter!(IsGetter,Overloads) Getters;
        static if(_mode == "" && Getters.length == 0) {
            enum isgproperty = false;
            enum rmode = "";
        }else {
            static assert(Getters.length != 0,
                    format!("can't find property %s.%s getter",
                        Parent.stringof, nom));
            static assert(Getters.length == 1,
                    format!("can't handle property overloads of %s.%s getter (types %s)",
                        Parent.stringof, nom, staticMap!(ReturnType,Getters).stringof));
            alias Getters[0] GetterFn;
            alias typeof(&GetterFn) getter_type;
            enum isgproperty = IsProperty!GetterFn;
            enum rmode = "r";
        }
    }else {
        enum isgproperty = false;
        enum rmode = "";
    }
    //enum bool pred1 = _mode == "" || countUntil(_mode, "w") != -1;
    static if(_mode == "" || countUntil(_mode, "w") != -1) {
        static if(rmode == "r") {
            alias Filter!(IsSetter!(ReturnType!getter_type), Overloads) Setters;
        }else {
            alias Filter!(IsAnySetter, Overloads) Setters;
        }

        //enum bool pred2 = _mode == "" && Setters.length == 0;
        static if(_mode == "" && Setters.length == 0) {
            enum bool issproperty = false;
            enum string wmode = "";
        }else{
            static assert(Setters.length != 0, format("can't find property %s.%s setter", Parent.stringof, nom));
            static assert(Setters.length == 1,
                format("can't handle property overloads of %s.%s setter %s",
                    Parent.stringof, nom, Setters.stringof));
            alias Setters[0] SetterFn;
            alias typeof(&SetterFn) setter_type;
            static if(rmode == "r") {
                static assert(!(IsProperty!GetterFn ^ IsProperty!(Setters[0])),
                        format("%s.%s: getter and setter must both be @property or not @property",
                            Parent.stringof, nom));
            }
            enum issproperty = IsProperty!SetterFn;
            enum wmode = "w";
        }
    }else{
        enum issproperty = false;
        enum wmode = "";
    }

    static if(rmode != "") {
        alias ReturnType!(GetterFn) Type;
    }else static if(wmode != "") {
        alias Parameters!(SetterFn)[0] Type;
    }

    enum mode = rmode ~ wmode;
    enum bool isproperty = isgproperty || issproperty;
}


template wrapped_get(string fname, T, Parts) {
    // A generic wrapper around a "getter" property.
    extern(C) PyObject* func(PyObject* self, void* closure) {
        // method_wrap already catches exceptions
        return method_wrap!(T, Parts.GetterFn, fname).func(self, null, null);
    }
}


template wrapped_set(string fname, T, Parts) {
    // A generic wrapper around a "setter" property.
    extern(C) int func(PyObject* self, PyObject* value, void* closure) {
        PyObject* temp_tuple = PyTuple_New(1);
        if (temp_tuple is null) return -1;
        scope(exit) Py_DECREF(temp_tuple);
        Py_INCREF(value);
        PyTuple_SetItem(temp_tuple, 0, value);
        PyObject* res = method_wrap!(T, Parts.SetterFn, fname).func(self, temp_tuple, null);
        // If we get something back, we need to DECREF it.
        if (res) Py_DECREF(res);
        // If we don't, propagate the exception
        else return -1;
        // Otherwise, all is well.
        return 0;
    }
}



//-///////////////////////////
// CLASS WRAPPING INTERFACE //
//-///////////////////////////

//enum ParamType { Def, StaticDef, Property, Init, Parent, Hide, Iter, AltIter }
struct DoNothing {
    static void assemble(string classname, T) () {}
}

/**
Wraps a member function of the class.

Supports default arguments, typesafe variadic arguments, and python's
keyword arguments.

Params:
fn = The member function to wrap.
Options = Optional parameters. Takes Docstring!(docstring), PyName!(pyname),
and fn_t.
fn_t: The type of the function. It is only useful to specify this
       if more than one function has the same name as this one.
pyname: The name of the function as it will appear in Python. Defaults to
fn's name in D
docstring: The function's docstring. Defaults to "".
*/

struct Def(alias fn, Options...) {
    alias args = Args!("","", __traits(identifier,fn), "",Options);
    static if(args.rem.length) {
        alias fn_t = args.rem[0];
    }else {
        alias fn_t = typeof(&fn);
    }
    mixin _Def!(fn, args.pyname, fn_t, args.docstring);
}
private template _Def(alias _fn, string name, fn_t, string docstring) {
    alias func = def_selector!(_fn,fn_t).FN;
    static assert(!__traits(isStaticFunction, func)); // TODO
    static assert(
        0 == (functionAttributes!fn_t & (FunctionAttribute.nothrow_ | FunctionAttribute.pure_ | FunctionAttribute.trusted | FunctionAttribute.safe)),
        "pyd currently does not support pure, nothrow, @trusted, or @safe member functions"
    );
    alias /*StripSafeTrusted!*/func_t = fn_t;
    enum realname = __traits(identifier,func);
    enum funcname = name;
    enum min_args = minArgs!(func);
    enum bool needs_shim = false;

    static void assemble(string classname, T) () {
        alias cT = ApplyConstness!(T, constness!(typeof(func)));
        static PyMethodDef empty = { null, null, 0, null };
        alias list = wrapped_method_list!(T);
        list[$-1].ml_name = (name ~ "\0").ptr;
        list[$-1].ml_meth = cast(PyCFunction) &method_wrap!(cT, func, classname ~ "." ~ name).func;
        list[$-1].ml_flags = METH_VARARGS | METH_KEYWORDS;
        list[$-1].ml_doc = (docstring~"\0").ptr;
        list ~= empty;
        // It's possible that appending the empty item invalidated the
        // pointer in the type struct, so we renew it here.
        PydTypeObject!(T).tp_methods = list.ptr;
    }
    template shim(size_t i, T) {
        enum shim = Replace!(q{
            alias Params[$i] __pyd_p$i;
            $override ReturnType!(__pyd_p$i.func_t) $realname(ParameterTypeTuple!(__pyd_p$i.func_t) t) $attrs {
                return __pyd_get_overload!("$realname", __pyd_p$i.func_t).func!(ParameterTypeTuple!(__pyd_p$i.func_t))("$name", t);
            }
            alias T.$realname $realname;
        }, "$i",i,"$realname",realname, "$name", name,
        "$attrs", attrs_to_string(functionAttributes!func_t) ~ " " ~ tattrs_to_string!(func_t)(),
        "$override",
        // todo: figure out what's going on here
        (variadicFunctionStyle!func == Variadic.no ? "override":""));
    }
}



/**
Wraps a static member function of the class. Similar to pyd.def.def

Supports default arguments, typesafe variadic arguments, and python's
keyword arguments.

Params:
fn = The member function to wrap.
Options = Optional parameters. Takes Docstring!(docstring), PyName!(pyname),
and fn_t
fn_t: The type of the function. It is only useful to specify this
       if more than one function has the same name as this one.
pyname: The name of the function as it will appear in Python. Defaults to fn's
name in D.
docstring: The function's docstring. Defaults to "".
*/
struct StaticDef(alias fn, Options...) {
    alias Args!("","", __traits(identifier,fn), "",Options) args;
    static if(args.rem.length) {
        alias args.rem[0] fn_t;
    }else {
        alias typeof(&fn) fn_t;
    }
    mixin _StaticDef!(fn, args.pyname, fn_t, args.docstring);
}


mixin template _StaticDef(alias fn, string name, fn_t, string docstring) {
    alias def_selector!(fn,fn_t).FN func;
    static assert(__traits(isStaticFunction, func)); // TODO
    alias /*StripSafeTrusted!*/fn_t func_t;
    enum funcname = name;
    enum bool needs_shim = false;
    static void assemble(string classname, T) () {
        //pragma(msg, "class.static_def: " ~ name);
        static PyMethodDef empty = { null, null, 0, null };
        alias wrapped_method_list!(T) list;
        list[$-1].ml_name = (name ~ "\0").ptr;
        list[$-1].ml_meth = cast(PyCFunction) &function_wrap!(func, classname ~ "." ~ name).func;
        list[$-1].ml_flags = METH_VARARGS | METH_STATIC | METH_KEYWORDS;
        list[$-1].ml_doc = (docstring~"\0").ptr;
        list ~= empty;
        PydTypeObject!(T).tp_methods = list.ptr;
    }
    template shim(size_t i,T) {
        enum shim = "";
    }
}


/**
Wraps a property of the class.

Params:
fn = The property to wrap.
Options = Optional parameters. Takes Docstring!(docstring), PyName!(pyname),
and Mode!(mode)
pyname: The name of the property as it will appear in Python. Defaults to
fn's name in D.
mode: specifies whether this property is readable, writable. possible values
are "r", "w", "rw", and "" (in the latter case, automatically determine which
mode to use based on availability of getter and setter forms of fn). Defaults
to "".
docstring: The function's docstring. Defaults to "".
*/
struct Property(alias fn, Options...) {
    alias args = Args!("","", __traits(identifier,fn), "",Options);
    static assert(args.rem.length == 0, "Propery takes no other parameter");
    mixin _Property!(fn, args.pyname, args.mode, args.docstring);
}


template _Property(alias fn, string pyname, string _mode, string docstring) {
    alias parts = property_parts!(fn, _mode);

    static if(parts.isproperty) {
        mixin set_tp_getset!(parts.nom, pyname, parts.mode, docstring, parts);

        template shim(size_t i, T) {
            enum shim = "";
        }
    }else {
        static if(countUntil(parts.mode,"r") != -1) {
            alias parts.getter_type get_t;
        }
        static if(countUntil(parts.mode,"w") != -1) {
            alias parts.setter_type set_t;
        }
        enum realname = __traits(identifier, fn);
        enum funcname = pyname;
        enum bool needs_shim = false;
        static void assemble(string classname, T) () {
            static PyGetSetDef empty = { null, null, null, null, null };
            wrapped_prop_list!(T)[$-1].name = (pyname ~ "\0").dup.ptr;
            static if (countUntil(parts.mode, "r") != -1) {
                alias cT_g = ApplyConstness!(T, constness!(typeof(parts.GetterFn)));
                wrapped_prop_list!(T)[$-1].get =
                    &wrapped_get!(classname ~ "." ~ pyname, cT_g, parts).func;
            }
            static if (countUntil(parts.mode, "w") != -1) {
                alias cT_s = ApplyConstness!(T, constness!(typeof(parts.SetterFn)));
                wrapped_prop_list!(T)[$-1].set =
                    &wrapped_set!(classname ~ "." ~ pyname,cT_s, parts).func;
            }
            wrapped_prop_list!(T)[$-1].doc = (docstring~"\0").dup.ptr;
            wrapped_prop_list!(T)[$-1].closure = null;
            wrapped_prop_list!(T) ~= empty;
            // It's possible that appending the empty item invalidated the
            // pointer in the type struct, so we renew it here.
            PydTypeObject!(T).tp_getset =
                wrapped_prop_list!(T).ptr;
        }
        template shim(size_t i, T) {
            static if(countUntil(parts.mode, "r") != -1) {
                enum getter = Replace!(q{
                override ReturnType!(__pyd_p$i.get_t) $realname() {
                    return __pyd_get_overload!("$realname", __pyd_p$i.get_t).func("$name");
                }
                } , "$i",i,"$realname",realname, "$name", pyname);
            }else{
                enum getter = "";
            }
            static if(countUntil(parts.mode, "w") != -1) {
                enum setter = Replace!(q{
                override ReturnType!(__pyd_p$i.set_t) $realname(Parameters!(__pyd_p$i.set_t) t) {
                    return __pyd_get_overload!("$realname", __pyd_p$i.set_t).func("$name", t);
                }
                }, "$i", i, "$realname",realname, "$name", pyname);
            }else {
                enum setter = "";
            }
            enum shim = Replace!(q{
                alias Params[$i] __pyd_p$i;
                $getter
                $setter;
            }, "$i",i, "$getter", getter, "$setter",setter);
        }
    }
}


enum unaryslots = [
    "+": "type.tp_as_number.nb_positive",
    "-": "type.tp_as_number.nb_negative",
    "~": "type.tp_as_number.nb_invert",
];


bool IsPyUnary(string op) {
    foreach(_op, slot; unaryslots) {
        if(op == _op) return true;
    }
    return false;
}


// string mixin to initialize tp_as_number or tp_as_sequence or tp_as_mapping
// if necessary. Scope mixed in must have these variables:
//  slot: a value from binaryslots or unaryslots
//  type: a PyObjectType.
string autoInitializeMethods() {
    return q{
        static if(countUntil(slot, "tp_as_number") != -1) {
            if(type.tp_as_number is null)
                type.tp_as_number = new PyNumberMethods;
        }else static if(countUntil(slot, "tp_as_sequence") != -1) {
            if(type.tp_as_sequence is null)
                type.tp_as_sequence = new PySequenceMethods;
        }else static if(countUntil(slot, "tp_as_mapping") != -1) {
            if(type.tp_as_mapping is null)
                type.tp_as_mapping = new PyMappingMethods;
        }
    };
}

struct Infer{}

// ?BinaryOperatorX
struct BinaryOperatorX(string _op, bool isR, rhs_t) {

    pragma(msg, "class_wrap.BinaryOperatorX", rhs_t.stringof~"."~(_op));

    enum op = _op;
    enum isRight = isR;
    static if(isR) {enum nom = "opBinaryRight";} else {enum nom = "opBinary";}
    enum bool needs_shim = false;

    template Inner(_T) {
        pragma(msg, "BinaryOperatorX.Inner - ", fullyQualifiedName!_T, ", op: ", op, " is ptr ", isPointer!_T);
        static if (isPointer!_T) {
            alias T = PointerTarget!_T;
        }else{
            alias T = _T;
        }
        pragma(msg, "--- ", T, ".", nom, "(", _op, ")(", rhs_t, ") ---");
        static assert(__traits(hasMember, T, nom), T.stringof ~ " has no "~(isR ?"reflected ":"")~ "binary operator overloads");

        enum fn_str1 = "Alias!(T."~nom~"!(op))";
        enum fn_str2 = "T."~nom~"!(op,rhs_t)";
        enum string OP = op;

        template Alias(alias fn) {
            alias Alias = fn;
        }

        //pragma(msg, typeof(mixin(fn_str1)).stringof);
        static if(is(typeof(mixin(fn_str1)) == function)) {
            static if(_op == "/") {
                pragma(msg, "getted here 1");
                pragma(msg, T.stringof);
            }
            alias RHS_T = Parameters!(typeof(mixin(fn_str1)))[0];
            alias RET_T = ReturnType!(typeof(mixin(fn_str1)));
            mixin("alias FN = " ~ fn_str1 ~ ";");
            static if(!is(rhs_t == Infer)){
                static assert(is(RHS_T == rhs_t), format( "expected typeof(rhs) = %s, found %s", rhs.stringof, RHS_T.stringof));
            }
        }else static if(is(rhs_t == Infer)) {
            static assert(0, format("Operator %s: could not determine type of rhs", op));
        } else static if(is(typeof(mixin(fn_str2)) == function)) {
            alias RHS_T = rhs_t;
            alias RET_T = ReturnType!(typeof(mixin(fn_str2)));
            mixin("alias "~fn_str2~" FN;");
        } else static assert(0, "Cannot get operator overload");
    }

    static void assemble(string classname, T)() {
        // can't handle __op__ __rop__ pairs here
    }

    template shim(size_t i, T) {
        enum shim = "";
    }
}





/**
  Wrap an operator assignment overload.

Example:
---
class Foo{
    int _j;
    void opOpAssign(string op)(int i) if(op == "+"){
        _j = i;
    }
}

class_wrap!(Foo,
    OpAssign!("+"));
---
Params:
    _op = Base operator to wrap
    rhs_t = (optional) Type of opOpAssign's parameter for disambiguation if
    there are multiple overloads.
*/
struct OpAssign(string _op, rhs_t = Infer) if(IsPyAsg(_op)) {
    enum op = _op~"=";

    enum bool needs_shim = false;

    template Inner(T) {
        enum string OP = op;
        static if(!__traits(hasMember, T, "opOpAssign")) {
            static assert(0, T.stringof ~ " has no operator assignment overloads");
        }
        static if(is(typeof(T.init.opOpAssign!(_op)) == function)) {
            alias Parameters!(typeof(T.opOpAssign!(_op)))[0] RHS_T;
            alias ReturnType!(typeof(T.opOpAssign!(_op))) RET_T;
            alias T.opOpAssign!(_op) FN;
            static if(!is(rhs_t == Infer))
                static assert(is(RHS_T == rhs_t),
                        format("expected typeof(rhs) = %s, found %s",
                            rhs.stringof, RHS_T.stringof));
        }else static if(is(rhs_t == Infer)) {
            static assert(false, "Cannot determine type of rhs");
        } else static if(is(typeof(T.opOpAssign!(_op,rhs_t)) == function)) {
            alias rhs_t RHS_T;
            alias ReturnType!(typeof(T.opOpAssign!(_op,rhs_t))) RET_T;
            alias T.opOpAssign!(_op,rhs_t) FN;
        } else static assert(false, "Cannot get operator assignment overload");
    }
    static void assemble(string classname, T)() {
        alias type = PydTypeObject!T;
        enum slot = getBinarySlot(op);
        mixin(autoInitializeMethods());
        alias OpAsg = CW!(TypeTuple!(OpAssign));
        alias Nop = CW!(TypeTuple!());
        static if(op == "^^=")
            mixin(slot ~ " = &powopasg_wrap!(T, Inner!T.FN).func;");
        else
            mixin(slot ~ " = &binopasg_wrap!(T, Inner!T.FN).func;");
    }

    template shim(size_t i,T) {
        enum shim = "";
    }
}



/**
  Wrap opIndex, opIndexAssign.

Params:
    index_t = (optional) Types of opIndex's parameters for disambiguation if
    there are multiple overloads.
*/
struct OpIndex(index_t...) {
    enum bool needs_shim = false;
    template Inner(T) {

        static if(!__traits(hasMember, T, "opIndex")) {
            static assert(0, T.stringof ~ " has no index operator overloads");
        }
        static if(is(typeof(T.init.opIndex) == function)) {
            alias TypeTuple!(__traits(getOverloads, T, "opIndex")) Overloads;
            static if(index_t.length == 0 && Overloads.length > 1) {
                static assert(0,
                        format("%s.opIndex: Cannot choose between %s",
                            T.stringof,Overloads.stringof));
            }else static if(index_t.length == 0) {
                alias Overloads[0] FN;
            }else{
                template IsDesiredOverload(alias fn) {
                    enum bool IsDesiredOverload = is(Parameters!fn == index_t);
                }
                alias Filter!(IsDesiredOverload, Overloads) Overloads1;
                static assert(Overloads1.length == 1,
                        format("%s.opIndex: Cannot choose between %s",
                            T.stringof,Overloads1.stringof));
                alias Overloads1[0] FN;
            }
        }else static if(is(typeof(T.init.opIndex!(index_t)) == function)) {
            alias T.opIndex!(index_t) FN;
        }else{
            static assert(0,
                    format("cannot get a handle on %s.opIndex", T.stringof));
        }
    }
    static void assemble(string classname, T)() {
        /*
        alias PydTypeObject!T type;
        enum slot = "type.tp_as_mapping.mp_subscript";
        mixin(autoInitializeMethods());
        mixin(slot ~ " = &opindex_wrap!(T, Inner!T.FN).func;");
        */
    }
    template shim(size_t i,T) {
        enum shim = "";
    }
}

/// ditto
struct OpIndexAssign(index_t...) {
    static assert(index_t.length != 1,
            "opIndexAssign must have at least 2 parameters");
    enum bool needs_shim = false;
    template Inner(T) {
        static assert(__traits(hasMember, T, "opIndexAssign"), T.stringof ~ " has no index operator overloads");
        static if(is(typeof(T.init.opIndex) == function)) {
            alias Overloads = TypeTuple!(__traits(getOverloads, T, "opIndexAssign"));
            template IsValidOverload(alias fn) {
                enum bool IsValidOverload = Parameters!fn.length >= 2;
            }
            alias VOverloads = Filter!(IsValidOverload, Overloads);
            static assert(
                VOverloads.length != 0 || Overloads.length == 0,
                "opIndexAssign must have at least 2 parameters"
            );
            static if(index_t.length == 0 && VOverloads.length > 1) {
                static assert(0,
                        format("%s.opIndexAssign: Cannot choose between %s",
                            T.stringof,VOverloads.stringof));
            }else static if(index_t.length == 0) {
                alias FN = VOverloads[0];
            }else{
                template IsDesiredOverload(alias fn) {
                    enum bool IsDesiredOverload = is(Parameters!fn == index_t);
                }
                alias Overloads1 = Filter!(IsDesiredOverload, VOverloads);
                static assert(Overloads1.length == 1,
                        format("%s.opIndex: Cannot choose between %s",
                            T.stringof,Overloads1.stringof));
                alias FN = Overloads1[0];
            }
        }else static if(is(typeof(T.init.opIndexAssign!(index_t)) == function)) {
            alias T.opIndexAssign!(index_t) FN;
        }else{
            static assert(0,
                    format("cannot get a handle on %s.opIndexAssign", T.stringof));
        }
    }
    static void assemble(string classname, T)() {
        /*
        alias PydTypeObject!T type;
        enum slot = "type.tp_as_mapping.mp_ass_subscript";
        mixin(autoInitializeMethods());
        mixin(slot ~ " = &opindexassign_wrap!(T, Inner!T.FN).func;");
        */
    }
    template shim(size_t i,T) {
        enum shim = "";
    }
}

/**
  Wrap opSlice.

  Requires signature
---
Foo.opSlice(Py_ssize_t, Py_ssize_t);
---
 This is a limitation of the C/Python API.
  */
struct OpSlice() {
    enum bool needs_shim = false;
    template Inner(T) {

        static if(!__traits(hasMember, T, "opSlice")) {
            static assert(0, T.stringof ~ " has no slice operator overloads");
        }
        static if(is(typeof(T.init.opSlice) == function)) {
            alias TypeTuple!(__traits(getOverloads, T, "opSlice")) Overloads;
            template IsDesiredOverload(alias fn) {
                enum bool IsDesiredOverload = is(Parameters!fn ==
                        TypeTuple!(Py_ssize_t,Py_ssize_t));
            }
            alias Filter!(IsDesiredOverload, Overloads) Overloads1;
            static assert(Overloads1.length != 0,
                    format("%s.opSlice: must have overload %s",
                        T.stringof,TypeTuple!(Py_ssize_t,Py_ssize_t).stringof));
            static assert(Overloads1.length == 1,
                    format("%s.opSlice: cannot choose between %s",
                        T.stringof,Overloads1.stringof));
            alias Overloads1[0] FN;
        }else{
            static assert(0, format("cannot get a handle on %s.opSlice",
                        T.stringof));
        }
    }
    static void assemble(string classname, T)() {
        /*
        alias PydTypeObject!T type;
        enum slot = "type.tp_as_sequence.sq_slice";
        mixin(autoInitializeMethods());
        mixin(slot ~ " = &opslice_wrap!(T, Inner!T.FN).func;");
        */
    }
    template shim(size_t i,T) {
        enum shim = "";
    }
}

/**
  Wrap opSliceAssign.

  Requires signature
---
Foo.opSliceAssign(Value,Py_ssize_t, Py_ssize_t);
---
 This is a limitation of the C/Python API.
  */
struct OpSliceAssign(rhs_t = Infer) {
    enum bool needs_shim = false;
    template Inner(T) {
        static if(!__traits(hasMember, T, "opSliceAssign")) {
            static assert(0, T.stringof ~ " has no slice assignment operator overloads");
        }
        static if(is(typeof(T.init.opSliceAssign) == function)) {
            alias TypeTuple!(__traits(getOverloads, T, "opSliceAssign")) Overloads;
            template IsDesiredOverload(alias fn) {
                alias Parameters!fn ps;
                enum bool IsDesiredOverload =
                    is(ps[1..3] == TypeTuple!(Py_ssize_t,Py_ssize_t));
            }
            alias Filter!(IsDesiredOverload, Overloads) Overloads1;
            static assert(Overloads1.length != 0,
                    format("%s.opSliceAssign: must have overload %s",
                        T.stringof,TypeTuple!(Infer,Py_ssize_t,Py_ssize_t).stringof));
            static if(is(rhs_t == Infer)) {
                static assert(Overloads1.length == 1,
                        format("%s.opSliceAssign: cannot choose between %s",
                            T.stringof,Overloads1.stringof));
                alias Overloads1[0] FN;
            }else{
                template IsDesiredOverload2(alias fn) {
                    alias Parameters!fn ps;
                    enum bool IsDesiredOverload2 = is(ps[0] == rhs_t);
                }
                alias Filter!(IsDesiredOverload2, Overloads1) Overloads2;
                static assert(Overloads2.length == 1,
                        format("%s.opSliceAssign: cannot choose between %s",
                            T.stringof,Overloads2.stringof));
                alias Overloads2[0] FN;
            }
        }else{
            static assert(0, format("cannot get a handle on %s.opSlice",
                        T.stringof));
        }
    }
    static void assemble(string classname, T)() {
        /*
        alias PydTypeObject!T type;
        enum slot = "type.tp_as_sequence.sq_ass_slice";
        mixin(autoInitializeMethods());
        mixin(slot ~ " = &opsliceassign_wrap!(T, Inner!T.FN).func;");
        */
    }
    template shim(size_t i,T) {
        enum shim = "";
    }
}

/**
  wrap opCall. The parameter types of opCall must be specified.
*/
// ?OpCall
struct OpCall(Args_t...) {
    enum bool needs_shim = false;

    //static if(PyiTrace) pragma(msg, "pyd.class_wrap.OpCall #1");


    template Inner(T) {

        alias Overloads = TypeTuple!(__traits(getOverloads, T, "opCall"));
        template IsDesiredOverload(alias fn) {
            alias ps = Parameters!fn;
            enum bool IsDesiredOverload = is(ps == Args_t);
        }
        alias VOverloads = Filter!(IsDesiredOverload, Overloads);
        static if(VOverloads.length == 0) {
            static assert(0,
                    format("%s.opCall: cannot find signature %s", T.stringof,
                        Args_t.stringof));
        }else static if(VOverloads.length == 1){
            alias FN = VOverloads[0];
        }else static assert(0,
                format("%s.%s: cannot choose between %s", T.stringof, nom,
                    VOverloads.stringof));
    }
    static void assemble(string classname, T)() {
        alias type = PydTypeObject!T;
        alias fn = Inner!T.FN;
        alias cT = ApplyConstness!(T, constness!(typeof(fn)));

        // DBHERE
        alias f = opcall_wrap!(cT, fn, classname);
        //static if(PyiTrace) pragma(msg, "pyd.class_wrap.OpCall.assemble #2  fn - "~signatureWithAttributes!fn);
        type.tp_call = &f.func;
        //static if(PyiTrace) pragma(msg, "pyd.class_wrap.OpCall.assemble #3  f - "~signatureWithAttributes!f);
    }
    template shim(size_t i,T) {
        enum shim = "";
    }
}


/**
  Wraps Foo.length or another function as python's __len__ function.

  Requires signature
---
Py_ssize_t length();
---
  This is a limitation of the C/Python API.
  */
// ?Len
template Len() {
    alias Len = _Len!();
}

/// ditto
template Len(alias fn) {
    alias _Len!(fn) Len;
}


struct _Len(fnt...) {
    enum bool needs_shim = false;
    template Inner(T) {

        static if(fnt.length == 0) {
            enum nom = "length";
        }else{
            enum nom = __traits(identifier, fnt[0]);
        }
        alias TypeTuple!(__traits(getOverloads, T, nom)) Overloads;
        template IsDesiredOverload(alias fn) {
            alias Parameters!fn ps;
            alias ReturnType!fn rt;
            enum bool IsDesiredOverload = isImplicitlyConvertible!(rt,Py_ssize_t) && ps.length == 0;
        }
        alias Filter!(IsDesiredOverload, Overloads) VOverloads;
        static if(VOverloads.length == 0 && Overloads.length != 0) {
            static assert(0, format("%s.%s must have signature %s", T.stringof, nom, (Py_ssize_t function()).stringof));
        }else static if(VOverloads.length == 1){
            alias VOverloads[0] FN;
        }else static assert(0, format("%s.%s: cannot choose between %s", T.stringof, nom, VOverloads.stringof));
    }
    static void assemble(string classname, T)() {
        alias PydTypeObject!T type;
        enum slot = "type.tp_as_sequence.sq_length";
        mixin(autoInitializeMethods());
        mixin(slot ~ " = &length_wrap!(T, Inner!T.FN).func;");
    }
    template shim(size_t i,T) {
        enum shim = "";
    }
}


template param1(C) {
    template param1(T) {
        alias param1 = Parameters!(T.Inner!C .FN)[0];
    }
}


template IsUn(A) {
    enum IsUn = A.stringof.startsWith("OpUnary!");
}


template IsBin(T...) {
    static if(T[0].stringof.startsWith("BinaryOperatorX!"))
        enum bool IsBin = !T[0].isRight;
    else
        enum bool IsBin = false;
}


template IsBinR(T...) {
    static if(T[0].stringof.startsWith("BinaryOperatorX!"))
        enum IsBinR = T[0].isRight;
    else
        enum IsBinR = false;
}


template IsDef(string pyname) {
    template IsDef(Params...) {
        static if(Params[0].stringof.startsWith("Def!") && __traits(hasMember,Params[0], "funcname")) {
            enum bool IsDef = (Params[0].funcname == pyname);
        }else{
            enum bool IsDef = false;
        }
    }
}


struct Iterator(Params...) {
    alias Filter!(IsDef!"__iter__", Params) Iters;
    alias Filter!(IsDef!"next", Params) Nexts;
    enum bool needs_shim = false;
    static void assemble(T)() {
        alias PydTypeObject!T type;
        import std.range;
        static if(Iters.length == 1 && (Nexts.length == 1 || isInputRange!(ReturnType!(Iters[0].func)))) {
            version(Python_3_0_Or_Later) {
            }else{
                type.tp_flags |= Py_TPFLAGS_HAVE_ITER;
            }
            type.tp_iter = &opiter_wrap!(T, Iters[0].func).func;
            static if(Nexts.length == 1)
                type.tp_iternext = &opiter_wrap!(T, Nexts[0].func).func;
        }
    }
}


template IsOpIndex(P...) {
    enum bool IsOpIndex = P[0].stringof.startsWith("OpIndex!");
}
template IsOpIndexAssign(P...) {
    enum bool IsOpIndexAssign = P[0].stringof.startsWith("OpIndexAssign!");
}
template IsOpSlice(P...) {
    enum bool IsOpSlice = P[0].stringof.startsWith("OpSlice!");
}
template IsOpSliceAssign(P...) {
    enum bool IsOpSliceAssign = P[0].stringof.startsWith("OpSliceAssign!");
}
template IsLen(P...) {
    enum bool IsLen = P[0].stringof.startsWith("Len!");
}



template assemble_type(_T, string pyname, string docstring, string modulename, Params...) {

    static if (is(_T == class)) {
        alias shim_class = shim_type!(_T, Params);
        alias T = _T;
    }else static if (is(_T == struct)){
        alias shim_class = void;
        alias T = _T*;
    }else {
        static assert(0, "assemble_type - unhandled type");
    }

    void _build() {
        if(!Pyd_Module_p(modulename)) {
            if(should_defer_class_wrap(modulename, pyname)) {
                defer_class_wrap(modulename, pyname,  toDelegate(&_build));
                return;
            }
        }

        //assert(Pyd_Module_p(modulename) !is null, "Must initialize module '" ~ modulename ~ "' before wrapping classes.");
        //string module_name = to!string(PyModule_GetName(Pyd_Module_p(modulename)));

        pragma(msg, "\n--------------------------------------------------------------------");

        static if (is(_T == class)) {
            pragma(msg, "class proxy - ", fullyQualifiedName!_T, " => ", pyname);
        } else {
            pragma(msg, "struct proxy - ", fullyQualifiedName!_T, " => ", pyname);
        }
        pragma(msg, "--------------------------------------------------------------------");


        alias type = PydTypeObject!(T);
        init_PyTypeObject!T(type);

        foreach (param; Params) {
            static if (param.needs_shim) {
                param.assemble!(pyname, T, shim_class)();
            } else {
                param.assemble!(pyname,T)();
            }
        }

        assert(Pyd_Module_p(modulename) !is null, "Must initialize module '" ~ modulename ~ "' before wrapping classes.");
        string module_name = to!string(PyModule_GetName(Pyd_Module_p(modulename)));


        Py_SET_TYPE(&type, &PyType_Type);
        type.tp_basicsize = PyObject.sizeof;
        type.tp_doc = (docstring ~ "\0").ptr;
        version(Python_3_0_Or_Later) {
            type.tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE;
        }else{
            type.tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_CHECKTYPES;
        }
        type.tp_methods = wrapped_method_list!(T).ptr;
        type.tp_name = (module_name ~ "." ~ pyname ~ "\0").ptr;


        // Inherit classes from their wrapped superclass.
        static if (is(T B == super)) {
            foreach (C; B) {
                static if (is(C == class) && !is(C == Object)) {
                    if (is_wrapped!(C)) {
                        type.tp_base = &PydTypeObject!(C);
                    }
                }
            }
        }

        assemble_operators!(Filter!(_isOp, Params)).assemble!T();
        assembleIndexSliceMerge!(Params).assemble!T();            // indexing and slicing aren't exactly simple.

        set_tp_init!(pyname, Filter!(_isInit, Params)).assemble!(T, shim_class)();
        Iterator!(Params).assemble!(T)();

        // Finalisation
        if (PyType_Ready(&type) < 0) {throw new Exception("Couldn't ready wrapped type!");}
        Py_INCREF(cast(PyObject*) &type);
        PyModule_AddObject(Pyd_Module_p(modulename), (pyname~"\0").ptr, cast(PyObject*)&type);

        is_wrapped!(T) = true;
        static if (is(T == class)) {
            is_wrapped!(shim_class) = true;
            wrapped_classes[T.classinfo] = &type;
            wrapped_classes[shim_class.classinfo] = &type;
        }

        pragma(msg, "--------------------------------------------------------------------\n");
    }
}


// ?assemble_operators
// handle all operator overloads. Ops must only contain operator overloads.
private struct assemble_operators(Ops...) {
    enum bool needs_shim = false;
    //pragma(msg, "--- ","Operators"," ---  ", Ops.stringof);
    template BinOp(string op, T) {
        enum IsThisOp(A) = A.op == op;
        alias Ops0 = Filter!(IsThisOp, Ops);
        alias OpsL = Filter!(IsBin, Ops0);
        alias OpsLparams = staticMap!(param1!T, OpsL);
        pragma(msg, "--- ","assemble_operators.BinOp"," ---  ", op, ", ", T);
        static assert(OpsL.length <= 1, Replace!("Cannot overload $T1 $OP x with types $T2", "$OP", op, "$T1", T.stringof, "$T2",  OpsLparams.stringof));
        alias OpsR = Filter!(IsBinR, Ops0);
        alias OpsRparams = staticMap!(param1, OpsR);
        static assert(OpsR.length <= 1, Replace!("Cannot overload x $OP $T1 with types $T2", "$OP", op, "$T1", T.stringof, "$T2",  OpsRparams.stringof));
        static assert(op[$-1] != '=' || OpsR.length == 0, "Cannot reflect assignment operator" );
        static void assemble() {
            static if(OpsL.length + OpsR.length != 0) {
                alias type = PydTypeObject!T;
                enum slot = getBinarySlot(op);
                mixin(autoInitializeMethods());
                static if(op == "in"){
                    mixin(slot ~ " = &to_objobjproc!(T, CW!OpsR).objobjproc;");  // objobjproc
                    //mixin(slot ~ " = &to_objobjproc!(T, CW!OpsL, CW!OpsR).objobjproc;");  // objobjproc
                }else static if(op == "^^" || op == "^^="){
                    mixin(slot ~ " = &to_ternaryfunc!(T, CW!OpsL, CW!OpsR).ternaryfunc;");          // ternaryfunc
                }else{
                    mixin(slot ~ " = &to_binaryfunc!(T, CW!OpsL, CW!OpsR).binaryfunc;");  // binaryfunc
                }
            }
        }

    }
    struct UnOp(string op, T) {
        enum IsThisOp(A) = A.op == op;
        alias Ops1 = Filter!(IsUn, Filter!(IsThisOp, Ops));
        static assert(
        Ops1.length <= 1,
        Replace!("Cannot have overloads of $OP$T1", "$OP", op, "$T1", T.stringof)
        );
        static void assemble() {
            static if(Ops1.length != 0) {
                alias type = PydTypeObject!T;
                alias Ops1_0 = Ops1[0];
                alias fn = Ops1_0.Inner!T .FN;
                enum slot = unaryslots[op];
                mixin(autoInitializeMethods());
                mixin(slot ~ " = &to_unaryfunc!(T, fn);");
            }
        }
    }

    static void assemble(T)() {
        enum GetOp(A) = A.op;
        alias str_op_tuple = NoDuplicates!(staticMap!(GetOp, Ops));
        enum binops = binaryslots.keys();
        foreach(_op; str_op_tuple) {
            BinOp!(_op, T).assemble(); // noop if op is unary
            UnOp!(_op, T).assemble(); // noop if op is binary
        }
    }
}


enum binaryslots = [
    "+": "type.tp_as_number.nb_add",
    "+=": "type.tp_as_number.nb_inplace_add",
    "-": "type.tp_as_number.nb_subtract",
    "-=": "type.tp_as_number.nb_inplace_subtract",
    "*": "type.tp_as_number.nb_multiply",
    "*=": "type.tp_as_number.nb_inplace_multiply",
    "/": "type.tp_as_number.nb_divide",
    "/=": "type.tp_as_number.nb_inplace_divide",
    "%": "type.tp_as_number.nb_remainder",
    "%=": "type.tp_as_number.nb_inplace_remainder",
    "^^": "type.tp_as_number.nb_power",
    "^^=": "type.tp_as_number.nb_inplace_power",
    "<<": "type.tp_as_number.nb_lshift",
    "<<=": "type.tp_as_number.nb_inplace_lshift",
    ">>": "type.tp_as_number.nb_rshift",
    ">>=": "type.tp_as_number.nb_inplace_rshift",
    "&": "type.tp_as_number.nb_and",
    "&=": "type.tp_as_number.nb_inplace_and",
    "^": "type.tp_as_number.nb_xor",
    "^=": "type.tp_as_number.nb_inplace_xor",
    "|": "type.tp_as_number.nb_or",
    "|=": "type.tp_as_number.nb_inplace_or",
    "~": "type.tp_as_sequence.sq_concat",
    "~=": "type.tp_as_sequence.sq_inplace_concat",
    "in": "type.tp_as_sequence.sq_contains",
];


string getBinarySlot(string op) {
    version(Python_3_0_Or_Later) {
        if (op == "/") return "type.tp_as_number.nb_true_divide";
        if (op == "/=") return "type.tp_as_number.nb_inplace_true_divide";
    }
    return binaryslots[op];
}


bool IsPyBinary(string op) {
    foreach(_op, slot; binaryslots) {
        if (op[$-1] != '=' && op == _op) return true;
    }
    return false;
}


bool IsPyAsg(string op0) {
    auto op = op0~"=";
    foreach(_op, slot; binaryslots) {
        if (op == _op) return true;
    }
    return false;
}

/*
   Extended slice syntax goes through mp_subscript, mp_ass_subscript,
   not sq_slice, sq_ass_slice.

TODO: Python's extended slicing is more powerful than D's. We should expose
this.
*/
private struct assembleIndexSliceMerge(Params...) {
    alias OpIndexs = Filter!(IsOpIndex, Params);
    alias OpIndexAssigns = Filter!(IsOpIndexAssign, Params);
    alias OpSlices = Filter!(IsOpSlice, Params);
    alias OpSliceAssigns = Filter!(IsOpSliceAssign, Params);
    alias Lens = Filter!(IsLen, Params);

    static assert(OpIndexs.length <= 1);
    static assert(OpIndexAssigns.length <= 1);
    static assert(OpSlices.length <= 1);
    static assert(OpSliceAssigns.length <= 1);

    static void assemble(T)() {
        alias type = PydTypeObject!T;
        static if(OpIndexs.length + OpSlices.length) {
            {
                enum slot = "type.tp_as_mapping.mp_subscript";
                mixin(autoInitializeMethods());
                mixin(slot ~ " = &op_func!(T);");
            }
        }
        static if(OpIndexAssigns.length + OpSliceAssigns.length) {
            {
                enum slot = "type.tp_as_mapping.mp_ass_subscript";
                mixin(autoInitializeMethods());
                mixin(slot ~ " = &ass_func!(T);");
            }
        }
    }


    static extern(C) PyObject* op_func(T)(PyObject* self, PyObject* key) {

        static if(OpIndexs.length) {
            version(Python_2_5_Or_Later) {
                Py_ssize_t i;
                if(!PyIndex_Check(key)) goto slice;
                i = PyNumber_AsSsize_t(key, PyExc_IndexError);
            }else{
                C_long i;
                if(!PyInt_Check(key)) goto slice;
                i = PyLong_AsLong(key);
            }
            if(i == -1 && PyErr_Occurred()) {
                return null;
            }
            alias OpIndex0 = OpIndexs[0];
            return opindex_wrap!(T, OpIndex0.Inner!T.FN).func(self, key);
        }
        slice:
        static if(OpSlices.length) {
            if(PySlice_Check(key)) {
                Py_ssize_t len = PyObject_Length(self);
                Py_ssize_t start, stop, step, slicelength;
                if(PySlice_GetIndicesEx(key, len,
                &start, &stop, &step, &slicelength) < 0) {
                    return null;
                }
                if(step != 1) {
                    PyErr_SetString(PyExc_TypeError,
                    "slice steps not supported in D");
                    return null;
                }
                alias OpSlice0 = OpSlices[0];
                return opslice_wrap!(T, OpSlice0.Inner!T.FN).func(
                self, start, stop);
            }
        }
        PyErr_SetString(PyExc_TypeError, format(
        "index type '%s' not supported\0", to!string(key.ob_type.tp_name)).ptr);
        return null;
    }

    static extern(C) int ass_func(T)(PyObject* self, PyObject* key,
    PyObject* val) {

        static if(OpIndexAssigns.length) {
            version(Python_2_5_Or_Later) {
                Py_ssize_t i;
                if(!PyIndex_Check(key)) goto slice;
                i = PyNumber_AsSsize_t(key, PyExc_IndexError);
            }else{
                C_long i;
                if(!PyInt_Check(key)) goto slice;
                i = PyLong_AsLong(key);
            }
            if(i == -1 && PyErr_Occurred()) {
                return -1;
            }
            alias OpIndexAssign0 = OpIndexAssigns[0];
            return opindexassign_wrap!(T, OpIndexAssign0.Inner!T.FN).func(
            self, key, val);
        }
        slice:
        static if(OpSliceAssigns.length) {
            if(PySlice_Check(key)) {
                Py_ssize_t len = PyObject_Length(self);
                Py_ssize_t start, stop, step, slicelength;
                if(PySlice_GetIndicesEx(key, len,
                &start, &stop, &step, &slicelength) < 0) {
                    return -1;
                }
                if(step != 1) {
                    PyErr_SetString(PyExc_TypeError,
                    "slice steps not supported in D");
                    return -1;
                }
                alias OpSliceAssign0 = OpSliceAssigns[0];
                return opsliceassign_wrap!(T, OpSliceAssign0.Inner!T.FN).func(
                self, start, stop, val);
            }
        }
        PyErr_SetString(PyExc_TypeError, format(
        "assign index type '%s' not supported\0", to!string(key.ob_type.tp_name)).ptr);
        return -1;
    }
}
