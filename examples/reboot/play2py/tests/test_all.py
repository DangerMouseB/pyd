import play
print(dir(play))

# from play import Visible, BTypeFromId, BType, BSumType, typesInSum, Foo, Doo, Coo, sizeOfCoo, sizeOfDoo, \
from play import Magic

# print(sizeOfCoo())
# print(sizeOfDoo())


def testInvisible():
    try:
        from play import Invisible
        raise RuntimeError("Invisible is visible!")
    except ImportError:
        pass

def testBasic():
    v = Visible(1)
    print("Visible: ", v.id)
    assert v.id == 1

def testFooDoo():
    print(str(Coo(1) + Coo(1)))
    assert str(Coo(1) + Coo(1)) == "Coo(2)"
    # Coo(1) + 1
    try:
        assert str(Foo(1) + Foo(1)) == "Foo(2)"
    except TypeError:
        pass
    try:
        assert str(Doo(1) + Doo(1)) == "Doo(2)"
    except TypeError:
        pass

def testMyTypeCreation():
    tUTF8 = BType("utf8")
    print("tUTF8: ", tUTF8)
    print("id: ", tUTF8.id)
    print("name: ", tUTF8.name)
    print("type: ", type(tUTF8))
    print("dir: ", dir(tUTF8))

    print(BTypeFromId(1))
    print(BTypeFromId(1).name)
    assert BType("utf8").id == 1
    assert BTypeFromId(1).name == "utf8"

def testMySumType():
    s1 = BSumType([BType("utf8"), BType("null")])
    print(s1.id, s1.name)
    print(typesInSum(s1))
    s2 = BSumType([BType("utf8"), BType("null")])
    s3 = BSumType([BType("i32"), BType("null")])
    assert s1.id == s2.id
    assert s1 is not s2
    assert s1.id != s3.id

def testComparisons():
    assert BType("utf8") == BType("utf8")
    assert (BType("utf8"),) == (BType("utf8"),)
    assert BType("utf8") != str
    assert str != BType("utf8")
    assert (BType("utf8"),) != (str,)
    assert (str,) != (BType("utf8"),)

def testComparisons():
    assert '__add__' in dir(BType("i32"))
    s1 = BType("i32") + BType("null")
    print(s1.id, s1.name)
    try:
        str + BType("null")
    except TypeError:
        pass
    try:
        BType("i32") + str
    except TypeError:
        pass

def testMagic():
    m = Magic()
    assert m + 1 == '__add__'
    assert 1 + m == '__radd__'
    assert m % 1 == '__mod__'
    assert 1 % m == '__rmod__'
    assert m ** 1 == '__pow__'
    # assert 1 ** m == '__rpow__'

    assert m << 1 == '__lshift__'
    assert 1 << m == '__rlshift__'
    assert m >> 1 == '__rshift__'
    assert 1 >> m == '__rrshift__'

    assert m & 1 == '__and__'
    assert 1 & m == '__rand__'
    assert m | 1 == '__or__'
    assert 1 | m == '__ror__'
    assert m ^ 1 == '__xor__'
    assert 1 ^ m == '__rxor__'

    assert repr(m) == '__repr__'
    assert str(m) == '__str__'

    assert m("hello") == '__call__'

    assert m[0] == '__index__'
    assert m[0:5] == '__index__'
    assert m[0:5:5] == '__index__'
    assert m[0,0] == '__index__'


# assert (+m) == '__pos__'
    # assert -m == '__neg__'
    # assert ~m == '__invert__'
    assert abs(m) == '__abs__'




def main():
    # testInvisible()
    # testFooDoo()
    # testBasic()
    # testMyTypeCreation()
    # testMySumType()
    # testComparisons()
    testMagic()


if __name__ == '__main__':
    main()
