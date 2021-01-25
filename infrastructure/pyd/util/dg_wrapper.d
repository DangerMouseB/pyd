module pyd.util.dg_wrapper;

import std.traits;

import pyd.reboot.common : RebootFullTrace;


// dirty hacks for converting between function and delegate types. As of DMD 0.174,
// the language has built-in support for hacking apart delegates like this. Hooray!


// converts a pointer to a member function into a delegate.
auto dg_wrapper(T, F) (T t, F fn) {
    //static if(RebootFullTrace) pragma(msg, "pyd.util.dg_wrapper.dg_wrapper fn - ");
    fn_to_dg!(F) dg;
    dg.ptr = cast(void*) t;
    static if(variadicFunctionStyle!fn == Variadic.typesafe) {
        // trying to stuff a Ret function(P[]...) into a Ret function(P[])
        // it'll totally work!
        dg.funcptr = cast(typeof(dg.funcptr)) fn;
    } else {
        dg.funcptr = fn;
    }
    return dg;
}

// converts function type into an equivalent delegate type.
template fn_to_dg(F) {
    alias fn_to_dg = fn_to_dgT!(F).type;
}

template fn_to_dgT(F) {
    alias T = Parameters!F;
    alias Ret = ReturnType!F;

    mixin("alias Ret delegate(T) " ~ tattrs_to_string!F() ~ " type;");
}

private string tattrs_to_string(F)() {
    string s;
    if(isConstFunction!F) {
        s ~= " const";
    }
    if(isImmutableFunction!F) {
        s ~= " immutable";
    }
    if(isSharedFunction!F) {
        s ~= " shared";
    }
    if(isWildcardFunction!F) {
        s ~= " inout";
    }
    return s;
}

template isImmutableFunction(T...) if (T.length == 1) {
    alias func_t = funcTarget!T;
    enum isImmutableFunction = is(func_t == immutable);
}
template isConstFunction(T...) if (T.length == 1) {
    alias func_t = funcTarget!T;
    enum isConstFunction = is(func_t == const);
}
template isMutableFunction(T...) if (T.length == 1) {
    alias func_t = funcTarget!T;
    enum isMutableFunction = !is(func_t == inout) && !is(func_t == const) && !is(func_t == immutable);
}
template isWildcardFunction(T...) if (T.length == 1) {
    alias func_t = funcTarget!T;
    enum isWildcardFunction = is(func_t == inout);
}
template isSharedFunction(T...) if (T.length == 1) {
    alias func_t = funcTarget!T;
    enum isSharedFunction = is(func_t == shared);
}

template funcTarget(T...) if(T.length == 1) {
    static if(isPointer!(T[0]) && is(PointerTarget!(T[0]) == function)) {
        alias funcTarget = PointerTarget!(T[0]);
    } else static if(is(T[0] == function)) {
        alias funcTarget = T[0];
    } else static if(is(T[0] == delegate)) {
            alias funcTarget = PointerTarget!(typeof((T[0]).init.funcptr));
        } else static assert(false);
}

