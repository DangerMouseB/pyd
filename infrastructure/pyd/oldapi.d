module pyd.oldapi;

import deimos.python.Python : PyObject;
import pyd.make_object : items_to_PyTuple;



PyObject *PyTuple_FromItems() {return items_to_PyTuple();}

