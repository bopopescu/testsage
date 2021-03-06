r"""
Weyl Groups
"""
#*****************************************************************************
#  Copyright (C) 2009    Nicolas M. Thiery <nthiery at users.sf.net>
#
#  Distributed under the terms of the GNU General Public License (GPL)
#                  http://www.gnu.org/licenses/
#******************************************************************************

from sage.misc.cachefunc import cached_method, cached_in_parent_method
from sage.categories.category_singleton import Category_singleton
from sage.categories.coxeter_groups import CoxeterGroups
from sage.rings.infinity import infinity
from sage.rings.rational_field import QQ

class WeylGroups(Category_singleton):
    r"""
    The category of Weyl groups

    See: http://en.wikipedia.org/wiki/Weyl_groups

    EXAMPLES::

        sage: WeylGroups()                      # todo: uppercase for Weyl
        Category of weyl groups
        sage: WeylGroups().super_categories()
        [Category of coxeter groups]

    Here are some examples::

        sage: WeylGroups().example()            # todo: not implemented
        sage: FiniteWeylGroups().example()
        The symmetric group on {0, ..., 3}
        sage: AffineWeylGroups().example()      # todo: not implemented
        sage: WeylGroup(["B", 3])
        Weyl Group of type ['B', 3] (as a matrix group acting on the ambient space)

    This one will eventually be also in this category::

        sage: SymmetricGroup(4)
        Symmetric group of order 4! as a permutation group

    TESTS::

        sage: C = WeylGroups()
        sage: TestSuite(C).run()
    """

    def super_categories(self):
        r"""
        EXAMPLES::

            sage: WeylGroups().super_categories()
            [Category of coxeter groups]
        """
        return [CoxeterGroups()]

    class ParentMethods:

        def pieri_factors(self, *args, **keywords):
            r"""
            Returns the set of Pieri factors in this Weyl group.

            For any type, the set of Pieri factors forms a lower ideal
            in Bruhat order, generated by all the conjugates of some
            special element of the Weyl group. In type `A_n`, this
            special element is `s_n\cdots s_1`, and the conjugates are
            obtained by rotating around this reduced word.

            These are used to compute Stanley symmetric functions.

            See also:

             * :meth:WeylGroups.ElementMethods.stanley_symmetric_function`
             * :mod:`sage.combinat.root_system.pieri_factors`

            EXAMPLES::

                sage: W = WeylGroup(['A',5,1])
                sage: PF = W.pieri_factors()
                sage: PF.cardinality()
                63

                sage: W = WeylGroup(['B',3])
                sage: PF = W.pieri_factors()
                sage: [w.reduced_word() for w in PF]
                [[1, 2, 3, 2, 1], [1, 2, 3, 2], [2, 3, 2], [2, 3], [3, 1, 2, 1], [1, 2, 1], [2], [1, 2], [1], [], [2, 1], [3, 2, 1], [3, 1], [2, 3, 2, 1], [3], [3, 2], [1, 2, 3], [1, 2, 3, 1], [3, 1, 2], [2, 3, 1]]

                sage: W = WeylGroup(['C',4,1])
                sage: PF = W.pieri_factors()
                sage: W.from_reduced_word([3,2,0]) in PF
                True
            """
            # Do not remove this line which makes sure the pieri factor
            # code is properly inserted inside the cartan types
            import sage.combinat.root_system.pieri_factors
            ct = self.cartan_type()
            if hasattr(ct, "PieriFactors"):
                return ct.PieriFactors(self, *args, **keywords)
            else:
                raise NotImplementedError("Pieri factors for type %s"%ct)

        def quantum_bruhat_graph(self, index_set = None):
            r"""
            Returns the quantum Bruhat graph of the quotient of the Weyl group by a parabolic subgroup.

            INPUT:

            - ``index_set`` -- (default: None) indicates the set of simple reflections used to generate the parabolic subgroup;
               the default value indicates that the subgroup is trivial and the quotient is the Weyl group

            EXAMPLES::

                sage: W = WeylGroup(['A',3], prefix="s")
                sage: g = W.quantum_bruhat_graph([1,3])
                sage: g
                Parabolic Quantum Bruhat Graph of Weyl Group of type ['A', 3] (as a matrix group acting on the ambient space) for nodes [1, 3]: Digraph on 6 vertices
                sage: g.vertices()
                [s2*s3*s1*s2, s3*s1*s2, s1*s2, s3*s2, s2, 1]
                sage: g.edges()
                [(s2*s3*s1*s2, s2, alpha[2]), (s3*s1*s2, s2*s3*s1*s2, alpha[1] + alpha[2] + alpha[3]),
                (s3*s1*s2, 1, alpha[2]), (s1*s2, s3*s1*s2, alpha[2] + alpha[3]),
                (s3*s2, s3*s1*s2, alpha[1] + alpha[2]), (s2, s1*s2, alpha[1] + alpha[2]),
                (s2, s3*s2, alpha[2] + alpha[3]), (1, s2, alpha[2])]
                sage: W = WeylGroup(['A',3,1], prefix="s")
                sage: g = W.quantum_bruhat_graph()
                Traceback (most recent call last):
                ...
                ValueError: The Cartan type ['A', 3, 1] is not finite
            """
            if not self.cartan_type().is_finite():
                raise ValueError, "The Cartan type %s is not finite"%(self.cartan_type())
            from sage.graphs.digraph import DiGraph
            if index_set is None:
                index_set = []
            WP = [x for x in self if x==x.coset_representative(index_set)]
            return DiGraph([[x,i[0],i[1]] for x in WP for i in x.quantum_bruhat_successors(index_set, roots = True)],
                           name="Parabolic Quantum Bruhat Graph of %s for nodes %s"%(self.__repr__(),index_set))

    class ElementMethods:

        def is_pieri_factor(self):
            r"""
            Returns whether ``self`` is a Pieri factor, as used for
            computing Stanley symmetric functions.

            See also:

             * :meth:`stanley_symmetric_function`
             * :meth:`WeylGroups.ParentMethods.pieri_factors`

            EXAMPLES::

                sage: W = WeylGroup(['A',5,1])
                sage: W.from_reduced_word([3,2,5]).is_pieri_factor()
                True
                sage: W.from_reduced_word([3,2,4,5]).is_pieri_factor()
                False

                sage: W = WeylGroup(['C',4,1])
                sage: W.from_reduced_word([0,2,1]).is_pieri_factor()
                True
                sage: W.from_reduced_word([0,2,1,0]).is_pieri_factor()
                False

                sage: W = WeylGroup(['B',3])
                sage: W.from_reduced_word([3,2,3]).is_pieri_factor()
                False
                sage: W.from_reduced_word([2,1,2]).is_pieri_factor()
                True
            """

            return self in self.parent().pieri_factors()

        def left_pieri_factorizations(self, max_length = infinity):
            r"""
            Returns all factorizations of ``self`` as `uv`, where `u`
            is a Pieri factor and `v` is an element of the Weyl group.

            See also:

             * :meth:`WeylGroups.ParentMethods.pieri_factors`
             * :mod:`sage.combinat.root_system.pieri_factors`

            EXAMPLES:

            If we take `w = w_0` the maximal element of a strict parabolic
            subgroup of type `A_{n_1} \times \cdots \times A_{n_k}`, then the Pieri
            factorizations are in correspondence with all Pieri factors, and
            there are `\prod 2^{n_i}` of them::

                sage: W = WeylGroup(['A', 4, 1])
                sage: W.from_reduced_word([]).left_pieri_factorizations().cardinality()
                1
                sage: W.from_reduced_word([1]).left_pieri_factorizations().cardinality()
                2
                sage: W.from_reduced_word([1,2,1]).left_pieri_factorizations().cardinality()
                4
                sage: W.from_reduced_word([1,2,3,1,2,1]).left_pieri_factorizations().cardinality()
                8

                sage: W.from_reduced_word([1,3]).left_pieri_factorizations().cardinality()
                4
                sage: W.from_reduced_word([1,3,4,3]).left_pieri_factorizations().cardinality()
                8

                sage: W.from_reduced_word([2,1]).left_pieri_factorizations().cardinality()
                3
                sage: W.from_reduced_word([1,2]).left_pieri_factorizations().cardinality()
                2
                sage: [W.from_reduced_word([1,2]).left_pieri_factorizations(max_length=i).cardinality() for i in [-1, 0, 1, 2]]
                [0, 1, 2, 2]

                sage: W = WeylGroup(['C',4,1])
                sage: w = W.from_reduced_word([0,3,2,1,0])
                sage: w.left_pieri_factorizations().cardinality()
                7
                sage: [(u.reduced_word(),v.reduced_word()) for (u,v) in w.left_pieri_factorizations()]
                [([], [3, 2, 0, 1, 0]),
                ([0], [3, 2, 1, 0]),
                ([3], [2, 0, 1, 0]),
                ([3, 0], [2, 1, 0]),
                ([3, 2], [0, 1, 0]),
                ([3, 2, 0], [1, 0]),
                ([3, 2, 0, 1], [0])]

                sage: W = WeylGroup(['B',4,1])
                sage: W.from_reduced_word([0,2,1,0]).left_pieri_factorizations().cardinality()
                6
            """
            pieri_factors = self.parent().pieri_factors()
            def predicate(u):
                return u in pieri_factors and u.length() <= max_length

            return self.binary_factorizations(predicate)

        @cached_in_parent_method
        def stanley_symmetric_function_as_polynomial(self, max_length = infinity):
            r"""
            Returns a multivariate generating function for the number
            of factorizations of a Weyl group element into Pieri
            factors of decreasing length, weighted by a statistic on
            Pieri factors.

            See also:
             * :meth:stanley_symmetric_function`
             * :meth:`WeylGroups.ParentMethods.pieri_factors`
             * :mod:`sage.combinat.root_system.pieri_factors`

            INPUT:

                - ``self`` -- an element `w` of a Weyl group `W`
                - ``max_length`` -- a non negative integer or infinity (default: infinity)

            Returns the generating series for the Pieri factorizations
            `w = u_1 \cdots u_k`, where `u_i` is a Pieri factor for
            all `i`, `l(w) = \sum_{i=1}^k l(u_i)` and
            ``max_length```\geq l(u_1) \geq \dots \geq l(u_k)`.

            A factorization `u_1 \cdots u_k` contributes a monomial of
            the form `\prod_i x_{l(u_i)}`, with coefficient given by
            `\prod_i 2^{c(u_i)}`, where `c` is a type-dependent
            statistic on Pieri factors, as returned by the method
            ``u[i].stanley_symm_poly_weight()``.

            EXAMPLES::

                sage: W = WeylGroup(['A', 3, 1])
                sage: W.from_reduced_word([]).stanley_symmetric_function_as_polynomial()
                1
                sage: W.from_reduced_word([1]).stanley_symmetric_function_as_polynomial()
                x1
                sage: W.from_reduced_word([1,2]).stanley_symmetric_function_as_polynomial()
                x1^2
                sage: W.from_reduced_word([2,1]).stanley_symmetric_function_as_polynomial()
                x1^2 + x2
                sage: W.from_reduced_word([1,2,1]).stanley_symmetric_function_as_polynomial()
                2*x1^3 + x1*x2
                sage: W.from_reduced_word([1,2,1,0]).stanley_symmetric_function_as_polynomial()
                3*x1^4 + 2*x1^2*x2 + x2^2 + x1*x3
                sage: W.from_reduced_word([1,2,3,1,2,1,0]).stanley_symmetric_function_as_polynomial() # long time
                22*x1^7 + 11*x1^5*x2 + 5*x1^3*x2^2 + 3*x1^4*x3 + 2*x1*x2^3 + x1^2*x2*x3
                sage: W.from_reduced_word([3,1,2,0,3,1,0]).stanley_symmetric_function_as_polynomial() # long time
                8*x1^7 + 4*x1^5*x2 + 2*x1^3*x2^2 + x1*x2^3

                sage: W = WeylGroup(['C',3,1])
                sage: W.from_reduced_word([0,2,1,0]).stanley_symmetric_function_as_polynomial()
                32*x1^4 + 16*x1^2*x2 + 8*x2^2 + 4*x1*x3

                sage: W = WeylGroup(['B',3,1])
                sage: W.from_reduced_word([3,2,1]).stanley_symmetric_function_as_polynomial()
                2*x1^3 + x1*x2 + 1/2*x3

            Algorithm: Induction on the left Pieri factors. Note that
            this induction preserves subsets of `W` which are stable
            by taking right factors, and in particular Grassmanian
            elements.
            """
            W = self.parent()
            pieri_factors = W.pieri_factors()
            R = QQ[','.join('x%s'%l for l in range(1,pieri_factors.max_length()+1))]
            x = R.gens()
            if self.is_one():
                return R(1)

            return R(sum(2**(pieri_factors.stanley_symm_poly_weight(u))*x[u.length()-1] * v.stanley_symmetric_function_as_polynomial(max_length = u.length())
                           for (u,v) in self.left_pieri_factorizations(max_length)
                           if u != W.unit()))

        def stanley_symmetric_function(self):
            r"""
            INPUT:
                - ``self`` -- an element `w` of a Weyl group

            Returns the affine Stanley symmetric function indexed by
            `w`. Stanley symmetric functions are defined as generating
            series of the factorizations of `w` into Pieri factors and
            weighted by a statistic on Pieri factors.

            EXAMPLES::

                sage: W = WeylGroup(['A', 3, 1])
                sage: W.from_reduced_word([3,1,2,0,3,1,0]).stanley_symmetric_function()
                8*m[1, 1, 1, 1, 1, 1, 1] + 4*m[2, 1, 1, 1, 1, 1] + 2*m[2, 2, 1, 1, 1] + m[2, 2, 2, 1]

                sage: W = WeylGroup(['C',3,1])
                sage: W.from_reduced_word([0,2,1,0]).stanley_symmetric_function()
                32*m[1, 1, 1, 1] + 16*m[2, 1, 1] + 8*m[2, 2] + 4*m[3, 1]

                sage: W = WeylGroup(['B',3,1])
                sage: W.from_reduced_word([3,2,1]).stanley_symmetric_function()
                2*m[1, 1, 1] + m[2, 1] + 1/2*m[3]

                sage: W = WeylGroup(['B',4])
                sage: w = W.from_reduced_word([3,2,3,1])
                sage: w.stanley_symmetric_function()  # long time (6s on sage.math, 2011)
                48*m[1, 1, 1, 1] + 24*m[2, 1, 1] + 12*m[2, 2] + 8*m[3, 1] + 2*m[4]

             * :meth:stanley_symmetric_function_as_polynomial`
             * :meth:`WeylGroups.ParentMethods.pieri_factors`
             * :mod:`sage.combinat.root_system.pieri_factors`

            REFERENCES:

                .. [BH1994] S. Billey, M. Haiman.  Schubert polynomials for the classical groups. J. Amer. Math. Soc., 1994.
                .. [Lam2008] T. Lam. Schubert polynomials for the affine Grassmannian.  J. Amer. Math. Soc., 2008.
                .. [LSS2009] T. Lam, A. Schilling, M. Shimozono. Schubert polynomials for the affine Grassmannian of the symplectic group. Mathematische Zeitschrift 264(4) (2010) 765-811 (arXiv:0710.2720 [math.CO])
                .. [Pon2010] S. Pon. Types B and D affine Stanley symmetric functions, unpublished PhD Thesis, UC Davis, 2010.

            """
            import sage.combinat.sf
            m = sage.combinat.sf.sf.SymmetricFunctions(QQ).monomial()
            return m.from_polynomial_exp(self.stanley_symmetric_function_as_polynomial())

        @cached_in_parent_method
        def reflection_to_root(self):
            r"""
            Returns the root associated with the reflection ``self``.

            EXAMPLES::

                sage: W=WeylGroup(['C',2],prefix="s")
                sage: r=W.from_reduced_word([1,2,1])
                sage: r.reflection_to_root()
                2*alpha[1] + alpha[2]
                sage: r=W.from_reduced_word([1,2])
                sage: r.reflection_to_root()
                Traceback (most recent call last):
                ...
                ValueError: s1*s2 is not a reflection

            """

            i = self.first_descent()
            if i is None:
                raise ValueError, "%s is not a reflection"%(self)
            if self == self.parent().simple_reflection(i):
                from sage.combinat.root_system.root_system import RootSystem
                return RootSystem(self.parent().cartan_type()).root_lattice().simple_root(i)
                #return self.parent().domain().simple_root(i)
            if not self.has_descent(i, side='left'):
                raise ValueError, "%s is not a reflection"%(self)
            return ((self.apply_conjugation_by_simple_reflection(i)).reflection_to_root()).simple_reflection(i)

        @cached_in_parent_method
        def reflection_to_coroot(self):
            r"""
            Returns the coroot associated with the reflection ``self``.

            EXAMPLES::

                sage: W=WeylGroup(['C',2],prefix="s")
                sage: r=W.from_reduced_word([1,2,1])
                sage: r.reflection_to_coroot()
                alphacheck[1] + alphacheck[2]
                sage: r=W.from_reduced_word([1,2])
                sage: r.reflection_to_coroot()
                Traceback (most recent call last):
                ...
                ValueError: s1*s2 is not a reflection

            """

            i = self.first_descent()
            if i is None:
                raise ValueError, "%s is not a reflection"%(self)
            if self == self.parent().simple_reflection(i):
                from sage.combinat.root_system.root_system import RootSystem
                return RootSystem(self.parent().cartan_type()).root_lattice().simple_coroot(i)
                #return self.parent().domain().simple_coroot(i)
            if not self.has_descent(i, side='left'):
                raise ValueError, "%s is not a reflection"%(self)
            return ((self.apply_conjugation_by_simple_reflection(i)).reflection_to_coroot()).simple_reflection(i)

        def inversions(self, side = 'right', inversion_type = 'reflections'):
            """
            Returns the set of inversions of ``self``.

            INPUT:

            - ``side`` -- 'right' (default) or 'left'
            - ``inversion_type`` -- 'reflections' (default), 'roots', or 'coroots'.

            OUTPUT:

            For reflections, the set of reflections r in the Weyl group such that
            ``self`` ``r`` < ``self``. For (co)roots, the set of positive (co)roots that are sent
            by ``self`` to negative (co)roots; their associated reflections are described above.

            If ``side`` is 'left', the inverse Weyl group element is used.

            EXAMPLES::

                sage: W=WeylGroup(['C',2], prefix="s")
                sage: w=W.from_reduced_word([1,2])
                sage: w.inversions()
                [s2, s2*s1*s2]
                sage: w.inversions(inversion_type = 'reflections')
                [s2, s2*s1*s2]
                sage: w.inversions(inversion_type = 'roots')
                [alpha[2], alpha[1] + alpha[2]]
                sage: w.inversions(inversion_type = 'coroots')
                [alphacheck[2], alphacheck[1] + 2*alphacheck[2]]
                sage: w.inversions(side = 'left')
                [s1, s1*s2*s1]
                sage: w.inversions(side = 'left', inversion_type = 'roots')
                [alpha[1], 2*alpha[1] + alpha[2]]
                sage: w.inversions(side = 'left', inversion_type = 'coroots')
                [alphacheck[1], alphacheck[1] + alphacheck[2]]

            """

            if side == 'left':
                self = self.inverse()
            reflections = self.inversions_as_reflections()
            if inversion_type == 'reflections':
                return reflections
            if inversion_type == 'roots':
                return [r.reflection_to_root() for r in reflections]
            if inversion_type == 'coroots':
                return [r.reflection_to_coroot() for r in reflections]
            raise ValueError, "inversion_type %s is invalid"%(inversion_type)

        def bruhat_lower_covers_coroots(self):
            r"""
            Returns all 2-tuples (``v``, `\alpha`) where ``v`` is covered by ``self`` and `\alpha`
            is the positive coroot such that ``self`` = ``v`` `s_\alpha` where `s_\alpha` is
            the reflection orthogonal to `\alpha`.

            ALGORITHM:

            See :meth:`.bruhat_lower_covers` and :meth:`.bruhat_lower_covers_reflections` for Coxeter groups.

            EXAMPLES::

                sage: W = WeylGroup(['A',3], prefix="s")
                sage: w = W.from_reduced_word([3,1,2,1])
                sage: w.bruhat_lower_covers_coroots()
                [(s1*s2*s1, alphacheck[1] + alphacheck[2] + alphacheck[3]), (s3*s2*s1, alphacheck[2]), (s3*s1*s2, alphacheck[1])]

            """

            return [(x[0],x[1].reflection_to_coroot()) for x in self.bruhat_lower_covers_reflections()]

        def bruhat_upper_covers_coroots(self):
            r"""
            Returns all 2-tuples (``v``, `\alpha`) where ``v`` is covers ``self`` and `\alpha`
            is the positive coroot such that ``self`` = ``v`` `s_\alpha` where `s_\alpha` is
            the reflection orthogonal to `\alpha`.

            ALGORITHM:

            See :meth:`~CoxeterGroups.ElementMethods.bruhat_upper_covers` and :meth:`.bruhat_upper_covers_reflections` for Coxeter groups.

            EXAMPLES::

                sage: W = WeylGroup(['A',4], prefix="s")
                sage: w = W.from_reduced_word([3,1,2,1])
                sage: w.bruhat_upper_covers_coroots()
                [(s1*s2*s3*s2*s1, alphacheck[3]), (s2*s3*s1*s2*s1, alphacheck[2] + alphacheck[3]), (s3*s4*s1*s2*s1, alphacheck[4]), (s4*s3*s1*s2*s1, alphacheck[1] + alphacheck[2] + alphacheck[3] + alphacheck[4])]

            """

            return [(x[0],x[1].reflection_to_coroot()) for x in self.bruhat_upper_covers_reflections()]

        def quantum_bruhat_successors(self, index_set = None, roots = False, quantum_only = False):
            r"""
            Returns the successors of ``self`` in the parabolic quantum Bruhat graph.

            INPUT:

            - ``self`` -- a Weyl group element, which is assumed to be of minimum length in its coset with respect to the parabolic subgroup

            - ``index_set`` -- (default: None) indicates the set of simple reflections used to generate the parabolic subgroup;
               the default value indicates that the subgroup is the identity

            - ``roots`` -- (default: False) if True, returns the list of 2-tuples (``w``, `\alpha`) where ``w`` is a
               successor and `\alpha` is the positive root associated with the successor relation.

            - ``quantum_only`` -- (default: False) if True, returns only the quantum successors

            Returns the successors of ``self`` in the quantum Bruhat graph on the parabolic quotient of the Weyl group determined
            by the subset of Dynkin nodes ``index_set``.

            EXAMPLES::

                sage: W = WeylGroup(['A',3], prefix="s")
                sage: w = W.from_reduced_word([3,1,2])
                sage: w.quantum_bruhat_successors([1], roots = True)
                [(s3, alpha[2]), (s1*s2*s3*s2, alpha[3]), (s2*s3*s1*s2, alpha[1] + alpha[2] + alpha[3])]
                sage: w.quantum_bruhat_successors([1,3])
                [1, s2*s3*s1*s2]
                sage: w.quantum_bruhat_successors(roots = True)
                [(s3*s1*s2*s1, alpha[1]), (s3*s1, alpha[2]), (s1*s2*s3*s2, alpha[3]), (s2*s3*s1*s2, alpha[1] + alpha[2] + alpha[3])]
                sage: w.quantum_bruhat_successors()
                [s3*s1*s2*s1, s3*s1, s1*s2*s3*s2, s2*s3*s1*s2]
                sage: w.quantum_bruhat_successors(quantum_only = True)
                [s3*s1]
                sage: w = W.from_reduced_word([2,3])
                sage: w.quantum_bruhat_successors([1,3])
                Traceback (most recent call last):
                ...
                ValueError: s2*s3 is not of minimum length in its coset of the parabolic subgroup
                generated by the reflections [1, 3]

            """
            W = self.parent()
            if not W.cartan_type().is_finite():
                raise ValueError, "The Cartan type %s is not finite"%(W.cartan_type())
            if index_set is None:
                index_set = []
            else:
                index_set = [x for x in index_set]
            if self != self.coset_representative(index_set):
                raise ValueError, "%s is not of minimum length in its coset of the parabolic subgroup generated by the reflections %s"%(self,index_set)
            lattice = W.cartan_type().root_system().root_lattice()
            non_parab_roots = lattice.positive_roots_nonparabolic(tuple(index_set))
            two_rho_minus_two_rho_P = lattice.positive_roots_nonparabolic_sum(tuple(index_set))
            w_length_plus_one = self.length() + 1
            successors = []
            for alpha in non_parab_roots:
                wr = self * W.from_reduced_word(alpha.associated_reflection())
                wrc = wr.coset_representative(index_set)
                if wrc == wr and wr.length() == w_length_plus_one and not quantum_only:
                    if roots:
                        successors.append((wr,alpha))
                    else:
                        successors.append(wr)
                elif alpha.quantum_root() and wrc.length() == w_length_plus_one - two_rho_minus_two_rho_P.scalar(alpha.associated_coroot()):
                    if roots:
                        successors.append((wrc,alpha))
                    else:
                        successors.append(wrc)
            return successors
