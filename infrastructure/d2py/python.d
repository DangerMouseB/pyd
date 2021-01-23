public import deimos.python.object : PyObject, Py_INCREF, Py_DECREF, Py_XDECREF, Py_XINCREF;
public import deimos.python.abstract_ : PyObject_Length;
public import deimos.python.pyerrors : PyErr_SetString, PyExc_TypeError, PyExc_ValueError;
public import deimos.python.tupleobject : PyTuple_New, PyTuple_SetItem, PyTuple_GetItem;
public import deimos.python.Python: Py_ssize_t, Py_Initialize;
