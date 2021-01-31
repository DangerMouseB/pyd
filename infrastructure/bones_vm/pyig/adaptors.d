module bones_vm.pyig.adaptors;

//import std.meta : allSatisfy, AliasSeq, Filter, staticMap, templateNot;
import std.format : format;
import std.conv : to;
import std.algorithm : startsWith, endsWith, countUntil;
import std.stdio : writeln;
import std.exception : enforce;
//import std.meta : Filter;
import std.traits : Parameters, ReturnType, FunctionTypeOf, isPointer; //, ParameterIdentifierTuple;
//import std.typetuple: TypeTuple; //, staticMap, NoDuplicates, staticIndexOf, allSatisfy;

import deimos.python.object : PyObject, Py_INCREF, Py_None, Py_LT, Py_LE, Py_EQ, Py_NE, Py_GT, Py_GE;
import deimos.python.boolobject : Py_True, Py_False;
//import deimos.python.object : PyObject, , Py_DECREF, Py_XDECREF, Py_XINCREF, ;
import deimos.python.abstract_ : PyObject_IsInstance;
//import deimos.python.abstract_ : PyObject_Length, PySequence_GetItem;
import deimos.python.pyerrors : PyErr_SetString, PyExc_TypeError, PyExc_ValueError;

//import pyd.def : def_selector;
import pyd.exception : exception_catcher;
import pyd.references : PydTypeObject, get_d_reference, is_wrapped;
//import pyd.references : , , remove_pyd_mapping;
import pyd.util.typeinfo : constness, constCompatible, ApplyConstness2;
//import pyd.util.typeinfo : , constness, constCompatible, NewParamT;
import pyd.util.dg_wrapper : dg_wrapper;
//import pyd.util.replace : Replace;
//import pyd.util.typelist : Join;
//
//import pyd.func_wrap : getparams;
import pyd.conversions.d_to_python : d_to_python;
import pyd.conversions.python_to_d : python_to_d;

//import pyd.util.typeinfo : attrs_to_string, ApplyConstness, constness, NewParamT


// our signatures - self is missing from the sig
alias inquiry = int function();
alias reprfunc = string function();                                 // in cpython api reprfunc function answers PyObject* - we'll handle the conversion below
alias initproc = int function(PyObject*, PyObject*);
alias richcmpfunc = PyObject* function(PyObject*, int);


// ?to_inquiry
template to_inquiry(T, alias fn) {
    static assert(
        constCompatible(constness!T, constness!(typeof(fn))),
        format("constness mismatch instance: %s function: %s", T.stringof, typeof(fn).stringof)
    );
    extern(C) int inquiry(PyObject* pySelf) {
        return exception_catcher(delegate int() {
            auto dg  = dg_wrapper!(T, typeof(&fn))(get_d_reference!T(pySelf), &fn);
            return dg();
        });
    }
}


// ?to_reprfunc
// ne pyd.class_wrap.wrapped_repr
template to_reprfunc(T, alias fn) {
    static assert(
        constCompatible(constness!T, constness!(typeof(fn))),
        format("constness mismatch instance: %s function: %s", T.stringof, typeof(fn).stringof)
    );
    extern(C) PyObject* reprfunc(PyObject* pySelf) {
        return exception_catcher(delegate PyObject*() {
            auto dg = dg_wrapper!(T, typeof(&fn))(get_d_reference!T(pySelf), &fn);
            return d_to_python(dg());
        });
    }
}


// ne opfunc_unary_wrap
template to_unaryfunc(T, alias fn) {
    extern(C) PyObject* unary(PyObject* pySelf) {
        return exception_catcher(delegate PyObject*() {
            if (pySelf is null) {
                PyErr_SetString(PyExc_TypeError, "Wrapped method didn't get a 'self' parameter.");  // should never happen
                return null;
            }
            T dSelf = get_d_reference!T(pySelf);
            if (dSelf is null) {
                PyErr_SetString(PyExc_ValueError, "Wrapped dSelf is null!");
                return null;
            }
            auto dg = dg_wrapper!(T, typeof(&fn))(dSelf, &fn);
            static if (is(ReturnType!(dg) == void)) {
                dg();
                return Py_INCREF(Py_None());
            } else {
                return d_to_python(dg());
            }
        });
    }
    alias to_unaryfunc = unary;
}


//template to_objobjproc(T, _lop, _rop) {
template to_objobjproc(T, _rop) {
    alias rop = _rop.C;
    static if(rop.length) {
        alias rop0 = rop[0];
        alias rfn = rop0.Inner!T.FN;
        alias ROtherT = Parameters!(rfn)[0];
    }

    extern(C) int objobjproc(PyObject* o1, PyObject* o2) {
        return exception_catcher(delegate int() {
            auto dg = dg_wrapper!(T, typeof(&rfn))(get_d_reference!T(o1), &rfn);
            return dg(python_to_d!ROtherT(o2));
        });
    }
}


// ne pyd.opwrap.rich_opcmp_wrap
template to_richcmpfunc(T, alias fn) {
    static assert(
        constCompatible(constness!T, constness!(typeof(fn))),
        format("constness mismatch instance: %s function: %s", T.stringof, typeof(fn).stringof)
    );
    alias Info = Parameters!(fn);
    alias TOther = Info[0];
    extern(C) PyObject* richcmpfunc(PyObject* pySelf, PyObject* pyOther, int op) {
        return exception_catcher(delegate PyObject*() {
            auto dg = dg_wrapper!(T, typeof(&fn))(get_d_reference!T(pySelf), &fn);
            return dg(pyOther, op);
        });
    }
}


// wrap a binary operator overload, handling __op__, __rop__, or
// __op__ and __rop__ as necessary.
// use new style operator overloading (ie check which arg is actually self).
// _lop.C is a tuple w length 0 or 1 containing a BinaryOperatorX instance.
// same for _rop.C.
// ?to_binaryfunc - ne pyd.op_wrap.binop_wrap
template to_binaryfunc(T, _lop, _rop) {
    pragma(msg, "to_binaryfunc ---  ", T, _lop, _rop);
    alias lop = _lop.C;
    alias rop = _rop.C;
    alias wtype = PydTypeObject!T;
    static if(lop.length) {
        alias lop0 = lop[0];
        alias lfn = lop0.Inner!T.FN;
        alias get_dgl = dg_wrapper!(T, typeof(&lfn));
        alias LOtherT = Parameters!(lfn)[0];
        alias LRet = ReturnType!(lfn);
    }
    static if(rop.length) {
        alias rop0 = rop[0];
        alias rfn = rop0.Inner!T.FN;
        alias get_dgr = dg_wrapper!(T, typeof(&rfn));
        alias ROtherT = Parameters!(rfn)[0];
        alias RRet = ReturnType!(rfn);
    }
    enum mode = (lop.length?"l":"")~(rop.length?"r":"");
    extern(C) PyObject* binaryfunc(PyObject* o1, PyObject* o2) {
        return exception_catcher(delegate PyObject*() {
            enforce(is_wrapped!(T));

            pragma(msg, "to_binaryfunc.binaryfunc ---  ", mode);
            static if(mode == "lr") {
                //writeln("binaryfunc lr");
                if (PyObject_IsInstance(o1, cast(PyObject*)&wtype)) {
                    goto op;
                }else if(PyObject_IsInstance(o2, cast(PyObject*)&wtype)) {
                    goto rop;
                }else{
                    enforce(false, format("unsupported operand type(s) for %s: '%s' and '%s'", lop[0].op, to!string(o1.ob_type.tp_name), to!string(o2.ob_type.tp_name)));
                }
            }
            static if(mode.startsWith("l")) {
op:
                //writeln("binaryfunc l");
                static if(lop[0].op.endsWith("=")) {
                    get_dgl(get_d_reference!T(o1), &lfn)(python_to_d!LOtherT(o2));
                    // why?
                    // http://stackoverflow.com/questions/11897597/implementing-nb-inplace-add-results-in-returning-a-read-only-buffer-object
                    // .. still don't know
                    Py_INCREF(o1);
                    return o1;
                }else static if (is(LRet == void)) {
                    get_dgl(get_d_reference!T(o1), &lfn)(python_to_d!LOtherT(o2));
                    return Py_INCREF(Py_None());
                } else {
                    return d_to_python(get_dgl(get_d_reference!T(o1), &lfn)(python_to_d!LOtherT(o2)));
                }
            }
            static if(mode.endsWith("r")) {
rop:
                //writeln("binaryfunc r");
                static if (is(RRet == void)) {
                    get_dgr(get_d_reference!T(o2), &rfn)(python_to_d!ROtherT(o1));
                    return Py_INCREF(Py_None());
                } else {
                    return d_to_python(get_dgr(get_d_reference!T(o2), &rfn)(python_to_d!ROtherT(o1)));
                }
            }
        });
    }
}


// ?to_ternaryfunc
template to_ternaryfunc(T, _lop, _rop) {
    alias lop = _lop.C;
    alias rop = _rop.C;
    alias wtype = PydTypeObject!T;
    static if(lop.length) {
        alias lop0 = lop[0];
        alias lfn = lop0.Inner!T.FN;
        alias get_dgl = dg_wrapper!(T, typeof(&lfn));
        alias LOtherT = Parameters!(lfn)[0];
        alias LRet = ReturnType!(lfn);
    }
    static if(rop.length) {
        alias rop0 = rop[0];
        alias rfn = rop0.Inner!T.FN;
        alias get_dgr = dg_wrapper!(T, typeof(&rfn));
        alias ROtherT = Parameters!(rfn)[0] ;
        alias RRet = ReturnType!(rfn);
    }
    enum mode = (lop.length?"l":"")~(rop.length?"r":"");
    extern(C) PyObject* ternaryfunc(PyObject* o1, PyObject* o2, PyObject* o3) {
        return exception_catcher(delegate PyObject*() {
            enforce(is_wrapped!(T));

            static if(mode == "lr") {
                if (PyObject_IsInstance(o1, cast(PyObject*)&wtype)) {
                    goto op;
                }else if(PyObject_IsInstance(o2, cast(PyObject*)&wtype)) {
                    goto rop;
                }else{
                    //static if(PyiTrace) pragma(msg, "DB HERE");
                    enforce(false, format(
                    "unsupported operand type(s) for %s: '%s' and '%s'",
                    opl.op, o1.ob_type.tp_name, o2.ob_type.tp_name,
                    ));
                }
            }
            static if(mode.startsWith("l")) {
                op:
                auto dgl = get_dgl(get_d_reference!T(o1), &lfn);
                static if (is(LRet == void)) {
                    dgl(python_to_d!LOtherT(o2));
                    return Py_INCREF(Py_None());
                } else {
                    return d_to_python(dgl(python_to_d!LOtherT(o2)));
                }
            }
            static if(mode.endsWith("r")) {
                rop:
                auto dgr = get_dgr(get_d_reference!T(o2), &rfn);
                static if (is(RRet == void)) {
                    dgr(python_to_d!ROtherT(o1));
                    return Py_INCREF(Py_None());
                } else {
                    return d_to_python(dgr(python_to_d!LOtherT(o1)));
                }
            }
        });
    }
}


// It is intended that all of these templates accept a pointer-to-struct type
// as a template parameter, rather than the struct type itself.

template to_PyGetSetDef(T, string dname, string mode, PropertyParts...) {

    pragma (msg, "struct_wrap.wrapped_member ", T, ", ", dname, ", ", mode);

    alias type = PydTypeObject!(T);
    alias oby = wrapped_class_object!(T);
    static if(PropertyParts.length != 0) {
        alias ppart0 = PropertyParts[0];
        alias M = ppart0.Type;
        // const setters make no sense. getters though..
        static if(ppart0.isgproperty) {
            alias GT = ApplyConstness2!(T,constness!(FunctionTypeOf!(ppart0.GetterFn)));
        }
    }else {
        alias GT = T;
        mixin("alias typeof(T."~dname~") M;");
    }

    static if(countUntil(mode, "r") != -1) {

        enum isStructInStruct = isPointer!GT &&
        is(PointerTarget!GT == struct) &&
        is(typeof(mixin("GT.init."~dname)) == struct);

        extern(C) PyObject* get(PyObject* self, void* closure) {
            return exception_catcher(delegate PyObject*() {
                GT t = get_d_reference!GT(self);
                static if(isStructInStruct) {
                    mixin("return d_to_python(&t."~dname~");");
                }else{
                    mixin("return d_to_python(t."~dname~");");
                }
            });
        }
    }

    static if(countUntil(mode, "w") != -1) {
        extern(C) int set(PyObject* self, PyObject* value, void* closure) {
            return exception_catcher(delegate int() {
                T t = get_d_reference!T(self);
                mixin("t."~dname~" = python_to_d!(M)(value);");
                return 0;
            });
        }
    }
}


// kill
private template wrapped_class_object(T) {
    alias wrapped_class_object = PyObject;
}

