from coppertop import cout, AssertRaises


import bones_vm_ex2
print(dir(bones_vm_ex2))


from bones_vm_ex2 import BType, BSumType, typesInSum, BHashTable




def testBTypeCreation():
    tUTF8 = BType("utf8")
    print("tUTF8: ", repr(tUTF8))
    assert(repr(tUTF8) == "utf8")
    print("type: ", type(tUTF8))
    print("dir: ", dir(tUTF8))

def testComparisons():
    assert BType("utf8") == BType("utf8")
    assert BType("utf8") != BType("bool")
    assert (BType("utf8"),) == (BType("utf8"),)
    assert BType("utf8") != str
    assert str != BType("utf8")
    assert (BType("utf8"),) != (str,)
    assert (str,) != (BType("utf8"),)
    with AssertRaises(TypeError):
        BType("utf8") < BType("utf8")

def testMySumType():
    s1 = BSumType([BType("utf8"), BType("null")])
    print(s1)
    print(typesInSum(s1))
    s2 = BSumType([BType("utf8"), BType("null")])
    s3 = BSumType([BType("i32"), BType("null")])
    assert s1 == s2
    assert s1 is not s2
    assert s1 != s3

def testAddAndIn():
    s1 = BSumType([BType("utf8"), BType("null")])
    assert(BType("null") in s1)
    assert(s1 not in BType("i32"))
    print(dir(BType("i32")))
    assert '__add__' in dir(BType("i32"))
    print("BType + BType")
    s1 = BType("i32") + BType("null")
    print(s1)
    with AssertRaises(TypeError):
        print("BType + str")
        BType("i32") + str
    with AssertRaises(TypeError):
        print("str + BType")
        str + BType("null")


def testCall():
    num = BType("f64")
    GBP = num("GBP")
    GBPUSD = num(d="GBP", f="USD")
    assert GBP == [("GBP",), {}]
    assert GBPUSD == [(), dict(d="GBP", f="USD")]

def testGetItemEtAl():
    bytes = BBuffer(1)
    bytes[0] = 5
    assert bytes[0] == 5

def testHashTable():
    counts = BHashTable(1, 2)
    assert counts+"fred" == "fred"
    with AssertRaises(TypeError):
        "fred"+counts
    assert +counts == "+BHashTable"
    assert str(counts) == "__str__"
    assert repr(counts) == "__repr__"
    if counts:
        assert False
    assert len(counts) == 0
    sFred = BSym("fred")
    sJoe = BSym("joe")
    counts[sFred] == 5
    assert len(counts) == 1
    assert counts[sFred] == 5
    assert sJoe not in counts
    counts[sJoe] += 1
    assert len(counts) == 2
    assert counts[sJoe] == 1
    del[sFred]
    assert len(counts) == 1
    assert sFred not in counts
    assert counts._numTombstones == 1   # or at small size does the array shrink?

def testGetAttrEtAl():
    tPerson = BProduct(name=str, age=int);
    penfold = BStruct(tPerson, name="Penfold", age=35)
    assert penfold.name == "Penfold"
    assert penfold.age == 35
    with AssertRaises(TypeError):
        address = penfold.address

def main():
    testBTypeCreation()
    testComparisons()
    testMySumType()
    testAddAndIn()
    testCall()
    testHashTable()
    # testHashIndex()
    # testGetItemEtAl()
    # testGetAttrEtAl()

if __name__ == '__main__':
    main()
