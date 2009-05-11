"""
This file implements elements of eisenstein and unramified extensions of Zp and Qp with fixed modulus precision.
For the parent class see padic_extension_leaves.pyx.

The underlying implementation is through NTL's ZZ_pX class.  Each element contains the following data:
  value (ZZ_pX_c) -- An ntl ZZ_pX storing the value.  The varible x is the uniformizer in the case of eisenstein extensions.
                     This ZZ_pX is created with global ntl modulus determined by the parent's precision cap and shared among
                     all elements.
  prime_pow (some subclass of PowComputer_ZZ_pX) -- a class, identical among all elements with the same parent, holding
                     common data.
    prime_pow.deg -- The degree of the extension
    prime_pow.e   -- The ramification index
    prime_pow.f   -- The inertia degree
    prime_pow.prec_cap -- the unramified precision cap.  For eisenstein extensions this is the smallest power of p that is zero.
    prime_pow.ram_prec_cap -- the ramified precision cap.  For eisenstein extensions this will be the smallest power of x that is
                     indistinugishable from zero.
    prime_pow.pow_ZZ_tmp, prime_pow.pow_mpz_t_tmp, prime_pow.pow_Integer -- functions for accessing powers of p.
                     The first two return pointers.  See sage/rings/padics/pow_computer_ext for examples and important warnings.
    prime_pow.get_context, prime_pow.get_context_capdiv, prime_pow.get_top_context -- obtain an ntl_ZZ_pContext_class corresponding to p^n.
                     The capdiv version divides by prime_pow.e as appropriate.  top_context corresponds to prec_cap.
    prime_pow.restore_context, prime_pow.restore_context_capdiv, prime_pow.restore_top_context -- restores the given context.
    prime_pow.get_modulus, get_modulus_capdiv, get_top_modulus -- Returns a ZZ_pX_Modulus_c* pointing to a polynomial modulus defined modulo
                     p^n (appropriately divided by prime_pow.e in the capdiv case).

EXAMPLES:
An eisenstein extension:
    sage: R = ZpFM(5,5)
    sage: S.<x> = R[]
    sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
    sage: W.<w> = R.ext(f); W
    Eisenstein Extension of 5-adic Ring of fixed modulus 5^5 in w defined by (1 + O(5^5))*x^5 + (3*5^2 + O(5^5))*x^3 + (2*5 + 4*5^2 + 4*5^3 + 4*5^4 + O(5^5))*x^2 + (5^3 + O(5^5))*x + (4*5 + 4*5^2 + 4*5^3 + 4*5^4 + O(5^5))
    sage: z = (1+w)^5; z
    1 + w^5 + w^6 + 2*w^7 + 4*w^8 + 3*w^10 + w^12 + 4*w^13 + 4*w^14 + 4*w^15 + 4*w^16 + 4*w^17 + 4*w^20 + w^21 + 4*w^24 + O(w^25)
    sage: y = z >> 1; y
    w^4 + w^5 + 2*w^6 + 4*w^7 + 3*w^9 + w^11 + 4*w^12 + 4*w^13 + 4*w^14 + 4*w^15 + 4*w^16 + 4*w^19 + w^20 + 4*w^23 + 4*w^24 + O(w^25)
    sage: y.valuation()
    4
    sage: y.precision_relative()
    21
    sage: y.precision_absolute()
    25
    sage: z - (y << 1)
    1 + O(w^25)

An unramified extension:
    sage: g = x^3 + 3*x + 3
    sage: A.<a> = R.ext(g)
    sage: z = (1+a)^5; z
    (2*a^2 + 4*a) + (3*a^2 + 3*a + 1)*5 + (4*a^2 + 3*a + 4)*5^2 + (4*a^2 + 4*a + 4)*5^3 + (4*a^2 + 4*a + 4)*5^4 + O(5^5)
    sage: z - 1 - 5*a - 10*a^2 - 10*a^3 - 5*a^4 - a^5
    O(5^5)
    sage: y = z >> 1; y
    (3*a^2 + 3*a + 1) + (4*a^2 + 3*a + 4)*5 + (4*a^2 + 4*a + 4)*5^2 + (4*a^2 + 4*a + 4)*5^3 + O(5^5)
    sage: 1/a
    (3*a^2 + 4) + (a^2 + 4)*5 + (3*a^2 + 4)*5^2 + (a^2 + 4)*5^3 + (3*a^2 + 4)*5^4 + O(5^5)

Different printing modes:
    sage: R = ZpFM(5, print_mode='digits'); S.<x> = R[]; f = x^5 + 75*x^3 - 15*x^2 + 125*x -5; W.<w> = R.ext(f)
    sage: z = (1+w)^5; repr(z)
    '...4110403113210310442221311242000111011201102002023303214332011214403232013144001400444441030421100001'
    sage: R = ZpFM(5, print_mode='bars'); S.<x> = R[]; g = x^3 + 3*x + 3; A.<a> = R.ext(g)
    sage: z = (1+a)^5; repr(z)
    '...[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 4, 4]|[4, 3, 4]|[1, 3, 3]|[0, 4, 2]'
    sage: R = ZpFM(5, print_mode='terse'); S.<x> = R[]; f = x^5 + 75*x^3 - 15*x^2 + 125*x -5; W.<w> = R.ext(f)
    sage: z = (1+w)^5; z
    6 + 95367431640505*w + 25*w^2 + 95367431640560*w^3 + 5*w^4 + O(w^100)
    sage: R = ZpFM(5, print_mode='val-unit'); S.<x> = R[]; f = x^5 + 75*x^3 - 15*x^2 + 125*x -5; W.<w> = R.ext(f)
    sage: y = (1+w)^5 - 1; y
    w^5 * (2090041 + 95367431439401*w + 76293946571402*w^2 + 57220458985049*w^3 + 57220459001160*w^4) + O(w^100)

AUTHORS:
    -- David Roe  (2008-01-01) initial version
"""

#*****************************************************************************
#       Copyright (C) 2008 David Roe <roed@math.harvard.edu>
#                          William Stein <wstein@gmail.com>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#
#                  http://www.gnu.org/licenses/
#*****************************************************************************

include "../../ext/cdefs.pxi"
include "../../ext/stdsage.pxi"
include "../../ext/interrupt.pxi"

from sage.structure.element cimport Element
from sage.rings.padics.padic_printing cimport pAdicPrinter_class
from sage.rings.polynomial.polynomial_ring_constructor import PolynomialRing
from sage.rings.integer_ring import ZZ
from sage.rings.integer cimport Integer
from sage.rings.padics.padic_generic_element cimport pAdicGenericElement
from sage.rings.padics.padic_base_generic_element cimport pAdicBaseGenericElement
from sage.rings.padics.padic_ext_element cimport pAdicExtElement
from sage.libs.ntl.ntl_ZZ_pX cimport ntl_ZZ_pX
from sage.libs.ntl.ntl_ZZX cimport ntl_ZZX
from sage.libs.ntl.ntl_ZZ cimport ntl_ZZ
from sage.libs.ntl.ntl_ZZ_p cimport ntl_ZZ_p
from sage.libs.ntl.ntl_ZZ_pContext cimport ntl_ZZ_pContext_class
from sage.libs.ntl.ntl_ZZ_pContext import ntl_ZZ_pContext
from sage.rings.rational cimport Rational
from sage.libs.pari.gen import gen as pari_gen
from sage.rings.integer_mod import is_IntegerMod
from sage.rings.all import IntegerModRing
from sage.rings.padics.pow_computer_ext cimport PowComputer_ZZ_pX_FM_Eis

cdef class pAdicZZpXFMElement(pAdicZZpXElement):
    def __init__(self, parent, x, absprec=None, relprec=None, empty=False):
        """
        Creates an element of a fixed modulus, unramified or eisenstein extension of Zp or Qp.

        INPUT:
        parent -- either an EisensteinRingFixedMod or UnramifiedRingFixedMod
        x -- an integer, rational, p-adic element, polynomial, list, integer_mod, pari int/frac/poly_t/pol_mod, an ntl_ZZ_pX, an ntl_ZZX, an ntl_ZZ, or an ntl_ZZ_p
        absprec -- not used
        relprec -- not used
        empty -- whether to return after initializing to zero (without setting anything).

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = (1+w)^5; z # indirect doctest
        1 + w^5 + w^6 + 2*w^7 + 4*w^8 + 3*w^10 + w^12 + 4*w^13 + 4*w^14 + 4*w^15 + 4*w^16 + 4*w^17 + 4*w^20 + w^21 + 4*w^24 + O(w^25)
        """
        pAdicZZpXElement.__init__(self, parent)
        ZZ_pX_construct(&self.value)
        if empty:
            return
        cdef mpz_t tmp
        cdef ZZ_c tmp_z
        cdef Integer tmp_Int
        cdef Py_ssize_t i
        if PY_TYPE_CHECK(x, pAdicGenericElement):
            if x.valuation() < 0:
                raise ValueError, "element has negative valuation"
            if parent.prime() != x.parent().prime():
                raise TypeError, "Cannot coerce between p-adic parents with different primes."
        if PY_TYPE_CHECK(x, pAdicBaseGenericElement):
            mpz_init(tmp)
            (<pAdicBaseGenericElement>x)._set_to_mpz(tmp)
            self._set_from_mpz(tmp)
            mpz_clear(tmp)
            return
        if isinstance(x, pari_gen):
            if x.type() == "t_PADIC":
                x = x.lift()
            if x.type() == 't_INT':
                x = Integer(x)
            elif x.type() == 't_FRAC':
                x = Rational(x)
            elif x.type() == 't_POLMOD' or x.type == 't_POL':
                # This code doesn't check to see if the primes are the same.
                L = []
                x = x.lift().lift()
                for i from 0 <= i <= x.poldegree():
                    L.append(Integer(x.polcoeff(i)))
                x = L
            else:
                raise TypeError, "unsupported coercion from pari: only p-adics, integers, rationals, polynomials and pol_mods allowed"
        elif is_IntegerMod(x):
            if (<Integer>x.modulus())._is_power_of(<Integer>parent.prime()):
                x = x.lift()
            else:
                raise TypeError, "cannot coerce from the given integer mod ring (not a power of the same prime)"
        elif PY_TYPE_CHECK(x, ntl_ZZ_p):
            ctx_prec = ZZ_remove(tmp_z, (<ntl_ZZ>x.modulus()).x, self.prime_pow.pow_ZZ_tmp(1)[0])
            if ZZ_IsOne(tmp_z):
                x = x.lift()
                tmp_Int = PY_NEW(Integer)
                ZZ_to_mpz(&tmp_Int.value, &(<ntl_ZZ>x).x)
                x = tmp_Int
            else:
                raise TypeError, "cannot coerce the given ntl_ZZ_p (modulus not a power of the same prime)"
        elif PY_TYPE_CHECK(x, ntl_ZZ):
            tmp_Int = PY_NEW(Integer)
            ZZ_to_mpz(&tmp_Int.value, &(<ntl_ZZ>x).x)
            x = tmp_Int
        elif isinstance(x, (int, long)):
            x = Integer(x)
        if PY_TYPE_CHECK(x, Integer):
            self._set_from_mpz((<Integer>x).value)
        elif PY_TYPE_CHECK(x, Rational):
            self._set_from_mpq((<Rational>x).value)
        elif PY_TYPE_CHECK(x, ntl_ZZ_pX):
            self._set_from_ZZ_pX(&(<ntl_ZZ_pX>x).x, (<ntl_ZZ_pX>x).c)
        elif PY_TYPE_CHECK(x, ntl_ZZX):
            self._set_from_ZZX((<ntl_ZZX>x).x)
        elif PY_TYPE_CHECK(x, pAdicExtElement):
            if x.parent() is parent:
                self._set_from_ZZ_pX(&(<pAdicZZpXFMElement>x).value, self.prime_pow.get_top_context())
            else:
                raise NotImplementedError, "Conversion from different p-adic extensions not yet supported"
        else:
            try:
                x = list(x)
            except TypeError:
                try:
                    x = x.list()
                except AttributeError:
                    raise TypeError, "cannot convert x to a p-adic element"
            self._set_from_list(x)

    cdef int _set_from_mpz(self, mpz_t x) except -1:
        """
        Sets self from an mpz_t.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: W(70) # indirect doctest
        4*w^5 + 3*w^7 + w^9 + 2*w^10 + 2*w^11 + w^13 + 3*w^16 + w^17 + w^18 + 4*w^20 + 4*w^21 + w^22 + 2*w^23 + O(w^25)
        """
        self.prime_pow.restore_top_context()
        cdef ZZ_c tmp
        cdef mpz_t tmp_m
        _sig_on
        mpz_init(tmp_m)
        mpz_set(tmp_m, x)
        mpz_to_ZZ(&tmp, &tmp_m)
        mpz_clear(tmp_m)
        ZZ_pX_SetCoeff(self.value, 0, ZZ_to_ZZ_p(tmp))
        _sig_off

    cdef int _set_from_mpq(self, mpq_t x) except -1:
        """
        Sets self from an mpq_t.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = W(70/3); z # indirect doctest
        3*w^5 + w^7 + 2*w^9 + 2*w^10 + 4*w^11 + w^12 + 2*w^13 + 3*w^15 + 2*w^16 + 3*w^17 + w^18 + 3*w^19 + 3*w^20 + 2*w^21 + 2*w^22 + 3*w^23 + 4*w^24 + O(w^25)
        sage: z * 3
        4*w^5 + 3*w^7 + w^9 + 2*w^10 + 2*w^11 + w^13 + 3*w^16 + w^17 + w^18 + 4*w^20 + 4*w^21 + w^22 + 2*w^23 + O(w^25)
        sage: W(70)
        4*w^5 + 3*w^7 + w^9 + 2*w^10 + 2*w^11 + w^13 + 3*w^16 + w^17 + w^18 + 4*w^20 + 4*w^21 + w^22 + 2*w^23 + O(w^25)
        """
        self.prime_pow.restore_top_context()
        if mpz_divisible_p(mpq_denref(x), self.prime_pow.prime.value):
            raise ValueError, "p divides denominator"
        cdef mpz_t tmp_m
        cdef ZZ_c tmp_z
        _sig_on
        mpz_init(tmp_m)
        mpz_invert(tmp_m, mpq_denref(x), self.prime_pow.pow_mpz_t_top()[0])
        mpz_mul(tmp_m, tmp_m, mpq_numref(x))
        mpz_mod(tmp_m, tmp_m, self.prime_pow.pow_mpz_t_top()[0])
        mpz_to_ZZ(&tmp_z, &tmp_m)
        ZZ_pX_SetCoeff(self.value, 0, ZZ_to_ZZ_p(tmp_z))
        mpz_clear(tmp_m)
        _sig_off
        return 0

    cdef int _set_from_ZZ_pX(self, ZZ_pX_c* poly, ntl_ZZ_pContext_class ctx) except -1:
        """
        Sets self from a ZZ_pX_c.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = W(ntl.ZZ_pX([4,1,16],5^2)); z # indirect doctest
        4 + w + w^2 + 3*w^7 + w^9 + 2*w^11 + 4*w^13 + 3*w^14 + 2*w^15 + w^16 + 3*w^18 + 2*w^19 + 4*w^20 + 4*w^21 + 2*w^22 + 2*w^23 + 4*w^24 + O(w^25)
        sage: z._ntl_rep()
        [4 1 16]
        """
        self.prime_pow.restore_top_context()
        self._check_ZZ_pContext(ctx)
        ZZ_pX_conv_modulus(self.value, poly[0], self.prime_pow.get_top_context().x)

    cdef int _set_from_ZZX(self, ZZX_c poly) except -1:
        """
        Sets self from a ZZX with relative precision bounded by relprec and absolute precision bounded by absprec.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = W(ntl.ZZX([4,1,16])); z # indirect doctest
        4 + w + w^2 + 3*w^7 + w^9 + 2*w^11 + 4*w^13 + 3*w^14 + 2*w^15 + w^16 + 3*w^18 + 2*w^19 + 4*w^20 + 4*w^21 + 2*w^22 + 2*w^23 + 4*w^24 + O(w^25)
        sage: z._ntl_rep()
        [4 1 16]
        """
        self.prime_pow.restore_top_context()
        ZZX_to_ZZ_pX(self.value, poly)

    cpdef bint _is_inexact_zero(self):
        """
        Tests if self is an inexact zero.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = W(0)
        sage: z._is_inexact_zero()
        True
        sage: z = W(5^6)
        sage: z._is_inexact_zero()
        True
        """
        return ZZ_pX_IsZero(self.value) or (self.prime_pow.e * self.prime_pow.prec_cap != self.prime_pow.ram_prec_cap and self.valuation_c() >= self.prime_pow.ram_prec_cap)

    def __reduce__(self):
        """
        Pickles self.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = (1 + w)^5 - 1
        sage: loads(dumps(z)) == z #indirect doctest
        True
        """
        self.prime_pow.restore_top_context()
        cdef ntl_ZZ_pX holder = PY_NEW(ntl_ZZ_pX)
        holder.c = self.prime_pow.get_top_context()
        holder.x = self.value
        return make_ZZpXFMElement, (self.parent(), holder)

    def __dealloc__(self):
        """
        Deallocates self.value.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = W(17)
        sage: del z # indirect doctest
        """
        ZZ_pX_destruct(&self.value)

    cdef pAdicZZpXFMElement _new_c(self):
        """
        Returns a new element with the same parent as self.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: w^5 + 1 # indirect doctest
        1 + w^5 + O(w^25)
        """
        self.prime_pow.restore_top_context()
        cdef pAdicZZpXFMElement ans = PY_NEW(pAdicZZpXFMElement)
        ans._parent = self._parent
        ZZ_pX_construct(&ans.value)
        ans.prime_pow = self.prime_pow
        return ans

    def __richcmp__(left, right, op):
        """
        Compares left and right under the operation op.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: w == 1 # indirect doctest
        False
        sage: y = 1 + w
        sage: z = 1 + w + w^27
        sage: y == z
        True
        """
        return (<Element>left)._richcmp(right, op)

    cdef int _cmp_c_impl(left, Element right) except -2:
        """
        First compare valuations, then compare the values.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: w == 1 # indirect doctest
        False
        sage: y = 1 + w
        sage: z = 1 + w + w^27
        sage: y == z
        True
        """
        cdef pAdicZZpXFMElement _left = <pAdicZZpXFMElement>left
        cdef pAdicZZpXFMElement _right = <pAdicZZpXFMElement>right
        cdef long x_ordp = _left.valuation_c()
        cdef long y_ordp = _right.valuation_c()
        if x_ordp < y_ordp:
            return -1
        elif x_ordp > y_ordp:
            return 1
        else:  # equal ordp
            _left.prime_pow.restore_top_context()
            if x_ordp == left.prime_pow.ram_prec_cap:
                return 0 # since both are zero
            elif ZZ_pX_equal(_left.value, _right.value):
                return 0
            else:
                # for now just return 1
                return 1

    def __invert__(self):
        """
        Returns the inverse of self, as long as self is a unit.

        If self is not a unit, raises a ValueError.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = (1 + w)^5
        sage: y = ~z; y # indirect doctest
        1 + 4*w^5 + 4*w^6 + 3*w^7 + w^8 + 2*w^10 + w^11 + w^12 + 2*w^14 + 3*w^16 + 3*w^17 + 4*w^18 + 4*w^19 + 2*w^20 + 2*w^21 + 4*w^22 + 3*w^23 + 3*w^24 + O(w^25)
        sage: y.parent()
        Eisenstein Extension of 5-adic Ring of fixed modulus 5^5 in w defined by (1 + O(5^5))*x^5 + (3*5^2 + O(5^5))*x^3 + (2*5 + 4*5^2 + 4*5^3 + 4*5^4 + O(5^5))*x^2 + (5^3 + O(5^5))*x + (4*5 + 4*5^2 + 4*5^3 + 4*5^4 + O(5^5))
        sage: z = z - 1
        sage: ~z
        Traceback (most recent call last):
        ...
        ValueError: cannot invert non-unit
        """
        return self._invert_c_impl()

    cpdef RingElement _invert_c_impl(self):
        """
        Returns the inverse of self, as long as self is a unit.

        If self is not a unit, raises a ValueError.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = (1 + w)^5
        sage: y = ~z; y # indirect doctest
        1 + 4*w^5 + 4*w^6 + 3*w^7 + w^8 + 2*w^10 + w^11 + w^12 + 2*w^14 + 3*w^16 + 3*w^17 + 4*w^18 + 4*w^19 + 2*w^20 + 2*w^21 + 4*w^22 + 3*w^23 + 3*w^24 + O(w^25)
        sage: y.parent()
        Eisenstein Extension of 5-adic Ring of fixed modulus 5^5 in w defined by (1 + O(5^5))*x^5 + (3*5^2 + O(5^5))*x^3 + (2*5 + 4*5^2 + 4*5^3 + 4*5^4 + O(5^5))*x^2 + (5^3 + O(5^5))*x + (4*5 + 4*5^2 + 4*5^3 + 4*5^4 + O(5^5))
        sage: z = z - 1
        sage: ~z
        Traceback (most recent call last):
        ...
        ValueError: cannot invert non-unit
        """
        if self.valuation_c() > 0:
            raise ValueError, "cannot invert non-unit"
        cdef pAdicZZpXFMElement ans = self._new_c()
        _sig_on
        if self.prime_pow.e == 1:
            ZZ_pX_InvMod_newton_unram(ans.value, self.value, self.prime_pow.get_top_modulus()[0], self.prime_pow.get_top_context().x, self.prime_pow.get_context(1).x)
        else:
            ZZ_pX_InvMod_newton_ram(ans.value, self.value, self.prime_pow.get_top_modulus()[0], self.prime_pow.get_top_context().x)
        _sig_off
        return ans

    cdef pAdicZZpXFMElement _lshift_c(self, long n):
        """
        Multiplies self by the uniformizer raised to the power n.  If n is negative, right shifts by -n.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = (1 + w)^5
        sage: z
        1 + w^5 + w^6 + 2*w^7 + 4*w^8 + 3*w^10 + w^12 + 4*w^13 + 4*w^14 + 4*w^15 + 4*w^16 + 4*w^17 + 4*w^20 + w^21 + 4*w^24 + O(w^25)
        sage: z << 17 # indirect doctest
        w^17 + w^22 + w^23 + 2*w^24 + O(w^25)
        sage: z << (-1)
        w^4 + w^5 + 2*w^6 + 4*w^7 + 3*w^9 + w^11 + 4*w^12 + 4*w^13 + 4*w^14 + 4*w^15 + 4*w^16 + 4*w^19 + w^20 + 4*w^23 + 4*w^24 + O(w^25)
        """
        if n < 0:
            return self._rshift_c(-n)
        elif n == 0:
            return self
        cdef pAdicZZpXFMElement ans = self._new_c()
        if n < self.prime_pow.ram_prec_cap:
            if self.prime_pow.e == 1:
                ZZ_pX_left_pshift(ans.value, self.value, self.prime_pow.pow_ZZ_tmp(n)[0], self.prime_pow.get_top_context().x)
            else:
                self.prime_pow.eis_shift(&ans.value, &self.value, -n, self.prime_pow.prec_cap)
        return ans

    def __lshift__(pAdicZZpXFMElement self, shift):
        """
        Multiplies self by the uniformizer raised to the power n.  If n is negative, right shifts by -n.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = (1 + w)^5
        sage: z
        1 + w^5 + w^6 + 2*w^7 + 4*w^8 + 3*w^10 + w^12 + 4*w^13 + 4*w^14 + 4*w^15 + 4*w^16 + 4*w^17 + 4*w^20 + w^21 + 4*w^24 + O(w^25)
        sage: z << 17 # indirect doctest
        w^17 + w^22 + w^23 + 2*w^24 + O(w^25)
        sage: z << (-1)
        w^4 + w^5 + 2*w^6 + 4*w^7 + 3*w^9 + w^11 + 4*w^12 + 4*w^13 + 4*w^14 + 4*w^15 + 4*w^16 + 4*w^19 + w^20 + 4*w^23 + 4*w^24 + O(w^25)
        """
        cdef pAdicZZpXFMElement ans
        if not PY_TYPE_CHECK(shift, Integer):
            shift = Integer(shift)
        if mpz_fits_slong_p((<Integer>shift).value) == 0:
            ans = self._new_c()
            #Assuming that _new_c() initializes to zero.
            return ans
        return self._lshift_c(mpz_get_si((<Integer>shift).value))

    cdef pAdicZZpXFMElement _rshift_c(self, long n):
        """
        Divides self by the uniformizer raised to the power n.  Throws away the non-positive part of the series expansion.
        The top digits will be garbage.
        If n is negative, left shifts by -n.

        EXAMPLES:
        sage: R = ZpFM(5,5,print_mode='digits')
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = (1 + w)^5
        sage: for m in range(26): '...' + repr(z >> m)[len(repr(z >> m)) - 25 + m:] # indirect doctest
        '...4001400444441030421100001'
        '...400140044444103042110000'
        '...40014004444410304211000'
        '...4001400444441030421100'
        '...400140044444103042110'
        '...40014004444410304211'
        '...4001400444441030421'
        '...400140044444103042'
        '...40014004444410304'
        '...4001400444441030'
        '...400140044444103'
        '...40014004444410'
        '...4001400444441'
        '...400140044444'
        '...40014004444'
        '...4001400444'
        '...400140044'
        '...40014004'
        '...4001400'
        '...400140'
        '...40014'
        '...4001'
        '...400'
        '...40'
        '...4'
        '...'
        sage: repr(z >> (-4))
        '...4004444410304211000010000'
        """
        if n < 0:
            return self._lshift_c(-n)
        elif n == 0:
            return self
        cdef pAdicZZpXFMElement ans = self._new_c()
        cdef Py_ssize_t i
        cdef long topcut, rem
        cdef ntl_ZZ holder
        if n < self.prime_pow.ram_prec_cap:
            if self.prime_pow.e == 1:
                ZZ_pX_right_pshift(ans.value, self.value, self.prime_pow.pow_ZZ_tmp(n)[0], self.prime_pow.get_top_context().x)
            else:
                self.prime_pow.eis_shift(&ans.value, &self.value, n, self.prime_pow.prec_cap)
        return ans

    def __rshift__(pAdicZZpXFMElement self, shift):
        """
        Divides self by the uniformizer raised to the power n.  Throws away the non-positive part of the series expansion.
        The top digits will be garbage.
        If n is negative, left shifts by -n.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = (1 + w)^5
        sage: z
        1 + w^5 + w^6 + 2*w^7 + 4*w^8 + 3*w^10 + w^12 + 4*w^13 + 4*w^14 + 4*w^15 + 4*w^16 + 4*w^17 + 4*w^20 + w^21 + 4*w^24 + O(w^25)
        sage: z >> (6) # indirect doctest
        1 + 2*w + 4*w^2 + 3*w^4 + w^6 + 4*w^7 + 4*w^8 + 4*w^9 + 4*w^10 + 4*w^11 + 4*w^14 + w^15 + 4*w^18 + 4*w^19 + w^20 + 2*w^21 + 4*w^22 + 3*w^24 + O(w^25)
        sage: z >> (-4)
        w^4 + w^9 + w^10 + 2*w^11 + 4*w^12 + 3*w^14 + w^16 + 4*w^17 + 4*w^18 + 4*w^19 + 4*w^20 + 4*w^21 + 4*w^24 + O(w^25)
        """
        cdef pAdicZZpXFMElement ans
        if not PY_TYPE_CHECK(shift, Integer):
            shift = Integer(shift)
        if mpz_fits_slong_p((<Integer>shift).value) == 0:
            ans = self._new_c()
            return ans
        return self._rshift_c(mpz_get_si((<Integer>shift).value))

    cpdef ModuleElement _neg_(self):
        """
        Returns -self.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = (1 + w)^5; z
        1 + w^5 + w^6 + 2*w^7 + 4*w^8 + 3*w^10 + w^12 + 4*w^13 + 4*w^14 + 4*w^15 + 4*w^16 + 4*w^17 + 4*w^20 + w^21 + 4*w^24 + O(w^25)
        sage: -z # indirect doctest
        4 + 3*w^5 + 4*w^6 + w^7 + w^8 + w^9 + w^10 + w^11 + 2*w^12 + 4*w^13 + 4*w^15 + 3*w^16 + w^17 + 2*w^18 + 3*w^19 + 2*w^21 + 4*w^23 + 4*w^24 + O(w^25)
        sage: y = z + (-z); y
        O(w^25)
        sage: -y
        O(w^25)
        """
        cdef pAdicZZpXFMElement ans = self._new_c()
        ZZ_pX_negate(ans.value, self.value)
        return ans

    def __pow__(pAdicZZpXFMElement self, right, m): # m ignored
        """
        Computes self^right.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: (1 + w)^5 # indirect doctest
        1 + w^5 + w^6 + 2*w^7 + 4*w^8 + 3*w^10 + w^12 + 4*w^13 + 4*w^14 + 4*w^15 + 4*w^16 + 4*w^17 + 4*w^20 + w^21 + 4*w^24 + O(w^25)
        """
        if not PY_TYPE_CHECK(right, Integer):
            right = Integer(right)
        if not right and not self:
            raise ArithmeticError, "0^0 is undefined"
        cdef pAdicZZpXFMElement ans = self._new_c()
        cdef ntl_ZZ rZZ = PY_NEW(ntl_ZZ)
        mpz_to_ZZ(&rZZ.x, &(<Integer>right).value)
        _sig_on
        ZZ_pX_PowerMod_pre(ans.value, self.value, rZZ.x, self.prime_pow.get_top_modulus()[0])
        _sig_off
        return ans

    cpdef ModuleElement _add_(self, ModuleElement right):
        """
        Returns self + right.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: (4*w^5 + 3*w^7 + w^9 + 2*w^10 + 2*w^11) - 69 # indirect doctest
        1 + 4*w^13 + 2*w^16 + 4*w^17 + 3*w^18 + 4*w^20 + 4*w^22 + O(w^25)
        sage: -69 + (4*w^5 + 3*w^7 + w^9 + 2*w^10 + 2*w^11)
        1 + 4*w^13 + 2*w^16 + 4*w^17 + 3*w^18 + 4*w^20 + 4*w^22 + O(w^25)
        """
        cdef pAdicZZpXFMElement ans = self._new_c()
        ZZ_pX_add(ans.value, self.value, (<pAdicZZpXFMElement>right).value)
        return ans

    cpdef RingElement _mul_(self, RingElement right):
        """
        Returns the product of self and right.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: a = W(329)
        sage: b = W(111)
        sage: a*b
        4 + 3*w^5 + w^7 + 2*w^9 + 4*w^11 + 3*w^12 + 2*w^13 + w^14 + 2*w^15 + 3*w^16 + 4*w^17 + 4*w^18 + 2*w^19 + 2*w^21 + 4*w^22 + 2*w^23 + w^24 + O(w^25)
        sage: a * 0
        O(w^25)
        sage: W(125) * W(375)
        O(w^25)
        """
        cdef pAdicZZpXFMElement ans = self._new_c()
        ZZ_pX_MulMod_pre(ans.value, self.value, (<pAdicZZpXFMElement>right).value, self.prime_pow.get_top_modulus()[0])
        return ans

    cpdef ModuleElement _sub_(self, ModuleElement right):
        """
        Returns the difference of self and right.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: a = W(329)
        sage: b = W(111)
        sage: a - b
        3 + 3*w^5 + w^7 + 2*w^9 + 3*w^10 + 4*w^11 + 2*w^13 + 2*w^14 + w^15 + 4*w^16 + 2*w^18 + 3*w^19 + 2*w^20 + 3*w^21 + w^22 + w^24 + O(w^25)
        sage: W(218)
        3 + 3*w^5 + w^7 + 2*w^9 + 3*w^10 + 4*w^11 + 2*w^13 + 2*w^14 + w^15 + 4*w^16 + 2*w^18 + 3*w^19 + 2*w^20 + 3*w^21 + w^22 + w^24 + O(w^25)
        """
        cdef pAdicZZpXFMElement ans = self._new_c()
        ZZ_pX_sub(ans.value, self.value, (<pAdicZZpXFMElement>right).value)
        return ans

    cpdef RingElement _div_(self, RingElement _right):
        """
        Returns the quotient of self by right.
        If right is not a unit, raises a ValueError.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: W(125) / W(14)
        4*w^15 + 4*w^17 + w^19 + w^20 + w^23 + 2*w^24 + O(w^25)
        """
        cdef pAdicZZpXFMElement right = <pAdicZZpXFMElement>_right
        if right.valuation_c() > 0:
            raise ValueError, "cannot invert non-unit"
        cdef pAdicZZpXFMElement ans = self._new_c()
        ZZ_pX_PowerMod_long_pre(ans.value, right.value, -1, self.prime_pow.get_top_modulus()[0])
        ZZ_pX_MulMod_pre(ans.value, self.value, ans.value, self.prime_pow.get_top_modulus()[0])
        return ans

    def copy(self):
        """
        Returns a copy of self.

        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: b = W(45); b
        4*w^5 + 3*w^7 + w^9 + w^10 + 2*w^11 + w^12 + w^13 + 3*w^14 + w^16 + 2*w^17 + w^19 + 4*w^20 + w^21 + 3*w^22 + 3*w^23 + 4*w^24 + O(w^25)
        sage: c = b.copy(); c
        4*w^5 + 3*w^7 + w^9 + w^10 + 2*w^11 + w^12 + w^13 + 3*w^14 + w^16 + 2*w^17 + w^19 + 4*w^20 + w^21 + 3*w^22 + 3*w^23 + 4*w^24 + O(w^25)
        sage: c is b
        False
        """
        cdef pAdicZZpXFMElement ans = self._new_c()
        ans.value = self.value # does this actually copy correctly
        return ans

    def exp_artin_hasse(self):
        raise NotImplementedError

    def gamma(self):
        raise NotImplementedError

    def is_zero(self, absprec = None):
        """
        Returns whether the valuation of self is at least absprec.  If absprec is None,
        returns if self is indistinugishable from zero.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: O(w^189).is_zero()
        True
        sage: W(0).is_zero()
        True
        sage: a = W(675)
        sage: a.is_zero()
        False
        sage: a.is_zero(7)
        True
        sage: a.is_zero(21)
        False
        """
        cdef bint ans
        if absprec is None:
            ans = ZZ_pX_IsZero(self.value)
        else:
            if not PY_TYPE_CHECK(absprec, Integer):
                absprec = Integer(absprec)
            if mpz_fits_slong_p((<Integer>absprec).value) == 0:
                if mpz_sgn((<Integer>absprec).value) < 0:
                    return True
                else:
                    ans = ZZ_pX_IsZero(self.value)
            else:
                ans = (self.valuation_c() >= mpz_get_si((<Integer>absprec).value))
        return ans

    #def add_bigoh(self, absprec):
    #    if not PY_TYPE_CHECK(absprec, Integer):
    #        absprec = Integer(absprec)
    #    cdef pAdicZZpXFMElement ans = self._new_c()
    #    cdef ZZ_pX_c tmp
    #    cdef ntl_ZZ_pContext_class c
    #    cdef unsigned long aprec
    #    if self.prime_pow.e == 1:
    #        if mpz_fits_ulong_p((<Integer>absprec).value) == 0:
    #            if mpz_sgn((<Integer>absprec).value) < 0:
    #                return ans # assumes _new_c() initializes to 0
    #            return self # absprec > prec_cap
    #        aprec = mpz_get_ui((<Integer>absprec).value)
    #        if aprec >= self.prime_pow.prec_cap:
    #            return self
    #        c = self.prime_pow.get_context(aprec)
    #        c.restore_c()
    #        ZZ_pX_conv_modulus(tmp, self.value, c.x)
    #        ZZ_pX_conv_modulus(ans.value, tmp, (<ntl_ZZ_pContext_class>self.prime_pow.get_top_context()).x)
    #    else:
    #        raise NotImplementedError
    #    return ans

    def log(self, branch = None, same_ring = True):
        r"""
        Compute the p-adic logarithm of any unit.
        (See below for normalization.)

        INPUT:
        branch -- pAdicZZpXFMElement (default None).  The log of the uniformizer.
                  If None, then an error is raised if self is not a unit.
        same_ring -- bool or pAdicGeneric (default True).  When e > p it is
                  possible (even common) that the image of the log map
                  is not contained in the ring of integers.  If same_ring
                  is True, then this function will return a value in self.parent()
                  or raise an error if the answer would have negative valuation.
                  If same_ring is False, then this function will raise an error
                  (this behavior is for consistency with other p-adic types).
                  If same_ring is a p-adic field into which this fixed mod ring
                  can be successfully cast, then self is cast into that field
                  and the log is taken there.  Note that this casting will
                  assume that self has the full precision possible.

        OUTPUT:
        The p-adic log of self.

        Let K be the parent of self, pi be a uniformizer of K and w be
        a generator for the group of roots of unity in K.  The usual
        power series for log with values in the additive
        group of K only converges for 1-units (units congruent to
        1 modulo pi).  However, there is a unique extension of log to a
        homomorphism defined on all the units.  If u = a*v is a unit
        with v = 1 (mod p), then we define log(u) = log(v).  This is
        the correct extension because the units U of K split as a
        product U = V x <w>, where V is the subgroup of 1-units.
        The <w> factor is torsion, so must go to 0 under any
        homomorphism to the torsion free group $(K, +)$.

        Notes -- What some other systems do with regard to non-1-units:
           PARI:  Seems to define log the same way as we do.
           MAGMA: Gives an error when unit is not a 1-unit.

        In addition, if branch is specified, then the log map
        will work on non-units:

           log(pi^k * u) = k * branch + log(u)

        Algorithm:
           Input: Some unit u.
           1. Check that the input is really a unit
              (i.e., valuation 0), or that branch is specified.
           2. Let $1-x = u^{q-1}$, which is a 1-unit, where q is the
              order of the residue field of K.
           3. Use the series expansion
              $$
                \log(1-x) = F(x) = -x - 1/2*x^2 - 1/3*x^3 - 1/4*x^4 - 1/5*x^5 - ...
              $$
              to compute the logarithm log(u**(q-1)).
              Add on terms until x^k is zero modulo the precision cap, and then
              determine if there are further terms that contribute to the sum
              (those where k is slightly above the precision cap but divisible by p).
           4. Then $$\log(u) = log(u^{q-1})/(q-1) = F(1-u^{q-1})/(q-1).$$

        EXAMPLES:
        First, the Eisenstein case.
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^4 + 15*x^2 + 625*x - 5
        sage: W.<w> = R.ext(f)
        sage: z = 1 + w^2 + 4*w^7; z
        1 + w^2 + 4*w^7 + O(w^20)
        sage: z.log()
        4*w^2 + 3*w^4 + w^6 + w^7 + w^8 + 4*w^9 + 3*w^10 + w^12 + w^13 + 3*w^14 + w^15 + 4*w^16 + 4*w^17 + 3*w^18 + 3*w^19 + O(w^20)

        Check that log is multiplicative:
        sage: y = 1 + 3*w^4 + w^5
        sage: y.log() + z.log() - (y*z).log()
        O(w^20)

        Now an unramified example.
        sage: g = x^3 + 3*x + 3
        sage: A.<a> = R.ext(g)
        sage: b = 1 + 5*(1 + a^2) + 5^3*(3 + 2*a)
        sage: b.log()
        (4*a^2 + 4)*5 + (a^2 + a + 2)*5^2 + (a^2 + 2*a + 4)*5^3 + (a^2 + 2*a + 2)*5^4 + O(5^5)

        Check that log is multiplicative:
        sage: c = 3 + 5^2*(2 + 4*a)
        sage: b.log() + c.log() - (b*c).log()
        O(5^5)

        AUTHORS:
            -- David Roe: initial version

        TODO:
            -- Currently implemented as $O(N^2)$. This can be improved to
            soft-$O(N)$ using algorithm described by Dan Bernstein:
            http://cr.yp.to/lineartime/multapps-20041007.pdf
        """
        if same_ring is False:
            raise TypeError, "Please specify a field explicitly: fixed modulus rings have no defined fraction field."
        elif not (same_ring is True):
            return same_ring(self).log(branch = branch)
        elif mpz_cmp_ui(self.prime_pow.prime.value, self.prime_pow.e) < 0:
            raise ValueError, "result is non-integral.  Use a non fixed modulus ring or specify a field to cast the answer to."
        cdef ZZ_c p, q, j, ZZ_top, leftover, gap
        cdef ZZ_pX_c res
        cdef long val = self.valuation_c()
        cdef long mini
        cdef long top = self.prime_pow.ram_prec_cap
        cdef long extra_prec
        cdef long p_long
        cdef long to_shift, p_shift
        cdef pAdicZZpXFMElement ans = self._new_c()
        cdef pAdicZZpXFMElement branch_add
        cdef ZZ_pX_c x, xpow, to_add, to_mul
        cdef Integer tester, Integer_val, Integer_e
        cdef ntl_ZZ to_list
        cdef bint is_one, branched

        cdef ntl_ZZ printer_ZZ
        cdef ntl_ZZ_pX printer_ZZ_pX

        self.prime_pow.restore_top_context()
        if val != 0:
            if branch is None:
                raise ValueError, "not a unit: specify a branch of the log map"
            branched = True
            branch_add = self._new_c()
            ZZ_pX_SetCoeff_long(branch_add.value, 0, val)
            branch_add = <pAdicZZpXFMElement>(self.parent()(branch) * branch_add)
            x = (<pAdicZZpXFMElement>self.unit_part()).value
        else:
            branched = False
            x = self.value
        p = self.prime_pow.pow_ZZ_tmp(1)[0]
        q = self.prime_pow.pow_ZZ_tmp(self.prime_pow.f)[0]
        if self.prime_pow.e == 1:
            # This function was written before residue, so we check
            # the residue the hard way.
            self.prime_pow.restore_context(1)
            ZZ_pX_conv_modulus(res, x, self.prime_pow.get_context(1).x)
            if ZZ_pX_IsOne(res):
                is_one = True
                # It's already a 1-unit, so just use the series
                # (base case of "induction")
                # Set x = (1 - self).unit_part(), val = (1-self).valuation()
                self.prime_pow.restore_top_context()
            else:
                is_one = False
                # We raise to the q-1 power.  Note that this means our running time has a linear dependence on
                # the residue extension degree.
                # Set x = (1 - self^(q-1)).unit_part(), val = (1 - self^(q-1)).valuation()
                self.prime_pow.restore_top_context()
                ZZ_add_long(j, q, -1)
                ZZ_pX_PowerMod_pre(x, x, j, self.prime_pow.get_top_modulus()[0])
            ZZ_pX_sub_long(x, 1, x)
            ZZ_pX_min_val_coeff(val, mini, x, p)
            if mini == -1:
                # self == 1
                if branched:
                    return branch_add
                else:
                    # ans is already 0, so return ans
                    return ans
            ZZ_pX_right_pshift(x, x, self.prime_pow.pow_ZZ_tmp(val)[0], self.prime_pow.get_top_context().x)
        else:
            ZZ_rem(gap, ZZ_p_rep(ZZ_pX_ConstTerm(x)), self.prime_pow.pow_ZZ_tmp(1)[0])
            if ZZ_IsOne(gap):
                is_one = True
                # It's already a 1-unit, so just use the series
                # (base case of "induction")
                # Set x = (1 - self).unit_part(), val = (1-self).valuation()
                self.prime_pow.restore_top_context()
            else:
                is_one = False
                # We raise to the p-1 power.
                # Set x = (1 - self^(p-1)).unit_part(), val = (1 - self^(p-1)).valuation()
                self.prime_pow.restore_top_context()
                ZZ_add_long(j, p, -1)
                ZZ_pX_PowerMod_pre(x, x, j, self.prime_pow.get_top_modulus()[0])
            ZZ_pX_sub_long(x, 1, x)
            ZZ_pX_min_val_coeff(val, mini, x, p)
            if mini == -1:
                #self == 1
                if branched:
                    return branch_add
                else:
                    # ans is already 0, so return ans
                    return ans
            val = val * self.prime_pow.e + mini
            self.prime_pow.eis_shift(&x, &x, val, self.prime_pow.ram_prec_cap)

        # Need extra precision to take into account powers of p
        # in the denominators of the series. (Indeed, it's a
        # not-entirely-trivial fact that if x is given mod p^n, that
        # log(x) is well-defined mod p^n !) Specifically:
        # we are only guaranteed that $x^j/j$ is zero mod $p^n$ if
        # j >= floor(log_p(j)) + n.
        # But we only actually need to do this extra computation
        # if there is some j with j - j.valuation(p) < n.

        if val > 1:
            top = (top - 1) / val + 1
        extra_prec = 0
        tester = PY_NEW(Integer)
        Integer_val = PY_NEW(Integer)
        Integer_e = PY_NEW(Integer)
        mpz_set_si(Integer_val.value, val)
        mpz_set_si(Integer_e.value, self.prime_pow.e)
        L = []
        while True:
            mpz_set_si(tester.value, top + extra_prec)
            if extra_prec * val >= tester.exact_log(self.prime_pow.prime) * self.prime_pow.e:
                break
            if mpz_divisible_p(tester.value, self.prime_pow.prime.value) != 0 and \
                   mpz_cmp_ui((<Integer>(tester * Integer_val - tester.valuation(self.prime_pow.prime) * Integer_e)).value, self.prime_pow.ram_prec_cap) < 0:
                to_list = PY_NEW(ntl_ZZ)
                mpz_to_ZZ(&to_list.x, &tester.value)
                L.append(to_list)
            extra_prec += 1

        xpow = x
        ZZ_conv_from_long(j, 1)
        ZZ_conv_from_long(ZZ_top, top)

        printer_ZZ = PY_NEW(ntl_ZZ)
        printer_ZZ_pX = ntl_ZZ_pX([], self.prime_pow.get_top_context())
        while ZZ_compare(j, ZZ_top) < 0:
            ZZ_conv_to_long(to_shift, j)
            to_shift *= val
            if ZZ_divide_test(j, p):
                p_shift = ZZ_remove(leftover, j, p)
            else:
                p_shift = 0
                leftover = j
            ##print "a"
            ##printer_ZZ.x = leftover
            ##print "leftover = %s"%printer_ZZ
            ##printer_ZZ.x = p
            ##print "p = %s"%printer_ZZ
            ##printer_ZZ.x = self.prime_pow.pow_ZZ_top()[0]
            ##print "p^n = %s"%printer_ZZ
            ##print "p_shift = %s"%p_shift
            ##print "a"
            _sig_on
            ZZ_InvMod(leftover, leftover, self.prime_pow.pow_ZZ_top()[0])
            _sig_off
            ##print "b"
            ZZ_pX_mul_ZZ_p(to_add, xpow, ZZ_to_ZZ_p(leftover))
            if self.prime_pow.e == 1:
                ZZ_pX_left_pshift(to_add, to_add, self.prime_pow.pow_ZZ_tmp(to_shift - p_shift)[0], self.prime_pow.get_top_context().x)
            else:
                ##printer_ZZ.x = self.prime_pow.pow_ZZ_tmp(p_shift)[0]
                ##print printer_ZZ
                #ZZ_pX_clear(to_mul)
                #ZZ_pX_SetCoeff(to_mul, 0, ZZ_to_ZZ_p(self.prime_pow.pow_ZZ_tmp(p_shift)[0]))
                #self.prime_pow.eis_shift(&to_mul, &to_mul, p_shift * self.prime_pow.e, self.prime_pow.ram_prec_cap)
                ##printer_ZZ_pX.x = to_mul
                ##print printer_ZZ_pX
                ##print "c"
                ZZ_pX_InvMod_newton_ram(to_mul, (<PowComputer_ZZ_pX_FM_Eis>self.prime_pow).high_shifter[0].val(), self.prime_pow.get_top_modulus()[0], self.prime_pow.get_top_context().x)
                ##print "d"
                ZZ_pX_PowerMod_long_pre(to_mul, to_mul, p_shift, self.prime_pow.get_top_modulus()[0])
                ZZ_pX_MulMod_pre(to_add, to_add, to_mul, self.prime_pow.get_top_modulus()[0])
                self.prime_pow.eis_shift(&to_add, &to_add, -(to_shift - p_shift * self.prime_pow.e), self.prime_pow.ram_prec_cap)
            ##printer_ZZ.x = j
            ##print "j = %s"%printer_ZZ
            ##printer_ZZ_pX.x = to_add
            ##print "to_add = %s"%printer_ZZ_pX
            ##printer_ZZ_pX.x = xpow
            ##print "xpow = %s"%printer_ZZ_pX
            ZZ_pX_add(ans.value, ans.value, to_add)
            ZZ_pX_MulMod_pre(xpow, xpow, x, self.prime_pow.get_top_modulus()[0])
            ZZ_add_long(j, j, 1)
        ##print "starting L"
        for m in L:
            ZZ_conv_to_long(to_shift, (<ntl_ZZ>m).x)
            to_shift *= val
            p_shift = ZZ_remove(leftover, (<ntl_ZZ>m).x, p)
            ##print "e"
            ZZ_InvMod(leftover, leftover, self.prime_pow.pow_ZZ_top()[0])
            ##print "f"
            ZZ_pX_mul_ZZ_p(to_add, xpow, ZZ_to_ZZ_p(leftover))
            if self.prime_pow.e == 1:
                ZZ_pX_left_pshift(to_add, to_add, self.prime_pow.pow_ZZ_tmp(to_shift - p_shift)[0], self.prime_pow.get_top_context().x)
            else:
                #ZZ_pX_clear(to_mul)
                #ZZ_pX_SetCoeff(to_mul, 0, ZZ_to_ZZ_p(self.prime_pow.pow_ZZ_tmp(p_shift)[0]))
                #self.prime_pow.eis_shift(&to_mul, &to_mul, p_shift * self.prime_pow.e, self.prime_pow.ram_prec_cap)
                ##print "g"
                ZZ_pX_InvMod_newton_ram(to_mul, (<PowComputer_ZZ_pX_FM_Eis>self.prime_pow).high_shifter[0].val(), self.prime_pow.get_top_modulus()[0], self.prime_pow.get_top_context().x)
                ##print "h"
                ZZ_pX_PowerMod_long_pre(to_mul, to_mul, p_shift, self.prime_pow.get_top_modulus()[0])
                ZZ_pX_MulMod_pre(to_add, to_add, to_mul, self.prime_pow.get_top_modulus()[0])
                self.prime_pow.eis_shift(&to_add, &to_add, -(to_shift - p_shift * self.prime_pow.e), self.prime_pow.ram_prec_cap)
            ##print "m = %s"%m
            ##printer_ZZ_pX.x = to_add
            ##print printer_ZZ_pX
            ZZ_pX_add(ans.value, ans.value, to_add)
            ZZ_sub(gap, (<ntl_ZZ>m).x, ZZ_top)
            ZZ_top = (<ntl_ZZ>m).x
            ZZ_pX_PowerMod_pre(to_mul, x, gap, self.prime_pow.get_top_modulus()[0])
            ZZ_pX_MulMod_pre(xpow, xpow, to_mul, self.prime_pow.get_top_modulus()[0])
        if not is_one:
            ZZ_add_long(q, q, -1)
            ZZ_rem(q, q, self.prime_pow.pow_ZZ_top()[0])
            ##print "i"
            ZZ_InvMod(q, q, self.prime_pow.pow_ZZ_top()[0])
            ##print "j"
            ZZ_pX_mul_ZZ_p(ans.value, ans.value, ZZ_to_ZZ_p(q))
        if branched:
            return ans + branch_add
        else:
            return ans

    def matrix_mod_pn(self):
        """
        Returns the matrix of right multiplication by
        the element on the power basis $1, x, x^2, \ldots, x^{d-1}$
        for this extension field.  Thus the \emph{rows} of this matrix give
        the images of each of the $x^i$.  The entries of the matrices
        are IntegerMod elements, defined modulo p^(self.absprec() / e).

        Raises an error if self has negative valuation.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: a = (3+w)^7
        sage: a.matrix_mod_pn()
        [2757  333 1068  725 2510]
        [  50 1507  483  318  725]
        [ 500   50 3007 2358  318]
        [1590 1375 1695 1032 2358]
        [2415  590 2370 2970 1032]
        """
        from sage.matrix.all import matrix
        R = IntegerModRing(self.prime_pow.pow_Integer(self.prime_pow.prec_cap))
        n = self.prime_pow.deg
        L = []
        cdef ntl_ZZ_pX cur = <ntl_ZZ_pX>self._ntl_rep()
        cur.c.restore_c()
        cdef ZZ_pX_Modulus_c* m = self.prime_pow.get_top_modulus()
        cdef ZZ_pX_c x
        ZZ_pX_SetX(x)
        cdef Py_ssize_t i, j
        zero = int(0)
        for i from 0 <= i < n:
            curlist = cur.list()
            L.extend(curlist + [zero]*(n - len(curlist)))
            ZZ_pX_MulMod_pre(cur.x, cur.x, x, m[0])
        return matrix(R, n, n,  L)

    def matrix(self, base = None):
        """
        If base is None, return the matrix of right multiplication by
        the element on the power basis $1, x, x^2, \ldots, x^{d-1}$
        for this extension field.  Thus the \emph{rows} of this matrix give
        the images of each of the $x^i$.

        If base is not None, then base must be either a field that
        embeds in the parent of self or a morphism to the parent of
        self, in which case this function returns the matrix of
        multiplication by self on the power basis, where we view the
        parent field as a field over base.

        INPUT:
            base -- field or morphism
        """
        raise NotImplementedError

    def norm(self, base = None):
        """
        Return the absolute or relative norm of this element.

        NOTE!  This is not the p-adic absolute value.  This is a field theoretic norm down to a ground ring.
        If you want the p-adic absolute value, use the abs() function instead.

        If K is given then K must be a subfield of the parent L of
        self, in which case the norm is the relative norm from L to K.
        In all other cases, the norm is the absolute norm down to Qp or Zp.

        EXAMPLES:
        sage: R = ZpCR(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: ((1+2*w)^5).norm()
        1 + 5^2 + O(5^5)
        sage: ((1+2*w)).norm()^5
        1 + 5^2 + O(5^5)
        """
        if base is not None:
            if base is self.parent():
                return self
            else:
                raise NotImplementedError
        if self._is_exact_zero():
            return self.parent().ground_ring()(0)
        elif self._is_inexact_zero():
            return self.ground_ring(0, self.valuation())
        norm_of_uniformizer = (-1)**self.parent().degree() * self.parent().defining_polynomial()[0]
        return self.parent().ground_ring()(self.unit_part().matrix_mod_pn().det()) * norm_of_uniformizer**self.valuation()

    def trace(self, base = None):
        """
        Return the absolute or relative trace of this element.

        If K is given then K must be a subfield of the parent L of
        self, in which case the norm is the relative norm from L to K.
        In all other cases, the norm is the absolute norm down to Qp or Zp.

        EXAMPLES:
        sage: R = ZpCR(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: a = (2+3*w)^7
        sage: b = (6+w^3)^5
        sage: a.trace()
        3*5 + 2*5^2 + 3*5^3 + 2*5^4 + O(5^5)
        sage: a.trace() + b.trace()
        4*5 + 5^2 + 5^3 + 2*5^4 + O(5^5)
        sage: (a+b).trace()
        4*5 + 5^2 + 5^3 + 2*5^4 + O(5^5)
        """
        if base is not None:
            if base is self.parent():
                return self
            else:
                raise NotImplementedError
        if self._is_exact_zero():
            return self.parent().ground_ring()(0)
        elif self._is_inexact_zero():
            return self.ground_ring(0, (self.valuation() - 1) // self.parent().e() + 1)
        if self.valuation() >= 0:
            return self.parent().ground_ring()(self.matrix_mod_pn().trace())
        else:
            shift = -(self.valuation() // self.parent().e())
            return self.parent().ground_ring()((self * self.parent().prime() ** shift).matrix_mod_pn().trace()) / self.parent().prime()**shift

    def _ntl_rep(self):
        """
        Returns an ntl_ZZ_pX holding self.value.

        sage: R = Zp(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: a = 72 + 4*w^2; b = 17 + 9*w + w^3; c = a + b
        sage: c._ntl_rep()
        [89 9 4 1]
        """
        self.prime_pow.restore_top_context()
        cdef ntl_ZZ_pX ans = PY_NEW(ntl_ZZ_pX)
        ans.c = self.prime_pow.get_top_context()
        ans.x = self.value
        return ans

    cdef ZZ_p_c _const_term(self):
        """
        Returns the constant term of self.unit.

        Note: this may be divisible by p if self is not normalized.
        """
        return ZZ_pX_ConstTerm(self.value)

    def is_equal_to(self, right, absprec = None):
        """
        Returns if self is equal to right modulo self.uniformizer()^absprec.

        If absprec is None, returns if self is equal to right modulo the precision cap.

        EXAMPLES:
        sage: R = Zp(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: a = W(47); b = W(47 + 25)
        sage: a.is_equal_to(b)
        False
        sage: a.is_equal_to(b, 7)
        True
        """
        # Should be sped up later
        return (self - right).is_zero(absprec)

    def lift(self):
        raise NotImplementedError

    def lift_to_precision(self, absprec):
        """
        Returns self.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: w.lift_to_precision(10000)
        w + O(w^25)
        """
        return self

    def list(self, lift_mode = 'simple'):
        """
        Returns a list giving a series representation of self.

        If lift_mode == 'simple' or 'smallest', the returned list will consist
        of integers (in the eisenstein case) or a list of lists of integers (in the unramified case).
        self can be reconstructed as a sum of elements of the list times powers of the uniformiser (in the eisenstein case),
        or as a sum of powers of the p times polynomials in the generator (in the unramified case).
        If lift_mode == 'simple', all integers will be in the range [0,p-1], if 'smallest' they will be in the range [(1-p)/2, p/2].

        If lift_mode == 'teichmuller', returns a list of pAdicZZpXCRElements, all of which are Teichmuller representatives
        and such that self is the sum of that list times powers of the uniformizer.

        Note that zeros are truncated from the returned list, so you must use the valuation function to fully reconstruct self.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: y = W(775); y
        w^10 + 4*w^12 + 2*w^14 + w^15 + 2*w^16 + 4*w^17 + w^18 + w^20 + 2*w^21 + 3*w^22 + w^23 + w^24 + O(w^25)
        sage: y.list()
        [1, 0, 4, 0, 2, 1, 2, 4, 1, 0, 1, 2, 3, 1, 1]
        sage: y.list('smallest')
        [1, 0, -1, 0, 2, 1, 2, 0, 1, 2, 1, 1, -1, -1, 2]
        sage: w^10 - w^12 + 2*w^14 + w^15 + 2*w^16 + w^18 + 2*w^19 + w^20 + w^21 - w^22 - w^23 + 2*w^24
        w^10 + 4*w^12 + 2*w^14 + w^15 + 2*w^16 + 4*w^17 + w^18 + w^20 + 2*w^21 + 3*w^22 + w^23 + w^24 + O(w^25)
        sage: g = x^3 + 3*x + 3
        sage: A.<a> = R.ext(g)
        sage: y = 75 + 45*a + 1200*a^2; y
        4*a*5 + (3*a^2 + a + 3)*5^2 + 4*a^2*5^3 + a^2*5^4 + O(5^5)
        sage: y.list()
        [[0, 4], [3, 1, 3], [0, 0, 4], [0, 0, 1]]
        sage: y.list('smallest')
        [[0, -1], [-2, 2, -2], [1], [0, 0, 2]]
        sage: 5*((-2*5 + 25) + (-1 + 2*5)*a + (-2*5 + 2*125)*a^2)
        4*a*5 + (3*a^2 + a + 3)*5^2 + 4*a^2*5^3 + a^2*5^4 + O(5^5)
        """
        if lift_mode == 'simple':
            return self.ext_p_list(1)
        elif lift_mode == 'smallest':
            return self.ext_p_list(0)
        elif lift_mode == 'teichmuller':
            return self.teichmuller_list()
        else:
            raise ValueError, "lift mode must be one of 'simple', 'smallest' or 'teichmuller'"

    def teichmuller_list(self):
        raise NotImplementedError

    def _teichmuller_set(self):
        """
        Sets self to the teichmuller representative congruent to self modulo pi.

        This function should not be used externally: elements are supposed to be immutable.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: y = W.teichmuller(3); y #indirect doctest
        3 + 3*w^5 + w^7 + 2*w^9 + 2*w^10 + 4*w^11 + w^12 + 2*w^13 + 3*w^15 + 2*w^16 + 3*w^17 + w^18 + 3*w^19 + 3*w^20 + 2*w^21 + 2*w^22 + 3*w^23 + 4*w^24 + O(w^25)
        sage: y^5 == y
        True
        sage: g = x^3 + 3*x + 3
        sage: A.<a> = R.ext(g)
        sage: b = A.teichmuller(1 + 2*a - a^2); b
        (4*a^2 + 2*a + 1) + 2*a*5 + (3*a^2 + 1)*5^2 + (a + 4)*5^3 + (a^2 + a + 1)*5^4 + O(5^5)
        sage: b^125 == b
        True
        """
        if self.valuation_c() > 0:
            ZZ_pX_clear(self.value)
        else:
            self.prime_pow.teichmuller_set_c(&self.value, &self.value, self.prime_pow.ram_prec_cap)

    def multiplicative_order(self):
        raise NotImplementedError

    def padded_list(self, n, lift_mode = 'simple'):
        raise NotImplementedError

    def precision_absolute(self):
        """
        Returns the absolute precision of self, ie the precision cap of self.parent().

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: a = W(75); a
        3*w^10 + 2*w^12 + w^14 + w^16 + w^17 + 3*w^18 + 3*w^19 + 2*w^21 + 3*w^22 + 3*w^23 + O(w^25)
        sage: a.valuation()
        10
        sage: a.precision_absolute()
        25
        sage: a.precision_relative()
        15
        sage: a.unit_part()
        3 + 2*w^2 + w^4 + w^6 + w^7 + 3*w^8 + 3*w^9 + 2*w^11 + 3*w^12 + 3*w^13 + w^15 + 4*w^16 + 2*w^17 + w^18 + w^22 + 3*w^24 + O(w^25)
        """
        cdef Integer ans = PY_NEW(Integer)
        mpz_set_ui(ans.value, self.prime_pow.ram_prec_cap)
        return ans

    def precision_relative(self):
        """
        Returns the relative precision of self, ie the precision cap of self.parent() minus the valuation of self.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: a = W(75); a
        3*w^10 + 2*w^12 + w^14 + w^16 + w^17 + 3*w^18 + 3*w^19 + 2*w^21 + 3*w^22 + 3*w^23 + O(w^25)
        sage: a.valuation()
        10
        sage: a.precision_absolute()
        25
        sage: a.precision_relative()
        15
        sage: a.unit_part()
        3 + 2*w^2 + w^4 + w^6 + w^7 + 3*w^8 + 3*w^9 + 2*w^11 + 3*w^12 + 3*w^13 + w^15 + 4*w^16 + 2*w^17 + w^18 + w^22 + 3*w^24 + O(w^25)
        """
        cdef Integer ans = PY_NEW(Integer)
        mpz_set_ui(ans.value, self.prime_pow.ram_prec_cap - self.valuation_c())
        return ans

    def residue(self, n):
        raise NotImplementedError

    cpdef pAdicZZpXFMElement unit_part(self):
        """
        Returns the unit part of self, ie self / uniformizer^(self.valuation())

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: a = W(75); a
        3*w^10 + 2*w^12 + w^14 + w^16 + w^17 + 3*w^18 + 3*w^19 + 2*w^21 + 3*w^22 + 3*w^23 + O(w^25)
        sage: a.valuation()
        10
        sage: a.precision_absolute()
        25
        sage: a.precision_relative()
        15
        sage: a.unit_part()
        3 + 2*w^2 + w^4 + w^6 + w^7 + 3*w^8 + 3*w^9 + 2*w^11 + 3*w^12 + 3*w^13 + w^15 + 4*w^16 + 2*w^17 + w^18 + w^22 + 3*w^24 + O(w^25)
        """
        return self._rshift_c(self.valuation_c())

    cdef long valuation_c(self):
        """
        Returns the valuation of self.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: a = W(75); a
        3*w^10 + 2*w^12 + w^14 + w^16 + w^17 + 3*w^18 + 3*w^19 + 2*w^21 + 3*w^22 + 3*w^23 + O(w^25)
        sage: a.valuation()
        10
        sage: a.precision_absolute()
        25
        sage: a.precision_relative()
        15
        sage: a.unit_part()
        3 + 2*w^2 + w^4 + w^6 + w^7 + 3*w^8 + 3*w^9 + 2*w^11 + 3*w^12 + 3*w^13 + w^15 + 4*w^16 + 2*w^17 + w^18 + w^22 + 3*w^24 + O(w^25)
        """
        cdef long valuation, index
        ZZ_pX_min_val_coeff(valuation, index, self.value, self.prime_pow.pow_ZZ_tmp(1)[0])
        if index == -1: # self == 0
            return self.prime_pow.ram_prec_cap
        if self.prime_pow.e == 1:
            return valuation
        else:
            if index + valuation * self.prime_pow.e >= self.prime_pow.ram_prec_cap:
                return self.prime_pow.ram_prec_cap
            else:
                return index + valuation * self.prime_pow.e
            return index + valuation * self.prime_pow.e

    cdef ext_p_list(self, bint pos):
        """
        Returns a list giving a series representation of self.

        The returned list will consist of integers (in the eisenstein case) or a list of lists of integers (in the unramified case).
        self can be reconstructed as a sum of elements of the list times powers of the uniformiser (in the eisenstein case),
        or as a sum of powers of the p times polynomials in the generator (in the unramified case).
        If pos is True, all integers will be in the range [0,p-1], otherwise they will be in the range [(1-p)/2, p/2].

        Note that zeros are truncated from the returned list, so you must use the valuation function to fully reconstruct self.

        EXAMPLES:
        sage: R = ZpFM(5,5)
        sage: S.<x> = R[]
        sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
        sage: W.<w> = R.ext(f)
        sage: y = W(775); y
        w^10 + 4*w^12 + 2*w^14 + w^15 + 2*w^16 + 4*w^17 + w^18 + w^20 + 2*w^21 + 3*w^22 + w^23 + w^24 + O(w^25)
        sage: y.list() #indirect doctest
        [1, 0, 4, 0, 2, 1, 2, 4, 1, 0, 1, 2, 3, 1, 1]
        sage: y.list('smallest') #indirect doctest
        [1, 0, -1, 0, 2, 1, 2, 0, 1, 2, 1, 1, -1, -1, 2]
        sage: w^10 - w^12 + 2*w^14 + w^15 + 2*w^16 + w^18 + 2*w^19 + w^20 + w^21 - w^22 - w^23 + 2*w^24
        w^10 + 4*w^12 + 2*w^14 + w^15 + 2*w^16 + 4*w^17 + w^18 + w^20 + 2*w^21 + 3*w^22 + w^23 + w^24 + O(w^25)
        sage: g = x^3 + 3*x + 3
        sage: A.<a> = R.ext(g)
        sage: y = 75 + 45*a + 1200*a^2; y
        4*a*5 + (3*a^2 + a + 3)*5^2 + 4*a^2*5^3 + a^2*5^4 + O(5^5)
        sage: y.list() #indirect doctest
        [[0, 4], [3, 1, 3], [0, 0, 4], [0, 0, 1]]
        sage: y.list('smallest') #indirect doctest
        [[0, -1], [-2, 2, -2], [1], [0, 0, 2]]
        sage: 5*((-2*5 + 25) + (-1 + 2*5)*a + (-2*5 + 2*125)*a^2)
        4*a*5 + (3*a^2 + a + 3)*5^2 + 4*a^2*5^3 + a^2*5^4 + O(5^5)
        """
        return self.ext_p_list_precs(pos, self.prime_pow.ram_prec_cap)

def make_ZZpXFMElement(parent, f):
    """
    Creates a new pAdicZZpXFMElement out of an ntl_ZZ_pX f, with parent parent.  For use with pickling.

    EXAMPLES:
    sage: R = ZpFM(5,5)
    sage: S.<x> = R[]
    sage: f = x^5 + 75*x^3 - 15*x^2 +125*x - 5
    sage: W.<w> = R.ext(f)
    sage: z = (1 + w)^5 - 1
    sage: loads(dumps(z)) == z # indirect doctest
    True
    """
    return pAdicZZpXFMElement(parent, f)
