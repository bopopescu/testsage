Matrices and Spaces of Matrices
===============================

Sage provides native support for working with matrices over any
commutative or noncommutative ring. The parent object for a matrix
is a matrix space ``MatrixSpace(R, n, m)`` of all
:math:`n\times
m` matrices over a ring :math:`R`.

To create a matrix, either use the ``matrix(...)``
function or create a matrix space using the
``MatrixSpace`` command and coerce an object into it.

Matrices also act on row vectors, which you create using the
``vector(...)`` command or by making a
``VectorSpace`` and coercing lists into it. The natural
action of matrices on row vectors is from the right. Sage currently
does not have a column vector class (on which matrices would act
from the left), but this is planned.

In addition to native Sage matrices, Sage also includes the
following additional ways to compute with matrices:

-  Several math software systems included with Sage have their own
   native matrix support, which can be used from Sage. E.g., PARI,
   GAP, Maxima, and Singular all have a notion of matrices.

-  The GSL C-library is included with Sage, and can be used via
   Cython.

-  The ``scipy`` module provides support for
   *sparse* numerical linear algebra, among many other things.

-  The ``numpy`` module, which you load by typing
   ``import numpy`` is included standard with Sage. It
   contains a very sophisticated and well developed array class, plus
   optimized support for *numerical linear algebra*.  Sage's matrices
   over RDF and CDF (native floating-point real and complex numbers)
   use numpy.

Finally, this module contains some data-structures for matrix-like
objects like operation tables (e.g. the multiplication table of a group).

.. toctree::
   :maxdepth: 2

   sage/matrix/matrix_space

   sage/matrix/constructor

   sage/matrix/docs

   sage/matrix/matrix

   sage/matrix/matrix0

   sage/matrix/matrix1

   sage/matrix/matrix2

   sage/matrix/strassen

   sage/matrix/berlekamp_massey

   sage/matrix/matrix_dense
   sage/matrix/matrix_sparse

   sage/matrix/matrix_generic_dense
   sage/matrix/matrix_generic_sparse

   sage/matrix/matrix_modn_dense
   sage/matrix/matrix_modn_sparse

   sage/matrix/matrix_symbolic_dense

   sage/matrix/matrix_integer_dense

   sage/matrix/matrix_rational_dense

   sage/matrix/matrix_double_dense

   sage/matrix/matrix_real_double_dense

   sage/matrix/matrix_complex_double_dense

   sage/matrix/operation_table

   sage/matrix/benchmark

.. include:: ../footer.txt
