module d.types;

import std.exception : enforce;
import std.algorithm : sort;
import std.conv : to;
import std.algorithm.mutation : SwapStrategy;



class Urm {
    int opBinaryRight(string op)(int lhs) if (op == "^^") {
        return 1;
    }
    int opBinary(string op)(int lhs) if (op == "^^") {
        return 1;
    }
}


struct MyTypeManager {
    enum NAME_UNKNOWN = -1;
    string[] names;// = new string[0];
    int[ string] idByName;
    int[][ int] sumById;
    int idCount = 0;
    int sumTypeNameSeed = 1;
    Urm u = new Urm();

    MyType newType( string name) {
        int i = 1 ^^ u;
        int j = u ^^ 1;
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
        return MyType( id);
    }

    MyType newType( int id) {
        enforce(id < idCount, "Unknown id");
        return MyType(id);
    }


    MyType newSumType( MyType[] sum, string name=null) {
        // union of all in sum
        foreach(i, MyType t; sum) {
            enforce( t.id < idCount, "Unknown id "~to!string( t.id));
        }
        int[] orderedSum = cast( int[]) sum.dup;
        orderedSum.sort!( "a < b", SwapStrategy.stable);
        foreach( id, s; sumById) {
            if ( orderedSum == s) { return MyType( id);}
        }
        if ( name is null) {
            name = "s"~to!string( sumTypeNameSeed);
            sumTypeNameSeed += 1;
        }
        MyType answer = newType( name);
        sumById[ answer.id] = orderedSum;
        return answer;
    }

    bool isSumType( MyType t) { return sumById.get( t.id, []).length > 0;}

    MyType[] typesInSum( MyType t) {
        int[] ids = sumById.get( t.id, []);
        enforce( ids.length > 0, "Not a sum type");
        return cast( MyType[]) ids;
    }

    bool aCompletelyInB( MyType a, MyType b) {
        // could implement as a == (a.intersect( b))
        if ( isSumType( a)) {
            if ( isSumType( b)) {
                return true;    //
            } else {
                return true;
            }
        } else {
            if ( isSumType( b)) {
                return true;
            } else {
                return a.id == b.id;
            }
        }
    }

    string name( MyType t) { return names[ t.id];}

    this( int dummy) {
        newType( "null");
        newType( "utf8");
        newType( "i32");
        newType( "f64");
        newType( "bool");
    }

}



struct MyType {
    int id;
    int opCmp( ref const MyType that) {
        return id < that.id ? -1 : ( id > that.id ? 1 : 0);
    }
    bool opEquals()( auto ref const MyType rhs) const @safe pure nothrow { return this.id.opEquals( rhs.id);}  // for l-values and r-values
    size_t toHash() const @safe pure nothrow { return this.id;}
}


