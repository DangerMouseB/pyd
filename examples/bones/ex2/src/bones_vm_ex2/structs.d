module bones_vm_ex2.structs;

import std.algorithm : map;
import std : array;
import std.stdio : writeln;
import std.conv : to;
import std.traits : Unqual;

//import deimos.python.object : PyObject;
//import deimos.python.object : PyObject, PyObject_TypeCheck, Py_INCREF, Py_None, PyTypeObject;
//import deimos.python.abstract_ : PyObject_IsInstance;

//import pyd.class_wrap : wrapped_classes;
//import pyd.conversions.d_to_python : d_to_python;
//import pyd.conversions.python_to_d : python_to_d;
//import pyd.references : PydTypeObject, is_wrapped;
//import pyd.pydobject : PydObject;

import bones_vm.pyig.attributes;   // args, kwargs, __repr__ etc
import bones_vm.pyig.utils : Py_RETURN_NOTIMPLEMENTED;



struct BHashTable {
    // answers the offset to the question offsetOf(Sym name)
    // can start off as a linear search and can transform into a hash map
    // store some bookkeeping for analysis
    // for cow speed and cache locality this should be a variable size value type with elements in line
    // for immediate simplicity put elements in ptr

    uint size;
    uint numTombstones;
    uint count;
    ushort numResizes;
    ushort numRehashes;
    ulong numGets;
    ulong numSets;
    ulong numLinProbes;
    string[] names;            // and tombstones
    uint[] offsets;

    void initialize(uint size) {
    }

    void initialize(string[] names, uint[] offsets) {
    }

    uint offsetForName(string name) {
        return 0;
    }

    uint addName(string name, uint offset) {
        return 0;
    }

    uint removeName(string name) {
        // tombstones the old name
        return 0;
    }

    uint rename(string oldName, string newName){
        // gets the index for the oldName, tombstones the old name, adds the offset for the new name
        return 0;
    }

    void rebuild() {
        // can can just rebuild the index if we have a lot of tombstones instead of growing
    }

    void grow() {
        //
    }



    // PYTHON INTERFACE

    @__init__
    this(uint size) {
        initialize(size);
    }

    @__repr__
    string _repr_() {return "__repr__";}

    @__str__
    string _str_() {return "__str__";}

    @__bool__
    int _bool_() {return count > 0;}



}




// check out  https://github.com/atilaneves/concepts  to see if that can help
