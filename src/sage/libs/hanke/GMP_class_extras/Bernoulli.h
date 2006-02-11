#include<valarray>

////////////////////////////////////////
// Computes the n-th Bernoulli vector //
////////////////////////////////////////

void BernoulliNumberVector(valarray<mpq_class> & Bvec, long n);

////////////////////////////////////////
// Computes the n-th Bernoulli number //
////////////////////////////////////////

mpq_class BernoulliNumber(long n);

////////////////////////////////////////////
// Computes the n-th Bernoulli polynomial //
////////////////////////////////////////////

void BernoulliPolynomial(valarray<mpq_class> & bernpoly, long n);

/////////////////////////////////////////////////////////////////////////////////
// Evaluate a rational "polynomial" (given as a valarray) at a rational number //
/////////////////////////////////////////////////////////////////////////////////

mpq_class EvaluatePolynomial(const valarray<mpq_class> & Coeffs, mpq_class num);

////////////////////////////////////////////////////////////////////////////
// Computes the k-th generalized Bernoulli number for the character (d/.) //
////////////////////////////////////////////////////////////////////////////

mpq_class QuadraticBernoulliNumber(unsigned long k, long d);

// ---------------------------------------------

#if !defined(BERNOULLI_H)
#define BERNOULLI_H

#include "mpz_class_extras.h"
#include "mpq_stuff.h"

#include "Bernoulli.cc"

#endif
