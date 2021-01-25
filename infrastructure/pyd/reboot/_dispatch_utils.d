module pyd.reboot._dispatch_utils;

import std.format : format;
import std.conv : to;

import std.traits : variadicFunctionStyle, Parameters, Variadic;


import pyd.util.typeinfo : WorkaroundParameterDefaults;



bool supportsNArgs(alias fn, fn_t = typeof(&fn))(size_t n) {
    if (n < minArgs!(fn,fn_t)) return false;
    alias vstyle = variadicFunctionStyle!fn;
    alias ps = Parameters!fn;
    //https://issues.dlang.org/show_bug.cgi?id=17192
    //alias ParameterDefaultValueTuple!fn defaults;
    alias defaults = WorkaroundParameterDefaults!fn;
    static if(vstyle == Variadic.no) {
        return (n >= minArgs!(fn,fn_t) && n <= maxArgs!(fn,fn_t).max);
    }else static if(vstyle == Variadic.c){
        return true;
    }else static if(vstyle == Variadic.d){
        return true;
    }else static if(vstyle == Variadic.typesafe){
        return true;
    }else static assert(0);
}

//**
//  Determines at runtime whether the function can be given n arguments.
//  */
//bool supportsNArgs(alias fn, fn_t = typeof(&fn))(size_t n) {
//    if (n < minArgs!(fn,fn_t)) return false;
//    alias variadicFunctionStyle!fn vstyle;
//    alias Parameters!fn ps;
//    //https://issues.dlang.org/show_bug.cgi?id=17192
//    //alias ParameterDefaultValueTuple!fn defaults;
//    import pyd.util.typeinfo : WorkaroundParameterDefaults;
//    alias defaults = WorkaroundParameterDefaults!fn;
//    static if(vstyle == Variadic.no) {
//        return (n >= minArgs!(fn,fn_t) && n <= maxArgs!(fn,fn_t).max);
//    }else static if(vstyle == Variadic.c){
//        return true;
//    }else static if(vstyle == Variadic.d){
//        return true;
//    }else static if(vstyle == Variadic.typesafe){
//        return true;
//    }else static assert(0);
//}



string gensym(Taken...)() {
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


/**
  Finds the maximum number of arguments a given function may be provided
  and/or whether the function has a maximum number of arguments.
  */
template maxArgs(alias fn, fnT=typeof(&fn)) {
    alias vstyle = variadicFunctionStyle!fn;
    alias ps = Parameters!fn;
    /// _
    enum bool hasMax = vstyle == Variadic.no;
    /// _
    enum size_t max = ps.length;
}

/**
  Finds the minimal number of arguments a given function needs to be provided
 */
template minArgs(alias fn, fnT=typeof(&fn)) {
    enum size_t minArgs = minNumArgs_impl!(fn, fnT).res;
}
private template minNumArgs_impl(alias fn, fnT) {
    alias Params = Parameters!(fnT);
    //https://issues.dlang.org/show_bug.cgi?id=17192
    //alias ParameterDefaultValueTuple!(fn) Defaults;
    alias Defaults = WorkaroundParameterDefaults!fn;
    alias vstyle = variadicFunctionStyle!fn;
    static if(Params.length == 0) {
        // handle func(), func(...)
        enum res = 0;
    }else static if(vstyle == Variadic.typesafe){
        // handle func(nondefault T1 t1, nondefault T2 t2, etc, TN[]...)
        enum res = Params.length-1;
    }else{
        size_t count_nondefault() {
            size_t result = 0;
            foreach(i, v; Defaults) {
                static if(is(v == void)) {
                    result ++;
                }else{
                    break;
                }
            }
            return result;
        }
        enum res = count_nondefault();
    }
}

