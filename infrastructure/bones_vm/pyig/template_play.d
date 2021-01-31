module bones_vm.pyig.template_play;

import std.conv;

import std.meta : allSatisfy, AliasSeq, Filter, staticMap, templateNot;
import std.traits : isArray, hasMember, Parameters, fullyQualifiedName, ReturnType, isIntegral, isFunction, getUDAs, FunctionTypeOf,
    isCallable;


import bones_vm.pyig.attributes;   // args, kwargs, __add__ etc

import bones_vm.pyig.config : __ShouldThrow__;
import bones_vm.pyig.traits : _filterMembersFor_tp_as_number, _isString, _isString2;


struct Num {
    private int _n;

    this(int n){_n = n;};

    @__add__
    int add(int rhs) {return addImpl(_n, rhs);}

    @__add__
    int add2(int rhs) {return _n + rhs;}

    @__add__
    float add(float rhs) {return _n * rhs + rhs;}      // this doesn't cause a compiler error

    @__sub__
    int sub(int rhs) {return _n - rhs;}

    @__rsub__
    int rsub(int lhs) {return lhs - _n;}

    //@__mul__
    //int mul(int rhs) {
    //    return this.opBinary!("*")(rhs);
    //}

    @__mul__
    int opBinary(string op)(int rhs) if (op == "*") {return _n * rhs;}

}

int addImpl(int a, int b) {return a + b;}


void fred() {
    pragma(msg, "-------------------");
    pragma(msg, "__ShouldThrow__ ", __ShouldThrow__);


    pragma(msg, "__traits(allMembers, Num) ", __traits(allMembers, bones_vm.pyig.config));


    alias x = _filterMembersFor_tp_as_number!Num;

    static if (x.members__add__.length > 0) pragma(msg, "__add__  ", x.members__add__);
    static if (x.members__radd__.length > 0) pragma(msg, "__radd__  ", x.members__radd__);
    static if (x.members__mul__.length > 0) pragma(msg, "__mul__  ", x.members__mul__);
    static if (x.members__rmul__.length > 0) pragma(msg, "__rmul__  ", x.members__rmul__);
    static if (x.members__sub__.length > 0) pragma(msg, "__sub__  ", x.members__sub__);
    static if (x.members__rsub__.length > 0) pragma(msg, "__rsub__  ", x.members__rsub__);

    pragma(msg, "fred  ", FunctionTypeOf!(x.members__sub__[0]));
    pragma(msg, "fred  ", isCallable!(x.members__sub__[0]));
    pragma(msg, "fred  ", fullyQualifiedName!(x.members__sub__[0]));

    pragma(msg, "_isString  ", _isString!"hello");
    pragma(msg, "_isString  ", _isString!x);
    pragma(msg, "_isString2  ", _isString2!"hello");
    pragma(msg, "_isString2  ", _isString2!x);

    template Sally (){
        enum inner = 10;
    }
    alias y = Sally!();


    //int _ = 1/0;        // throws because compiler try to figure out 1/0 rather than delaying until runtime
    pragma(msg, "-------------------");
}




//
//
//
//void fred2() {
//
//    template Sally (){
//        enum inner = 10;
//    }
//
//    template joe(alias S, T) {
//        alias i = S;
//        enum T j = 5;
//        enum T k = j + 1;
//    }
//
//    template harry(int v) {
//        enum result = v * 2;
//        alias harry = result;
//    }
//
//    alias c = Sally!();
//    alias a = joe!(c,int);
//    alias d = harry!(4);
//
//    pragma(msg, "-----------------");
//    pragma(msg, joe!(c,int).j, joe!(c,int).k);
//    pragma(msg, a.j);
//    pragma(msg, a.i.inner);
//    pragma(msg, d);
//    pragma(msg, "-----------------");
//
//
//    int b = 1 / 0;
//
//
//
//}
//


