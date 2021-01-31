module bones_vm.pyig.boilerplate;      // adapted from autowrap:pyd

/**
   Necessary boilerplate for pyd.

   To wrap all functions/return/parameter types and  struct/class definitions from
   a list of modules, write this in a "main" module and generate mylib.{so,dll}:

   ------
   mixin wrapAll(LibraryName("mylib"), Modules("module1", "module2", ...));
   ------
 */


import std.format: format;
import std.algorithm: map;
import std.array: join;

import autowrap.types: Modules, LibraryName, PreModuleInitCode, PostModuleInitCode, RootNamespace;



/**
   Returns a string to mixin that implements the necessary boilerplate
   to create a Python library containing one Python module
   wrapping all relevant D code and data structures.
 */
string genPydMain(
        LibraryName libraryName,
        Modules modules,
        RootNamespace _ = RootNamespace(),  // ignored in this backend
        PreModuleInitCode preModuleInitCode = PreModuleInitCode(),
        PostModuleInitCode postModuleInitCode = PostModuleInitCode()
) () {

    return __ctfe
        ? wrapAll(libraryName, modules, preModuleInitCode, postModuleInitCode)
        : null;
}


/**
   answers generated srcCode that defines all the necessary runtime pyd boilerplate.
 */
string wrapAll(
        in LibraryName libraryName,
        in Modules modules,
        in PreModuleInitCode preModuleInitCode = PreModuleInitCode(),
        in PostModuleInitCode postModuleInitCode = PostModuleInitCode()
) @safe pure {

    if(!__ctfe) return null;

    string ret =
        pydMainDSrc(modules, preModuleInitCode, postModuleInitCode) ~
        pydInitDSrc(libraryName.value);

    version(Have_excel_d) {
        ret ~=
        // this is needed because of the excel-d dependency
        q{
            import xlld.wrap.worksheet: WorksheetFunction;
            extern(C) WorksheetFunction[] getWorksheetFunctions() @safe pure nothrow { return []; }
        };
    } else version(Windows) {
        import autowrap.common : dllMainMixinStr;
        ret ~= dllMainMixinStr;
    }

    return ret;
}


// answers d src for registering all functions and structs in the passed in modules
string pydMainDSrc(
        in Modules modules,
        in PreModuleInitCode preModuleInitCode = PreModuleInitCode(),
        in PostModuleInitCode postModuleInitCode = PostModuleInitCode()
) @safe pure {

    if(!__ctfe) return null;

    const modulesList = modules.value.map!(a => a.toString).join(", ");

    return q{
        extern(C) void PydMain() {
            import std.typecons: Yes, No;
            import pyd.pyd: module_init, add_module, ModuleName;
            import bones_vm.pyig.boilerplate_utils: wrapAllFunctions, wrapAllAggregates;

            // this must go before module_init

            add_module!(ModuleName!"bones_vm")();

            wrapAllFunctions!(%s);

            %s

            module_init();


            // this must go after module_init
            wrapAllAggregates!(%s);

            %s
        }
    }.format(
            modulesList,
            preModuleInitCode.value,
            modulesList,
            postModuleInitCode.value
    );
}


// defines PyInit function for a library.
string pydInitDSrc(in string libraryName) @safe pure {

    if(!__ctfe) return null;

    version(Python_3_0_Or_Later) {
        return q{
            import deimos.python.object: PyObject;
            extern(C) export PyObject* PyInit_%s() {
                import pyd.def: pyd_module_name, pyd_modules;
                import pyd.exception: exception_catcher;
                import pyd.thread: ensureAttached;
                import core.runtime: rt_init;

                rt_init;

                return exception_catcher(delegate PyObject*() {
                        ensureAttached();
                        pyd_module_name = "%s";
                        PydMain();
                        return pyd_modules[""];
                    });
            }
        }.format(libraryName, libraryName);
    } else {
        return q{
            extern(C) export void init%s() {
                import pyd.exception: exception_catcher;
                import pyd.thread: ensureAttached;
                import pyd.def: pyd_module_name;
                import core.runtime: rt_init;

                rt_init;

                exception_catcher(delegate void() {
                        ensureAttached();
                        pyd_module_name = "%s";
                        PydMain();
                    });

            }
        }.format(libraryName, libraryName);
    }
}
