import std.typecons: Yes, No;

import autowrap.types: Modules, Module, Ignore, LibraryName;

import bones_vm.pyig.boilerplate : genPydMainSrcFor;


enum str = genPydMainSrcFor!(
    LibraryName("bones_vm_ex2"),
    // No.alwaysExport doesn't seem to suppress structs so explitily Ignore
    Modules(
        Module("bones_vm_ex2.types", No.alwaysExport,
            Ignore("BTypeManager"), Ignore("PyTypeObject"), Ignore("PyVarObject"), Ignore("PyAsyncMethods"), Ignore("PyNumberMethods")
            , Ignore("PyObject"), Ignore("PySequenceMethods"), Ignore("PyMappingMethods"), Ignore("PyBufferProcs"), Ignore("PyMethodDef")
            , Ignore("PyMethodDef"), Ignore("PyMemberDef"), Ignore("PyGetSetDef"), Ignore("PyMethodDef")
        ),
        Module("bones_vm_ex2.structs", No.alwaysExport,
            Ignore("MyType")
        )
        //Module("py.basic", No.alwaysExport,
        //    Ignore("NotInvisible")
        //),
        //Module("py.magic", No.alwaysExport,
        //    Ignore("PyTypeObject"), Ignore("PyMethodDef"), Ignore("PyGetSetDef"), Ignore("PyMemberDef")
        //)
    ),
);


mixin(str);

