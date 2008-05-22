include '../ext/cdefs.pxi'

cdef int *hamming_weights()

ctypedef unsigned int codeword

cdef struct WordPermutation:
    # A word permutation is a permutation of the bits in a codeword.
    int chunk_num
    int chunk_words
    int degree
    codeword **images
    codeword gate

cdef class BinaryCode:
    cdef codeword *basis
    cdef codeword *words
    cdef int ncols
    cdef int nrows
    cdef int radix
    cdef int nwords

    cdef int is_one(self, int, int)
    cdef int is_automorphism(self, int *, int *)
    cpdef int put_in_std_form(self)
    cdef void _apply_permutation_to_basis(self, object labeling)
    cdef void _update_words_from_basis(self)

cdef WordPermutation *create_word_perm(object)
cdef WordPermutation *create_array_word_perm(int *, int, int)
cdef WordPermutation *create_id_word_perm(int)
cdef WordPermutation *create_comp_word_perm(WordPermutation *, WordPermutation *)
cdef WordPermutation *create_inv_word_perm(WordPermutation *)
cdef int dealloc_word_perm(WordPermutation *)
cdef codeword permute_word_by_wp(WordPermutation *, codeword)
cdef codeword *expand_to_ortho_basis(BinaryCode, int)

cdef class OrbitPartition:
    cdef int nwords
    cdef int ncols
    cdef int *wd_parent
    cdef int *wd_rank
    cdef int *wd_min_cell_rep
    cdef int *wd_size
    cdef int *col_parent
    cdef int *col_rank
    cdef int *col_min_cell_rep
    cdef int *col_size

    cdef int wd_find(self, int)
    cdef void wd_union(self, int, int)
    cdef int col_find(self, int)
    cdef void col_union(self, int, int)
    cdef int merge_perm(self, int *, int *)

cdef class PartitionStack:
    cdef int *wd_ents
    cdef int *wd_lvls
    cdef int *col_ents
    cdef int *col_lvls
    cdef int *basis_locations
    cdef int nwords
    cdef int nrows
    cdef int ncols
    cdef int radix
    cdef int flag
    cdef int *col_degs   #
    cdef int *col_counts #
    cdef int *col_output #
    cdef int *wd_degs    #
    cdef int *wd_counts  # These are just for scratch space...
    cdef int *wd_output  #

    cdef int is_discrete(self, int)
    cdef int num_cells(self, int)
    cdef int sat_225(self, int)
    cdef void new_min_cell_reps(self, int, unsigned int *, int)
    cdef void fixed_vertices(self, int, unsigned int *, unsigned int *, int)
    cdef int new_first_smallest_nontrivial(self, int, unsigned int *, int)
    cdef void col_percolate(self, int, int)
    cdef void wd_percolate(self, int, int)
    cdef int split_vertex(self, int, int)
    cdef int col_degree(self, BinaryCode, int, int, int)
    cdef int wd_degree(self, BinaryCode, int, int, int, int *)
    cdef int sort_cols(self, int, int)
    cdef int sort_wds(self, int, int)
    cdef int refine(self, int, int *, int, BinaryCode, int *)
    cdef void clear(self, int)
    cdef int cmp(self, PartitionStack, BinaryCode)
    cdef int find_basis(self, int *)
    cdef void get_permutation(self, PartitionStack, int *, int *)

cdef class BinaryCodeClassifier:
    cdef int *ham_wts
    cdef int L
    cdef unsigned int *Phi
    cdef unsigned int *Omega
    cdef unsigned int *W
    cdef int radix
    cdef int *Lambda1, *Lambda2, *Lambda3
    cdef int *w_gamma, *c_gamma
    cdef int w_gamma_size
    cdef int *alpha
    cdef int alpha_size
    cdef int *v, *e
    cdef int *aut_gp_gens, *labeling, *base
    cdef int aut_gp_index, aut_gens_size, base_size
    cdef object aut_gp_size

    cdef int Phi_size

    cdef void record_automorphism(self, int *, int)
    cdef void aut_gp_and_can_label(self, BinaryCode, int)
