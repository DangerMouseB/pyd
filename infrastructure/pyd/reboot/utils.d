module pyd.reboot.utils;

import std.traits : isAssignable;


 
// compose a tuple without cast-breaking constness
// example:
// ----------
// alias TupleComposer!(immutable(int), immutable(string)) T1;
// T1* t = new T1(1);
// t = t.put!1("foo");
// // t.fields is a thing now
struct TupleComposer(Ts...) {
    Ts fields;

    TupleComposer!Ts* put(size_t i)(Ts[i] val) {
        static if(isAssignable!(Ts[i])){
            fields[i] = val;
            return &this;
        }else{
            return new TupleComposer(fields[0 .. i], val);
        }

    }
}


