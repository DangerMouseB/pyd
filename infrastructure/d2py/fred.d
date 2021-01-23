//
//
//
//
//PyObject* tp_call(PyObject* self, PyObject* args, PyObject* kwargs) {return null};
//PyNumberMethods.nb_add
//
//
//
//PyObject* nb_add(PyObject* self, PyObject* other) PyNumberMethods.nb_add
//
//binaryfunc PyNumberMethods.nb_subtract
//binaryfunc PyNumberMethods.nb_multiply
//binaryfunc PyNumberMethods.nb_remainder
//binaryfunc PyNumberMethods.nb_divmod
//ternaryfunc PyNumberMethods.nb_power
//unaryfunc PyNumberMethods.nb_negative
//unaryfunc PyNumberMethods.nb_positive
//unaryfunc PyNumberMethods.nb_absolute
//inquiry PyNumberMethods.nb_bool
//unaryfunc PyNumberMethods.nb_invert
//binaryfunc PyNumberMethods.nb_lshift
//binaryfunc PyNumberMethods.nb_rshift
//binaryfunc PyNumberMethods.nb_and
//binaryfunc PyNumberMethods.nb_xor
//binaryfunc PyNumberMethods.nb_or
//unaryfunc PyNumberMethods.nb_int
//void *PyNumberMethods.nb_reserved
//unaryfunc PyNumberMethods.nb_float
//binaryfunc PyNumberMethods.nb_inplace_add
//binaryfunc PyNumberMethods.nb_inplace_subtract
//binaryfunc PyNumberMethods.nb_inplace_multiply
//binaryfunc PyNumberMethods.nb_inplace_remainder
//ternaryfunc PyNumberMethods.nb_inplace_power
//binaryfunc PyNumberMethods.nb_inplace_lshift
//binaryfunc PyNumberMethods.nb_inplace_rshift
//binaryfunc PyNumberMethods.nb_inplace_and
//binaryfunc PyNumberMethods.nb_inplace_xor
//binaryfunc PyNumberMethods.nb_inplace_or
//binaryfunc PyNumberMethods.nb_floor_divide
//binaryfunc PyNumberMethods.nb_true_divide
//binaryfunc PyNumberMethods.nb_inplace_floor_divide
//binaryfunc PyNumberMethods.nb_inplace_true_divide
//unaryfunc PyNumberMethods.nb_index
//binaryfunc PyNumberMethods.nb_matrix_multiply
//binaryfunc PyNumberMethods.nb_inplace_matrix_multiply
//
//PyObject *(*unaryfunc)(PyObject *)
//PyObject *(*binaryfunc)(PyObject *, PyObject *)
//PyObject *(*ternaryfunc)(PyObject *, PyObject *, PyObject *)
//PyObject *(*ssizeargfunc)(PyObject *, Py_ssize_t)
//
//
//nb_power            __pow__ __rpow__
//nb_inplace_power   __pow__
//
