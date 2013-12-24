#ifndef __DEVICE_MATRIX_H__
#define __DEVICE_MATRIX_H__

#include <cassert>
#include <string>
#include <iostream>
using namespace std;

/* Includes, cuda */
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <helper_cuda.h>

#define CCE(x) checkCudaErrors(x)

template <typename T>
class SCALAR_MEMORY_BUFFER {
public:
  static T* getBuffer() {
    static SCALAR_MEMORY_BUFFER buffer;
    return buffer._ptr;
  }
private:
  SCALAR_MEMORY_BUFFER(): _ptr(NULL) {
    T scalar = 1;
    CCE(cudaMalloc((void **) &_ptr, sizeof(T)));
    CCE(cudaMemcpy(_ptr, &scalar, sizeof(T), cudaMemcpyHostToDevice));
  };
  SCALAR_MEMORY_BUFFER(const SCALAR_MEMORY_BUFFER& source);
  ~SCALAR_MEMORY_BUFFER() { CCE(cudaFree(_ptr)); }
  SCALAR_MEMORY_BUFFER& operator = (const SCALAR_MEMORY_BUFFER& rhs);

  T* _ptr;
};

class CUBLAS_HANDLE {
public:
  static cublasHandle_t& getInstance() {
    static CUBLAS_HANDLE H;
    return H._handle;
  }
private:
  CUBLAS_HANDLE()  { CCE(cublasCreate(&_handle)); }
  CUBLAS_HANDLE(const CUBLAS_HANDLE& source);
  ~CUBLAS_HANDLE() { CCE(cublasDestroy(_handle)); }
  CUBLAS_HANDLE& operator = (const CUBLAS_HANDLE& rhs);

  cublasHandle_t _handle;
};

template <typename T>
class device_matrix {
public:
  // default constructor 
  device_matrix();

  device_matrix(size_t r, size_t c);

  // Copy data from host pointer (in column-major)
  device_matrix(T* h_data, size_t r, size_t c);

  // Load from file. Ex: *.mat in text-form
  device_matrix(const string& filename);

  // Copy Constructor 
  device_matrix(const device_matrix<T>& source);

#ifdef HAVE_THRUST_DEVICE_VECTOR_H
  // Conversion operator
  operator thrust::device_vector<T>() const;
#endif

  // Destructor
  ~device_matrix();

  // ===========================
  // ===== Other Functions =====
  // ===========================
  
  // ===== Addition =====
  device_matrix<T>& operator += (T val);
  device_matrix<T> operator + (T val) const;
  
  device_matrix<T>& operator += (device_matrix<T>& rhs);
  device_matrix<T> operator + (device_matrix<T>& rhs);

  // ===== Substraction =====
  device_matrix<T>& operator -= (T val);
  device_matrix<T> operator - (T val) const;
  
  device_matrix<T>& operator -= (device_matrix<T>& rhs);
  device_matrix<T> operator - (device_matrix<T>& rhs);

  // ===== Division =====
  device_matrix<T>& operator /= (T alpha);
  device_matrix<T> operator / (T alpha) const;
  
  // ===== Matrix-scalar Multiplication =====
  device_matrix<T>& operator *= (T alpha);
  device_matrix<T> operator * (T alpha) const;

  // ===== Matrix-Matrix Multiplication =====
  device_matrix<T>& operator *= (device_matrix<T>& rhs);
  device_matrix<T> operator * (device_matrix<T>& rhs);

  template <typename S>
  friend void swap(device_matrix<S>& lhs, device_matrix<S>& rhs);

  // Operator Assignment:
  // call copy constructor first, and swap with the temp variable
  device_matrix<T>& operator = (device_matrix<T> rhs);

  // Operator transpose
  device_matrix<T>& operator ~ ();

  void _init();
  void resize(size_t r, size_t c);
  void print(FILE* fid = stdout) const;

  void fillwith(T val);
  size_t size() const { return _rows * _cols; }
  size_t getRows() const { return _rows; }
  size_t getCols() const { return _cols; }
  bool isTransposed() const { return _transposed; }
  T* getData() const { return _data; }
  void save(const string& filename) const;

  static void cublas_gemm(
    cublasOperation_t transA, cublasOperation_t transB,
    int m, int n, int k,
    T alpha,
    const T* A, int lda,
    const T* B, int ldb,
    T beta,
    T* C, int ldc);

  static void cublas_geam(
      cublasOperation_t transA, cublasOperation_t transB,
      int m, int n,
      T alpha, const T *A, int lda,
      T beta , const T *B, int ldb,
      T *C, int ldc);

  static void cublas_gemv(
      cublasOperation_t trans,
      int m, int n,
      T alpha,
      const T *A, int lda,
      const T *x, int incx,
      T beta,
      T *y, int incy);

  static void cublas_nrm2(int n, const T *x, int incx, T *result);

  static void cublas_scal(int n, T alpha, T *x, int incx);

  static void cublas_axpy(
      int n, T alpha,
      const T *x, int incx,
      T *y, int incy);

private:
  bool _transposed;

  size_t _rows;
  size_t _cols;
  size_t _capacity;

  T* _data;
};

template <typename T>
void swap(device_matrix<T>& lhs, device_matrix<T>& rhs) {
  using std::swap;
  swap(lhs._transposed, rhs._transposed);
  swap(lhs._rows, rhs._rows);
  swap(lhs._cols, rhs._cols);
  swap(lhs._data, rhs._data);
}

#define dmat device_matrix<T>
template <typename T>
T nrm2(const dmat& A) {
  T result;
  device_matrix<T>::cublas_nrm2(A.size(), A.getData(), 1, &result);
  return result;
}

template <typename T>
void gemm(const dmat& A, const dmat& B, dmat& C, T alpha = 1.0, T beta = 0.0) {
  // Perform C = αA*B + βC, not transpose on A and B
  size_t m = A.getRows();
  size_t n = A.getCols();
  if (A.isTransposed())
    std::swap(m, n);

  size_t k = B.getRows();
  size_t l = B.getCols();
  if (B.isTransposed())
    std::swap(k, l);

  assert(n == k);

  C.resize(m, l);

  int lda = A.getRows();
  int ldb = B.getRows();
  int ldc = C.getRows();

  cublasOperation_t opA = A.isTransposed() ? CUBLAS_OP_T : CUBLAS_OP_N;
  cublasOperation_t opB = B.isTransposed() ? CUBLAS_OP_T : CUBLAS_OP_N;

  device_matrix<T>::cublas_gemm(opA, opB, m, l, k, alpha, A.getData(), lda, B.getData(), ldb, beta, C.getData(), ldc);
}

template <typename T>
void geam(const dmat& A, const dmat& B, dmat& C, T alpha = 1.0, T beta = 1.0) {
  // Perform C = αA + βB, not transpose on A and B
  
  size_t m = A.getRows();
  size_t n = A.getCols();
  if (A.isTransposed())
    std::swap(m, n);

  size_t k = B.getRows();
  size_t l = B.getCols();
  if (B.isTransposed())
    std::swap(k, l);

  assert( m == k && n == l );

  C.resize(m, n);

  int lda = A.getRows();
  int ldb = B.getRows();
  int ldc = C.getRows();

  cublasOperation_t opA = A.isTransposed() ? CUBLAS_OP_T : CUBLAS_OP_N;
  cublasOperation_t opB = B.isTransposed() ? CUBLAS_OP_T : CUBLAS_OP_N;

  device_matrix<T>::cublas_geam(opA, opB, m, n, alpha, A.getData(), lda, beta, B.getData(), ldb, C.getData(), ldc);
}
#undef dmat


template <typename T, typename U>
device_matrix<T> operator + (U alpha, const device_matrix<T>& m) {
  return m + (T) alpha;
}

template <typename T, typename U>
device_matrix<T> operator - (U alpha, const device_matrix<T>& m) {
  return m - (T) alpha;
}

template <typename T, typename U>
device_matrix<T> operator * (U alpha, const device_matrix<T>& m) {
  return m * (T) alpha;
}

#endif // __DEVICE_MATRIX_H__
