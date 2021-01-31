module bones_vm_ex2.sym;

import std.conv;
import std.stdio;
import std.format;
import std.algorithm.mutation : SwapStrategy;
import std.algorithm;


alias SYM_ID = ushort;
enum ushort MISSING_SYM = 65535u;

// id = 0 is reserved for uninitialised array entry in a hash index
// MISSING_SYM is used for tombstones


// numGets, numSets, numProbes, numTombstones, numEntries, numResize, numRehash, size



// the idea of keeping the sort order of Sym is to make comparisons fast (for faster groupBy), additionally a counting sort
// or radix sort based on order may prove to be quick than a quick / tim sort



private SymManager _sm;


// COULDDO
// store the strings compacted into a single contiguous area
// make sortedIds faster by


struct SymManager {
    private string[] _stringById;
    private SYM_ID[string] _idByString;       // hash map for finding existing sym
    private SYM_ID _symCount = 0;
    private SYM_ID[] _order;                   // stores the sort order, e.g. {joe->1, fred-> 0, sally -> 2}
    private auto _lastSortedCount = 0;


    // this could be made faster (if necessary) by only sorting the new elements and then merging the old list
    // of sorted elements with the new list


    SYM_ID[] sortIds() {
        //MUSTDO fix

        //if (_symCount == 0) return SY;

        SYM_ID[] ids = new SYM_ID[_symCount];
        // get the already sorted Sym ids
        foreach(id ; 0 .. _lastSortedCount) {
            ids[_order[id]] = to!SYM_ID(id);
        }
        // add more recently added Sym ids
        foreach(id ; _lastSortedCount .. _symCount) {
            ids[id] = to!SYM_ID(id);
        }
        if (_symCount == _lastSortedCount) return ids;

        // sort them in ascending order by name
        alias cmpStrings = (idX, idY) => this._stringById[idX] < this._stringById[idY];
        ids.sort!(cmpStrings, SwapStrategy.stable).release;

        // save the answer
        foreach (pos, id ; ids) {
            _order[id] = to!SYM_ID(pos);
        }
        _lastSortedCount = _symCount;
        return ids;
    }


    Sym newSym(string name) {
        SYM_ID id = _idByString.get(name, MISSING_SYM);
        if (id == MISSING_SYM) {
            id = _symCount;
            _symCount += 1;
            if ((id + 1) == _stringById.length) {
                _stringById.length += 100;
                _order.length += 100;
            }
            _stringById[id] = name;
            _idByString[name] = id;
        }
        return Sym(cast(SYM_ID) id);
    }

}



static this() {
    _sm = SymManager();
}



struct Sym {
    SYM_ID id;
    //this(string name) {
    //
    //}

    string toString() { return "`"~_sm._stringById[id]; }

    @property
    string name() { return _sm._stringById[id]; }

    // autowrap:pyd doesn't handle this
    //void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) const {
    //    if (fmt.spec == 's') {
    //        sink("`\"");
    //        sink(_stringById[id]);
    //        sink("\"");
    //    } else {
    //        sink("Sym(");
    //        sink(_stringById[id]);
    //        sink(")");
    //    }
    //}


    // autowrap:pyd doesn't do opEquals at all - this can be for d only
    bool opEquals(ref const Sym rhs) const {
        return id == rhs.id;
    }

    extern (D) size_t toHash() const nothrow @safe {
        return id.hashOf();
    }

    // opCmp should be int opCmp(ref const S s) const { ... } however that isn't handled by autowrap:pyd
    // so remove const and ref
    int opCmp(Sym rhs) {
        if (id == rhs.id) return 0;
        if (_sm._symCount > _sm._lastSortedCount) _sm.sortIds();
        if (_sm._order[id] < _sm._order[rhs.id]) return -1;
        return 1;
    }

}


//export symId[] countSortIndex(Sym[] syms) {
//    // count (in the correct order)
//    symId[] counts = new symId[_symCount];
//    for (symId i = 0; i < syms.length; i++) {
//        counts[_order[syms[i].id]] += 1;
//    }
//    // integrate
//    for (symId i = 1; i < counts.length; i++) {
//        counts[i] += counts[i-1];
//    }
//    // rotate
//    for (symId i = cast (symId) counts.length - 1; i > 0; i--) {
//        counts[i] = counts[i-1];
//    }
//    counts[0] = 0;
//    // build index
//    symId[] index = new symId[syms.length];
//    for (symId i = 0; i < syms.length; i++) {
//        int iCounts = _order[syms[i].id];
//        index[symId[iCounts]] = i;
//        symId[iCounts] += 1;
//    }
//    return index;
//}