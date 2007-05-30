from equations import SymbolicEquation, forget, assume, assumptions, solve

from calculus import (SymbolicExpressionRing,
                      is_SymbolicExpressionRing,
                      is_SymbolicExpression,
                      CallableSymbolicExpressionRing,
                      is_CallableSymbolicExpressionRing,
                      is_CallableSymbolicExpression,
                      SR,
                      sin, cos, sec, tan, log, erf, sqrt, asin, acos, atan,
                      tanh, sinh, cosh, coth, sech, csch, ln,
                      ceil, floor,
                      polylog,
                      abs_symbolic, exp,
                      is_SymbolicExpression,
                      is_SymbolicExpressionRing)

from functional import (diff, derivative,
                        laplace, inverse_laplace,
                        expand,
                        integrate, limit, lim,
                        taylor, simplify)

from var import (var, function, clear_vars)

from predefined import (a,
                      b,
                      c,
                      d,
                      f,
                      g,
                      h,
                      j,
                      k,
                      l,
                      m,
                      n,
                      o,
                      p,
                      q,
                      r,
                      s,
                      t,
                      u,
                      v,
                      w,
                      x,
                      y,
                      z,
                      A,
                      B,
                      C,
                      D,
                      E,
                      F,
                      G,
                      H,
                      J,
                      K,
                      L,
                      M,
                      N,
                      P,
                      Q,
                      R,
                      S,
                      T,
                      U,
                      V,
                      W,
                      X,
                      Y,
                      Z)

def symbolic_expression(x):
    return SR(x)
