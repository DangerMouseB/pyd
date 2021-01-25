import play
print(dir(play))

from play import Visible, BTypeFromId, BType, BSumType, typesInSum, Foo, Doo, Coo, sizeOfCoo, sizeOfDoo

print(sizeOfCoo())
print(sizeOfDoo())



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



def main():
    testInvisible()
    testFooDoo()
    testBasic()
    testMyTypeCreation()
    testMySumType()
    testComparisons()


if __name__ == '__main__':
    main()
