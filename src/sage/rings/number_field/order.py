from sage.rings.ring import DedekindDomain
from number_field_element import NumberFieldElement
from sage.structure.sequence import Sequence
from sage.rings.integer_ring import ZZ

class Order(DedekindDomain):

    def __init__(self, K):
        self._K = K

    def number_field(self):
        return self._K

    def fraction_field(self):
        return self._K

    def __eq__(left, right):
        if not isinstance(left, Order) or not isinstance(right, Order):
            if left == ZZ:
                return right.absolute_order()._module_rep.dimension() == 1
            elif right == ZZ:
                return left.absolute_order()._module_rep.dimension() == 1
            return False
        left = left.absolute_order()
        right = right.absolute_order()
        return left._K == right._K and left._module_rep == right._module_rep

class AbsoluteOrder(Order):

    def __init__(self, K, module_rep, check=True):
        """
        EXAMPLES:
            sage: from sage.rings.number_field.order import *
            sage: x = polygen(QQ)
            sage: K.<a> = NumberField(x^3+2)
            sage: V, from_v, to_v = K.vector_space()
            sage: M = span(ZZ, [to_v(a), to_v(1)])
            sage: O = AbsoluteOrder(K, M); O
            Order in Number Field in a with defining polynomial x^3 + 2 generated by 1, a

            sage: M = span(ZZ, [to_v(a), to_v(2)])
            sage: O = AbsoluteOrder(K, M); O
            Traceback (most recent call last):
            ...
            ValueError: One is not in the span of the module, hence not an order.
        """
        Order.__init__(self, K)
        self._module_rep = module_rep
        V, from_v, to_v = self._K.vector_space()
        if check:
            if not K.is_absolute():
                raise ValueError, "AbsoluteOrder must be called with an absolute number field."
            if to_v(1) not in module_rep:
                raise ValueError, "1 is not in the span of the module, hence not an order."
            if module_rep.rank() != self._K.degree():
                raise ValueError, "the module must have full rank."

    def __call__(self, x):
        if x.parent() is not self._K:
            x = self._K(x)
        V, _, embedding = self._K.vector_space()
        if not embedding(x) in self._module_rep:
            raise TypeError, "Not an element of the order."
        return NumberFieldElement(self, x)

    def __add__(left, right):
        """
        Add two orders.

        EXAMPLES:
            sage: from sage.rings.number_field.order import *
            sage: K.<a> = NumberField(x^3+2)
            sage: V, from_v, to_v = K.vector_space()
            sage: M = span(ZZ, [to_v(a), to_v(1)])
            sage: O = AbsoluteOrder(K, M); O
            Order in Number Field in a with defining polynomial x^3 + 2 generated by 1, a
            sage: M = span(ZZ, [to_v(a^2), to_v(1)])
            sage: O2 = AbsoluteOrder(K, M); O2
            Order in Number Field in a with defining polynomial x^3 + 2 generated by 1, a^2
            sage: O+O2
            Order in Number Field in a with defining polynomial x^3 + 2 generated by 1, a, a^2
        """
        if not isinstance(left, AbsoluteOrder) or not isinstance(right, AbsoluteOrder):
            raise NotImplementedError
        if left.number_field() != right.number_field():
            raise TypeError, "Number fields don't match."
        return AbsoluteOrder(left._K, left._module_rep + right._module_rep, False)

    def __and__(left, right):
        """
        Intersect orders.

        EXAMPLES:
            sage: from sage.rings.number_field.order import *
            sage: K.<a> = NumberField(x^3+2)
            sage: V, from_v, to_v = K.vector_space()
            sage: M = span(ZZ, [to_v(a), to_v(1)])
            sage: O = AbsoluteOrder(K, M); O
            Order in Number Field in a with defining polynomial x^3 + 2 generated by 1, a
            sage: M = span(ZZ, [to_v(a^2), to_v(1)])
            sage: O2 = AbsoluteOrder(K, M); O2
            Order in Number Field in a with defining polynomial x^3 + 2 generated by 1, a^2
            sage: O & O2
            Order in Number Field in a with defining polynomial x^3 + 2 generated by 1
            sage: O & O2 == ZZ
            True
        """
        if not isinstance(left, AbsoluteOrder) or not isinstance(right, AbsoluteOrder):
            raise NotImplementedError
        if left.number_field() != right.number_field():
            raise TypeError, "Number fields don't match."
        return AbsoluteOrder(left._K, left._module_rep.intersection(right._module_rep), False)

    def intersection(self, other):
        return self & other

    def __repr__(self):
        return "Order in %r generated by %s" % (self._K, ", ".join([str(b) for b in self.basis()]))

    def basis(self):
        V, from_V, to_V = self._K.vector_space()
        return [from_V(b) for b in self._module_rep.basis()]

    def absolute_order(self):
        return self

class RelativeOrder(Order):

    def __init__(self, K, absolute_order, base, embedding, check=True):
        Order.__init__(self, K)
        self._absolute_order = absolute_order
        self._base = base
        self._embedding = embedding

    def __call__(self, x):
        if x.parent() is not self._K:
            x = self._K(x)
        x = self._absolute_order(x) # will test membership
        return NumberFieldElement(self, x)

    def __repr__(self, x):
        V, to_V, from_V = self._K.vector_space()
        basis = self._module_rep.basis()
        return "Order over %r spanned by %r" % (self._base, ",".join([from_V(b) for b in self._absolute_order.basis()]))

    def absolute_order(self):
        return self._absolute_order

def each_is_integral(v):
    """
    Return True if each element of the list v of elements
    of a number field is integral.
    """
    for x in v:
        if not x.is_integral():
            return False
    return True

def absolute_order_from_ring_generators(gens, check=True):
    """
    INPUT:
        gens -- list of integral elements of an absolute order.
        check -- bool (default: True) whether to check that the
                 generators are integral.
    """
    if not each_is_integral(gens):
        raise ValueError, "each generator must be integral"
    gens = Sequence(gens)
    K = gens.universe()
    n = K.degree()

    module_gens = []

def absolute_order_from_module_generators(gens, check=True):
    """
    INPUT:
        gens -- list of elements of an absolute number field
                that generates an order in that number field as a ZZ
                *module*.
        check -- bool (default: True) check that these are really
                module generators.

    OUTPUT:
        an absolute order

    EXAMPLES:
        sage: ???
    """
    if len(gens) == 0:
        raise ValueError, "gens must span an order over ZZ"
    gens = Sequence(gens)
    K = gens.universe()
    V, _, to_V = K.vector_space()
    gens = [to_V(x) for x in gens]
    W = V.span(gens)
    return AbsoluteOrder(K, W)
