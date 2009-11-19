r"""
ModulesWithBasis
"""
#*****************************************************************************
#  Copyright (C) 2008 Teresa Gomez-Diaz (CNRS) <Teresa.Gomez-Diaz@univ-mlv.fr>
#                2008-2009 Nicolas M. Thiery <nthiery at users.sf.net>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#                  http://www.gnu.org/licenses/
#******************************************************************************

from sage.categories.all import Modules, Rings, Fields, VectorSpaces, HomCategory, Homset, CategoryWithCartesianProduct, CartesianProductCategory, CategoryWithTensorProduct, TensorCategory
from category_types import Category_over_base_ring
from sage.misc.lazy_attribute import lazy_attribute
from sage.misc.cachefunc import cached_method
from sage.structure.element import ModuleElement
from sage.categories.morphism import SetMorphism, Morphism
from sage.categories.homset import Hom
from sage.structure.element import parent

class ModulesWithBasis(Category_over_base_ring, CategoryWithCartesianProduct, CategoryWithTensorProduct): #, DualityCategory):
    """
    The category of modules with a distinguished basis

    The elements are represented by expanding them in the distinguished basis.
    The morphisms are not required to respect the distinguished basis.

    EXAMPLES::

        sage: ModulesWithBasis(ZZ)
        Category of modules with basis over Integer Ring
        sage: ModulesWithBasis(ZZ).super_categories()
        [Category of modules over Integer Ring]

    If the base ring is actually a field, this is a subcategory of
    the category of abstract vector fields::

        sage: ModulesWithBasis(RationalField()).super_categories()
        [Category of vector spaces over Rational Field]

    Let `X` and `Y` be two modules with basis. We can build `Hom(X,Y)`::

        sage: X = CombinatorialFreeModule(QQ, [1,2]); X.__custom_name = "X"
        sage: Y = CombinatorialFreeModule(QQ, [3,4]); Y.__custom_name = "Y"
        sage: H = Hom(X, Y); H
        Set of Morphisms from X to Y in Category of modules with basis over Rational Field

    The simplest morphism is the zero map::

        sage: H.zero()         # todo: move this test into module once we have an example
        Generic morphism:
          From: X
          To:   Y

    which we can apply to elements of X::

        sage: x = X.term(1) + 3 * X.term(2)
        sage: H.zero()(x)
        0

    TESTS::

        sage: f = H.zero().on_basis()
        sage: f(1)
        0
        sage: f(2)
        0

    EXAMPLES:

    We now construct a more interesting morphism by extending a
    function by linearity::

        sage: phi = H(on_basis = lambda i: Y.term(i+2)); phi
        Generic morphism:
          From: X
          To:   Y
        sage: phi(x)
        B[3] + 3*B[4]

    We can retrieve the function acting on indices of the basis::

        sage: f = phi.on_basis()
        sage: f(1), f(2)
        (B[3], B[4])

    `Hom(X,Y)` has a natural module structure (except for the zero,
    the operations are not yet implemented though). However since the
    dimension is not necessarily finite, it is not a module with
    basis; but see FiniteDimensionalModulesWithBasis and
    GradedModulesWithBasis::

        sage: H in ModulesWithBasis(QQ), H in Modules(QQ)
        (False, True)

    Some more playing around with categories and higher order homsets::

        sage: H.category()
        Category of hom sets in Category of modules with basis over Rational Field
        sage: Hom(H, H).category()
        Category of hom sets in Category of modules over Rational Field

    # TODO: End(X) is an algebra

    TESTS::

        sage: TestSuite(ModulesWithBasis(ZZ)).run()
    """

    @cached_method
    def super_categories(self):
        """
        EXAMPLES::

            sage: ModulesWithBasis(QQ).super_categories()
            [Category of vector spaces over Rational Field]
            sage: ModulesWithBasis(ZZ).super_categories()
            [Category of modules over Integer Ring]
        """
        R = self.base_ring()
        if R in Fields():
            return [VectorSpaces(R)]
        else:
            return [Modules(R)]

    def _call_(self, x):
        """
        Construct a module with basis from the data in ``x``

        EXAMPLES::

            sage: C = ModulesWithBasis(QQ)

        ``x`` is returned unchanged if it is readilly in this category::

            sage: C(CombinatorialFreeModule(QQ, ('a','b','c')))
            Free module generated by {'a', 'b', 'c'} over Rational Field
            sage: C(QQ^3)
            Vector space of dimension 3 over Rational Field

        If needed (and possible) the base ring is changed appropriately::

            sage: C(ZZ^3)                       # indirect doctest
            Vector space of dimension 3 over Rational Field

        If ``x`` itself is not a module with basis, but there is a
        canonical one associated to it, the later is returned::

            sage: C(AbelianVariety(Gamma0(37))) # indirect doctest
            Vector space of dimension 4 over Rational Field
        """
        try:
            M = x.free_module()
            if M.base_ring() != self.base_ring():
                M = M.change_ring(self.base_ring())
        except (TypeError, AttributeError), msg:
            raise TypeError, "%s\nunable to coerce x (=%s) into %s"%(msg,x,self)
        return M

    def is_abelian(self):
        """
        Returns whether this category is abelian

        This is the case if and only if the base ring is a field.

        EXAMPLES::

            sage: ModulesWithBasis(QQ).is_abelian()
            True
            sage: ModulesWithBasis(ZZ).is_abelian()
            False
        """
        return self.base_ring().is_field()

    # TODO: find something better to get this inheritance from CategoryWithTensorProduct.Element
    class ParentMethods(CategoryWithTensorProduct.ParentMethods, CategoryWithCartesianProduct.ParentMethods):
        def module_morphism(self, on_basis = None, diagonal = None,  **keywords):
            """
            Constructs functions by linearity

            INPUT:
             - self: a parent `X` in ModulesWithBasis(R), with basis `x` indexed by `I`
             - codomain: the codomain `Y` of f: defaults to `f.codomain if the later is defined
             - zero: the zero of the codomain; defaults to codomain.zero() or 0 if codomain is not specified
             - position: a non negative integer; defaults to 0
             - on_basis: a function `f` which accepts elements of `I`
               as position-th argument and returns  elements of `Y`
             - diagonal: a function `d` from `I` to `R`
             - category: a category. By default, this is
               ``ModulesWithBasis(R)`` if `Y` is in this category, and
               otherwise this lets `Hom(X,Y)` decide

            Exactly one of ``on_basis`` and ``diagonal`` options should be specified.

            With the ``on_basis`` option, this returns a function `g`
            obtained by extending `f` by linearity on the position-th
            positional argument. For example, for position == 1 and a
            ternary function `f`, and denoting by x_i the basis of
            `X`, one has:

                `g(a, \sum \lambda_i x_i, c) = \sum \lambda_i f(a, i, c)`

            EXAMPLES::

                sage: X = CombinatorialFreeModule(QQ, [1,2,3]);   X.rename("X")
                sage: Y = CombinatorialFreeModule(QQ, [1,2,3,4]); Y.rename("Y")
                sage: phi = X.module_morphism(lambda i: Y.term(i) + 2*Y.term(i+1), codomain = Y)
                sage: phi
                Generic morphism:
                From: X
                To:   Y
                sage: x = X.basis()
                sage: phi(x[1] + x[3])
                B[1] + 2*B[2] + B[3] + 2*B[4]

            With the ``diagonal`` argument, this returns the module morphism `g` such that:

                `g(x_i) = d(i) y_i`

            This assumes that the respective bases `x` and `y` of `X`
            and `Y` have the same index set `I`.

            Caveat: the returned element is in ``Hom(codomain, domain,
            category``). This is only correct for unary functions.

            Todo: should codomain be self by default in the diagonal case?

            """
            if diagonal is not None:
                return DiagonalModuleMorphism(diagonal = diagonal, domain = self, **keywords)
            elif on_basis is not None:
                return ModuleMorphismByLinearity(on_basis = on_basis, domain = self, **keywords)
            else:
                raise ValueError("module morphism requires either on_basis or diagonal argument")

        _module_morphism = module_morphism

    # TODO: find something better to get this inheritance from CategoryWithTensorProduct.Element
    class ElementMethods(CategoryWithTensorProduct.ElementMethods, CategoryWithCartesianProduct.ElementMethods):
        pass

#         def _neg_(self):
#             """
#             Default implementation of negation by trying to multiply by -1.
#             """
#             return self._lmul_(-self.parent().base_ring().one(), self)

    class HomCategory(HomCategory):
        """
        The category of homomorphisms sets Hom(X,Y) for X, Y modules with basis
        """

        class ParentMethods: #(sage.modules.free_module_homspace.FreeModuleHomspace): #    Only works for plain FreeModule's
            """
            Abstract class for hom sets
            """

            def __call__(self, on_basis = None, *args, **options):
                """
                Construct an element of this homset

                INPUT:

                 - on_basis (optional) -- a function from the indices
                   of the basis of the domain of ``self`` to the
                   codomain of ``self``

                EXAMPLES::

                    sage: X = CombinatorialFreeModule(QQ, [1,2,3]);   X.rename("X")
                    sage: Y = CombinatorialFreeModule(QQ, [1,2,3,4]); Y.rename("Y")
                    sage: H = Hom(X, Y)
                    sage: x = X.basis()

                As for usual homsets, the argument can be a Python function::

                    sage: phi = H(lambda x: Y.zero())
                    sage: phi
                    Generic morphism:
                      From: X
                      To:   Y
                    sage: phi(x[1] + x[3])
                    0

                With the on_basis argument, the function can instead
                be constructed by extending by linearity a function on
                the basis::

                    sage: phi = H(on_basis = lambda i: Y.term(i) + 2*Y.term(i+1))
                    sage: phi
                    Generic morphism:
                    From: X
                    To:   Y
                    sage: phi(x[1] + x[3])
                    B[1] + 2*B[2] + B[3] + 2*B[4]

                This is achieved internaly by using
                :meth:`ModulesWithBasis.ParentMethods.module_morphism`, which see.
                """
                if on_basis is not None:
                    args = (self.domain().module_morphism(on_basis, codomain = self.codomain()),) + args
                h = Homset.__call__(self, *args, **options)
                if on_basis is not None:
                    h._on_basis = on_basis
                return h

            # Temporary hack
            __call_on_basis__ = __call__

            @lazy_attribute
            def element_class_set_morphism(self):
                """
                A base class for elements of this homset which are
                also SetMorphism's, i.e. implemented by mean of a
                Python function.

                This overrides the default implementation
                :meth:`Homset.element_class_set_morphism`, to also
                inherit from categories.

                Todo: refactor during the upcoming homset cleanup.

                EXAMPLES::

                    sage: X = CombinatorialFreeModule(QQ, [1,2,3]);   X.rename("X")
                    sage: Y = CombinatorialFreeModule(QQ, [1,2,3,4]); Y.rename("Y")
                    sage: H = Hom(X, Y)
                    sage: H.element_class_set_morphism
                    <class 'sage.categories.morphism.SetMorphism_with_category'>
                    sage: H.element_class_set_morphism.mro()
                    [<class 'sage.categories.morphism.SetMorphism_with_category'>,
                     <type 'sage.categories.morphism.SetMorphism'>,
                     <type 'sage.categories.morphism.Morphism'>,
                     <type 'sage.categories.map.Map'>,
                     <type 'sage.structure.element.Element'>,
                     <type 'sage.structure.sage_object.SageObject'>,
                     <class 'sage.categories.modules_with_basis.ModulesWithBasis.HomCategory.element_class'>,
                     <class 'sage.categories.category.Modules.HomCategory.element_class'>,
                     <class 'sage.categories.modules.Modules.element_class'>,
                     ...]

                Compare with:

                    sage: H = Hom(ZZ, ZZ)
                    sage: H.element_class_set_morphism
                    <type 'sage.categories.morphism.SetMorphism'>
                """
                return self.__make_element_class__(SetMorphism, inherit = True)

        class ElementMethods:
            """
            Abstract class for morphisms of modules with basis
            """
            def on_basis(self):
                """
                Returns the action of this morphism on basis elements

                OUTPUT:

                - a function from the indices of the basis of the domain to the codomain.

                EXAMPLES::

                    sage: X = CombinatorialFreeModule(QQ, [1,2,3]);   X.rename("X")
                    sage: Y = CombinatorialFreeModule(QQ, [1,2,3,4]); Y.rename("Y")
                    sage: H = Hom(X, Y)
                    sage: x = X.basis()

                    sage: f = H(lambda x: Y.zero()).on_basis()
                    sage: f(2)
                    0

                    sage: f = lambda i: Y.term(i) + 2*Y.term(i+1)
                    sage: g = H(on_basis = f).on_basis()
                    sage: g(2)
                    B[2] + 2*B[3]
                    sage: g == f
                    True
                """
                if not hasattr(self, "_on_basis"):
                    term = self.domain().term
                    self._on_basis = lambda t: self(term(t))
                return self._on_basis

    class CartesianProductCategory(CartesianProductCategory):
        """
        The category of modules with basis constructed by cartesian products of modules with basis
        """
        @cached_method
        def super_categories(self):
            """
            EXAMPLES::

                sage: ModulesWithBasis(QQ).cartesian_product_category().super_categories()
                [Category of modules with basis over Rational Field]
            """
            return [ModulesWithBasis(self.base_category.base_ring())]

        class ParentMethods:

            def _an_element_(self):
                """
                EXAMPLES::

                    sage: A = AlgebrasWithBasis(QQ).example(); A
                    An example of an algebra with basis: the free algebra on the generators ('a', 'b', 'c') over Rational Field
                    sage: B = HopfAlgebrasWithBasis(QQ).example(); A
                    An example of an algebra with basis: the free algebra on the generators ('a', 'b', 'c') over Rational Field
                    sage: A.an_element(), B.an_element()
                    (B[word: ] + 2*B[word: a] + 3*B[word: b], B[()] + 2*B[(2,3)] + 3*B[(1,2)] + B[(1,2,3)])
                    sage: cartesian_product((A, B, A)).an_element()           # indirect doctest
                    2*B[(0, word: )] + 2*B[(0, word: a)] + 3*B[(0, word: b)]
                """
                from cartesian_product import cartesian_product
                return cartesian_product([module.an_element() for module in self.modules])

    class TensorCategory(TensorCategory):
        """
        The category of modules with basis constructed by tensor product of modules with basis
        """
        @cached_method
        def super_categories(self):
            """
            EXAMPLES::

                sage: ModulesWithBasis(QQ).tensor_category().super_categories()
                [Category of modules with basis over Rational Field]
            """
            return [ModulesWithBasis(self.base_category.base_ring())]

        class ParentMethods:
            """
            implements operations on tensor products of modules with basis
            """
            pass

        class ElementMethods:
            """
            implements operations on elements of tensor products of Hopf algebras
            """
            pass

class ModuleMorphismByLinearity(Morphism):
    """
    A class for module morphisms obtained by extending a function by linearity
    """
    def __init__(self, domain, on_basis = None, position = 0, zero = None, codomain = None, category = None):
        """
        Constructs a module morphism by linearity

        INPUT:

         - ``domain`` -- a parent in ModulesWithBasis(...)
         - ``codomain`` -- a parent in Modules(...); defaults to f.codomain() if the later is defined
         - ``position`` -- a non negative integer; defaults to 0
         - ``on_basis`` -- a function which accepts indices of the basis of domain as position-th argument (optional)
         - ``zero`` -- the zero of the codomain; defaults to codomain.zero() or 0 if codomain is not specified

        on_basis may alternatively be provided in derived classes by implementing or setting _on_basis.

        EXAMPLES::

            sage: X = CombinatorialFreeModule(ZZ, [-2, -1, 1, 2])
            sage: Y = CombinatorialFreeModule(ZZ, [1, 2])
            sage: phi = sage.categories.modules_with_basis.ModuleMorphismByLinearity(X, on_basis = Y.term * abs)

        TESTS::

            sage: TestSuite(phi).run()
        """
        if codomain is None and hasattr(on_basis, 'codomain'):
            codomain = on_basis.codomain()
        if zero is None:
            if codomain is not None:
                zero = codomain.zero()
            else:
                zero = 0
        if category is None and codomain is not None and codomain.category().is_subcategory(ModulesWithBasis(domain.base_ring())):
            category = ModulesWithBasis(domain.base_ring())
        assert codomain is not None
        Morphism.__init__(self, Hom(domain, codomain, category = category))
        self._zero = zero
        self._position = position
        if on_basis is not None:
            self._on_basis = on_basis

    def __eq__(self, other):
        """
        EXAMPLES::

            sage: X = CombinatorialFreeModule(ZZ, [-2, -1, 1, 2])
            sage: Y = CombinatorialFreeModule(ZZ, [1, 2])
            sage: f  = X.module_morphism(on_basis = Y.term * abs)
            sage: g  = X.module_morphism(on_basis = Y.term * abs)
            sage: h1 = X.module_morphism(on_basis = X.term * abs)
            sage: h2 = X.module_morphism(on_basis = X.term * factorial)
            sage: h3 = X.module_morphism(on_basis = Y.term * abs, category = Modules(ZZ))
            sage: f == g, f == h1, f == h2, f == h3, f == 1, 1 == f
            (True, False, False, False, False, False)
        """
        return self.__class__ is other.__class__ and parent(self) == parent(other) and self.__dict__ == other.__dict__

    def on_basis(self):
        """
        Returns the action of this morphism on basis elements, as per
        :meth:`ModulesWithBasis.HomCategory.ElementMethods.on_basis`.

        OUTPUT:

        - a function from the indices of the basis of the domain to the codomain.

        EXAMPLES::

            sage: X = CombinatorialFreeModule(ZZ, [-2, -1, 1, 2])
            sage: Y = CombinatorialFreeModule(ZZ, [1, 2])
            sage: phi_on_basis = Y.term * abs
            sage: phi = sage.categories.modules_with_basis.ModuleMorphismByLinearity(X, on_basis = phi_on_basis, codomain = Y)
            sage: x = X.basis()
            sage: phi.on_basis()(-2)
            B[2]
            sage: phi.on_basis() == phi_on_basis
            True

        Note: could probably be inherited from the categories
        """
        return self._on_basis

    def __call__(self, *args):
        """
        Apply this morphism

        EXAMPLES::

            sage: X = CombinatorialFreeModule(ZZ, [-2, -1, 1, 2])
            sage: Y = CombinatorialFreeModule(ZZ, [1, 2])
            sage: def phi_on_basis(i): return Y.term(abs(i))
            sage: phi = sage.categories.modules_with_basis.ModuleMorphismByLinearity(X, on_basis = Y.term * abs, codomain = Y)
            sage: x = X.basis()
            sage: phi(x[1]), phi(x[-2]), phi(x[1] + 3 * x[-2])
            (B[1], B[2], B[1] + 3*B[2])

        Todo: add more tests for multi-parameter module morphisms.
        """
        before = args[0:self._position]
        after = args[self._position+1:len(args)]
        x = args[self._position]
        assert(x.parent() is self.domain())
        return sum([self._on_basis(*(before+(index,)+after))._lmul_(coeff) for (index, coeff) in args[self._position]], self._zero)

    # As per the specs of Map, we should in fact implement _call_.
    # However we currently need to abuse Map.__call__ (which strict
    # type checking) for multi-parameter module morphisms
    # To be cleaned up
    _call_ = __call__

class DiagonalModuleMorphism(ModuleMorphismByLinearity):
    """
    A class for diagonal module morphisms.

    See :meth:`module_morphism` of ModulesWithBasis

    Todo:

     - implement an optimized _call_ function
     - generalize to a mapcoeffs
     - generalize to a mapterms
    """

    def __init__(self, diagonal, domain, codomain = None, category = None):
        """
        INPUT:
         - domain, codomain: two modules with basis `F` and `G`
         - diagonal: a function `d`

        Assumptions:
         - `F` and `G` have the same base ring `R`
         - Their respective bases `f` and `g` have the same index set `I`
         - `d` is a function `I\mapsto R`

        Returns the diagonal module morphism from F to G which maps
        `f_\lambda` to `d(\lambda) g_\lambda`.

        By default, codomain is currently assumed to be domain
        (Todo: make a consistent choice with ModuleMorphism)

        EXAMPLES::

            sage: X = CombinatorialFreeModule(QQ, [1, 2, 3]); X.rename("X")
            sage: phi = X.module_morphism(diagonal = factorial, codomain = X)
            sage: x = X.basis()
            sage: phi(x[1]), phi(x[2]), phi(x[3])
            (B[1], 2*B[2], 6*B[3])

        TESTS::

            sage: phi.__class__
            <class 'sage.categories.modules_with_basis.DiagonalModuleMorphism'>
            sage: TestSuite(phi).run()
        """
        assert codomain is not None
        assert domain.basis().keys() == codomain.basis().keys()
        assert domain.base_ring()    == codomain.base_ring()
        if category is None:
            category = ModulesWithBasis(domain.base_ring())
        ModuleMorphismByLinearity.__init__(self, domain = domain, codomain = codomain, category = category)
        self._diagonal = diagonal

    def _on_basis(self, i):
        """
        Returns the image by self of the basis element indexed by i

        TESTS::

            sage: X = CombinatorialFreeModule(QQ, [1, 2, 3]); X.rename("X"); x = X.basis()
            sage: Y = CombinatorialFreeModule(QQ, [1, 2, 3]); X.rename("Y"); y = Y.basis()
            sage: phi = X.module_morphism(diagonal = factorial, codomain = X)
            sage: phi._on_basis(3)
            6*B[3]
        """
        return self.codomain().monomial(i, self._diagonal(i))

    def __invert__(self):
        """
        Returns the inverse diagonal morphism

        EXAMPLES::

            sage: X = CombinatorialFreeModule(QQ, [1, 2, 3]); X.rename("X"); x = X.basis()
            sage: Y = CombinatorialFreeModule(QQ, [1, 2, 3]); X.rename("Y"); y = Y.basis()
            sage: phi = X.module_morphism(diagonal = factorial, codomain = X)
            sage: phi_inv = ~phi
            sage: phi_inv
            Generic endomorphism of Y
            sage: phi_inv(y[3])
            1/6*B[3]

        Caveat: this inverse morphism is only well defined if
        `d(\lambda)` is always invertible in the base ring. This is
        condition is *not* tested for, so using an ill defined inverse
        morphism will trigger arithmetic errors.
        """
        return self.__class__(
            pointwise_inverse_function(self._diagonal),
            domain = self.codomain(), codomain = self.domain(), category = self.category_for())

def pointwise_inverse_function(f):
    """
    INPUT:
     - f: a function

    Returns the function (...) -> 1 / f(...)

    EXAMPLES:
        sage: from sage.categories.modules_with_basis import pointwise_inverse_function
        sage: def f(x): return x
        ...
        sage: g = pointwise_inverse_function(f)
        sage: g(1), g(2), g(3)
        (1, 1/2, 1/3)

    pointwise_inverse_function is an involution:

        sage: f is pointwise_inverse_function(g)
        True

    Todo: this has nothing to do here!!! Should there be a library for
    pointwise operations on functions somewhere in Sage?

    """
    if hasattr(f, "pointwise_inverse"):
        return f.pointwise_inverse()
    else:
        return PointwiseInverseFunction(f)

from sage.structure.sage_object import SageObject
class PointwiseInverseFunction(SageObject):
    """
    A class for point wise inverse functions

    EXAMPLES:
        sage: from sage.categories.modules_with_basis import PointwiseInverseFunction
        sage: f = PointwiseInverseFunction(factorial)
        sage: f(0), f(1), f(2), f(3)
        (1, 1, 1/2, 1/6)
    """

    def __eq__(self, other):
        """
        TESTS:
            sage: from sage.categories.modules_with_basis import PointwiseInverseFunction
            sage: f = PointwiseInverseFunction(factorial)
            sage: g = PointwiseInverseFunction(factorial)
            sage: f is g
            False
            sage: f == g
            True
        """
        return self.__class__ is other.__class__ and self.__dict__ == other.__dict__

    def __init__(self, f):
        """
        TESTS::

            sage: from sage.categories.modules_with_basis import PointwiseInverseFunction
            sage: f = PointwiseInverseFunction(factorial)
            sage: f(0), f(1), f(2), f(3)
            (1, 1, 1/2, 1/6)
            sage: loads(dumps(f)) == f
            True
        """
        self._pointwise_inverse = f

    def __call__(self, *args):
        """
        TESTS:
            sage: from sage.categories.modules_with_basis import PointwiseInverseFunction
            sage: g = PointwiseInverseFunction(operator.mul)
            sage: g(5,7)
            1/35
        """
        return ~(self._pointwise_inverse(*args))

    def pointwise_inverse(self):
        """
        TESTS:
            sage: from sage.categories.modules_with_basis import PointwiseInverseFunction
            sage: g = PointwiseInverseFunction(operator.mul)
            sage: g.pointwise_inverse() is operator.mul
            True
        """
        return self._pointwise_inverse
