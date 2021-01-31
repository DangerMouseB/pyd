module bones_vm.pyig.reflection;


import std.meta: allSatisfy;
import std.traits : getUDAs;
import std.typecons: Flag, No;

public import autowrap.types: isModule, Modules, Module, Ignore;

import bones_vm.pyig.attributes;


private enum isString(alias T) = is(typeof(T) == string);


template AllConstants(Modules modules) {
    import std.algorithm: map;
    import std.array: join;
    import std.typecons: Yes, No;  // needed for Module.toString in the mixin

    enum modulesList = modules.value.map!(a => a.toString).join(", ");
    mixin(`alias AllConstants = AllConstants!(`, modulesList, `);`);
}

template AllConstants(Modules...) if(allSatisfy!(isModule, Modules)) {
    import std.meta: staticMap;
    alias AllConstants = staticMap!(Constants, Modules);
}

template Constants(Module module_) {
    import mirror.meta.reflection: MirrorModule = Module;
    import std.meta: Filter;

    alias mod = MirrorModule!(module_.name);

    private enum isConstant(alias var) = var.isConstant;

    alias Constants = Filter!(isConstant, mod.Variables);
}


template AllFunctions(Modules modules) {
    import std.algorithm: map;
    import std.array: join;
    import std.typecons: Yes, No;  // needed for Module.toString in the mixin

    enum modulesList = modules.value.map!(a => a.toString).join(", ");
    mixin(`alias AllFunctions = AllFunctions!(`, modulesList, `);`);
}

template AllFunctions(Modules...) if(allSatisfy!(isString, Modules)) {
    import std.meta: staticMap;
    enum module_(string name) = Module(name);
    alias AllFunctions = staticMap!(Functions, staticMap!(module_, Modules));
}

template AllFunctions(Modules...) if(allSatisfy!(isModule, Modules)) {
    import std.meta: staticMap;
    alias AllFunctions = staticMap!(Functions, Modules);
}

template Functions(Module module_) {
    mixin(`import dmodule = ` ~ module_.name ~ `;`);
    alias Functions = Functions!(dmodule, module_.alwaysExport, module_.ignoredSymbols);
}

template Functions(alias module_, Flag!"alwaysExport" alwaysExport = No.alwaysExport, Ignore[] ignoredSymbols = [])
    if(!is(typeof(module_) == string))
{
    import mirror.meta.reflection: MirrorModule = Module, FunctionSymbol;
    import std.meta: staticMap, Filter, templateNot;
    import std.traits: moduleName;
    import std.algorithm: canFind;

    alias mod = MirrorModule!(moduleName!module_);
    enum isExport(alias F) = isExportFunction!(F.symbol, alwaysExport);
    enum shouldIgnore(alias F) = ignoredSymbols.canFind!(a => a.identifier == F.identifier);

    alias Functions = Filter!(templateNot!shouldIgnore,
                              Filter!(isExport, mod.FunctionsBySymbol));
}


template AllAggregates(Modules modules) {
    import std.algorithm: map;
    import std.array: join;
    import std.typecons: Yes, No;  // needed for Module.toString in the mixin

    enum modulesList = modules.value.map!(a => a.toString).join(", ");
    mixin(`alias AllAggregates = AllAggregates!(`, modulesList, `);`);
}

template AllAggregates(ModuleNames...) if(allSatisfy!(isString, ModuleNames)) {
    import std.meta: staticMap;

    enum module_(string name) = Module(name);
    enum Modules = staticMap!(module_, ModuleNames);

    alias AllAggregates = AllAggregates!(staticMap!(module_, ModuleNames));
}

template AllAggregates(Modules...) if(allSatisfy!(isModule, Modules)) {
    import std.meta: Filter, NoDuplicates, staticMap;
    import std.traits: isCopyable;

    alias AllAggregates = Filter!(isCopyable, NoDuplicates!(staticMap!(AllAggregatesInModule, Modules)));
}

private template AllAggregatesInModule(Module module_) {
    import mirror.meta.reflection: MirrorModule = Module;
    import std.meta: NoDuplicates, Filter, staticMap, templateNot;
    import std.algorithm: canFind;

    alias mod = MirrorModule!(module_.name);
    enum shouldIgnore(T) = module_.ignoredSymbols.canFind!(a => a.identifier == T.stringof);

    alias AllAggregatesInModule =
        Filter!(templateNot!shouldIgnore,
                NoDuplicates!(
                    Filter!(isUserAggregate,
                            staticMap!(PrimordialType, mod.AllAggregates))));
}


// if a type is a struct or a class
template isUserAggregate(A...) if(A.length == 1) {
    import std.datetime;
    import std.traits: Unqual, isInstanceOf;
    import std.typecons: Tuple;
    import core.time: Duration;

    alias T = A[0];

    enum isUserAggregate =
        !is(Unqual!T == DateTime) &&
        !is(Unqual!T == Date) &&
        !is(Unqual!T == TimeOfDay) &&
        !is(Unqual!T == Duration) &&
        !isInstanceOf!(Tuple, T) &&
        (is(T == struct) || is(T == class) || is(T == enum) || is(T == union));
}


// T -> T, T[] -> T, T[][] -> T, T* -> T
template PrimordialType(T) {
    import mirror.meta.traits: FundamentalType;
    import std.traits: Unqual;
    alias PrimordialType = Unqual!(FundamentalType!T);
}


package template isExportFunction(alias F, Flag!"alwaysExport" alwaysExport = No.alwaysExport) {
    import std.traits: isFunction;
    enum hasInclude = getUDAs!(F, include).length != 0;
    static if(!isFunction!F)
        enum isExportFunction = false || hasInclude;
    else {
        version(AutowrapAlwaysExport) {
            enum linkage = __traits(getLinkage, F);
            enum isExportFunction = hasInclude || (linkage != "C" && linkage != "C++");
        } else version(AutowrapAlwaysExportC) {
            enum linkage = __traits(getLinkage, F);
            enum isExportFunction = hasInclude || (linkage == "C" || linkage == "C++");
        } else
            enum isExportFunction = hasInclude || (isExportSymbol!(F, alwaysExport));
    }
}


private template isExportSymbol(alias S, Flag!"alwaysExport" alwaysExport = No.alwaysExport) {
    static if(__traits(compiles, __traits(getProtection, S)))
        enum isExportSymbol = isPublicSymbol!S && (alwaysExport || __traits(getProtection, S) == "export");
    else
        enum isExportSymbol = false;
}


private template isPublicSymbol(alias S) {
    enum isPublicSymbol = __traits(getProtection, S) == "export" || __traits(getProtection, S) == "public";
}


