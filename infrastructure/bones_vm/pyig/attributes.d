module bones_vm.pyig.attributes;

import std.traits : hasUDA;

enum kwargs;
enum args;
enum include;


// unaryfunc - PyObject *(*unaryfunc)(PyObject *)¶
// binaryfunc - (PyObject*, PyObject*) -> PyObject*
// ternaryfunc - (PyObject*, PyObject*, PyObject*) -> PyObject*
// reprfunc - (PyObject*) -> PyObject*
// hashfunc - Py_hash_t (*hashfunc)(PyObject *)
// getattrofunc - PyObject *(*getattrofunc)(PyObject *self, PyObject *attr)
// setattrofunc - int (*setattrofunc)(PyObject *self, PyObject *attr, PyObject *value)
// richcmpfunc - PyObject *(*richcmpfunc)(PyObject *, PyObject *, int)
// getiterfunc - PyObject *(*getiterfunc)(PyObject *)¶
// iternextfunc - PyObject *(*iternextfunc)(PyObject *)
// newfunc - PyObject *(*newfunc)(PyObject *, PyObject *, PyObject *)
// initproc - int (*initproc)(PyObject *, PyObject *, PyObject *)
// destructor - void (*destructor)(PyObject *)
// lenfunc - Py_ssize_t (*lenfunc)(PyObject *)
// objobjargproc - int (*objobjargproc)(PyObject *, PyObject *, PyObject *)
// ssizeargfunc - PyObject *(*ssizeargfunc)(PyObject *, Py_ssize_t)
// ssizeobjargproc - int (*ssizeobjargproc)(PyObject *, Py_ssize_t)
// objobjproc - int (*objobjproc)(PyObject *, PyObject *)
// inquiry - int (*inquiry)(PyObject *self)



// PyTypeObject Definition
// https://docs.python.org/3/c-api/typeobj.html#pytypeobject-definition

//typedef struct _typeobject {
//    PyObject_VAR_HEAD
//    const char *tp_name; /* For printing, in format "<module>.<name>" */
//    Py_ssize_t tp_basicsize, tp_itemsize; /* For allocation */
//
//    /* Methods to implement standard operations */
//
//    destructor tp_dealloc;
//    Py_ssize_t tp_vectorcall_offset;
//    getattrfunc tp_getattr;
//    setattrfunc tp_setattr;
//    PyAsyncMethods *tp_as_async; /* formerly known as tp_compare (Python 2)
//                                    or tp_reserved (Python 3) */
//    reprfunc tp_repr;
//
//    /* Method suites for standard classes */
//
//    PyNumberMethods *tp_as_number;
//    PySequenceMethods *tp_as_sequence;
//    PyMappingMethods *tp_as_mapping;
//
//    /* More standard operations (here for binary compatibility) */
//
//    hashfunc tp_hash;
//    ternaryfunc tp_call;
//    reprfunc tp_str;
//    getattrofunc tp_getattro;
//    setattrofunc tp_setattro;
//
//    /* Functions to access object as input/output buffer */
//    PyBufferProcs *tp_as_buffer;
//
//    /* Flags to define presence of optional/expanded features */
//    unsigned long tp_flags;
//
//    const char *tp_doc; /* Documentation string */
//
//    /* call function for all accessible objects */
//    traverseproc tp_traverse;
//
//    /* delete references to contained objects */
//    inquiry tp_clear;
//
//    /* rich comparisons */
//    richcmpfunc tp_richcompare;
//
//    /* weak reference enabler */
//    Py_ssize_t tp_weaklistoffset;
//
//    /* Iterators */
//    getiterfunc tp_iter;
//    iternextfunc tp_iternext;
//
//    /* Attribute descriptor and subclassing stuff */
//    struct PyMethodDef *tp_methods;
//    struct PyMemberDef *tp_members;
//    struct PyGetSetDef *tp_getset;
//    struct _typeobject *tp_base;
//    PyObject *tp_dict;
//    descrgetfunc tp_descr_get;
//    descrsetfunc tp_descr_set;
//    Py_ssize_t tp_dictoffset;
//    initproc tp_init;
//    allocfunc tp_alloc;
//    newfunc tp_new;
//    freefunc tp_free; /* Low-level free-memory routine */
//    inquiry tp_is_gc; /* For PyObject_IS_GC */
//    PyObject *tp_bases;
//    PyObject *tp_mro; /* method resolution order */
//    PyObject *tp_cache;
//    PyObject *tp_subclasses;
//    PyObject *tp_weaklist;
//    destructor tp_del;
//
//    /* Type attribute cache version tag. Added in version 2.6 */
//    unsigned int tp_version_tag;
//
//    destructor tp_finalize;
//
//} PyTypeObject;



enum __repr__;                      // tp_repr - reprfunc

enum __hash__;                     // tp_hash - hashfunc

enum __call__;                      // tp_call - ternaryfunc

enum __str__;                       // tp_str - reprfunc


// A key difference between __getattr__ and __getattribute__ is that __getattr__
// is only invoked if the attribute wasn't found the usual ways

enum __getattribute__;             // tp_getattro - getattrofunc
enum __getattr__;

enum __setattr__;                   // tp_setattro - setattrofunc
enum __delattr__;

//PyBufferProcs *tp_as_buffer;

enum __doc__;                       // tp_doc - const char *


enum __richcmpfunc__;             // tp_richcompare - richcmpfunc - a function that handles all following
enum __lt__;
enum __le__;
enum __eq__;
enum __ne__;
enum __gt__;
enum __ge__;


enum __iter__;                      // tp_iter - getiterfunc
enum __next__;                     // tp_iternext - iternextfunc


enum __init__;                      // tp_init - initproc
enum __new__;                       // tp_new - newfunc
enum __del__;                       // tp_finalize - destructor



// Number Object Structures - PyNumberMethods* tp_as_number
// https://docs.python.org/3/c-api/typeobj.html#number-object-structures

// sub-slots

enum __add__;           // nb_add - binaryfunc
enum __radd__;

enum __sub__;           // nb_subtract - binaryfunc
enum __rsub__;

enum __mul__;           // nb_multiply - binaryfunc
enum __rmul__;

enum __pow__;           // nb_power - ternaryfunc, nb_inplace_power - ternaryfunc
enum __rpow__;

enum __neg__;           // nb_negative - unaryfunc
enum __pos__;           // nb_positive - unaryfunc
enum __abs__;           // nb_absolute - unaryfunc

enum __bool__;          // nb_bool - inquiry
enum __invert__;        // nb_invert - unaryfunc

enum __lshift__;        // nb_lshift - binaryfunc
enum __rlshift__;
enum __lshift__ip__;    // nb_inplace_lshift - binaryfunc

enum __rshift__;        // nb_rshift - binaryfunc
enum __rrshift__;
enum __rshift__ip__;   // nb_inplace_rshift - binaryfunc

enum __index__;           // nb_index - unary func

enum __matmul__;        // nb_matrix_multiply - binaryfunc
enum __rmatmul__;
enum __matmul__ip__;   // nb_inplace_matrix_multiply - binaryfunc



// Mapping Object Structures - PyMappingMethods* tp_as_mapping
// https://docs.python.org/3/c-api/mapping.html
// https://docs.python.org/3/c-api/typeobj.html#mapping-object-structures

enum __len__mp__;            // mp_length - lenfunc
enum __getitem__mp__;       // mp_subscript - binaryfunc
enum __setitem__mp__;       // mp_ass_subscript - objobjargproc
enum __delitem__mp__;



// Sequence Object Structures - PySequenceMethods* tp_as_sequence
// https://docs.python.org/3/c-api/sequence.html
// https://docs.python.org/3/c-api/typeobj.html#sequence-object-structures

enum __len__;             // sq_length - lenfunc - pyd.class_wrap.Len
enum __add__sq__;       // sq_concat - binaryfunc - pyd.class_wrap.binaryslots - "~": "type.tp_as_sequence.sq_concat"
enum __mul__sq__;       // sq_repeat - ssizeargfunc

enum __getitem__;        // sq_item - ssizeargfunc
enum __setitem__;        // sq_ass_item - ssizeobjargproc
enum __delitem__;
enum __contains__;       // sq_contains - objobjproc - pyd.class_wrap.binaryslots - "in": "type.tp_as_sequence.sq_contains"

enum __add__sq__ip__;     // sq_inplace_concat - binaryfunc - pyd.class_wrap.binaryslots - "~=": "type.tp_as_sequence.sq_inplace_concat"
enum __mul__sq__ip__;     // ssizeargfunc




enum __enter__;             // as far as I can tell not part of the cpython api but might be nice to have pyi map the function to the name __enter__
enum __exit__;




//class.__instancecheck__(self, instance)
//Return true if instance should be considered a (direct or indirect) instance of class. If defined, called to implement isinstance(instance, class).
//
//class.__subclasscheck__(self, subclass)
//
//__reversed__





string signatureWithAttributes(alias fn)() {
    import std.traits : Parameters, ReturnType, getUDAs, hasUDA, fullyQualifiedName, isCallable;
    static if (isCallable!fn) {
        string s = "";
        s ~= fullyQualifiedName!fn~" => ";
        s ~= Parameters!fn.stringof~"->";
        s ~= ReturnType!fn.stringof;
        auto attributes = __traits(getAttributes, fn);
        bool first;   // gotta be out of the loop - SHOULDDO understand why that is
        if (attributes.length > 0) {
            s ~= " : ";
            first = true;
            foreach (attribute; attributes) {
                if (!first) {
                    s ~= " ";
                }
                if (is(typeof(attribute) == pymagic)) {
                    s ~= "@pymagic("~attribute.name~")";
                } else if (is(typeof(attribute) == kwargs)) {
                    s ~= "@kwargs("~attribute.name~")";
                } else if (is(typeof(attribute) == args)) {
                    s ~= "@args("~attribute.name~")";
                } else {
                    s ~= attribute.stringof;
                }
                first = false;
            }
        }
        return s;
    } else {
        return fn.stringof~" is not callable";
    }
}


bool fnHasArgsAttr(alias x)() {return hasUDA!(x, args);}
bool fnHasKwargsAttr(alias x)() {return hasUDA!(x, kwargs);}

