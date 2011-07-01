"""
Fast compiled graphs

This is a Cython implementation of the base class for sparse and dense graphs
in Sage. It is not intended for use on its own. Specific graph types should
extend this base class and implement missing functionalities. Whenever
possible, specific methods should also be overridden with implementations that
suit the graph type under consideration.

Data structure
--------------

The class ``CGraph`` maintains the following variables:

- ``cdef int num_verts``
- ``cdef int num_arcs``
- ``cdef int *in_degrees``
- ``cdef int *out_degrees``
- ``cdef bitset_t active_vertices``

The bitset ``active_vertices`` is a list of all available vertices for use, but
only the ones which are set are considered to actually be in the graph. The
variables ``num_verts`` and ``num_arcs`` are self-explanatory. Note that
``num_verts`` is the number of bits set in ``active_vertices``, not the full
length of the bitset. The arrays ``in_degrees`` and ``out_degrees`` are of the
same length as the bitset.

For more information about active vertices, see the documentation for the
method :meth:`realloc <sage.graphs.base.c_graph.CGraph.realloc>`.
"""

#**************************************************************************
#        Copyright (C) 2008-9 Robert L. Miller <rlmillster@gmail.com>
#
# Distributed  under  the  terms  of  the  GNU  General  Public  License (GPL)
#                         http://www.gnu.org/licenses/
#**************************************************************************

include "../../misc/bitset.pxi"

from graph_backends import GenericGraphBackend
from sage.rings.integer cimport Integer

cdef class CGraph:
    """
    Compiled sparse and dense graphs.
    """

    ###################################
    # Vertex Functions
    ###################################

    cpdef bint has_vertex(self, int n):
        """
        Determine whether the vertex ``n`` is in ``self``.

        This method is different from :meth:`check_vertex`. The current method
        returns a boolean to signify whether or not ``n`` is a vertex of this
        graph. On the other hand, :meth:`check_vertex` raises an error if
        ``n`` is not a vertex of this graph.

        INPUT:

        - ``n`` -- a nonnegative integer representing a vertex.

        OUTPUT:

        - ``True`` if ``n`` is a vertex of this graph; ``False`` otherwise.

        .. SEEALSO::

            - :meth:`check_vertex`
              -- raise an error if this graph does not contain a specific
              vertex.

        EXAMPLES:

        Upon initialization, a
        :class:`SparseGraph <sage.graphs.base.sparse_graph.SparseGraph>`
        or
        :class:`DenseGraph <sage.graphs.base.dense_graph.DenseGraph>`
        has the first ``nverts`` vertices::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: S = SparseGraph(nverts=10, expected_degree=3, extra_vertices=10)
            sage: S.has_vertex(6)
            True
            sage: S.has_vertex(12)
            False
            sage: S.has_vertex(24)
            False
            sage: S.has_vertex(-19)
            False

        ::

            sage: from sage.graphs.base.dense_graph import DenseGraph
            sage: D = DenseGraph(nverts=10, extra_vertices=10)
            sage: D.has_vertex(6)
            True
            sage: D.has_vertex(12)
            False
            sage: D.has_vertex(24)
            False
            sage: D.has_vertex(-19)
            False
        """
        return (n >= 0 and
                n < self.active_vertices.size and
                bitset_in(self.active_vertices, n))

    cpdef check_vertex(self, int n):
        """
        Checks that ``n`` is a vertex of ``self``.

        This method is different from :meth:`has_vertex`. The current method
        raises an error if ``n`` is not a vertex of this graph. On the other
        hand, :meth:`has_vertex` returns a boolean to signify whether or not
        ``n`` is a vertex of this graph.

        INPUT:

        - ``n`` -- a nonnegative integer representing a vertex.

        OUTPUT:

        - Raise an error if ``n`` is not a vertex of this graph.

        .. SEEALSO::

            - :meth:`has_vertex`
              -- determine whether this graph has a specific vertex.

        EXAMPLES::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: S = SparseGraph(nverts=10, expected_degree=3, extra_vertices=10)
            sage: S.check_vertex(4)
            sage: S.check_vertex(12)
            Traceback (most recent call last):
            ...
            RuntimeError: Vertex (12) is not a vertex of the graph.
            sage: S.check_vertex(24)
            Traceback (most recent call last):
            ...
            RuntimeError: Vertex (24) is not a vertex of the graph.
            sage: S.check_vertex(-19)
            Traceback (most recent call last):
            ...
            RuntimeError: Vertex (-19) is not a vertex of the graph.

        ::

            sage: from sage.graphs.base.dense_graph import DenseGraph
            sage: D = DenseGraph(nverts=10, extra_vertices=10)
            sage: D.check_vertex(4)
            sage: D.check_vertex(12)
            Traceback (most recent call last):
            ...
            RuntimeError: Vertex (12) is not a vertex of the graph.
            sage: D.check_vertex(24)
            Traceback (most recent call last):
            ...
            RuntimeError: Vertex (24) is not a vertex of the graph.
            sage: D.check_vertex(-19)
            Traceback (most recent call last):
            ...
            RuntimeError: Vertex (-19) is not a vertex of the graph.
        """
        if not self.has_vertex(n):
            raise RuntimeError("Vertex (%d) is not a vertex of the graph." % n)

    cdef int add_vertex_unsafe(self, int k):
        """
        Adds the vertex ``k`` to the graph.

        INPUT:

        - ``k`` -- nonnegative integer or ``-1``. For `k >= 0`, add the
          vertex ``k`` to this graph if the vertex is not already in the graph.
          If `k = -1`, this function will find the first available vertex
          that is not in ``self`` and add that vertex to this graph.

        OUTPUT:

        - ``-1`` -- indicates that no vertex was added because the current
          allocation is already full or the vertex is out of range.

        - nonnegative integer -- this vertex is now guaranteed to be in the
          graph.

        .. WARNING::

            This method is potentially unsafe. You should instead use
            :meth:`add_vertex`.
        """
        if k == -1:
            k = bitset_first_in_complement(self.active_vertices)
        elif self.active_vertices.size <= k:
            k = -1
        if k != -1:
            if not bitset_in(self.active_vertices, k):
                self.num_verts += 1
            bitset_add(self.active_vertices, k)
        return k

    def add_vertex(self, int k=-1):
        """
        Adds vertex ``k`` to the graph.

        INPUT:

        - ``k`` -- nonnegative integer or ``-1`` (default: ``-1``). If
          `k = -1`, a new vertex is added and the integer used is returned.
          That is, for `k = -1`, this function will find the first available
          vertex that is not in ``self`` and add that vertex to this graph.

        OUTPUT:

        - ``-1`` -- indicates that no vertex was added because the current
          allocation is already full or the vertex is out of range.

        - nonnegative integer -- this vertex is now guaranteed to be in the
          graph.

        .. SEEALSO::

            - :meth:`add_vertex_unsafe`
              -- add a vertex to a graph. This method is potentially unsafe.
              You should instead use :meth:`add_vertex`.

            - :meth:`add_vertices`
              -- add a bunch of vertices to a graph.

        EXAMPLES:

        Adding vertices to a sparse graph::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: G = SparseGraph(3, extra_vertices=3)
            sage: G.add_vertex(3)
            3
            sage: G.add_arc(2, 5)
            Traceback (most recent call last):
            ...
            RuntimeError: Vertex (5) is not a vertex of the graph.
            sage: G.add_arc(1, 3)
            sage: G.has_arc(1, 3)
            True
            sage: G.has_arc(2, 3)
            False

        Adding vertices to a dense graph::

            sage: from sage.graphs.base.dense_graph import DenseGraph
            sage: G = DenseGraph(3, extra_vertices=3)
            sage: G.add_vertex(3)
            3
            sage: G.add_arc(2,5)
            Traceback (most recent call last):
            ...
            RuntimeError: Vertex (5) is not a vertex of the graph.
            sage: G.add_arc(1, 3)
            sage: G.has_arc(1, 3)
            True
            sage: G.has_arc(2, 3)
            False

        Repeatedly adding a vertex using `k = -1` will allocate more memory
        as required::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: G = SparseGraph(3, extra_vertices=0)
            sage: G.verts()
            [0, 1, 2]
            sage: for i in range(10):
            ...       _ = G.add_vertex(-1);
            ...
            sage: G.verts()
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

        ::

            sage: from sage.graphs.base.dense_graph import DenseGraph
            sage: G = DenseGraph(3, extra_vertices=0)
            sage: G.verts()
            [0, 1, 2]
            sage: for i in range(12):
            ...       _ = G.add_vertex(-1);
            ...
            sage: G.verts()
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]

        TESTS::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: G = SparseGraph(3, extra_vertices=0)
            sage: G.add_vertex(6)
            Traceback (most recent call last):
            ...
            RuntimeError: Requested vertex is past twice the allocated range: use realloc.

        ::

            sage: from sage.graphs.base.dense_graph import DenseGraph
            sage: G = DenseGraph(3, extra_vertices=0)
            sage: G.add_vertex(6)
            Traceback (most recent call last):
            ...
            RuntimeError: Requested vertex is past twice the allocated range: use realloc.
        """
        if k >= (2 * self.active_vertices.size):
            raise RuntimeError(
                "Requested vertex is past twice the allocated range: " +
                "use realloc.")
        if (k >= self.active_vertices.size or
            (k == -1 and self.active_vertices.size == self.num_verts)):
            self.realloc(2 * self.active_vertices.size)
        return self.add_vertex_unsafe(k)

    cpdef add_vertices(self, object verts):
        """
        Adds vertices from the iterable ``verts``.

        INPUT:

        - ``verts`` -- an iterable of vertices.

        OUTPUT:

        - Same as for :meth:`add_vertex`.

        .. SEEALSO::

            - :meth:`add_vertex`
              -- add a vertex to a graph.

        EXAMPLE:

        Adding vertices for sparse graphs::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: S = SparseGraph(nverts=4, extra_vertices=4)
            sage: S.verts()
            [0, 1, 2, 3]
            sage: S.add_vertices([3,5,7,9])
            sage: S.verts()
            [0, 1, 2, 3, 5, 7, 9]
            sage: S.realloc(20)
            sage: S.verts()
            [0, 1, 2, 3, 5, 7, 9]

        Adding vertices for dense graphs::

            sage: from sage.graphs.base.dense_graph import DenseGraph
            sage: D = DenseGraph(nverts=4, extra_vertices=4)
            sage: D.verts()
            [0, 1, 2, 3]
            sage: D.add_vertices([3,5,7,9])
            sage: D.verts()
            [0, 1, 2, 3, 5, 7, 9]
            sage: D.realloc(20)
            sage: D.verts()
            [0, 1, 2, 3, 5, 7, 9]
        """
        cdef int v
        for v in verts:
            self.add_vertex(v)

    cdef int del_vertex_unsafe(self, int v):
        """
        Deletes the vertex ``v``, along with all edges incident to it.

        INPUT:

        - ``v`` -- nonnegative integer representing a vertex.

        OUTPUT:

        - None.

        .. WARNING::

            This method is potentially unsafe. Use :meth:`del_vertex` instead.
        """
        cdef int size = 0
        cdef int num_nbrs
        cdef int i
        cdef int *neighbors
        if self.in_degrees[v] > size:
            size = self.in_degrees[v]
        if self.out_degrees[v] > size:
            size = self.out_degrees[v]
        if size > 0:
            neighbors = <int *> sage_malloc(size * sizeof(int))
            if not neighbors:
                raise RuntimeError("Failure allocating memory.")
            # delete each arc incident with v
            num_nbrs = self.in_neighbors_unsafe(v, neighbors, size)
            for i from 0 <= i < num_nbrs:
                self.del_arc_unsafe(neighbors[i], v)
            num_nbrs = self.out_neighbors_unsafe(v, neighbors, size)
            for i from 0 <= i < num_nbrs:
                self.del_arc_unsafe(v, neighbors[i])
            sage_free(neighbors)

        self.num_verts -= 1
        bitset_remove(self.active_vertices, v)

    cpdef del_vertex(self, int v):
        """
        Deletes the vertex ``v``, along with all edges incident to it. If ``v``
        is not in ``self``, fails silently.

        INPUT:

        - ``v`` -- a nonnegative integer representing a vertex.

        OUTPUT:

        - None.

        .. SEEALSO::

            - :meth:`del_vertex_unsafe`
              -- delete a vertex from a graph. This method is potentially
              unsafe. Use :meth:`del_vertex` instead.

        EXAMPLES:

        Deleting vertices of sparse graphs::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: G = SparseGraph(3)
            sage: G.add_arc(0, 1)
            sage: G.add_arc(0, 2)
            sage: G.add_arc(1, 2)
            sage: G.add_arc(2, 0)
            sage: G.del_vertex(2)
            sage: for i in range(2):
            ...       for j in range(2):
            ...           if G.has_arc(i, j):
            ...               print i, j
            0 1
            sage: G = SparseGraph(3)
            sage: G.add_arc(0, 1)
            sage: G.add_arc(0, 2)
            sage: G.add_arc(1, 2)
            sage: G.add_arc(2, 0)
            sage: G.del_vertex(1)
            sage: for i in xrange(3):
            ...       for j in xrange(3):
            ...           if G.has_arc(i, j):
            ...               print i, j
            0 2
            2 0

        Deleting vertices of dense graphs::

            sage: from sage.graphs.base.dense_graph import DenseGraph
            sage: G = DenseGraph(4)
            sage: G.add_arc(0, 1); G.add_arc(0, 2)
            sage: G.add_arc(3, 1); G.add_arc(3, 2)
            sage: G.add_arc(1, 2)
            sage: G.verts()
            [0, 1, 2, 3]
            sage: G.del_vertex(3); G.verts()
            [0, 1, 2]
            sage: for i in range(3):
            ...       for j in range(3):
            ...           if G.has_arc(i, j):
            ...               print i, j
            ...
            0 1
            0 2
            1 2

        If the vertex to be deleted is not in this graph, then fail silently::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: G = SparseGraph(3)
            sage: G.verts()
            [0, 1, 2]
            sage: G.has_vertex(3)
            False
            sage: G.del_vertex(3)
            sage: G.verts()
            [0, 1, 2]

        ::

            sage: from sage.graphs.base.dense_graph import DenseGraph
            sage: G = DenseGraph(5)
            sage: G.verts()
            [0, 1, 2, 3, 4]
            sage: G.has_vertex(6)
            False
            sage: G.del_vertex(6)
            sage: G.verts()
            [0, 1, 2, 3, 4]
        """
        if self.has_vertex(v):
            self.del_vertex_unsafe(v)

    cpdef int current_allocation(self):
        """
        Report the number of vertices allocated.

        INPUT:

        - None.

        OUTPUT:

        - The number of vertices allocated. This number is usually different
          from the order of a graph. We may have allocated enough memory for
          a graph to hold `n > 0` vertices, but the order (actual number of
          vertices) of the graph could be less than `n`.

        EXAMPLES::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: S = SparseGraph(nverts=4, extra_vertices=4)
            sage: S.current_allocation()
            8
            sage: S.add_vertex(6)
            6
            sage: S.current_allocation()
            8
            sage: S.add_vertex(10)
            10
            sage: S.current_allocation()
            16
            sage: S.add_vertex(40)
            Traceback (most recent call last):
            ...
            RuntimeError: Requested vertex is past twice the allocated range: use realloc.
            sage: S.realloc(50)
            sage: S.add_vertex(40)
            40
            sage: S.current_allocation()
            50
            sage: S.realloc(30)
            -1
            sage: S.current_allocation()
            50
            sage: S.del_vertex(40)
            sage: S.realloc(30)
            sage: S.current_allocation()
            30

        The actual number of vertices in a graph might be less than the
        number of vertices allocated for the graph::

            sage: from sage.graphs.base.dense_graph import DenseGraph
            sage: G = DenseGraph(nverts=3, extra_vertices=2)
            sage: order = len(G.verts())
            sage: order
            3
            sage: G.current_allocation()
            5
            sage: order < G.current_allocation()
            True
        """
        return self.active_vertices.size

    cpdef list verts(self):
        """
        Returns a list of the vertices in ``self``.

        INPUT:

        - None.

        OUTPUT:

        - A list of all vertices in this graph.

        EXAMPLE::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: S = SparseGraph(nverts=4, extra_vertices=4)
            sage: S.verts()
            [0, 1, 2, 3]
            sage: S.add_vertices([3,5,7,9])
            sage: S.verts()
            [0, 1, 2, 3, 5, 7, 9]
            sage: S.realloc(20)
            sage: S.verts()
            [0, 1, 2, 3, 5, 7, 9]

        ::

            sage: from sage.graphs.base.dense_graph import DenseGraph
            sage: G = DenseGraph(3, extra_vertices=2)
            sage: G.verts()
            [0, 1, 2]
            sage: G.del_vertex(0)
            sage: G.verts()
            [1, 2]
        """
        cdef int i
        return [i for i from 0 <= i < self.active_vertices.size
                if bitset_in(self.active_vertices, i)]

    cpdef realloc(self, int total):
        """
        Reallocate the number of vertices to use, without actually adding any.

        INPUT:

        - ``total`` -- integer; the total size to make the array of vertices.

        OUTPUT:

        - Raise a ``NotImplementedError``. This method is not implemented in
          this base class. A child class should provide a suitable
          implementation.

        .. SEEALSO::

            - :meth:`realloc <sage.graphs.base.sparse_graph.SparseGraph.realloc>`
              -- a ``realloc`` implementation for sparse graphs.

            - :meth:`realloc <sage.graphs.base.dense_graph.DenseGraph.realloc>`
              -- a ``realloc`` implementation for dense graphs.

        EXAMPLES:

        First, note that :meth:`realloc` is implemented for
        :class:`SparseGraph <sage.graphs.base.sparse_graph.SparseGraph>`
        and
        :class:`DenseGraph <sage.graphs.base.dense_graph.DenseGraph>`
        differently, and is not implemented at the
        :class:`CGraph` level::

            sage: from sage.graphs.base.c_graph import CGraph
            sage: G = CGraph()
            sage: G.realloc(20)
            Traceback (most recent call last):
            ...
            NotImplementedError

        The ``realloc`` implementation for sparse graphs::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: S = SparseGraph(nverts=4, extra_vertices=4)
            sage: S.current_allocation()
            8
            sage: S.add_vertex(6)
            6
            sage: S.current_allocation()
            8
            sage: S.add_vertex(10)
            10
            sage: S.current_allocation()
            16
            sage: S.add_vertex(40)
            Traceback (most recent call last):
            ...
            RuntimeError: Requested vertex is past twice the allocated range: use realloc.
            sage: S.realloc(50)
            sage: S.add_vertex(40)
            40
            sage: S.current_allocation()
            50
            sage: S.realloc(30)
            -1
            sage: S.current_allocation()
            50
            sage: S.del_vertex(40)
            sage: S.realloc(30)
            sage: S.current_allocation()
            30

        The ``realloc`` implementation for dense graphs::

            sage: from sage.graphs.base.dense_graph import DenseGraph
            sage: D = DenseGraph(nverts=4, extra_vertices=4)
            sage: D.current_allocation()
            8
            sage: D.add_vertex(6)
            6
            sage: D.current_allocation()
            8
            sage: D.add_vertex(10)
            10
            sage: D.current_allocation()
            16
            sage: D.add_vertex(40)
            Traceback (most recent call last):
            ...
            RuntimeError: Requested vertex is past twice the allocated range: use realloc.
            sage: D.realloc(50)
            sage: D.add_vertex(40)
            40
            sage: D.current_allocation()
            50
            sage: D.realloc(30)
            -1
            sage: D.current_allocation()
            50
            sage: D.del_vertex(40)
            sage: D.realloc(30)
            sage: D.current_allocation()
            30
        """
        raise NotImplementedError()

    ###################################
    # Edge Functions
    ###################################

    cdef int add_arc_unsafe(self, int u, int v) except? -1:
        raise NotImplementedError()

    cdef int has_arc_unsafe(self, int u, int v) except? -1:
        raise NotImplementedError()

    cdef int del_arc_unsafe(self, int u, int v) except? -1:
        raise NotImplementedError()

    cdef int out_neighbors_unsafe(self, int u, int *neighbors, int size) except? -2:
        raise NotImplementedError()

    cdef int in_neighbors_unsafe(self, int u, int *neighbors, int size) except? -2:
        raise NotImplementedError()

    cpdef add_arc(self, int u, int v):
        """
        Add the given arc to this graph.

        INPUT:

        - ``u`` -- integer; the tail of an arc.

        - ``v`` -- integer; the head of an arc.

        OUTPUT:

        - Raise ``NotImplementedError``. This method is not implemented at
          the :class:`CGraph` level. A child class should provide a suitable
          implementation.

        .. SEEALSO::

            - :meth:`add_arc <sage.graphs.base.sparse_graph.SparseGraph.add_arc>`
              -- ``add_arc`` method for sparse graphs.

            - :meth:`add_arc <sage.graphs.base.dense_graph.DenseGraph.add_arc>`
              -- ``add_arc`` method for dense graphs.

        EXAMPLE::

            sage: from sage.graphs.base.c_graph import CGraph
            sage: G = CGraph()
            sage: G.add_arc(0, 1)
            Traceback (most recent call last):
            ...
            NotImplementedError
        """
        raise NotImplementedError()

    cpdef bint has_arc(self, int u, int v) except -1:
        """
        Determine whether or not the given arc is in this graph.

        INPUT:

        - ``u`` -- integer; the tail of an arc.

        - ``v`` -- integer; the head of an arc.

        OUTPUT:

        - Print a ``Not Implemented!`` message. This method is not implemented
          at the :class:`CGraph` level. A child class should provide a
          suitable implementation.

        .. SEEALSO::

            - :meth:`has_arc <sage.graphs.base.sparse_graph.SparseGraph.has_arc>`
              -- ``has_arc`` method for sparse graphs.

            - :meth:`has_arc <sage.graphs.base.dense_graph.DenseGraph.has_arc>`
              -- ``has_arc`` method for dense graphs.

        EXAMPLE::

            sage: from sage.graphs.base.c_graph import CGraph
            sage: G = CGraph()
            sage: G.has_arc(0, 1)
            Not Implemented!
            False
        """
        # The following is due to a hard to reproduce bug in Cython where except,
        # cpdef, and classes don't play well together:
        print "Not Implemented!"
        # raise NotImplementedError() ... results in:
        # Exception exceptions.NotImplementedError: NotImplementedError() in 'sage.graphs.base.c_graph.CGraph.has_arc' ignored
        # False

    cpdef del_all_arcs(self, int u, int v):
        """
        Delete all arcs from ``u`` to ``v``.

        INPUT:

        - ``u`` -- integer; the tail of an arc.

        - ``v`` -- integer; the head of an arc.

        OUTPUT:

        - Raise ``NotImplementedError``. This method is not implemented at the
          :class:`CGraph` level. A child class should provide a suitable
          implementation.

        .. SEEALSO::

            - :meth:`del_all_arcs <sage.graphs.base.sparse_graph.SparseGraph.del_all_arcs>`
              -- ``del_all_arcs`` method for sparse graphs.

            - :meth:`del_all_arcs <sage.graphs.base.dense_graph.DenseGraph.del_all_arcs>`
              -- ``del_all_arcs`` method for dense graphs.

        EXAMPLE::

            sage: from sage.graphs.base.c_graph import CGraph
            sage: G = CGraph()
            sage: G.del_all_arcs(0,1)
            Traceback (most recent call last):
            ...
            NotImplementedError
        """
        raise NotImplementedError()

    cdef int * adjacency_sequence_in(self, int n, int *vertices, int v):
        r"""
        Returns the adjacency sequence corresponding to a list of vertices
        and a vertex.

        See the OUTPUT section for a formal definition.

        See the function ``_test_adjacency_sequence()`` of
        ``dense_graph.pyx`` and ``sparse_graph.pyx`` for unit tests.

        INPUT:

        - ``n`` -- nonnegative integer; the maximum index in
          ``vertices`` up to which we want to consider. If ``n = 0``,
          we only want to know if ``(vertices[0],v)`` is an edge. If
          ``n = 1``, we want to know whether ``(vertices[0],v)`` and
          ``(vertices[1],v)`` are edges.  Let ``k`` be the length of
          ``vertices``. If ``0 <= n < k``, then we want to know if
          ``v`` is adjacent to each of ``vertices[0], vertices[1],
          ..., vertices[n]``. Where ``n = k - 1``, then we consider
          all elements in the list ``vertices``.

        - ``vertices`` -- list of vertices.

        - ``v`` -- a vertex.

        - ``reverse`` (bool) -- if set to ``True``, considers the
          edges ``(v,vertices[i])`` instead of ``(v,vertices[i])``
          (only useful for digraphs).

        OUTPUT:

        Returns a list of ``n`` integers, whose i-th element is set to
        `1` iff ``(v,vertices[i])`` is an edge.

        .. SEEALSO::

            - :meth:`adjacency_sequence_out` -- Similar method for
            ``(v, vertices[i])`` instead of ``(vertices[i], v)`` (the
            difference only matters for digraphs).
        """
        cdef int i = 0
        cdef int *seq = <int *>sage_malloc(n * sizeof(int))
        for 0 <= i < n:
            seq[i] = 1 if self.has_arc_unsafe(vertices[i], v) else 0

        return seq

    cdef int * adjacency_sequence_out(self, int n, int *vertices, int v):
        r"""
        Returns the adjacency sequence corresponding to a list of vertices
        and a vertex.

        See the OUTPUT section for a formal definition.

        See the function ``_test_adjacency_sequence()`` of
        ``dense_graph.pyx`` and ``sparse_graph.pyx`` for unit tests.

        INPUT:

        - ``n`` -- nonnegative integer; the maximum index in
          ``vertices`` up to which we want to consider. If ``n = 0``,
          we only want to know if ``(v, vertices[0])`` is an edge. If
          ``n = 1``, we want to know whether ``(v, vertices[0])`` and
          ``(v, vertices[1])`` are edges.  Let ``k`` be the length of
          ``vertices``. If ``0 <= n < k``, then we want to know if
          each of ``vertices[0], vertices[1], ..., vertices[n]`` is
          adjacent to ``v``. Where ``n = k - 1``, then we consider all
          elements in the list ``vertices``.

        - ``vertices`` -- list of vertices.

        - ``v`` -- a vertex.

        OUTPUT:

        Returns a list of ``n`` integers, whose i-th element is set to
        `1` iff ``(v,vertices[i])`` is an edge.

        .. SEEALSO::

            - :meth:`adjacency_sequence_in` -- Similar method for
            ``(vertices[i],v)`` instead of ``(v,vertices[i])`` (the
            difference only matters for digraphs).

        """
        cdef int i = 0
        cdef int *seq = <int *>sage_malloc(n * sizeof(int))
        for 0 <= i < n:
            seq[i] = 1 if self.has_arc_unsafe(v, vertices[i]) else 0

        return seq

    cpdef list all_arcs(self, int u, int v):
        """
        Return the labels of all arcs from ``u`` to ``v``.

        INPUT:

        - ``u`` -- integer; the tail of an arc.

        - ``v`` -- integer; the head of an arc.

        OUTPUT:

        - Raise ``NotImplementedError``. This method is not implemented at the
          :class:`CGraph` level. A child class should provide a suitable
          implementation.

        .. SEEALSO::

            - :meth:`all_arcs <sage.graphs.base.sparse_graph.SparseGraph.all_arcs>`
              -- ``all_arcs`` method for sparse graphs.

        EXAMPLE::

            sage: from sage.graphs.base.c_graph import CGraph
            sage: G = CGraph()
            sage: G.all_arcs(0, 1)
            Traceback (most recent call last):
            ...
            NotImplementedError
        """
        raise NotImplementedError()

    cpdef list in_neighbors(self, int v):
        """
        Gives the in-neighbors of the vertex ``v``.

        INPUT:

        - ``v`` -- integer representing a vertex of this graph.

        OUTPUT:

        - Raise ``NotImplementedError``. This method is not implemented at
          the :class:`CGraph` level. A child class should provide a suitable
          implementation.

        .. SEEALSO::

            - :meth:`in_neighbors <sage.graphs.base.sparse_graph.SparseGraph.in_neighbors>`
              -- ``in_neighbors`` method for sparse graphs.

            - :meth:`in_neighbors <sage.graphs.base.dense_graph.DenseGraph.in_neighbors>`
              -- ``in_neighbors`` method for dense graphs.

        EXAMPLE::

            sage: from sage.graphs.base.c_graph import CGraph
            sage: G = CGraph()
            sage: G.in_neighbors(0)
            Traceback (most recent call last):
            ...
            NotImplementedError
        """
        raise NotImplementedError()

    cpdef list out_neighbors(self, int u):
        """
        Gives the out-neighbors of the vertex ``u``.

        INPUT:

        - ``u`` -- integer representing a vertex of this graph.

        OUTPUT:

        - Raise ``NotImplementedError``. This method is not implemented at the
          :class:`CGraph` level. A child class should provide a suitable
          implementation.

        .. SEEALSO::

            - :meth:`out_neighbors <sage.graphs.base.sparse_graph.SparseGraph.out_neighbors>`
              -- ``out_neighbors`` implementation for sparse graphs.

            - :meth:`out_neighbors <sage.graphs.base.dense_graph.DenseGraph.out_neighbors>`
              -- ``out_neighbors`` implementation for dense graphs.

        EXAMPLE::

            sage: from sage.graphs.base.c_graph import CGraph
            sage: G = CGraph()
            sage: G.out_neighbors(0)
            Traceback (most recent call last):
            ...
            NotImplementedError
        """
        raise NotImplementedError()

    def _in_degree(self, int v):
        """
        Return the number of edges coming into ``v``.

        INPUT:

        - ``v`` -- a vertex of this graph.

        OUTPUT:

        - The number of in-neighbors of ``v``.

        EXAMPLE::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: SparseGraph(7)._in_degree(3)
            0

        TEST::

            sage: g = Graph({1: [2,5], 2: [1,5,3,4], 3: [2,5], 4: [3], 5: [2,3]}, implementation="c_graph")
            sage: g._backend.degree(5, False)
            3
        """
        if not self.has_vertex(v):
            raise RuntimeError("Vertex (%d) is not a vertex of the graph." % v)
        return self.in_degrees[v]

    def _out_degree(self, int v):
        """
        Return the number of edges coming out of ``v``.

        INPUT:

        - ``v`` -- a vertex of this graph.

        OUTPUT:

        - The number of out-neighbors of ``v``.

        EXAMPLE::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: SparseGraph(7)._out_degree(3)
            0
        """
        if not self.has_vertex(v):
            raise RuntimeError("Vertex (%d) is not a vertex of the graph." % v)
        return self.out_degrees[v]

    def _num_verts(self):
        """
        Return the number of vertices in the (di)graph.

        INPUT:

        - None.

        OUTPUT:

        - The order of this graph.

        EXAMPLE::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: SparseGraph(7)._num_verts()
            7
        """
        return self.num_verts

    def _num_arcs(self):
        """
        Return the number of arcs in ``self``.

        INPUT:

        - None.

        OUTPUT:

        - The size of this graph.

        EXAMPLE::

            sage: from sage.graphs.base.sparse_graph import SparseGraph
            sage: SparseGraph(7)._num_arcs()
            0
        """
        return self.num_arcs

cdef int get_vertex(object u, dict vertex_ints, dict vertex_labels,
                    CGraph G) except ? -2:
    """
    Returns an int representing the arbitrary hashable vertex u (whether or not
    u is actually in the graph), or -1 if a new association must be made for u
    to be a vertex.

    TESTS:

    We check that the bug described in #8406 is gone::

        sage: G = Graph()
        sage: R.<a> = GF(3**3)
        sage: S.<x> = R[]
        sage: G.add_vertex(a**2)
        sage: G.add_vertex(x)
        sage: G.vertices()
        [a^2, x]

    And that the bug described in #9610 is gone::

        sage: n = 20
        sage: k = 3
        sage: g = DiGraph()
        sage: g.add_edges( (i,Mod(i+j,n)) for i in range(n) for j in range(1,k+1) )
        sage: g.vertices()
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
        sage: g.strongly_connected_components()
        [[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]]

    """
    cdef int u_int
    if u in vertex_ints:
        return vertex_ints[u]
    try:
        u_int = u
    except:
        return -1
    if u_int < 0 or u_int >= G.active_vertices.size or u_int in vertex_labels:
        return -1
    return u_int

cdef object vertex_label(int u_int, dict vertex_ints, dict vertex_labels,
                         CGraph G):
    """
    Returns the object represented by u_int, or None if this does not represent
    a vertex.
    """
    if u_int in vertex_labels:
        return vertex_labels[u_int]
    elif bitset_in(G.active_vertices, u_int):
        return u_int
    else:
        return None

cdef int check_vertex(object u, dict vertex_ints, dict vertex_labels,
                      CGraph G, CGraph G_rev, bint reverse) except ? -1:
    """
    Returns an int representing the arbitrary hashable vertex u, and updates,
    if necessary, the translation dict and list. Adds a vertex if the label
    is new.
    """
    cdef int u_int = get_vertex(u, vertex_ints, vertex_labels, G)
    if u_int != -1:
        if not bitset_in(G.active_vertices, u_int):
            bitset_add(G.active_vertices, u_int)
            G.num_verts += 1
            if reverse:
                bitset_add(G_rev.active_vertices, u_int)
                G_rev.num_verts += 1
        return u_int
    u_int = bitset_first_in_complement(G.active_vertices)
    if u_int == -1:
        G.realloc(2*G.active_vertices.size)
        if reverse:
            G_rev.realloc(2*G_rev.active_vertices.size)
        return check_vertex(u, vertex_ints, vertex_labels, G, G_rev, reverse)
    vertex_labels[u_int] = u
    vertex_ints[u] = u_int
    G.add_vertex(u_int)
    if reverse:
        G_rev.add_vertex(u_int)
    return u_int

class CGraphBackend(GenericGraphBackend):
    """
    Base class for sparse and dense graph backends.

    ::

        sage: from sage.graphs.base.c_graph import CGraphBackend

    This class is extended by
    :class:`SparseGraphBackend <sage.graphs.base.sparse_graph.SparseGraphBackend>`
    and
    :class:`DenseGraphBackend <sage.graphs.base.dense_graph.DenseGraphBackend>`,
    which are fully functional backends. This class is mainly just for vertex
    functions, which are the same for both. A :class:`CGraphBackend` will not
    work on its own::

        sage: from sage.graphs.base.c_graph import CGraphBackend
        sage: CGB = CGraphBackend()
        sage: CGB.degree(0, True)
        Traceback (most recent call last):
        ...
        AttributeError: 'CGraphBackend' object has no attribute 'vertex_ints'

    The appropriate way to use these backends is via Sage graphs::

        sage: G = Graph(30, implementation="c_graph")
        sage: G.add_edges([(0,1), (0,3), (4,5), (9, 23)])
        sage: G.edges(labels=False)
        [(0, 1), (0, 3), (4, 5), (9, 23)]

    .. SEEALSO::

        - :class:`SparseGraphBackend <sage.graphs.base.sparse_graph.SparseGraphBackend>`
          -- backend for sparse graphs.

        - :class:`DenseGraphBackend <sage.graphs.base.dense_graph.DenseGraphBackend>`
          -- backend for dense graphs.
    """

    _cg = None
    _cg_rev = None
    _directed = None

    def has_vertex(self, v):
        """
        Returns whether ``v`` is a vertex of ``self``.

        INPUT:

        - ``v`` -- any object.

        OUTPUT:

        - ``True`` if ``v`` is a vertex of this graph; ``False`` otherwise.

        EXAMPLE::

            sage: from sage.graphs.base.sparse_graph import SparseGraphBackend
            sage: B = SparseGraphBackend(7)
            sage: B.has_vertex(6)
            True
            sage: B.has_vertex(7)
            False
        """
        cdef v_int = get_vertex(v, self.vertex_ints, self.vertex_labels,
                                self._cg)
        if v_int == -1:
            return False
        if not bitset_in((<CGraph>self._cg).active_vertices, v_int):
            return False
        return True

    def degree(self, v, directed):
        """
        Return the degree of the vertex ``v``.

        INPUT:

        - ``v`` -- a vertex of the graph.

        - ``directed`` -- boolean; whether to take into account the
          orientation of this graph in counting the degree of ``v``.

        OUTPUT:

        - The degree of vertex ``v``.

        EXAMPLE::

            sage: from sage.graphs.base.sparse_graph import SparseGraphBackend
            sage: B = SparseGraphBackend(7)
            sage: B.degree(3, False)
            0

        TESTS:

        Ensure that ticket #8395 is fixed. ::

            sage: def my_add_edges(G, m, n):
            ...       for i in range(m):
            ...           u = randint(0, n)
            ...           v = randint(0, n)
            ...           G.add_edge(u, v)
            sage: G = Graph({1:[1]}); G
            Looped graph on 1 vertex
            sage: G.edges(labels=False)
            [(1, 1)]
            sage: G.degree(); G.size()
            [2]
            1
            sage: sum(G.degree()) == 2 * G.size()
            True
            sage: G = Graph({1:[1,2], 2:[2,3]}, loops=True); G
            Looped graph on 3 vertices
            sage: my_add_edges(G, 100, 50)
            sage: sum(G.degree()) == 2 * G.size()
            True
            sage: G = Graph({1:[2,2], 2:[3]}); G
            Multi-graph on 3 vertices
            sage: G.edges(labels=False)
            [(1, 2), (1, 2), (2, 3)]
            sage: G.degree(); G.size()
            [2, 3, 1]
            3
            sage: sum(G.degree()) == 2 * G.size()
            True
            sage: G.allow_loops(True); G
            Looped multi-graph on 3 vertices
            sage: my_add_edges(G, 100, 50)
            sage: sum(G.degree()) == 2 * G.size()
            True
            sage: D = DiGraph({1:[2], 2:[1,3]}); D
            Digraph on 3 vertices
            sage: D.edges(labels=False)
            [(1, 2), (2, 1), (2, 3)]
            sage: D.degree(); D.size()
            [2, 3, 1]
            3
            sage: sum(D.degree()) == 2 * D.size()
            True
            sage: D.allow_loops(True); D
            Looped digraph on 3 vertices
            sage: my_add_edges(D, 100, 50)
            sage: sum(D.degree()) == 2 * D.size()
            True
            sage: D.allow_multiple_edges(True)
            sage: my_add_edges(D, 200, 50)
            sage: sum(D.degree()) == 2 * D.size()
            True
            sage: G = Graph({1:[2,2,2]})
            sage: G.allow_loops(True)
            sage: G.add_edge(1,1)
            sage: G.add_edge(1,1)
            sage: G.edges(labels=False)
            [(1, 1), (1, 1), (1, 2), (1, 2), (1, 2)]
            sage: G.degree(1)
            7
            sage: G.allow_loops(False)
            sage: G.edges(labels=False)
            [(1, 2), (1, 2), (1, 2)]
            sage: G.degree(1)
            3
            sage: G = Graph({1:{2:['a','a','a']}})
            sage: G.allow_loops(True)
            sage: G.add_edge(1,1,'b')
            sage: G.add_edge(1,1,'b')
            sage: G.add_edge(1,1)
            sage: G.add_edge(1,1)
            sage: G.edges()
            [(1, 1, None), (1, 1, None), (1, 1, 'b'), (1, 1, 'b'), (1, 2, 'a'), (1, 2, 'a'), (1, 2, 'a')]
            sage: G.degree(1)
            11
            sage: G.allow_loops(False)
            sage: G.edges()
            [(1, 2, 'a'), (1, 2, 'a'), (1, 2, 'a')]
            sage: G.degree(1)
            3
            sage: G = Graph({1:{2:['a','a','a']}})
            sage: G.allow_loops(True)
            sage: G.add_edge(1,1,'b')
            sage: G.add_edge(1,1,'b')
            sage: G.edges()
            [(1, 1, 'b'), (1, 1, 'b'), (1, 2, 'a'), (1, 2, 'a'), (1, 2, 'a')]
            sage: G.degree(1)
            7
            sage: G.allow_loops(False)
            sage: G.edges()
            [(1, 2, 'a'), (1, 2, 'a'), (1, 2, 'a')]
            sage: G.degree(1)
            3

        """
        cdef v_int = get_vertex(v,
                                self.vertex_ints,
                                self.vertex_labels,
                                self._cg)
        if directed:
            return self._cg._in_degree(v_int) + self._cg._out_degree(v_int)
        d = 0
        if self._loops and self.has_edge(v, v, None):
            if self._multiple_edges:
                d += len(self.get_edge_label(v, v))
            else:
                d += 1
        return self._cg._out_degree(v_int) + d

    def add_vertex(self, object name):
        """
        Add a vertex to ``self``.

        INPUT:

        - ``name`` -- the vertex to be added (must be hashable).

        OUTPUT:

        - None.

        .. SEEALSO::

            - :meth:`add_vertices`
              -- add a bunch of vertices of this graph.

            - :meth:`has_vertex`
              -- returns whether or not this graph has a specific vertex.

        EXAMPLE::

            sage: D = sage.graphs.base.dense_graph.DenseGraphBackend(9)
            sage: D.add_vertex(10)
            sage: D.add_vertex([])
            Traceback (most recent call last):
            ...
            TypeError: unhashable type: 'list'

        ::

            sage: S = sage.graphs.base.sparse_graph.SparseGraphBackend(9)
            sage: S.add_vertex(10)
            sage: S.add_vertex([])
            Traceback (most recent call last):
            ...
            TypeError: unhashable type: 'list'
        """
        if name is None:
            name = 0
            while name in self.vertex_ints or (
                name not in self.vertex_labels and
                bitset_in((<CGraph>self._cg).active_vertices, name)):
                name += 1
        check_vertex(name,
                     self.vertex_ints,
                     self.vertex_labels,
                     self._cg,
                     self._cg_rev,
                     (self._directed and
                      self._cg_rev is not None)) # this will add the vertex

    def add_vertices(self, object vertices):
        """
        Add vertices to ``self``.

        INPUT:

        - ``vertices`` -- iterator of vertex labels.

        OUTPUT:

        - None.

        .. SEEALSO::

            - :meth:`add_vertex`
              -- add a vertex to this graph.

        EXAMPLE::

            sage: D = sage.graphs.base.sparse_graph.SparseGraphBackend(1)
            sage: D.add_vertices([1,2,3])

        ::

            sage: G = sage.graphs.base.sparse_graph.SparseGraphBackend(0)
            sage: G.add_vertices([0,1])
            sage: list(G.iterator_verts(None))
            [0, 1]
            sage: list(G.iterator_edges([0,1], True))
            []

        ::

            sage: import sage.graphs.base.dense_graph
            sage: D = sage.graphs.base.dense_graph.DenseGraphBackend(9)
            sage: D.add_vertices([10,11,12])
        """
        cdef object v
        for v in vertices:
            self.add_vertex(v)

    def del_vertex(self, v):
        """
        Delete a vertex in ``self``, failing silently if the vertex is not
        in the graph.

        INPUT:

        - ``v`` -- vertex to be deleted.

        OUTPUT:

        - None.

        .. SEEALSO::

            - :meth:`del_vertices`
              -- delete a bunch of vertices from this graph.

        EXAMPLE::

            sage: D = sage.graphs.base.dense_graph.DenseGraphBackend(9)
            sage: D.del_vertex(0)
            sage: D.has_vertex(0)
            False

        ::

            sage: S = sage.graphs.base.sparse_graph.SparseGraphBackend(9)
            sage: S.del_vertex(0)
            sage: S.has_vertex(0)
            False
        """
        if not self.has_vertex(v):
            return
        cdef int v_int = get_vertex(v,
                                    self.vertex_ints,
                                    self.vertex_labels,
                                    self._cg)

        # delete each arc incident with v and v
        self._cg.del_vertex(v_int)
        if self._cg_rev is not None:
            self._cg_rev.del_vertex(v_int)

        # add v to unused vertices
        if v_int in self.vertex_labels:
            self.vertex_ints.pop(v)
            self.vertex_labels.pop(v_int)

    def del_vertices(self, vertices):
        """
        Delete vertices from an iterable container.

        INPUT:

        - ``vertices`` -- iterator of vertex labels.

        OUTPUT:

        - Same as for :meth:`del_vertex`.

        .. SEEALSO::

            - :meth:`del_vertex`
              -- delete a vertex of this graph.

        EXAMPLE::

            sage: import sage.graphs.base.dense_graph
            sage: D = sage.graphs.base.dense_graph.DenseGraphBackend(9)
            sage: D.del_vertices([7,8])
            sage: D.has_vertex(7)
            False
            sage: D.has_vertex(6)
            True

        ::

            sage: D = sage.graphs.base.sparse_graph.SparseGraphBackend(9)
            sage: D.del_vertices([1,2,3])
            sage: D.has_vertex(1)
            False
            sage: D.has_vertex(0)
            True
        """
        cdef object v
        for v in vertices:
            self.del_vertex(v)

    def iterator_nbrs(self, v):
        """
        Returns an iterator over the neighbors of ``v``.

        INPUT:

        - ``v`` -- a vertex of this graph.

        OUTPUT:

        - An iterator over the neighbors the vertex ``v``.

        .. SEEALSO::

            - :meth:`iterator_in_nbrs`
              -- returns an iterator over the in-neighbors of a vertex.

            - :meth:`iterator_out_nbrs`
              -- returns an iterator over the out-neighbors of a vertex.

            - :meth:`iterator_verts`
              -- returns an iterator over a given set of vertices.

        EXAMPLE::

            sage: P = Graph(graphs.PetersenGraph(), implementation="c_graph")
            sage: list(P._backend.iterator_nbrs(0))
            [1, 4, 5]
        """
        return iter(set(self.iterator_in_nbrs(v)) |
                    set(self.iterator_out_nbrs(v)))

    def iterator_in_nbrs(self, v):
        """
        Returns an iterator over the incoming neighbors of ``v``.

        INPUT:

        - ``v`` -- a vertex of this graph.

        OUTPUT:

        - An iterator over the in-neighbors of the vertex ``v``.

        .. SEEALSO::

            - :meth:`iterator_nbrs`
              -- returns an iterator over the neighbors of a vertex.

            - :meth:`iterator_out_nbrs`
              -- returns an iterator over the out-neighbors of a vertex.

        EXAMPLE::

            sage: P = DiGraph(graphs.PetersenGraph().to_directed(), implementation="c_graph")
            sage: list(P._backend.iterator_in_nbrs(0))
            [1, 4, 5]
        """
        cdef int u_int
        cdef int v_int = get_vertex(v,
                                    self.vertex_ints,
                                    self.vertex_labels,
                                    self._cg)
        # Sparse
        if self._cg_rev is not None:
            return iter([vertex_label(u_int,
                                      self.vertex_ints,
                                      self.vertex_labels,
                                      self._cg)
                         for u_int in self._cg_rev.out_neighbors(v_int)])
        # Dense
        else:
            return iter([vertex_label(u_int,
                                      self.vertex_ints,
                                      self.vertex_labels,
                                      self._cg)
                         for u_int in self._cg.in_neighbors(v_int)])

    def iterator_out_nbrs(self, v):
        """
        Returns an iterator over the outgoing neighbors of ``v``.

        INPUT:

        - ``v`` -- a vertex of this graph.

        OUTPUT:

        - An iterator over the out-neighbors of the vertex ``v``.

        .. SEEALSO::

            - :meth:`iterator_nbrs`
              -- returns an iterator over the neighbors of a vertex.

            - :meth:`iterator_in_nbrs`
              -- returns an iterator over the in-neighbors of a vertex.

        EXAMPLE::

            sage: P = DiGraph(graphs.PetersenGraph().to_directed(), implementation="c_graph")
            sage: list(P._backend.iterator_out_nbrs(0))
            [1, 4, 5]
        """
        cdef u_int
        cdef int v_int = get_vertex(v,
                                    self.vertex_ints,
                                    self.vertex_labels,
                                    self._cg)
        return iter([vertex_label(u_int,
                                  self.vertex_ints,
                                  self.vertex_labels,
                                  self._cg)
                     for u_int in self._cg.out_neighbors(v_int)])

    def iterator_verts(self, verts=None):
        """
        Returns an iterator over the vertices of ``self`` intersected with
        ``verts``.

        INPUT:

        - ``verts`` -- an iterable container of objects (default: ``None``).

        OUTPUT:

        - If ``verts=None``, return an iterator over all vertices of this
          graph.

        - If ``verts`` is an iterable container of vertices, find the
          intersection of ``verts`` with the vertex set of this graph and
          return an iterator over the resulting intersection.

        .. SEEALSO::

            - :meth:`iterator_nbrs`
              -- returns an iterator over the neighbors of a vertex.

        EXAMPLE::

            sage: P = Graph(graphs.PetersenGraph(), implementation="c_graph")
            sage: list(P._backend.iterator_verts(P))
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            sage: list(P._backend.iterator_verts())
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
            sage: list(P._backend.iterator_verts([1, 2, 3]))
            [1, 2, 3]
            sage: list(P._backend.iterator_verts([1, 2, 10]))
            [1, 2]
        """
        cdef int i
        cdef object v
        if verts is None:
            S = set(self.vertex_ints.iterkeys())
            for i from 0 <= i < (<CGraph>self._cg).active_vertices.size:
                if (i not in self.vertex_labels and
                    bitset_in((<CGraph>self._cg).active_vertices, i)):
                    S.add(i)
            return iter(S)
        is_hashable = False
        try:
            v = hash(verts)
            is_hashable = True
        except:
            pass
        if is_hashable and self.has_vertex(verts):
            return iter([verts])
        else:
            L = []
            for v in verts:
                if self.has_vertex(v):
                    L.append(v)
            return iter(L)

    def loops(self, new=None):
        """
        Returns whether loops are allowed in this graph.

        INPUT:

        - ``new`` -- (default: ``None``); boolean (to set) or ``None``
          (to get).

        OUTPUT:

        - If ``new=None``, return ``True`` if this graph allows self-loops or
          ``False`` if self-loops are not allowed.

        - If ``new`` is a boolean, set the self-loop permission of this graph
          according to the boolean value of ``new``.

        EXAMPLE::

            sage: G = Graph(implementation='c_graph')
            sage: G._backend.loops()
            False
            sage: G._backend.loops(True)
            sage: G._backend.loops()
            True
        """
        if new is None:
            return self._loops
        if new:
            self._loops = True
        else:
            self._loops = False

    def name(self, new=None):
        """
        Returns the name of this graph.

        INPUT:

        - ``new`` -- (default: ``None``); boolean (to set) or ``None``
          (to get).

        OUTPUT:

        - If ``new=None``, return the name of this graph. Otherwise, set the
          name of this graph to the value of ``new``.

        EXAMPLE::

            sage: G = Graph(graphs.PetersenGraph(), implementation="c_graph")
            sage: G._backend.name()
            'Petersen graph'
            sage: G._backend.name("Peter Pan's graph")
            sage: G._backend.name()
            "Peter Pan's graph"
        """
        if new is None:
            return self._name
        self._name = new

    def num_edges(self, directed):
        """
        Returns the number of edges in ``self``.

        INPUT:

        - ``directed`` -- boolean; whether to count ``(u,v)`` and ``(v,u)``
          as one or two edges.

        OUTPUT:

        - If ``directed=True``, counts the number of directed edges in this
          graph. Otherwise, return the size of this graph.

        .. SEEALSO::

            - :meth:`num_verts`
              -- return the order of this graph.

        EXAMPLE::

            sage: G = Graph(graphs.PetersenGraph(), implementation="c_graph")
            sage: G._backend.num_edges(False)
            15

        TESTS:

        Ensure that ticket #8395 is fixed. ::

            sage: G = Graph({1:[1]}); G
            Looped graph on 1 vertex
            sage: G.edges(labels=False)
            [(1, 1)]
            sage: G.size()
            1
            sage: G = Graph({1:[2,2]}); G
            Multi-graph on 2 vertices
            sage: G.edges(labels=False)
            [(1, 2), (1, 2)]
            sage: G.size()
            2
            sage: G = Graph({1:[1,1]}); G
            Looped multi-graph on 1 vertex
            sage: G.edges(labels=False)
            [(1, 1), (1, 1)]
            sage: G.size()
            2
            sage: D = DiGraph({1:[1]}); D
            Looped digraph on 1 vertex
            sage: D.edges(labels=False)
            [(1, 1)]
            sage: D.size()
            1
            sage: D = DiGraph({1:[2,2], 2:[1,1]}); D
            Multi-digraph on 2 vertices
            sage: D.edges(labels=False)
            [(1, 2), (1, 2), (2, 1), (2, 1)]
            sage: D.size()
            4
            sage: D = DiGraph({1:[1,1]}); D
            Looped multi-digraph on 1 vertex
            sage: D.edges(labels=False)
            [(1, 1), (1, 1)]
            sage: D.size()
            2
            sage: from sage.graphs.base.sparse_graph import SparseGraphBackend
            sage: S = SparseGraphBackend(7)
            sage: S.num_edges(directed=False)
            0
            sage: S.loops(True)
            sage: S.add_edge(1, 1, None, directed=False)
            sage: S.num_edges(directed=False)
            1
            sage: S.multiple_edges(True)
            sage: S.add_edge(1, 1, None, directed=False)
            sage: S.num_edges(directed=False)
            2
            sage: from sage.graphs.base.dense_graph import DenseGraphBackend
            sage: D = DenseGraphBackend(7)
            sage: D.num_edges(directed=False)
            0
            sage: D.loops(True)
            sage: D.add_edge(1, 1, None, directed=False)
            sage: D.num_edges(directed=False)
            1
        """
        if directed:
            return self._cg._num_arcs()
        else:
            i = self._cg._num_arcs()
            k = 0
            if self.loops(None):
                if self.multiple_edges(None):
                    for j in self.iterator_verts():
                        if self.has_edge(j, j, None):
                            k += len(self.get_edge_label(j, j))
                else:
                    for j in self.iterator_verts():
                        if self.has_edge(j, j, None):
                            k += 1
            i = (i - k) / 2
            return i + k

    def num_verts(self):
        """
        Returns the number of vertices in ``self``.

        INPUT:

        - None.

        OUTPUT:

        - The order of this graph.

        .. SEEALSO::

            - :meth:`num_edges`
              -- return the number of (directed) edges in this graph.

        EXAMPLE::

            sage: G = Graph(graphs.PetersenGraph(), implementation="c_graph")
            sage: G._backend.num_verts()
            10
        """
        return (<CGraph>self._cg).num_verts

    def relabel(self, perm, directed):
        """
        Relabels the graph according to ``perm``.

        INPUT:

        - ``perm`` -- anything which represents a permutation as
          ``v --> perm[v]``, for example a dict or a list.

        - ``directed`` -- ignored (this is here for compatibility with other
          backends).

        EXAMPLES::

            sage: G = Graph(graphs.PetersenGraph(), implementation="c_graph")
            sage: G._backend.relabel(range(9,-1,-1), False)
            sage: G.edges()
            [(0, 2, None),
             (0, 3, None),
             (0, 5, None),
             (1, 3, None),
             (1, 4, None),
             (1, 6, None),
             (2, 4, None),
             (2, 7, None),
             (3, 8, None),
             (4, 9, None),
             (5, 6, None),
             (5, 9, None),
             (6, 7, None),
             (7, 8, None),
             (8, 9, None)]
        """
        cdef int i
        cdef object v
        cdef dict new_vx_ints = {}
        cdef dict new_vx_labels = {}
        for v in self.iterator_verts(None):
            i = get_vertex(v, self.vertex_ints, self.vertex_labels, self._cg)
            new_vx_ints[perm[v]] = i
            new_vx_labels[i] = perm[v]
        self.vertex_ints = new_vx_ints
        self.vertex_labels = new_vx_labels

    def shortest_path(self, x, y):
        r"""
        Returns the shortest path between ``x`` and ``y``.

        INPUT:

        - ``x`` -- the starting vertex in the shortest path from ``x`` to
          ``y``.

        - ``y`` -- the end vertex in the shortest path from ``x`` to ``y``.

        OUTPUT:

        - A list of vertices in the shortest path from ``x`` to ``y``.

        EXAMPLE::

            sage: G = Graph(graphs.PetersenGraph(), implementation="c_graph")
            sage: G.shortest_path(0, 1)
            [0, 1]
        """
        if x == y:
            return 0

        # The function being mostly symmetric in x and y, their roles are
        # reversed at the end of each loop. For this reason is defined, for
        # example, two dictionaries dist_y and dist_x containing the distances
        # to x and y, and a dictionary dist_current and dist_other, pointing
        # toward the previous two, alternatively.
        #
        # Besides, there is another difference in the fact that for directed
        # graphs we are interested in paths leaving x toward y, so we are
        # considering the out_neighbors on x's side, and in_neighbors on
        # y's side.

        cdef int x_int = get_vertex(x,
                                    self.vertex_ints,
                                    self.vertex_labels,
                                    self._cg)
        cdef int y_int = get_vertex(y,
                                    self.vertex_ints,
                                    self.vertex_labels,
                                    self._cg)
        cdef int u = 0
        cdef int v = 0
        cdef int w = 0

        # Each vertex knows its predecessors in the search, for each side
        cdef dict pred_x = {}
        cdef dict pred_y = {}
        cdef dict pred_current = pred_x
        cdef dict pred_other = pred_y

        # Stores the distances from x and y
        cdef dict dist_x = {}
        cdef dict dist_y = {}
        cdef dict dist_current = dist_x
        cdef dict dist_other = dist_y
        dist_x[x_int] = 0
        dist_y[y_int] = 0

        # Lists of vertices whose neighbors have not been explored yet
        cdef list next_x = [x_int]
        cdef list next_y = [y_int]
        cdef list next_current = next_x
        cdef list next_other = next_y
        cdef list next_temporary = []
        cdef list neighbors

        cdef list shortest_path = []

        # We are interested in edges leaving x and entering y, so we
        # are dealing with two different "neighbors" functions
        cdef int out = 1

        # As long as the current side (x or y) is not totally explored ...
        while next_current:
            next_temporary = []

            # Take the next vertex in the list, and study all of its neighbors.
            # When a new neighbor is found, it is added into a temporary list.
            # When all the vertices in the list are tested
            # and next_current is replaced by the temporary list
            #
            # After this, current and other are reversed, and the loop restarts
            for u in next_current:
                if out == 1:
                    neighbors = self._cg.out_neighbors(u)
                elif self._cg_rev is not None: # Sparse
                    neighbors = self._cg_rev.out_neighbors(u)
                else: # Dense
                    neighbors = self._cg.in_neighbors(u)
                for v in neighbors:
                    # If the neighbor is new, updates the distances and adds
                    # to the list.
                    if v not in dist_current:
                        dist_current[v] = dist_current[u] + 1
                        pred_current[v] = u
                        next_current.append(v)

                        # If the new neighbor is already known by the other
                        # side ...
                        if v in dist_other:
                            # build the shortest path and returns in.
                            w = v

                            while w != x_int:
                                shortest_path.append(
                                    vertex_label(w,
                                                 self.vertex_ints,
                                                 self.vertex_labels,
                                                 self._cg))
                                w = pred_x[w]

                            shortest_path.append(x)
                            shortest_path.reverse()

                            if v == y_int:
                                return shortest_path

                            w = pred_y[v]
                            while w != y_int:
                                shortest_path.append(
                                    vertex_label(w,
                                                 self.vertex_ints,
                                                 self.vertex_labels,
                                                 self._cg))
                                w = pred_y[w]
                            shortest_path.append(y)

                            return shortest_path

            next_current = next_temporary
            pred_current, pred_other = pred_other, pred_current
            dist_current, dist_other = dist_other, dist_current
            next_current, next_other = next_other, next_current
            out = -out

        return []

    def bidirectional_dijkstra(self, x, y):
        r"""
        Returns the shortest path between ``x`` and ``y`` using a
        bidirectional version of Dijkstra's algorithm.

        INPUT:

        - ``x`` -- the starting vertex in the shortest path from ``x`` to
          ``y``.

        - ``y`` -- the end vertex in the shortest path from ``x`` to ``y``.

        OUTPUT:

        - A list of vertices in the shortest path from ``x`` to ``y``.

        EXAMPLE::

            sage: G = Graph(graphs.PetersenGraph(), implementation="c_graph")
            sage: for (u,v) in G.edges(labels=None):
            ...      G.set_edge_label(u,v,1)
            sage: G.shortest_path(0, 1, by_weight=True)
            [0, 1]

        TEST:

        Bugfix from #7673 ::

            sage: G = Graph(implementation="networkx")
            sage: G.add_edges([(0,1,9),(0,2,8),(1,2,7)])
            sage: Gc = G.copy(implementation='c_graph')
            sage: sp = G.shortest_path_length(0,1,by_weight=True)
            sage: spc = Gc.shortest_path_length(0,1,by_weight=True)
            sage: sp == spc
            True
        """
        if x == y:
            return 0

        # ****************** WARNING **********************
        # Use Python to maintain a heap...
        # Rewrite this in Cython as soon as possible !
        # *************************************************
        from heapq import heappush, heappop

        # As for shortest_path, the roles of x and y are symmetric, hence we
        # define dictionaries like pred_current and pred_other, which
        # represent alternatively pred_x or pred_y according to the side
        # studied.
        cdef int x_int = get_vertex(x,
                                    self.vertex_ints,
                                    self.vertex_labels,
                                    self._cg)
        cdef int y_int = get_vertex(y,
                                    self.vertex_ints,
                                    self.vertex_labels,
                                    self._cg)
        cdef int u = 0
        cdef int v = 0
        cdef int w = 0
        cdef int pred
        cdef float distance
        cdef float edge_label
        cdef int side
        cdef float f_tmp
        cdef object v_obj
        cdef object w_obj

        # Each vertex knows its predecessors in the search, for each side
        cdef dict pred_x = {}
        cdef dict pred_y = {}
        cdef dict pred_current
        cdef dict pred_other

        # Stores the distances from x and y
        cdef dict dist_x = {}
        cdef dict dist_y = {}
        cdef dict dist_current
        cdef dict dist_other

        # Lists of vertices who are left to be explored. They are represented
        # as 4-tuples: (distance, side, predecessor ,name).
        # 1 indicates x's side, -1 indicates y's, the distance being
        # defined relatively.
        cdef list queue = [(0, 1, x_int, x_int), (0, -1, y_int, y_int)]
        cdef list neighbors

        cdef list shortest_path = []

        # Meeting_vertex is a vertex discovered through x and through y
        # which defines the shortest path found
        # (of length shortest_path_length).
        cdef int meeting_vertex = -1
        cdef float shortest_path_length

        # As long as the current side (x or y) is not totally explored ...
        while queue:
            (distance, side, pred, v) = heappop(queue)
            if meeting_vertex != -1 and distance > shortest_path_length:
                break

            if side == 1:
                dist_current, dist_other = dist_x, dist_y
                pred_current, pred_other = pred_x, pred_y
            else:
                dist_current, dist_other = dist_y, dist_x
                pred_current, pred_other = pred_y, pred_x

            if v not in dist_current:
                pred_current[v] = pred
                dist_current[v] = distance

                if v in dist_other:
                    f_tmp = distance + dist_other[v]
                    if meeting_vertex == -1 or f_tmp < shortest_path_length:
                        meeting_vertex = v
                        shortest_path_length = f_tmp

                if side == 1:
                    neighbors = self._cg.out_neighbors(v)
                elif self._cg_rev is not None: # Sparse
                    neighbors = self._cg_rev.out_neighbors(v)
                else: # Dense
                    neighbors = self._cg.in_neighbors(v)
                for w in neighbors:
                    # If the neighbor is new, adds its non-found neighbors to
                    # the queue.
                    if w not in dist_current:
                        v_obj = vertex_label(v, self.vertex_ints, self.vertex_labels, self._cg)
                        w_obj = vertex_label(w, self.vertex_ints, self.vertex_labels, self._cg)
                        edge_label = self.get_edge_label(v_obj, w_obj) if side == 1 else self.get_edge_label(w_obj, v_obj)
                        heappush(queue, (distance + edge_label, side, v, w))

        # No meeting point has been found
        if meeting_vertex == -1:
            return []
        else:
            # build the shortest path and returns it.
            w = meeting_vertex

            while w != x_int:
                shortest_path.append(
                    vertex_label(w,
                                 self.vertex_ints,
                                 self.vertex_labels,
                                 self._cg))
                w = pred_x[w]

            shortest_path.append(x)
            shortest_path.reverse()

            if meeting_vertex == y_int:
                return shortest_path

            w = pred_y[meeting_vertex]
            while w != y_int:
                shortest_path.append(
                    vertex_label(w,
                                 self.vertex_ints,
                                 self.vertex_labels,
                                 self._cg))
                w = pred_y[w]
            shortest_path.append(y)

            return shortest_path

    def shortest_path_all_vertices(self, v, cutoff=None):
        r"""
        Returns for each vertex ``u`` a shortest  ``v-u`` path.

        INPUT:

        - ``v`` -- a starting vertex in the shortest path.

        - ``cutoff`` -- maximal distance. Longer paths will not be returned.

        OUTPUT:

        - A list which associates to each vertex ``u`` the shortest path
          between ``u`` and ``v`` if there is one.

        .. NOTE::

            The weight of edges is not taken into account.

        ALGORITHM:

        This is just a breadth-first search.

        EXAMPLES:

        On the Petersen Graph::

            sage: g = graphs.PetersenGraph()
            sage: paths = g._backend.shortest_path_all_vertices(0)
            sage: all([ len(paths[v]) == 0 or len(paths[v])-1 == g.distance(0,v) for v in g])
            True

        On a disconnected graph ::

            sage: g = 2*graphs.RandomGNP(20,.3)
            sage: paths = g._backend.shortest_path_all_vertices(0)
            sage: all([ (not paths.has_key(v) and g.distance(0,v) == +Infinity) or len(paths[v])-1 == g.distance(0,v) for v in g])
            True
        """
        cdef list current_layer
        cdef list next_layer
        cdef bitset_t seen
        cdef int v_int
        cdef int u_int
        cdef dict distances_int
        cdef dict distance
        cdef int d

        distances = {}
        d = 0

        v_int = get_vertex(v, self.vertex_ints, self.vertex_labels, self._cg)

        bitset_init(seen, (<CGraph>self._cg).active_vertices.size)
        bitset_set_first_n(seen, 0)
        bitset_add(seen, v_int)

        current_layer = [(u_int, v_int)
                         for u_int in self._cg.out_neighbors(v_int)]
        next_layer = []
        distances[v] = [v]

        while current_layer:
            if cutoff is not None and d >= cutoff:
                break

            while current_layer:
                v_int, u_int = current_layer.pop()

                if bitset_not_in(seen, v_int):
                    bitset_add(seen, v_int)
                    distances[vertex_label(v_int, self.vertex_ints, self.vertex_labels, self._cg)] = distances[vertex_label(u_int, self.vertex_ints, self.vertex_labels, self._cg)] + [vertex_label(v_int, self.vertex_ints, self.vertex_labels, self._cg)]
                    next_layer.extend([(u_int, v_int) for u_int in self._cg.out_neighbors(v_int)])

            current_layer = next_layer
            next_layer = []
            d += 1

        # If the graph is not connected, vertices which have not been
        # seen should be associated to the empty path

        #for 0 <= v_int < (<CGraph>self._cg).active_vertices.size:
        #    if bitset_in((<CGraph>self._cg).active_vertices, v_int) and not bitset_in(seen, v_int):
        #        distances[vertex_label(v_int, self.vertex_ints, self.vertex_labels, self._cg)] = []

        bitset_free(seen)
        return distances

    def depth_first_search(self, v, reverse=False, ignore_direction=False):
        r"""
        Returns a depth-first search from vertex ``v``.

        INPUT:

        - ``v`` -- a vertex from which to start the depth-first search.

        - ``reverse`` -- boolean (default: ``False``). This is only relevant
          to digraphs. If this is a digraph, consider the reversed graph in
          which the out-neighbors become the in-neighbors and vice versa.

        - ``ignore_direction`` -- boolean (default: ``False``). This is only
          relevant to digraphs. If this is a digraph, ignore all orientations
          and consider the graph as undirected.

        ALGORITHM:

        Below is a general template for depth-first search.

        - **Input:** A directed or undirected graph `G = (V, E)` of order
          `n > 0`. A vertex `s` from which to start the search. The vertices
          are numbered from 1 to `n = |V|`, i.e. `V = \{1, 2, \dots, n\}`.

        - **Output:** A list `D` of distances of all vertices from `s`. A
          tree `T` rooted at `s`.

        #. `S \leftarrow [s]`  # a stack of nodes to visit
        #. `D \leftarrow [\infty, \infty, \dots, \infty]`  # `n` copies of `\infty`
        #. `D[s] \leftarrow 0`
        #. `T \leftarrow [\,]`
        #. while `\text{length}(S) > 0` do

           #. `v \leftarrow \text{pop}(S)`
           #. for each `w \in \text{adj}(v)` do  # for digraphs, use out-neighbor set `\text{oadj}(v)`

              #. if `D[w] = \infty` then

                 #. `D[w] \leftarrow D[v] + 1`
                 #. `\text{push}(S, w)`
                 #. `\text{append}(T, vw)`
        #. return `(D, T)`

        .. SEEALSO::

            - :meth:`breadth_first_search`
              -- breadth-first search for fast compiled graphs.

            - :meth:`breadth_first_search <sage.graphs.generic_graph.GenericGraph.breadth_first_search>`
              -- breadth-first search for generic graphs.

            - :meth:`depth_first_search <sage.graphs.generic_graph.GenericGraph.depth_first_search>`
              -- depth-first search for generic graphs.

        EXAMPLES:

        Traversing the Petersen graph using depth-first search::

            sage: G = Graph(graphs.PetersenGraph(), implementation="c_graph")
            sage: list(G.depth_first_search(0))
            [0, 5, 8, 6, 9, 7, 2, 3, 4, 1]

        Visiting German cities using depth-first search::

            sage: G = Graph({"Mannheim": ["Frankfurt","Karlsruhe"],
            ...   "Frankfurt": ["Mannheim","Wurzburg","Kassel"],
            ...   "Kassel": ["Frankfurt","Munchen"],
            ...   "Munchen": ["Kassel","Nurnberg","Augsburg"],
            ...   "Augsburg": ["Munchen","Karlsruhe"],
            ...   "Karlsruhe": ["Mannheim","Augsburg"],
            ...   "Wurzburg": ["Frankfurt","Erfurt","Nurnberg"],
            ...   "Nurnberg": ["Wurzburg","Stuttgart","Munchen"],
            ...   "Stuttgart": ["Nurnberg"],
            ...   "Erfurt": ["Wurzburg"]}, implementation="c_graph")
            sage: list(G.depth_first_search("Frankfurt"))
            ['Frankfurt', 'Wurzburg', 'Nurnberg', 'Munchen', 'Kassel', 'Augsburg', 'Karlsruhe', 'Mannheim', 'Stuttgart', 'Erfurt']
        """
        return Search_iterator(self,
                               v,
                               direction=-1,
                               reverse=reverse,
                               ignore_direction=ignore_direction)

    def breadth_first_search(self, v, reverse=False, ignore_direction=False):
        r"""
        Returns a breadth-first search from vertex ``v``.

        INPUT:

        - ``v`` -- a vertex from which to start the breadth-first search.

        - ``reverse`` -- boolean (default: ``False``). This is only relevant
          to digraphs. If this is a digraph, consider the reversed graph in
          which the out-neighbors become the in-neighbors and vice versa.

        - ``ignore_direction`` -- boolean (default: ``False``). This is only
          relevant to digraphs. If this is a digraph, ignore all orientations
          and consider the graph as undirected.

        ALGORITHM:

        Below is a general template for breadth-first search.

        - **Input:** A directed or undirected graph `G = (V, E)` of order
          `n > 0`. A vertex `s` from which to start the search. The vertices
          are numbered from 1 to `n = |V|`, i.e. `V = \{1, 2, \dots, n\}`.

        - **Output:** A list `D` of distances of all vertices from `s`. A
          tree `T` rooted at `s`.

        #. `Q \leftarrow [s]`  # a queue of nodes to visit
        #. `D \leftarrow [\infty, \infty, \dots, \infty]`  # `n` copies of `\infty`
        #. `D[s] \leftarrow 0`
        #. `T \leftarrow [\,]`
        #. while `\text{length}(Q) > 0` do

           #. `v \leftarrow \text{dequeue}(Q)`
           #. for each `w \in \text{adj}(v)` do  # for digraphs, use out-neighbor set `\text{oadj}(v)`

              #. if `D[w] = \infty` then

                 #. `D[w] \leftarrow D[v] + 1`
                 #. `\text{enqueue}(Q, w)`
                 #. `\text{append}(T, vw)`
        #. return `(D, T)`

        .. SEEALSO::

            - :meth:`breadth_first_search <sage.graphs.generic_graph.GenericGraph.breadth_first_search>`
              -- breadth-first search for generic graphs.

            - :meth:`depth_first_search <sage.graphs.generic_graph.GenericGraph.depth_first_search>`
              -- depth-first search for generic graphs.

            - :meth:`depth_first_search`
              -- depth-first search for fast compiled graphs.

        EXAMPLES:

        Breadth-first search of the Petersen graph starting at vertex 0::

            sage: G = Graph(graphs.PetersenGraph(), implementation="c_graph")
            sage: list(G.breadth_first_search(0))
            [0, 1, 4, 5, 2, 6, 3, 9, 7, 8]

        Visiting German cities using breadth-first search::

            sage: G = Graph({"Mannheim": ["Frankfurt","Karlsruhe"],
            ...   "Frankfurt": ["Mannheim","Wurzburg","Kassel"],
            ...   "Kassel": ["Frankfurt","Munchen"],
            ...   "Munchen": ["Kassel","Nurnberg","Augsburg"],
            ...   "Augsburg": ["Munchen","Karlsruhe"],
            ...   "Karlsruhe": ["Mannheim","Augsburg"],
            ...   "Wurzburg": ["Frankfurt","Erfurt","Nurnberg"],
            ...   "Nurnberg": ["Wurzburg","Stuttgart","Munchen"],
            ...   "Stuttgart": ["Nurnberg"],
            ...   "Erfurt": ["Wurzburg"]}, implementation="c_graph")
            sage: list(G.breadth_first_search("Frankfurt"))
            ['Frankfurt', 'Mannheim', 'Kassel', 'Wurzburg', 'Karlsruhe', 'Munchen', 'Erfurt', 'Nurnberg', 'Augsburg', 'Stuttgart']
        """
        return Search_iterator(self,
                               v,
                               direction=0,
                               reverse=reverse,
                               ignore_direction=ignore_direction)

    def is_connected(self):
        r"""
        Returns whether the graph is connected.

        INPUT:

        - None.

        OUTPUT:

        - ``True`` if this graph is connected; ``False`` otherwise.

        EXAMPLES:

        Petersen's graph is connected::

           sage: DiGraph(graphs.PetersenGraph(),implementation="c_graph").is_connected()
           True

        While the disjoint union of two of them is not::

           sage: DiGraph(2*graphs.PetersenGraph(),implementation="c_graph").is_connected()
           False

        A graph with non-integer vertex labels::
            sage: Graph(graphs.CubeGraph(3), implementation='c_graph').is_connected()
            True
        """
        cdef int v_int = 0
        v_int = bitset_first((<CGraph>self._cg).active_vertices)

        if v_int == -1:
            return True
        v = vertex_label(v_int, self.vertex_ints, self.vertex_labels, self._cg)
        return len(list(self.depth_first_search(v, ignore_direction=True))) == (<CGraph>self._cg).num_verts

    def is_strongly_connected(self):
        r"""
        Returns whether the graph is strongly connected.

        INPUT:

        - None.

        OUTPUT:

        - ``True`` if this graph is strongly connected; ``False`` otherwise.

        EXAMPLES:

        The circuit on 3 vertices is obviously strongly connected::

            sage: g = DiGraph({0: [1], 1: [2], 2: [0]}, implementation="c_graph")
            sage: g.is_strongly_connected()
            True

        But a transitive triangle is not::

            sage: g = DiGraph({0: [1,2], 1: [2]}, implementation="c_graph")
            sage: g.is_strongly_connected()
            False
        """
        cdef int v_int = 0

        # Pick one vertex
        v_int = bitset_first((<CGraph>self._cg).active_vertices)

        if v_int == -1:
            return True

        v = vertex_label(v_int, self.vertex_ints, self.vertex_labels, self._cg)

        return (<CGraph>self._cg).num_verts == len(list(self.depth_first_search(v))) and \
            (<CGraph>self._cg).num_verts == len(list(self.depth_first_search(v, reverse=True)))

    def strongly_connected_component_containing_vertex(self, v):
        r"""
        Returns the strongly connected component containing the given vertex.

        INPUT:

        - ``v`` -- a vertex

        EXAMPLES:

        The digraph obtained from the ``PetersenGraph`` has an unique
        strongly connected component::

            sage: g = DiGraph(graphs.PetersenGraph())
            sage: g.strongly_connected_component_containing_vertex(0)
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

        In the Butterfly DiGraph, each vertex is a strongly connected
        component::

            sage: g = digraphs.ButterflyGraph(3)
            sage: all([[v] == g.strongly_connected_component_containing_vertex(v) for v in g])
            True
        """
        cdef int v_int = get_vertex(v,
                                    self.vertex_ints,
                                    self.vertex_labels,
                                    self._cg)
        cdef set a = set(self.depth_first_search(v))
        cdef set b = set(self.depth_first_search(v, reverse=True))
        return list(a & b)

    def is_directed_acyclic(self, certificate = False):
        r"""
        Returns whether the graph is both directed and acylic (possibly with a
        certificate)

        INPUT:

        - ``certificate`` -- whether to return a certificate (``False`` by
          default).

        OUTPUT:

        When ``certificate=False``, returns a boolean value. When
        ``certificate=True`` :

            * If the graph is acyclic, returns a pair ``(True, ordering)`` where
              ``ordering`` is a list of the vertices such that ``u`` appears
              before ``v`` in ``ordering`` if ``u, v`` is an edge.

            * Else, returns a pair ``(False, cycle)`` where ``cycle`` is a list
              of vertices representing a circuit in the graph.

        .. NOTE::

            The graph is assumed to be directed. An exception is raised if it is
            not.

        EXAMPLES:

        At first, the following graph is acyclic::

            sage: D = DiGraph({ 0:[1,2,3], 4:[2,5], 1:[8], 2:[7], 3:[7], 5:[6,7], 7:[8], 6:[9], 8:[10], 9:[10] })
            sage: D.plot(layout='circular').show()
            sage: D.is_directed_acyclic()
            True

        Adding an edge from `9` to `7` does not change it::

            sage: D.add_edge(9,7)
            sage: D.is_directed_acyclic()
            True

        We can obtain as a proof an ordering of the vertices such that `u`
        appears before `v` if `uv` is an edge of the graph::

            sage: D.is_directed_acyclic(certificate = True)
            (True, [4, 5, 6, 9, 0, 1, 2, 3, 7, 8, 10])

        Adding an edge from 7 to 4, though, makes a difference::

            sage: D.add_edge(7,4)
            sage: D.is_directed_acyclic()
            False

        Indeed, it creates a circuit `7, 4, 5`::

            sage: D.is_directed_acyclic(certificate = True)
            (False, [7, 4, 5])

        Checking acyclic graphs are indeed acyclic ::

            sage: def random_acyclic(n, p):
            ...    g = graphs.RandomGNP(n, p)
            ...    h = DiGraph()
            ...    h.add_edges([ ((u,v) if u<v else (v,u)) for u,v,_ in g.edges() ])
            ...    return h
            ...
            sage: all( random_acyclic(100, .2).is_directed_acyclic()    # long time
            ...        for i in range(50))                              # long time
            True
        """

        if not self._directed:
            raise ValueError("The graph should be directed !")

        # Vertices that have already been seen
        cdef bitset_t seen
        bitset_init(seen, (<CGraph>self._cg).active_vertices.size)
        bitset_set_first_n(seen, 0)

        # Activated vertices
        cdef bitset_t activated
        bitset_init(activated, (<CGraph>self._cg).active_vertices.size)
        bitset_set_first_n(activated, (<CGraph>self._cg).active_vertices.size)

        # Vertices whose neighbors have already been added to the stack
        cdef bitset_t tried
        bitset_init(tried, (<CGraph>self._cg).active_vertices.size)
        bitset_set_first_n(tried, 0)

        # Parent of a vertex in the discovery tree
        cdef dict parent = {}

        # The vertices left to be visited
        cdef list stack = []

        # Final ordering, if the graph turns out to be acyclic
        cdef list ordering = []

        # Circuit, if the graph turns out to contain one
        cdef list cycle

        # We try any vertex as the source of the exploration tree
        for v in (<CGraph>self._cg).verts():

            # We are not interested in trying de-activated vertices
            if bitset_not_in(activated, v):
                continue

            stack = [v]
            bitset_add(seen, v)

            # For as long as some vertices are to be visited
            while stack:

                # We take the last one (depth-first search)
                u = stack.pop(-1)

                # If we never tried it, we put it at the end of the stack again,
                # but remember we tried it once.
                if bitset_not_in(tried, u):
                    bitset_add(tried, u)
                    bitset_add(seen, u)
                    stack.append(u)

                # If we tried all the path starting from this vertex already, it
                # means it leads to no circuit. We can remove it, and go to the
                # next one
                else:
                    ordering.insert(0, vertex_label(u, self.vertex_ints, self.vertex_labels, self._cg))
                    bitset_discard(seen, u)
                    bitset_discard(activated, u)
                    continue

                # For each out-neighbor of the current vertex
                for uu in self._cg.out_neighbors(u):

                    # If we have found a new vertex, we put it at the end of the
                    # stack. We ignored de-activated vertices.
                    if bitset_not_in(seen, uu):
                        if bitset_in(activated, uu):
                            parent[uu] = u
                            stack.append(uu)

                    # If we have already met this vertex, it means we have
                    # found a circuit !
                    else:

                        bitset_free(seen)
                        bitset_free(activated)
                        bitset_free(tried)

                        if not certificate:
                            return False

                        # We build it, then return it
                        # // answer = [u]
                        cycle = [vertex_label(u, self.vertex_ints, self.vertex_labels, self._cg)]

                        tmp = u
                        while u != uu:
                            u = parent.get(u,uu)
                            cycle.append(vertex_label(u, self.vertex_ints, self.vertex_labels, self._cg))

                        cycle.reverse()
                        return (False, cycle)

            # Each time we have explored all the descendants of a vertex v and
            # met no circuit, we de-activate all these vertices, as we know we
            # do not need them anyway.
            for v in (<CGraph>self._cg).verts():
                if bitset_in(seen, v):
                    bitset_discard(seen, v)
                    bitset_discard(activated, v)
                    bitset_add(tried, v)

        # No Cycle... Good news ! Let's return it.
        bitset_free(seen)
        bitset_free(activated)
        bitset_free(tried)

        if certificate:
            return (True, ordering)
        else:
            return True

def floyd_warshall(gg, paths = True, distances = False):
    r"""
    Computes the shortest path/distances between all pairs of vertices.

    For more information on the Floyd-Warshall algorithm, see the `Wikipedia
    article on Floyd-Warshall
    <http://en.wikipedia.org/wiki/Floyd%E2%80%93Warshall_algorithm>`_.

    INPUT:

        - ``gg`` -- the graph on which to work.

        - ``paths`` (boolean) -- whether to return the dictionary of shortest
          paths. Set to ``True`` by default.

        - ``distances`` (boolean) -- whether to return the dictionary of
          distances. Set to ``False`` by default.

    OUTPUT:

        Depending on the input, this function return the dictionary of paths,
        the dictionary of distances, or a pair of dictionaries
        ``(distances, paths)`` where ``distance[u][v]`` denotes the distance of a
        shortest path from `u` to `v` and ``paths[u][v]`` denotes an inneighbor
        `w` of `v` such that `dist(u,v)= 1 + dist(u,w)`.

    .. WARNING::

        Because this function works on matrices whose size is quadratic compared
        to the number of vertices, it uses short variables instead of long ones
        to divide by 2 the size in memory. This means that the current
        implementation does not run on a graph of more than 65536 nodes (this
        can be easily changed if necessary, but would require much more
        memory. It may be worth writing two versions). For information, the
        current version of the algorithm on a graph with `65536=2^{16}` nodes
        creates in memory `2` tables on `2^{32}` short elements (2bytes each),
        for a total of `2^{34}` bytes or `16` gigabytes. Let us also remember
        that if the memory size is quadratic, the algorithm runs in cubic time.

    .. NOTE::

        When ``paths = False`` the algorithm saves roughly half of the memory as
        it does not have to maintain the matrix of predecessors. However,
        setting ``distances=False`` produces no such effect as the algorithm can
        not run without computing them. They will not be returned, but they will
        be stored while the method is running.

    EXAMPLES:

    Shortest paths in a small grid ::

        sage: g = graphs.Grid2dGraph(2,2)
        sage: from sage.graphs.base.c_graph import floyd_warshall
        sage: print floyd_warshall(g)
        {(0, 1): {(0, 1): None, (1, 0): (0, 0), (0, 0): (0, 1), (1, 1): (0, 1)},
        (1, 0): {(0, 1): (0, 0), (1, 0): None, (0, 0): (1, 0), (1, 1): (1, 0)},
        (0, 0): {(0, 1): (0, 0), (1, 0): (0, 0), (0, 0): None, (1, 1): (0, 1)},
        (1, 1): {(0, 1): (1, 1), (1, 0): (1, 1), (0, 0): (0, 1), (1, 1): None}}

    Checking the distances are correct ::

        sage: g = graphs.Grid2dGraph(5,5)
        sage: dist,path = floyd_warshall(g, distances = True)
        sage: all( dist[u][v] == g.distance(u,v) for u in g for v in g )
        True

    Checking a random path is valid ::

        sage: u,v = g.random_vertex(), g.random_vertex()
        sage: p = [v]
        sage: while p[0] != None:
        ...     p.insert(0,path[u][p[0]])
        sage: len(p) == dist[u][v] + 2
        True

    Distances for all pairs of vertices in a diamond::

        sage: g = graphs.DiamondGraph()
        sage: floyd_warshall(g, paths = False, distances = True)
        {0: {0: 0, 1: 1, 2: 1, 3: 2},
         1: {0: 1, 1: 0, 2: 1, 3: 1},
         2: {0: 1, 1: 1, 2: 0, 3: 1},
         3: {0: 2, 1: 1, 2: 1, 3: 0}}

    TESTS:

    Too large graphs::

        sage: from sage.graphs.base.c_graph import floyd_warshall
        sage: floyd_warshall(Graph(65536))
        Traceback (most recent call last):
        ...
        ValueError: The graph backend contains more than 65535 nodes
    """

    from sage.rings.infinity import Infinity
    cdef CGraph g = <CGraph> gg._backend._cg

    cdef list gverts = g.verts()

    cdef int n = max(gverts) + 1

    if n >= <unsigned short> -1:
        raise ValueError("The graph backend contains more than "+str(<unsigned short> -1)+" nodes")

    # All this just creates two tables prec[n][n] and dist[n][n]
    cdef unsigned short * t_prec
    cdef unsigned short * t_dist
    cdef unsigned short ** prec
    cdef unsigned short ** dist

    cdef int i
    cdef int v_int
    cdef int u_int
    cdef int w_int

    # init dist
    t_dist = <unsigned short *> sage_malloc(n*n*sizeof(short))
    dist = <unsigned short **> sage_malloc(n*sizeof(short *))
    dist[0] = t_dist
    for 1 <= i< n:
        dist[i] = dist[i-1] + n
    memset(t_dist, -1, n*n*sizeof(short))
    # Copying the adjacency matrix (vertices at distance 1)
    for v_int in gverts:
        dist[v_int][v_int] =  0
        for u_int in g.out_neighbors(v_int):
            dist[v_int][u_int] = 1

    if paths:
        # init prec
        t_prec = <unsigned short *> sage_malloc(n*n*sizeof(short))
        prec = <unsigned short **> sage_malloc(n*sizeof(short *))
        prec[0] = t_prec
        for 1 <= i< n:
            prec[i] = prec[i-1] + n
        memset(t_prec, 0, n*n*sizeof(short))
        # Copying the adjacency matrix (vertices at distance 1)
        for v_int in gverts:
            prec[v_int][v_int] = v_int
            for u_int in g.out_neighbors(v_int):
                prec[v_int][u_int] = v_int

    # The algorithm itself.
    cdef unsigned short *dv, *dw
    cdef int dvw
    cdef int val

    for w_int in gverts:
        dw = dist[w_int]
        for v_int in gverts:
            dv = dist[v_int]
            dvw = dv[w_int]
            for u_int in gverts:
                val = dvw + dw[u_int]
                # If it is shorter to go from u to v through w, do it
                if dv[u_int] > val:
                    dv[u_int] = val
                    if paths:
                        prec[v_int][u_int] = prec[w_int][u_int]

    # Dictionaries of distance, precedent element, and integers
    cdef dict d_prec
    cdef dict d_dist
    cdef dict tmp_prec
    cdef dict tmp_dist

    cdef dict ggbvi = gg._backend.vertex_ints
    cdef dict ggbvl = gg._backend.vertex_labels

    if paths: d_prec = {}
    if distances: d_dist = {}
    for v_int in gverts:
        if paths: tmp_prec = {}
        if distances: tmp_dist = {}
        v = vertex_label(v_int, ggbvi, ggbvl, g)
        dv = dist[v_int]
        for u_int in gverts:
            u = vertex_label(u_int, ggbvi, ggbvl, g)
            if paths:
                tmp_prec[u] = (None if v == u
                               else vertex_label(prec[v_int][u_int], ggbvi, ggbvl, g))
            if distances:
                tmp_dist[u] = (dv[u_int] if (dv[u_int] != <unsigned short> -1)
                               else Infinity)
        if paths: d_prec[v] = tmp_prec
        if distances: d_dist[v] = tmp_dist

    if paths:
        sage_free(t_prec)
        sage_free(prec)

    sage_free(t_dist)
    sage_free(dist)

    if distances and paths:
        return d_dist, d_prec
    if paths:
        return d_prec
    if distances:
        return d_dist

cpdef all_pairs_shortest_path_BFS(gg):
    """
    Computes the shortest path and the distances between each pair of vertices
    through successive breadth-first-searches

    OUTPUT:

        This function return a pair of dictionaries ``(distances,paths)`` where
        ``distance[u][v]`` denotes the distance of a shortest path from `u` to
        `v` and ``paths[u][v]`` denotes an inneighbor `w` of `v` such that
        `dist(u,v)= 1 + dist(u,w)`.

    .. WARNING::

        Because this function works on matrices whose size is quadratic compared
        to the number of vertices, it uses short variables instead of long ones
        to divide by 2 the size in memory. This means that the current
        implementation does not run on a graph of more than 65536 nodes (this
        can be easily changed if necessary, but would require much more
        memory. It may be worth writing two versions). For information, the
        current version of the algorithm on a graph with `65536=2^{16}` nodes
        creates in memory `2` tables on `2^{32}` short elements (2bytes each),
        for a total of `2^{34}` bytes or `16` gigabytes.

    EXAMPLE:

    On a grid::

        sage: g = graphs.Grid2dGraph(10,10)
        sage: from sage.graphs.base.c_graph import all_pairs_shortest_path_BFS
        sage: dist, path = all_pairs_shortest_path_BFS(g)
        sage: all( dist[u][v] == g.distance(u,v) for u in g for v in g )
        True

    TESTS:

    Too large graphs::

        sage: all_pairs_shortest_path_BFS(Graph(65536))
        Traceback (most recent call last):
        ...
        ValueError: The graph backend contains more than 65535 nodes

    """
    from sage.rings.infinity import Infinity

    cdef CGraph cg = <CGraph> gg._backend._cg

    cdef list vertices = cg.verts()
    cdef int n = max(vertices)+1

    if n > <unsigned short> -1:
        raise ValueError("The graph backend contains more than "+str(<unsigned short> -1)+" nodes")

    # The vertices which have already been visited
    cdef bitset_t seen
    bitset_init(seen, cg.active_vertices.size)

    # The list of waiting vertices, the beginning and the end of the list

    cdef unsigned short * waiting_list = <unsigned short *> sage_malloc(n*sizeof(short))
    cdef unsigned short waiting_beginning = 0
    cdef unsigned short waiting_end = 0

    cdef unsigned short source
    cdef unsigned short v, u

    # Dictionaries of dictionaries of distances/predecessors
    cdef dict d_distances = dict()
    cdef dict d_prec      = dict()

    # Temporary dictionaries of distances/predecessors
    cdef dict tmp_distances
    cdef dict tmp_prec

    # Temporary vectors of distances/predecessors
    cdef unsigned short * v_distances = <unsigned short *> sage_malloc(n*sizeof(short))
    cdef unsigned short * v_prec      = <unsigned short *> sage_malloc(n*sizeof(short))

    cdef dict ggbvi = gg._backend.vertex_ints
    cdef dict ggbvl = gg._backend.vertex_labels

    cdef int *outneighbors
    cdef int o_n_size
    cdef int i
    for source in vertices:
        bitset_set_first_n(seen, 0)
        bitset_add(seen, source)

        v_distances[source] = 0
        v_prec[source] = source
        waiting_list[0] = source
        waiting_beginning = 0
        waiting_end = 0

        while waiting_beginning <= waiting_end:
            v = waiting_list[waiting_beginning]
            o_n_size = cg.out_degrees[v]
            outneighbors = <int *>sage_malloc(o_n_size * sizeof(int))
            o_n_size = cg.out_neighbors_unsafe(v, outneighbors, o_n_size)
            for 0 <= i < o_n_size:
                u = outneighbors[i]
                if not bitset_in(seen, u):
                    v_distances[u] = v_distances[v]+1
                    v_prec[u] = v
                    bitset_add(seen, u)
                    waiting_end += 1
                    waiting_list[waiting_end] = u
            sage_free(outneighbors)
            waiting_beginning += 1

        tmp_distances = dict()
        tmp_prec = dict()
        for v in vertices:
            vv = vertex_label(v, ggbvi, ggbvl, cg)

            if bitset_in(seen, v):
                tmp_prec[vv] = vertex_label(v_prec[v], ggbvi, ggbvl, cg)
                tmp_distances[vv] = v_distances[v]
            else:
                tmp_prec[vv] = None
                tmp_distances[vv] = Infinity

        vv = vertex_label(source, ggbvi, ggbvl, cg)
        tmp_prec[vv] = None
        d_prec[vv] = tmp_prec
        d_distances[vv] = tmp_distances

    bitset_free(seen)
    sage_free(waiting_list)
    sage_free(v_distances)
    sage_free(v_prec)

    return d_distances, d_prec

cdef class Search_iterator:
    r"""
    An iterator for traversing a (di)graph.

    This class is commonly used to perform a depth-first or breadth-first
    search. The class does not build all at once in memory the whole list of
    visited vertices. The class maintains the following variables:

    - ``graph`` -- a graph whose vertices are to be iterated over.

    - ``direction`` -- integer; this determines the position at which
      vertices to be visited are removed from the list ``stack``. For
      breadth-first search (BFS), element removal occurs at the start of the
      list, as signified by the value ``direction=0``. This is because in
      implementations of BFS, the list of vertices to visit are usually
      maintained by a queue, so element insertion and removal follow a
      first-in first-out (FIFO) protocol. For depth-first search (DFS),
      element removal occurs at the end of the list, as signified by the value
      ``direction=-1``. The reason is that DFS is usually implemented using
      a stack to maintain the list of vertices to visit. Hence, element
      insertion and removal follow a last-in first-out (LIFO) protocol.

    - ``stack`` -- a list of vertices to visit.

    - ``seen`` -- a list of vertices that are already visited.

    - ``test_out`` -- boolean; whether we want to consider the out-neighbors
      of the graph to be traversed. For undirected graphs, we consider both
      the in- and out-neighbors. However, for digraphs we only traverse along
      out-neighbors.

    - ``test_in`` -- boolean; whether we want to consider the in-neighbors of
      the graph to be traversed. For undirected graphs, we consider both
      the in- and out-neighbors.

    EXAMPLE::

        sage: g = graphs.PetersenGraph()
        sage: list(g.breadth_first_search(0))
        [0, 1, 4, 5, 2, 6, 3, 9, 7, 8]
    """

    cdef graph
    cdef int direction
    cdef list stack
    cdef bitset_t seen
    cdef bint test_out
    cdef bint test_in

    def __init__(self, graph, v, direction=0, reverse=False,
                 ignore_direction=False):
        r"""
        Initialize an iterator for traversing a (di)graph.

        INPUT:

        - ``graph`` -- a graph to be traversed.

        - ``v`` -- a vertex in ``graph`` from which to start the traversal.

        - ``direction`` -- integer (default: ``0``). This determines the
          position at which vertices to be visited are removed from the list
          ``stack`` of vertices to visit. For breadth-first search (BFS),
          element removal occurs at the start of the list, as signified by the
          value ``direction=0``. This is because in implementations of BFS,
          the list of vertices to visit are usually maintained by a queue, so
          element insertion and removal follow a first-in first-out (FIFO)
          protocol. For depth-first search (DFS), element removal occurs at
          the end of the list, as signified by the value ``direction=-1``. The
          reason is that DFS is usually implemented using a stack to maintain
          the list of vertices to visit. Hence, element insertion and removal
          follow a last-in first-out (LIFO) protocol.

        - ``reverse`` -- boolean (default: ``False``). This is only relevant
          to digraphs. If ``graph`` is a digraph, consider the reversed graph
          in which the out-neighbors become the in-neighbors and vice versa.

        - ``ignore_direction`` -- boolean (default: ``False``). This is only
          relevant to digraphs. If ``graph`` is a digraph, ignore all
          orientations and consider the graph as undirected.

        EXAMPLE::

            sage: g = graphs.PetersenGraph()
            sage: list(g.breadth_first_search(0))
            [0, 1, 4, 5, 2, 6, 3, 9, 7, 8]
        """
        self.graph = graph
        self.direction = direction

        bitset_init(self.seen, (<CGraph>self.graph._cg).active_vertices.size)
        bitset_set_first_n(self.seen, 0)

        self.stack = [get_vertex(v,
                                 self.graph.vertex_ints,
                                 self.graph.vertex_labels,
                                 self.graph._cg)]

        if not self.graph.directed:
            ignore_direction = False

        self.test_out = (not reverse) or ignore_direction
        self.test_in = reverse or ignore_direction

    def __iter__(self):
        r"""
        Return an iterator object over a traversal of a graph.

        EXAMPLE::

            sage: g = graphs.PetersenGraph()
            sage: g.breadth_first_search(0)
            <generator object breadth_first_search at ...
        """
        return self

    def __next__(self):
        r"""
        Return the next vertex in a traversal of a graph.

        EXAMPLE::

            sage: g = graphs.PetersenGraph()
            sage: g.breadth_first_search(0)
            <generator object breadth_first_search at ...
            sage: g.breadth_first_search(0).next()
            0
        """
        cdef int v_int
        cdef int w_int

        while self.stack:
            v_int = self.stack.pop(self.direction)

            if bitset_not_in(self.seen, v_int):
                value = vertex_label(v_int,
                                     self.graph.vertex_ints,
                                     self.graph.vertex_labels,
                                     self.graph._cg)
                bitset_add(self.seen, v_int)

                if self.test_out:
                    self.stack.extend(self.graph._cg.out_neighbors(v_int))
                if self.test_in:
                    self.stack.extend(self.graph._cg.in_neighbors(v_int))

                break
        else:
            bitset_free(self.seen)
            raise StopIteration

        return value