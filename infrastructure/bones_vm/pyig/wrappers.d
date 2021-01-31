module bones_vm.pyig.wrappers;       // adapted from autowrap:pyd

import std.traits : FunctionAttribute, functionAttributes, variadicFunctionStyle, Variadic;


import deimos.python.methodobject : PyMethodDef, PyCFunction, METH_VARARGS, METH_KEYWORDS;
import pyd.class_wrap : wrapped_method_list, assemble_type, Infer, IsPyBinary, BinaryOperatorX;
import pyd.references : PydTypeObject;
import pyd.def : def_selector, Args;
import pyd.util.typeinfo : ApplyConstness, constness, attrs_to_string, tattrs_to_string;
import pyd.util.replace : Replace;

import bones_vm.pyig._dispatch : method_wrap;
import bones_vm.pyig._dispatch_utils : minArgs;
import bones_vm.pyig.attributes : signatureWithAttributes;


// public interface

public import pyd.class_wrap : OpCall, OpSliceAssign, Def, OpSlice, Len, OpIndex, OpIndexAssign, StaticDef, Property,
                                   OpAssign;
public import pyd.def : PyName, def, ModuleName, Docstring;
public import bones_vm.pyig.tp_slots : Init;






/*
Params: each param is a Type which supports the interface

Param.needs_shim == false => Param.assemble!(pyclassname, T)
or
Param.needs_shim == true => Param.assemble!(pyclassname,T, Shim)

    performs appropriate mutations to the PyTypeObject

Param.shim!(i,T) for i : Params[i] == Param

    generates a string to be mixed in to Shim type

where T is the type being wrapped, Shim is the wrapped type

*/

/**
  Wrap a class.

Parameters:
    T = The class being wrapped.
    Params = Mixture of definitions of members of T to be wrapped and optional arguments.
    Concerning optional arguments, accepts
    PyName!(pyname) The name of the class as it will appear in Python. Defaults to T's name in D
    ModuleName!(modulename): The name of the python module in which the wrapped class resides. Defaults to "".
    Docstring!(docstring): The class's docstring. Defaults to "".
  */

// ?wrap_class
void wrap_class(T, Params...)() {
    alias args = Args!("","", __traits(identifier,T), "",Params);
    assemble_type!(T, args.pyname, args.docstring, args.modulename, args.rem)._build();
}

alias wrap_struct = wrap_class;



// Wrap a member variable of a class or struct
//
// Template Parameters:
// name = The name of the member to wrap
// Options = Optional parameters. Takes Docstring!(docstring), PyName!(pyname), and Mode!(mode)
// pyname = The name of the member as it will appear in Python. Defaults to name
// mode = Mode!"r", Mode!"w" or Mode!"rw" - defaults to "rw"
// docstring = The function's docstring - efaults to ""

struct Member(string dname, Options...) {
    import bones_vm.pyig.tp_slots : set_tp_getset;
    alias args = Args!("", "", dname, "rw", Options);
    mixin set_tp_getset!(dname, args.pyname, args.mode, args.docstring);
}



/**
Wraps a member function of the class.

Supports default arguments, typesafe variadic arguments, and python's
keyword arguments.

Params:
fn = The member function to wrap.
Options = Optional parameters. Takes Docstring!(docstring), PyName!(pyname),
and fn_t.
fn_t = The type of the function. It is only useful to specify this
       if more than one function has the same name as this one.
pyname = The name of the function as it will appear in Python. Defaults to
fn's name in D
docstring = The function's docstring. Defaults to "".
*/

struct MemberFunction(alias fn, Options...) {
    // DBHERE
    //pragma(msg, "\nbones_vm.pyig.wrappers.MemberFunction  fn"~signatureWithAttributes!fn);

    alias args = Args!("", "", __traits(identifier, fn), "", Options);

    static if(args.rem.length) {
        alias fn_t = args.rem[0];
    } else {
        alias fn_t = typeof(&fn);
    }

    mixin MemberFunctionImpl!(fn, args.pyname, fn_t, args.docstring);
}

private template MemberFunctionImpl(alias _fn, string name, fn_t, string docstring) {
    alias func = def_selector!(_fn, fn_t).FN;

    static assert(!__traits(isStaticFunction, func), "Cannot register " ~ name ~ " because static member functions are not yet supported");
    alias /*StripSafeTrusted!*/fn_t func_t;
    enum realname = __traits(identifier,func);
    enum funcname = name;
    enum min_args = minArgs!func;
    enum bool needs_shim = false; // needed for the compile-time interface

    static void assemble(string classname, T) () { // needed for the compile-time interface
        alias cT = ApplyConstness!(T, constness!(typeof(func)));
        static PyMethodDef empty = { null, null, 0, null };
        alias list = wrapped_method_list!(T);

        list[$ - 1].ml_name = (name ~ "\0").ptr;
        list[$ - 1].ml_meth = cast(PyCFunction) &method_wrap!(cT, func, classname ~ "." ~ name).func;
        list[$ - 1].ml_flags = METH_VARARGS | METH_KEYWORDS;
        list[$ - 1].ml_doc = (docstring~"\0").ptr;
        list ~= empty;
        // It's possible that appending the empty item invalidated the
        // pointer in the type struct, so we renew it here.
        PydTypeObject!T.tp_methods = list.ptr;
    }

    template shim(size_t i, T) {
        enum shim = Replace!(q{
            alias __pyd_p$i = Params[$i];
            $override ReturnType!(__pyd_p$i.func_t) $realname(Parameters!(__pyd_p$i.func_t) t) $attrs {
                return __pyd_get_overload!("$realname", __pyd_p$i.func_t).func!(Parameters!(__pyd_p$i.func_t))("$name", t);
            }
            alias T.$realname $realname;
        },
        "$i", i, "$realname", realname, "$name", name,
        "$attrs", attrs_to_string(functionAttributes!func_t) ~ " " ~ tattrs_to_string!func_t(),
        "$override",
        //TODO: figure out what's going on here
        (variadicFunctionStyle!func == Variadic.no ? "override": ""));
    }
}


private template isImmutableFunction(T...) if (T.length == 1) {
    alias func_t = funcTarget!T;
    enum isImmutableFunction = is(func_t == immutable);
}
private template isConstFunction(T...) if (T.length == 1) {
    alias func_t = funcTarget!T;
    enum isConstFunction = is(func_t == const);
}
private template isMutableFunction(T...) if (T.length == 1) {
    alias func_t = funcTarget!T;
    enum isMutableFunction = !is(func_t == inout) && !is(func_t == const) && !is(func_t == immutable);
}
private template isWildcardFunction(T...) if (T.length == 1) {
    alias func_t = funcTarget!T;
    enum isWildcardFunction = is(func_t == inout);
}
private template isSharedFunction(T...) if (T.length == 1) {
    alias func_t = funcTarget!T;
    enum isSharedFunction = is(func_t == shared);
}

private template funcTarget(T...) if(T.length == 1) {
    import std.traits : PointerTarget, FuncTarget;
    static if(isPointer!(T[0]) && is(PointerTarget!(T[0]) == function)) {
        alias funcTarget = PointerTarget!(T[0]);
    } else static if(is(T[0] == function)) {
        alias funcTarget = T[0];
    } else static if(is(T[0] == delegate)) {
            alias funcTarget = PointerTarget!(typeof((T[0]).init.funcptr));
        } else static assert(false);
}



/**
Wrap a binary operator overload.

Example:
---
class Foo{
    int _j;
    int opBinary(string op)(int i) if(op == "+"){
        return i+_j;
    }
    int opBinaryRight(string op)(int i) if(op == "+"){
        return i+_j;
    }
}

class_wrap!(Foo,
    OpBinary!("+"),
    OpBinaryRight!("+"));
---

Params:
    op = Operator to wrap
    rhs_t = (optional) Type of opBinary's parameter for disambiguation if there are multiple overloads.
Bugs:
    Issue 8602 prevents disambiguation for case X opBinary(string op, T)(T t);
  */

// ?OpBinary
template OpBinary(string op, rhs_t = Infer) if(IsPyBinary(op) && op != "in"){
    pragma(msg, "OpBinary", op, rhs_t);
    alias OpBinary = BinaryOperatorX!(op, false, rhs_t);
}


// ?OpBinaryRight
template OpBinaryRight(string op, lhs_t = Infer) if(IsPyBinary(op)) {
    alias OpBinaryRight = BinaryOperatorX!(op, true, lhs_t);
}


// ?OpUnary
struct OpUnary(string _op) if(IsPyUnary(_op)) {

    pragma(msg, "OpUnary - ", _op);
    enum op = _op;
    enum bool needs_shim = false;

    template Inner(_T) {
        pragma(msg, "OpUnary.Inner - ", fullyQualifiedName!_T, ", op: ", op, " is ptr ", isPointer!_T);
        static if (isPointer!_T) {
            alias T = PointerTarget!_T;
        }else{
            alias T = _T;
        }
        enum string OP = op;
        pragma(msg, "OpUnary.Inner - ", fullyQualifiedName!T, ", op: ", op, " is ptr ", isPointer!T);
        static if(!__traits(hasMember, T, "opUnary")) {
            static assert(0, T.stringof ~ " has no unary operator overloads");
        }
        static if(is(typeof(T.init.opUnary!(op)) == function)) {
            alias RET_T = ReturnType!(T.opUnary!(op));
            pragma(msg, RET_T);
            alias FN = T.opUnary!(op);
        } else static assert(false, "Cannot get operator overload");
    }
    static void assemble(string classname, T)() {
        pragma(msg, "OpUnary.assemble 1 - ", T.stringof);
        alias type = PydTypeObject!T;
        enum slot = unaryslots[op];
        mixin(autoInitializeMethods());
        mixin(slot ~ " = &to_unaryfunc!(T, Inner!T.FN);");
        pragma(msg, "OpUnary.assemble 2 - ", type.stringof);
    }
    template shim(size_t i,T) {
        enum shim = "";
    }
}