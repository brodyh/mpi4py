cdef class Info:

    """
    Info
    """

    def __cinit__(self):
        self.ob_mpi = MPI_INFO_NULL

    def __dealloc__(self):
        if not (self.flags & PyMPI_OWNED): return
        CHKERR( del_Info(&self.ob_mpi) )

    def __richcmp__(self, other, int op):
        if not isinstance(self,  Info): return NotImplemented
        if not isinstance(other, Info): return NotImplemented
        cdef Info s = <Info>self, o = <Info>other
        if   op == Py_EQ: return (s.ob_mpi == o.ob_mpi)
        elif op == Py_NE: return (s.ob_mpi != o.ob_mpi)
        else: raise TypeError("only '==' and '!='")

    def __bool__(self):
        return self.ob_mpi != MPI_INFO_NULL

    @classmethod
    def Create(cls):
        """
        Create a new, empty info object
        """
        cdef Info info = <Info>cls()
        CHKERR( MPI_Info_create(&info.ob_mpi) )
        return info

    def Free(self):
        """
        Free a info object
        """
        CHKERR( MPI_Info_free(&self.ob_mpi) )

    def Dup(self):
        """
        Duplicate an existing info object, creating a new object, with
        the same (key, value) pairs and the same ordering of keys
        """
        cdef Info info = <Info>type(self)()
        CHKERR( MPI_Info_dup(self.ob_mpi, &info.ob_mpi) )
        return info

    def Get(self, object key, int maxlen=-1):
        """
        Retrieve the value associated with a key
        """
        if maxlen < 0: maxlen = MPI_MAX_INFO_VAL
        if maxlen > MPI_MAX_INFO_VAL: maxlen = MPI_MAX_INFO_VAL
        cdef char *ckey = NULL
        cdef char *cvalue = NULL
        cdef int flag = 0
        key = asmpistr(key, &ckey, NULL)
        cdef tmp = allocate((maxlen+1), sizeof(char), <void**>&cvalue)
        CHKERR( MPI_Info_get(self.ob_mpi, ckey, maxlen, cvalue, &flag) )
        cvalue[maxlen] = 0 # just in case
        if not flag: return None
        return mpistr(cvalue)

    def Set(self, object key, object value):
        """
        Add the (key, value) pair to info, and overrides the value if
        a value for the same key was previously set
        """
        cdef char *ckey = NULL
        cdef char *cvalue = NULL
        key = asmpistr(key, &ckey, NULL)
        value = asmpistr(value, &cvalue, NULL)
        CHKERR( MPI_Info_set(self.ob_mpi, ckey, cvalue) )

    def Delete(self, object key):
        """
        Remove a (key, value) pair from info
        """
        cdef char *ckey = NULL
        key = asmpistr(key, &ckey, NULL)
        CHKERR( MPI_Info_delete(self.ob_mpi, ckey) )

    def Get_nkeys(self):
        """
        Return the number of currently defined keys in info
        """
        cdef int nkeys = 0
        CHKERR( MPI_Info_get_nkeys(self.ob_mpi, &nkeys) )
        return nkeys

    def Get_nthkey(self, int n):
        """
        Return the nth defined key in info. Keys are numbered in the
        range [0, N) where N is the value returned by
        `Info.Get_nkeys()`
        """
        cdef char ckey[MPI_MAX_INFO_KEY+1]
        CHKERR( MPI_Info_get_nthkey(self.ob_mpi, n, ckey) )
        ckey[MPI_MAX_INFO_KEY] = 0 # just in case
        return mpistr(ckey)

    # Fortran Handle
    # --------------

    def py2f(self):
        """
        """
        return MPI_Info_c2f(self.ob_mpi)

    @classmethod
    def f2py(cls, arg):
        """
        """
        cdef Info info = <Info>cls()
        info.ob_mpi = MPI_Info_f2c(arg)
        return info

    # Python mapping emulation
    # ------------------------

    def __len__(self):
        if not self: return 0
        return self.Get_nkeys()

    def __contains__(self, object key):
        if not self: return False
        cdef char *ckey = NULL
        cdef int dummy = 0
        cdef int haskey = 0
        key = asmpistr(key, &ckey, NULL)
        CHKERR( MPI_Info_get_valuelen(self.ob_mpi, ckey, &dummy, &haskey) )
        return <bint>haskey

    def __iter__(self):
        return iter(self.keys())

    def __getitem__(self, object key):
        if not self: raise KeyError(key)
        cdef object value = self.Get(key)
        if value is None: raise KeyError(key)
        return value

    def __setitem__(self, object key, object value):
        if not self: raise KeyError(key)
        self.Set(key, value)

    def __delitem__(self, object key):
        if not self: raise KeyError(key)
        if key not in self: raise KeyError(key)
        self.Delete(key)

    def get(self, object key, object default=None):
        """info get"""
        if not self: return default
        cdef object value = self.Get(key)
        if value is None: return default
        return value

    def keys(self):
        """info keys"""
        if not self: return []
        cdef list keys = []
        cdef int k = 0, nkeys = self.Get_nkeys()
        cdef object key
        for k from 0 <= k < nkeys:
            key = self.Get_nthkey(k)
            keys.append(key)
        return keys

    def values(self):
        """info values"""
        if not self: return []
        cdef list values = []
        cdef int k = 0, nkeys = self.Get_nkeys()
        cdef object key, val
        for k from 0 <= k < nkeys:
            key = self.Get_nthkey(k)
            val = self.Get(key)
            values.append(val)
        return values

    def items(self):
        """info items"""
        if not self: return []
        cdef list items = []
        cdef int k = 0, nkeys = self.Get_nkeys()
        cdef object key, value
        for k from 0 <= k < nkeys:
            key = self.Get_nthkey(k)
            value = self.Get(key)
            items.append((key, value))
        return items

    def update(self, other=(), **kwds):
        """info update"""
        if not self: raise KeyError
        cdef object key, value
        if hasattr(other, 'keys'):
            for key in other.keys():
                self.Set(key, other[key])
        else:
            for key, value in other:
                self.Set(key, value)
        for key, value in kwds.items():
            self.Set(key, value)

    def clear(self):
        """info clear"""
        if not self: return None
        cdef int k = 0, nkeys = self.Get_nkeys()
        cdef object key
        for k from 0 <= k < nkeys:
            key = self.Get_nthkey(0)
            self.Delete(key)



cdef Info __INFO_NULL__ = new_Info(MPI_INFO_NULL)
cdef Info __INFO_ENV__  = new_Info(MPI_INFO_ENV)


# Predefined info handles
# -----------------------

INFO_NULL = __INFO_NULL__  #: Null info handle
INFO_ENV  = __INFO_ENV__   #: Environment info handle
