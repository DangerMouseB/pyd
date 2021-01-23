module pyd.util.dg_wrapper;

import std.traits;



// dirty hacks for converting between function and delegate types. As of DMD 0.174,
// the language has built-in support for hacking apart delegates like this. Hooray!


// converts a pointer to a member function into a delegate.
auto dg_wrapper(T, Fn) (T t, Fn fn) {
    pragma(msg, "pyd.util.dg_wrapper.dg_wrapper fn - ");
    fn_to_dg!(Fn) dg;
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
template fn_to_dg(Fn) {
    alias fn_to_dg = fn_to_dgT!(Fn).type;
}

template fn_to_dgT(Fn) {
    alias T = Parameters!(Fn);
    alias Ret = ReturnType!(Fn);

    mixin("alias Ret delegate(T) " ~ tattrs_to_string!(Fn)() ~ " type;");
}

string tattrs_to_string(fn_t)() {
    string s;
    if(isConstFunction!fn_t) {
        s ~= " const";
    }
    if(isImmutableFunction!fn_t) {
        s ~= " immutable";
    }
    if(isSharedFunction!fn_t) {
        s ~= " shared";
    }
    if(isWildcardFunction!fn_t) {
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

