r"""
List of Elements of $P^1(\Z/N\Z)$
"""

# TODO:
# Precompute table of xgcd's with N.  This would likely greatly speed
# things up, and probably be easy to compute!!!

from sage.misc.search import search

cimport sage.ext.arith
import sage.ext.arith
cdef sage.ext.arith.arith_int arith_int
cdef sage.ext.arith.arith_llong arith_llong
arith_int  = sage.ext.arith.arith_int()
arith_llong = sage.ext.arith.arith_llong()

ctypedef long long llong

include '../../ext/interrupt.pxi'

cdef int c_p1_normalize_int(int N, int u, int v,
                            int* uu, int* vv, int* ss,
                            int compute_s) except -1:
    """
    Do not compute s if compute_s == 0.
    """
    cdef int d, k, g, s, t, min_v, min_t, Ng, vNg
    if N == 1:
        uu[0] = 0
        vv[0] = 0
        ss[0] = 1
        return 0

    if N<=0 or N > 46340:
        raise OverflowError, "Modulus is too large (must be < 46340)"
        return -1

    u = u % N
    v = v % N
    if u<0: u = u + N
    if v<0: v = v + N
    if u == 0:
        uu[0] = 0
        if arith_int.c_gcd_int(v,N) == 1:
            vv[0] = 1
        else:
            vv[0] = 0
        ss[0] = v
        return 0

    g = arith_int.c_xgcd_int(u, N, &s, &t)
    s = s % N
    if s<0: s = s + N
    if arith_int.c_gcd_int(g, v) != 1:
        uu[0] = 0
        vv[0] = 0
        ss[0] = 0
        return 0

    # Now g = s*u + t*N, so s is a "pseudo-inverse" of u mod N
    # Adjust s modulo N/g so it is coprime to N.
    if g!=1:
        d = N/g
        while arith_int.c_gcd_int(s,N) != 1:
            s = (s+d) % N

    # Multiply [u,v] by s; then [s*u,s*v] = [g,s*v] (mod N)
    u = g
    v = (s*v) % N

    min_v = v; min_t = 1
    if g!=1:
        Ng = N/g
        vNg = (v*Ng) % N
        t = 1
        for k from 2 <= k <= g:
            v = (v + vNg) % N
            t = (t + Ng) % N
            if v<min_v and arith_int.c_gcd_int(t,N)==1:
                min_v = v; min_t = t
    v = min_v
    if u<0: u = u+N
    if v<0: v = v+N
    uu[0] = u
    vv[0] = v
    if compute_s:
        ss[0] = arith_int.c_inverse_mod_int(s*min_t, N);
    return 0

def p1_normalize_int(N, u, v):
    r"""
    p1_normalize_int(N, u, v):

    Computes the canonical representative of $\PP^1(\Z/N\Z)$ equivalent
    to $(u,v)$ along with a transforming scalar.

    INPUT:
        N -- an integer
        u -- an integer
        v -- an integer

    OUTPUT:
        If gcd(u,v,N) = 1, then returns
             uu -- an integer
             vv -- an integer
             ss -- an integer
             such that (ss*uu, ss*vv) is equivalent to (u,v) mod N
        and if gcd(u,v,N) != 1, returns
             0, 0, 0
    """
    cdef int uu, vv, ss
    c_p1_normalize_int(N, u%N, v%N, &uu, &vv, &ss, 1)
    return (uu,vv,ss)

def p1list_int(int N):
    r"""
    p1list_int(int N):

    Make a list of the normalized elements of $\PP^1(\Z/N\Z)$.
    """
    cdef int g, u, v, s, c, d
    cdef object lst

    if N==1: return [(0,0)]

    _sig_on
    lst = [(0,1), (1,0)]
    for c from 1 <= c < N:
        lst.append((1,c))
        g = arith_int.c_gcd_int(c,N)
        if g > 1:
            c_p1_normalize_int(N, c, 1, &u, &v, &s, 0)
            lst.append((u,v))
            if g==c:  # is a divisor
                for d from 2 <= d < N:
                    if arith_int.c_gcd_int(d,N)>1 and arith_int.c_gcd_int(d,c)==1:
                        c_p1_normalize_int(N, c, d, &u, &v, &s, 0)
                        lst.append((u,v))
    _sig_off
    # delete duplicate entries
    lst = list(set(lst))
    lst.sort()
    return lst

###############################################################
#
# The following is a version of the three functions
#
#      c_p1_normalize_int, p1_normalize_int, and p1list_int
#
# but the gcd's are done using GMP, so there are no overflow
# worries.   Also, the one multiplication is done using double
# precision.
#
################################################################

cdef int c_p1_normalize_llong(int N, int u, int v,
                              int* uu, int* vv, int* ss,
                              int compute_s) except -1:
    """
    Do not compute s if compute_s == 0.
    """
    cdef int d, k, g, s, t, min_v, min_t, Ng, vNg
    cdef llong ll_s, ll_t, ll_N
    if N == 1:
        uu[0] = 0
        vv[0] = 0
        ss[0] = 1
        return 0

    ll_N = <long> N

    #if N<=0 or N >= 2**31:
    #    raise OverflowError, "Modulus is too large (must be < 46340)"
    #    return -1

    u = u % N
    v = v % N
    if u<0: u = u + N
    if v<0: v = v + N
    if u == 0:
        uu[0] = 0
        if arith_int.c_gcd_int(v,N) == 1:
            vv[0] = 1
        else:
            vv[0] = 0
        ss[0] = v
        return 0

    #g = xgcd_int_llong(u, N, &s, &t)
    g = <int> arith_llong.c_xgcd_longlong(u, N, &ll_s, &ll_t)
    s = <int>(ll_s % ll_N)
    t = <int>(ll_t % ll_N)
    s = s % N
    if s<0: s = s + N
    if arith_int.c_gcd_int(g, v) != 1:
        uu[0] = 0
        vv[0] = 0
        ss[0] = 0
        return 0

    # Now g = s*u + t*N, so s is a "pseudo-inverse" of u mod N
    # Adjust s modulo N/g so it is coprime to N.
    if g!=1:
        d = N/g
        while arith_int.c_gcd_int(s,N) != 1:
            s = (s+d) % N

    # Multiply [u,v] by s; then [s*u,s*v] = [g,s*v] (mod N)
    u = g
    # v = (s*v) % N
    v = <int> ( ((<llong>s) * (<llong>v)) % ll_N )

    min_v = v; min_t = 1
    if g!=1:
        Ng = N/g
        vNg = <int> ((<llong>v * <llong> Ng) % ll_N)
        t = 1
        for k from 2 <= k <= g:
            v = (v + vNg) % N
            t = (t + Ng) % N
            if v<min_v and arith_int.c_gcd_int(t,N)==1:
                min_v = v; min_t = t
    v = min_v
    if u<0: u = u+N
    if v<0: v = v+N
    uu[0] = u
    vv[0] = v
    if compute_s:
        ss[0] = <int> (arith_llong.c_inverse_mod_longlong(s*min_t, N) % ll_N)
    return 0

def p1_normalize_llong(N, u, v):
    r"""
    p1_normalize_llong(N, u, v):

    Computes the canonical representative of $\PP^1(\Z/N\Z)$ equivalent
    to $(u,v)$ along with a transforming scalar.

    INPUT:
        N -- an integer
        u -- an integer
        v -- an integer
    OUTPUT:
        If gcd(u,v,N) = 1, then returns
             uu -- an integer
             vv -- an integer
             ss -- an integer
             such that (ss*uu, ss*vv) is equivalent to (u,v) mod N
        and if gcd(u,v,N) != 1, returns
             0, 0, 0
    """
    cdef int uu, vv, ss
    c_p1_normalize_llong(N, u%N, v%N, &uu, &vv, &ss, 1)
    return (uu,vv,ss)

def p1list_llong(int N):
    r"""
    p1list_llong(int N):

    Make a list of the normalized elements of $\PP^1(\Z/N\Z)$.
    """
    cdef int g, u, v, s, c, d
    if N==1: return [(0,0)]

    lst = [(0,1), (1,0)]
    _sig_on
    for c from 1 <= c < N:
        lst.append((1,c))
        g = arith_int.c_gcd_int(c,N)
        if g > 1:
            c_p1_normalize_llong(N, c, 1, &u, &v, &s, 0)
            lst.append((u,v))
            if g==c:  # is a divisor
                for d from 2 <= d < N:
                    if arith_int.c_gcd_int(d,N)>1 and arith_llong.c_gcd_longlong(d,c)==1:
                        c_p1_normalize_llong(N, c, d, &u, &v, &s, 0)
                        lst.append((u,v))
    _sig_off
    # delete duplicate entries
    lst = list(set(lst))
    lst.sort()
    return lst

def p1list(N):
    if N <= 46340:
        return p1list_int(N)
    if N <= 2147483647:
        return p1list_llong(N)
    else:
        raise OverflowError, "p1list not defined for such large N."

def p1_normalize(int N, int u, int v):
    if N <= 46340:
        return p1_normalize_int(N, u, v)
    if N <= 2147483647:
        return p1_normalize_llong(N, u, v)
    else:
        raise OverflowError

cdef class P1List:
    """
    EXAMPLES:
        sage: P = P1List(12); P
        The projective line over the integers modulo 12
        sage: list(P)
        [(0, 1), (1, 0), (1, 1), (1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7), (1, 8), (1, 9), (1, 10), (1, 11), (2, 1), (2, 3), (2, 5), (3, 1), (3, 2), (3, 4), (3, 7), (4, 1), (4, 3), (4, 5), (6, 1)]

    Saving and loading works.
        sage: loads(dumps(P)) == P
        True
    """
    cdef int __N
    # Here we use a pointer to a function, so the if logic
    # for normalizing an element does not need to be used
    # every time the user calls the normalize function.
    cdef int (*__normalize)(int N, int u, int v,\
                            int* uu, int* vv, int* ss,
                            int compute_s) except -1
    cdef object __list

    def __init__(self, int N):
        self.__N = N
        if N <= 46340:
            self.__list = p1list_int(N)
            self.__normalize = c_p1_normalize_int
        elif N <= 2147483647:
            self.__list = p1list_llong(N)
            self.__normalize = c_p1_normalize_llong
        else:
            raise OverflowError, "p1list not defined for such large N."
        self.__list.sort()

    def __cmp__(self, other):
        if not isinstance(other, P1List):
            return -1
        cdef P1List O
        O = other
        if self.__N < O.__N:
            return -1
        elif self.__N > O.__N:
            return 1
        return 0

    def __reduce__(self):
        import sage.modular.modsym.p1list
        return sage.modular.modsym.p1list._make_p1list, (self.__N, )

    def __getitem__(self, n):
        return self.__list[n]

    def __getslice__(self,  Py_ssize_t n,  Py_ssize_t m):
        return self.__list[n:m]

    def __len__(self):
        return len(self.__list)

    def __repr__(self):
        return "The projective line over the integers modulo %s"%self.__N

    def lift_to_sl2z(self, int i):
        """
        Lift an element of P1 to an element of SL(2,Z)

        If the ith P1 element is (c,d), this function
        computes and returns a list [a,b, c',d'] that defines a 2x2
        matrix with determinant 1 and integer entries, such that
        c=c'(mod N) and d=d'(mod N).

        EXAMPLES
	    sage: p=P1List(11)

	    sage: p.list()[3]
	     (1, 2)

	    sage: p.lift_to_sl2z(3)
	     [0, -1, 1, 2]

        AUTHOR:
            -- Justin Walker
        """
        cdef int c, d, N

        if self.__N == 1:
            return [1,0,0,1]

        c, d = self.__list[i]
        N = self.__N
        # No overflow: This was adjudicated during init...
        if N <= 46340:
            return lift_to_sl2z_int(c, d, self.__N)
        elif N <= 2147483647:
            return lift_to_sl2z_llong(c, d, self.__N)
        else:
            raise OverflowError, "N too large"

    def apply_I(self, int i):
        cdef int u, v, uu, vv, ss
        u,v = self.__list[i]
        self.__normalize(self.__N, -u, v, &uu, &vv, &ss, 0)
        _, j = search(self.__list, (uu,vv))
        return j

    def apply_S(self, int i):
        cdef int u, v, uu, vv, ss
        u,v = self.__list[i]
        self.__normalize(self.__N, -v, u, &uu, &vv, &ss, 0)
        _, j = search(self.__list, (uu,vv))
        return j

    def apply_T(self, int i):
        cdef int u, v, uu, vv, ss
        u,v = self.__list[i]
        self.__normalize(self.__N, v, -u-v, &uu, &vv, &ss, 0)
        _, j = search(self.__list, (uu,vv))
        return j

    def index(self, int u, int v):
        r"""
        Returns the index of the class of $(u,v)$ in the fixed list of
        representatives of $\PP^1(\Z/N\Z)$.

        INPUT:
            u, v -- integers, with GCD(u,v,N)=1.

        OUTPUT:
            i -- the index of $u$, $v$, in the $P^1$ list.
        """
        cdef int uu, vv, ss
        self.__normalize(self.__N, u, v, &uu, &vv, &ss, 0)
        t, i = search(self.__list, (uu,vv))
        if t: return i
        return -1

    def index_of_normalized_pair(self, int u, int v):
        r"""
        Returns the index of the class of $(u,v)$ in the fixed list of
        representatives of $\PP^1(\Z/N\Z)$.

        INPUT:
            u, v -- integers, with GCD(u,v,N)=1 normalized so they lie in the list.
        OUTPUT:
            i -- the index of $u$, $v$, in the $P^1$ list.
        """
        t, i = search(self.__list, (u,v))
        if t: return i
        return -1

    def index_and_scalar(self, int u, int v):
        """
        Returns the index of the class of $(u,v)$ in the fixed list of
        representatives of $\PP^1(\Z/N\Z)$.

        INPUT:
            u, v -- integers, with GCD(u,v,N)=1.

        OUTPUT:
            i -- the index of $u$, $v$, in the $P^1$ list.
            s -- scalar that transforms normalized form to u,v
        """
        cdef int uu, vv, ss
        self.__normalize(self.__N, u, v, &uu, &vv, &ss, 1)
        t, i = search(self.__list, (uu,vv)), ss
        if t: return i
        return -1

    def list(self):
        return self.__list

    def normalize(self, int u, int v):
        cdef int uu, vv, ss
        self.__normalize(self.__N, u, v, &uu, &vv, &ss, 0)
        return (uu,vv)

    def normalize_with_scalar(self, int u, int v):
        """
        normalize_with_scalar(self, int u, int v)

        INPUT:
            u, v -- integers, with GCD(u,v,N)=1.

        OUTPUT:
            uu, vv -- integers of *normalized* rep
            ss -- scalar such that (ss*uu, ss*vv) = (u,v) mod N
        """
        cdef int uu, vv, ss
        self.__normalize(self.__N, u, v, &uu, &vv, &ss, 1)
        return (uu,vv,ss)

    def N(self):
        return self.__N

cdef class export:
    cdef int c_p1_normalize_int(self, int N, int u, int v,
                                int* uu, int* vv, int* ss,
                                int compute_s) except -1:
        return c_p1_normalize_int(N, u, v, uu, vv, ss, compute_s)

    cdef int c_p1_normalize_llong(self, int N, int u, int v,
                                  int* uu, int* vv, int* ss,
                                  int compute_s) except -1:
        return c_p1_normalize_llong(N, u, v, uu, vv, ss, compute_s)

def lift_to_sl2z_int(int c, int d, int N):
        """
        Lift a pair (c, d) to an element of SL(2, Z)

        (c,d) is assumed to be an element of P1(Z/NZ).  This function
        computes and returns a list [a, b, c', d'] that defines a 2x2
        matrix, with determinant 1 and integer entries, such that
        c=c'(mod N) and d=d'(mod N).

        EXAMPLES
	    sage: lift_to_sl2z_int(2,6,11)
	    [1, 8, 2, 17]
	    sage: m=Matrix(Integers(),2,2,lift_to_sl2z_int(2,6,11))
	    sage: m
	    [ 1  8]
	    [ 2 17]

        AUTHOR:
            -- Justin Walker
        """
        cdef int z1, z2, g, m

        if c == 0 and d == 0:
            raise AttributeError, "Element not in P1."
        g = arith_int.c_xgcd_int(c, d, &z1, &z2)

        # We're lucky: z1*c + z2*d = 1.
        if g==1:
            return [z2, -z1, c, d]

        # Have to try harder.
        if c == 0:
            c = c + N;
        if d == 0:
            d = d + N;
        m = c;

        # compute prime-to-d part of m.
        while True:
            g = arith_int.c_gcd_int(m,d)
            if g == 1:
                break
            m = m / g

        # compute prime-to-N part of m.
        while True:
            g = arith_int.c_gcd_int(m,N)
            if g == 1:
                break
            m = m / g
        d = d + N*m
        g = arith_int.c_xgcd_int(c, d, &z1, &z2)
#        assert g==1
        return [z2, -z1, c, d]

def lift_to_sl2z_llong(llong c, llong d, int N):
        """
        Lift a pair (c, d) to an element of SL(2, Z)

        (c,d) is assumed to be an element of P1(Z/NZ).  This function
        computes and returns a list [a, b, c', d'] that defines a 2x2
        matrix, with determinant 1 and integer entries, such that
        c=c'(mod N) and d=d'(mod N).

        EXAMPLES
	    sage: lift_to_sl2z_llong(2,6,11)
	    [1L, 8L, 2L, 17L]
	    sage: m=Matrix(Integers(),2,2,lift_to_sl2z_llong(2,6,11))
	    sage: m
	    [ 1  8]
	    [ 2 17]

        AUTHOR:
            -- Justin Walker
        """
        cdef llong z1, z2, g, m

        if c == 0 and d == 0:
            raise AttributeError, "Element not in P1."
        g = arith_llong.c_xgcd_longlong(c, d, &z1, &z2)

        # We're lucky: z1*c + z2*d = 1.
        if g==1:
            return [z2, -z1, c, d]

        # Have to try harder.
        if c == 0:
            c = c + N;
        if d == 0:
            d = d + N;
        m = c;

        # compute prime-to-d part of m.
        while True:
            g = arith_llong.c_gcd_longlong(m,d)
            if g == 1:
                break
            m = m / g

        # compute prime-to-N part of m.
        while True:
            g = arith_llong.c_gcd_longlong(m,N)
            if g == 1:
                break
            m = m / g
        d = d + N*m
        g = arith_llong.c_xgcd_longlong(c, d, &z1, &z2)
#        assert g==1
        return [z2, -z1, c, d]

def lift_to_sl2z(c, d, N):
    """
    Return a list of Python ints [a,b,c',d'] that are the entries of a
    2x2 matrix with determinant 1 and lower two entries congruent to
    c,d modulo N.

    EXAMPLES:
        sage: lift_to_sl2z(2,3,6)
        [1, 1, 2, 3]
        sage: lift_to_sl2z(15,6,24)
        [-2, -17, 15, 126]
        sage: lift_to_sl2z(15,6,2400000)
        [-2L, -320001L, 15L, 2400006L]
    """
    if N <= 46340:
        return lift_to_sl2z_int(c,d,N)
    elif N <= 2147483647:
        return lift_to_sl2z_llong(c,d,N)
    else:
        raise OverflowError, "N too large"

def _make_p1list(n):
    return P1List(n)
