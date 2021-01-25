import autowrap;

enum str = wrapDlang!(
    LibraryName("play"),
    // No.alwaysExport doesn't seem to suppress structs so explitily Ignore
    Modules(
        Module("py.types", No.alwaysExport,
            Ignore("MyType")
        ),
        Module("py.basic", No.alwaysExport,
            Ignore("NotInvisible")
        )
    ),
);

pragma(msg, str);
mixin(str);

