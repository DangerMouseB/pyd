module bones_vm_ex2.types;

import std.exception : enforce;
import std.algorithm : sort, canFind;
import std.conv : to;
import std.algorithm.mutation : SwapStrategy;
import std.algorithm : map;
import std : array;
import std.stdio : writeln;
import std.traits : Unqual;

import deimos.python.object : PyObject, PyObject_TypeCheck, Py_INCREF, Py_None, PyTypeObject;
import deimos.python.abstract_ : PyObject_IsInstance;

import pyd.class_wrap : wrapped_classes;
import pyd.conversions.d_to_python : d_to_python;
import pyd.conversions.python_to_d : python_to_d;
import pyd.references : PydTypeObject, is_wrapped;
import pyd.pydobject : PydObject;

import bones_vm.pyig.attributes;   // args, kwargs, __repr__ etc
import bones_vm.pyig.utils : Py_RETURN_NOTIMPLEMENTED;
import bones_vm.pyig.constants : Contains;



private BTypeManager _tm;


static this() {
    _tm = BTypeManager();

    _tm.typeIdOrNew("null");
    _tm.typeIdOrNew("utf8");
    _tm.typeIdOrNew("i32");
    _tm.typeIdOrNew("f64");
    _tm.typeIdOrNew("bool");

}


struct BTypeManager {
    enum NAME_UNKNOWN = -1;
    string[] names;// = new string[0];
    int[ string] idByName;
    int[][ int] sumById;
    int idCount = 0;
    int sumTypeNameSeed = 1;

    int typeIdOrNew( string name) {
        int id = idByName.get( name, NAME_UNKNOWN);
        if ( id == NAME_UNKNOWN) {
            id = idCount;
            idCount += 1;
            if ( idCount > idByName.length) {
                names.length += 128;
            }
            names[ id] = name;
            idByName[ name] = id;
        }
        return id;
    }

    BType idToBType( int id) {
        enforce(id < idCount, "Unknown id");
        return BType(id, 0);
    }


    BType newSumType( BType[] sum, string name=null) {
        // union of all in sum
        foreach(i, BType t; sum) {
            enforce(t.id < idCount, "Unknown id "~to!string(t.id));
        }
        int[] orderedSum = cast(int[]) sum.dup;
        orderedSum.sort!("a < b", SwapStrategy.stable);
        foreach(id, s; sumById) {
            if (orderedSum == s) {return BType(id, 0);}
        }
        if (name is null) {
            name = "s"~to!string(sumTypeNameSeed);
            sumTypeNameSeed += 1;
        }
        BType answer = BType(typeIdOrNew(name), 0);
        sumById[answer.id] = orderedSum;
        return answer;
    }

    bool isSumType(BType t) {return sumById.get(t.id, []).length > 0;}

    BType[] typesInSum(BType t) {
        int[] ids = sumById.get(t.id, []);
        if (ids.length == 0) {
            return [t];
        } else {
            return cast(BType[]) ids;
        }
    }

    bool isACompletelyInB(BType a, BType b) {
        // could implement as a == (a.intersect(b))
        if (isSumType(a)) {
            if (isSumType(b)) {
                return true;    //
            } else {
                return true;
            }
        } else {
            if (isSumType(b)) {
                return true;
            } else {
                return a.id == b.id;
            }
        }
    }

    string name(BType t) {return names[t.id];}

}

@include BType BSumType(BType[] sum) {return _tm.newSumType(sum);}
@include BType[] typesInSum(BType t) {return _tm.typesInSum(t);}


@include
struct BType {
    private int id;

    private this(int id, int annoyingParam) {
        this.id = id;
    }

    bool opEquals(const BType that) const {return this.id == that.id;}
    size_t toHash() const @safe pure nothrow {return this.id;}




    // python interface

    @property
    string name() {return _tm.name(this);}

    @__richcmpfunc__
    PyObject* richcmpfunc(PyObject* _that, int op) {
        import bones_vm.pyig.constants : Py_EQ, Py_NE;
        if (!PyObject_TypeCheck(_that, &PydTypeObject!(BType*))) {return Py_RETURN_NOTIMPLEMENTED();}
        BType that = python_to_d!BType(_that);
        if (op == Py_EQ) {return d_to_python(this == that);}
        else if (op == Py_NE) {return d_to_python(this != that);}
        else {return Py_RETURN_NOTIMPLEMENTED();}
    }

    @__hash__
    size_t toHash() const @safe pure nothrow {return this.id;}

    @__init__
    this(string name) {id = _tm.typeIdOrNew(name);}

    @__repr__
    string _repr_() {return _tm.name(this);}


    @__call__ @args @kwargs
    PyObject* opCall(PyObject* args, PyObject* kwargs) {
        return d_to_python([args, kwargs]);
    }


    @__add__
    PyObject* opBinary(string op)(PyObject* _rhs) if (op == "+") {
        if (!PyObject_TypeCheck(_rhs, &PydTypeObject!(BType*))) {return Py_RETURN_NOTIMPLEMENTED();}
        return d_to_python(BSumType([this, python_to_d!BType(_rhs)]));
    }

    @__radd__ @__contains__
    PyObject* opBinaryRight(string op)(PyObject* _lhs) if (op == "+") {
        if (!PyObject_TypeCheck(_lhs, &PydTypeObject!(BType*))) {return Py_RETURN_NOTIMPLEMENTED();}
        return d_to_python(BSumType([python_to_d!BType(_lhs), this]));
    }
    int opBinaryRight(string op)(PyObject* _lhs) if (op == "in") {
        if (!PyObject_TypeCheck(_lhs, &PydTypeObject!(BType*))) {return Contains.Error;}
        BType lhs = python_to_d!BType(_lhs);
        if (_tm.typesInSum(this).canFind(lhs))
            return Contains.True;
        else
            return Contains.False;
    }


}







