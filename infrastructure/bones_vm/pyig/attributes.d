module bones_vm.pyig.attributes;

import std.traits : hasUDA;

struct kwargs { string name; this(string name) {this.name = name;}}
struct args { string name; this(string name) {this.name = name;}}


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

// getattrfunc - deprecated
// setattrfunc - deprecated



enum __repr__;                      // tp_repr - reprfunc

enum __hash__;                     // tp_hash - hashfunc

enum __call__;                      // tp_call - ternaryfunc

enum __str__;                       // tp_str - reprfunc


enum __getattribute__;             // tp_getattro - getattrofunc
enum __getattr__;

enum __setattr__;                   // tp_setattro - setattrofunc
enum __delattr__;

enum __doc__;                       // tp_doc - const char *


enum __lt__;                        // tp_richcompare - richcmpfunc
enum __le__;
enum __eq__;
enum __ne__;
enum __gt__;
enum __ge__;
enum __richcmpfunc__;             // a function that handles all the above


enum __iter__;                      // tp_iter - getiterfunc
enum __next__;                     // tp_iternext - iternextfunc


enum __new__;                       // tp_new - newfunc
enum __init__;                      // tp_init - initproc
enum __del__;                       // tp_finalize - destructor




// sub-slots

enum __add__;            // nb_add - binaryfunc
enum __radd__;

enum __sub__;           // nb_subtract - binaryfunc
enum __rsub__;

enum __mul__;            // nb_multiply - binaryfunc
enum __rmul__;


enum __pow__;            // nb_power - ternaryfunc
enum __rpow__;


enum __matmul__;        // nb_matrix_multiply - binaryfunc
enum __rmatmul__;

enum __matmul__ip__;   // nb_inplace_matrix_multiply - binaryfunc




enum __len__;            // mp_length - lenfunc
enum __getitem__;       // mp_subscript - binaryfunc
enum __setitem__;       // mp_ass_subscript - objobjargproc
enum __delitem__;

enum __len__sq__;      // sq_length - lenfunc
enum __add__sq__;     // sq_concat - binaryfunc
enum __mul__sq__;     // sq_repeat - ssizeargfunc


enum __getitem__sq__;   // sq_item - ssizeargfunc

enum __setitem__sq__;   // sq_ass_item - ssizeobjargproc
enum __delitem__sq__;
enum __contains__sq__;  // sq_contains - objobjproc


enum __bool__;          // nb_bool - inquiry

enum __invert__;        // nb_invert - unaryfunc

enum __lshift__;        // nb_lshift - binaryfunc
enum __rlshift__;
enum __lshift__ip__;    // nb_inplace_lshift - binaryfunc

enum __rshift__;        // nb_rshift - binaryfunc
enum __rrshift__;
enum __rshift__ip__;   // nb_inplace_rshift - binaryfunc



enum __getattribute__dep__;      // (tp_getattr) - getattrfunc
enum __getattr__dep__;

enum __setattr__dep__;           // (tp_setattr) - setattrfunc
enum __delattr__dep__;




enum __enter__;             // as far as I can tell not part of the cpython api but might be nice to have pyi map the function to the name __enter__
enum __exit__;


//class.__instancecheck__(self, instance)¶
//Return true if instance should be considered a (direct or indirect) instance of class. If defined, called to implement isinstance(instance, class).
//
//class.__subclasscheck__(self, subclass)
//
//__reversed__


// A key difference between __getattr__ and __getattribute__ is that __getattr__ is only invoked if the attribute wasn't found the usual ways.



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
bool fnHasMagicAttr(alias x)() {return hasUDA!(x, pymagic);}
bool fnHasIgnoreAttr(alias x)() {return hasUDA!(x, pymagic);}

