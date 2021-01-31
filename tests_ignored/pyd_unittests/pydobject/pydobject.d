import std.range;
import pyd.pyd, pyd.embedded;

static this() {
    on_py_init({
    add_module!(ModuleName!"testing")();
    });
    py_init();
}

// PydObject as dict
unittest {
    auto g = d_to_pydobject(["a":"b"]);
    version(Python_3_0_Or_Later) {
        assert((g.keys()).toString() == "['a']");
        assert((g.values()).toString() == "['b']");
        assert(g.items().toString() == "[('a', 'b')]");
        assert(g["a"].toString()  == "b");
        g["b"] = d_to_pydobject("truck");
        assert(g.items().toString() == "[('a', 'b'), ('b', 'truck')]" ||
                g.items().toString() == "[('b', 'truck'), ('a', 'b')]");
        foreach(key, val; g) {
            if (key.toString() == "a") assert(val.toString() == "b");
            else if (key.toString() == "b") assert(val.toString() == "truck");
            else assert(false);
        }
        g.del_item("b");
        assert((g.items()).toString() == "[('a', 'b')]");
        auto g2 = g.copy();
        assert((g2.items()).toString() == "[('a', 'b')]");
        g2.del_item("a");
        assert((g2.items()).toString() == "[]");
        assert((g.items()).toString() == "[('a', 'b')]");
        g2 = d_to_pydobject(["k":"z", "a":"f"]);
        g.merge(g2);
        assert(g.items().toString() == "[('k', 'z'), ('a', 'f')]" ||
                g.items().toString() == "[('a', 'f'), ('k', 'z')]");
        g = d_to_pydobject(["a":"b"]);
        g.merge(g2,false);
        assert(g.items().toString() == "[('k', 'z'), ('a', 'b')]" ||
                g.items().toString() == "[('a', 'b'), ('k', 'z')]");
        assert("k" in g);
        assert("a" in g);
        assert(g.has_key("k"));
        assert(g.has_key("a"));
    }else{
        assert((g.keys()).toString() == "[u'a']");
        assert((g.values()).toString() == "[u'b']");
        assert(g.items().toString() == "[(u'a', u'b')]");
        assert(g["a"].toString()  == "b");
        g["b"] = d_to_pydobject("truck");
        assert(g.items().toString() == "[(u'a', u'b'), (u'b', u'truck')]" ||
                g.items().toString() == "[(u'b', u'truck'), (u'a', u'b')]");
        foreach(key, val; g) {
            if (key.toString() == "a") assert(val.toString() == "b");
            else if (key.toString() == "b") assert(val.toString() == "truck");
            else assert(false);
        }
        g.del_item("b");
        assert((g.items()).toString() == "[(u'a', u'b')]");
        auto g2 = g.copy();
        assert((g2.items()).toString() == "[(u'a', u'b')]");
        g2.del_item("a");
        assert((g2.items()).toString() == "[]");
        assert((g.items()).toString() == "[(u'a', u'b')]");
        g2 = d_to_pydobject(["k":"z", "a":"f"]);
        g.merge(g2);
        assert(g.items().toString() == "[(u'k', u'z'), (u'a', u'f')]" ||
                g.items().toString() == "[(u'a', u'f'), (u'k', u'z')]");
        g = d_to_pydobject(["a":"b"]);
        g.merge(g2,false);
        assert(g.items().toString() == "[(u'k', u'z'), (u'a', u'b')]" ||
                g.items().toString() == "[(u'a', u'b'), (u'k', u'z')]");
        assert("k" in g);
        assert("a" in g);
        assert(g.has_key("k"));
        assert(g.has_key("a"));
    }

    g = d_to_pydobject([5:7, 8:10]);
    g.clear();
    assert(g.length() == 0);
}

// PydObject as list
unittest {
    auto g = d_to_pydobject(["a","b","c","e"]);
    assert(d_to_pydobject("a") in g);
    assert("a" in g);
    assert("e" in g);
    foreach(i,x; g) {
        if(i == d_to_pydobject(0)) assert(x == d_to_pydobject("a"));
        if(i == d_to_pydobject(1)) assert(x == d_to_pydobject("b"));
        if(i == d_to_pydobject(2)) assert(x == d_to_pydobject("c"));
        if(i == d_to_pydobject(3)) assert(x == d_to_pydobject("e"));
    }
    {
        int i = 0;
        foreach(x; g) {
            if(i == (0)) assert(x == d_to_pydobject("a"));
            if(i == (1)) assert(x == d_to_pydobject("b"));
            if(i == (2)) assert(x == d_to_pydobject("c"));
            if(i == (3)) assert(x == d_to_pydobject("e"));
            i++;
        }
    }
    auto g2 = g ~ d_to_pydobject(["a","c","e"]);
    assert(g2 == d_to_pydobject(["a","b","c","e","a","c","e"]));
    g ~= d_to_pydobject(["a","c","e"]);
    assert(g == d_to_pydobject(["a","b","c","e","a","c","e"]));
    //writeln(g.count(d_to_pydobject(["c","e"])));
    assert(g.count(d_to_pydobject("c")) == 2);
    assert(g.index(d_to_pydobject("b")) == 1);
    g.insert(3, d_to_pydobject("X"));
    assert(g == d_to_pydobject(["a","b","c","X","e","a","c","e"]));
    g.append(d_to_pydobject("Z"));
    assert(g == d_to_pydobject(["a","b","c","X","e","a","c","e", "Z"]));
    g.sort();
    assert(g == d_to_pydobject(["X","Z","a","a","b","c","c","e","e"]));
    g.reverse();
    assert(g == d_to_pydobject(["e","e","c","c","b","a","a","Z","X"]));
    g = d_to_pydobject(["a","b"]);
    assert(g * 2 == d_to_pydobject(["a","b","a","b"]));
    g *= 2;
    assert(g == d_to_pydobject(["a","b","a","b"]));
    g = d_to_pydobject(["a","b"]);
    assert(g ~ ["z"] == d_to_pydobject(["a","b","z"]));
    assert(g ~ d_to_pydobject(["z"]) == d_to_pydobject(["a","b","z"]));
    g ~= d_to_pydobject(["f","h"]);
    assert(g == d_to_pydobject(["a","b","f","h"]));
}

// PydObject as number (int? long? who know?)
unittest {
    auto n = d_to_pydobject(1);
    n = n + d_to_pydobject(2);
    assert(n == d_to_pydobject(3));
    assert(d_to_pydobject(2) + 1 == d_to_pydobject(3));
    n = n * d_to_pydobject(12);
    assert(n == d_to_pydobject(36));
    n = n / d_to_pydobject(5);
    version(Python_3_0_Or_Later) {
        assert(n == d_to_pydobject(7.2));
    }else{
        assert(n == d_to_pydobject(7));
    }
    n = d_to_pydobject(36).floor_div(d_to_pydobject(5));
    assert(n == d_to_pydobject(7));
    n = d_to_pydobject(36).true_div(d_to_pydobject(5));
    assert(n == d_to_pydobject(7.2)); // *twitch*
    n = (d_to_pydobject(37).divmod(d_to_pydobject(5)));
    assert(n.toString() == "(7, 2)" || n.toString() == "(7L, 2L)");
    n = d_to_pydobject(37) % d_to_pydobject(5);
    assert(n == d_to_pydobject(2));
    n = d_to_pydobject(3) ^^ d_to_pydobject(4);
    assert(n == d_to_pydobject(81));
    // holy guacamole! I didn't know Python's pow() did this!
    n = d_to_pydobject(13).pow(d_to_pydobject(3), d_to_pydobject(5));
    assert(n == (d_to_pydobject(13) ^^ d_to_pydobject(3)) % d_to_pydobject(5));
    assert(n == d_to_pydobject(2));
    assert(d_to_pydobject(1).abs() == d_to_pydobject(1));
    assert(d_to_pydobject(-1).abs() == d_to_pydobject(1));
    assert(~d_to_pydobject(2) == d_to_pydobject(-3));
    assert((d_to_pydobject(15) >> d_to_pydobject(3)) == d_to_pydobject(1));
    assert(d_to_pydobject(1) << d_to_pydobject(3) == d_to_pydobject(8));
    assert((d_to_pydobject(7) & d_to_pydobject(5)) == d_to_pydobject(5));
    assert((d_to_pydobject(17) | d_to_pydobject(5)) == d_to_pydobject(21));
    assert((d_to_pydobject(17) ^ d_to_pydobject(5)) == d_to_pydobject(20));

    n = d_to_pydobject(1);
    n += d_to_pydobject(3);
    assert(n == d_to_pydobject(4));
    n -= d_to_pydobject(2);
    assert(n == d_to_pydobject(2));
    n *= d_to_pydobject(7);
    assert(n == d_to_pydobject(14));
    n /= d_to_pydobject(3);
    version(Python_3_0_Or_Later) {
        assert(n == d_to_pydobject(14./3)); // 4.6bar
        assert(n.as_long() == d_to_pydobject(4));
        n = d_to_pydobject(4);
    }else{
        assert(n == d_to_pydobject(4));
    }
    n %= d_to_pydobject(3);
    assert(n == d_to_pydobject(1));
    n <<= d_to_pydobject(4);
    assert(n == d_to_pydobject(16));
    n >>= d_to_pydobject(1);
    assert(n == d_to_pydobject(8));
    n |= d_to_pydobject(17);
    assert(n == d_to_pydobject(25));
    n &= d_to_pydobject(19);
    assert(n == d_to_pydobject(17));
    n ^= d_to_pydobject(11);
    assert(n == d_to_pydobject(26));
}

// PydObject as python object
unittest {
    py_stmts(q"<
    class X:
        def __init__(self):
            self.a = "widget"
            self.b = 515
        def __add__(self, g):
            return self.b + g;
        def __getitem__(self, i):
            return 1000 + i*2
        def __setitem__(self, i, j):
            self.b = 100*j + 10*i;
        def foo(self):
            return self.a
        def bar(self, wongo, xx):
            return "%s %s b %s" % (self.a, wongo, self.b)
>", "testing");
    auto x = py_eval("X()","testing");
    assert(x.getattr("a") == d_to_pydobject("widget"));
    assert(x.a == d_to_pydobject("widget"));
    assert(x.method("foo") == d_to_pydobject("widget"));
    assert(x[4] == d_to_pydobject(1008));
    auto xb = x.b;
    x[4] = 5;
    assert(x.b == d_to_pydobject(540));
    x.b = xb;
    // *#^$&%#*(@*&$!!!!!
    // I long for the day..
    //assert(x.foo != x.foo());
    //assert(x.foo() == py("widget"));
    assert(x.foo.opCall() == py("widget"));
    assert(x.bar(py(9.5),1) == py("widget 9.5 b 515"));
    assert(x.bar(9.5,1) == py("widget 9.5 b 515"));
    assert(x + 10 == py(525));
}

// Buffer interface
version(Python_2_6_Or_Later) {
    unittest {
        auto arr = py_eval("bytearray([1,2,3])");
        auto b = arr.buffer_view();
        import std.stdio;
        assert(b.format == "B");
        assert(b.itemsize == 1);
        if(b.has_simple) {
            assert(b.buf == [1,2,3]);
        }
        if(b.has_nd) {
            assert(b.ndim == 1);
            assert(b.shape == [3]);

        }
        if(b.has_strides) {
            assert(b.strides == [1]);
        }
        if(b.has_indirect) {
            assert(b.suboffsets == []);
        }
    }

    unittest {
        import std.stdio;

        PydObject numpy;
        try {
            numpy = py_import("numpy");
        }catch(PythonException e) {
            writeln("If you had numpy, we could do some more unittests");
        }

        if(numpy) {
            py_stmts("
                    from numpy import eye
                    a = eye(4,k=1)"
                    ,
                    "testing");
            PydObject ao = py_eval("a","testing");
            auto b = ao.buffer_view();
            assert(b.format == "d");
            assert(b.itemsize == 8);
            assert(b.has_nd);
            assert(b.ndim == 2);
            assert(b.c_contiguous);
            assert(b.shape == [4,4]);
            assert(b.strides == [32, 8]);
            assert(b.suboffsets == []);
            // ao is
            // 0 1 0 0
            // 0 0 1 0
            // 0 0 0 1
            // 0 0 0 0
            assert(b.item!double(1,0) == 0);
            assert(b.item!double(0,1) == 1);
        }
    }
}

unittest {
    static assert(!isInputRange!PydObject);
    static assert(!isForwardRange!PydObject);
    static assert(!isBidirectionalRange!PydObject);
    static assert(!isRandomAccessRange!PydObject);
    // :(
    //static assert(!isOutputRange!(PydObject, PydObject));
}

void main(){}
