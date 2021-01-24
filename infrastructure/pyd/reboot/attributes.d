module pyd.reboot.attributes;

struct pykwargs { string name; this(string name) {this.name = name;}}
struct pyargs { string name; this(string name) {this.name = name;}}
struct pymagic { string name; this(string name) {this.name = name;}}
enum pyclass;
enum pyignore;



string signatureWithAttributes(alias fn)() {
    import std.traits : Parameters, ReturnType, getUDAs, hasUDA, fullyQualifiedName, isCallable;
    static if (isCallable!fn) {
        string s = "";
        s ~= fullyQualifiedName!fn~" => ";
        s ~= Parameters!fn.stringof~"->";
        s ~= ReturnType!fn.stringof;
        auto attributes = __traits(getAttributes, fn);
        bool first;   // gotta be out of the loop - SHOULDDO understand why that is
        if (attributes.length > 0) {
            s ~= " : ";
            first = true;
            foreach (attribute; attributes) {
                if (!first) {
                    s ~= " ";
                }
                if (is(typeof(attribute) == pymagic)) {
                    s ~= "pymagic("~attribute.name~")";
                } else if (is(typeof(attribute) == pykwargs)) {
                    s ~= "pykwargs("~attribute.name~")";
                } else if (is(typeof(attribute) == pyargs)) {
                    s ~= "pyargs("~attribute.name~")";
                } else {
                    s ~= attribute.stringof;
                }
                first = false;
            }
        }
        return s;
    } else {
        return fn.stringof~" is not callable";
    }
}

bool hasArgs(alias x)() {
    //auto attributes = __traits(getAttributes, x);
    //if (attributes.length == 0) return false;
    //foreach(attribute; attributes) {
    //    if (is(typeof(attribute) == pyargs)) {
    //        return true;
    //    }
    //}
    return false;
}

bool hasKwargs(alias x)() {
    //auto attributes = __traits(getAttributes, x);
    //if (attributes.length == 0) return false;
    //foreach(attribute; attributes) {
    //    if (is(typeof(attribute) == pykwargs)) {
    //        return true;
    //    }
    //}
    return false;
}

