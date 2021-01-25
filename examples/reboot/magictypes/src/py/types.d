module py.types;

import std.algorithm : map;
import std : array;
import std.stdio : writeln;

import deimos.python.object : PyObject, PyObject_TypeCheck, Py_INCREF, Py_None;
import deimos.python.abstract_ : PyObject_IsInstance;
import pyd.make_object : python_to_d, d_to_python;
import pyd.references : PydTypeObject;

import d.types : _MyType=MyType, MyTypeManager;
import py._utils : Py_RETURN_NOTIMPLEMENTED;



private MyTypeManager _tm;

static this() {
    _tm = MyTypeManager(1);
}

// needs to support hash and == too - as the type will be addable to tuples and used as keys for dictionaries


// COULDDO follow tp_richcompare in pyd

 //pyd doesn't support opBinary for struct so we'll make this a class
export class BType {
    private _MyType t;

    PyObject* opBinary(string op)(PyObject* rhs) if (op == "+") {return BType__add__(this, rhs);}
    PyObject* opBinaryRight(string op)(PyObject* lhs) if (op == "+") {return BType__radd__(lhs, this);}
    //PyObject* opBinaryRight(string op)(PyObject* lhs) if (op == "in") {return BType__contains__(lhs, this);}


    //bool opEquals(const PyObject* rhs) const {
    //    // if the
    //}

    this(string name) {
        this.t = _tm.newType(name);
    }

    this(int id) {
        this.t = _tm.newType(id);
    }

    this(_MyType t) {
        this.t = t;
    }

    @property
    int id() {return t.id;}

    @property
    string name() {return _tm.name(t);}

    override string toString() {return _tm.name(t);}

    // opCmp should be int opCmp(ref const S s) const { ... } however that isn't
    // handled by autowrap:pyd hence the removal remove const and ref

    int opCmp(PyObject* that) {
        // class version
        if (!PyObject_IsInstance(that, cast(PyObject*)&PydTypeObject!(BType)) ) {return 1;}    // ugh
        BType thatBType = python_to_d!BType(that);
        return this.t.opCmp(thatBType.t);
    }

    //int opCmp(PyObject* that) {
    //    // struct version
    //    if (!PyObject_TypeCheck(that, &PydTypeObject!(BType*))) {return 1;}    // ugh
    //    BType thatBType = python_to_d!BType(that);
    //    return this.t.opCmp(thatBType.t);
    //}





    //int idSegFaultHere() {return this.id;}
}



// either pyd or autowrap is a little aggressive on suppressing errors in the wrappers - use private free functions so
// we get dmd compiler error messages

private PyObject* BType__add__(BType lhs, PyObject* rhs) {
    //writeln("BType__add__");
    if (!PyObject_IsInstance(rhs, cast(PyObject*)&PydTypeObject!(BType)) ) {return Py_RETURN_NOTIMPLEMENTED();}
    return d_to_python(BSumType([lhs, python_to_d!BType(rhs)]));
}

private PyObject* BType__radd__(PyObject* lhs, BType rhs) {
    //writeln("BType__radd__");
    if (!PyObject_IsInstance(lhs, cast(PyObject*)&PydTypeObject!(BType)) ) {return Py_RETURN_NOTIMPLEMENTED();}
    return d_to_python(BSumType([python_to_d!BType(lhs), rhs]));
}

private PyObject* BType__contains__(PyObject* lhs, BType rhs) {
    //writeln("BType__contains__");

    if (!PyObject_IsInstance(lhs, cast(PyObject*)&PydTypeObject!(BType)) ) {return Py_RETURN_NOTIMPLEMENTED();}
    _MyType _lhs = (python_to_d!BType(lhs)).t;
    return Py_INCREF(Py_None);
    //return d_to_python(_tm.aCompletelyInB( (python_to_d!BType(lhs)).t, ptRhs.t ));
}




export BType BTypeFromId (int id) {return new BType(id);}
export BType BSumType(BType[] sum) {
    return new BType(_tm.newSumType(
        sum.map!((x) => x.t).array
    ));
}

export BType[] typesInSum(BType t) {
    return _tm.typesInSum(t.t).map!(componentType => new BType(componentType.id)).array;
}
//struct version
//export BType[] typesInSum(BType t) {
//    return cast(BType[]) _tm.typesInSum(cast(_MyType) t);
//}

//export size_t sizeOfCoo() {return Coo.sizeof;}
//export size_t sizeOfDoo() {return Doo.sizeof;}

//class Foo {
//    int _i;
//    this(int i) {
//        _i = i;
//    }
//    Foo opBinary(string op)(Foo that) if(op == "+") {
//        return new Foo(_i + f._i);                          // this shouldn't compile but it does
//    }
//    override string toString() {
//        import std.conv: text;
//        return text("Foo(", _i, ")");
//    }
//}
//
//class Coo {
//    int _i;
//    this(int i) {
//        _i = i;
//    }
//    Coo opBinary(string op)(Coo f) if(op == "+") {
//        return new Coo(_i + f._i);
//    }
//
//    override string toString() {
//        import std.conv: text;
//        return text("Coo(", _i, ")");
//    }
//
//    string __str__() {return this.toString();}
//}
//
//struct Doo {
//    int _i;
//    this(int i) {
//        _i = i;
//    }
//    Doo opBinary(string op)(Doo that) if(op == "+") {
//        return new Doo(_i + that._i);               // new is vital here
//    }
//    string toString() {
//        import std.conv: text;
//        return text("Doo(", _i, ")");
//    }
//}
//
