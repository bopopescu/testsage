"""
Subspace of ambient spaces of modular symbols
"""

#*****************************************************************************
#       SAGE: System for Algebra and Geometry Experimentation
#
#       Copyright (C) 2005 William Stein <wstein@gmail.com>
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

import weakref

import ambient
import sage.modules.free_module as free_module
import sage.misc.misc as misc
import sage.modular.congroup as congroup
import sage.rings.arith as arith
import sage.modules.free_module_morphism as free_module_morphism
import sage.modular.hecke.all as hecke

import sage.structure.factorization

import sage.modular.modsym.space

import sage.modular.modsym.element

class ModularSymbolsSubspace(sage.modular.modsym.space.ModularSymbolsSpace, hecke.HeckeSubmodule):
    """
    Subspace of ambient space of modular symbols
    """
    ################################
    # Special Methods
    ################################
    def __init__(self, ambient_hecke_module, submodule, dual_free_module=None, check=False):
        """
        INPUT:
            ambient_hecke_module -- the ambient space of modular
                      symbols in which we're constructing a submodule
            submodule -- the underlying free module of the submodule
            dual_free_module -- underlying free module of the dual of
                      the submodule (optional)
            check -- (default: False) whether to check that the
                     submodule is invariant under all Hecke operators T_p.
        """
        self.__ambient_hecke_module = ambient_hecke_module
        A = ambient_hecke_module
        sage.modular.modsym.space.ModularSymbolsSpace.__init__(self, A.group(), A.weight(), \
                                           A.character(), A.sign(), A.base_ring())
        hecke.HeckeSubmodule.__init__(self, A, submodule, dual_free_module = dual_free_module, check=check)

    def _repr_(self):
        return "Modular Symbols subspace of dimension %s of %s"%(
                    self.rank(), self.ambient_module())

    ################################
    # Public functions
    ################################
    def boundary_map(self):
        """
        The boundary map to the corresponding space of boundary
        modular symbols.  (This is the restriction of the map on the
        ambient space.)
        """
        try:
            return self.__boundary_map
        except AttributeError:
            # restrict from ambient space
            b = self.ambient_hecke_module().boundary_map()
            self.__boundary_map = b.restrict_domain(self)
            return self.__boundary_map

    def cuspidal_submodule(self):
        """
        Return the cuspidal subspace of this space of modular symbols.
        """
        try:
            return self.__cuspidal_submodule
        except AttributeError:
            S = self.ambient_hecke_module().cuspidal_submodule()
            self.__cuspidal_submodule = S.intersection(self)
            return self.__cuspidal_submodule

    def dual_star_involution_matrix(self):
        """
        Return the matrix of the dual star involution, which is
        induced by complex conjugation on the linear dual of modular
        symbols.
        """
        try:
            return self.__dual_star_involution
        except AttributeError:
            pass
        S = self.ambient_hecke_module().dual_star_involution_matrix()
        A = S.restrict(self.dual_free_module())
        self.__dual_star_involution = A
        return self.__dual_star_involution

    def eisenstein_subspace(self):
        """
        Return the Eisenstein subspace of this space of modular symbols.
        """
        try:
            return self.__eisenstein_subspace
        except AttributeError:
            S = self.ambient_hecke_module().eisenstein_subspace()
            self.__eisenstein_subspace = S.intersection(self)
            return self.__eisenstein_subspace

    def factorization(self):
        """
        Returns a list of pairs $(S,e)$ where $S$ is simple spaces of
        modular symbols and self is isomorphic to the direct sum of
        the $S^e$ as a module over the \emph{anemic} Hecke algebra
        adjoin the star involution.

        The factors are sorted by dimension -- don't depend on much more for now.

        ASSUMPTION: self is a module over the anemic Hecke algebra.

        EXAMPLES:
        Note that if the sign is 1 then the cuspidal factors occur twice, one with each star eigenvalue.
            sage: M = ModularSymbols(11)
            sage: D = M.factorization(); D
            (Modular Symbols subspace of dimension 1 of Modular Symbols space of dimension 3 for Gamma_0(11) of weight 2 with sign 0 over Rational Field) *
            (Modular Symbols subspace of dimension 1 of Modular Symbols space of dimension 3 for Gamma_0(11) of weight 2 with sign 0 over Rational Field) *
            (Modular Symbols subspace of dimension 1 of Modular Symbols space of dimension 3 for Gamma_0(11) of weight 2 with sign 0 over Rational Field)
            sage: [A.T(2).matrix() for A, _ in D]
            [[-2], [3], [-2]]
            sage: [A.star_eigenvalues() for A, _ in D]
            [[-1], [1], [1]]

        In this example there is one old factor squared.
            sage: M = ModularSymbols(22,sign=1)
            sage: S = M.cuspidal_submodule()
            sage: S.factorization()
            (Modular Symbols subspace of dimension 1 of Modular Symbols space of dimension 2 for Gamma_0(11) of weight 2 with sign 1 over Rational Field)^2

        The following example exposes a not-implemented issue:
             sage: M = ModularSymbols(Gamma0(22), 2, sign=1)
             sage: M1 = M.decomposition()[1]
             sage: M1.factorization()
             Traceback (most recent call last):
             ...
             NotImplementedError: modular symbols factorization not fully implemented yet --  self has dimension 3, but sum of dimensions of factors is 2
        """
        try:
            return self._factorization
        except AttributeError:
            pass
        try:
            if self._is_simple:
                return [(self, 1)]
        except AttributeError:
            pass
        if self.is_new():
            D = []
            N = self.decomposition()
            if self.sign() == 0:
                for A in N:
                    if A.is_cuspidal():
                        V = A.plus_submodule()
                        V._is_simple = True
                        D.append((V,1))
                        V = A.minus_submodule()
                        V._is_simple = True
                        D.append((V,1))
                    else:
                        A._is_simple = True
                        D.append((A, 1))
            else:
                for A in N:
                    A._is_simple = True
                    D.append((A,1))
        else:
            # Compute factorization of the ambient space, then compute multiplicity
            # of each factor in this space.
            D = []
            for S in self.ambient_hecke_module().simple_factors():
                n = self.multiplicity(S)
                if n > 0:
                    D.append((S,n))
        # endif

        # check that dimensions add up
        r = self.dimension()
        s = sum([A.rank()*mult for A, mult in D])
        if r != s:
            raise NotImplementedError, "modular symbols factorization not fully implemented yet --  self has dimension %s, but sum of dimensions of factors is %s"%(
            r, s)
        self._factorization = sage.structure.factorization.Factorization(D, cr=True)
        return self._factorization

    def hecke_bound(self):
        if self.is_cuspidal():
            return self.sturm_bound()
        else:
            return self.ambient_hecke_module().hecke_bound()

    def is_cuspidal(self):
        try:
            return self.__is_cuspidal
        except AttributeError:
            C = self.ambient_hecke_module().cuspidal_submodule()
            self.__is_cuspidal = self.is_submodule(C)
            return self.__is_cuspidal

    def is_eisenstein(self):
        try:
            return self.__is_eisenstien
        except AttributeError:
            C = self.ambient_hecke_module().eisenstein_subspace()
            self.__is_eisenstein = self.is_submodule(C)
            return self.__is_eisenstein

    def _compute_sign_subspace(self, sign, compute_dual=True):
        """
        Return the subspace of self that is fixed under the star involution.

        INPUT:
            sign -- int (either -1 or +1)
            compute_dual -- bool (default: True) also compute dual subspace.
                            This are useful for many algorithms.
        OUTPUT:
            subspace of modular symbols

        """
        S = self.star_involution().matrix() - sign
        V = S.kernel()
        if compute_dual:
            Sdual = self.dual_star_involution_matrix() - sign
            Vdual = Sdual.kernel()
        else:
            Vdual = None
        return self.submodule_from_nonembedded_module(V, Vdual)

    def star_involution(self):
        """
        Return the star involution on self, which is induced by complex
        conjugation on modular symbols.
        """
        try:
            return self.__star_involution
        except AttributeError:
            pass
        S = self.ambient_hecke_module().star_involution()
        self.__star_involution = S.restrict(self)
        return self.__star_involution
