/**
  Mirror _pyport.h
  */
module deimos.python.pyport;

/* D long is always 64 bits, but when the Python/C API mentions long, it is of
 * course referring to the C type long, the size of which is 32 bits on both
 * X86 and X86_64 under Windows, but 32 bits on X86 and 64 bits on X86_64 under
 * most other operating systems. */

/// _
alias long C_longlong;
/// _
alias ulong C_ulonglong;

version(Windows) {
/// _
  alias int C_long;
/// _
  alias uint C_ulong;
} else {
  version (X86) {
/// _
    alias int C_long;
/// _
    alias uint C_ulong;
  } else {
/// _
    alias long C_long;
/// _
    alias ulong C_ulong;
  }
}


/*
 * Py_ssize_t is defined as a signed type which is 8 bytes on X86_64 and 4
 * bytes on X86.
 */
version(Python_2_5_Or_Later){
    version (X86_64) {
        /// _
        alias long Py_ssize_t;
    } else {
        /// _
        alias int Py_ssize_t;
    }
    version(Python_3_2_Or_Later) {
        /// Availability: 3.2
        alias Py_ssize_t Py_hash_t;
        /// Availability: 3.2
        alias size_t Py_uhash_t;
    }
}else {
    /*
     * Seems Py_ssize_t didn't exist in 2.4, and int was everywhere it is now.
     */
    /// _
    alias int Py_ssize_t;
}

