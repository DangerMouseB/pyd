module pyd.reboot.attributes;

import std.traits : hasUDA;

struct kwargs { string name; this(string name) {this.name = name;}}
struct args { string name; this(string name) {this.name = name;}}
struct pymagic { string name; this(string name) {this.name = name;}}
enum pyignore;
enum __repr__;
enum __str__;
enum __call__;
enum __hash__;


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
                    s ~= "@pymagic("~attribute.name~")";
                } else if (is(typeof(attribute) == kwargs)) {
                    s ~= "@kwargs("~attribute.name~")";
                } else if (is(typeof(attribute) == args)) {
                    s ~= "@args("~attribute.name~")";
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


bool fnHasArgsAttr(alias x)() {return hasUDA!(x, args);}
bool fnHasKwargsAttr(alias x)() {return hasUDA!(x, kwargs);}
bool fnHasMagicAttr(alias x)() {return hasUDA!(x, pymagic);}
bool fnHasIgnoreAttr(alias x)() {return hasUDA!(x, pymagic);}

