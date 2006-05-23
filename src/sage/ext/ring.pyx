"""
Abstract base class for rings
"""

#*****************************************************************************
#       Copyright (C) 2005 William Stein <wstein@ucsd.edu>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#
#    This code is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#    General Public License for more details.
#
#  The full text of the GPL is available at:
#
#                  http://www.gnu.org/licenses/
#*****************************************************************************

import random
import sage.ext.coerce

import sage.rings.finite_field
import sage.rings.integer_ring
import sage.rings.rational_field

cdef class Ring(gens.Generators):
    """
    Generic ring class.
    """
    def __init__(self):
        pass

    def __call__(self, x):
        """
        Coerce x into the ring.
        """
        raise NotImplementedError

    def __iter__(self):
        raise NotImplementedError, "object does not support iteration"

    def __getitem__(self, x):
        """
        Create a polynomial or power series ring over self.

        EXAMPLES:
        We create several polynomial rings.
            sage: Z['x']
            Univariate Polynomial Ring in x over Integer Ring
            sage: Q['x']
            Univariate Polynomial Ring in x over Rational Field
            sage: GF(17)['abc']
            Univariate Polynomial Ring in abc over Finite Field of size 17
            sage: GF(17)['a,b,c']
            Polynomial Ring in a, b, c over Finite Field of size 17

        We can also create power series rings (in one variable) by
        using double brackets:
            sage: Q[['t']]
            Power Series Ring in t over Rational Field
            sage: Z[['W']]
            Power Series Ring in W over Integer Ring

        Use \code{Frac} (for fraction field) to obtain a Laurent series ring:
            sage: Frac(Q[['t']])
            Laurent Series Ring in t over Rational Field

        """
        P = None
        if isinstance(x, list):
            if len(x) != 1:
                raise NotImplementedError, "Power series rings only implemented in 1 variable"
            x = (str(x[0]), )
            from sage.rings.power_series_ring import PowerSeriesRing
            P = PowerSeriesRing

        elif isinstance(x, (tuple, str)):
            from sage.rings.polynomial_ring import PolynomialRing
            P = PolynomialRing
            if isinstance(x, tuple):
                y = []
                for w in x:
                    y.append(str(w))
                x = tuple(y)

        else:
            from sage.rings.polynomial_ring import PolynomialRing
            P = PolynomialRing
            x = (str(x),)

        if P is None:
            raise NotImplementedError

        if isinstance(x, tuple):
            v = x
        else:
            v = x.split(',')

        if len(v) > 1:
            return P(self, len(v), names=v)
        else:
            return P(self, x)

    def __xor__(self, n):
        raise RuntimeError, "Use ** for exponentiation, not '^', which means xor\n"+\
              "in Python, and has the wrong precedence."

    def _coerce_(self, x):
        return self(x)

    def base_ring(self):
        return sage.rings.integer_ring.Z

    def category(self):
        """
        Return the category to which this ring belongs.
        """
        from sage.categories.all import Rings
        return Rings()

    def ideal(self, x, coerce=True):
        """
        Return the ideal defined by x (e.g., generators).
        """
        C = self._ideal_class_()
        return C(self, x, coerce=coerce)

    def __mul__(self, x):
        if isinstance(self, Ring):
            return self.ideal(x)
        else:
            return x.ideal(self)    # switched because this is Pyrex / extension class

    def _r_action(self, x):
        return self.ideal(x)

    def _ideal_class_(self):
        import sage.rings.ideal
        return sage.rings.ideal.Ideal

    def principal_ideal(self, gen, coerce=True):
        """
        Return the principal ideal generated by gen.
        """
        return self.ideal([gen], coerce=coerce)

    def unit_ideal(self):
        """
        Return the unit ideal of this ring.
        """
        return Ring.ideal(self, [self(1)], coerce=False)

    def zero_ideal(self):
        """
        Return the zero ideal of this ring.
        """
        return Ring.ideal(self, [self(0)], coerce=False)

    def is_atomic_repr(self):
        """
        True if the elements have atomic string representations, in the sense
        that they print if they print at s, then -s means the negative of s.
        For example, integers are atomic but polynomials are not.
        """
        return False

    def is_commutative(self):
        """
        Return True if this ring is commutative.
        """
        raise NotImplementedError

    def is_field(self):
        """
        Return True if this ring is a field.
        """
        raise NotImplementedError

    def is_prime_field(self):
        r"""
        Return True if this ring is one of the prime fields $\Q$
        or $\F_p$.
        """
        return False

    def is_finite(self):
        """
        Return True if this ring is finite.
        """
        raise NotImplementedError

    def is_integral_domain(self):
        """
        Return True if this ring is an integral domain.
        """
        return NotImplementedError

    def is_ring(self):
        """
        Return True since self is a ring.
        """
        return True

    def is_noetherian(self):
        """
        Return True if this ring is Noetherian.
        """
        raise NotImplementedError

    def characteristic(self):
        """
        Return the characteristic of this ring.
        """
        raise NotImplementedError

    def order(self):
        """
        The number of elements of self.
        """
        raise NotImplementedError

    def __hash__(self):
        return hash(self.__repr__())

    def zeta(self):
        return self(-1)

    def zeta_order(self):
        return self.zeta().multiplicative_order()

    def random_element(self, bound=None):
        """
        Return a random integer coerced into this ring, where the
        integer is chosen uniformly from the interval [-bound,bound].

        INPUT:
            bound -- int or None; (default: None, which defaults to 2.)
        """
        if bound is None:
            bound = 2
        return self(random.randrange(-bound, bound+1))

cdef class CommutativeRing(Ring):
    """
    Generic commutative ring.
    """
    def __pow__(self, n, _):
        """
        Return the free module of rank $n$ over this ring.
        """
        import sage.modules.all
        return sage.modules.all.FreeModule(self, n)

    def is_commutative(self):
        """
        Return True, since this ring is commutative.
        """
        return True

    def krull_dimension(self):
        """
        Return the Krull dimension if this commutative ring.

        The Krull dimension is the length of the longest ascending chain
        of prime ideals.
        """
        raise NotImplementedError

    def ideal_monoid(self):
        """
        Return the monoid of ideals of this ring.
        """
        try:
            return self.__ideal_monoid
        except AttributeError:
            from sage.rings.ideal_monoid import IdealMonoid
            M = IdealMonoid(self)
            try:
                self.__ideal_monoid = M
            except AttributeError:   # for pyrex classes
                pass
            return M

    def quotient(self, I, names=None):
        """
        Create the quotient of R by the ideal I.

        INPUT:
            R -- a commutative ring
            I -- an ideal of R

        EXAMPLES:
            sage: R, x = (Z['x']).objgen()
            sage: I = R.ideal([4 + 3*x + x^2, 1 + x^2])
            sage: S = R.quotient(I, 'a')
            sage: S.gens()
            (a,)

            sage: R, (x,y) = PolynomialRing(QQ, 2, 'xy').objgens()
            sage: S, (a,b) = ( R/ (x^2, y) ).objgens('ab')
            sage: S
            Quotient of Polynomial Ring in x, y over Rational Field by the ideal (y, x^2)
            sage: S.gens()
            (a, 0)
            sage: a == b
            False
        """
        import sage.rings.quotient_ring
        Q = sage.rings.quotient_ring.QuotientRing(self, I)
        Q.assign_names(names)
        return Q

    def __div__(self, I):
        return self.quotient(I)

    def quotient_ring(self, I):
        """
        Return the quotient of self by the ideal I of self.
        (Synonym for self.quotient(I).)
        """
        return self.quotient(I)

cdef class IntegralDomain(CommutativeRing):
    """
    Generic integral domain class.
    """
    def is_integral_domain(self):
        """
        Return True, since this ring is an integral domain.
        """
        return True

    def fraction_field(self):
        """
        Return the fraction field of self.
        """
        try:
            return self.__fraction_field
        except AttributeError:
            import sage.rings.fraction_field
            self.__fraction_field = sage.rings.fraction_field.FractionField_generic(self)
        return self.__fraction_field

    def is_field(self):
        """
        Return True if this ring is a field.
        """
        if self.is_finite():
            return True
        raise NotImplementedError, "unable to determine whether or not is a field."

cdef class NoetherianRing(CommutativeRing):
    """
    Generic Noetherian ring class.

    A Noetherian ring is a commutative ring in which every ideal is
    finitely generated.
    """
    def is_noetherian(self):
        """
        Return True since this ring is Noetherian.
        """
        return True

cdef class DedekindDomain(IntegralDomain):
    """
    Generic Dedekind domain class.

    A Dedekind domain is a Noetherian integral domain of Krull
    dimension one that is integrally closed in its field of fractions.
    """
    def krull_dimension(self):
        """
        Return 1 since Dedekind domains have Krull dimension 1.
        """
        return 1

    def is_integrally_closed(self):
        """
        Return True since Dedekind domains are integrally closed.
        """
        return True

    def integral_closure(self):
        """
        Return self since Dedekind domains are integrally closed.
        """
        return self

    def is_noetherian(self):
        """
        Return True since Dedekind domains are noetherian.
        """
        return True

cdef class PrincipalIdealDomain(IntegralDomain):
    """
    Generic principal ideal domain.
    """
    def class_group(self):
        """
        Return the trivial group, since the class group of a PID is trivial.

        EXAMPLES:
            sage: QQ.class_group()
            Trivial Abelian Group
        """
        from sage.groups.abelian_gps.abelian_group import AbelianGroup
        return AbelianGroup([])

    def gcd(self, x, y, coerce=True):
        """
        Return the greatest common divisor of x and y, as elements
        of self.
        """
        if coerce:
            x = self(x)
            y = self(y)
        return x.gcd(y)

cdef class EuclideanDomain(PrincipalIdealDomain):
    """
    Generic Euclidean domain class.
    """
    def parameter(self):
        """
        Return an element of degree 1.
        """
        raise NotImplementedError

def is_Field(x):
    """
    Return True if x is of class Field.
    """
    return isinstance(x, Field)

cdef class Field(PrincipalIdealDomain):
    """
    Generic field
    """
    def base_ring(self):
        """
        Return the base ring of this field.  This is the prime
        subfield of this field.
        """
        p = self.characteristic()
        if p == 0:
            return sage.rings.rational_field.Q
        return sage.rings.finite_field.GF(p)

    def category(self):
        from sage.categories.all import Fields
        return Fields()

    def fraction_field(self):
        """
        Return the fraction field of self.
        """
        return self

    def divides(self, x, y, coerce=True):
        """
        Return True if x divides y in this field (usually True in a
        field!).  If coerce is True (the default), first coerce x and
        y into self.
        """
        if coerce:
            x = self(x)
            y = self(y)
        if x.is_zero():
            return y.is_zero()
        return True

    def ideal(self, gens):
        """
        Return the ideal generated by gens.
        """
        if not isinstance(gens, (list, tuple)):
            gens = [gens]
        for x in gens:
            if not self(x).is_zero():
                return self.unit_ideal()
        return self.zero_ideal()

    def integral_closure(self):
        """
        Return this field, since fields are integrally closed in their
        fraction field.
        """
        return self

    def is_field(self):
        """
        Return True since this is a field.
        """
        return True

    def is_integrally_closed(self):
        """
        Return True since fields are integrally closed in their
        fraction field.
        """
        return True

    def is_noetherian(self):
        """
        Return True since fields are noetherian rings.
        """
        return True

    def krull_dimension(self):
        """
        Return the Krull dimension of this field, which is 0.
        """
        return 0

    def prime_subfield(self):
        """
        Return the prime subfield of self.

        EXAMPLES:
            sage: k = GF(9)
            sage: k.prime_subfield()
            Finite Field of size 3
        """
        if self.characteristic() == 0:
            import sage.rings.rational_field
            return sage.rings.rational_field.RationalField()
        else:
            import sage.rings.finite_field
            return sage.rings.finite_field.FiniteField(self.characteristic())

cdef class Algebra(Ring):
    """
    Generic algebra
    """
    def __init__(self, base_ring):
        self.__base_ring = base_ring

    def base_ring(self):
        """
        Return the base ring of this algebra.  This is part of the
        structure of being an algebra.
        """
        return self.__base_ring

    def characteristic(self):
        """
        Return the characteristic of this algebra, which is the same
        as the characteristic of its base ring.
        """
        return self.base_ring().characteristic()

cdef class CommutativeAlgebra(Algebra):
    """
    Generic algebra
    """
    def __init__(self, base_ring):
        Algebra.__init__(self, base_ring)

    def base_ring(self):
        """
        Return the base ring of this commutative algebra.
        """
        return self.__base_ring

    def is_commutative(self):
        """
        Return True since this algebra is commutative.
        """
        return True
