module py._utils;

import deimos.python.object : PyObject, Py_INCREF;
import deimos.python.pyport : PyAPI_DATA;

mixin(PyAPI_DATA!"PyObject _Py_NotImplementedStruct");
private PyObject* Py_NotImplemented = &_Py_NotImplementedStruct;
private PyObject* Py_NewRef(PyObject* p) {Py_INCREF(p); return p;}
PyObject* Py_RETURN_NOTIMPLEMENTED() {return Py_NewRef(Py_NotImplemented);}

