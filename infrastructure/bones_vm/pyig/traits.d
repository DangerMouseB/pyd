module bones_vm.pyig.traits;


import std.algorithm : startsWith;
import std.meta : Filter, staticMap, templateNot;
import std.traits;

public import mirror.meta.traits :
    _isPropertyFn=isProperty,
    _isStaticMemberFunctionFn=isStaticMemberFunction,
    _PublicFieldNamesFn=PublicFieldNames;

import bones_vm.pyig.config : __ShouldThrow__;
import bones_vm.pyig.attributes;    // args, kwargs, __add__ etc



// ?_isInit
template _isInit(T) {
    enum bool _isInit = __traits(hasMember, T, "CtorParams");
}

template _filterMembersFor_tp_as_number(T) {
    private alias getExpr(string memberName) = _memberExprFromNameFn!(T, memberName);
    alias members = staticMap!(getExpr, __traits(allMembers, T));

    alias members__add__ = Filter!(_isMemberFnWithUda!__add__, members);
    alias members__radd__ = Filter!(_isMemberFnWithUda!__radd__, members);
    alias members__sub__ = Filter!(_isMemberFnWithUda!__sub__, members);
    alias members__rsub__ = Filter!(_isMemberFnWithUda!__rsub__, members);
    alias members__mul__ = Filter!(_isMemberFnWithUda!__mul__, members);
    alias members__rmul__ = Filter!(_isMemberFnWithUda!__rmul__, members);
    alias members__pow__ = Filter!(_isMemberFnWithUda!__pow__, members);
    alias members__rpow__ = Filter!(_isMemberFnWithUda!__rpow__, members);

    alias members__bool__ = Filter!(_isMemberFnWithUda!__bool__, members);
    alias members__invert__ = Filter!(_isMemberFnWithUda!__invert__, members);

    alias members__index__ = Filter!(_isMemberFnWithUda!__index__, members);

    alias members__matmul__ = Filter!(_isMemberFnWithUda!__matmul__, members);
    alias members__rmatmul__ = Filter!(_isMemberFnWithUda!__rmatmul__, members);

}

// ?_hasUda
template _hasUda(alias attr) {
    private bool hasUdaFn(alias func, alias x)() {return getUDAs!(func, x).length != 0;}
    alias _has(alias func) = hasUdaFn!(func, attr);
    alias _hasUda = _has;    // return the result
}

// ?_isMemberFnWithUda
template _isMemberFnWithUda(alias attr) {
    private bool hasUdaFn(alias func, alias x)() {return getUDAs!(func, x).length != 0;}
    enum condition(alias func) = _isMemberFn!func && hasUdaFn!(func, attr);
    alias _isMemberFnWithUda = condition;    // return the result
}


enum bool _isString(alias T) = is(typeof(T) == string);

// ?_isOperator
enum bool _isOperator(alias T) = __traits(identifier, T).startsWith("op");


//? _isOp
enum _isOp(A) = __traits(hasMember, A, "op");


// ?_isMemberFn
enum bool _isMemberFn(alias T) = !_isOperator!T;

// ?_isString2
template _isString2(alias T) {
    enum res = is(typeof(T) == string);
    alias _isString2 = res;
}

// ?_isPublicFunction
template _isPublicFunction(alias F) {
    enum p = __traits(getProtection, F);
    enum hasInclude = getUDAs!(F, include).length != 0;
    static if (isFunction!F && (p == "export" || p == "public")) {
        //pragma(msg, "_isPublicFunction ", fullyQualifiedName!F, ", ", hasInclude);
    }
    enum _isPublicFunction = isFunction!F && (p == "export" || p == "public" || hasInclude);
    //enum _isPublicFunction = isFunction!F && (p == "public");
}

// ?_isMemberFunctionFn
template _isMemberFunctionFn(A...) if(A.length == 1) {
    alias T = A[0];
    static if(!__ShouldThrow__ && !__traits(compiles, __traits(identifier, T))){
        enum _isMemberFunctionFn = false;
    }else{
        enum name = __traits(identifier, T);
        // __ is not allowed in d - see https://dlang.org/spec/lex.html#identifiers
        // toHash need wrapping specially as it should have a nothrow property
        //size_t toHash() const @safe pure nothrow;
        //bool opEquals(ref const typeof(this) s) const @safe pure nothrow;
        // see - https://dlang.org/spec/hash-map.html#using_struct_as_key and
        //        https://dlang.org/spec/hash-map.html#using_classes_as_key
        enum _isMemberFunctionFn = _isPublicFunction!T && !name.startsWith("__") && name != "toHash";
    }
}

// ?_isConstCharStar
template _isConstCharStar(T) {
    static if(isPointer!T){
        alias StarT = PointerTarget!T;
        static if (is(StarT == const(char))) {
            enum _isConstCharStar = true;
        }else{
            enum _isConstCharStar = false;
        }
    }else{
        enum _isConstCharStar = false;
    }
}

// ?_isCharStar
template _isCharStar(T) {
    static if(isPointer!T){
        alias StarT = PointerTarget!T;
        static if (is(StarT == char)) {
            enum _isCharStar = true;
        }else{
            enum _isCharStar = false;
        }
    }else{
        enum _isCharStar = false;
    }
}


// utils


// Given an alias T (module, struct, ...) and a memberName, alias the actual member, or void if not possible
// ne autowrap.python.wrap.Symbol
template _memberExprFromNameFn(alias T, string memberName) {
    alias self(alias T) = T;
    static if(!__ShouldThrow__ && !__traits(compiles, self!(__traits(getMember, T, memberName))))
        alias _memberExprFromNameFn = void;
    else
        alias _memberExprFromNameFn = self!(__traits(getMember, T, memberName));
}

