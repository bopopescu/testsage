"""
Arbitrary Precision Real Intervals

AUTHORS:

- Carl Witty (2007-01-21): based on ``real_mpfr.pyx``; changed it to
  use mpfi rather than mpfr.

- William Stein (2007-01-24): modifications and clean up and docs,
  etc.

- Niles Johnson (2010-08): Trac #3893: ``random_element()`` should pass on ``*args`` and ``**kwds``.

This is a straightforward binding to the MPFI library; it may be
useful to refer to its documentation for more details.

An interval is represented as a pair of floating-point numbers a
and b (where a <= b) and is printed as a standard floating-point
number with a question mark (for instance, 3.1416?). The question
mark indicates that the preceding digit may have an error of +/- 1.
These floating-point numbers are implemented using MPFR (the same
as the RealNumber elements of RealField).

There is also an alternate method of printing, where the interval
prints as [a .. b] (for instance, [3.1415 .. 3.1416]).

The interval represents the set { x : a <= x <= b } (so if a == b, then
the interval represents that particular floating-point number). The
endpoints can include positive and negative infinity, with the
obvious meaning. It is also possible to have a NaN (not-a-number)
interval, which is represented by having either endpoint be NaN.

PRINTING:

There are two styles for printing intervals: 'brackets' style and
'question' style (the default).

In question style, we print the "known correct" part of the number,
followed by a question mark. The question mark indicates that the
preceding digit is possibly wrong by +/- 1.

::

    sage: RIF(sqrt(2))
    1.414213562373095?

However, if the interval is precise (its lower bound is equal to
its upper bound) and equal to a not-too-large integer, then we just
print that integer.

::

    sage: RIF(0)
    0
    sage: RIF(654321)
    654321

::

    sage: RIF(123, 125)
    124.?
    sage: RIF(123, 126)
    1.3?e2

As we see in the last example, question style can discard almost a
whole digit's worth of precision. We can reduce this by allowing
"error digits": an error following the question mark, that gives
the maximum error of the digit(s) before the question mark. If the
error is absent (which it always is in the default printing), then
it is taken to be 1.

::

    sage: RIF(123, 126).str(error_digits=1)
    '125.?2'
    sage: RIF(123, 127).str(error_digits=1)
    '125.?2'
    sage: v = RIF(-e, pi); v
    0.?e1
    sage: v.str(error_digits=1)
    '1.?4'
    sage: v.str(error_digits=5)
    '0.2117?29300'

Error digits also sometimes let us indicate that the interval is
actually equal to a single floating-point number.

::

    sage: RIF(54321/256)
    212.19140625000000?
    sage: RIF(54321/256).str(error_digits=1)
    '212.19140625000000?0'

In brackets style, intervals are printed with the left value
rounded down and the right rounded up, which is conservative, but
in some ways unsatisfying.

Consider a 3-bit interval containing exactly the floating-point
number 1.25. In round-to-nearest or round-down, this prints as 1.2;
in round-up, this prints as 1.3. The straightforward options, then,
are to print this interval as [1.2 .. 1.2] (which does not even
contain the true value, 1.25), or to print it as [1.2 .. 1.3]
(which gives the impression that the upper and lower bounds are not
equal, even though they really are). Neither of these is very
satisfying, but we have chosen the latter.

::

    sage: R = RealIntervalField(3)
    sage: a = R(1.25)
    sage: a.str(style='brackets')
    '[1.2 .. 1.3]'
    sage: a == 1.25
    True
    sage: a == 2
    False

COMPARISONS:

Comparison operations (==,!=,<,<=,>,>=) return true if every value in
the first interval has the given relation to every value in the
second interval. The cmp(a, b) function works differently; it
compares two intervals lexicographically. (However, the behavior is
not specified if given a non-interval and an interval.)

This convention for comparison operators has good and bad points.  The
good:

- Expected transitivity properties hold (if a > b and b == c, then a >
  c; etc.)

- if a>b, then cmp(a, b) == 1; if a==b, then cmp(a,b) == 0; if a<b,
  then cmp(a, b) == -1

- a==0 is true if the interval contains only the floating-point number
  0; similarly for a==1

- a>0 means something useful (that every value in the interval is
  greater than 0)

The bad:

- Trichotomy fails to hold: there are values (a,b) such that none of
  a<b, a==b, or a>b are true

- It is not the case that if cmp(a, b) == 0 then a==b, or that if
  cmp(a, b) == 1 then a>b, or that if cmp(a, b) == -1 then a<b

- There are values a,b such that a<=b but neither a<b nor a==b hold

Note that intervals a and b overlap iff not(a != b).

EXAMPLES::

    sage: 0 < RIF(1, 2)
    True
    sage: 0 == RIF(0)
    True
    sage: not(0 == RIF(0, 1))
    True
    sage: not(0 != RIF(0, 1))
    True
    sage: 0 <= RIF(0, 1)
    True
    sage: not(0 < RIF(0, 1))
    True
    sage: cmp(RIF(0), RIF(0, 1))
    -1
    sage: cmp(RIF(0, 1), RIF(0))
    1
    sage: cmp(RIF(0, 1), RIF(1))
    -1
    sage: cmp(RIF(0, 1), RIF(0, 1))
    0
"""

############################################################################
#
#   Sage: System for Algebra and Geometry Experimentation
#
#       Copyright (C) 2005-2006 William Stein <wstein@gmail.com>
#
#                  http://www.gnu.org/licenses/
############################################################################

import math # for log
import sys

include '../ext/interrupt.pxi'
include "../ext/stdsage.pxi"
include "../ext/cdefs.pxi"

cimport sage.rings.ring
import  sage.rings.ring

cimport sage.structure.element
from sage.structure.element cimport RingElement, Element, ModuleElement
import  sage.structure.element

cimport real_mpfr
from real_mpfr cimport RealField_class, RealNumber
from real_mpfr import RealField
import real_mpfr

import operator

from integer import Integer
from integer cimport Integer

from real_double import RealDoubleElement
from real_double cimport RealDoubleElement

import sage.rings.complex_field

import sage.rings.infinity

from sage.structure.parent_gens cimport ParentWithGens

cdef class RealIntervalFieldElement(sage.structure.element.RingElement)

#*****************************************************************************
#
#       Implementation
#
#*****************************************************************************

# Global settings
printing_style = 'question'
printing_error_digits = 0

cdef double LOG_TEN_TWO_PLUS_EPSILON = 3.321928094887363 # a small overestimate of log(10,2)

#*****************************************************************************
#
#       Real Field
#
#*****************************************************************************
# The real field is in Cython, so mpfi elements will have access to
# their parent via direct C calls, which will be faster.

RealIntervalField_cache = {}

def RealIntervalField(prec=53, sci_not=False):
    r"""
    Construct a RealIntervalField_class, with caching.

    INPUT:

    -  ``prec`` - (integer) precision; default = 53:
       The number of bits used to represent the mantissa of a
       floating-point number. The precision can be any integer between
       mpfr_prec_min() and mpfr_prec_max(). In the current
       implementation, mpfr_prec_min() is equal to 2.

    -  ``sci_not`` - (default: False) whether or not to display using
       scientific notation

    EXAMPLES::

        sage: RealIntervalField()
        Real Interval Field with 53 bits of precision
        sage: RealIntervalField(200, sci_not=True)
        Real Interval Field with 200 bits of precision
        sage: RealIntervalField(53) is RIF
        True
        sage: RealIntervalField(200) is RIF
        False
        sage: RealIntervalField(200) is RealIntervalField(200)
        True

    See the documentation for :class:`~sage.rings.real_mpfi.RealIntervalField_class`
    for many more examples.
    """
    try:
        return RealIntervalField_cache[prec, sci_not]
    except KeyError:
        RealIntervalField_cache[prec, sci_not] = R = RealIntervalField_class(prec, sci_not)
        return R

cdef class RealIntervalField_class(sage.rings.ring.Field):
    """
    RealIntervalField(prec, sci_not):

    INPUT:

    -  ``prec`` - (integer) precision; default = 53 prec is
       the number of bits used to represent the mantissa of a
       floating-point number. The precision can be any integer between
       mpfr_prec_min() and mpfr_prec_max(). In the current
       implementation, mpfr_prec_min() is equal to 2.

    -  ``sci_not`` - (default: False) whether or not to display using
       scientific notation

    EXAMPLES::

        sage: RealIntervalField(10)
        Real Interval Field with 10 bits of precision
        sage: RealIntervalField()
        Real Interval Field with 53 bits of precision
        sage: RealIntervalField(100000)
        Real Interval Field with 100000 bits of precision

    .. note::

       The default precision is 53, since according to the GMP manual:
       'mpfr should be able to exactly reproduce all computations with
       double-precision machine floating-point numbers (double type in
       C), except the default exponent range is much wider and
       subnormal numbers are not implemented.'

    EXAMPLES: Creation of elements

    First with default precision. First we coerce elements of various
    types, then we coerce intervals.

    ::

        sage: RIF = RealIntervalField(); RIF
        Real Interval Field with 53 bits of precision
        sage: RIF(3)
        3
        sage: RIF(RIF(3))
        3
        sage: RIF(pi)
        3.141592653589794?
        sage: RIF(RealField(53)('1.5'))
        1.5000000000000000?
        sage: RIF(-2/19)
        -0.1052631578947369?
        sage: RIF(-3939)
        -3939
        sage: RIF(-3939r)
        -3939
        sage: RIF('1.5')
        1.5000000000000000?
        sage: R200 = RealField(200)
        sage: RIF(R200.pi())
        3.141592653589794?

    The base must be explicitly specified as a named parameter::

        sage: RIF('101101', base=2)
        45
        sage: RIF('+infinity')
        [+infinity .. +infinity]
        sage: RIF('[1..3]').str(style='brackets')
        '[1.0000000000000000 .. 3.0000000000000000]'

    Next we coerce some 2-tuples, which define intervals.

    ::

        sage: RIF((-1.5, -1.3))
        -1.4?
        sage: RIF((RDF('-1.5'), RDF('-1.3')))
        -1.4?
        sage: RIF((1/3,2/3)).str(style='brackets')
        '[0.33333333333333331 .. 0.66666666666666675]'

    The extra parentheses aren't needed.

    ::

        sage: RIF(1/3,2/3).str(style='brackets')
        '[0.33333333333333331 .. 0.66666666666666675]'
        sage: RIF((1,2)).str(style='brackets')
        '[1.0000000000000000 .. 2.0000000000000000]'
        sage: RIF((1r,2r)).str(style='brackets')
        '[1.0000000000000000 .. 2.0000000000000000]'
        sage: RIF((pi, e)).str(style='brackets')
        '[2.7182818284590455 .. 3.1415926535897932]'

    Values which can be represented as an exact floating-point number
    (of the precision of this RealIntervalField) result in a precise
    interval, where the lower bound is equal to the upper bound (even
    if they print differently). Other values typically result in an
    interval where the lower and upper bounds are adjacent
    floating-point numbers.

    ::

        sage: def check(x):
        ...       return (x, x.lower() == x.upper())
        sage: check(RIF(pi))
        (3.141592653589794?, False)
        sage: check(RIF(RR(pi)))
        (3.1415926535897932?, True)
        sage: check(RIF(1.5))
        (1.5000000000000000?, True)
        sage: check(RIF('1.5'))
        (1.5000000000000000?, True)
        sage: check(RIF(0.1))
        (0.10000000000000001?, True)
        sage: check(RIF(1/10))
        (0.10000000000000000?, False)
        sage: check(RIF('0.1'))
        (0.10000000000000000?, False)

    Similarly, when specifying both ends of an interval, the lower end
    is rounded down and the upper end is rounded up.

    ::

        sage: outward = RIF(1/10, 7/10); outward.str(style='brackets')
        '[0.099999999999999991 .. 0.70000000000000007]'
        sage: nearest = RIF(RR(1/10), RR(7/10)); nearest.str(style='brackets')
        '[0.10000000000000000 .. 0.69999999999999996]'
        sage: nearest.lower() - outward.lower()
        1.38777878078144e-17
        sage: outward.upper() - nearest.upper()
        1.11022302462516e-16

    Some examples with a real interval field of higher precision::

        sage: R = RealIntervalField(100)
        sage: R(3)
        3
        sage: R(R(3))
        3
        sage: R(pi)
        3.14159265358979323846264338328?
        sage: R(-2/19)
        -0.1052631578947368421052631578948?
        sage: R(e,pi).str(style='brackets')
        '[2.7182818284590452353602874713512 .. 3.1415926535897932384626433832825]'

    TESTS::

        sage: RIF._lower_field() is RealField(53, rnd='RNDD')
        True
        sage: RIF._upper_field() is RealField(53, rnd='RNDU')
        True
        sage: RIF._middle_field() is RR
        True
        sage: TestSuite(RIF).run()
    """

    def __init__(self, int prec=53, int sci_not=0):
        if prec < MPFR_PREC_MIN or prec > MPFR_PREC_MAX:
            raise ValueError, "prec (=%s) must be >= %s and <= %s."%(
                prec, MPFR_PREC_MIN, MPFR_PREC_MAX)
        self.__prec = prec
        self.sci_not = sci_not
        self.__lower_field = RealField(prec, sci_not, "RNDD")
        self.__middle_field = RealField(prec, sci_not, "RNDN")
        self.__upper_field = RealField(prec, sci_not, "RNDU")
        from sage.categories.fields import Fields
        ParentWithGens.__init__(self, self, tuple([]), False, category = Fields())

    def _lower_field(self):
        return self.__lower_field

    def _middle_field(self):
        return self.__middle_field

    def _upper_field(self):
        return self.__upper_field

    def _real_field(self, rnd):
        if rnd == "RNDD":
            return self._lower_field()
        elif rnd == "RNDN":
            return self._middle_field()
        elif rnd == "RNDU":
            return self._upper_field()
        else:
            return RealField(self.__prec, self.sci_not, "RNDZ")

    cdef RealIntervalFieldElement _new(self):
        """
        Return a new real number with parent self.
        """
        cdef RealIntervalFieldElement x
        x = PY_NEW(RealIntervalFieldElement)
        x._parent = self
        mpfi_init2(x.value, self.__prec)
        x.init = 1
        return x

    def _repr_(self):
        s = "Real Interval Field with %s bits of precision"%self.__prec
        return s

    def _latex_(self):
        r"""
        LaTeX representation for Real Interval Field.

        EXAMPLES::

            sage: RIF._latex_()
            '\\Bold{I} \\Bold{R}'
        """
        return "\\Bold{I} \\Bold{R}"

    def _sage_input_(self, sib, coerce):
        r"""
        Produce an expression which will reproduce this value when evaluated.

        EXAMPLES:
            sage: sage_input(RIF, verify=True)
            # Verified
            RIF
            sage: sage_input(RealIntervalField(25), verify=True)
            # Verified
            RealIntervalField(25)
            sage: k = (RIF, RealIntervalField(37), RealIntervalField(1024))
            sage: sage_input(k, verify=True)
            # Verified
            (RIF, RealIntervalField(37), RealIntervalField(1024))
            sage: sage_input((k, k), verify=True)
            # Verified
            RIF37 = RealIntervalField(37)
            RIF1024 = RealIntervalField(1024)
            ((RIF, RIF37, RIF1024), (RIF, RIF37, RIF1024))
            sage: from sage.misc.sage_input import SageInputBuilder
            sage: RealIntervalField(2)._sage_input_(SageInputBuilder(), False)
            {call: {atomic:RealIntervalField}({atomic:2})}
        """
        if self.prec() == 53:
            return sib.name('RIF')

        v = sib.name('RealIntervalField')(sib.int(self.prec()))
        name = 'RIF%d' % self.prec()
        sib.cache(self, v, name)
        return v

    cpdef bint is_exact(self) except -2:
        return False

    def __call__(self, x, y=None, int base=10):
        """
        Create an element in this real interval field.

        INPUT:

        -  ``x`` - a number, string, or 2-tuple.

        -  ``y`` - (default: None); if given x is set to (x,y);
           this is so you can write R(2,3) to make the interval from 2 to 3.

        -  ``base`` - integer (default: 10) - only used if x is
           a string.

        OUTPUT: an element of this real interval field.

        EXAMPLES::

            sage: R = RealIntervalField(20)
            sage: R('1.234')
            1.23400?
            sage: R('2', base=2)
            Traceback (most recent call last):
            ...
            TypeError: Unable to convert number to real interval.
            sage: a = R('1.1001', base=2); a
            1.5625000?
            sage: a.str(2)
            '1.1001000000000000000?'

        Type: RealIntervalField? for more information.
        """
        if not y is None:
            x = (x,y)
        return RealIntervalFieldElement(self, x, base)

    def construction(self):
        """
        Returns the functorial construction of self, namely, completion of
        the rational numbers with respect to the prime at `\infty`,
        and the note that this is an interval field.

        Also preserves other information that makes this field unique (e.g.
        precision, print mode).

        EXAMPLES::

            sage: R = RealIntervalField(123)
            sage: c, S = R.construction(); S
            Rational Field
            sage: R == c(S)
            True
        """
        from sage.categories.pushout import CompletionFunctor
        return (CompletionFunctor(sage.rings.infinity.Infinity,
                                  self.prec(),
                                  {'sci_not': self.scientific_notation(), 'type': 'Interval'}),
               sage.rings.rational_field.QQ)

    cdef _coerce_c_impl(self, x):
        """
        Canonical coercion of x to this mpfi real field.

        The rings that canonically coerce to this mpfi real field are:

        - this mpfi field itself

        - any mpfr real field with precision that is as large as this
          one

        - any other mpfi real field with precision that is as large as
          this one

        - anything that canonically coerces to the mpfr real field
          with same precision as self.

        Values which can be exactly represented as a floating-point number
        are coerced to a precise interval, with upper and lower bounds
        equal; otherwise, the upper and lower bounds will typically be
        adjacent floating-point numbers that surround the given value.
        """
        if isinstance(x, real_mpfr.RealNumber):
            P = x.parent()
            if (<RealField_class> P).__prec >= self.__prec:
                return self(x)
            else:
                raise TypeError, "Canonical coercion from lower to higher precision not defined"
        if isinstance(x, RealIntervalFieldElement):
            P = x.parent()
            if (<RealIntervalField_class> P).__prec >= self.__prec:
                return self(x)
            else:
                raise TypeError, "Canonical coercion from lower to higher precision not defined"
        if isinstance(x, (Integer, Rational)):
            return self(x)
        cdef RealNumber lower, upper
        try:
            lower = self.__lower_field._coerce_(x)
            upper = self.__upper_field._coerce_(x)
            return self(lower, upper)
        except TypeError, msg:
            raise TypeError, "no canonical coercion of element into self"

    def __cmp__(self, other):
        """
        EXAMPLES::

            sage: RealIntervalField(10) == RealIntervalField(11)
            False
            sage: RealIntervalField(10) == RealIntervalField(10)
            True
            sage: RealIntervalField(10,sci_not=True) == RealIntervalField(10,sci_not=False)
            True
            sage: RealIntervalField(10) == IntegerRing()
            False
        """
        if not isinstance(other, RealIntervalField_class):
            return -1
        cdef RealIntervalField_class _other
        _other = other  # to access C structure
        if self.__prec == _other.__prec:
            return 0
        return 1

    def __reduce__(self):
        """
        EXAMPLES::

            sage: R = RealIntervalField(sci_not=1, prec=200)
            sage: loads(dumps(R)) == R
            True
        """
        return __create__RealIntervalField_version0, (self.__prec, self.sci_not)

    def random_element(self, *args, **kwds):
        """
        Returns a random element of self. Any arguments or keywords are
        passed onto the random element function in real field.

        By default, this is uniformly distributed in `[-1, 1]`.

        EXAMPLES::

            sage: RIF.random_element()
            0.15363619378561300?
            sage: RIF.random_element()
            -0.50298737524751780?
            sage: RIF.random_element(-100, 100)
            60.958996432224126?

        Passes extra positional or keyword arguments through::

            sage: RIF.random_element(min=0, max=100)
            2.5572702830891970?
            sage: RIF.random_element(min=-100, max=0)
            -1.5803457307118123?
        """
        return self(self._middle_field().random_element(*args, **kwds))

    def gen(self, i=0):
        if i == 0:
            return self(1)
        else:
            raise IndexError

    def complex_field(self):
        """
        Return complex field of the same precision.

        EXAMPLES::

            sage: RIF.complex_field()
            Complex Interval Field with 53 bits of precision
        """
        return sage.rings.complex_interval_field.ComplexIntervalField(self.prec())

    def ngens(self):
        return 1

    def gens(self):
        return [self.gen()]

    def _is_valid_homomorphism_(self, codomain, im_gens):
        try:
            s = codomain._coerce_(self(1))
        except TypeError:
            return False
        return s == im_gens[0]

    def is_atomic_repr(self):
        """
        Returns True, to signify that elements of this field print without
        sums, so parenthesis aren't required, e.g., in coefficients of
        polynomials.

        EXAMPLES::

            sage: RealIntervalField(10).is_atomic_repr()
            True
        """
        return True

    def is_finite(self):
        """
        Returns False, since the field of real numbers is not finite.

        EXAMPLES::

            sage: RealIntervalField(10).is_finite()
            False
        """
        return False

    def characteristic(self):
        """
        Returns 0, since the field of real numbers has characteristic 0.

        EXAMPLES::

            sage: RealIntervalField(10).characteristic()
            0
        """
        return Integer(0)

    def name(self):
        return "IntervalRealIntervalField%s"%(self.__prec)

    def __hash__(self):
        return hash(self.name())

    def precision(self):
        return self.__prec

    def prec(self):
        """
        Returns the precision of this field (in bits).

        EXAMPLES::

            sage: RIF.prec()
            53
            sage: RealIntervalField(200).prec()
            200
        """
        return self.__prec

    def to_prec(self, prec):
        """
        Returns a real interval field to the given precision.

        EXAMPLES::

            sage: RIF.to_prec(200)
            Real Interval Field with 200 bits of precision
            sage: RIF.to_prec(20)
            Real Interval Field with 20 bits of precision
            sage: RIF.to_prec(53) is RIF
            True
        """
        return RealIntervalField(prec)

    def _magma_init_(self, magma):
        r"""
        Return a string representation of self in the Magma language.

        EXAMPLES::

            sage: magma(RealIntervalField(80)) # optional - magma
            Real field of precision 24
            sage: floor(RR(log(2**80, 10)))
            24
        """
        return "RealField(%s : Bits := true)" % self.prec()

    def pi(self):
        """
        Returns pi to the precision of this field.

        EXAMPLES::

            sage: R = RealIntervalField(100)
            sage: R.pi()
            3.14159265358979323846264338328?
            sage: R.pi().sqrt()/2
            0.88622692545275801364908374167?
            sage: R = RealIntervalField(150)
            sage: R.pi().sqrt()/2
            0.886226925452758013649083741670572591398774728?
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        mpfi_const_pi(x.value)
        return x

    def euler_constant(self):
        """
        Returns Euler's gamma constant to the precision of this field.

        EXAMPLES::

            sage: RealIntervalField(100).euler_constant()
            0.577215664901532860606512090083?
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        mpfi_const_euler(x.value)
        return x

#     def catalan_constant(self):
#         """
#         Returns Catalan's constant to the precision of this field.

#         EXAMPLES:
#             sage: RealIntervalField(100).catalan_constant()
#             0.91596559417721901505460351493
#         """
#         cdef RealIntervalFieldElement x
#         x = self._new()
#         mpfr_const_catalan(x.value, self.rnd)
#         return x

    def log2(self):
        """
        Returns log(2) to the precision of this field.

        EXAMPLES::

            sage: R=RealIntervalField(100)
            sage: R.log2()
            0.693147180559945309417232121458?
            sage: R(2).log()
            0.693147180559945309417232121458?
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        mpfi_const_log2(x.value)
        return x

# MPFI does not have factorial
#     def factorial(self, int n):
#         """
#         Return the factorial of the integer n as a real number.
#         """
#         cdef RealIntervalFieldElement x
#         if n < 0:
#             raise ArithmeticError, "n must be nonnegative"
#         x = self._new()
#         mpfr_fac_ui(x.value, n, self.rnd)
#         return x

    def scientific_notation(self, status=None):
        """
        Set or return the scientific notation printing flag. If this flag
        is True then real numbers with this space as parent print using
        scientific notation.

        INPUT:

        -  ``status`` - (bool -) optional flag
        """
        if status is None:
            return self.sci_not
        else:
            self.sci_not = status

    def zeta(self, n=2):
        """
        Return an `n`-th root of unity in the real field, if one
        exists, or raise a ValueError otherwise.

        EXAMPLES::

            sage: R = RealIntervalField()
            sage: R.zeta()
            -1
            sage: R.zeta(1)
            1
            sage: R.zeta(5)
            Traceback (most recent call last):
            ...
            ValueError: No 5th root of unity in self
        """
        if n == 1:
            return self(1)
        elif n == 2:
            return self(-1)
        raise ValueError, "No %sth root of unity in self"%n

R = RealIntervalField()

#*****************************************************************************
#
#     RealIntervalFieldElement -- element of Real Field
#
#
#
#*****************************************************************************
cdef class RealIntervalFieldElement(sage.structure.element.RingElement):
    """
    A real number interval.
    """
    cdef RealIntervalFieldElement _new(self):
        """
        Return a new real interval with same parent as self.
        """
        cdef RealIntervalFieldElement x
        x = PY_NEW(RealIntervalFieldElement)
        x._parent = self._parent
        mpfi_init2(x.value, (<RealIntervalField_class>self._parent).__prec)
        x.init = 1
        return x

    def __init__(self, RealIntervalField_class parent, x=0, int base=10):
        """
        Create a real interval element. Should be called by first creating
        a RealIntervalField, as illustrated in the examples.

        EXAMPLES::

            sage: R = RealIntervalField()
            sage: R('1.2456')
            1.245600000000000?
            sage: R = RealIntervalField(3)
            sage: R('1.2456').str(style='brackets')
            '[1.0 .. 1.3]'

        EXAMPLE: Rounding

        ::

            sage: w = RealIntervalField(3)(5/2)
            sage: RealIntervalField(2)(w).str(2, style='brackets')
            '[10. .. 11.]'

        TESTS::

            sage: a = RealIntervalField(428)(factorial(100)/exp(2)); a
            1.26303298005073195998439505058085204028142920134742241494671502106333548593576383141666758300089860337889002385197008191910406895?e157
            sage: a.diameter()
            4.7046373946079775711568954992429894854882556641460240333441655212438503516287848720594584761250430179569094634219773739322602945e-129

        Type: RealIntervalField? for many more examples.
        """
        import sage.rings.qqbar

        self.init = 0
        if parent is None:
            raise TypeError
        self._parent = parent
        mpfi_init2(self.value, parent.__prec)
        self.init = 1
        if x is None: return
        cdef RealIntervalFieldElement _x, n, d
        cdef RealNumber rn, rn1
        cdef Rational rat, rat1
        cdef Integer integ, integ1
        cdef RealDoubleElement dx, dx1
        cdef int ix, ix1
        if PY_TYPE_CHECK(x, RealIntervalFieldElement):
            _x = x  # so we can get at x.value
            mpfi_set(self.value, _x.value)
        elif PY_TYPE_CHECK(x, RealNumber):
            rn = x
            mpfi_set_fr(self.value, rn.value)
        elif PY_TYPE_CHECK(x, Rational):
            rat = x
            mpfi_set_q(self.value, rat.value)
        elif PY_TYPE_CHECK(x, Integer):
            integ = x
            mpfi_set_z(self.value, integ.value)
        elif PY_TYPE_CHECK(x, int):
            ix = x
            mpfi_set_si(self.value, ix)
        elif isinstance(x, tuple):
            try:
                a, b = x
            except ValueError:
                raise TypeError, "tuple defining an interval must have length 2"
            if PY_TYPE_CHECK(a, RealNumber) and PY_TYPE_CHECK(b, RealNumber):
                rn = a
                rn1 = b
                mpfi_interv_fr(self.value, rn.value, rn1.value)
            elif PY_TYPE_CHECK(a, RealDoubleElement) and PY_TYPE_CHECK(b, RealDoubleElement):
                dx = a
                dx1 = b
                mpfi_interv_d(self.value, dx._value, dx1._value)
            elif PY_TYPE_CHECK(a, Rational) and PY_TYPE_CHECK(b, Rational):
                rat = a
                rat1 = b
                mpfi_interv_q(self.value, rat.value, rat1.value)
            elif PY_TYPE_CHECK(a, Integer) and PY_TYPE_CHECK(b, Integer):
                integ = a
                integ1 = b
                mpfi_interv_z(self.value, integ.value, integ1.value)
            elif PY_TYPE_CHECK(a, int) and PY_TYPE_CHECK(b, int):
                ix = a
                ix1 = b
                mpfi_interv_si(self.value, ix, ix1)
            else:  # generic fallback
                rn  = self._parent(a).lower()
                rn1 = self._parent(b).upper()
                mpfi_interv_fr(self.value, rn.value, rn1.value)

        elif isinstance(x, sage.rings.qqbar.AlgebraicReal):
            d = x.interval(self._parent)
            mpfi_set(self.value, d.value)

        elif hasattr(x, '_real_mpfi_'):
            d = x._real_mpfi_(self._parent)
            mpfi_set(self.value, d.value)

        else:
            from sage.symbolic.expression import Expression

            if isinstance(x, Expression):
                d = x._real_mpfi_(self._parent)
                mpfi_set(self.value, d.value)

            elif isinstance(x, str):
                # string
                s = str(x).replace('..', ',').replace(' ','').replace('+infinity', '@inf@').replace('-infinity','-@inf@')
                if mpfi_set_str(self.value, s, base):
                    raise TypeError, "Unable to convert number to real interval."
            else:
                # try coercing to real
                try:
                    rn = self._parent._lower_field()(x)
                    rn1 = self._parent._upper_field()(x)
                except TypeError:
                    raise TypeError, "Unable to convert number to real interval."
                mpfi_interv_fr(self.value, rn.value, rn1.value)

    def __reduce__(self):
        """
        Pickling support.

        EXAMPLES::

            sage: a = RIF(5,5.5)
            sage: cmp(loads(dumps(a)), a)
            0
            sage: R = RealIntervalField(sci_not=1, prec=200)
            sage: b = R('393.39203845902384098234098230948209384028340')
            sage: cmp(loads(dumps(b)), b)
            0
            sage: b = R(1)/R(0); b # R(0) has no particular sign, thus 1/R(0) covers the whole reals
            [-infinity .. +infinity]
            sage: c = loads(dumps(b))
            sage: (c.lower(), c.upper()) == (b.lower(), b.upper())
            True
            sage: b = R(-1)/R(0); b # same as above
            [-infinity .. +infinity]
            sage: c = loads(dumps(b))
            sage: (c.lower(), c.upper()) == (b.lower(), b.upper())
            True
            sage: b = R('[2 .. 3]'); b.str(error_digits=1)
            '2.5?5'
            sage: cmp(loads(dumps(b)), b)
            0
            sage: R = RealIntervalField(4000)
            sage: s = 1/R(3)
            sage: t = loads(dumps(s))
            sage: (t.upper(), t.lower()) == (s.upper(), s.lower())
            True
            sage: loads(dumps(1/RIF(0,1)))
            [1.0000000000000000 .. +infinity]
        """
        return (__create__RealIntervalFieldElement_version1, (self._parent, self.upper(), self.lower()))

    def  __dealloc__(self):
        if self.init:
            mpfi_clear(self.value)

    def __repr__(self):
        return self.str(10)

    def _latex_(self):
        return str(self)

    def _magma_init_(self, magma):
        r"""
        Return a string representation of self in the Magma language.

        EXAMPLES::

            sage: t = RIF(10, 10.5); t
            11.?
            sage: magma(t) # optional - magma
            10.2500000000000
        """
        return "%s!%s" % (self.parent()._magma_init_(magma), self.center())

    def _interface_init_(self, I=None):
        """
        Raise a TypeError.

        This function would return the string representation of self that
        makes sense as a default representation of a real interval in other
        computer algebra systems. But, most other computer algebra systems
        do not support interval arithmetic, so instead we just raise a
        TypeError.

        Define the appropriate _cas_init_ function if there is a
        computer algebra system you would like to support.

        EXAMPLES::

            sage: n = RIF(1.3939494594)
            sage: n._interface_init_()
            Traceback (most recent call last):
            ...
            TypeError

        Here's a conversion to Maxima happens, which results in a type
        error::

            sage: a = RealInterval('2.3')
            sage: maxima(a)
            Traceback (most recent call last):
            ...
            TypeError
        """
        raise TypeError

    def _sage_input_(self, sib, coerce):
        r"""
        Produce an expression which will reproduce this value when evaluated.

        EXAMPLES:
            sage: sage_input(RIF(e, pi), verify=True)
            # Verified
            RIF(RR(2.7182818284590451), RR(3.1415926535897936))
            sage: sage_input(RealIntervalField(64)(sqrt(2)), preparse=False, verify=True)
            # Verified
            RR64 = RealField(64)
            RealIntervalField(64)(RR64('1.41421356237309504876'), RR64('1.41421356237309504887'))
            sage: sage_input(RealIntervalField(2)(12), verify=True)
            # Verified
            RealIntervalField(2)(RealField(2)(12.))
            sage: sage_input(RealIntervalField(2)(13), verify=True)
            # Verified
            RR2 = RealField(2)
            RealIntervalField(2)(RR2(12.), RR2(16.))
            sage: from sage.misc.sage_input import SageInputBuilder
            sage: sib = SageInputBuilder()
            sage: RIF(-sqrt(3), -sqrt(2))._sage_input_(sib, False)
            {call: {atomic:RIF}({unop:- {call: {atomic:RR}({atomic:1.7320508075688774})}}, {unop:- {call: {atomic:RR}({atomic:1.4142135623730949})}})}
        """
        # Interval printing could often be much prettier,
        # but I'm feeling lazy :)
        if self.is_exact():
            return sib(self.parent())(sib(self.lower(rnd='RNDN')))
        else:
            # The following line would also be correct, but even though it
            # uses coerced=2, that doesn't help because RealNumber doesn't
            # print pretty for directed-rounding fields.
            #return sib(self.parent())(sib(self.lower(), 2), sib(self.upper(), 2))
            return sib(self.parent())(sib(self.lower(rnd='RNDN')), sib(self.upper(rnd='RNDN')))

    def __hash__(self):
        return hash(self.str(16))

    def _im_gens_(self, codomain, im_gens):
        return codomain(self) # since 1 |--> 1

    def real(self):
        """
        Return the real part of self.

        (Since self is a real number, this simply returns self.)
        """
        return self

    def parent(self):
        """
        EXAMPLES::

            sage: R = RealIntervalField()
            sage: a = R('1.2456')
            sage: a.parent()
            Real Interval Field with 53 bits of precision
        """
        return self._parent

    # MPFR had an elaborate "truncation" scheme to avoid printing
    # inaccurate-looking results; this has been removed for MPFI,
    # because I think it's less confusing to get such results than to
    # see [0.333 .. 0.333] for an interval with unequal left and right
    # sides.
    def str(self, int base=10, style=None, no_sci=None, e=None, error_digits=None):
        r"""
        INPUT:

        -  ``base`` - base for output

        -  ``style`` - The printing style; either 'brackets' or
           'question' (or None, to use the current default).

        -  ``no_sci`` - if True do not print using scientific
           notation; if False print with scientific notation; if None (the
           default), print how the parent prints.

        -  ``e`` - symbol used in scientific notation

        -  ``error_digits`` - The number of digits of error to
           print, in 'question' style.

        We support two different styles of printing; 'question' style and
        'brackets' style. In question style (the default), we print the
        "known correct" part of the number, followed by a question mark::

            sage: RIF(pi).str()
            '3.141592653589794?'
            sage: RIF(pi, 22/7).str()
            '3.142?'
            sage: RIF(pi, 22/7).str(style='question')
            '3.142?'

        However, if the interval is precisely equal to some integer that's
        not too large, we just return that integer.

        ::

            sage: RIF(-42).str()
            '-42'
            sage: RIF(0).str()
            '0'
            sage: RIF(12^5).str(base=3)
            '110122100000'

        Very large integers, however, revert to the normal question-style
        printing.

        ::

            sage: RIF(3^7).str()
            '2187'
            sage: RIF(3^7 * 2^256).str()
            '2.5323729916201052?e80'

        In brackets style, we print the lower and upper bounds of the
        interval within brackets::

            sage: RIF(237/16).str(style='brackets')
            '[14.812500000000000 .. 14.812500000000000]'

        Note that the lower bound is rounded down, and the upper bound is
        rounded up. So even if the lower and upper bounds are equal, they
        may print differently. (This is done so that the printed
        representation of the interval contains all the numbers in the
        internal binary interval.)

        For instance, we find the best 10-bit floating point representation
        of 1/3::

            sage: RR10 = RealField(10)
            sage: RR(RR10(1/3))
            0.333496093750000

        And we see that the point interval containing only this
        floating-point number prints as a wider decimal interval, that does
        contain the number::

            sage: RIF10 = RealIntervalField(10)
            sage: RIF10(RR10(1/3)).str(style='brackets')
            '[0.33349 .. 0.33350]'

        We always use brackets style for NaN and infinities.

        ::

            sage: RIF(pi, infinity)
            [3.1415926535897931 .. +infinity]
            sage: RIF(NaN)
            [.. NaN ..]

        Let's take a closer, formal look at the question style. In its full
        generality, a number printed in the question style looks like:

        MANTISSA ?ERROR eEXPONENT

        (without the spaces). The "eEXPONENT" part is optional; if it is
        missing, then the exponent is 0. (If the base is greater than 10,
        then the exponent separator is "@" instead of "e".)

        The "ERROR" is optional; if it is missing, then the error is 1.

        The mantissa is printed in base `b`, and always contains a
        decimal point (also known as a radix point, in bases other than
        10). (The error and exponent are always printed in base 10.)

        We define the "precision" of a floating-point printed
        representation to be the positional value of the last digit of the
        mantissa. For instance, in 2.7?e5, the precision is `10^4`;
        in 8.?, the precision is `10^0`; and in 9.35? the precision
        is `10^{-2}`. This precision will always be `10^k`
        for some `k` (or, for an arbitrary base `b`,
        `b^k`).

        Then the interval is contained in the interval:

        .. math::

            \text{mantissa}*b^{\text{exponent}} - \text{error}*b^k ..
            \text{mantissa}*b^{\text{exponent}} + \text{error}*b^k

        To control the printing, we can specify a maximum number of error
        digits. The default is 0, which means that we do not print an error
        at all (so that the error is always the default, 1).

        Now, consider the precisions needed to represent the endpoints
        (this is the precision that would be produced by
        ``v.lower().str(no_sci=False, truncate=False)``). Our
        result is no more precise than the less precise endpoint, and is
        sufficiently imprecise that the error can be represented with the
        given number of decimal digits. Our result is the most precise
        possible result, given these restrictions. When there are two
        possible results of equal precision and with the same error width,
        then we pick the one which is farther from zero. (For instance,
        RIF(0, 123) with two error digits could print as 61.?62 or 62.?62.
        We prefer the latter because it makes it clear that the interval is
        known not to be negative.)

        EXAMPLES::

            sage: a = RIF(59/27); a
            2.185185185185186?
            sage: a.str()
            '2.185185185185186?'
            sage: a.str(style='brackets')
            '[2.1851851851851851 .. 2.1851851851851856]'
            sage: a.str(16)
            '2.2f684bda12f69?'
            sage: a.str(no_sci=False)
            '2.185185185185186?e0'
            sage: pi_appr = RIF(pi, 22/7)
            sage: pi_appr.str(style='brackets')
            '[3.1415926535897931 .. 3.1428571428571433]'
            sage: pi_appr.str()
            '3.142?'
            sage: pi_appr.str(error_digits=1)
            '3.1422?7'
            sage: pi_appr.str(error_digits=2)
            '3.14223?64'
            sage: pi_appr.str(base=36)
            '3.6?'
            sage: RIF(NaN)
            [.. NaN ..]
            sage: RIF(pi, infinity)
            [3.1415926535897931 .. +infinity]
            sage: RIF(-infinity, pi)
            [-infinity .. 3.1415926535897936]
            sage: RealIntervalField(210)(3).sqrt()
            1.732050807568877293527446341505872366942805253810380628055806980?
            sage: RealIntervalField(210)(RIF(3).sqrt())
            1.732050807568878?
            sage: RIF(3).sqrt()
            1.732050807568878?
            sage: RIF(0, 3^-150)
            1.?e-71
        """
        if base < 2 or base > 36:
            raise ValueError, "the base (=%s) must be between 2 and 36"%base

        # If self is a NaN, always use brackets style.
        if mpfi_nan_p(self.value):
            if base >= 24:
                return "[.. @NaN@ ..]"
            else:
                return "[.. NaN ..]"

        if e is None:
            if base > 10:
                e = '@'
            else:
                e = 'e'

        if style is None:
            style = printing_style
        if error_digits is None:
            error_digits = printing_error_digits

        if mpfr_inf_p(&self.value.left) or mpfr_inf_p(&self.value.right):
            style = 'brackets'

        if style == 'brackets':
            t1 = self.lower().str(base=base, no_sci=no_sci, e=e, truncate=False)
            t2 = self.upper().str(base=base, no_sci=no_sci, e=e, truncate=False)

            return "[%s .. %s]"%(t1, t2)

        elif style == 'question':
            if no_sci == False:
                prefer_sci = True
            else:
                prefer_sci = False
            return self._str_question_style(base, error_digits, e, prefer_sci)

        else:
            raise ValueError, 'Illegal interval printing style %s'%printing_style

    cpdef _str_question_style(self, int base, int error_digits, e, bint prefer_sci):
        r"""
        Compute the "question-style print representation" of this value,
        with the given base and error_digits. See the documentation for
        the str method for the definition of the question style.

        INPUTS:

          - ``base`` - base for output

          - ``error_digits`` - maximum number of decimal digits for error

          - ``e`` - symbol for exponent (typically ``'e'`` for base
            less than or equal to 10, ``'@'`` for larger base)

          - ``prefer_sci`` - ``True`` to always print in scientific notation;
            ``False`` to prefer non-scientific notation when
            possible

        EXAMPLES::

            sage: v = RIF(e, pi)
            sage: v.str(2, style='brackets')
            '[10.101101111110000101010001011000101000101011101101001 .. 11.001001000011111101101010100010001000010110100011001]'
            sage: v._str_question_style(2, 0, 'e', False)
            '11.0?'
            sage: v._str_question_style(2, 3, '@', False)
            '10.111011100001?867'
            sage: v._str_question_style(2, 30, 'e', False)
            '10.111011100001000001011101111101011000100001001000001?476605618580184'
            sage: v.str(5, style='brackets')
            '[2.32434303404423034041024 .. 3.03232214303343241124132]'
            sage: v._str_question_style(5, 3, '@', False)
            '2.43111?662'
            sage: (Integer('232434', 5) + 2*662).str(5)
            '303233'
            sage: v.str(style='brackets')
            '[2.7182818284590450 .. 3.1415926535897936]'
            sage: v._str_question_style(10, 3, '@', False)
            '2.930?212'
            sage: v._str_question_style(10, 3, '@', True)
            '2.930?212@0'
            sage: v.str(16, style='brackets')
            '[2.b7e151628aed2 .. 3.243f6a8885a32]'
            sage: v._str_question_style(16, 3, '@', False)
            '2.ee1?867'
            sage: (Integer('2b7e', 16) + 2*867).str(16)
            '3244'
            sage: v.str(36, style='brackets')
            '[2.puw5nggjf8f .. 3.53i5ab8p5gz]'
            sage: v._str_question_style(36, 3, '@', False)
            '2.xh?275'
            sage: (Integer('2pu', 36) + 2*275).str(36)
            '354'

        TESTS::

            sage: RIF(0, infinity)._str_question_style(10, 0, 'e', False)
            Traceback (most recent call last):
            ...
            ValueError: _str_question_style on NaN or infinity
            sage: for i in range(1, 9):
            ...       print RIF(-10^i, 12345).str(style='brackets')
            ...       print RIF(-10^i, 12345)._str_question_style(10, 0, 'e', False)
            ...       print RIF(-10^i, 12345)._str_question_style(10, 3, 'e', False)
            [-10.000000000000000 .. 12345.000000000000]
            0.?e5
            6.17?618e3
            [-100.00000000000000 .. 12345.000000000000]
            0.?e5
            6.13?623e3
            [-1000.0000000000000 .. 12345.000000000000]
            0.?e5
            5.68?668e3
            [-10000.000000000000 .. 12345.000000000000]
            0.?e5
            1.2?112e3
            [-100000.00000000000 .. 12345.000000000000]
            0.?e5
            -4.38?562e4
            [-1.0000000000000000e6 .. 12345.000000000000]
            0.?e6
            -4.94?507e5
            [-1.0000000000000000e7 .. 12345.000000000000]
            0.?e7
            -4.99?501e6
            [-1.0000000000000000e8 .. 12345.000000000000]
            0.?e8
            -5.00?501e7
            sage: RIF(10^-3, 12345)._str_question_style(10, 3, 'e', False)
            '6.18?618e3'
            sage: RIF(-golden_ratio, -10^-6)._str_question_style(10, 3, 'e', False)
            '-0.810?810'
            sage: RIF(-0.85, 0.85)._str_question_style(10, 0, 'e', False)
            '0.?'
            sage: RIF(-0.85, 0.85)._str_question_style(10, 1, 'e', False)
            '0.0?9'
            sage: RIF(-0.85, 0.85)._str_question_style(10, 2, 'e', False)
            '0.00?85'
            sage: RIF(-8.5, 8.5)._str_question_style(10, 0, 'e', False)
            '0.?e1'
            sage: RIF(-85, 85)._str_question_style(10, 0, 'e', False)
            '0.?e2'
            sage: for i in range(-6, 7):
            ...       v = RIF(2).sqrt() * 10^i
            ...       print v._str_question_style(10, 0, 'e', False)
            1.414213562373095?e-6
            0.00001414213562373095?
            0.0001414213562373095?
            0.001414213562373095?
            0.01414213562373095?
            0.1414213562373095?
            1.414213562373095?
            14.14213562373095?
            141.4213562373095?
            1414.213562373095?
            14142.13562373095?
            141421.3562373095?
            1.414213562373095?e6
            sage: RIF(3^33)
            5559060566555523
            sage: RIF(3^33 * 2)
            1.1118121133111046?e16
            sage: RIF(-pi^-512, 0)
            -1.?e-254
            sage: RealIntervalField(2)(3 * 2^18)
            786432
            sage: RealIntervalField(2)(3 * 2^19)
            1.6?e6
            sage: v = RIF(AA(2-sqrt(3)))
            sage: v
            0.2679491924311227?
            sage: v.str(error_digits=1)
            '0.26794919243112273?4'
            sage: v.str(style='brackets')
            '[0.26794919243112269 .. 0.26794919243112276]'
            sage: -v
            -0.2679491924311227?
        """
        if not(mpfr_number_p(&self.value.left) and mpfr_number_p(&self.value.right)):
            raise ValueError, "_str_question_style on NaN or infinity"
        if base < 2 or base > 36:
            raise ValueError, "the base (=%s) must be between 2 and 36"%base
        if error_digits < 0 or error_digits > 1000:
            # The restriction to 1000 is not essential.  The reason to have
            # a restriction is that this code is not efficient for
            # large error_digits values (for instance, we always construct
            # a number with that many digits); a very large error_digits
            # could run out of memory, etc.
            # I think that 1000 is a pretty "safe" limit.  The whole
            # purpose of question_style is to be human-readable, and
            # the human-readability will go way down after about 6
            # error digits; 1000 error digits is just silly.
            raise ValueError, "error_digits (=%s) must be between 0 and 1000"%error_digits

        cdef mp_exp_t self_exp
        cdef mpz_t self_zz
        cdef int prec = (<RealIntervalField_class>self._parent).__prec
        cdef char *zz_str
        cdef size_t zz_str_maxlen

        if mpfr_equal_p(&self.value.left, &self.value.right) \
                and mpfr_integer_p(&self.value.left):
            # This might be suitable for integer printing, but not if it's
            # too big.  (We can represent 2^3000000 exactly in RIF, but we
            # don't want to print this 903090 digit number; we'd rather
            # just print 9.7049196389007116?e903089 .)

            # Represent self as m*2^k, where m is an integer with
            # self.prec() bits and k is an integer.  (So RIF(1) would have
            # m = 2^52 and k=-52.)  Then, as a simple heuristic, we print
            # as an integer if k<=0.  (As a special dispensation for tiny
            # precisions, we also print as an integer if the number is
            # less than a million (actually, less than 2^20); this
            # will never affect "normal" uses, but it makes tiny examples
            # with RealIntervalField(2) prettier.)

            self_exp = mpfr_get_exp(&self.value.left)
            if mpfr_zero_p(&self.value.left) or self_exp <= prec or self_exp <= 20:
                mpz_init(self_zz)
                mpfr_get_z(self_zz, &self.value.left, GMP_RNDN)
                zz_str_maxlen = mpz_sizeinbase(self_zz, base) + 2
                zz_str = <char *>PyMem_Malloc(zz_str_maxlen)
                if zz_str == NULL:
                    mpz_clear(self_zz)
                    raise MemoryError, "Unable to allocate memory for integer representation of interval"
                sig_on()
                mpz_get_str(zz_str, base, self_zz)
                sig_off()
                v = PyString_FromString(zz_str)
                PyMem_Free(zz_str)
                return v

        # We want the endpoints represented as an integer mantissa
        # and an exponent, using the given base.  MPFR will do that for
        # us in mpfr_get_str, so we end up converting from MPFR to strings
        # to MPZ to strings... ouch.  We could avoid this overhead by
        # copying most of the guts of mpfr_get_str to give something like
        # mpfr_get_mpz_exp (to give the mantissa as an mpz and the exponent);
        # we could also write the body of this method using the string
        # values, so that the second and third conversions are always
        # on small values (of around the size of error_digits).
        # We don't do any of that.

        cdef char *lower_s
        cdef char *upper_s
        cdef mp_exp_t lower_expo
        cdef mp_exp_t upper_expo
        cdef mpz_t lower_mpz
        cdef mpz_t upper_mpz

        sig_on()
        lower_s = mpfr_get_str(<char*>0, &lower_expo, base, 0,
                                &self.value.left, GMP_RNDD)
        upper_s = mpfr_get_str(<char*>0, &upper_expo, base, 0,
                                &self.value.right, GMP_RNDU)
        sig_off()

        if lower_s == <char*> 0:
            raise RuntimeError, "Unable to convert interval lower bound to a string"
        if upper_s == <char*> 0:
            raise RuntimeError, "Unable to convert interval upper bound to a string"

        # MPFR returns an exponent assuming that the implicit radix point
        # is to the left of the first mantissa digit.  We'll be doing
        # arithmetic on mantissas that might not preserve the number of
        # digits; we adjust the exponent so that the radix point is to
        # the right of the last mantissa digit (that is, so the number
        # is mantissa*base^exponent, if you interpret mantissa as an integer).

        cdef int digits
        digits = strlen(lower_s)
        if lower_s[0] == '-':
            digits -= 1
        lower_expo -= digits

        digits = strlen(upper_s)
        if upper_s[0] == '-':
            digits -= 1
        upper_expo -= digits

        sig_on()
        mpz_init_set_str(lower_mpz, lower_s, base)
        mpz_init_set_str(upper_mpz, upper_s, base)
        mpfr_free_str(lower_s)
        mpfr_free_str(upper_s)
        sig_off()

        cdef mpz_t tmp
        mpz_init(tmp)

        # At several places in the function, we divide by a power of
        # base.  This could be sped up by shifting instead, when base
        # is a power of 2.  (I'm not bothering right now because I
        # expect the not-base-10 case to be quite rare, especially
        # when combined with high precision and question style.)

        # First we normalize so that both mantissas are at the same
        # precision.  This just involves dividing the more-precise
        # endpoint by the appropriate power of base.  However, there's
        # one potentially very slow case we want to avoid: if the two
        # exponents are sufficiently different, the simple code would
        # involve computing a huge power of base, and then dividing
        # by it to get -1, 0, or 1 (depending on the rounding).

        # There's one complication first: if one of the endpoints is zero,
        # we want to treat it as infinitely precise (otherwise, it defaults
        # to a precision of 2^-self.prec(), so that RIF(0, 2^-1000)
        # would print as 1.?e-17).  (If both endpoints are zero, then
        # we can't get here; we already returned '0' in the integer
        # case above.)

        if mpfr_zero_p(&self.value.left):
            lower_expo = upper_expo
        if mpfr_zero_p(&self.value.right):
            upper_expo = lower_expo

        cdef int expo_delta

        if lower_expo < upper_expo:
            expo_delta = upper_expo - lower_expo
            if mpz_sizeinbase(lower_mpz, base) < expo_delta:
                # abs(lower) < base^expo_delta, so
                # floor(lower/base^expo_delta) is either -1 or 0
                # (depending on the sign of lower).
                if mpz_sgn(lower_mpz) < 0:
                    mpz_set_si(lower_mpz, -1)
                else:
                    mpz_set_ui(lower_mpz, 0)
            else:
                mpz_ui_pow_ui(tmp, base, expo_delta)
                mpz_fdiv_q(lower_mpz, lower_mpz, tmp)
            lower_expo = upper_expo
        elif upper_expo < lower_expo:
            expo_delta = lower_expo - upper_expo
            if mpz_sizeinbase(upper_mpz, base) < expo_delta:
                # abs(upper) < base^expo_delta, so
                # ceiling(upper/base^expo_delta) is either 0 or 1
                # (depending on the sign of upper).
                if mpz_sgn(upper_mpz) > 0:
                    mpz_set_ui(upper_mpz, 1)
                else:
                    mpz_set_ui(upper_mpz, 0)
            else:
                mpz_ui_pow_ui(tmp, base, expo_delta)
                mpz_cdiv_q(upper_mpz, upper_mpz, tmp)
            upper_expo = lower_expo

        cdef int expo = lower_expo

        # Now the basic plan is to repeat
        # lower = floor(lower/base); upper = ceiling(upper/base)
        # until the error upper-lower is sufficiently small.  However,
        # if this loop executes many times, that's pretty inefficient
        # (quadratic).  We do a single pre-check to see approximately
        # how many times we would have to go through that loop,
        # and do most of them with a single division.

        cdef mpz_t cur_error
        mpz_init(cur_error)

        mpz_sub(cur_error, upper_mpz, lower_mpz)

        cdef mpz_t max_error
        mpz_init(max_error)
        if error_digits == 0:
            mpz_set_ui(max_error, 2)
        else:
            mpz_ui_pow_ui(max_error, 10, error_digits)
            mpz_sub_ui(max_error, max_error, 1)
            mpz_mul_2exp(max_error, max_error, 1)

        # Now we want to compute k as large as possible such that
        # ceiling(upper/base^(k-1)) - floor(lower/base^(k-1)) > max_error.
        # We start by noting that
        # ceiling(upper/base^(k-1)) - floor(lower/base^(k-1)) >=
        #    cur_error/base^(k-1),
        # so it suffices if
        # cur_error/base^(k-1) > max_error, or
        # cur_error/max_error > base^(k-1).

        # We would like to take logarithms and subtract, but taking
        # logarithms is expensive.  Instead we use mpz_sizeinbase
        # as an approximate logarithm.  (This could probably be
        # improved, either by assuming undocumented knowledge of
        # the internals of mpz_sizeinbase, or by writing our own
        # approximate logarithm.)

        cdef int cur_error_digits = mpz_sizeinbase(cur_error, base)
        cdef int max_error_digits = mpz_sizeinbase(max_error, base)

        # The GMP documentation claims that mpz_sizeinbase will be either
        # the true number of digits, or one too high.  So
        # cur_error might have as few as cur_error_digits-1 digits,
        # so it might be as small as base^(cur_error_digits-2).
        # max_error might have as many as max_error_digits digits, so it
        # might be almost (but not quite) as large as base^max_error_digits.
        # Then their quotient will be at least slightly larger than
        # base^(cur_error_digits-2-max_error_digits).  So we can take
        # k-1 = cur_error_digits-2-max_error_digits, and
        # k = cur_error_digits-1-max_error_digits.

        cdef int k = cur_error_digits - 1 - max_error_digits

        if k > 0:
            mpz_ui_pow_ui(tmp, base, k)
            mpz_fdiv_q(lower_mpz, lower_mpz, tmp)
            mpz_cdiv_q(upper_mpz, upper_mpz, tmp)
            expo += k
            mpz_sub(cur_error, upper_mpz, lower_mpz)

        # OK, we've almost divided enough times to fit within max_error.
        # (In fact, maybe we already have.)  Now we just loop a few more
        # times until we're done.

        while mpz_cmp(cur_error, max_error) > 0:
            mpz_fdiv_q_ui(lower_mpz, lower_mpz, base)
            mpz_cdiv_q_ui(upper_mpz, upper_mpz, base)
            expo += 1
            mpz_sub(cur_error, upper_mpz, lower_mpz)

        # Almost done.  Now we need to print out a floating-point number
        # with a mantissa halfway between lower_mpz and upper_mpz,
        # an error of half of cur_error (rounded up), and an exponent
        # based on expo (shifted by the location of the decimal point
        # within the mantissa).

        # We briefly re-purpose lower_mpz to hold the final mantissa:
        mpz_add(lower_mpz, lower_mpz, upper_mpz)
        # According to our spec, we're supposed to divide lower_mpz
        # by 2, rounding away from 0.
        if mpz_sgn(lower_mpz) >= 0:
            mpz_cdiv_q_2exp(lower_mpz, lower_mpz, 1)
        else:
            mpz_fdiv_q_2exp(lower_mpz, lower_mpz, 1)

        # and cur_error to hold the error:
        mpz_cdiv_q_2exp(cur_error, cur_error, 1)

        cdef char *tmp_cstr

        tmp_cstr = <char *>PyMem_Malloc(mpz_sizeinbase(lower_mpz, base) + 2)
        if tmp_cstr == NULL:
            raise MemoryError, "Unable to allocate memory for the mantissa of an interval"
        mpz_get_str(tmp_cstr, base, lower_mpz)
        digits = strlen(tmp_cstr)
        if tmp_cstr[0] == '-':
            digits -= 1
            mant_string = <object> PyString_FromString(tmp_cstr+1)
            sign_string = '-'
        else:
            mant_string = <object> PyString_FromString(tmp_cstr)
            sign_string = ''
        PyMem_Free(tmp_cstr)

        if error_digits == 0:
            error_string = ''
        else:
            tmp_cstr = <char *>PyMem_Malloc(mpz_sizeinbase(cur_error, 10) + 2)
            if tmp_cstr == NULL:
                raise MemoryError, "Unable to allocate memory for the error of an interval"
            mpz_get_str(tmp_cstr, 10, cur_error)
            error_string = <object> PyString_FromString(tmp_cstr)
            PyMem_Free(tmp_cstr)

        mpz_clear(lower_mpz)
        mpz_clear(upper_mpz)
        mpz_clear(tmp)
        mpz_clear(cur_error)
        mpz_clear(max_error)

        cdef bint scientific = prefer_sci

        # If the exponent is >0, we must use scientific notation.  For
        # instance, RIF(10, 30) gives 2.?e1; we couldn't write that
        # number in the question syntax (with no error digits) without
        # scientific notation.
        if expo > 0:
            scientific = True

        # If we use scientific notation, we put the radix point to the
        # right of the first digit; that would give us an exponent of:
        cdef int sci_expo = expo + digits - 1
        if abs(sci_expo) >= 6:
            scientific = True

        if scientific:
            return '%s%s.%s?%s%s%s'%(sign_string,
                                     mant_string[0], mant_string[1:],
                                     error_string, e, sci_expo)

        if expo + digits <= 0:
            return '%s0.%s%s?%s'%(sign_string,
                                  '0' * -(expo + digits), mant_string,
                                  error_string)

        return '%s%s.%s?%s'%(sign_string,
                             mant_string[:expo+digits],
                             mant_string[expo+digits:],
                             error_string)

    def __copy__(self):
        """
        Return copy of self - since self is immutable, we just return self
        again.

        EXAMPLES::

            sage: a = RIF(3.5)
            sage: copy(a) is  a
            True
        """
        return self

    # Interval-specific functions
    def lower(self, rnd=None):
        """
        Returns the lower bound of this interval

        rnd - (string) the rounding mode

        - RNDN - round to nearest
        - RNDD - (default) round towards minus infinity
        - RNDZ - round towards zero
        - RNDU - round towards plus infinity

        The rounding mode does not affect the value returned as a
        floating-point number, but it does control which variety of
        RealField the returned number is in, which affects printing and
        subsequent operations.

        EXAMPLES::

            sage: R = RealIntervalField(13)
            sage: R.pi().lower().str(truncate=False)
            '3.1411'

        ::

            sage: x = R(1.2,1.3); x.str(style='brackets')
            '[1.1999 .. 1.3001]'
            sage: x.lower()
            1.19
            sage: x.lower('RNDU')
            1.20
            sage: x.lower('RNDN')
            1.20
            sage: x.lower('RNDZ')
            1.19
            sage: x.lower().parent()
            Real Field with 13 bits of precision and rounding RNDD
            sage: x.lower('RNDU').parent()
            Real Field with 13 bits of precision and rounding RNDU
            sage: x.lower() == x.lower('RNDU')
            True
        """
        cdef RealNumber x
        if rnd is None:
            x = (<RealIntervalField_class>self._parent).__lower_field._new()
        else:
            x = (<RealField_class>(self._parent._real_field(rnd)))._new()
        mpfi_get_left(x.value, self.value)
        return x

    def upper(self, rnd =None):
        """
        Returns the upper bound of this interval

        - RNDN - round to nearest
        - RNDD - round towards minus infinity
        - RNDZ - round towards zero
        - RNDU - (default) round towards plus infinity

        The rounding mode does not affect the value returned as a
        floating-point number, but it does control which variety of
        RealField the returned number is in, which affects printing and
        subsequent operations.

        EXAMPLES::

            sage: R = RealIntervalField(13)
            sage: R.pi().upper().str(truncate=False)
            '3.1417'

        ::

            sage: R = RealIntervalField(13)
            sage: x = R(1.2,1.3); x.str(style='brackets')
            '[1.1999 .. 1.3001]'
            sage: x.upper()
            1.31
            sage: x.upper('RNDU')
            1.31
            sage: x.upper('RNDN')
            1.30
            sage: x.upper('RNDD')
            1.30
            sage: x.upper('RNDZ')
            1.30
            sage: x.upper().parent()
            Real Field with 13 bits of precision and rounding RNDU
            sage: x.upper('RNDD').parent()
            Real Field with 13 bits of precision and rounding RNDD
            sage: x.upper() == x.upper('RNDD')
            True
        """
        cdef RealNumber x
        if rnd is None:
            x = (<RealIntervalField_class>self._parent).__upper_field._new()
        else:
            x = ((<RealField_class>self._parent._real_field(rnd)))._new()
        mpfi_get_right(x.value, self.value)
        return x

    def endpoints(self, rnd=None):
        """
        Returns the lower and upper endpoints of self.

        EXAMPLES::

            sage: RIF(1,2).endpoints()
            (1.00000000000000, 2.00000000000000)
            sage: RIF(pi).endpoints()
            (3.14159265358979, 3.14159265358980)
            sage: a = CIF(RIF(1,2), RIF(3,4))
            sage: a.real().endpoints()
            (1.00000000000000, 2.00000000000000)

        As with ``lower()`` and ``upper()``, a rounding mode is accepted::

            sage: RIF(1,2).endpoints('RNDD')[0].parent()
            Real Field with 53 bits of precision and rounding RNDD
        """
        return self.lower(rnd), self.upper(rnd)

    def absolute_diameter(self):
        """
        The diameter of this interval (for [a .. b], this is b-a), rounded
        upward, as a RealNumber.

        EXAMPLES::

            sage: RIF(1, pi).absolute_diameter()
            2.14159265358979
        """
        cdef RealNumber x
        x = (<RealIntervalField_class>self._parent).__middle_field._new()
        mpfi_diam_abs(x.value, self.value)
        return x

    def relative_diameter(self):
        """
        The relative diameter of this interval (for [a .. b], this is
        (b-a)/((a+b)/2)), rounded upward, as a RealNumber.

        EXAMPLES::

            sage: RIF(1, pi).relative_diameter()
            1.03418797197910
        """
        cdef RealNumber x
        x = (<RealIntervalField_class>self._parent).__middle_field._new()
        mpfi_diam_rel(x.value, self.value)
        return x

    def diameter(self):
        """
        If (0 in self), returns self.absolute_diameter(), otherwise
        self.relative_diameter().

        EXAMPLES::

            sage: RIF(1, 2).diameter()
            0.666666666666667
            sage: RIF(1, 2).absolute_diameter()
            1.00000000000000
            sage: RIF(1, 2).relative_diameter()
            0.666666666666667
            sage: RIF(pi).diameter()
            1.41357985842823e-16
            sage: RIF(pi).absolute_diameter()
            4.44089209850063e-16
            sage: RIF(pi).relative_diameter()
            1.41357985842823e-16
            sage: (RIF(pi) - RIF(3, 22/7)).diameter()
            0.142857142857144
            sage: (RIF(pi) - RIF(3, 22/7)).absolute_diameter()
            0.142857142857144
            sage: (RIF(pi) - RIF(3, 22/7)).relative_diameter()
            2.03604377705518
        """
        cdef RealNumber x
        x = (<RealIntervalField_class>self._parent).__middle_field._new()
        mpfi_diam(x.value, self.value)
        return x

    def fp_rank_diameter(self):
        r"""
        Computes the diameter of this interval in terms of the
        "floating-point rank". That is, it gives the number of
        floating-point numbers (of the current precision) contained in the
        given interval, minus one. An ``fp_rank_diameter`` of
        0 means that the interval is exact; an
        ``fp_rank_diameter`` of 1 means that the interval is
        as tight as possible, unless the number you're trying to represent
        is actually exactly representable as a floating-point number.

        EXAMPLES::

            sage: RIF(pi).fp_rank_diameter()
            1
            sage: RIF(12345).fp_rank_diameter()
            0
            sage: RIF(-sqrt(2)).fp_rank_diameter()
            1
            sage: RIF(5/8).fp_rank_diameter()
            0
            sage: RIF(5/7).fp_rank_diameter()
            1
            sage: a = RIF(pi)^12345; a
            2.06622879260?e6137
            sage: a.fp_rank_diameter()
            30524
            sage: (RIF(sqrt(2)) - RIF(sqrt(2))).fp_rank_diameter()
            9671406088542672151117826            # 32-bit
            41538374868278620559869609387229186  # 64-bit

        Just because we have the best possible interval, doesn't mean the
        interval is actually small::

            sage: a = RIF(pi)^12345678901234567890; a
            [2.0985787164673874e323228496 .. +infinity]            # 32-bit
            [5.8756537891115869e1388255822130839282 .. +infinity]  # 64-bit
            sage: a.fp_rank_diameter()
            1
        """
        return self.lower().fp_rank_delta(self.upper())

    def is_exact(self):
        return mpfr_equal_p(&self.value.left, &self.value.right)

    def magnitude(self):
        """
        The largest absolute value of the elements of the interval.

        EXAMPLES::

            sage: RIF(-2, 1).magnitude()
            2.00000000000000
            sage: RIF(-1, 2).magnitude()
            2.00000000000000
        """
        cdef RealNumber x
        x = (<RealIntervalField_class>self._parent).__middle_field._new()
        mpfi_mag(x.value, self.value)
        return x

    def mignitude(self):
        """
        The smallest absolute value of the elements of the interval.

        EXAMPLES::

            sage: RIF(-2, 1).mignitude()
            0.000000000000000
            sage: RIF(-2, -1).mignitude()
            1.00000000000000
            sage: RIF(3, 4).mignitude()
            3.00000000000000
        """
        cdef RealNumber x
        x = (<RealIntervalField_class>self._parent).__middle_field._new()
        mpfi_mig(x.value, self.value)
        return x

    def center(self):
        """
        RIF(a, b).center() == (a+b)/2

        EXAMPLES::

            sage: RIF(1, 2).center()
            1.50000000000000
        """
        cdef RealNumber x
        x = (<RealIntervalField_class>self._parent).__middle_field._new()
        mpfi_mid(x.value, self.value)
        return x

    def bisection(self):
        """
        Returns the bisection of self into two intervals of half the size
        whose union is ``self`` and intersection is ``self.center()``.

        EXAMPLES::

            sage: a, b = RIF(1,2).bisection()
            sage: a.lower(), a.upper()
            (1.00000000000000, 1.50000000000000)
            sage: b.lower(), b.upper()
            (1.50000000000000, 2.00000000000000)

            sage: I = RIF(e, pi)
            sage: a, b = I.bisection()
            sage: a.intersection(b) == I.center()
            True
            sage: a.union(b).endpoints() == I.endpoints()
            True
        """
        cdef RealIntervalFieldElement left = self._new()
        cdef RealIntervalFieldElement right = self._new()
        mpfr_set(&left.value.left, &self.value.left, GMP_RNDN)
        mpfi_mid(&left.value.right, self.value)
        mpfi_interv_fr(right.value, &left.value.right, &self.value.right)
        return left, right

    def alea(self):
        """
        RIF(a, b).alea() gives a floating-point number picked at random
        from the interval.

        EXAMPLES::

            sage: RIF(1, 2).alea() # random
            1.34696133696137
        """
        cdef RealNumber x
        x = (<RealIntervalField_class>self._parent).__middle_field._new()
        mpfi_alea(x.value, self.value)
        return x

#     def integer_part(self):
#         """
#         If in decimal this number is written n.defg, returns n.

#         OUTPUT:
#             -- a Sage Integer

#         EXAMPLE:
#             sage: a = 119.41212
#             sage: a.integer_part()
#             119
#         """
#         s = self.str(base=32, no_sci=True)
#         i = s.find(".")
#         return Integer(s[:i], base=32)

    ########################
    #   Basic Arithmetic
    ########################

    cpdef ModuleElement _add_(self, ModuleElement other):
        """
        Add two real intervals with the same parent.

        EXAMPLES::

            sage: R = RealIntervalField()
            sage: R(-1.5) + R(2.5)
            1
            sage: R('-1.3') + R('2.3')
            1.000000000000000?
            sage: (R(1, 2) + R(3, 4)).str(style='brackets')
            '[4.0000000000000000 .. 6.0000000000000000]'
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        mpfi_add(x.value, self.value, (<RealIntervalFieldElement>other).value)
        return x

    def __invert__(self):
        """
        Return the multiplicative "inverse" of this interval. (Technically,
        non-precise intervals don't have multiplicative inverses.)

        EXAMPLES::

            sage: v = RIF(2); v
            2
            sage: ~v
            0.50000000000000000?
            sage: v * ~v
            1
            sage: v = RIF(1.5, 2.5); v.str(style='brackets')
            '[1.5000000000000000 .. 2.5000000000000000]'
            sage: (~v).str(style='brackets')
            '[0.39999999999999996 .. 0.66666666666666675]'
            sage: (v * ~v).str(style='brackets')
            '[0.59999999999999986 .. 1.6666666666666670]'
            sage: ~RIF(-1, 1)
            [-infinity .. +infinity]
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        mpfi_inv(x.value, self.value)
        return x

    cpdef ModuleElement _sub_(self, ModuleElement right):
        """
        Subtract two real intervals with the same parent.

        EXAMPLES::

            sage: R = RealIntervalField()
            sage: R(-1.5) - R(2.5)
            -4
            sage: R('-1.3') - R('2.7')
            -4.000000000000000?
            sage: (R(1, 2) - R(3, 4)).str(style='brackets')
            '[-3.0000000000000000 .. -1.0000000000000000]'
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        mpfi_sub(x.value, self.value, (<RealIntervalFieldElement>right).value)
        return x

    cpdef RingElement _mul_(self, RingElement right):
        """
        Multiply two real intervals with the same parent.

        EXAMPLES::

            sage: R = RealIntervalField()
            sage: R(-1.5) * R(2.5)
            -3.7500000000000000?
            sage: R('-1.3') * R('2.3')
            -2.990000000000000?
            sage: (R(1, 2) * R(3, 4)).str(style='brackets')
            '[3.0000000000000000 .. 8.0000000000000000]'

        If two elements have different precision, arithmetic operations are
        performed after coercing to the lower precision.

        ::

            sage: R20 = RealIntervalField(20)
            sage: R100 = RealIntervalField(100)
            sage: a = R20('393.3902834028345')
            sage: b = R100('393.3902834028345')
            sage: a
            393.391?
            sage: b
            393.390283402834500000000000000?
            sage: a*b
            154756.?
            sage: b*a
            154756.?
            sage: parent(b*a)
            Real Interval Field with 20 bits of precision
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        mpfi_mul(x.value, self.value, (<RealIntervalFieldElement>right).value)
        return x

    cpdef RingElement _div_(self, RingElement right):
        """
        Divide self by other, where both are real intervals with the same
        parent.

        EXAMPLES::

            sage: R = RealIntervalField()
            sage: R(1)/R(3)
            0.3333333333333334?
            sage: R(1)/R(0) # since R(0) has no sign, gives the whole reals
            [-infinity .. +infinity]
            sage: R(1)/R(-1, 1)
            [-infinity .. +infinity]

        ::

            sage: R(-1.5) / R(2.5)
            -0.6000000000000000?
            sage: (R(1, 2) / R(3, 4)).str(style='brackets')
            '[0.25000000000000000 .. 0.66666666666666675]'
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        mpfi_div((<RealIntervalFieldElement>x).value, self.value,
                 (<RealIntervalFieldElement>right).value)
        return x

    cpdef ModuleElement _neg_(self):
        """
        Return the additive "inverse" of this interval. (Technically,
        non-precise intervals don't have additive inverses.)

        EXAMPLES::

            sage: v = RIF(2); v
            2
            sage: -v
            -2
            sage: v + -v
            0
            sage: v = RIF(1.5, 2.5); v.str(error_digits=3)
            '2.000?500'
            sage: (-v).str(style='brackets')
            '[-2.5000000000000000 .. -1.5000000000000000]'
            sage: (v + -v).str(style='brackets')
            '[-1.0000000000000000 .. 1.0000000000000000]'
        """

        cdef RealIntervalFieldElement x
        x = self._new()
        mpfi_neg(x.value, self.value)
        return x

    def __abs__(self):
        return self.abs()

    cdef RealIntervalFieldElement abs(RealIntervalFieldElement self):
        cdef RealIntervalFieldElement x
        x = self._new()
        mpfi_abs(x.value, self.value)
        return x

    def square(self):
        """
        Return the square of the interval. Note that squaring an interval
        is different than multiplying it by itself, because the square can
        never be negative.

        EXAMPLES::

            sage: RIF(1, 2).square().str(style='brackets')
            '[1.0000000000000000 .. 4.0000000000000000]'
            sage: RIF(-1, 1).square().str(style='brackets')
            '[0.00000000000000000 .. 1.0000000000000000]'
            sage: (RIF(-1, 1) * RIF(-1, 1)).str(style='brackets')
            '[-1.0000000000000000 .. 1.0000000000000000]'
        """

        cdef RealIntervalFieldElement x
        x = self._new()
        mpfi_sqr(x.value, self.value)
        return x

    # Bit shifting
    def _lshift_(RealIntervalFieldElement self, n):
        cdef RealIntervalFieldElement x
        if n > sys.maxint:
            raise OverflowError, "n (=%s) must be <= %s"%(n, sys.maxint)
        x = self._new()
        mpfi_mul_2exp(x.value, self.value, n)
        return x

    def __lshift__(x, y):
        """
        Returns `x * 2^y`, for `y` an integer. Much faster
        than an ordinary multiplication.

        EXAMPLES::

            sage: RIF(1.0) << 32
            4294967296
        """
        if isinstance(x, RealIntervalFieldElement) and isinstance(y, (int,long, Integer)):
            return x._lshift_(y)
        return sage.structure.element.bin_op(x, y, operator.lshift)

    def _rshift_(RealIntervalFieldElement self, n):
        if n > sys.maxint:
            raise OverflowError, "n (=%s) must be <= %s"%(n, sys.maxint)
        cdef RealIntervalFieldElement x
        x = self._new()
        mpfi_div_2exp(x.value, self.value, n)
        return x

    def __rshift__(x, y):
        """
        Returns `x / 2^y`, for `y` an integer. Much faster
        than an ordinary division.

        EXAMPLES::

            sage: RIF(1024.0) >> 14
            0.062500000000000000?
        """
        if isinstance(x, RealIntervalFieldElement) and \
               isinstance(y, (int,long,Integer)):
            return x._rshift_(y)
        return sage.structure.element.bin_op(x, y, operator.rshift)

    def multiplicative_order(self):
        if self == 1:
            return 1
        elif self == -1:
            return -1
        return sage.rings.infinity.infinity

#     def sign(self):
#         return mpfr_sgn(self.value)

    def prec(self):
        return (<RealIntervalField_class>self._parent).__prec

    ###################
    # Rounding etc
    ###################

    # Not implemented on intervals (for good reason!)
#     def round(self):
#         """
#         Rounds self to the nearest real number. There are 4
#         rounding modes. They are

#         EXAMPLES:
#             RNDN -- round to nearest:

#             sage: R = RealIntervalField(20,False,'RNDN')
#             sage: R(22.454)
#             22.454
#             sage: R(22.491)
#             22.490

#             RNDZ -- round towards zero:
#             sage: R = RealIntervalField(20,False,'RNDZ')
#             sage: R(22.454)
#             22.453
#             sage: R(22.491)
#             22.490

#             RNDU -- round towards plus infinity:
#             sage: R = RealIntervalField(20,False,'RNDU')
#             sage: R(22.454)
#             22.454
#             sage: R(22.491)
#             22.491

#             RNDU -- round towards minus infinity:
#             sage: R = RealIntervalField(20,False,'RNDD')
#             sage: R(22.454)
#             22.453
#             sage: R(22.491)
#             22.490
#         """
#         cdef RealIntervalFieldElement x
#         x = self._new()
#         mpfr_round(x.value, self.value)
#         return x

    def floor(self):
        """
        Returns the floor of this number

        EXAMPLES::

            sage: R = RealIntervalField()
            sage: (2.99).floor()
            2
            sage: (2.00).floor()
            2
            sage: floor(RR(-5/2))
            -3
            sage: R = RealIntervalField(100)
            sage: a = R(9.5, 11.3); a.str(style='brackets')
            '[9.5000000000000000000000000000000 .. 11.300000000000000710542735760101]'
            sage: floor(a).str(style='brackets')
            '[9.0000000000000000000000000000000 .. 11.000000000000000000000000000000]'
            sage: a.floor()
            10.?
            sage: ceil(a)
            11.?
            sage: a.ceil().str(style='brackets')
            '[10.000000000000000000000000000000 .. 12.000000000000000000000000000000]'
        """
        return self.parent()(self.lower().floor(), self.upper().floor())

    def ceil(self):
        """
        Returns the ceiling of this number

        OUTPUT: integer

        EXAMPLES::

            sage: (2.99).ceil()
            3
            sage: (2.00).ceil()
            2
            sage: (2.01).ceil()
            3
            sage: R = RealIntervalField(30)
            sage: a = R(-9.5, -11.3); a.str(style='brackets')
            '[-11.300000012 .. -9.5000000000]'
            sage: a.floor().str(style='brackets')
            '[-12.000000000 .. -10.000000000]'
            sage: a.ceil()
            -10.?
            sage: ceil(a).str(style='brackets')
            '[-11.000000000 .. -9.0000000000]'
        """
        return self.parent()(self.lower().ceil(), self.upper().ceil())

    def ceiling(self):
         return self.ceil()

#     def trunc(self):
#         """
#         Truncates this number

#         EXAMPLES:
#             sage: (2.99).trunc()
#             2.00000000000000
#             sage: (-0.00).trunc()
#             -0.000000000000000
#             sage: (0.00).trunc()
#             0.000000000000000
#         """
#         cdef RealIntervalFieldElement x
#         x = self._new()
#         mpfr_trunc(x.value, self.value)
#         return x

#     def frac(self):
#         """
#         frac returns a real number > -1 and < 1. it satisfies the
#         relation:
#             x = x.trunc() + x.frac()

#         EXAMPLES:
#             sage: (2.99).frac()
#             0.990000000000000
#             sage: (2.50).frac()
#             0.500000000000000
#             sage: (-2.79).frac()
#             -0.790000000000000
#         """
#         cdef RealIntervalFieldElement x
#         x = self._new()
#         mpfr_frac(x.value, self.value, (<RealIntervalField>self._parent).rnd)
#         return x

    ###########################################
    # Conversions
    ###########################################

#     def __float__(self):
#         return mpfr_get_d(self.value, (<RealIntervalField>self._parent).rnd)

#     def __int__(self):
#         """
#         Returns integer truncation of this real number.
#         """
#         s = self.str(32)
#         i = s.find('.')
#         return int(s[:i], 32)

#     def __long__(self):
#         """
#         Returns long integer truncation of this real number.
#         """
#         s = self.str(32)
#         i = s.find('.')
#         return long(s[:i], 32)

#     def __complex__(self):
#         return complex(float(self))

#     def _complex_number_(self):
#         return sage.rings.complex_field.ComplexField(self.prec())(self)

#     def _pari_(self):
#         return sage.libs.pari.all.pari.new_with_bits_prec(str(self), (<RealIntervalField>self._parent).__prec)

    def unique_floor(self):
        """
        Returns the unique floor of this interval, if it is well defined,
        otherwise raises a ValueError.

        EXAMPLES::

            sage: RIF(pi).unique_floor()
            3
            sage: RIF(100*pi).unique_floor()
            314
            sage: RIF(100, 200).unique_floor()
            Traceback (most recent call last):
            ...
            ValueError: interval does not have a unique floor
        """
        a, b = self.lower().floor(), self.upper().floor()
        if a == b:
            return a
        else:
            raise ValueError, "interval does not have a unique floor"

    def unique_integer(self):
        """
        Returns the unique integer in this interval, if there is exactly one,
        otherwise raises a ValueError.

        EXAMPLES::

            sage: RIF(pi).unique_integer()
            Traceback (most recent call last):
            ...
            ValueError: interval contains no integer
            sage: RIF(pi, pi+1).unique_integer()
            4
            sage: RIF(pi, pi+2).unique_integer()
            Traceback (most recent call last):
            ...
            ValueError: interval contains more than one integer
            sage: RIF(100).unique_integer()
            100
        """
        a, b = self.lower().ceil(), self.upper().floor()
        if a == b:
            return a
        elif a < b:
            raise ValueError, "interval contains more than one integer"
        else:
            raise ValueError, "interval contains no integer"

    def simplest_rational(self, low_open=False, high_open=False):
        """
        Returns the simplest rational in this interval. Given rationals a/b
        and c/d (both in lowest terms), the former is simpler if b<d or if
        b==d and `|a|<|c|`.

        If optional parameters low_open or high_open are true, then treat
        this as an open interval on that end.

        EXAMPLES::

            sage: RealIntervalField(10)(pi).simplest_rational()
            22/7
            sage: RealIntervalField(20)(pi).simplest_rational()
            355/113
            sage: RIF(0.123, 0.567).simplest_rational()
            1/2
            sage: RIF(RR(1/3).nextabove(), RR(3/7)).simplest_rational()
            2/5
            sage: RIF(1234/567).simplest_rational()
            1234/567
            sage: RIF(-8765/432).simplest_rational()
            -8765/432
            sage: RIF(-1.234, 0.003).simplest_rational()
            0
            sage: RIF(RR(1/3)).simplest_rational()
            6004799503160661/18014398509481984
            sage: RIF(RR(1/3)).simplest_rational(high_open=True)
            Traceback (most recent call last):
            ...
            ValueError: simplest_rational() on open, empty interval
            sage: RIF(1/3, 1/2).simplest_rational()
            1/2
            sage: RIF(1/3, 1/2).simplest_rational(high_open=True)
            1/3
            sage: phi = ((RealIntervalField(500)(5).sqrt() + 1)/2)
            sage: phi.simplest_rational() == fibonacci(362)/fibonacci(361)
            True
        """
        if mpfr_equal_p(&self.value.left, &self.value.right):
            if low_open or high_open:
                raise ValueError, 'simplest_rational() on open, empty interval'
            return self.lower().exact_rational()

        if mpfi_has_zero(self.value):
            return Rational(0)

        if mpfi_is_neg(self.value):
            return -(self._neg_().simplest_rational(low_open=high_open, high_open=low_open))

        low = self.lower()
        high = self.upper()

        # First, we try using approximate arithmetic of slightly higher
        # precision.
        cdef RealIntervalFieldElement highprec
        highprec = RealIntervalField_class(int(self.prec() * 1.2))(self)

        cdef Rational try1 = highprec._simplest_rational_helper()

        # Note that to compute "try1 >= low", Sage converts try1 to a
        # floating-point number rounding down, and "try1 <= high"
        # rounds up (since "low" and "high" are in downward-rounding
        # and upward-rounding fields, respectively).
        if try1 >= low and try1 <= high:
            ok = True
            if low_open and (try1 == low.exact_rational()):
                ok = False
            if high_open and (try1 == high.exact_rational()):
                ok = False
            if ok:
                return try1

        # We could try again with higher precision; instead, we
        # go directly to using exact arithmetic.
        return _simplest_rational_exact(low.exact_rational(),
                                        high.exact_rational(),
                                        low_open,
                                        high_open)

    cdef Rational _simplest_rational_helper(self):
        """
        Returns the simplest rational in an interval which is either equal
        to or slightly larger than self. We assume that both endpoints of
        self are nonnegative.
        """

        low = self.lower()

        cdef RealIntervalFieldElement new_elt

        if low <= 1:
            if low == 0:
                return Rational(0)
            if self.upper() >= 1:
                return Rational(1)
            new_elt = ~self
            return ~(new_elt._simplest_rational_helper())

        fl = low.floor()
        new_elt = self - fl
        return fl + new_elt._simplest_rational_helper()

    ###########################################
    # Comparisons: ==, !=, <, <=, >, >=
    ###########################################

    def is_NaN(self):
        return mpfi_nan_p(self.value)

    def __richcmp__(left, right, int op):
        return (<Element>left)._richcmp(right, op)

    cdef _richcmp_c_impl(left, Element right, int op):
        """
        Implements comparisons between intervals. (See the file header
        comment for more information on interval comparison.)

        EXAMPLES::

            sage: 0 < RIF(1, 3)
            True
            sage: 1 < RIF(1, 3)
            False
            sage: 2 < RIF(1, 3)
            False
            sage: 4 < RIF(1, 3)
            False
            sage: RIF(0, 1/2) < RIF(1, 3)
            True
            sage: RIF(0, 1) < RIF(1, 3)
            False
            sage: RIF(0, 2) < RIF(1, 3)
            False
            sage: RIF(1, 2) < RIF(1, 3)
            False
            sage: RIF(1, 3) < 4
            True
            sage: RIF(1, 3) < 3
            False
            sage: RIF(1, 3) < 2
            False
            sage: RIF(1, 3) < 0
            False
            sage: 0 <= RIF(1, 3)
            True
            sage: 1 <= RIF(1, 3)
            True
            sage: 2 <= RIF(1, 3)
            False
            sage: 4 <= RIF(1, 3)
            False
            sage: RIF(0, 1/2) <= RIF(1, 3)
            True
            sage: RIF(0, 1) <= RIF(1, 3)
            True
            sage: RIF(0, 2) <= RIF(1, 3)
            False
            sage: RIF(1, 2) <= RIF(1, 3)
            False
            sage: RIF(1, 3) <= 4
            True
            sage: RIF(1, 3) <= 3
            True
            sage: RIF(1, 3) <= 2
            False
            sage: RIF(1, 3) <= 0
            False
            sage: RIF(1, 3) > 0
            True
            sage: RIF(1, 3) > 1
            False
            sage: RIF(1, 3) > 2
            False
            sage: RIF(1, 3) > 4
            False
            sage: RIF(1, 3) > RIF(0, 1/2)
            True
            sage: RIF(1, 3) > RIF(0, 1)
            False
            sage: RIF(1, 3) > RIF(0, 2)
            False
            sage: RIF(1, 3) > RIF(1, 2)
            False
            sage: 4 > RIF(1, 3)
            True
            sage: 3 > RIF(1, 3)
            False
            sage: 2 > RIF(1, 3)
            False
            sage: 0 > RIF(1, 3)
            False
            sage: RIF(1, 3) >= 0
            True
            sage: RIF(1, 3) >= 1
            True
            sage: RIF(1, 3) >= 2
            False
            sage: RIF(1, 3) >= 4
            False
            sage: RIF(1, 3) >= RIF(0, 1/2)
            True
            sage: RIF(1, 3) >= RIF(0, 1)
            True
            sage: RIF(1, 3) >= RIF(0, 2)
            False
            sage: RIF(1, 3) >= RIF(1, 2)
            False
            sage: 4 >= RIF(1, 3)
            True
            sage: 3 >= RIF(1, 3)
            True
            sage: 2 >= RIF(1, 3)
            False
            sage: 0 >= RIF(1, 3)
            False
            sage: 0 == RIF(0)
            True
            sage: 0 == RIF(1)
            False
            sage: 1 == RIF(0)
            False
            sage: 0 == RIF(0, 1)
            False
            sage: 1 == RIF(0, 1)
            False
            sage: RIF(0, 1) == RIF(0, 1)
            False
            sage: RIF(1) == 0
            False
            sage: RIF(1) == 1
            True
            sage: RIF(0) == RIF(0)
            True
            sage: RIF(pi) == RIF(pi)
            False
            sage: RIF(0, 1) == RIF(1, 2)
            False
            sage: RIF(1, 2) == RIF(0, 1)
            False
            sage: 0 != RIF(0)
            False
            sage: 0 != RIF(1)
            True
            sage: 1 != RIF(0)
            True
            sage: 0 != RIF(0, 1)
            False
            sage: 1 != RIF(0, 1)
            False
            sage: RIF(0, 1) != RIF(0, 1)
            False
            sage: RIF(1) != 0
            True
            sage: RIF(1) != 1
            False
            sage: RIF(0) != RIF(0)
            False
            sage: RIF(pi) != RIF(pi)
            False
            sage: RIF(0, 1) != RIF(1, 2)
            False
            sage: RIF(1, 2) != RIF(0, 1)
            False
        """
        cdef RealIntervalFieldElement lt, rt

        lt = left
        rt = right

        if op == 0: #<
            return mpfr_less_p(&lt.value.right, &rt.value.left)
        elif op == 2: #==
            # a == b iff a<=b and b <= a
            # (this gives a result with two comparisons, where the
            # obvious approach would use three)
            return mpfr_lessequal_p(&lt.value.right, &rt.value.left) \
                and mpfr_lessequal_p(&rt.value.right, &lt.value.left)
        elif op == 4: #>
            return mpfr_less_p(&rt.value.right, &lt.value.left)
        elif op == 1: #<=
            return mpfr_lessequal_p(&lt.value.right, &rt.value.left)
        elif op == 3: #!=
            return mpfr_less_p(&lt.value.right, &rt.value.left) \
                or mpfr_less_p(&rt.value.right, &lt.value.left)
        elif op == 5: #>=
            return mpfr_lessequal_p(&rt.value.right, &lt.value.left)

    def __nonzero__(self):
        """
        Returns true if self is not known to be exactly zero.

        EXAMPLES::

            sage: RIF(0).__nonzero__()
            False
            sage: RIF(1).__nonzero__()
            True
            sage: RIF(1, 2).__nonzero__()
            True
            sage: RIF(0, 1).__nonzero__()
            True
            sage: RIF(-1, 1).__nonzero__()
            True
        """
        return not (mpfr_zero_p(&self.value.left) and mpfr_zero_p(&self.value.right))

    def __cmp__(left, right):
        """
        Compare two intervals lexicographically. Returns 0 if they are the
        same interval, -1 if the second is larger, or 1 if the first is
        larger.

        EXAMPLES::

            sage: cmp(RIF(0), RIF(1))
            -1
            sage: cmp(RIF(0, 1), RIF(1))
            -1
            sage: cmp(RIF(0, 1), RIF(1, 2))
            -1
            sage: cmp(RIF(0, 0.99999), RIF(1, 2))
            -1
            sage: cmp(RIF(1, 2), RIF(0, 1))
            1
            sage: cmp(RIF(1, 2), RIF(0))
            1
            sage: cmp(RIF(0, 1), RIF(0, 2))
            -1
            sage: cmp(RIF(0, 1), RIF(0, 1))
            0
            sage: cmp(RIF(0, 1), RIF(0, 1/2))
            1
        """
        return (<Element>left)._cmp(right)

    cdef int _cmp_c_impl(left, Element right) except -2:
        """
        Implements the lexicographic total order on intervals.
        """
        cdef RealIntervalFieldElement lt, rt

        lt = left
        rt = right

        cdef int i
        i = mpfr_cmp(&lt.value.left, &rt.value.left)
        if i < 0:
            return -1
        elif i > 0:
            return 1
        i = mpfr_cmp(&lt.value.right, &rt.value.right)
        if i < 0:
            return -1
        elif i > 0:
            return 1
        else:
            return 0

    def __contains__(self, other):
        """
        Test whether one interval (or real number) is totally contained in
        another.

        EXAMPLES::

            sage: RIF(0, 2) in RIF(1, 3)
            False
            sage: RIF(0, 2) in RIF(0, 2)
            True
            sage: RIF(1, 2) in RIF(0, 3)
            True
            sage: 1.0 in RIF(0, 2)
            True
            sage: pi in RIF(3.1415, 3.1416)
            True
            sage: 22/7 in RIF(3.1415, 3.1416)
            False
        """

        cdef RealIntervalFieldElement other_intv
        cdef RealNumber other_rn
        if PY_TYPE_CHECK(other, RealIntervalFieldElement):
            other_intv = other
            return mpfi_is_inside(other_intv.value, self.value)
        elif PY_TYPE_CHECK(other, RealNumber):
            other_rn = other
            return mpfi_is_inside_fr(other_rn.value, self.value)
        try:
            other_intv = self._parent(other)
            return mpfi_is_inside(other_intv.value, self.value)
        except TypeError, msg:
            return False

    def contains_zero(self):
        """
        Returns True if self is an interval containing zero.

        EXAMPLES::

            sage: RIF(0).contains_zero()
            True
            sage: RIF(1, 2).contains_zero()
            False
            sage: RIF(-1, 1).contains_zero()
            True
            sage: RIF(-1, 0).contains_zero()
            True
        """
        return mpfi_has_zero(self.value)

    def overlaps(self, RealIntervalFieldElement other):
        """
        Returns true if self and other are intervals with at least one
        value in common. For intervals a and b, we have a.overlaps(b) iff
        not(a!=b).

        EXAMPLES::

            sage: RIF(0, 1).overlaps(RIF(1, 2))
            True
            sage: RIF(1, 2).overlaps(RIF(0, 1))
            True
            sage: RIF(0, 1).overlaps(RIF(2, 3))
            False
            sage: RIF(2, 3).overlaps(RIF(0, 1))
            False
            sage: RIF(0, 3).overlaps(RIF(1, 2))
            True
            sage: RIF(0, 2).overlaps(RIF(1, 3))
            True
        """
        return mpfr_greaterequal_p(&self.value.right, &other.value.left) \
           and mpfr_greaterequal_p(&other.value.right, &self.value.left)

    def intersection(self, other):
        """
        Return the intersection of two intervals. If the intervals do not
        overlap, raises a ValueError.

        EXAMPLES::

            sage: RIF(1, 2).intersection(RIF(1.5, 3)).str(style='brackets')
            '[1.5000000000000000 .. 2.0000000000000000]'
            sage: RIF(1, 2).intersection(RIF(4/3, 5/3)).str(style='brackets')
            '[1.3333333333333332 .. 1.6666666666666668]'
            sage: RIF(1, 2).intersection(RIF(3, 4))
            Traceback (most recent call last):
            ...
            ValueError: intersection of non-overlapping intervals
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        cdef RealIntervalFieldElement other_intv
        if PY_TYPE_CHECK(other, RealIntervalFieldElement):
            other_intv = other
        else:
            # Let type errors from _coerce_ propagate...
            other_intv = self._parent(other)

        mpfi_intersect(x.value, self.value, other_intv.value)
        if mpfr_less_p(&x.value.right, &x.value.left):
            raise ValueError, "intersection of non-overlapping intervals"
        return x

    def union(self, other):
        """
        Return the union of two intervals, or of an interval and a real
        number (more precisely, the convex hull).

        EXAMPLES::

            sage: RIF(1, 2).union(RIF(pi, 22/7)).str(style='brackets')
            '[1.0000000000000000 .. 3.1428571428571433]'
            sage: RIF(1, 2).union(pi).str(style='brackets')
            '[1.0000000000000000 .. 3.1415926535897936]'
            sage: RIF(1).union(RIF(0, 2)).str(style='brackets')
            '[0.00000000000000000 .. 2.0000000000000000]'
            sage: RIF(1).union(RIF(-1)).str(style='brackets')
            '[-1.0000000000000000 .. 1.0000000000000000]'
        """

        cdef RealIntervalFieldElement x
        x = self._new()
        cdef RealIntervalFieldElement other_intv
        cdef RealNumber other_rn
        if PY_TYPE_CHECK(other, RealIntervalFieldElement):
            other_intv = other
            mpfi_union(x.value, self.value, other_intv.value)
        elif PY_TYPE_CHECK(other, RealNumber):
            other_rn = other
            mpfi_set(x.value, self.value)
            mpfi_put_fr(x.value, other_rn.value)
        else:
            # Let type errors from _coerce_ propagate...
            other_intv = self._parent(other)
            mpfi_union(x.value, self.value, other_intv.value)
        return x

    def min(self, _other):
        """
        Returns an interval containing the minimum of self and other.

        EXAMPLES::

            sage: a=RIF(-1, 1).min(0).endpoints()
            sage: a[0] == -1.0 and a[1].abs() == 0.0 # in MPFI, the sign of 0.0 is not specified
            True
            sage: RIF(-1, 1).min(pi).endpoints()
            (-1.00000000000000, 1.00000000000000)
            sage: RIF(-1, 1).min(RIF(-100, 100)).endpoints()
            (-100.000000000000, 1.00000000000000)
            sage: RIF(-1, 1).min(RIF(-100, 0)).endpoints()
            (-100.000000000000, 0.000000000000000)

        The generic min does not always do the right thing::

            sage: min(0, RIF(-1, 1))
            0
            sage: min(RIF(-1, 1), RIF(-100, 100)).endpoints()
            (-1.00000000000000, 1.00000000000000)
        """
        cdef RealIntervalFieldElement other
        if isinstance(_other, RealIntervalFieldElement):
            other = <RealIntervalFieldElement>_other
        else:
            other = self._parent(_other)
        if mpfr_cmp(&self.value.right, &other.value.left) <= 0:
            return self
        elif mpfr_cmp(&other.value.right, &self.value.left) <= 0:
            return other
        cdef RealIntervalFieldElement x = self._new()
        mpfr_min(&x.value.left, &self.value.left, &other.value.left, GMP_RNDD)
        mpfr_min(&x.value.right, &self.value.right, &other.value.right, GMP_RNDU)
        return x

    def max(self, _other):
        """
        Returns an interval containing the maximum of self and other.

        EXAMPLES::

            sage: RIF(-1, 1).max(0).endpoints()
            (0.000000000000000, 1.00000000000000)
            sage: RIF(-1, 1).max(RIF(2, 3)).endpoints()
            (2.00000000000000, 3.00000000000000)
            sage: RIF(-1, 1).max(RIF(-100, 100)).endpoints()
            (-1.00000000000000, 100.000000000000)

        The generic max does not always do the right thing::

            sage: max(0, RIF(-1, 1))
            0
            sage: max(RIF(-1, 1), RIF(-100, 100)).endpoints()
            (-1.00000000000000, 1.00000000000000)
        """
        cdef RealIntervalFieldElement other
        if isinstance(_other, RealIntervalFieldElement):
            other = <RealIntervalFieldElement>_other
        else:
            other = self._parent(_other)
        if mpfr_cmp(&self.value.right, &other.value.left) <= 0:
            return other
        elif mpfr_cmp(&other.value.right, &self.value.left) <= 0:
            return self
        cdef RealIntervalFieldElement x = self._new()
        mpfr_max(&x.value.left, &self.value.left, &other.value.left, GMP_RNDD)
        mpfr_max(&x.value.right, &self.value.right, &other.value.right, GMP_RNDU)
        return x

    ############################
    # Special Functions
    ############################

    def sqrt(self):
        """
            Return a square root of self. Raises an error if self is
            nonpositive.

            If you use self.square_root() then an interval will always be
            returned (though it will be NaN if self is nonpositive).

            EXAMPLES::

                sage: r = RIF(4.0)
                sage: r.sqrt()
                2
                sage: r.sqrt()^2 == r
                True

            ::

                sage: r = RIF(4344)
                sage: r.sqrt()
                65.90902821313633?
                sage: r.sqrt()^2 == r
                False
                sage: r in r.sqrt()^2
                True
                sage: r.sqrt()^2 - r
                0.?e-11
                sage: (r.sqrt()^2 - r).str(style='brackets')
                '[-9.0949470177292824e-13 .. 1.8189894035458565e-12]'

            ::

                sage: r = RIF(-2.0)
                sage: r.sqrt()
                Traceback (most recent call last):
                ...
                ValueError: self (=-2) is not >= 0

            ::

                sage: r = RIF(-2, 2)
                sage: r.sqrt()
                Traceback (most recent call last):
                ...
                ValueError: self (=0.?e1) is not >= 0
            """
        if self.lower() < 0:
            raise ValueError, "self (=%s) is not >= 0"%self
        return self.square_root()

    def square_root(self):
        """
        Return a square root of self. An interval will always be returned
        (though it will be NaN if self is nonpositive).

        EXAMPLES::

            sage: r = RIF(-2.0)
            sage: r.square_root()
            [.. NaN ..]
            sage: r.sqrt()
            Traceback (most recent call last):
            ...
            ValueError: self (=-2) is not >= 0
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_sqrt(x.value, self.value)
        sig_off()
        return x

# MPFI does not have cbrt.
#     def cube_root(self):
#         """
#         Return the cubic root (defined over the real numbers) of self.

#         EXAMPLES:
#             sage: r = 125.0; r.cube_root()
#             5.00000000000000
#             sage: r = -119.0
#             sage: r.cube_root()^3 - r       # illustrates precision loss
#             -0.0000000000000142108547152020
#         """
#         cdef RealIntervalFieldElement x
#         x = self._new()
#         sig_on()
#         mpfr_cbrt(x.value, self.value, (<RealIntervalField>self._parent).rnd)
#         sig_off()
#         return x

# MPFI does not have pow.
#     def __pow(self, RealIntervalFieldElement exponent):
#         cdef RealIntervalFieldElement x
#         x = self._new()
#         sig_on()
#         mpfr_pow(x.value, self.value, exponent.value, (<RealIntervalField>self._parent).rnd)
#         sig_off()
#         if mpfr_nan_p(x.value):
#             return self._complex_number_()**exponent._complex_number_()
#         return x

#     def __pow__(self, exponent, modulus):
#         """
#         Compute self raised to the power of exponent, rounded in
#         the direction specified by the parent of self.

#         If the result is not a real number, self and the exponent are
#         both coerced to complex numbers (with sufficient precision),
#         then the exponentiation is computed in the complex numbers.
#         Thus this function can return either a real or complex number.

#         EXAMPLES:
#             sage: R = RealIntervalField(30)
#             sage: a = R('1.23456')
#             sage: a^20
#             67.646297
#             sage: a^a
#             1.2971114
#             sage: b = R(-1)
#             sage: b^(1/2)
#             1.0000000*I                   # 32-bit
#             -0.00000000000000000010842021 + 0.99999999*I   # 64-bit
#         """
#         cdef RealIntervalFieldElement x
#         if not PY_TYPE_CHECK(self, RealIntervalFieldElement):
#             return self.__pow__(float(exponent))
#         if not PY_TYPE_CHECK(exponent, RealIntervalFieldElement):
#             x = self
#             exponent = x._parent(exponent)
#         return self.__pow(exponent)

    def __pow__(self, exponent, modulus):
        """
        EXAMPLES:
        sage: R = RealIntervalField(17)
        sage: x = R((-e,pi))
        sage: x2 = x^2; x2.lower(), x2.upper()
        (0.0000, 9.870)
        sage: x3 = x^3; x3.lower(), x3.upper()
        (-26.83, 31.01)
        """
        if exponent == 2:
            return self.square()
        if isinstance(exponent, (int, long, Integer)):
            q, r = divmod (exponent, 2)
            if r == 0: # x^(2q) = (x^q)^2
               xq = sage.rings.ring_element.RingElement.__pow__(self, q)
               return xq.abs().square()
            else:
               return sage.rings.ring_element.RingElement.__pow__(self, exponent)
        return (self.log() * exponent).exp()

    def log(self, base='e'):
        """
        EXAMPLES::

            sage: R = RealIntervalField()
            sage: r = R(2); r.log()
            0.6931471805599453?
            sage: r = R(-2); r.log()
            0.6931471805599453? + 3.141592653589794?*I
        """
        cdef RealIntervalFieldElement x
        if self < 0:
            return self.parent().complex_field()(self).log(base)
        if base == 'e':
            x = self._new()
            sig_on()
            mpfi_log(x.value, self.value)
            sig_off()
            return x
        elif base == 10:
            return self.log10()
        elif base == 2:
            return self.log2()
        else:
            return self.log() / (self.parent()(base)).log()

    def log2(self):
        """
        Returns log to the base 2 of self

        EXAMPLES::

            sage: r = RIF(16.0)
            sage: r.log2()
            4

        ::

            sage: r = RIF(31.9); r.log2()
            4.995484518877507?

        ::

            sage: r = RIF(0.0, 2.0)
            sage: r.log2()
            [-infinity .. 1.0000000000000000]
        """
        cdef RealIntervalFieldElement x
        if self < 0:
            return self.parent().complex_field()(self).log(2)
        x = self._new()
        sig_on()
        mpfi_log2(x.value, self.value)
        sig_off()
        return x

    def log10(self):
        """
        Returns log to the base 10 of self

        EXAMPLES::

            sage: r = RIF(16.0); r.log10()
            1.204119982655925?
            sage: r.log() / log(10.0)
            1.204119982655925?

        ::

            sage: r = RIF(39.9); r.log10()
            1.600972895686749?

        ::

            sage: r = RIF(0.0)
            sage: r.log10()
            [-infinity .. -infinity]

        ::

            sage: r = RIF(-1.0)
            sage: r.log10()
            1.364376353841841?*I
        """
        cdef RealIntervalFieldElement x
        if self < 0:
            return self.parent().complex_field()(self).log(10)
        x = self._new()
        sig_on()
        mpfi_log10(x.value, self.value)
        sig_off()
        return x

    def exp(self):
        r"""
        Returns `e^\mathtt{self}`

        EXAMPLES::

            sage: r = RIF(0.0)
            sage: r.exp()
            1

        ::

            sage: r = RIF(32.3)
            sage: a = r.exp(); a
            1.065888472748645?e14
            sage: a.log()
            32.30000000000000?

        ::

            sage: r = RIF(-32.3)
            sage: r.exp()
            9.38184458849869?e-15
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_exp(x.value, self.value)
        sig_off()
        return x

    def exp2(self):
        """
        Returns `2^\mathtt{self}`

        EXAMPLES::

            sage: r = RIF(0.0)
            sage: r.exp2()
            1

        ::

            sage: r = RIF(32.0)
            sage: r.exp2()
            4294967296

        ::

            sage: r = RIF(-32.3)
            sage: r.exp2()
            1.891172482530207?e-10
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_exp2(x.value, self.value)
        sig_off()
        return x

    def is_int(self):
        r"""
        OUTPUT:

        -  ``bool`` - True or False

        -  ``n`` - an integer

        Checks to see whether this interval includes exactly one integer.
        If so, returns a tuple ``(True, n)``, where
        ``n`` is that integer; otherwise, returns
        ``(False, None)``.

        EXAMPLES::

            sage: a = RIF(0.8,1.5)
            sage: a.is_int()
            (True, 1)
            sage: a = RIF(1.1,1.5)
            sage: a.is_int()
            (False, None)
            sage: a = RIF(1,2)
            sage: a.is_int()
            (False, None)
            sage: a = RIF(-1.1, -0.9)
            sage: a.is_int()
            (True, -1)
            sage: a = RIF(0.1, 1.9)
            sage: a.is_int()
            (True, 1)
            sage: RIF(+infinity,+infinity).is_int()
            (False, None)
        """
        a = self.lower()
        if a.is_NaN() or a.is_infinity():
            return False, None
        a = a.ceil()
        b = self.upper()
        if b.is_NaN() or b.is_infinity():
            return False, None
        b = b.floor()
        if a == b:
            return True, a
        else:
            return False, None

# MPFI does not have exp10.  (Could easily be synthesized if anybody cares.)
#     def exp10(self):
#         r"""
#         Returns $10^\code{self}$

#         EXAMPLES:
#             sage: r = 0.0
#             sage: r.exp10()
#             1.00000000000000

#             sage: r = 32.0
#             sage: r.exp10()
#             100000000000000000000000000000000

#             sage: r = -32.3
#             sage: r.exp10()
#             0.00000000000000000000000000000000501187233627275
#         """
#         cdef RealIntervalFieldElement x
#         x = self._new()
#         sig_on()
#         mpfr_exp10(x.value, self.value, (<RealIntervalField>self._parent).rnd)
#         sig_off()
#         return x

    def cos(self):
        """
        Returns the cosine of this number.

        EXAMPLES::

            sage: t=RIF(pi)/2
            sage: t.cos()
            0.?e-15
            sage: t.cos().str(style='brackets')
            '[-1.6081226496766367e-16 .. 6.1232339957367661e-17]'
            sage: t.cos().cos()
            0.9999999999999999?

        TESTS:

        This looped forever with an earlier version of MPFI, but now
        it works.

        ::

            sage: RIF(-1, 1).cos().str(style='brackets')
            '[0.54030230586813965 .. 1.0000000000000000]'
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_cos(x.value, self.value)
        sig_off()
        return x

    def sin(self):
        """
        Returns the sine of this number

        EXAMPLES::

            sage: R = RealIntervalField(100)
            sage: R(2).sin()
            0.909297426825681695396019865912?
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_sin(x.value, self.value)
        sig_off()
        return x

    def tan(self):
        """
        Returns the tangent of this number

        EXAMPLES::

            sage: q = RIF.pi()/3
            sage: q.tan()
            1.732050807568877?
            sage: q = RIF.pi()/6
            sage: q.tan()
            0.577350269189626?
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_tan(x.value, self.value)
        sig_off()
        return x

# MPFI does not have sincos
#     def sincos(self):
#         """
#         Returns a pair consisting of the sine and cosine.

#         EXAMPLES:
#             sage: R = RealIntervalField()
#             sage: t = R.pi()/6
#             sage: t.sincos()
#             (0.499999999999999, 0.866025403784438)
#         """
#         cdef RealIntervalFieldElement x,y
#         x = self._new()
#         y = self._new()
#         sig_on()
#         mpfi_sin_cos(x.value, y.value, self.value)
#         sig_off()
#         return x,y

    def arccos(self):
        """
        Returns the inverse cosine of this number

        EXAMPLES::

            sage: q = RIF.pi()/3; q
            1.047197551196598?
            sage: i = q.cos(); i
            0.500000000000000?
            sage: q2 = i.arccos(); q2
            1.047197551196598?
            sage: q == q2
            False
            sage: q != q2
            False
            sage: q2.lower() == q.lower()
            False
            sage: q - q2
            0.?e-15
            sage: q in q2
            True
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_acos(x.value, self.value)
        sig_off()
        return x

    def arcsin(self):
        """
        Returns the inverse sine of this number

        EXAMPLES::

            sage: q = RIF.pi()/5; q
            0.6283185307179587?
            sage: i = q.sin(); i
            0.587785252292474?
            sage: q2 = i.arcsin(); q2
            0.628318530717959?
            sage: q == q2
            False
            sage: q != q2
            False
            sage: q2.lower() == q.lower()
            False
            sage: q - q2
            0.?e-15
            sage: q in q2
            True
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_asin(x.value, self.value)
        sig_off()
        return x

    def arctan(self):
        """
        Returns the inverse tangent of this number

        EXAMPLES::

            sage: q = RIF.pi()/5; q
            0.6283185307179587?
            sage: i = q.tan(); i
            0.726542528005361?
            sage: q2 = i.arctan(); q2
            0.628318530717959?
            sage: q == q2
            False
            sage: q != q2
            False
            sage: q2.lower() == q.lower()
            False
            sage: q - q2
            0.?e-15
            sage: q in q2
            True
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_atan(x.value, self.value)
        sig_off()
        return x

    def cosh(self):
        """
        Returns the hyperbolic cosine of this number

        EXAMPLES::

            sage: q = RIF.pi()/12
            sage: q.cosh()
            1.034465640095511?
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_cosh(x.value, self.value)
        sig_off()
        return x

    def sinh(self):
        """
        Returns the hyperbolic sine of this number

        EXAMPLES::

            sage: q = RIF.pi()/12
            sage: q.sinh()
            0.2648002276022707?
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_sinh(x.value, self.value)
        sig_off()
        return x

    def tanh(self):
        """
        Returns the hyperbolic tangent of this number

        EXAMPLES::

            sage: q = RIF.pi()/11
            sage: q.tanh()
            0.2780794292958503?
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_tanh(x.value, self.value)
        sig_off()
        return x

    def arccosh(self):
        """
        Returns the hyperbolic inverse cosine of this number

        EXAMPLES::

            sage: q = RIF.pi()/2
            sage: i = q.arccosh() ; i
            1.023227478547551?
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_acosh(x.value, self.value)
        sig_off()
        return x

    def arcsinh(self):
        """
        Returns the hyperbolic inverse sine of this number

        EXAMPLES::

            sage: q = RIF.pi()/7
            sage: i = q.sinh() ; i
            0.464017630492991?
            sage: i.arcsinh() - q
            0.?e-15
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_asinh(x.value, self.value)
        sig_off()
        return x

    def arctanh(self):
        """
        Returns the hyperbolic inverse tangent of this number

        EXAMPLES::

            sage: q = RIF.pi()/7
            sage: i = q.tanh() ; i
            0.420911241048535?
            sage: i.arctanh() - q
            0.?e-15
        """
        cdef RealIntervalFieldElement x
        x = self._new()
        sig_on()
        mpfi_atanh(x.value, self.value)
        sig_off()
        return x

    # We implement some inverses in the obvious way (so they will
    # usually not be perfectly rounded).  This gets us closer to the
    # API of RealField.

    def sec(self):
        r"""
        Returns the secant of this number.

        EXAMPLES::

            sage: RealIntervalField(100)(2).sec()
            -2.40299796172238098975460040142?
        """
        return ~self.cos()

    def csc(self):
        r"""
        Returns the cosecant of this number.

        EXAMPLES::

            sage: RealIntervalField(100)(2).csc()
            1.099750170294616466756697397026?
        """
        return ~self.sin()

    def cot(self):
        r"""
        Returns the cotangent of this number.

        EXAMPLES::

            sage: RealIntervalField(100)(2).cot()
            -0.457657554360285763750277410432?
        """
        return ~self.tan()

    def sech(self):
        r"""
        Returns the hyperbolic secant of this number.

        EXAMPLES::

            sage: RealIntervalField(100)(2).sech()
            0.265802228834079692120862739820?
        """
        return ~self.cosh()

    def csch(self):
        r"""
        Returns the hyperbolic cosecant of this number.

        EXAMPLES::

            sage: RealIntervalField(100)(2).csch()
            0.275720564771783207758351482163?
        """
        return ~self.sinh()

    def coth(self):
        r"""
        Returns the hyperbolic cotangent of this number.

        EXAMPLES::

            sage: RealIntervalField(100)(2).coth()
            1.03731472072754809587780976477?
        """
        return ~self.tanh()

    def arcsech(self):
        r"""
        Returns the inverse hyperbolic secant of this number.

        EXAMPLES::

            sage: RealIntervalField(100)(0.5).arcsech()
            1.316957896924816708625046347308?
            sage: (0.5).arcsech()
            1.31695789692482
        """
        return (~self).arccosh()

    def arccsch(self):
        r"""
        Returns the inverse hyperbolic cosecant of this number.

        EXAMPLES::

            sage: RealIntervalField(100)(2).arccsch()
            0.481211825059603447497758913425?
            sage: (2.0).arccsch()
            0.481211825059603
        """
        return (~self).arcsinh()

    def arccoth(self):
        r"""
        Returns the inverse hyperbolic cotangent of this number.

        EXAMPLES::

            sage: RealIntervalField(100)(2).arccoth()
            0.549306144334054845697622618462?
            sage: (2.0).arccoth()
            0.549306144334055
        """
        return (~self).arctanh()

    def algdep(self, n):
        """
        Returns a polynomial of degree at most `n` which is
        approximately satisfied by this number. Note that the returned
        polynomial need not be irreducible, and indeed usually won't be if
        this number is a good approximation to an algebraic number of
        degree less than `n`.

        Pari needs to know the number of "known good bits" in the number;
        we automatically get that from the interval width.

        ALGORITHM: Uses the PARI C-library algdep command.

        EXAMPLE::

            sage: r = sqrt(RIF(2)); r
            1.414213562373095?
            sage: r.algdep(5)
            x^2 - 2

        If we compute a wrong, but precise, interval, we get a wrong
        answer.

        ::

            sage: r = sqrt(RealIntervalField(200)(2)) + (1/2)^40; r
            1.414213562374004543503461652447613117632171875376948073176680?
            sage: r.algdep(5)
            7266488*x^5 + 22441629*x^4 - 90470501*x^3 + 23297703*x^2 + 45778664*x + 13681026

        But if we compute an interval that includes the number we mean,
        we're much more likely to get the right answer, even if the
        interval is very imprecise.

        ::

            sage: r = r.union(sqrt(2.0))
            sage: r.algdep(5)
            x^2 - 2

        Even on this extremely imprecise interval we get an answer which is
        technically correct.

        ::

            sage: RIF(-1, 1).algdep(5)
            x
        """

        # If 0 is in the interval, then we have no known bits!  But
        # fortunately, there's a perfectly valid answer we can
        # return anyway.
        if 0 in self:
            #import sage.rings.polynomial.polynomial_ring
            return sage.rings.polynomial.polynomial_ring.polygen(
                sage.rings.integer_ring.IntegerRing())

        known_bits = -self.relative_diameter().log2()

        return sage.rings.arith.algdep(self.center(), n, known_bits=known_bits)

    def gamma(self):
        """
        EXAMPLES::

            sage: RIF(1).gamma()
            1
            sage: RIF(5).gamma()
            24
            sage: a = RIF(3,4).gamma(); a
            1.?e1
            sage: a.lower(), a.upper()
            (2.00000000000000, 6.00000000000000)
            sage: RIF(-1/2).gamma()
            -3.54490770181104?
            sage: gamma(-1/2).n(100) in RIF(-1/2).gamma()
            True
            sage: 0 in (RealField(2000)(-19/3).gamma() - RealIntervalField(1000)(-19/3).gamma())
            True
            sage: gamma(RIF(100))
            9.33262154439442?e155
            sage: gamma(RIF(-10000/3))
            1.31280781451?e-10297

        Verify the result contains the local minima::

            sage: 0.88560319441088 in RIF(1, 2).gamma()
            True
            sage: 0.88560319441088 in RIF(0.25, 4).gamma()
            True
            sage: 0.88560319441088 in RIF(1.4616, 1.46164).gamma()
            True

            sage: (-0.99).gamma()
            -100.436954665809
            sage: (-0.01).gamma()
            -100.587197964411
            sage: RIF(-0.99, -0.01).gamma().upper()
            -1.60118039970055

        Correctly detects poles::

            sage: gamma(RIF(-3/2,-1/2))
            [-infinity .. +infinity]
        """
        cdef RealIntervalFieldElement x = self._new()
        if self > 1.462:
            # increasing
            mpfr_gamma(&x.value.left, &self.value.left, GMP_RNDD)
            mpfr_gamma(&x.value.right, &self.value.right, GMP_RNDU)
            return x
        elif self < 0:
            # Gamma(s) Gamma(1-s) = pi/sin(pi s)
            pi = self._parent.pi()
            return pi / ((self*pi).sin() * (1-self).gamma())
        elif self.contains_zero():
            # [-infinity, infinity]
            return ~self
        elif self < 1.461:
            # 0 < self as well, so decreasing
            mpfr_gamma(&x.value.left, &self.value.right, GMP_RNDD)
            mpfr_gamma(&x.value.right, &self.value.left, GMP_RNDU)
            return x
        else:
            # Worst case, this will recurse twice, as self is positive.
            return (1+self).gamma() / self

# MPFI does not have: agm, erf, gamma, zeta
#     def agm(self, other):
#         """
#         Return the arithmetic-geometric mean of self and other. The
#         arithmetic-geometric mean is the common limit of the sequences
#         $u_n$ and $v_n$, where $u_0$ is self, $v_0$ is other,
#         $u_{n+1}$ is the arithmetic mean of $u_n$ and $v_n$, and
#         $v_{n+1}$ is the geometric mean of u_n and v_n. If any operand
#         is negative, the return value is \code{NaN}.
#         """
#         cdef RealIntervalFieldElement x, _other
#         if not isinstance(other, RealIntervalFieldElement) or other.parent() != self._parent:
#             _other = self._parent(other)
#         else:
#             _other = other
#         x = self._new()
#         sig_on()
#         mpfi_agm(x.value, self.value, _other.value)
#         sig_off()
#         return x

#     def erf(self):
#         """
#         Returns the value of the error function on self.

#         EXAMPLES:
#            sage: R = RealIntervalField()
#            sage: R(6).erf()
#            0.999999999999999
#         """
#         cdef RealIntervalFieldElement x
#         x = self._new()
#         sig_on()
#         mpfi_erf(x.value, self.value)
#         sig_off()
#         return x

#     def gamma(self):
#         """
#         The Euler gamma function. Return gamma of self.

#         EXAMPLES:
#            sage: R = RealIntervalField()
#            sage: R(6).gamma()
#            120.000000000000
#            sage: R(1.5).gamma()
#            0.886226925452757
#         """
#         cdef RealIntervalFieldElement x
#         x = self._new()
#         sig_on()
#         mpfi_gamma(x.value, self.value)
#         sig_off()
#         return x

#     def zeta(self):
#         r"""
#         Return the Riemann zeta function evaluated at this real number.

#         \note{PARI is vastly more efficient at computing the Riemann zeta
#         function.   See the example below for how to use it.}

#         EXAMPLES:
#             sage: R = RealIntervalField()
#             sage: R(2).zeta()
#             1.64493406684822
#             sage: R.pi()^2/6
#             1.64493406684822
#             sage: R(-2).zeta()
#             0.000000000000000
#             sage: R(1).zeta()
#             +infinity

#         Computing zeta using PARI is much more efficient in difficult cases.
#         Here's how to compute zeta with at least a given precision:

#              sage: z = pari.new_with_bits_prec(2, 53).zeta(); z
#              1.644934066848226436472415167              # 32-bit
#              1.6449340668482264364724151666460251892    # 64-bit

#         Note that the number of bits of precision in the constructor only
#         affects the internal precision of the pari number, not the number
#         of digits that gets displayed.  To increase that you must
#         use \code{pari.set_real_precision}.

#              sage: type(z)
#              <type 'sage.libs.pari.gen.gen'>
#              sage: R(z)
#              1.64493406684822
#         """
#         cdef RealIntervalFieldElement x
#         x = self._new()
#         sig_on()
#         mpfi_zeta(x.value, self.value)
#         sig_off()
#         return x

def _simplest_rational_test_helper(low, high, low_open=False, high_open=False):
    """
    Call _simplest_rational_exact(). Only used to allow doctests on
    that function.
    """
    return _simplest_rational_exact(low, high, low_open, high_open)

cdef _simplest_rational_exact(Rational low, Rational high, int low_open, int high_open):
    """
    Return the simplest rational between low and high. May return low
    or high unless low_open or high_open (respectively) are true
    (non-zero). We assume that low and high are both nonnegative, and
    that high>low.

    This is a helper function for simplest_rational() on
    RealIntervalField, and should not be called directly.

    EXAMPLES::

        sage: test = sage.rings.real_mpfi._simplest_rational_test_helper
        sage: test(1/4, 1/3, 0, 0)
        1/3
        sage: test(1/4, 1/3, 0, 1)
        1/4
        sage: test(1/4, 1/3, 1, 1)
        2/7
        sage: test(QQ(0), QQ(2), 0, 0)
        0
        sage: test(QQ(0), QQ(2), 1, 0)
        1
        sage: test(QQ(0), QQ(1), 1, 0)
        1
        sage: test(QQ(0), QQ(1), 1, 1)
        1/2
        sage: test(1233/1234, QQ(1), 0, 0)
        1
        sage: test(1233/1234, QQ(1), 0, 1)
        1233/1234
        sage: test(10000/32007, 10001/32007, 0, 0)
        289/925
        sage: test(QQ(0), 1/3, 1, 0)
        1/3
        sage: test(QQ(0), 1/3, 1, 1)
        1/4
        sage: test(QQ(0), 2/5, 1, 0)
        1/3
        sage: test(QQ(0), 2/5, 1, 1)
        1/3
    """
    cdef Rational r

    if low < 1:
        if low == 0:
            if low_open:
                if high > 1:
                    return Rational(1)
                inv_high = ~high
                if high_open:
                    return ~Rational(inv_high.floor() + 1)
                else:
                    return ~Rational(inv_high.ceil())
            else:
                return Rational(0)

        if high > 1:
            return Rational(1)

        r = _simplest_rational_exact(~high, ~low, high_open, low_open)
        return ~r

    fl = low.floor()
    return fl + _simplest_rational_exact(low - fl, high - fl, low_open, high_open)

def RealInterval(s, upper=None, int base=10, int pad=0, min_prec=53):
    r"""
    Return the real number defined by the string s as an element of
    ``RealIntervalField(prec=n)``, where n potentially has
    slightly more (controlled by pad) bits than given by s.

    INPUT:

    -  ``s`` - a string that defines a real number (or
       something whose string representation defines a number)

    -  ``upper`` - (default: None) - upper endpoint of
       interval if given, in which case s is the lower endpoint.

    -  ``base`` - an integer between 2 and 36

    -  ``pad`` - an integer = 0.

    -  ``min_prec`` - number will have at least this many
       bits of precision, no matter what.

    EXAMPLES::

        sage: RealInterval('2.3')
        2.300000000000000?
        sage: RealInterval(10)
        10
        sage: RealInterval('1.0000000000000000000000000000000000')
        1
        sage: RealInterval('1.2345678901234567890123456789012345')
        1.23456789012345678901234567890123450?
        sage: RealInterval(29308290382930840239842390482, 3^20).str(style='brackets')
        '[3.48678440100000000000000000000e9 .. 2.93082903829308402398423904820e28]'

    TESTS:

    Make sure we've rounded up log(10,2) enough to guarantee
    sufficient precision (trac #10164).  This is a little tricky
    because at the time of writing, we don't support intervals long
    enough to trip the error.  However, at least we can make sure
    that we either do it correctly or fail noisily::

        sage: ks = 5*10**5, 10**6
        sage: for k in ks:
        ...      try:
        ...          z = RealInterval("1." + "1"*k)
        ...          assert len(str(z))-4 >= k
        ...      except TypeError:
        ...          pass

    """
    if not isinstance(s, str):
        s = str(s)
    if base == 10:
        # hard-code the common case
        bits = int(LOG_TEN_TWO_PLUS_EPSILON*len(s))
    else:
        bits = int(math.log(base,2)*1.00001*len(s))
    R = RealIntervalField(prec=max(bits+pad, min_prec))
    return R(s, upper, base)

# The default real interval field, with precision 53 bits
RIF = RealIntervalField()

def is_RealIntervalField(x):
    return PY_TYPE_CHECK(x, RealIntervalField_class)

def is_RealIntervalFieldElement(x):
    return PY_TYPE_CHECK(x, RealIntervalFieldElement)

#### pickle functions
def __create__RealIntervalField_version0(prec, sci_not):
    return RealIntervalField(prec, sci_not)

## Keep all old versions!!!
def __create__RealIntervalFieldElement_version0(parent, x, base=10):
    return RealIntervalFieldElement(parent, x, base=base)

def __create__RealIntervalFieldElement_version1(parent, lower, upper):
    return RealIntervalFieldElement(parent, (lower, upper))
