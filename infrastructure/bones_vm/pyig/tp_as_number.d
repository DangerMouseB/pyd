module bones_vm.pyig.tp_as_number;

import std.algorithm: countUntil;
//import std.meta : allSatisfy, AliasSeq, Filter, staticMap, templateNot;
//import std.format : format;
//import std.conv : to;
//import std.stdio : writeln;
//import std.meta : Filter;
//import std.traits : Parameters, ParameterIdentifierTuple;
//import std.typetuple: TypeTuple; //, staticMap, NoDuplicates, staticIndexOf, allSatisfy;

import deimos.python.object : PyNumberMethods; //PyObject;

import pyd.def : def_selector;
//import pyd.exception : exception_catcher;
import pyd.references : PydTypeObject; //, get_d_reference, is_wrapped;
import pyd.util.typeinfo : ApplyConstness, constness; //, constCompatible, NewParamT;
import pyd.class_wrap : autoInitializeMethods;
//import pyd.util.dg_wrapper : dg_wrapper;
//import pyd.util.replace : Replace;
//import pyd.util.typelist : Join;
//
//import pyd.func_wrap : getparams;
//import pyd.conversions.d_to_python : d_to_python;
//import pyd.conversions.python_to_d : python_to_d;
//import pyd.util.typeinfo : attrs_to_string, ApplyConstness, constness, NewParamT

import bones_vm.pyig.adaptors : to_inquiry, inquiry;



// ?set_nb_bool
struct set_nb_bool(alias _fn) {
    alias fn = def_selector!(_fn, inquiry).FN;
    enum bool needs_shim = false;
    static void assemble(string classname, T)() {
        pragma(msg, "set_nb_bool.assemble 1 - ", T.stringof);
        alias cT = ApplyConstness!(T, constness!(typeof(fn)));
        alias type = PydTypeObject!(T);
        enum slot = "tp_as_number.nb_bool";     // needed for the autoInitializeMethods mixin
        mixin(autoInitializeMethods());
        type.tp_as_number.nb_bool = &to_inquiry!(cT, fn).inquiry;
        pragma(msg, "set_nb_bool.assemble 2 - ", type.stringof);
    }
    template shim(size_t i,T) {
        enum shim = "";
    }
}



